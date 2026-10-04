import Foundation
import Testing
import Rostrum
@testable import LecternCore

@Suite struct ParagraphBoundaryRecipeTests {
    @Test(arguments: [false, true])
    func nativeBoundariesSurvivePublicFittingAndReopening(narrow: Bool) throws {
        let draft = try PlatformLabRecipes.make(.paragraphLayout, options: .init(text: "Native line boundary", sampleSize: 2, alternative: narrow))
        #expect(draft.deck.slides.count == 6)
        let references = try PlatformLabRecipes.paragraphBoundaryReferences()
        let samples = references.cases.filter { $0.narrow == narrow }
        #expect(samples.count == 2)
        for sample in samples {
            let original = try PlatformLabRecipes.paragraphGeometry(draft.deck, named: sample.id + " original", slideAt: 2)
            // Independent PowerPoint PDF: dejavu-18-1/-2 and dejavu-mixed-size-1/-2.
            let firstLineCount = sample.id.hasPrefix("dejavu-18-") ? (narrow ? 11 : 12) : (narrow ? 7 : 8)
            let nativeLines = [String(repeating: "m", count: firstLineCount), narrow ? "mZ" : "Z"]
            #expect(PlatformLabRecipes.boundaryLineStrings(original) == nativeLines)
            #expect(sample.nativeLines == nativeLines)
            let fitted = try PlatformLabRecipes.paragraphGeometry(draft.deck, named: sample.id + " shape fit", slideAt: 2)
            let fittedFrame = try PlatformLabRecipes.paragraphGeometry(draft.deck, named: sample.id + " frame fit", slideAt: 2)
            #expect(fitted.lines.count == 1 && fitted.fits && fitted.diagnostics.isEmpty)
            #expect(fitted.lines == fittedFrame.lines)
            #expect(fitted.lines.allSatisfy { $0.visibleWidth <= sample.widthPoints })
            #expect(fitted.contentHeight <= 22)
            #expect(PlatformLabRecipes.boundaryLineStrings(fitted).joined() == sample.runs.map(\.text).joined())
            let recoveredSizes = Set(original.lines.flatMap(\.spans).map(\.run.fontSize))
            #expect(recoveredSizes == Set(sample.runs.map(\.size)))
            let fittedBody = try PlatformLabRecipes.paragraphBody(draft.deck, named: sample.id + " shape fit", slideAt: 2)
            let norm = try #require(fittedBody.firstChild(named: "a:bodyPr")?.firstChild(named: "a:normAutofit"))
            let scale = try #require(Double(norm[attribute: "fontScale"] ?? ""))
            #expect(scale > 0 && scale < 100_000)
            #expect(Set(fitted.lines.flatMap(\.spans).map(\.run.fontSize)) == Set(sample.runs.map { $0.size * (scale / 100_000) }))
        }
        let metrics = try #require(draft.deck.fonts.metrics(for: "DejaVu Sans"))
        // This is the observed counterexample: raw advance exceeds the wider box,
        // but native line placement fits all twelve m characters on its first line.
        #expect(metrics.width(of: String(repeating: "m", count: 12), pointSize: 18) > 210.01)
        let data = try draft.deck.serializedData()
        let reopened = try Presentation(data: data)
        for check in draft.checks + (try draft.verify(reopened)) { #expect(check.passed, "\(check.name): \(check.detail)") }
        #expect(try reopened.serializedData() == data)
        #expect(draft.extraFiles["native-boundary-reference.json"] != nil)
        if let parent = ProcessInfo.processInfo.environment["LECTERN_PARAGRAPH_ARTIFACTS"] {
            let directory = URL(fileURLWithPath: parent).appendingPathComponent("narrow-\(narrow)-" + UUID().uuidString)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: directory.appendingPathComponent("paragraphLayout.pptx"))
        }
    }

    @Test func nativeReferenceKeepsSourceAndFontProvenance() throws {
        let reference = try PlatformLabRecipes.paragraphBoundaryReferences()
        #expect(reference.source.hasSuffix("LineBreakBoundaries/line-break-boundaries.pptx"))
        #expect(reference.nativePDF.hasSuffix("LineBreakBoundaries/powerpoint.pdf"))
        #expect(reference.sourceSHA256 == "515853d753943019db5245b08c8e5cdce70aebe86750b50439db1ca2a4d7c5d1")
        #expect(reference.nativePDFSHA256 == "c617e5f539cd053d5b3c22394a19aa369399ee63040bf76d764d4293df531096")
        #expect(reference.font == "DejaVuSans.ttf" && reference.fontSHA256.count == 64)
        #expect(reference.scope.contains("computed, not native autofit-choice"))
        #expect(Set(reference.cases.map(\.id)) == ["dejavu-18-1", "dejavu-18-2", "dejavu-mixed-size-1", "dejavu-mixed-size-2"])
        #expect(reference.cases.filter(\.narrow).map(\.widthPoints) == [209.99, 108.99])
        #expect(reference.cases.filter { !$0.narrow }.map(\.widthPoints) == [210.01, 109.01])
    }
}
