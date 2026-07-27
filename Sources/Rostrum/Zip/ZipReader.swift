import Foundation

/// A minimal zip archive reader sufficient for every real-world .pptx file.
///
/// Implementation notes for the implementer:
/// - Locate the EOCD record by scanning backwards from the end of the file for
///   signature 0x06054b50 (the trailing comment can be up to 65535 bytes; scan
///   at most that far). Truncated/absent EOCD → `RostrumError.zipCorrupt`.
/// - Parse the central directory for the authoritative entry list. Central
///   directory sizes/CRCs are authoritative even when the writer used streaming
///   mode (general-purpose bit 3) and the local header holds zeros.
/// - To read an entry's bytes, seek to its local header and use the *local
///   header's own* name/extra lengths to find the data start (they can differ
///   from the central directory's).
/// - Supported methods: 0 (STORED) and 8 (DEFLATE, via `Inflate`). Anything else
///   → `RostrumError.zipUnsupported`. Encrypted entries (bit 0) → unsupported.
/// - Zip64, partially: the ENTRY COUNT is supported, so an archive with more
///   than 65535 entries reads (and `ZipWriter` writes one). A 0xFFFF count in
///   the EOCD sends us to the zip64 EOCD record only when a locator (0x07064b50)
///   precedes the EOCD — 0xFFFF alone is a legal literal (APPNOTE 4.4.1.4).
///   Zip64 SIZES and OFFSETS are NOT supported: a 0xFFFFFFFF sentinel in a
///   central-directory entry, or in the EOCD's size/offset fields, throws
///   `zipUnsupported`. Those need the per-entry zip64 extra field, and nothing
///   in this project can exercise them without a four-gigabyte archive.
/// - Verify the CRC-32 of every decoded entry against the central directory and
///   throw `zipCorrupt` on mismatch.
/// - Duplicate entry names: last one wins (matches other tooling).
public struct ZipReader {

    /// Ceilings a caller can put on an archive somebody else wrote.
    ///
    /// Every entry is already bounded by its own declared uncompressed size:
    /// `Inflate` refuses the write that would pass it, and `data(forEntry:)`
    /// rejects a stream that decoded to anything else. What no per-entry bound
    /// can see is the *sum*. A few kilobytes of archive can declare thousands of
    /// entries that each expand to gigabytes, and opening a package decodes
    /// every one — amplification across entries rather than within one.
    ///
    /// Because the per-entry bound holds, one decode of each resolvable name —
    /// a single pass over `entryNames`/`allEntries`, which is what opening a
    /// package does — produces exactly the sum of their declared sizes, and the
    /// central directory states all of them before a byte is inflated. So the
    /// ceiling is checked up front rather than accumulated as entries decode:
    /// an over-budget archive costs no decompression at all, and the verdict
    /// cannot depend on which entries a caller reads, or in what order.
    ///
    /// Read what this bounds precisely, because three plausible readings are wrong:
    ///
    /// - It bounds bytes **produced**, not **work done**. Decoding costs
    ///   `compressedSize` per name — copied, copied again, then scanned —
    ///   and an entry can declare it produces nothing while costing megabytes.
    ///   Work is bounded instead by a structural check in `init`: the entries'
    ///   compressed sizes must sum to no more than the archive, which no
    ///   well-formed archive violates and which holds under `.unlimited` too.
    /// - Neither bound covers a caller who fetches the **same name twice**.
    ///   Both are per resolvable name, once. `centralDirectoryRecords` will
    ///   hand back one record per shadow, so looping *that* and fetching by
    ///   name decodes the survivor once per shadow; loop `allEntries` instead.
    /// - It bounds **decoded output**, not **peak memory**, and the gap is not
    ///   small. DEFLATE expands by at most 1032:1 against this decoder (one bit
    ///   per symbol, 258 bytes per match), so an archive passing the structural
    ///   check can still decode to ~1032x its own size — and `OPCPackage.read`
    ///   retains every decoded part for the package's lifetime, so the peak
    ///   tracks the SUM of all parts, not the largest one. Within a single
    ///   entry the decoder briefly holds its growing buffer, the buffer it is
    ///   growing out of, and the `Data` copy of the result.
    ///
    /// And it bounds *declared* size, which is the conservative direction: an
    /// archive that declares far more than it would really produce is refused.
    /// That is what a budget means; the alternative is doing the work to find out.
    ///
    /// The default is `.unlimited`, so decks that are simply large keep opening.
    /// Set a budget when reading files from somewhere you do not control.
    public struct Limits: Sendable, Equatable {
        /// Maximum total uncompressed bytes the archive may declare across the
        /// entries a name resolves to. `nil` means no ceiling. Never negative:
        /// a negative ceiling is clamped to zero on the way in, so the number
        /// enforced is always the number a rejection reports.
        ///
        /// Zero admits only an archive that declares nothing, which is exactly
        /// what it can produce.
        public var totalUncompressedBytes: Int? {
            didSet { totalUncompressedBytes = totalUncompressedBytes.map { Swift.max(0, $0) } }
        }

        public init(totalUncompressedBytes: Int? = nil) {
            // A budget computed as `available - alreadyUsed` can go negative;
            // clamping here keeps the comparison and the error message from
            // disagreeing about which number is in force.
            self.totalUncompressedBytes = totalUncompressedBytes.map { Swift.max(0, $0) }
        }

        /// No ceiling — the default, and the behaviour before limits existed.
        public static let unlimited = Limits()
    }
    public struct Entry: Sendable {
        public let name: String
        /// 0 = stored, 8 = deflate.
        public let method: UInt16
        public let compressedSize: Int
        public let uncompressedSize: Int
        public let crc32: UInt32
        /// Offset of the entry's *local file header* from the start of the archive.
        public let localHeaderOffset: Int
    }

    private static let eocdSignature: UInt32 = 0x0605_4B50
    private static let centralSignature: UInt32 = 0x0201_4B50
    private static let localSignature: UInt32 = 0x0403_4B50

    private let archive: [UInt8]
    private let entries: [Entry]
    /// General-purpose bit flags per entry, parallel to `entries`.
    private let entryFlags: [UInt16]
    /// Entry index by name; for duplicate names the last one wins.
    private let indexByName: [String: Int]
    /// Indices of the entries a name resolves to, ascending. Every entry that
    /// is not in here is shadowed by a later one with the same name and can
    /// never be decoded, so it costs nothing and is charged nothing.
    private let reachable: [Int]

    /// Total uncompressed bytes declared across the entries a name resolves to
    /// — the same set as `entryNames` and `allEntries`, not every
    /// central-directory record. This is the ceiling on what decoding the whole
    /// archive can produce, since each entry is bounded by its own declared
    /// size and a shadowed record can never be fetched.
    ///
    /// `UInt64` rather than `Int` because the value is derived from a file
    /// somebody else wrote and can legally reach ~2.8e14 — narrowing it would
    /// be a trapping conversion on exactly the input this guard exists for.
    public let declaredUncompressedSize: UInt64

    /// Parses the EOCD + central directory eagerly; entry data is decoded lazily.
    ///
    /// - Throws: `RostrumError.readBudgetExceeded` when the archive declares
    ///   more uncompressed bytes than `limits` allows; `RostrumError.zipCorrupt`
    ///   for a malformed archive — no end-of-central-directory record, a
    ///   truncated or mis-signed central directory, or entries claiming more
    ///   compressed bytes in total than the archive contains; and
    ///   `RostrumError.zipUnsupported` for zip64 and multi-disk archives.
    ///   All of them fire before anything is inflated.
    public init(data: Data, limits: Limits = .unlimited) throws {
        let bytes = [UInt8](data)
        let size = bytes.count
        guard size >= 22 else {
            throw RostrumError.zipCorrupt("file too small to contain an end-of-central-directory record (\(size) bytes)")
        }

        // Scan backwards for the EOCD signature; the trailing comment can push
        // it up to 65535 bytes from the end. Validate each candidate so that a
        // spurious signature inside the comment is not mistaken for the record.
        var eocd = -1
        let lowestCandidate = max(0, size - 22 - 65535)
        var candidate = size - 22
        scan: while candidate >= lowestCandidate {
            if Self.u32(bytes, candidate) == Self.eocdSignature {
                let commentLength = Self.u16(bytes, candidate + 20)
                if candidate + 22 + commentLength == size {
                    let totalEntries = Self.u16(bytes, candidate + 10)
                    let cdSize = Self.u32(bytes, candidate + 12)
                    let cdOffset = Self.u32(bytes, candidate + 16)
                    // 0xFFFF/0xFFFFFFFF are zip64 sentinels ONLY when a zip64
                    // EOCD locator (0x07064b50, 20 bytes) precedes the EOCD;
                    // otherwise they are legal literal values (e.g. an archive
                    // with exactly 65535 entries) per APPNOTE 4.4.1.4.
                    if totalEntries == 0xFFFF || cdSize == 0xFFFF_FFFF || cdOffset == 0xFFFF_FFFF {
                        let hasZip64Locator = candidate >= 20
                            && Self.u32(bytes, candidate - 20) == 0x0706_4B50
                        if hasZip64Locator {
                            // Only the entry COUNT is supported, matching what
                            // `ZipWriter` emits. A size or offset sentinel means
                            // an archive past 4 GB, which needs the per-entry
                            // zip64 extra field this reader does not parse —
                            // reporting that is honest, guessing at it is not.
                            guard cdSize != 0xFFFF_FFFF, cdOffset != 0xFFFF_FFFF else {
                                throw RostrumError.zipUnsupported(
                                    "zip64 sizes/offsets (only the entry count is supported)")
                            }
                        }
                    }
                    // The central directory must end exactly where the EOCD begins.
                    if Int(cdOffset) + Int(cdSize) == candidate {
                        eocd = candidate
                        break scan
                    }
                }
            }
            candidate -= 1
        }
        guard eocd >= 0 else {
            throw RostrumError.zipCorrupt("end-of-central-directory record not found")
        }

        let diskNumber = Self.u16(bytes, eocd + 4)
        let cdStartDisk = Self.u16(bytes, eocd + 6)
        let entriesOnDisk = Self.u16(bytes, eocd + 8)
        let totalEntries = Self.u16(bytes, eocd + 10)
        let cdOffset = Int(Self.u32(bytes, eocd + 16))
        guard diskNumber == 0, cdStartDisk == 0, entriesOnDisk == totalEntries else {
            throw RostrumError.zipUnsupported("multi-disk archive")
        }

        // A 0xFFFF count with a zip64 locator in front of the EOCD means the
        // real count lives in the zip64 EOCD record. 0xFFFF on its own is a
        // legal literal (APPNOTE 4.4.1.4) and must NOT send us looking.
        var realTotalEntries = Int(totalEntries)
        if totalEntries == 0xFFFF, eocd >= 20, Self.u32(bytes, eocd - 20) == 0x0706_4B50 {
            // Every number below comes from the file. Bound each one BEFORE
            // narrowing it: `Int(someUInt64)` is a trapping conversion, and the
            // whole point of this reader is that hostile bytes cannot abort the
            // host process.
            let recordOffset = Self.u64(bytes, eocd - 20 + 8)
            guard recordOffset <= UInt64(eocd), Int(recordOffset) + 56 <= eocd - 20 else {
                throw RostrumError.zipCorrupt("zip64 end-of-central-directory record out of range")
            }
            let zip64EOCD = Int(recordOffset)
            guard Self.u32(bytes, zip64EOCD) == 0x0606_4B50 else {
                throw RostrumError.zipCorrupt("zip64 end-of-central-directory record not found")
            }
            let count = Self.u64(bytes, zip64EOCD + 32)
            // The count bounds an allocation and a loop, and it came from the
            // file. One central-directory record is at least 46 bytes, so a
            // count that cannot fit between the directory's start and the EOCD
            // is a lie; refuse before reserving anything. `max(0, ...)` because
            // cdOffset is file-derived too and can exceed eocd, where the
            // subtraction goes negative and the conversion would trap.
            guard count <= UInt64(max(0, eocd - cdOffset) / 46) else {
                throw RostrumError.zipCorrupt(
                    "zip64 record claims \(count) entries, more than the central directory holds")
            }
            realTotalEntries = Int(count)
        }

        var entries: [Entry] = []
        var entryFlags: [UInt16] = []
        var indexByName: [String: Int] = [:]
        /// The raw bytes each decoded name came from, so a collision between
        /// two DIFFERENT byte sequences can be told from an honest duplicate.
        var rawNameByName: [String: [UInt8]] = [:]
        entries.reserveCapacity(realTotalEntries)
        entryFlags.reserveCapacity(realTotalEntries)

        var offset = cdOffset
        for _ in 0..<realTotalEntries {
            guard offset + 46 <= eocd else {
                throw RostrumError.zipCorrupt("truncated central directory")
            }
            guard Self.u32(bytes, offset) == Self.centralSignature else {
                throw RostrumError.zipCorrupt("bad central directory header signature at offset \(offset)")
            }
            let flags = UInt16(Self.u16(bytes, offset + 8))
            let method = UInt16(Self.u16(bytes, offset + 10))
            let crc = Self.u32(bytes, offset + 16)
            let compressedSize = Self.u32(bytes, offset + 20)
            let uncompressedSize = Self.u32(bytes, offset + 24)
            let nameLength = Self.u16(bytes, offset + 28)
            let extraLength = Self.u16(bytes, offset + 30)
            let commentLength = Self.u16(bytes, offset + 32)
            let localHeaderOffset = Self.u32(bytes, offset + 42)

            if compressedSize == 0xFFFF_FFFF || uncompressedSize == 0xFFFF_FFFF
                || localHeaderOffset == 0xFFFF_FFFF {
                throw RostrumError.zipUnsupported("zip64 sentinel in central directory entry")
            }
            guard offset + 46 + nameLength + extraLength + commentLength <= eocd else {
                throw RostrumError.zipCorrupt("truncated central directory entry")
            }

            let rawName = [UInt8](bytes[offset + 46..<offset + 46 + nameLength])
            let name = Self.decodeName(rawName, flags: flags)
            // Member names are BYTES; `indexByName` keys them by Swift String,
            // and Swift compares strings by canonical equivalence. Two records
            // whose names differ as bytes can therefore be `==` as Strings —
            // via Unicode normalisation (NFC vs NFD), or because `decodeName`
            // maps both UTF-8 and CP437 onto one String namespace. Last-wins
            // would silently drop one part and serve the other's bytes under
            // its name, with no error at any layer.
            //
            // Genuine duplicates — the same bytes twice — stay last-wins, which
            // is what other tooling does and what this type documents.
            if let previous = indexByName[name], rawNameByName[name] != rawName {
                throw RostrumError.zipCorrupt(
                    "entries \(previous) and \(entries.count) have different names that decode "
                        + "to the same text (\"\(name)\"), so one would silently replace the other")
            }
            rawNameByName[name] = rawName
            let entry = Entry(
                name: name,
                method: method,
                compressedSize: Int(compressedSize),
                uncompressedSize: Int(uncompressedSize),
                crc32: crc,
                localHeaderOffset: Int(localHeaderOffset)
            )
            indexByName[name] = entries.count
            entries.append(entry)
            entryFlags.append(flags)
            offset += 46 + nameLength + extraLength + commentLength
        }

        // Sum over the entries a name RESOLVES to, not over every record.
        // Duplicate names are last-wins, so a shadowed record can never be
        // decoded: charging for it would reject archives that cost nothing,
        // and — more to the point — the sum has to describe the same set the
        // caller will iterate, or the budget bounds the wrong thing.
        //
        // UInt64 because that is the natural width for a sum of 32-bit zip size
        // fields: it cannot overflow for any archive the format can express
        // (65535 records x just under 4 GB is ~2.8e14), so there is no width
        // question to reason about at the call site. Rostrum's platforms are
        // all 64-bit, where a plain Int would also hold it — this is about not
        // having to make that argument, not about rescuing a 32-bit build.
        let reachable = indexByName.values.sorted()
        let declared = reachable.reduce(UInt64(0)) { $0 + UInt64(entries[$1].uncompressedSize) }

        // The budget bounds bytes PRODUCED. It does not bound the work of
        // producing them, which is O(compressedSize) per name: the payload
        // slice is copied out of the archive, the decoder copies it again, and
        // the DEFLATE scan walks all of it. Nothing in the central directory
        // forces two records to describe DIFFERENT payload regions —
        // `localHeaderOffset` is per record and never compared against another
        // — so N records with N DISTINCT names can all point at one large
        // payload. Every one of them resolves, so every one is decoded, and
        // each can declare it produces nothing (a run of empty stored blocks
        // decodes to zero bytes with CRC 0), so the budget is charged nothing.
        //
        // A well-formed archive cannot do that: its payloads are disjoint and
        // inside the file, so their compressed sizes sum to less than the file
        // itself. That makes this a structural check on the archive rather than
        // caller policy — it holds under `.unlimited` too, and it bounds a full
        // read's work at O(archive size), which is what the budget was wrongly
        // assumed to give.
        let compressed = reachable.reduce(UInt64(0)) { $0 + UInt64(entries[$1].compressedSize) }
        if compressed > UInt64(size) {
            throw RostrumError.zipCorrupt(
                "entries claim \(compressed) compressed bytes in a \(size)-byte archive, so "
                    + "their payloads cannot all be distinct")
        }
        if let ceiling = limits.totalUncompressedBytes {
            // `Limits.init` clamps a negative ceiling to zero, so the number
            // compared is the number reported.
            if declared > UInt64(ceiling) {
                throw RostrumError.readBudgetExceeded(declared: declared, limit: ceiling)
            }
        }
        self.declaredUncompressedSize = declared
        self.reachable = reachable

        self.archive = bytes
        self.entries = entries
        self.entryFlags = entryFlags
        self.indexByName = indexByName
    }

    /// The names a caller can actually resolve, in central-directory order —
    /// one per distinct name.
    ///
    /// Duplicate names are last-wins (see the type documentation), so a name
    /// repeated N times still resolves to exactly one entry. Listing it N times
    /// would invite a caller looping over these names to decode that same entry
    /// N times: the shadowed records need no local header and no payload, only
    /// their 46-byte central-directory record, so a few megabytes of archive
    /// could buy tens of thousands of full decompressions. That is unbounded
    /// work behind a bounded `Limits` budget, which accounts per entry.
    public var entryNames: [String] {
        reachable.map { entries[$0].name }
    }

    /// The entries a name resolves to, in central-directory order — exposes
    /// each entry's compression `method`, sizes, and CRC for callers inspecting
    /// an archive. One per distinct name, matching `entryNames` position for
    /// position, and its `uncompressedSize`s sum to `declaredUncompressedSize`.
    ///
    /// Shadowed records are excluded for the same reason `entryNames` excludes
    /// them: a caller looping over these and fetching by name would otherwise
    /// decode one entry once per record that shares its name. Use
    /// `centralDirectoryRecords` to see the raw list.
    public var allEntries: [Entry] {
        reachable.map { entries[$0] }
    }

    /// Every central-directory record, in file order, including ones shadowed
    /// by a later record with the same name.
    ///
    /// For inspecting an archive's structure, not for reading it: a shadowed
    /// record cannot be fetched — `data(forEntry:)` resolves by name, and the
    /// last record with a name wins — so fetching one by name returns a
    /// different record's bytes. `allEntries` is what a reader wants.
    public var centralDirectoryRecords: [Entry] {
        entries
    }

    public func contains(_ name: String) -> Bool {
        indexByName[name] != nil
    }

    /// Decode and CRC-verify one entry.
    public func data(forEntry name: String) throws -> Data {
        guard let index = indexByName[name] else {
            throw RostrumError.partMissing(name)
        }
        let entry = entries[index]
        let flags = entryFlags[index]

        if flags & 0x0001 != 0 {
            throw RostrumError.zipUnsupported("encrypted entry \"\(name)\"")
        }

        // Seek to the local header; its own name/extra lengths (which can differ
        // from the central directory's) locate the start of the entry data.
        let local = entry.localHeaderOffset
        guard local + 30 <= archive.count else {
            throw RostrumError.zipCorrupt("local file header out of range for \"\(name)\"")
        }
        guard Self.u32(archive, local) == Self.localSignature else {
            throw RostrumError.zipCorrupt("bad local file header signature for \"\(name)\"")
        }
        let nameLength = Self.u16(archive, local + 26)
        let extraLength = Self.u16(archive, local + 28)
        let dataStart = local + 30 + nameLength + extraLength
        guard dataStart + entry.compressedSize <= archive.count else {
            throw RostrumError.zipCorrupt("entry data out of range for \"\(name)\"")
        }
        let raw = Data(archive[dataStart..<dataStart + entry.compressedSize])

        let decoded: Data
        switch entry.method {
        case 0:
            guard entry.compressedSize == entry.uncompressedSize else {
                throw RostrumError.zipCorrupt(
                    "stored entry \"\(name)\" has mismatched sizes (\(entry.compressedSize) vs \(entry.uncompressedSize))")
            }
            decoded = raw
        case 8:
            do {
                decoded = try Inflate.inflate(raw, expectedOutputSize: entry.uncompressedSize)
            } catch let error as RostrumError {
                if case .deflateCorrupt(let message) = error {
                    throw RostrumError.zipCorrupt("entry \"\(name)\": corrupt DEFLATE stream: \(message)")
                }
                throw error
            }
        default:
            throw RostrumError.zipUnsupported("compression method \(entry.method) for \"\(name)\"")
        }

        guard decoded.count == entry.uncompressedSize else {
            throw RostrumError.zipCorrupt(
                "entry \"\(name)\" decoded to \(decoded.count) bytes, expected \(entry.uncompressedSize)")
        }
        guard CRC32.checksum(decoded) == entry.crc32 else {
            throw RostrumError.zipCorrupt("CRC-32 mismatch for entry \"\(name)\"")
        }
        return decoded
    }

    // MARK: - Entry-name decoding

    /// Decode an entry name per APPNOTE Appendix D: bit 11 of the
    /// general-purpose flags means UTF-8; otherwise the name is nominally IBM
    /// CP437. Many modern tools write UTF-8 bytes without setting bit 11, so
    /// for the flag-clear case we accept valid UTF-8 first (ASCII is identical
    /// in both encodings) and fall back to the CP437 table only for byte
    /// sequences that are not valid UTF-8.
    private static func decodeName(_ bytes: [UInt8], flags: UInt16) -> String {
        if flags & 0x0800 != 0 {
            return String(decoding: bytes, as: UTF8.self)
        }
        if let utf8 = String(bytes: bytes, encoding: .utf8) {
            return utf8
        }
        var scalars = String.UnicodeScalarView()
        scalars.reserveCapacity(bytes.count)
        for byte in bytes {
            if byte < 0x80 {
                scalars.append(Unicode.Scalar(byte))
            } else {
                scalars.append(Self.cp437HighHalf[Int(byte) - 0x80])
            }
        }
        return String(scalars)
    }

    /// CP437 code points 0x80–0xFF.
    private static let cp437HighHalf: [Unicode.Scalar] = Array(
        "ÇüéâäàåçêëèïîìÄÅÉæÆôöòûùÿÖÜ¢£¥₧ƒáíóúñÑªº¿⌐¬½¼¡«»░▒▓│┤╡╢╖╕╣║╗╝╜╛┐└┴┬├─┼╞╟╚╔╩╦╠═╬╧╨╤╥╙╘╒╓╫╪┘┌█▄▌▐▀αßΓπΣσµτΦΘΩδ∞φε∩≡±≥≤⌠⌡÷≈°∙·√ⁿ²■\u{00A0}".unicodeScalars)

    // MARK: - Little-endian readers

    private static func u16(_ bytes: [UInt8], _ offset: Int) -> Int {
        Int(bytes[offset]) | Int(bytes[offset + 1]) << 8
    }

    private static func u64(_ bytes: [UInt8], _ offset: Int) -> UInt64 {
        var value: UInt64 = 0
        for i in 0..<8 { value |= UInt64(bytes[offset + i]) << UInt64(8 * i) }
        return value
    }

    private static func u32(_ bytes: [UInt8], _ offset: Int) -> UInt32 {
        UInt32(bytes[offset])
            | UInt32(bytes[offset + 1]) << 8
            | UInt32(bytes[offset + 2]) << 16
            | UInt32(bytes[offset + 3]) << 24
    }
}
