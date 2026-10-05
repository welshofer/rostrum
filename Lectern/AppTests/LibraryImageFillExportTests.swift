import Foundation
import Testing
import LecternCore
import Rostrum
@testable import Lectern

@Suite @MainActor struct LibraryImageFillExportAppTests {
    @Test(arguments: [false, true])
    func shapeAndBackgroundFillsReachInspectorAndExport(alternative: Bool) async throws {
        let context = try AppStateTestContext()
        defer { context.remove() }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("LabFillExport-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let model = LibraryLabModel()
        model.options = .init(alternative: alternative)
        await model.run([.fillsAndLines], in: root).value
        let result = try #require(model.results[.fillsAndLines])
        #expect(result.passed && model.failures.isEmpty && result.slideCount == 10)
        #expect(result.checks.contains { $0.name == "Selected image fills export exact bytes" && $0.passed })
        let source = try Data(contentsOf: result.afterURL), deck = try Presentation(data: source)
        let images = deck.package.parts.values.filter { $0.contentType.hasPrefix("image/") }
        try #require(images.count == 1)
        #expect(images[0].blob.count == 84)
        await context.app.inspect(deckAt: result.afterURL).value
        let inspection = try #require(context.app.inspection)
        #expect(context.app.phase == .inspected && inspection.previews.count == 10)
        for page in 1...10 {
            let position = try #require(inspection.previewSlideNumbers.firstIndex(of: page))
            let saved = try String(contentsOf: result.directory.appendingPathComponent(String(format: "previews/slide-%02d.svg", page)), encoding: .utf8)
            #expect(saved == inspection.previews[position])
        }
        let task = try #require(context.app.exportInspected(into: root.appendingPathComponent("Export")))
        await task.value
        #expect(context.app.exportProblem == nil)
        #expect(context.app.exportSummary == "10 slides · 3 media files · 0 chart CSVs")
        let directory = try #require(context.app.exportedDirectory)
        let markdown = try String(contentsOf: directory.appendingPathComponent("fillsAndLines.md"), encoding: .utf8)
        for page in [1, 9, 10] {
            let folder = directory.appendingPathComponent(String(format: "slide-%02d", page))
            #expect(try FileManager.default.contentsOfDirectory(atPath: folder.path) == ["image1.png"])
            #expect(try Data(contentsOf: folder.appendingPathComponent("image1.png")) == images[0].blob)
            #expect(markdown.contains(String(format: "slide-%02d/image1.png", page)))
        }
        let folders = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isDirectoryKey])
            .filter { try $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true }
        #expect(Set(folders.map(\.lastPathComponent)) == ["slide-01", "slide-09", "slide-10"])
        #expect(try Data(contentsOf: result.afterURL) == source)
        #expect(try deck.serializedData() == source)
    }
}
