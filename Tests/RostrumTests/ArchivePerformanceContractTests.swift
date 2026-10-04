import Foundation
import Testing
@testable import Rostrum

@Suite struct ArchivePerformanceContractTests {
    @Test func lazyCacheStaysBoundedAndMaterializesLosslessly() throws {
        let p = try Presentation(); _ = try p.slides.add()
        let data = try p.serializedData()
        let archive = try OPCArchive(data: data, validation: .onAccess, cacheBytes: 2000)
        #expect(archive.cacheStatistics.retainedBytes == 0)
        for uri in archive.partURIs {
            _ = try archive.data(forPart: uri)
            #expect(archive.cacheStatistics.retainedBytes <= 2000)
        }
        let uri = try #require(archive.mainPartURI)
        _ = try archive.xml(forPart: uri)
        _ = try archive.xml(forPart: uri)
        #expect(archive.cacheStatistics.hits > 0)
        #expect(try archive.presentation().serializedData() == data)
        archive.clearCache()
        #expect(archive.cacheStatistics.retainedBytes == 0)
    }
    @Test func budgetsApplyBeforeLazyDecoding() throws {
        let bytes = try Presentation().serializedData()
        #expect(throws: RostrumError.self) { try OPCArchive(data: bytes, validation: .onAccess, maximumEntryBytes: 0) }
        #expect(throws: RostrumError.self) { try OPCArchive(data: bytes, validation: .onAccess, limits: .init(totalUncompressedBytes: 0)) }
    }
    @Test func lazyBudgetAlsoBoundsCompressedInputWithTinyDecodedOutput() throws {
        let reader = try ZipReader(data: Presentation().serializedData())
        var zip = ZipWriter()
        for name in reader.entryNames { zip.addFile(name: name, data: try reader.data(forEntry: name)) }
        var emptyBlocks = Data()
        for _ in 0..<3000 { emptyBlocks.append(contentsOf: [0, 0, 0, 255, 255]) }
        emptyBlocks.append(contentsOf: [1, 0, 0, 255, 255])
        zip.addFile(name: "ppt/media/padded.bin", payload: .init(data: emptyBlocks, method: 8, size: 0, crc: 0))
        let bytes = try zip.finalize()
        #expect(try ZipReader(data: bytes).data(forEntry: "ppt/media/padded.bin").isEmpty)
        #expect(throws: RostrumError.self) { try OPCArchive(data: bytes, validation: .onAccess, maximumEntryBytes: 10000) }
        #expect(throws: RostrumError.self) { try OPCArchive(data: bytes, validation: .strict, maximumEntryBytes: 10000) }
    }
    @Test func lazyOpenRejectsNamesThatWouldNormalizeToAnotherPart() throws {
        let reader = try ZipReader(data: Presentation().serializedData())
        var zip = ZipWriter()
        for name in reader.entryNames { zip.addFile(name: name, data: try reader.data(forEntry: name)) }
        zip.addFile(name: "ppt//unexpected.xml", data: Data("<unexpected/>".utf8))
        let bytes = try zip.finalize()
        #expect(throws: RostrumError.self) { try OPCArchive(data: bytes, validation: .onAccess) }
        #expect(throws: RostrumError.self) { try Presentation(data: bytes) }
    }
    @Test func deferredCRCFailuresAreExplicitWhileEagerOpenStillThrows() throws {
        let p = try Presentation()
        let uri = PackURI("/ppt/media/bad.png")
        p.package.addPart(uri: uri, contentType: "image/png", blob: Data([1,2,3,4]))
        var data = try p.serializedData()
        let entry = try #require(ZipReader(data: data).allEntries.first { $0.name == uri.memberName })
        let offset = entry.localHeaderOffset
        let nameLength = Int(data[offset + 26]) + (Int(data[offset + 27]) << 8)
        let extraLength = Int(data[offset + 28]) + (Int(data[offset + 29]) << 8)
        data[offset + 30 + nameLength + extraLength] ^= 255
        let archive = try OPCArchive(data: data, validation: .onAccess)
        #expect(throws: RostrumError.self) { try archive.data(forPart: uri) }
        #expect(throws: RostrumError.self) { try OPCArchive(data: data, validation: .strict) }
        #expect(throws: RostrumError.self) { try Presentation(data: data) }
    }
    @Test func streamingAndCachedSavesAreByteIdenticalAndInvalidate() throws {
        let p = try Presentation()
        let text = try p.slides[0].shapes.addTextBox(Rect(x: .zero, y: .zero, width: .inches(3), height: .inches(2))).textFrame!
        text.text = String(repeating: "compressible text ", count: 100)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("rostrum-stream-\(UUID()).pptx")
        defer { try? FileManager.default.removeItem(at: url) }
        let original = try p.serializedData()
        try p.save(to: url)
        #expect(try Data(contentsOf: url) == original)
        text.text = "changed"
        try p.save(to: url)
        #expect(try Data(contentsOf: url) == p.serializedData())
        #expect(try Data(contentsOf: url) != original)
        let reopened = try Presentation(contentsOf: url)
        #expect(try reopened.serializedData() == p.serializedData())
        // A name the reader cannot preserve must be rejected before publishing.
        p.package.addPart(uri: PackURI("/invalid.rels"), contentType: "x", blob: Data())
        let beforeFailure = try Data(contentsOf: url)
        #expect(throws: RostrumError.self) { try p.save(to: url) }
        #expect(try Data(contentsOf: url) == beforeFailure)
    }

    @Test func replacingPartReleasesOldCompressionCacheOwnershipImmediately() throws {
        let p = try Presentation()
        let uri = PackURI("/ppt/media/replaced.png")
        weak var oldPart: Part?
        do {
            let part = p.package.addPart(uri: uri, contentType: "image/png", blob: Data(repeating: 1, count: 100000))
            oldPart = part
            _ = try p.serializedData()
        }
        #expect(oldPart != nil)
        p.package.addPart(uri: uri, contentType: "image/png", blob: Data([2]))
        #expect(oldPart == nil)
        let reopened = try Presentation(data: p.serializedData())
        #expect(reopened.package.parts[uri]?.blob == Data([2]))
    }

    @Test func saveCannotReplaceADirectoryAndPreservesExistingFilePermissions() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("rostrum-atomic-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let child = folder.appendingPathComponent("keep.txt")
        let original = Data("keep nested data".utf8)
        try original.write(to: child)
        let deck = try Presentation()
        #expect(throws: (any Error).self) { try deck.save(to: folder) }
        #expect(try Data(contentsOf: child) == original)
        #expect(try FileManager.default.contentsOfDirectory(atPath: folder.path) == ["keep.txt"])
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: child.path)
        try deck.save(to: child)
        let mode = try FileManager.default.attributesOfItem(atPath: child.path)[.posixPermissions] as? NSNumber
        #expect(mode?.intValue == 0o600)
        #expect(try Presentation(contentsOf: child).slideCount == deck.slideCount)
    }
}
