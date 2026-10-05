import Foundation
import Testing
import LecternCore
import Rostrum
@testable import Lectern

@Suite @MainActor struct LibraryTableJoinProfilesAppTests {
    @Test(arguments: [false, true])
    func nativeTableJoinProfilesReachInspectorAndExport(alternative: Bool) async throws {
        let context = try AppStateTestContext()
        defer { context.remove() }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("LabTableJoinProfiles-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let model = LibraryLabModel()
        model.options = .init(alternative: alternative)
        await model.run([.tableJoinProfiles], in: root).value
        let result = try #require(model.results[.tableJoinProfiles])
        #expect(result.passed && model.failures.isEmpty && model.completed == 1)
        #expect(result.slideCount == 3 && result.findings.isEmpty)
        for prefix in ["Native profile vectors:", "Saved Native profile vectors:", "Native profile glyphs:", "Saved Native profile glyphs:"] {
            #expect(result.checks.filter { $0.name.hasPrefix(prefix) && $0.passed }.count == 8)
        }
        #expect(result.checks.contains { $0.name == "Public join controls applied" && $0.passed })
        #expect(result.checks.contains { $0.name == "Join specimens and inheritance survive" && $0.passed })
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
        let control = try #require((deck.slides[2].shapes.first { $0.name == "Public merge control" } as? TableFrame)?.table)
        let merges = try control.mergedRegions
        #expect(merges.count == 1 && merges[0].rowSpan == (alternative ? 2 : 1) && merges[0].columnSpan == (alternative ? 1 : 2))
        let task = try #require(context.app.exportInspected(into: root.appendingPathComponent("Export")))
        await task.value
        #expect(context.app.exportProblem == nil)
        #expect(context.app.exportSummary == "3 slides · 0 media files · 0 chart CSVs")
        let directory = try #require(context.app.exportedDirectory)
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        let markdownURL = try #require(files.first { $0.pathExtension == "md" })
        let markdown = try String(contentsOf: markdownURL, encoding: .utf8)
        #expect(markdown.contains("Table join profiles") && markdown.contains("Agjp"))
        #expect(markdown.contains(alternative ? "vertical merge" : "horizontal merge"))
        let reference = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: result.directory.appendingPathComponent("native-table-join-profiles-reference.json"))) as? [String: Any])
        let cases = try #require(reference["cases"] as? [[String: Any]])
        #expect(cases.count == 8)
        for sample in cases { #expect(markdown.contains(try #require(sample["id"] as? String))) }
        #expect(try deck.serializedData() == bytes)
        #expect(try Data(contentsOf: result.afterURL) == bytes)
        context.app.goHome()
        #expect(model.results[.tableJoinProfiles]?.directory == result.directory)
    }
}
