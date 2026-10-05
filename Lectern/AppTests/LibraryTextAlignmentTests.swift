import Foundation
import Testing
import LecternCore
import Rostrum
@testable import Lectern

@Suite @MainActor struct LibraryTextAlignmentAppTests {
    @Test(arguments: [false, true])
    func nativeAlignmentDemoReachesInspectorAndExport(alternative: Bool) async throws {
        let context = try AppStateTestContext()
        defer { context.remove() }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("LabAlignment-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let model = LibraryLabModel()
        model.options = .init(alternative: alternative)
        await model.run([.textAlignment], in: root).value
        let result = try #require(model.results[.textAlignment])
        #expect(result.passed && model.failures.isEmpty && model.completed == 1)
        #expect(result.slideCount == 5)
        #expect(result.checks.filter { $0.name.hasPrefix("Native text alignment:") && $0.passed }.count == 24)
        #expect(result.checks.filter { $0.name.hasPrefix("Saved Native text alignment:") && $0.passed }.count == 24)
        #expect(result.checks.contains { $0.name == "Alignment bodies and inheritance survive" && $0.passed })
        #expect(result.checks.contains { $0.name == "Alignment public fits agree" && $0.passed })
        #expect(result.findings.count == 2)
        #expect(result.findings.allSatisfy { $0.message.contains("fontScale") })
        let beforeURL = try #require(result.beforeURL)
        await context.app.inspect(deckAt: beforeURL).value
        #expect(context.app.phase == .inspected && context.app.inspection?.previews.count == 4)
        await context.app.inspect(deckAt: result.afterURL).value
        let inspection = try #require(context.app.inspection)
        #expect(context.app.phase == .inspected && inspection.previews.count == 5)
        let issues = inspection.previewDiagnostics.flatMap(\.issues)
        #expect(issues.count == 2 && issues.allSatisfy { $0.message.contains("Native table cells ignore stored fontScale") })
        let bytes = try Data(contentsOf: result.afterURL)
        let deck = try Presentation(data: bytes)
        #expect(Set(deck.registerEmbeddedFonts()) == ["DejaVu Sans", "DejaVu Serif"])
        #expect(deck.slides.count == 5 && deck.slideSize.width == .points(720))
        for page in 0..<5 {
            let position = try #require(inspection.previewSlideNumbers.firstIndex(of: page + 1))
            // Inspector previews use 640 px; the raw library default is 1280.
            // Native pages have exact embedded faces. On the authored fifth
            // page only three childless border-rectangle text nodes can use
            // the inspector's different fallback metrics; no paint is removed.
            let expectedSVG = try deck.renderSVG(slideAt: page, pixelWidth: 640)
            let actualSVG = inspection.previews[position]
            if page < 4 {
                let matchesIndependentRender = actualSVG == expectedSVG
                #expect(matchesIndependentRender, "Alignment preview page \(page + 1), alternative=\(alternative)")
            } else {
                try Self.compareAuthoredPreview(actual: actualSVG, independent: expectedSVG)
            }
            let savedURL = result.directory.appendingPathComponent(
                String(format: "previews/slide-%02d.svg", page + 1))
            let savedSVG = try String(contentsOf: savedURL, encoding: .utf8)
            let matchesSavedPreview = actualSVG == savedSVG
            #expect(matchesSavedPreview, "Saved alignment preview page \(page + 1), alternative=\(alternative)")
        }
        let task = try #require(context.app.exportInspected(into: root.appendingPathComponent("Export")))
        await task.value
        #expect(context.app.exportProblem == nil)
        #expect(context.app.exportSummary == "5 slides · 0 media files · 0 chart CSVs")
        let directory = try #require(context.app.exportedDirectory)
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        let markdownURL = try #require(files.first { $0.pathExtension == "md" })
        let markdown = try String(contentsOf: markdownURL, encoding: .utf8)
        #expect(markdown.contains("Text alignment:"))
        #expect(markdown.contains("Shape.fitText") && markdown.contains("TextFrame.fitText"))
        #expect(markdown.contains(alternative ? "Text alignment: right" : "Text alignment: center"))
        #expect(markdown.contains("Agjp") && markdown.contains("AVATAR ToTo") && markdown.contains("BBBBBBBBBBBBZ"))
        let referenceURL = result.directory.appendingPathComponent("native-alignment-reference.json")
        let reference = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: referenceURL)) as? [String: Any])
        let nativeCases = try #require(reference["cases"] as? [[String: Any]])
        #expect(nativeCases.count == 24)
        for sample in nativeCases {
            #expect(markdown.contains(try #require(sample["id"] as? String)))
        }
        #expect(try deck.serializedData() == bytes)
        context.app.goHome()
        #expect(model.results[.textAlignment]?.directory == result.directory)
    }

    private static func compareAuthoredPreview(actual: String, independent: String) throws {
        let actualRoot = try XML.parse(Data(actual.utf8))
        let independentRoot = try XML.parse(Data(independent.utf8))
        func emptyText(_ node: XML.Element) -> [XML.Element] {
            (node.name == "text" && node.children.isEmpty ? [node] : []) + node.childElements.flatMap(emptyText)
        }
        let actualEmpty = emptyText(actualRoot), independentEmpty = emptyText(independentRoot)
        try #require(actualEmpty.count == 3 && independentEmpty.count == 3)
        let borderX = [35.0, 260, 485].map { $0 * Double(EMU.perPoint) }
        for (index, pair) in zip(actualEmpty, independentEmpty).enumerated() {
            let (a, b) = pair
            #expect(a.children.isEmpty && b.children.isEmpty && a.textContent.isEmpty && b.textContent.isEmpty)
            let actualTransform = try #require(a[attribute: "transform"])
            let rawTransform = try #require(b[attribute: "transform"])
            // These exact three empty border nodes differ only in the
            // fallback font's baseline: installed Arial in the inspector
            // versus the raw fontless default, a 1 pt shift without paint.
            let rawExpected = "translate(\(Int(borderX[index])),3512820) scale(12700)"
            let actualExpected = "translate(\(Int(borderX[index])),3500120) scale(12700)"
            #expect(rawTransform == rawExpected && actualTransform == actualExpected)
            a[attribute: "transform"] = nil; b[attribute: "transform"] = nil
            #expect(a.serialized() == b.serialized())
        }
        // Keep every node and all non-baseline attributes. Normalizing only
        // the verified empty transforms leaves the remaining XML exact.
        #expect(actualRoot.serialized() == independentRoot.serialized())
    }
}
