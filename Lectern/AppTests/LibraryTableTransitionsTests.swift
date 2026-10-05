import Foundation
import Testing
import LecternCore
import Rostrum
@testable import Lectern

@Suite @MainActor struct LibraryTableTransitionsAppTests {
    @Test(arguments: [false, true])
    func nativeTableTransitionsReachInspectorAndExport(alternative: Bool) async throws {
        let context = try AppStateTestContext()
        defer { context.remove() }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("LabTableTransitions-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let model = LibraryLabModel()
        model.options = .init(alternative: alternative)
        await model.run([.tableTransitions], in: root).value
        let result = try #require(model.results[.tableTransitions])
        #expect(result.passed && model.failures.isEmpty && model.completed == 1)
        #expect(result.slideCount == 5 && result.findings.isEmpty)
        for prefix in ["Native transition glyphs:", "Saved Native transition glyphs:"] {
            #expect(result.checks.filter { $0.name.hasPrefix(prefix) && $0.passed }.count == 14)
        }
        #expect(result.checks.contains { $0.name == "Public transition option changes edge paint" && $0.passed })
        #expect(result.checks.contains { $0.name == "Transition specimens and inheritance survive" && $0.passed })
        let bytes = try Data(contentsOf: result.afterURL)
        let beforeURL = try #require(result.beforeURL)
        await context.app.inspect(deckAt: beforeURL).value
        #expect(context.app.phase == .inspected && context.app.inspection?.previews.count == 2)
        await context.app.inspect(deckAt: result.afterURL).value
        let inspection = try #require(context.app.inspection)
        #expect(context.app.phase == .inspected && inspection.previews.count == 5)
        #expect(inspection.previewDiagnostics.flatMap(\.issues).isEmpty)
        let deck = try Presentation(data: bytes)
        #expect(deck.registerEmbeddedFonts() == ["DejaVu Sans"])
        #expect(deck.slides.count == 5 && deck.slideSize.width == .points(720))
        for page in 0..<5 {
            let position = try #require(inspection.previewSlideNumbers.firstIndex(of: page + 1))
            let raw = try deck.renderSVG(slideAt: page, pixelWidth: 640)
            #expect(inspection.previews[position] == raw, "Independent same-profile table SVG \(page + 1)")
            let saved = try String(contentsOf: result.directory.appendingPathComponent(String(format: "previews/slide-%02d.svg", page + 1)), encoding: .utf8)
            #expect(inspection.previews[position] == saved, "Exact actual saved inspector table SVG \(page + 1)")
        }
        #expect(result.checks.filter { $0.name.hasPrefix("Native transition paint:") && $0.passed }.count == 13)
        #expect(result.checks.contains { $0.name.hasPrefix("Excluded merged fallback:") && $0.passed })
        let control = try #require((deck.slides[4].shapes.first { $0.name == "Public transition control" } as? TableFrame)?.table)
        #expect(try control.cell(0, 0).border(.left)?.isNone == alternative)
        let task = try #require(context.app.exportInspected(into: root.appendingPathComponent("Export")))
        await task.value
        #expect(context.app.exportProblem == nil)
        #expect(context.app.exportSummary == "5 slides · 0 media files · 0 chart CSVs")
        let directory = try #require(context.app.exportedDirectory)
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        let markdownURL = try #require(files.first { $0.pathExtension == "md" })
        let markdown = try String(contentsOf: markdownURL, encoding: .utf8)
        #expect(markdown.contains("Border transitions") && markdown.contains("Agjp"))
        #expect(markdown.contains(alternative ? "Upper left donor suppressed" : "All donors present"))
        let reference = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: result.directory.appendingPathComponent("native-table-transitions-reference.json"))) as? [String: Any])
        let cases = try #require(reference["cases"] as? [[String: Any]])
        #expect(cases.count == 14)
        for sample in cases { #expect(markdown.contains(try #require(sample["id"] as? String))) }
        #expect(try deck.serializedData() == bytes)
        #expect(try Data(contentsOf: result.afterURL) == bytes)
        context.app.goHome()
        #expect(model.results[.tableTransitions]?.directory == result.directory)
    }
}
