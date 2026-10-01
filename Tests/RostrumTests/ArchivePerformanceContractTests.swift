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
}
