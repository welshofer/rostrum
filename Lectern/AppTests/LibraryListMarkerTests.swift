import Foundation
import Testing
import LecternCore
import Rostrum
@testable import Lectern

@Suite @MainActor struct LibraryListMarkerAppTests {
    @Test(arguments: [false, true])
    func nativeMarkerDemoReachesInspectorAndExport(alternative: Bool) async throws {
        let context = try AppStateTestContext()
        defer { context.remove() }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("LabMarkers-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let model = LibraryLabModel()
        model.options = .init(alternative: alternative)
        await model.run([.listMarkers], in: root).value
        let result = try #require(model.results[.listMarkers])
        #expect(result.passed && model.failures.isEmpty && model.completed == 1)
        #expect(result.slideCount == 5 && result.findings.isEmpty)
        #expect(result.checks.filter { $0.name.hasPrefix("Native list marker:") && $0.passed }.count == 24)
        #expect(result.checks.filter { $0.name.hasPrefix("Saved Native list marker:") && $0.passed }.count == 24)
        #expect(result.checks.contains { $0.name == "Marker bodies and inheritance survive" && $0.passed })
        #expect(result.checks.contains { $0.name == "Marker public fits agree" && $0.passed })
        let beforeURL = try #require(result.beforeURL)
        await context.app.inspect(deckAt: beforeURL).value
        #expect(context.app.phase == .inspected && context.app.inspection?.previews.count == 3)
        await context.app.inspect(deckAt: result.afterURL).value
        let inspection = try #require(context.app.inspection)
        #expect(context.app.phase == .inspected && inspection.previews.count == 5)
        let bytes = try Data(contentsOf: result.afterURL)
        let deck = try Presentation(data: bytes)
        #expect(Set(deck.registerEmbeddedFonts()) == ["DejaVu Sans", "DejaVu Serif"])
        #expect(deck.slides.count == 5 && deck.slideSize.width == .points(720))
        for page in 0..<5 {
            let position = try #require(inspection.previewSlideNumbers.firstIndex(of: page + 1))
            // Inspector previews use 640 px; the raw library default is 1280.
            // All painted faces in this fixture are embedded, so installed-font
            // registration must leave this independent render unchanged.
            let expectedSVG = try deck.renderSVG(slideAt: page, pixelWidth: 640)
            let actualSVG = inspection.previews[position]
            let matchesIndependentRender = actualSVG == expectedSVG
            #expect(matchesIndependentRender, "Marker preview page \(page + 1), alternative=\(alternative)")
            let savedURL = result.directory.appendingPathComponent(
                String(format: "previews/slide-%02d.svg", page + 1))
            let savedSVG = try String(contentsOf: savedURL, encoding: .utf8)
            let matchesSavedPreview = actualSVG == savedSVG
            #expect(matchesSavedPreview, "Saved marker preview page \(page + 1), alternative=\(alternative)")
        }
        let task = try #require(context.app.exportInspected(into: root.appendingPathComponent("Export")))
        await task.value
        #expect(context.app.exportProblem == nil)
        #expect(context.app.exportSummary == "5 slides · 0 media files · 0 chart CSVs")
        let directory = try #require(context.app.exportedDirectory)
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        let markdownURL = try #require(files.first { $0.pathExtension == "md" })
        let markdown = try String(contentsOf: markdownURL, encoding: .utf8)
        #expect(markdown.contains("List markers and hanging indents"))
        #expect(markdown.contains("Shape.fitText") && markdown.contains("TextFrame.fitText"))
        #expect(markdown.contains(alternative ? "Source: wide-number-hang6" : "Source: wide-number-hang18"))
        #expect(FileManager.default.fileExists(atPath: result.directory.appendingPathComponent("native-marker-reference.json").path))
        #expect(try deck.serializedData() == bytes)
        context.app.goHome()
        #expect(model.results[.listMarkers]?.directory == result.directory)
    }
}
