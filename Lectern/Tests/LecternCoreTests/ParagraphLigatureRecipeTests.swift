import Foundation
import Testing
import Rostrum
@testable import LecternCore

@Suite struct ParagraphLigatureRecipeTests {
    @Test(arguments: [false, true])
    func nativeCommonWordsSurviveBothFitsAndSaving(narrow: Bool) throws {
        let draft = try PlatformLabRecipes.make(.paragraphLayout, options: .init(text: "Native Latin words", sampleSize: 2, alternative: narrow))
        #expect(draft.deck.slides.count == 5)
        let reference = try PlatformLabRecipes.paragraphLigatureReferences()
        let samples = reference.cases.filter { $0.id == "mixed-size-edge" || $0.narrow == narrow }
        #expect(samples.count == 2)
        for sample in samples {
            let expected = sample.id == "office-edge-below" ? ["offic", "eZ"] : ["office", "Z"]
            #expect(sample.nativeLines == expected)
            let original = try PlatformLabRecipes.paragraphGeometry(draft.deck, named: sample.id + " original", slideAt: 3)
            #expect(PlatformLabRecipes.boundaryLineStrings(original) == expected)
            #expect(original.fits && original.diagnostics.isEmpty)
            let shape = try PlatformLabRecipes.paragraphGeometry(draft.deck, named: sample.id + " shape fit", slideAt: 3)
            let frame = try PlatformLabRecipes.paragraphGeometry(draft.deck, named: sample.id + " frame fit", slideAt: 3)
            #expect(shape.lines == frame.lines && shape.lines.count == 1)
            #expect(shape.fits && shape.diagnostics.isEmpty && shape.contentHeight <= 22)
            #expect(shape.lines.allSatisfy { $0.visibleWidth <= sample.widthPoints })
            #expect(PlatformLabRecipes.boundaryLineStrings(shape) == ["officeZ"])
            #expect(Set(original.lines.flatMap(\.spans).map(\.run.fontSize)) == Set(sample.runs.map(\.size)))
            #expect(try PlatformLabRecipes.ligaturePropertiesMatch(draft.deck, sample: sample, role: "original", fit: nil))
            let body = try PlatformLabRecipes.paragraphBody(draft.deck, named: sample.id + " shape fit", slideAt: 3)
            let norm = try #require(body.firstChild(named: "a:bodyPr")?.firstChild(named: "a:normAutofit"))
            let scale = try #require(Double(norm[attribute: "fontScale"] ?? ""))
            #expect(scale > 0 && scale < 100_000)
            #expect(Set(shape.lines.flatMap(\.spans).map(\.run.fontSize)) == Set(sample.runs.map { $0.size * (scale / 100_000) }))
        }
        let svg = try draft.deck.renderSVG(slideAt: 3)
        #expect(svg.contains("style=\"font-feature-settings: 'liga' 0\""))
        let bytes = try draft.deck.serializedData()
        let reopened = try Presentation(data: bytes)
        for check in draft.checks + (try draft.verify(reopened)) { #expect(check.passed, "\(check.name): \(check.detail)") }
        #expect(try reopened.serializedData() == bytes)
        #expect(draft.extraFiles["native-ligature-reference.json"] != nil)
        if let parent = ProcessInfo.processInfo.environment["LECTERN_LIGATURE_ARTIFACTS"] {
            let directory = URL(fileURLWithPath: parent).appendingPathComponent("narrow-\(narrow)-" + UUID().uuidString)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try bytes.write(to: directory.appendingPathComponent("paragraphLayout.pptx"))
        }
    }

    @Test func nativeCommonWordReferenceRetainsNamedEvidence() throws {
        let reference = try PlatformLabRecipes.paragraphLigatureReferences()
        #expect(reference.source.hasSuffix("NativeLigatureLayout/native-ligatures-regular-table.pptx"))
        #expect(reference.nativePDF.hasSuffix("NativeLigatureLayout/powerpoint-regular-table.pdf"))
        #expect(reference.sourceSHA256 == "3c4c668ad517fefe310e674402482f4ecef3e1c72a00ff50a80eaf8d9c138ab5")
        #expect(reference.nativePDFSHA256 == "a26eeeabada4a6e580b6cd32cc40bd580e7935d291b9344b126c3e5a49785722")
        #expect(reference.fontSHA256 == "7da195a74c55bef988d0d48f9508bd5d849425c1770dba5d7bfc6ce9ed848954")
        #expect(reference.kerningEquivalenceSource?.hasSuffix("NativeLigatureLayout/harfbuzz-controls.json") == true)
        #expect(reference.kerningEquivalenceSHA256 == "83337d80310287844ec8ae12c87c7477375453839bd2e438f6c1bdf7ba2b632a")
        #expect(reference.cases.map(\.id) == ["office-edge-below", "office-edge-above", "mixed-size-edge"])
        #expect(reference.cases.map(\.widthPoints) == [49.74, 49.76, 39.01])
        #expect(reference.cases.last?.runs.map(\.text) == ["of", "ficeZ"])
        #expect(reference.cases.last?.runs.map(\.size) == [18, 12])
    }
}
