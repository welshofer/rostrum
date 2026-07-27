import Foundation

/// A minimal, deterministic zip archive writer.
///
/// Produces a fully valid zip file using STORED (uncompressed) entries.
/// STORED entries are legal in .pptx packages — Office opens them fine; DEFLATE
/// support is a later size optimization, not a correctness requirement.
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
/// - No zip64: adding an entry that would push any 32-bit field past 0xFFFF_FFFF,
///   or more than 0xFFFF entries, is a programmer error (precondition failure) —
///   pptx files never approach these limits.
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
        if entries.count >= 0xFFFF {
            return note("more than 65535 entries")
        }
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

    /// Produce the complete archive bytes (entries + central directory + EOCD).
    ///
    /// - Throws: `RostrumError.packageInvalid` when an entry exceeded one of
    ///   the zip format's 32-bit fields. Writing archives that genuinely need
    ///   Zip64 is a separate, unimplemented feature; this is the difference
    ///   between reporting that and aborting the process.
    public func finalize() throws -> Data {
        if let violation {
            throw RostrumError.packageInvalid("cannot write this archive: \(violation)")
        }
        return bytes()
    }

    private func bytes() -> Data {
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

        // Central directory.
        let centralDirectoryOffset = UInt32(out.count)
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
        let centralDirectorySize = UInt32(out.count) - centralDirectoryOffset

        // End of central directory record.
        out.appendLE(Self.eocdSignature)
        out.appendLE(UInt16(0))  // number of this disk
        out.appendLE(UInt16(0))  // disk where central directory starts
        out.appendLE(UInt16(entries.count))  // entries on this disk
        out.appendLE(UInt16(entries.count))  // total entries
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

    fileprivate mutating func appendLE(_ value: UInt32) {
        append(UInt8(truncatingIfNeeded: value))
        append(UInt8(truncatingIfNeeded: value >> 8))
        append(UInt8(truncatingIfNeeded: value >> 16))
        append(UInt8(truncatingIfNeeded: value >> 24))
    }
}
