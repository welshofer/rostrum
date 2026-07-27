import Foundation
import Testing
@testable import Rostrum

/// Tests for the zip reader, against archives from the Info-ZIP `zip` CLI
/// (deflated) and hand-built minimal archives (stored, plus corruption and
/// unsupported-feature variants).
@Suite struct ZipReaderTests {

    // MARK: - Helpers

    private enum FixtureError: Error {
        case toolFailed(String, Int32)
    }

    @discardableResult
    private func runTool(_ path: String, _ arguments: [String], cwd: URL? = nil) throws -> Data {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        if let cwd { process.currentDirectoryURL = cwd }
        let stdoutPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice
        try process.run()
        let output = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw FixtureError.toolFailed(path, process.terminationStatus)
        }
        return output
    }

    /// Make a fresh temporary directory; caller cleans up.
    private func makeTempDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("rostrum-ziptest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func pseudorandomData(count: Int, seed: UInt64) -> Data {
        var state = seed
        var bytes = [UInt8]()
        bytes.reserveCapacity(count)
        for _ in 0..<count {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            bytes.append(UInt8(truncatingIfNeeded: state >> 33))
        }
        return Data(bytes)
    }

    private func expectError(
        _ label: String,
        _ isMatch: (RostrumError) -> Bool,
        sourceLocation: SourceLocation = #_sourceLocation,
        _ body: () throws -> Void
    ) {
        do {
            try body()
            Issue.record("\(label): expected an error but nothing was thrown", sourceLocation: sourceLocation)
        } catch let error as RostrumError {
            #expect(isMatch(error), "\(label): unexpected error \(error)", sourceLocation: sourceLocation)
        } catch {
            Issue.record("\(label): expected RostrumError, got \(error)", sourceLocation: sourceLocation)
        }
    }

    private func isZipCorrupt(_ e: RostrumError) -> Bool {
        if case .zipCorrupt = e { return true }
        return false
    }

    private func isZipUnsupported(_ e: RostrumError) -> Bool {
        if case .zipUnsupported = e { return true }
        return false
    }

    // MARK: - Hand-built archive builder (stored entries, arbitrary field overrides)

    private struct TestEntry {
        var name: String
        var payload: Data
        var crc: UInt32
        var method: UInt16 = 0
        var flags: UInt16 = 0
        var compressedSize: UInt32?
        var uncompressedSize: UInt32?
        /// CRC/sizes written into the *local* header (streaming writers put zeros there).
        var localCRC: UInt32?
        var localCompressedSize: UInt32?
        var localUncompressedSize: UInt32?
        var localExtra = Data()
        var writeDataDescriptor = false
    }

    private func le16(_ v: Int) -> [UInt8] { [UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF)] }
    private func le32(_ v: UInt32) -> [UInt8] {
        [UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF), UInt8((v >> 16) & 0xFF), UInt8((v >> 24) & 0xFF)]
    }

    private func buildZip(_ entries: [TestEntry], comment: Data = Data()) -> Data {
        var out = [UInt8]()
        var localOffsets: [Int] = []

        for entry in entries {
            localOffsets.append(out.count)
            let nameBytes = Array(entry.name.utf8)
            let comp = entry.compressedSize ?? UInt32(entry.payload.count)
            let uncomp = entry.uncompressedSize ?? UInt32(entry.payload.count)
            out += le32(0x0403_4B50)                              // local header signature
            out += le16(20)                                       // version needed
            out += le16(Int(entry.flags))
            out += le16(Int(entry.method))
            out += le16(0)                                        // mod time
            out += le16(0x21)                                     // mod date (1980-01-01)
            out += le32(entry.localCRC ?? entry.crc)
            out += le32(entry.localCompressedSize ?? comp)
            out += le32(entry.localUncompressedSize ?? uncomp)
            out += le16(nameBytes.count)
            out += le16(entry.localExtra.count)
            out += nameBytes
            out += [UInt8](entry.localExtra)
            out += [UInt8](entry.payload)
            if entry.writeDataDescriptor {
                out += le32(0x0807_4B50)                          // optional descriptor signature
                out += le32(entry.crc)
                out += le32(comp)
                out += le32(uncomp)
            }
        }

        let cdOffset = out.count
        for (i, entry) in entries.enumerated() {
            let nameBytes = Array(entry.name.utf8)
            let comp = entry.compressedSize ?? UInt32(entry.payload.count)
            let uncomp = entry.uncompressedSize ?? UInt32(entry.payload.count)
            out += le32(0x0201_4B50)                              // central header signature
            out += le16(20)                                       // version made by
            out += le16(20)                                       // version needed
            out += le16(Int(entry.flags))
            out += le16(Int(entry.method))
            out += le16(0)                                        // mod time
            out += le16(0x21)                                     // mod date
            out += le32(entry.crc)
            out += le32(comp)
            out += le32(uncomp)
            out += le16(nameBytes.count)
            out += le16(0)                                        // extra length
            out += le16(0)                                        // comment length
            out += le16(0)                                        // disk number start
            out += le16(0)                                        // internal attributes
            out += le32(0)                                        // external attributes
            out += le32(UInt32(localOffsets[i]))
            out += nameBytes
        }
        let cdSize = out.count - cdOffset

        out += le32(0x0605_4B50)                                  // EOCD signature
        out += le16(0)                                            // this disk
        out += le16(0)                                            // cd start disk
        out += le16(entries.count)                                // entries on disk
        out += le16(entries.count)                                // total entries
        out += le32(UInt32(cdSize))
        out += le32(UInt32(cdOffset))
        out += le16(comment.count)
        out += [UInt8](comment)
        return Data(out)
    }

    // MARK: - Archives from the zip CLI (deflated)

    @Test func zipCLIArchiveRoundTrip() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        // Strongly compressible text → the CLI will deflate it.
        let aContent = Data(String(repeating: "PowerPoint packaging is mostly XML plumbing. ", count: 500).utf8)
        let bContent = Data("short but sweet".utf8)
        let cContent = pseudorandomData(count: 4096, seed: 99) // incompressible → CLI stores it
        try aContent.write(to: dir.appendingPathComponent("a.txt"))
        try bContent.write(to: dir.appendingPathComponent("b.txt"))
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("sub"), withIntermediateDirectories: true)
        try cContent.write(to: dir.appendingPathComponent("sub/c.bin"))

        try runTool("/usr/bin/zip", ["-X", "-9", "archive.zip", "a.txt", "b.txt", "sub/c.bin"], cwd: dir)
        let archiveData = try Data(contentsOf: dir.appendingPathComponent("archive.zip"))

        // Sanity: the first local header (a.txt, at offset 0) uses method 8.
        let firstMethod = Int(archiveData[8]) | Int(archiveData[9]) << 8
        #expect(firstMethod == 8, "expected the CLI to deflate a.txt")

        let reader = try ZipReader(data: archiveData)
        #expect(reader.entryNames == ["a.txt", "b.txt", "sub/c.bin"])
        #expect(reader.contains("a.txt"))
        #expect(reader.contains("sub/c.bin"))
        #expect(!reader.contains("missing.txt"))
        #expect(try reader.data(forEntry: "a.txt") == aContent)
        #expect(try reader.data(forEntry: "b.txt") == bContent)
        #expect(try reader.data(forEntry: "sub/c.bin") == cContent)
    }

    @Test func zipCLICorruptedPayloadThrowsZipCorrupt() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let content = Data(String(repeating: "corrupt me gently, one byte at a time. ", count: 300).utf8)
        try content.write(to: dir.appendingPathComponent("victim.txt"))
        try runTool("/usr/bin/zip", ["-X", "-9", "archive.zip", "victim.txt"], cwd: dir)
        var archiveData = try Data(contentsOf: dir.appendingPathComponent("archive.zip"))

        // The entry data starts after the 30-byte local header + name; flip a
        // byte comfortably inside the compressed payload.
        let nameLength = Int(archiveData[26]) | Int(archiveData[27]) << 8
        let extraLength = Int(archiveData[28]) | Int(archiveData[29]) << 8
        let dataStart = 30 + nameLength + extraLength
        archiveData[dataStart + 20] ^= 0xFF

        let reader = try ZipReader(data: archiveData)
        expectError("corrupted deflate payload", isZipCorrupt) {
            _ = try reader.data(forEntry: "victim.txt")
        }
    }

    // MARK: - Hand-built stored archives

    @Test func storedArchiveRoundTrip() throws {
        let hello = Data("hello".utf8)
        let world = Data("world of zip readers".utf8)
        let archive = buildZip([
            TestEntry(name: "greeting.txt", payload: hello, crc: CRC32.checksum(hello)),
            TestEntry(name: "ppt/slides/slide1.xml", payload: world, crc: CRC32.checksum(world)),
        ])
        let reader = try ZipReader(data: archive)
        #expect(reader.entryNames == ["greeting.txt", "ppt/slides/slide1.xml"])
        #expect(reader.contains("greeting.txt"))
        #expect(!reader.contains("greeting"))
        #expect(try reader.data(forEntry: "greeting.txt") == hello)
        #expect(try reader.data(forEntry: "ppt/slides/slide1.xml") == world)
    }

    @Test func knownCRCOracleValue() throws {
        // CRC of "hello" is 0x3610A686 (verified against Python's zlib.crc32).
        let hello = Data("hello".utf8)
        let archive = buildZip([TestEntry(name: "h.txt", payload: hello, crc: 0x3610_A686)])
        let reader = try ZipReader(data: archive)
        #expect(try reader.data(forEntry: "h.txt") == hello)
    }

    @Test func emptyArchive() throws {
        let archive = buildZip([])
        #expect(archive.count == 22)
        let reader = try ZipReader(data: archive)
        #expect(reader.entryNames.isEmpty)
        #expect(!reader.contains("anything"))
    }

    @Test func crcMismatchThrowsZipCorrupt() throws {
        let original = Data("payload whose CRC is recorded".utf8)
        var corrupted = original
        corrupted[5] ^= 0x01
        // CRC field is for the original; the payload byte differs → CRC mismatch.
        let archive = buildZip([
            TestEntry(name: "bad.bin", payload: corrupted, crc: CRC32.checksum(original))
        ])
        let reader = try ZipReader(data: archive)
        expectError("stored CRC mismatch", isZipCorrupt) {
            _ = try reader.data(forEntry: "bad.bin")
        }
    }

    @Test func trailingCommentEOCDScan() throws {
        let content = Data("comments should not confuse the EOCD scan".utf8)
        let comment = Data("This archive has a chatty trailing comment! ".utf8)
            + Data(repeating: 0x2E, count: 300)
        let archive = buildZip(
            [TestEntry(name: "x.txt", payload: content, crc: CRC32.checksum(content))],
            comment: comment)
        let reader = try ZipReader(data: archive)
        #expect(reader.entryNames == ["x.txt"])
        #expect(try reader.data(forEntry: "x.txt") == content)
    }

    @Test func commentContainingFakeEOCDSignature() throws {
        // A comment that itself contains a plausible-looking EOCD record must
        // not hijack the scan (the fake claims zero entries).
        let content = Data("the real record wins".utf8)
        var fake = [UInt8]()
        fake += [0x50, 0x4B, 0x05, 0x06]           // EOCD signature
        fake += [UInt8](repeating: 0, count: 16)   // zero disks/counts/size/offset
        fake += [0, 0]                             // zero comment length
        let archive = buildZip(
            [TestEntry(name: "real.txt", payload: content, crc: CRC32.checksum(content))],
            comment: Data(fake))
        let reader = try ZipReader(data: archive)
        #expect(reader.entryNames == ["real.txt"])
        #expect(try reader.data(forEntry: "real.txt") == content)
    }

    @Test func streamingModeUsesCentralDirectoryValues() throws {
        // Streaming writers (general-purpose bit 3) put zeros in the local
        // header and append a data descriptor; central directory values are
        // authoritative.
        let content = Data("streamed entry with trailing data descriptor".utf8)
        let archive = buildZip([
            TestEntry(
                name: "streamed.txt", payload: content, crc: CRC32.checksum(content),
                flags: 0x0008, localCRC: 0, localCompressedSize: 0, localUncompressedSize: 0,
                writeDataDescriptor: true)
        ])
        let reader = try ZipReader(data: archive)
        #expect(try reader.data(forEntry: "streamed.txt") == content)
    }

    @Test func localHeaderExtraFieldDiffersFromCentral() throws {
        // The local header carries an extra field the central directory does
        // not; the data start must come from the local header's own lengths.
        let content = Data("extra fields shift the data start".utf8)
        let extra = Data([0x55, 0x54, 0x05, 0x00, 0x03, 0x12, 0x34, 0x56, 0x78]) // UT timestamp
        let archive = buildZip([
            TestEntry(name: "extra.txt", payload: content, crc: CRC32.checksum(content), localExtra: extra)
        ])
        let reader = try ZipReader(data: archive)
        #expect(try reader.data(forEntry: "extra.txt") == content)
    }

    @Test func duplicateNamesLastOneWins() throws {
        let first = Data("first version".utf8)
        let second = Data("second version wins".utf8)
        let archive = buildZip([
            TestEntry(name: "dup.txt", payload: first, crc: CRC32.checksum(first)),
            TestEntry(name: "dup.txt", payload: second, crc: CRC32.checksum(second)),
        ])
        let reader = try ZipReader(data: archive)
        // Both records are still visible as raw central-directory data...
        #expect(reader.allEntries.count == 2)
        // ...but the name is listed ONCE, because it resolves to one entry.
        // Listing it twice invited a caller looping over these names to decode
        // the same entry twice — 65535 records under one name is a few hundred
        // kilobytes of archive and tens of thousands of decompressions, which no
        // per-entry budget can see.
        #expect(reader.entryNames == ["dup.txt"])
        #expect(reader.contains("dup.txt"))
        #expect(try reader.data(forEntry: "dup.txt") == second)
        // The charge matches the work: only the surviving entry is counted.
        #expect(reader.declaredUncompressedSize == UInt64(second.count))
    }

    @Test func missingEntryThrows() throws {
        let content = Data("present".utf8)
        let archive = buildZip([TestEntry(name: "here.txt", payload: content, crc: CRC32.checksum(content))])
        let reader = try ZipReader(data: archive)
        #expect(throws: RostrumError.self) {
            _ = try reader.data(forEntry: "not-here.txt")
        }
    }

    // MARK: - Unsupported features

    @Test func unsupportedCompressionMethodThrows() throws {
        let payload = Data("pretend this is bzip2".utf8)
        let archive = buildZip([
            TestEntry(name: "weird.bin", payload: payload, crc: CRC32.checksum(payload), method: 12)
        ])
        let reader = try ZipReader(data: archive) // parsing succeeds; decode is lazy
        #expect(reader.contains("weird.bin"))
        expectError("method 12", isZipUnsupported) {
            _ = try reader.data(forEntry: "weird.bin")
        }
    }

    @Test func encryptedEntryThrows() throws {
        let payload = Data("secret bytes".utf8)
        let archive = buildZip([
            TestEntry(name: "vault.bin", payload: payload, crc: CRC32.checksum(payload), flags: 0x0001)
        ])
        let reader = try ZipReader(data: archive)
        expectError("encrypted entry", isZipUnsupported) {
            _ = try reader.data(forEntry: "vault.bin")
        }
    }

    @Test func zip64SentinelThrowsUnsupported() throws {
        // Sentinel values are only zip64 markers when a zip64 EOCD locator
        // (0x07064B50, 20 bytes) immediately precedes the EOCD; without one,
        // 0xFFFF… fields are literal values (see RegressionTests for the
        // 65535-entry case). Build locator + EOCD-with-sentinel: unsupported.
        var tail = [UInt8]()
        tail += [0x50, 0x4B, 0x06, 0x07]           // zip64 EOCD locator sig
        tail += [0, 0, 0, 0]                       // disk with zip64 EOCD
        tail += [0, 0, 0, 0, 0, 0, 0, 0]           // zip64 EOCD offset (u64)
        tail += [1, 0, 0, 0]                       // total disks
        tail += [0x50, 0x4B, 0x05, 0x06]           // EOCD sig
        tail += [0, 0, 0, 0]                       // disk numbers
        tail += [0xFF, 0xFF, 0xFF, 0xFF]           // entry counts: sentinel
        tail += [0xFF, 0xFF, 0xFF, 0xFF]           // cd size sentinel
        tail += [0xFF, 0xFF, 0xFF, 0xFF]           // cd offset sentinel
        tail += [0, 0]                             // no comment
        expectError("zip64 EOCD sentinel", isZipUnsupported) {
            _ = try ZipReader(data: Data(tail))
        }
    }

    @Test func zip64EntrySentinelThrowsUnsupported() throws {
        let payload = Data("normal payload".utf8)
        let archive = buildZip([
            TestEntry(
                name: "big.bin", payload: payload, crc: CRC32.checksum(payload),
                uncompressedSize: 0xFFFF_FFFF,
                localUncompressedSize: UInt32(payload.count))
        ])
        expectError("zip64 entry sentinel", isZipUnsupported) {
            _ = try ZipReader(data: archive)
        }
    }

    // MARK: - Structural corruption

    @Test func garbageDataThrowsZipCorrupt() {
        expectError("random bytes", isZipCorrupt) {
            _ = try ZipReader(data: pseudorandomData(count: 4096, seed: 5))
        }
        expectError("tiny file", isZipCorrupt) {
            _ = try ZipReader(data: Data([0x50, 0x4B]))
        }
        expectError("empty file", isZipCorrupt) {
            _ = try ZipReader(data: Data())
        }
    }

    @Test func corruptedCentralDirectorySignatureThrows() throws {
        let content = Data("soon to be broken".utf8)
        var archive = buildZip([TestEntry(name: "e.txt", payload: content, crc: CRC32.checksum(content))])
        // The central directory begins right after [30-byte local header + name + payload].
        let cdOffset = 30 + "e.txt".utf8.count + content.count
        #expect(Int(archive[cdOffset]) == 0x50) // sanity: found the signature
        archive[cdOffset] ^= 0xFF
        expectError("bad central signature", isZipCorrupt) {
            _ = try ZipReader(data: archive)
        }
    }

    @Test func truncatedArchiveThrowsZipCorrupt() throws {
        let content = Data("this archive will be cut short".utf8)
        let archive = buildZip([TestEntry(name: "t.txt", payload: content, crc: CRC32.checksum(content))])
        // Chop off the last 10 bytes: the EOCD is destroyed.
        expectError("truncated EOCD", isZipCorrupt) {
            _ = try ZipReader(data: archive.prefix(archive.count - 10))
        }
    }

    @Test func corruptedLocalHeaderSignatureThrows() throws {
        let content = Data("local header about to break".utf8)
        var archive = buildZip([TestEntry(name: "l.txt", payload: content, crc: CRC32.checksum(content))])
        archive[0] ^= 0xFF // destroy the local header signature
        let reader = try ZipReader(data: archive) // central directory still parses
        expectError("bad local signature", isZipCorrupt) {
            _ = try reader.data(forEntry: "l.txt")
        }
    }

    @Test func storedSizeMismatchThrowsZipCorrupt() throws {
        // A stored entry whose central-directory sizes disagree.
        let payload = Data("sizes disagree".utf8)
        let archive = buildZip([
            TestEntry(
                name: "s.bin", payload: payload, crc: CRC32.checksum(payload),
                compressedSize: UInt32(payload.count),
                uncompressedSize: UInt32(payload.count + 4))
        ])
        let reader = try ZipReader(data: archive)
        expectError("stored size mismatch", isZipCorrupt) {
            _ = try reader.data(forEntry: "s.bin")
        }
    }
}
