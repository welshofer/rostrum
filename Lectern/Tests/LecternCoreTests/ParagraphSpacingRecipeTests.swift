import Foundation
import Testing
import Rostrum
@testable import LecternCore

@Suite struct ParagraphSpacingRecipeTests {
    @Test(arguments: [false, true])
    func nativeSpacingAndAnchorsSurviveSaving(alternative: Bool) throws {
        let draft = try PlatformLabRecipes.make(.paragraphLayout,
            options: .init(text: "Native line spacing", sampleSize: 2, alternative: alternative))
        #expect(draft.deck.slides.count == 6)
        let reference = try PlatformLabRecipes.paragraphSpacingReferences()
        let samples = reference.cases.filter { $0.alternative == alternative }
        #expect(samples.count == 6)
        for sample in samples {
            let layout = try PlatformLabRecipes.paragraphGeometry(draft.deck, named: sample.id + " spacing", slideAt: 5)
            #expect(PlatformLabRecipes.spacingMarkersMatch(layout, sample: sample), "\(sample.id): \(layout.lines.map(\.baseline))")
            #expect(layout.fits && layout.diagnostics.isEmpty)
            #expect(try PlatformLabRecipes.spacingPropertiesMatch(draft.deck, sample: sample))
        }
        let bytes = try draft.deck.serializedData()
        let reopened = try Presentation(data: bytes)
        for check in draft.checks + (try draft.verify(reopened)) {
            #expect(check.passed, "\(check.name): \(check.detail)")
        }
        #expect(try reopened.serializedData() == bytes)
        #expect(try reopened.renderSVGReportingProblems(slideAt: 5).problems.isEmpty)
        #expect(draft.extraFiles["native-spacing-reference.json"] != nil)
        if let parent = ProcessInfo.processInfo.environment["LECTERN_SPACING_ARTIFACTS"] {
            let directory = URL(fileURLWithPath: parent).appendingPathComponent("alternative-\(alternative)-" + UUID().uuidString)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try bytes.write(to: directory.appendingPathComponent("paragraphLayout.pptx"))
        }
    }

    @Test func independentSpacingReferencesRetainOriginalProperties() throws {
        let reference = try PlatformLabRecipes.paragraphSpacingReferences()
        #expect(reference.cases.map(\.id) == ["exact14p4-three-compat1", "pct150-18-four-compat1", "pct150-18-four-compat0",
                                             "exact48p75-single30-b", "pct70-size18-ctr", "pct70-size18-b",
                                             "exact18-18-scale75-reduction20", "pct150-18-reduction10", "pct150-18-scale75-reduction20",
                                             "exact18-18-scale100-reduction20-b", "pct150-18-scale75-reduction20-ctr", "pct150-18-scale75-reduction20-b"])
        let expected = [[11.0, 25, 39], [24, 57, 89, 122], [24, 55, 86, 118], [153], [83.12], [155.36],
                        [14, 32, 50], [23, 53, 83], [16, 38, 60], [119.92, 137.92, 155.92],
                        [64.32, 86.16, 108.24], [112.56, 134.64, 156.48]]
        for (index, sample) in reference.cases.enumerated() {
            #expect(sample.widthPoints == 290 && sample.heightPoints == 160)
            #expect(sample.source.hasPrefix("Tests/RostrumTests/Fixtures/NativeLineSpacing/"))
            #expect(sample.sourceSHA256.count == 64 && sample.nativePDFSHA256.count == 64)
            #expect(sample.nativePDF.hasSuffix("/powerpoint.pdf"))
            #expect(sample.fontSHA256 == "7da195a74c55bef988d0d48f9508bd5d849425c1770dba5d7bfc6ce9ed848954")
            #expect(sample.nativeMarkers.count == expected[index].count)
            #expect(zip(sample.nativeMarkers, expected[index]).allSatisfy { abs($0.baseline - $1) <= 0.121 })
            let body = try XML.parse(Data(sample.textBodyXML.utf8))
            let properties = try #require(body.firstChild(named: "a:bodyPr"))
            #expect(["lIns", "rIns", "tIns", "bIns"].allSatisfy { properties[attribute: $0] == "0" })
            #expect(properties[attribute: "anchor"] == ([0, 1, 2, 6, 7, 8].contains(index) ? "t" : [4, 10].contains(index) ? "ctr" : "b"))
            let spacing = try #require(body.firstChild(named: "a:p")?.firstChild(named: "a:pPr")?.firstChild(named: "a:lnSpc"))
            #expect(spacing.firstChild(named: [0, 3, 6, 9].contains(index) ? "a:spcPts" : "a:spcPct") != nil)
        }
    }
}
