import Foundation
import Testing
import Rostrum
@testable import LecternCore

@Suite struct ImageFillExportRecipeTests {
    @Test(arguments: [LibraryDemoID.tableAppearance, .fillsAndLines], [false, true])
    func selectedFillAssetsReachActualExport(id: LibraryDemoID, alternative: Bool) throws {
        let retained = ProcessInfo.processInfo.environment["LECTERN_IMAGE_FILL_EXPORT_ARTIFACTS"]
        let parent = retained.map { URL(fileURLWithPath: $0) } ?? FileManager.default.temporaryDirectory.appendingPathComponent("FillExport-" + UUID().uuidString)
        defer { if retained == nil { try? FileManager.default.removeItem(at: parent) } }
        let result = try LibraryLab.run(id, options: .init(alternative: alternative), in: parent)
        #expect(result.passed)
        for name in ["Selected image fills enter the outline", "Selected image fills export exact bytes"] {
            #expect(result.checks.contains { $0.name == name && $0.passed })
        }
        let bytes = try Data(contentsOf: result.afterURL), deck = try Presentation(data: bytes)
        let expectedPages = id == .tableAppearance ? [1, 2] : [1, 9, 10]
        let expectedPaths = Set(expectedPages.map { String(format: "slide-%02d/image1.png", $0) })
        let imageParts = deck.package.parts.values.filter { $0.contentType.hasPrefix("image/") }
        try #require(imageParts.count == 1)
        #expect(imageParts[0].blob == LibraryLabSupport.pixels && imageParts[0].blob.count == 84)
        let outline = deck.outline()
        #expect(outline.warnings.isEmpty)
        #expect(outline.slides.filter { !$0.assets.isEmpty }.map(\.number) == expectedPages)
        #expect(outline.assetCount == expectedPages.count)
        #expect(outline.slides.flatMap(\.assets).allSatisfy { $0.kind == .image && $0.partName == imageParts[0].uri.value && $0.filename == "image1.png" })
        let extraction = result.directory.appendingPathComponent("extracted/" + id.rawValue)
        func fileBytes(_ directory: URL) throws -> [String: Data] {
            let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey])
            var files: [String: Data] = [:]
            while let file = enumerator?.nextObject() as? URL {
                if try file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
                    files[file.resolvingSymlinksInPath().pathComponents.dropFirst(directory.resolvingSymlinksInPath().pathComponents.count).joined(separator: "/")] = try Data(contentsOf: file)
                }
            }
            return files
        }
        let originalExport = try fileBytes(extraction)
        #expect(Set(originalExport.keys) == expectedPaths.union([id.rawValue + ".md"]))
        for path in expectedPaths { #expect(originalExport[path] == LibraryLabSupport.pixels) }
        let markdown = try String(contentsOf: extraction.appendingPathComponent(id.rawValue + ".md"), encoding: .utf8)
        for path in expectedPaths { #expect(markdown.contains(path)) }
        let repeated = try DeckExporter.export(deckAt: result.afterURL, into: result.directory.appendingPathComponent("extracted"))
        #expect(repeated.assetsWritten == expectedPages.count && repeated.chartsWritten == 0 && repeated.warnings.isEmpty)
        #expect(try fileBytes(repeated.directory) == originalExport)
        #expect(try deck.serializedData() == bytes)
        #expect(try Data(contentsOf: result.afterURL) == bytes)
        let fresh = try DeckInspector.inspect(deckAt: result.afterURL)
        for page in 1...result.slideCount {
            let index = try #require(fresh.previewSlideNumbers.firstIndex(of: page))
            let saved = try String(contentsOf: result.directory.appendingPathComponent(String(format: "previews/slide-%02d.svg", page)), encoding: .utf8)
            #expect(saved == fresh.previews[index])
        }
    }
}
