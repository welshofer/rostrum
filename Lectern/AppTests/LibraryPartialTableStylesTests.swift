import Foundation
import Testing
import LecternCore
import Rostrum
@testable import Lectern

@Suite @MainActor struct LibraryPartialTableStylesAppTests {
    @Test(arguments: [false, true])
    func nativePartialTableStylesReachInspectorAndExport(alternative: Bool) async throws {
        let context = try AppStateTestContext()
        defer { context.remove() }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("LabPartialTableStyles-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let model = LibraryLabModel()
        model.options = .init(alternative: alternative)
        await model.run([.partialTableStyles], in: root).value
        let result = try #require(model.results[.partialTableStyles])
        #expect(result.passed && model.failures.isEmpty && model.completed == 1)
        #expect(result.slideCount == 3 && result.findings.isEmpty)
        for prefix in ["Native partial-style paint:", "Saved Native partial-style paint:", "Native partial-style glyphs:", "Saved Native partial-style glyphs:"] {
            #expect(result.checks.filter { $0.name.hasPrefix(prefix) && $0.passed }.count == 12)
        }
        #expect(result.checks.contains { $0.name == "Public partial-style controls applied" && $0.passed })
        #expect(result.checks.contains { $0.name == "Partial-style specimens and inheritance survive" && $0.passed })
        let bytes = try Data(contentsOf: result.afterURL)
        let beforeURL = try #require(result.beforeURL)
        await context.app.inspect(deckAt: beforeURL).value
        #expect(context.app.phase == .inspected && context.app.inspection?.previews.count == 2)
        await context.app.inspect(deckAt: result.afterURL).value
        let inspection = try #require(context.app.inspection)
        #expect(context.app.phase == .inspected && inspection.previews.count == 3)
        #expect(inspection.previewDiagnostics.flatMap(\.issues).isEmpty)
        let deck = try Presentation(data: bytes)
        #expect(deck.registerEmbeddedFonts() == ["DejaVu Sans"])
        #expect(deck.slides.count == 3 && deck.slideSize.width == .points(720))
        for page in 0..<3 {
            let position = try #require(inspection.previewSlideNumbers.firstIndex(of: page + 1))
            let raw = try deck.renderSVG(slideAt: page, pixelWidth: 640)
            #expect(inspection.previews[position] == raw, "Independent same-profile table SVG \(page + 1)")
            let saved = try String(contentsOf: result.directory.appendingPathComponent(String(format: "previews/slide-%02d.svg", page + 1)), encoding: .utf8)
            #expect(inspection.previews[position] == saved, "Exact actual saved inspector table SVG \(page + 1)")
        }
        let control = try #require((deck.slides[2].shapes.first { $0.name == "Public partial-style control 3" } as? TableFrame)?.table)
        let cell = try control.cell(0, 0)
        #expect((cell.border(.left) == nil) == alternative)
        #expect(cell.border(.right)?.isNone == true)
        #expect(try TableStyleResolver(table: control, theme: deck.theme).border(.left, row: 0, column: 0)?.width == .points(alternative ? 1 : 4))
        let task = try #require(context.app.exportInspected(into: root.appendingPathComponent("Export")))
        await task.value
        #expect(context.app.exportProblem == nil)
        #expect(context.app.exportSummary == "3 slides · 0 media files · 0 chart CSVs")
        let directory = try #require(context.app.exportedDirectory)
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        let markdownURL = try #require(files.first { $0.pathExtension == "md" })
        let markdown = try String(contentsOf: markdownURL, encoding: .utf8)
        #expect(markdown.contains("Partial table styles") && markdown.contains("Agjp"))
        #expect(markdown.contains(alternative ? "Direct left override cleared" : "Direct blue 4 pt left override"))
        let reference = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: result.directory.appendingPathComponent("native-partial-table-styles-reference.json"))) as? [String: Any])
        let cases = try #require(reference["cases"] as? [[String: Any]])
        #expect(cases.count == 12)
        for sample in cases { #expect(markdown.contains(try #require(sample["id"] as? String))) }
        #expect(try deck.serializedData() == bytes)
        #expect(try Data(contentsOf: result.afterURL) == bytes)
        context.app.goHome()
        #expect(model.results[.partialTableStyles]?.directory == result.directory)
    }
}
