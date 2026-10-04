import Foundation
import Testing
import Rostrum
@testable import LecternCore

@Suite struct ParagraphBreakRecipeTests {
    @Test(arguments: [false, true])
    func nativeEmptyLinesSurviveBothFitsAndSaving(large: Bool) throws {
        let draft = try PlatformLabRecipes.make(.paragraphLayout, options: .init(text: "Styled empty lines", sampleSize: 2, alternative: large))
        #expect(draft.deck.slides.count == 5)
        let samples = try PlatformLabRecipes.paragraphBreakReferences().cases.filter { $0.large == large }
        #expect(samples.count == 2)
        for sample in samples {
            let original = try PlatformLabRecipes.paragraphGeometry(draft.deck, named: sample.id + " original", slideAt: 4)
            let shape = try PlatformLabRecipes.paragraphGeometry(draft.deck, named: sample.id + " shape fit", slideAt: 4)
            let frame = try PlatformLabRecipes.paragraphGeometry(draft.deck, named: sample.id + " frame fit", slideAt: 4)
            let expected = sample.id.hasPrefix("consecutive") ? ["A", "", "B"] : ["A", "", "Z"]
            #expect(PlatformLabRecipes.boundaryLineStrings(original) == expected)
            #expect(PlatformLabRecipes.breakMarkersMatch(original, sample: sample))
            #expect(original.lines.last?.baseline == (large ? 69 : 33))
            #expect(original.lines[1].height == (large ? 36.0 : 6.0) * 1.2)
            #expect(original.fits && original.diagnostics.isEmpty)
            #expect(shape.lines == frame.lines && shape.lines.count == 3)
            #expect(PlatformLabRecipes.boundaryLineStrings(shape) == expected)
            #expect(shape.fits && shape.diagnostics.isEmpty && shape.contentHeight <= 28)
            #expect(try PlatformLabRecipes.breakPropertiesMatch(draft.deck, sample: sample, role: "original", fit: nil))
            let originalBody = try PlatformLabRecipes.paragraphBody(draft.deck, named: sample.id + " original", slideAt: 4)
            let sourceParagraphs = originalBody.children(named: "a:p").map { $0.serialized() }
            for role in ["shape fit", "frame fit"] {
                let body = try PlatformLabRecipes.paragraphBody(draft.deck, named: sample.id + " " + role, slideAt: 4)
                #expect(body.children(named: "a:p").map { $0.serialized() } == sourceParagraphs)
                let norm = try #require(body.firstChild(named: "a:bodyPr")?.firstChild(named: "a:normAutofit"))
                let scale = try #require(Double(norm[attribute: "fontScale"] ?? ""))
                #expect(scale >= 25_000 && scale < 100_000)
            }
        }
        let bytes = try draft.deck.serializedData()
        let reopened = try Presentation(data: bytes)
        for check in draft.checks + (try draft.verify(reopened)) { #expect(check.passed, "\(check.name): \(check.detail)") }
        #expect(try reopened.serializedData() == bytes)
        #expect(draft.extraFiles["native-break-reference.json"] != nil)
        if let parent = ProcessInfo.processInfo.environment["LECTERN_BREAK_ARTIFACTS"] {
            let directory = URL(fileURLWithPath: parent).appendingPathComponent("large-\(large)-" + UUID().uuidString)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try bytes.write(to: directory.appendingPathComponent("paragraphLayout.pptx"))
        }
    }

    @Test func nativeBreakReferenceRetainsIndependentEvidenceAndProperties() throws {
        let reference = try PlatformLabRecipes.paragraphBreakReferences()
        #expect(reference.source.hasSuffix("NativeBreakMetrics/native-break-metrics-v1.pptx"))
        #expect(reference.nativePDF.hasSuffix("NativeBreakMetrics/powerpoint.pdf"))
        #expect(reference.sourceSHA256 == "3620121ad15fe85abb65e28cb686d454a0fad7b160cfdab7933543960ba087fe")
        #expect(reference.nativePDFSHA256 == "aa98866ab87866e985a7444790ec538b7b050abb5fba08885e9cd2f50e4c0c60")
        #expect(reference.fontSHA256 == "7da195a74c55bef988d0d48f9508bd5d849425c1770dba5d7bfc6ce9ed848954")
        #expect(reference.cases.map(\.id) == ["consecutive-36-6", "trailing-br36-end6", "consecutive-6-36", "trailing-br36-end36"])
        for sample in reference.cases {
            let body = try XML.parse(Data(sample.textBodyXML.utf8))
            let paragraphs = body.children(named: "a:p")
            let breaks = try #require(paragraphs.first).children(named: "a:br")
            let size = sample.large ? "3600" : "600"
            if sample.id.hasPrefix("consecutive") {
                #expect(breaks.count == 2)
                #expect(breaks.last?.firstChild(named: "a:rPr")?[attribute: "sz"] == size)
            } else {
                #expect(breaks.count == 1 && paragraphs.count == 2)
                #expect(paragraphs.first?.firstChild(named: "a:endParaRPr")?[attribute: "sz"] == size)
            }
            #expect(paragraphs.flatMap { $0.children(named: "a:r") }.allSatisfy {
                $0.firstChild(named: "a:rPr")?[attribute: "sz"] == "1200"
            })
        }
    }
}
