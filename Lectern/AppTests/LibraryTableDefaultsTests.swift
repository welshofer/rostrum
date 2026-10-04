import Foundation
import Testing
import LecternCore
import Rostrum
@testable import Lectern

@Suite @MainActor struct LibraryTableDefaultsAppTests {
    @Test(arguments: [false, true])
    func nativeTableDefaultsReachInspectorAndExport(alternative: Bool) async throws {
        let context = try AppStateTestContext()
        defer { context.remove() }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("LabTableDefaults-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let model = LibraryLabModel()
        model.options = .init(alternative: alternative)
        await model.run([.tableDefaults], in: root).value
        let result = try #require(model.results[.tableDefaults])
        #expect(result.passed && model.failures.isEmpty && model.completed == 1)
        #expect(result.slideCount == 4 && result.findings.isEmpty)
        for prefix in ["Native table vectors:", "Saved Native table vectors:", "Native table glyphs:", "Saved Native table glyphs:"] {
            #expect(result.checks.filter { $0.name.hasPrefix(prefix) && $0.passed }.count == 12)
        }
        #expect(result.checks.contains { $0.name == "Import keeps absent style with different destination default" && $0.passed })
        #expect(result.checks.contains { $0.name == "Public style changes actual paint" && $0.passed })
        #expect(result.checks.contains { $0.name == "Table specimens and inheritance survive" && $0.passed })
        let bytes = try Data(contentsOf: result.afterURL)
        let beforeURL = try #require(result.beforeURL)
        await context.app.inspect(deckAt: beforeURL).value
        #expect(context.app.phase == .inspected && context.app.inspection?.previews.count == 1)
        await context.app.inspect(deckAt: result.afterURL).value
        let inspection = try #require(context.app.inspection)
        #expect(context.app.phase == .inspected && inspection.previews.count == 4)
        #expect(inspection.previewDiagnostics.flatMap(\.issues).isEmpty)
        let deck = try Presentation(data: bytes)
        #expect(deck.registerEmbeddedFonts() == ["DejaVu Sans"])
        #expect(deck.slides.count == 4 && deck.slideSize.width == .points(720))
        for page in 0..<4 {
            let position = try #require(inspection.previewSlideNumbers.firstIndex(of: page + 1))
            let raw = try deck.renderSVG(slideAt: page, pixelWidth: 640)
            #expect(inspection.previews[position] == raw, "Independent same-profile table SVG \(page + 1)")
            let saved = try String(contentsOf: result.directory.appendingPathComponent(String(format: "previews/slide-%02d.svg", page + 1)), encoding: .utf8)
            #expect(inspection.previews[position] == saved, "Exact actual saved inspector table SVG \(page + 1)")
        }
        let imported = try #require((deck.slides[1].shapes.first { $0.name == "custom-absent" } as? TableFrame)?.table)
        #expect(imported.styleID == nil)
        let control = try #require((deck.slides[3].shapes.first { $0.name == "Public style control" } as? TableFrame)?.table)
        #expect((control.styleID == nil) == alternative)
        let task = try #require(context.app.exportInspected(into: root.appendingPathComponent("Export")))
        await task.value
        #expect(context.app.exportProblem == nil)
        #expect(context.app.exportSummary == "4 slides · 0 media files · 0 chart CSVs")
        let directory = try #require(context.app.exportedDirectory)
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        let markdownURL = try #require(files.first { $0.pathExtension == "md" })
        let markdown = try String(contentsOf: markdownURL, encoding: .utf8)
        #expect(markdown.contains("Table defaults and border joins") && markdown.contains("Agjp"))
        #expect(markdown.contains(alternative ? "applied style cleared" : "custom style explicitly applied"))
        let reference = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: result.directory.appendingPathComponent("native-table-defaults-reference.json"))) as? [String: Any])
        let cases = try #require(reference["cases"] as? [[String: Any]])
        #expect(cases.count == 12)
        for sample in cases { #expect(markdown.contains(try #require(sample["id"] as? String))) }
        #expect(try deck.serializedData() == bytes)
        #expect(try Data(contentsOf: result.afterURL) == bytes)
        context.app.goHome()
        #expect(model.results[.tableDefaults]?.directory == result.directory)
    }
}
