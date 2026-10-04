import Foundation
import Testing
import LecternCore
import Rostrum
@testable import Lectern

@Suite @MainActor struct LibraryMixedFaceSpacingAppTests {
    @Test(arguments: [false, true])
    func nativeMixedFaceSpacingDemoReachesInspectorAndExport(alternative: Bool) async throws {
        let context = try AppStateTestContext()
        defer { context.remove() }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("LabMixedSpacing-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let model = LibraryLabModel()
        model.options = .init(alternative: alternative)
        await model.run([.mixedFaceSpacing], in: root).value
        let result = try #require(model.results[.mixedFaceSpacing])
        #expect(result.passed && model.failures.isEmpty && model.completed == 1)
        #expect(result.slideCount == 3)
        #expect(result.checks.filter { $0.name.hasPrefix("Native mixed-face spacing:") && $0.passed }.count == 12)
        #expect(result.checks.filter { $0.name.hasPrefix("Saved Native mixed-face spacing:") && $0.passed }.count == 12)
        #expect(result.checks.contains { $0.name == "Mixed spacing specimens and inheritance survive" && $0.passed })
        #expect(result.checks.contains { $0.name == "Mixed spacing public fits agree" && $0.passed })
        #expect(result.findings.isEmpty)
        let beforeURL = try #require(result.beforeURL)
        await context.app.inspect(deckAt: beforeURL).value
        #expect(context.app.phase == .inspected && context.app.inspection?.previews.count == 1)
        await context.app.inspect(deckAt: result.afterURL).value
        let inspection = try #require(context.app.inspection)
        #expect(context.app.phase == .inspected && inspection.previews.count == 3)
        let issues = inspection.previewDiagnostics.flatMap(\.issues)
        #expect(issues.isEmpty)
        let bytes = try Data(contentsOf: result.afterURL)
        let deck = try Presentation(data: bytes)
        #expect(Set(deck.registerEmbeddedFonts()) == ["DejaVu Sans", "DejaVu Serif"])
        #expect(deck.slides.count == 3 && deck.slideSize.width == .points(720))
        for page in 0..<3 {
            let position = try #require(inspection.previewSlideNumbers.firstIndex(of: page + 1))
            // Same 640 px profile, exact embedded faces and no empty
            // decorative text nodes: retain full independent SVG identity.
            let expectedSVG = try deck.renderSVG(slideAt: page, pixelWidth: 640)
            let actualSVG = inspection.previews[position]
            #expect(actualSVG == expectedSVG, "Mixed spacing preview page \(page + 1), alternative=\(alternative)")
            let savedURL = result.directory.appendingPathComponent(
                String(format: "previews/slide-%02d.svg", page + 1))
            let savedSVG = try String(contentsOf: savedURL, encoding: .utf8)
            let matchesSavedPreview = actualSVG == savedSVG
            #expect(matchesSavedPreview, "Saved mixed spacing preview page \(page + 1), alternative=\(alternative)")
        }
        let task = try #require(context.app.exportInspected(into: root.appendingPathComponent("Export")))
        await task.value
        #expect(context.app.exportProblem == nil)
        #expect(context.app.exportSummary == "3 slides · 0 media files · 0 chart CSVs")
        let directory = try #require(context.app.exportedDirectory)
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        let markdownURL = try #require(files.first { $0.pathExtension == "md" })
        let markdown = try String(contentsOf: markdownURL, encoding: .utf8)
        #expect(markdown.contains("Mixed faces, exact line spacing"))
        #expect(markdown.contains("Shape.fitText") && markdown.contains("TextFrame.fitText"))
        #expect(markdown.contains(alternative ? "Computed comparison: bottom anchored" : "Computed comparison: top anchored"))
        #expect(markdown.contains("Agjp") && markdown.contains("Content extent: 37.334899 pt"))
        let referenceURL = result.directory.appendingPathComponent("native-mixed-spacing-reference.json")
        let reference = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: referenceURL)) as? [String: Any])
        let nativeCases = try #require(reference["cases"] as? [[String: Any]])
        #expect(nativeCases.count == 12)
        for sample in nativeCases {
            #expect(markdown.contains(try #require(sample["id"] as? String)))
        }
        #expect(try deck.serializedData() == bytes)
        context.app.goHome()
        #expect(model.results[.mixedFaceSpacing]?.directory == result.directory)
    }

}
