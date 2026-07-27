import Foundation
import Testing

@testable import Rostrum

@Suite("ZipWriterTests")
struct ZipWriterTests {

    // MARK: - Fixtures

    /// Deterministic ~100KB pseudorandom payload from a simple LCG
    /// (deliberately not SystemRandomNumberGenerator, so bytes are stable).
    private static func lcgBytes(count: Int, seed: UInt64) -> Data {
        var state = seed
        var data = Data(capacity: count)
        for _ in 0..<count {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            data.append(UInt8(truncatingIfNeeded: state >> 33))
        }
        return data
    }

    private static let smallText = Data(
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"/>
        """.utf8)

    private static let blob = lcgBytes(count: 100_000, seed: 0x0BAD_5EED)

    /// Builds the canonical 3-entry test archive:
    /// - "[Content_Types].xml": ASCII name that is not shell/glob-safe, small text
    /// - "ppt/slides/slide1.xml": nested path, empty file
    /// - "ppt/media/image1.bin": nested path, ~100KB seeded pseudorandom bytes
    /// STORED-only archive, for deterministically testing header layout
    /// independent of whether a payload happens to compress.
    private static func makeStoredArchive() throws -> Data {
        var writer = ZipWriter()
        writer.addFile(name: "[Content_Types].xml", data: smallText, compress: false)
        writer.addFile(name: "ppt/slides/slide1.xml", data: Data(), compress: false)
        writer.addFile(name: "ppt/media/image1.bin", data: blob, compress: false)
        return try writer.finalize()
    }

    private static func makeArchive() throws -> Data {
        var writer = ZipWriter()
        writer.addFile(name: "[Content_Types].xml", data: smallText)
        writer.addFile(name: "ppt/slides/slide1.xml", data: Data())
        writer.addFile(name: "ppt/media/image1.bin", data: blob)
        return try writer.finalize()
    }

    private static func writeTempArchive(_ archive: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("rostrum-ziptest-\(UUID().uuidString).zip")
        try archive.write(to: url)
        return url
    }

    /// Runs /usr/bin/unzip with the given arguments, returning exit status and stdout bytes.
    private static func runUnzip(_ arguments: [String]) throws -> (status: Int32, stdout: Data) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = arguments
        let out = Pipe()
        process.standardOutput = out
        process.standardError = Pipe()
        try process.run()
        // Drain stdout before waiting, so a large output can't deadlock the pipe.
        let stdout = out.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus, stdout)
    }

    // MARK: - Determinism

    @Test("Same inputs produce byte-identical archives")
    func deterministicOutput() throws {
        let first = try Self.makeArchive()
        let second = try Self.makeArchive()
        #expect(!first.isEmpty)
        #expect(first == second)
    }

    @Test("Empty writer emits just a valid EOCD record")
    func emptyArchive() throws {
        let writer = ZipWriter()
        let archive = try writer.finalize()
        #expect(archive.count == 22)
        #expect(Array(archive.prefix(4)) == [0x50, 0x4B, 0x05, 0x06])
        // Every remaining field (counts, sizes, offsets, comment length) is zero.
        #expect(archive.dropFirst(4).allSatisfy { $0 == 0 })
    }

    // MARK: - Structure

    @Test("Archive layout: local header signature, EOCD fields, central directory")
    func structuralFields() throws {
        let archive = try Self.makeStoredArchive()

        // Starts with a local file header signature PK\x03\x04.
        #expect(Array(archive.prefix(4)) == [0x50, 0x4B, 0x03, 0x04])

        // EOCD is the last 22 bytes (no comment).
        let eocd = archive.suffix(22)
        #expect(Array(eocd.prefix(4)) == [0x50, 0x4B, 0x05, 0x06])

        func le16(_ data: Data, _ offset: Int) -> UInt16 {
            let base = data.startIndex + offset
            return UInt16(data[base]) | (UInt16(data[base + 1]) << 8)
        }
        func le32(_ data: Data, _ offset: Int) -> UInt32 {
            let base = data.startIndex + offset
            return UInt32(data[base])
                | (UInt32(data[base + 1]) << 8)
                | (UInt32(data[base + 2]) << 16)
                | (UInt32(data[base + 3]) << 24)
        }

        let eocdData = Data(eocd)
        #expect(le16(eocdData, 8) == 3)  // entries on this disk
        #expect(le16(eocdData, 10) == 3)  // total entries
        let centralSize = le32(eocdData, 12)
        let centralOffset = le32(eocdData, 16)
        #expect(le16(eocdData, 20) == 0)  // comment length
        #expect(Int(centralOffset) + Int(centralSize) + 22 == archive.count)

        // Central directory begins with PK\x01\x02 at the recorded offset.
        let cdStart = archive.startIndex + Int(centralOffset)
        #expect(Array(archive[cdStart..<(cdStart + 4)]) == [0x50, 0x4B, 0x01, 0x02])

        // First central header: version made by / needed = 20, flag 0x0800, STORED,
        // DOS epoch timestamp.
        let cd = Data(archive[cdStart...])
        #expect(le16(cd, 4) == 20)  // version made by
        #expect(le16(cd, 6) == 20)  // version needed
        #expect(le16(cd, 8) == 0x0800)  // general-purpose flag: UTF-8, no bit 3
        #expect(le16(cd, 10) == 0)  // method STORED
        #expect(le16(cd, 12) == ZipWriter.dosEpochTime)
        #expect(le16(cd, 14) == ZipWriter.dosEpochDate)
        #expect(le32(cd, 16) == CRC32.checksum(Self.smallText))
        #expect(le32(cd, 20) == UInt32(Self.smallText.count))  // compressed
        #expect(le32(cd, 24) == UInt32(Self.smallText.count))  // uncompressed
        #expect(le16(cd, 28) == UInt16("[Content_Types].xml".utf8.count))
        #expect(le16(cd, 30) == 0)  // extra length
        #expect(le32(cd, 42) == 0)  // first local header offset
    }

    // MARK: - 32-bit ceilings

    @Test("Archive-wide ceilings are reported at their boundary, not one past it")
    func archiveOverflowBoundaries() {
        let ceiling: UInt64 = 0xFFFF_FFFF

        // `addFile` bounds where an entry *starts*; nothing there can see where
        // the archive ends. Two entries under the per-entry size limit can end
        // past the offset field, which is the case that used to trap in
        // `UInt32(out.count)` rather than throw.
        #expect(ZipWriter.archiveOverflow(entriesEnd: ceiling, centralDirectorySize: 0) == nil)
        #expect(ZipWriter.archiveOverflow(entriesEnd: ceiling + 1, centralDirectorySize: 0) != nil)

        #expect(ZipWriter.archiveOverflow(entriesEnd: 0, centralDirectorySize: ceiling) == nil)
        #expect(ZipWriter.archiveOverflow(entriesEnd: 0, centralDirectorySize: ceiling + 1) != nil)

        // The entries-end message must be the one reported when both overflow,
        // since that is the first field the writer would have to fill.
        let both = ZipWriter.archiveOverflow(
            entriesEnd: ceiling + 1, centralDirectorySize: ceiling + 1)
        #expect(both?.contains("entries end") == true)
    }

    @Test("The central-directory size finalize() projects is the size it writes")
    func projectedCentralDirectorySizeMatches() throws {
        // finalize() bounds a PROJECTED central-directory size (46 bytes plus
        // the name, per entry) and hands it to bytes(), which writes it into the
        // EOCD verbatim. So reading that field back and comparing it to the same
        // formula proves nothing — both sides would be the projection.
        //
        // Measure the emitted central directory instead: it runs from the offset
        // the EOCD records to the start of the EOCD itself. If the projection
        // ever drifts from the layout bytes() actually emits, the guard bounds a
        // number the archive does not have, and this is what notices.
        let archive = try Self.makeStoredArchive()
        let eocd = Data(archive.suffix(22))
        func le32(_ data: Data, _ offset: Int) -> UInt32 {
            let base = data.startIndex + offset
            return UInt32(data[base])
                | (UInt32(data[base + 1]) << 8)
                | (UInt32(data[base + 2]) << 16)
                | (UInt32(data[base + 3]) << 24)
        }
        let recordedSize = Int(le32(eocd, 12))
        let recordedOffset = Int(le32(eocd, 16))

        // Establish the two anchors BEFORE doing arithmetic with them, so a
        // drift fails the test instead of trapping on a bad slice — and so
        // "22 bytes from the end" is a verified fact about this archive rather
        // than a second projection subtracted from the first.
        try #require(recordedOffset >= 0 && recordedOffset + 4 <= archive.count - 22)
        let eocdStart = archive.startIndex + archive.count - 22
        #expect(Array(archive[eocdStart..<(eocdStart + 4)]) == [0x50, 0x4B, 0x05, 0x06])
        let start = archive.startIndex + recordedOffset
        #expect(Array(archive[start..<(start + 4)]) == [0x50, 0x4B, 0x01, 0x02])

        // The measured size: everything between the central directory's start
        // and the EOCD that terminates the file.
        let measuredSize = archive.count - 22 - recordedOffset
        #expect(recordedSize == measuredSize)
        #expect(recordedOffset > 0 && measuredSize > 0)

        // Walking the central headers must land exactly on the EOCD, which
        // catches a per-record size drift that the total could mask.
        var offset = recordedOffset
        for _ in 0..<3 {
            // Bounds-check before indexing. A drift in the layout is exactly
            // what this walk exists to catch, and an out-of-range subscript
            // would trap — aborting the whole test process instead of failing
            // this one test, which is the opposite of catching it.
            try #require(offset + 46 <= archive.count)
            #expect(Array(archive[(archive.startIndex + offset)..<(archive.startIndex + offset + 4)])
                == [0x50, 0x4B, 0x01, 0x02])
            let nameLength = Int(archive[archive.startIndex + offset + 28])
                | (Int(archive[archive.startIndex + offset + 29]) << 8)
            offset += 46 + nameLength
        }
        #expect(offset == archive.count - 22)
    }

    // MARK: - External oracle (/usr/bin/unzip)

    @Test("unzip -t validates the archive with exit status 0")
    func unzipIntegrityCheck() throws {
        let url = try Self.writeTempArchive(Self.makeArchive())
        defer { try? FileManager.default.removeItem(at: url) }

        let result = try Self.runUnzip(["-t", url.path])
        #expect(result.status == 0)

        let listing = String(decoding: result.stdout, as: UTF8.self)
        #expect(listing.contains("[Content_Types].xml"))
        #expect(listing.contains("ppt/slides/slide1.xml"))
        #expect(listing.contains("ppt/media/image1.bin"))
    }

    @Test("unzip -p reads back exact entry bytes")
    func unzipReadBack() throws {
        let url = try Self.writeTempArchive(Self.makeArchive())
        defer { try? FileManager.default.removeItem(at: url) }

        // ~100KB pseudorandom entry must round-trip byte-for-byte.
        let blobResult = try Self.runUnzip(["-p", url.path, "ppt/media/image1.bin"])
        #expect(blobResult.status == 0)
        #expect(blobResult.stdout == Self.blob)

        // Small text entry round-trips too.
        let textResult = try Self.runUnzip(["-p", url.path, "ppt/slides/slide1.xml"])
        #expect(textResult.status == 0)
        #expect(textResult.stdout.isEmpty)

        // The glob-unsafe ASCII name is addressable with escaped brackets.
        let typesResult = try Self.runUnzip(["-p", url.path, "\\[Content_Types\\].xml"])
        #expect(typesResult.status == 0)
        #expect(typesResult.stdout == Self.smallText)
    }
}
