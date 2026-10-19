import Foundation
import Testing
import Rostrum
@testable import LecternCore

@Suite struct PreviewFindingGroupTests {
    @Test func repeatedNotesAreGroupedSeparatelyWithoutDroppingRawDiagnostics() {
        let location = FidelityLocation(slideIndex: 0, partURI: "/ppt/slides/slide1.xml", path: "/")
        let note = FidelityIssue(code: .unverifiedTextLayout, impact: .approximation, location: location, message: "Native spacing is not verified")
        let missing = FidelityIssue(code: .missingGlyph, impact: .missingResource, location: location, message: "Missing checkmark")
        var records: [SlidePreviewRecord] = [], diagnostics: [SlidePreviewDiagnostics] = []
        for number in [1, 2, 3, 7] {
            var problems = SlideRenderProblems()
            problems.fidelityIssues = number == 7 ? [note, missing] : [note]
            let diagnostic = SlidePreviewDiagnostics(slideNumber: number, problems: problems)
            records.append(.init(number: number, title: "", svg: "<svg/>", warnings: diagnostic.messages))
            diagnostics.append(diagnostic)
        }
        let grouped = PreviewFindingGroup.collect(records: records, diagnostics: diagnostics)
        #expect(grouped.count == 2)
        #expect(grouped[0].slideLabel == "Slides 1–3, 7")
        #expect(grouped[0].isVerificationNote)
        #expect(grouped[1].slideLabel == "Slide 7")
        #expect(!grouped[1].isVerificationNote)
        #expect(records.flatMap(\.warnings).count == 5)
        #expect(diagnostics.flatMap(\.issues).count == 5)
        #expect(PreviewFindingGroup.collect(records: records, diagnostics: []).allSatisfy { !$0.isVerificationNote })
    }

    @Test func symbolSubstitutionsReadAsOneSentence() {
        let warnings = [
            "Preview symbol U+2192 uses registered Apple Symbols because Georgia has no glyph. The document font is unchanged.",
            "Preview symbol U+2717 uses registered Zapf Dingbats because Georgia has no glyph. The document font is unchanged.",
            "OS/2 embedding restrictions prevent embedding Zapf Dingbats in SVG.",
            "OS/2 embedding restrictions prevent embedding Brand Sans in SVG.",
        ]
        #expect(PreviewFindingGroup.combiningSymbolSubstitutions(warnings) == [
            "\u{2192} (U+2192) is drawn with Apple Symbols because Georgia lacks it.",
            "\u{2717} (U+2717) is drawn with the installed Zapf Dingbats because Georgia lacks it.",
            "OS/2 embedding restrictions prevent embedding Brand Sans in SVG.",
        ])
    }
}
