import Foundation

/// A minimal, deterministic zip archive writer.
///
/// DEFLATEs each entry when that comes out smaller and stores it otherwise —
/// see `addFile(name:data:compress:)`. STORED entries are legal in .pptx
/// packages too (Office opens them fine), so compression here is a size
/// optimization, not a correctness requirement.
///
/// Implementation notes for the implementer:
/// - Layout: [local file header + data] per entry, then the central directory,
///   then the end-of-central-directory (EOCD) record. All integers little-endian.
/// - Local file header signature 0x04034b50; central dir header 0x02014b50;
///   EOCD 0x06054b50. "version needed to extract" = 20, "version made by" = 20.
/// - General-purpose bit flag: set bit 11 (0x0800, UTF-8 names); never set bit 3
///   (no data descriptors — sizes are known up front).
/// - Determinism is a feature: identical input bytes must produce identical
///   archives. All entries carry the fixed DOS date/time below (the zip epoch),
///   no extra fields, no comments.
/// - Entry names are stored as provided (forward slashes, no leading slash).
/// - Zip64, for the ENTRY COUNT only: past 65535 entries a zip64 EOCD record
///   and locator are emitted and the classic EOCD carries the 0xFFFF sentinel.
///   Emitted only when needed, so smaller archives stay byte-identical.
///   Zip64 SIZES and OFFSETS are NOT implemented — an entry past 0xFFFF_FFFF,
///   or an archive whose central directory starts past it, is still *reported*:
///   `addFile` records the violation and `finalize()` throws
///   `RostrumError.packageInvalid`. Not a precondition, because the parts being
///   written can come from a file somebody else wrote and saving what you just
///   opened must not abort the host. The count is the ceiling a .pptx can
///   plausibly reach and the one this project can prove in CI; the size fields
///   need four gigabytes to exercise, so they stay reported rather than guessed.
public struct ZipWriter {
    /// Fixed DOS date/time stamped on every entry: 1980-01-01 00:00:00 (the DOS epoch).
    /// DOS format: date = ((year-1980)<<9 | month<<5 | day), time = (hour<<11 | minute<<5 | second/2).
    public static let dosEpochDate: UInt16 = 0x0021
    public static let dosEpochTime: UInt16 = 0x0000

    /// One recorded entry, with everything precomputed at `addFile` time.
    private struct Entry {
        let nameBytes: Data
        /// The bytes written into the archive: the original for STORED, or the
        /// DEFLATE stream for method 8.
        let payload: Data
        let method: UInt16
        /// Uncompressed size (payload size equals this only for STORED).
        let uncompressedSize: UInt32
        let crc: UInt32
        let localHeaderOffset: UInt32
    }

    private var entries: [Entry] = []

    /// Byte offset where the next local file header will land
    /// (i.e. total size of all [local header + data] blocks written so far).
    private var nextOffset: UInt64 = 0

    private static let localHeaderSignature: UInt32 = 0x0403_4B50
    private static let centralHeaderSignature: UInt32 = 0x0201_4B50
    private static let eocdSignature: UInt32 = 0x0605_4B50
    private static let zip64EOCDSignature: UInt32 = 0x0606_4B50
    private static let zip64LocatorSignature: UInt32 = 0x0706_4B50
    private static let versionNeeded: UInt16 = 20
    private static let versionMadeBy: UInt16 = 20
    /// Bit 11: UTF-8 file names. Bit 3 (data descriptors) is never set.
    private static let generalPurposeFlag: UInt16 = 0x0800
    /// Compression method 0: STORED. Method 8: DEFLATE.
    private static let methodStored: UInt16 = 0
    private static let methodDeflate: UInt16 = 8

    public init() {}

    /// Append one entry. `name` must use forward slashes and no leading slash
    /// (e.g. "ppt/slides/slide1.xml"). Order of calls is the order in the
    /// archive. When `compress` is true (the default) the entry is DEFLATEd if
    /// that yields a smaller payload, otherwise stored; pass false to skip the
    /// attempt for already-compressed data (PNG/JPEG/nested zips).
    public mutating func addFile(name: String, data: Data, compress: Bool = true) {
        let nameBytes = Data(name.utf8)
        // Record and skip rather than trap. These are the 32-bit fields a
        // non-Zip64 archive has, and every one can be exceeded by a deck that
        // arrived as a file — saving what you just opened must not abort the
        // host. `finalize()` reports it. Returning early also matters because
        // the UInt32 conversions below are themselves trapping.
        if nameBytes.count > 0xFFFF {
            return note("an entry name is \(nameBytes.count) bytes, over the 65535 name field")
        }
        if UInt64(data.count) > 0xFFFF_FFFF {
            return note("entry \(name) is \(data.count) bytes, over the 4294967295 size field")
        }
        if nextOffset > 0xFFFF_FFFF {
            return note("the archive passes the 4294967295 offset field at entry \(name)")
        }

        var method = Self.methodStored
        var payload = data
        if compress, !data.isEmpty {
            let deflated = Deflate.deflate(data)
            if deflated.count < data.count {
                method = Self.methodDeflate
                payload = deflated
            }
        }

        let entry = Entry(
            nameBytes: nameBytes,
            payload: payload,
            method: method,
            uncompressedSize: UInt32(data.count),
            crc: CRC32.checksum(data),
            localHeaderOffset: UInt32(nextOffset)
        )
        entries.append(entry)

        // 30-byte fixed local header + name + payload.
        nextOffset += 30 + UInt64(nameBytes.count) + UInt64(payload.count)
    }

    /// The first limit an entry exceeded, if any. `finalize()` throws on it.
    private var violation: String?

    private mutating func note(_ message: String) {
        if violation == nil { violation = message }
    }

    /// The two ceilings no per-entry check can see, because both are properties
    /// of the finished archive rather than of any one entry. Kept as a pure
    /// function of the numbers so the boundary arithmetic is testable without
    /// allocating four gigabytes.
    ///
    /// `addFile` rejects an entry that would *start* past the 32-bit offset
    /// field, but the last entry accepted can still carry the archive past it:
    /// two 2.5 GB entries both pass that check and end at 5 GB. The central
    /// directory has its own 32-bit size field, reachable with many long names.
    static func archiveOverflow(entriesEnd: UInt64, centralDirectorySize: UInt64) -> String? {
        if entriesEnd > 0xFFFF_FFFF {
            return "the archive's entries end at \(entriesEnd) bytes, "
                + "over the 4294967295 central-directory offset field"
        }
        if centralDirectorySize > 0xFFFF_FFFF {
            return "the central directory is \(centralDirectorySize) bytes, "
                + "over the 4294967295 size field"
        }
        return nil
    }

    /// Produce the complete archive bytes (entries + central directory + EOCD).
    ///
    /// - Throws: `RostrumError.packageInvalid` when an entry, or the finished
    ///   archive, exceeded one of the zip format's fixed-width fields: the
    ///   16-bit entry count and entry-name length, or the 32-bit entry size,
    ///   local-header offset and central-directory size. Writing archives that
    ///   genuinely need Zip64 is a separate, unimplemented feature; this is the
    ///   difference between reporting that and aborting the process.
    public func finalize() throws -> Data {
        if let violation {
            throw RostrumError.packageInvalid("cannot write this archive: \(violation)")
        }
        // 46-byte fixed central header + name, per entry.
        let centralDirectorySize = entries.reduce(UInt64(0)) { $0 + 46 + UInt64($1.nameBytes.count) }
        if let overflow = Self.archiveOverflow(
            entriesEnd: nextOffset, centralDirectorySize: centralDirectorySize) {
            throw RostrumError.packageInvalid("cannot write this archive: \(overflow)")
        }
        // Both conversions are the ones the check above just proved fit; they
        // are made here, next to it, rather than left for `bytes()` to redo.
        return bytes(centralDirectoryOffset: UInt32(nextOffset),
                     centralDirectorySize: UInt32(centralDirectorySize))
    }

    private func bytes(centralDirectoryOffset: UInt32, centralDirectorySize: UInt32) -> Data {
        var out = Data()
        out.reserveCapacity(Int(nextOffset) + entries.count * 46 + 22)

        // Local file headers + data, in insertion order.
        for entry in entries {
            out.appendLE(Self.localHeaderSignature)
            out.appendLE(Self.versionNeeded)
            out.appendLE(Self.generalPurposeFlag)
            out.appendLE(entry.method)
            out.appendLE(Self.dosEpochTime)
            out.appendLE(Self.dosEpochDate)
            out.appendLE(entry.crc)
            out.appendLE(UInt32(entry.payload.count))  // compressed size
            out.appendLE(entry.uncompressedSize)
            out.appendLE(UInt16(entry.nameBytes.count))
            out.appendLE(UInt16(0))  // extra field length
            out.append(entry.nameBytes)
            out.append(entry.payload)
        }

        // Central directory. Its offset is where the local blocks ended, which
        // `finalize()` bounded and passed in.
        for entry in entries {
            out.appendLE(Self.centralHeaderSignature)
            out.appendLE(Self.versionMadeBy)
            out.appendLE(Self.versionNeeded)
            out.appendLE(Self.generalPurposeFlag)
            out.appendLE(entry.method)
            out.appendLE(Self.dosEpochTime)
            out.appendLE(Self.dosEpochDate)
            out.appendLE(entry.crc)
            out.appendLE(UInt32(entry.payload.count))  // compressed size
            out.appendLE(entry.uncompressedSize)
            out.appendLE(UInt16(entry.nameBytes.count))
            out.appendLE(UInt16(0))  // extra field length
            out.appendLE(UInt16(0))  // file comment length
            out.appendLE(UInt16(0))  // disk number start
            out.appendLE(UInt16(0))  // internal file attributes
            out.appendLE(UInt32(0))  // external file attributes
            out.appendLE(entry.localHeaderOffset)
            out.append(entry.nameBytes)
        }

        // Zip64, but ONLY for the entry count, and only when it is needed.
        //
        // The 16-bit EOCD count is the one 32-bit-era ceiling an ordinary .pptx
        // can plausibly reach — 65536 tiny parts is a few megabytes — and it is
        // the one this project can actually prove, in CI and against
        // `/usr/bin/unzip`. The 64-bit SIZE and OFFSET fields are a different
        // feature: they need the per-entry extra field, and nothing here can
        // exercise them without writing four gigabytes, so those limits are
        // still reported by `finalize()` rather than supported. Claiming
        // "zip64" for half of it would be the overstatement this codebase keeps
        // having to walk back.
        //
        // Emitted only when the count needs it, so every archive that fit
        // before is byte-identical to what it was — the corpus gate and the
        // determinism gate both depend on that.
        let needsZip64 = entries.count > 0xFFFF
        if needsZip64 {
            let zip64EOCDOffset = UInt64(out.count)
            out.appendLE(Self.zip64EOCDSignature)
            out.appendLE(UInt64(44))                     // size of the rest of this record
            out.appendLE(UInt16(45))                     // version made by
            out.appendLE(UInt16(45))                     // version needed (4.5 = zip64)
            out.appendLE(UInt32(0))                      // this disk
            out.appendLE(UInt32(0))                      // disk with central directory
            out.appendLE(UInt64(entries.count))          // entries on this disk
            out.appendLE(UInt64(entries.count))          // total entries
            out.appendLE(UInt64(centralDirectorySize))
            out.appendLE(UInt64(centralDirectoryOffset))

            out.appendLE(Self.zip64LocatorSignature)
            out.appendLE(UInt32(0))                      // disk with the zip64 EOCD
            out.appendLE(zip64EOCDOffset)
            out.appendLE(UInt32(1))                      // total disks
        }

        // End of central directory record.
        let countField: UInt16 = needsZip64 ? 0xFFFF : UInt16(entries.count)
        out.appendLE(Self.eocdSignature)
        out.appendLE(UInt16(0))  // number of this disk
        out.appendLE(UInt16(0))  // disk where central directory starts
        out.appendLE(countField)  // entries on this disk
        out.appendLE(countField)  // total entries
        out.appendLE(centralDirectorySize)
        out.appendLE(centralDirectoryOffset)
        out.appendLE(UInt16(0))  // comment length

        return out
    }
}

extension Data {
    fileprivate mutating func appendLE(_ value: UInt16) {
        append(UInt8(truncatingIfNeeded: value))
        append(UInt8(truncatingIfNeeded: value >> 8))
    }

    fileprivate mutating func appendLE(_ value: UInt64) {
        for shift in stride(from: 0, through: 56, by: 8) {
            append(UInt8(truncatingIfNeeded: value >> UInt64(shift)))
        }
    }

    fileprivate mutating func appendLE(_ value: UInt32) {
        append(UInt8(truncatingIfNeeded: value))
        append(UInt8(truncatingIfNeeded: value >> 8))
        append(UInt8(truncatingIfNeeded: value >> 16))
        append(UInt8(truncatingIfNeeded: value >> 24))
    }
}
