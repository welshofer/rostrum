import Foundation
import Testing
@testable import Rostrum

@Suite struct SVGStyleGeometryTests {
    private func add(_ preset: String, to deck: Presentation, properties: String = "", adjustments: String = "", text: String = "", style: String = "") throws {
        let xml = """
        <p:sp><p:nvSpPr><p:cNvPr id="22" name="Fixture"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
        <p:spPr><a:xfrm><a:off x="100" y="200"/><a:ext cx="4000000" cy="2000000"/></a:xfrm>
        <a:prstGeom prst="\(preset)"><a:avLst>\(adjustments)</a:avLst></a:prstGeom>\(properties)</p:spPr>\(style)\(text)</p:sp>
        """
        let part = try deck.slides[0].part
        try #require(Slide.existingSpTree(of: part)).appendElement(XML.parse(Data(xml.utf8)))
        part.markDirty()
    }

    @Test func commonPresetsRenderDistinctOutlinesAndPreserveTheDeck() throws {
        let deck = try Presentation()
        for preset in SVGPresetGeometry.supported.sorted() {
            try add(preset, to: deck, properties: "<a:solidFill><a:srgbClr val=\"4472C4\"/></a:solidFill>")
        }
        let before = try deck.serializedData()
        let result = try deck.renderSVGReportingProblems(slideAt: 0)
        #expect(result.problems.isEmpty)
        #expect(result.svg.components(separatedBy: "<polygon ").count - 1 == 10)
        #expect(result.svg.contains("<ellipse "))
        // Diamond vertices: top, right, bottom, left, in the source frame.
        #expect(result.svg.contains("2000100.0,200.0 4000100.0,1000200.0 2000100.0,2000200.0 100.0,1000200.0"))
        #expect(try deck.serializedData() == before)
        _ = try XML.parse(Data(result.svg.utf8))
    }

    @Test func literalAdjustmentsChangeTheOutlineAndStayBounded() throws {
        let deck = try Presentation()
        try add("triangle", to: deck, properties: "<a:solidFill><a:srgbClr val=\"AA0000\"/></a:solidFill>",
                adjustments: "<a:gd name=\"adj\" fmla=\"val 25000\"/>")
        try add("roundRect", to: deck, properties: "<a:solidFill><a:srgbClr val=\"AA0000\"/></a:solidFill>",
                adjustments: "<a:gd name=\"adj\" fmla=\"val 999999999\"/>")
        let result = try deck.renderSVGReportingProblems(slideAt: 0)
        #expect(result.svg.contains("100.0,2000200.0 1000100.0,200.0 4000100.0,2000200.0"))
        #expect(result.svg.contains("rx=\"1000000.0\""))
        #expect(result.problems.isEmpty)
    }

    @Test func unsupportedAdjustmentFormulasProduceExplicitFallbackWarning() throws {
        let deck = try Presentation()
        try add("chevron", to: deck, properties: "<a:solidFill><a:srgbClr val=\"AA0000\"/></a:solidFill>",
                adjustments: "<a:gd name=\"adj\" fmla=\"*/ w 1 2\"/>")
        let result = try deck.renderSVGReportingProblems(slideAt: 0)
        #expect(result.problems.messages.contains { $0.contains("guide formulas") })
        #expect(result.svg.contains("<polygon"))
    }

    @Test func presetTextRegionsKeepLabelsInsideNotchesAndSlopedEdges() {
        let diamond = SVGPresetGeometry.textFrame("diamond", adjustments: nil, frame: (100,200,4000,2000))
        #expect(diamond.0 == 1100 && diamond.1 == 700 && diamond.2 == 2000 && diamond.3 == 1000)
        let arrow = SVGPresetGeometry.textFrame("rightArrow", adjustments: nil, frame: (0,0,4000,2000))
        #expect(arrow.0 == 0 && arrow.1 == 500 && arrow.2 == 3500 && arrow.3 == 1000)
        for preset in SVGPresetGeometry.supported {
            let box = SVGPresetGeometry.textFrame(preset, adjustments: nil, frame: (0,0,4000,2000))
            #expect(box.0 >= 0 && box.1 >= 0 && box.2 >= 0 && box.3 >= 0)
            #expect(box.0 + box.2 <= 4000 && box.1 + box.3 <= 2000)
        }
    }

    private let style = """
    <p:style><a:lnRef idx="1"><a:schemeClr val="accent2"/></a:lnRef>
    <a:fillRef idx="1"><a:schemeClr val="accent1"/></a:fillRef>
    <a:fontRef idx="minor"><a:schemeClr val="lt1"/></a:fontRef></p:style>
    """
    private let text = """
    <p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:pPr><a:defRPr sz="2400"/></a:pPr>
    <a:r><a:t>Theme text</a:t></a:r></a:p></p:txBody>
    """

    @Test func themeStylesSupplyFillOutlineFontAndTextColorWithoutMutation() throws {
        let deck = try Presentation()
        try add("diamond", to: deck, text: text, style: style)
        let before = try deck.serializedData()
        let svg = try deck.renderSVG(slideAt: 0)
        #expect(svg.contains("fill=\"#4472C4\""))
        #expect(svg.contains("stroke=\"#ED7D31\""))
        #expect(svg.contains("font-family=\"Calibri, sans-serif\""))
        #expect(svg.contains("font-size=\"24\""))
        #expect(svg.contains("fill=\"#FFFFFF\""))
        #expect(try deck.serializedData() == before)
    }

    @Test func directFormattingOverridesStyleButInheritsOtherLineProperties() throws {
        let deck = try Presentation()
        try add("diamond", to: deck, properties: "<a:noFill/><a:ln w=\"60000\"/>",
                text: text.replacingOccurrences(of: "<a:r><a:t>", with: "<a:r><a:rPr sz=\"1200\"><a:solidFill><a:srgbClr val=\"123456\"/></a:solidFill><a:latin typeface=\"Georgia\"/></a:rPr><a:t>"), style: style)
        let svg = try deck.renderSVG(slideAt: 0)
        #expect(svg.contains("fill=\"none\" stroke=\"#ED7D31\" stroke-width=\"60000\""))
        #expect(!svg.contains("fill=\"#4472C4\""))
        #expect(svg.contains("font-family=\"Georgia, sans-serif\""))
        #expect(svg.contains("font-size=\"12\""))
        #expect(svg.contains("fill=\"#123456\""))
    }

    @Test func disabledAndInvalidMatrixReferencesDoNotInventPaint() throws {
        for index in ["0", "1000", "-1", "999999999999999999999999999"] {
            let deck = try Presentation()
            try add("rect", to: deck, style: style.replacingOccurrences(of: "idx=\"1\"", with: "idx=\"\(index)\""))
            let svg = try deck.renderSVG(slideAt: 0)
            #expect(!svg.contains("#4472C4") && !svg.contains("#ED7D31"))
        }
    }
}
