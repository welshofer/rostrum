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
/// - Zip64 (0xFFFFFFFF sentinels / signature 0x06064b50) → `zipUnsupported`;
///   no real pptx needs it.
/// - Verify the CRC-32 of every decoded entry against the central directory and
///   throw `zipCorrupt` on mismatch.
/// - Duplicate entry names: last one wins (matches other tooling).
public struct ZipReader {

    /// Ceilings a caller can put on an archive somebody else wrote.
    ///
    /// Every entry is already bounded by its own declared uncompressed size:
    /// `Inflate` stops at it and `data(forEntry:)` rejects a stream that decoded
    /// to anything else. What no per-entry bound can see is the *sum*. A few
    /// kilobytes of archive can declare thousands of entries that each expand to
    /// gigabytes, and opening a package decodes every one of them — amplification
    /// across entries rather than within one.
    ///
    /// Because the per-entry bound does hold, the total a full read can produce
    /// is exactly the sum of the declared sizes, and the central directory
    /// declares all of them before a single byte is inflated. So the ceiling is
    /// checked up front rather than accumulated as entries are decoded: an
    /// over-budget archive costs no decompression at all, and the verdict cannot
    /// depend on which entries a caller happens to read, or in what order.
    ///
    /// This bounds *declared* size, which is the conservative direction — an
    /// archive that declares far more than it would really produce is refused.
    /// That is what a budget means; the alternative is doing the work to find out.
    ///
    /// The default is `.unlimited`, so decks that are simply large keep opening.
    /// Set a budget when reading files from somewhere you do not control.
    public struct Limits: Sendable, Equatable {
        /// Maximum total uncompressed bytes the archive may declare across every
        /// entry. `nil` means no ceiling.
        public var totalUncompressedBytes: Int?

        public init(totalUncompressedBytes: Int? = nil) {
            self.totalUncompressedBytes = totalUncompressedBytes
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

    /// Total uncompressed bytes the central directory declares across every
    /// entry. This is the ceiling on what decoding the whole archive can
    /// produce, since each entry is bounded by its own declared size.
    ///
    /// `UInt64` rather than `Int` because the value is derived from a file
    /// somebody else wrote and can legally reach ~2.8e14 — narrowing it would
    /// be a trapping conversion on exactly the input this guard exists for.
    public let declaredUncompressedSize: UInt64

    /// Parses the EOCD + central directory eagerly; entry data is decoded lazily.
    ///
    /// - Throws: `RostrumError.zipUnsupported` when the archive declares more
    ///   uncompressed bytes than `limits` allows — before anything is inflated.
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
                            throw RostrumError.zipUnsupported("zip64 end-of-central-directory sentinels")
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

        var entries: [Entry] = []
        var entryFlags: [UInt16] = []
        var indexByName: [String: Int] = [:]
        entries.reserveCapacity(totalEntries)
        entryFlags.reserveCapacity(totalEntries)

        var offset = cdOffset
        for _ in 0..<totalEntries {
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

            let name = Self.decodeName([UInt8](bytes[offset + 46..<offset + 46 + nameLength]), flags: flags)
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

        // Accumulate in UInt64 rather than Int: 65535 entries (the EOCD count
        // field is 16-bit) each declaring just under 4 GB is ~2.8e14, which no
        // 32-bit Int would hold. The declared sizes come from a file somebody
        // else wrote, so the arithmetic that bounds them must not itself
        // overflow.
        let declared = entries.reduce(UInt64(0)) { $0 + UInt64($1.uncompressedSize) }
        if let ceiling = limits.totalUncompressedBytes, declared > UInt64(max(0, ceiling)) {
            throw RostrumError.zipUnsupported(
                "the archive declares \(declared) uncompressed bytes across \(entries.count) "
                    + "entries, over the \(ceiling)-byte read budget")
        }
        self.declaredUncompressedSize = declared

        self.archive = bytes
        self.entries = entries
        self.entryFlags = entryFlags
        self.indexByName = indexByName
    }

    /// Entry names in central-directory order.
    public var entryNames: [String] {
        entries.map(\.name)
    }

    /// All central-directory entries, in order — exposes each entry's
    /// compression `method`, sizes, and CRC for callers inspecting an archive.
    public var allEntries: [Entry] {
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

    private static func u32(_ bytes: [UInt8], _ offset: Int) -> UInt32 {
        UInt32(bytes[offset])
            | UInt32(bytes[offset + 1]) << 8
            | UInt32(bytes[offset + 2]) << 16
            | UInt32(bytes[offset + 3]) << 24
    }
}
