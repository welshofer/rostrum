import Foundation
import Testing
@testable import Rostrum

@Suite struct ShapeEffectPreviewTests {
    private static let namespaces = "xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\" xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\""

    private func render(effects: String, custom: String? = nil, text: String = "") throws -> (svg: String, issues: [FidelityIssue]) {
        let deck = try Presentation()
        let geometry = custom ?? "<a:prstGeom prst=\"rect\"><a:avLst/></a:prstGeom>"
        let body = text.isEmpty ? "" : "<p:txBody><a:bodyPr lIns=\"0\" tIns=\"0\" rIns=\"0\" bIns=\"0\"/><a:p><a:r><a:t>\(text)</a:t></a:r></a:p></p:txBody>"
        let xml = """
        <p:sp \(Self.namespaces)><p:nvSpPr><p:cNvPr id="10" name="Box"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
        <p:spPr><a:xfrm><a:off x="914400" y="914400"/><a:ext cx="1828800" cy="914400"/></a:xfrm>
        \(geometry)<a:solidFill><a:srgbClr val="FF0000"/></a:solidFill>\(effects)</p:spPr>\(body)</p:sp>
        """
        let part = try deck.slides[0].part
        try #require(Slide.existingSpTree(of: part)).appendElement(try XML.parse(Data(xml.utf8)))
        part.markDirty()
        let saved = try deck.serializedData()
        let result = try deck.renderSVGReportingProblems(slideAt: 0)
        #expect(try deck.serializedData() == saved)
        return (result.svg, result.problems.fidelityIssues)
    }

    @Test func glowSoftEdgeAndInnerShadowBecomeFiltersAndOneApproximation() throws {
        let result = try render(effects: """
            <a:effectLst><a:glow rad="63500"><a:srgbClr val="00B0F0"><a:alpha val="40000"/></a:srgbClr></a:glow>\
            <a:innerShdw blurRad="63500" dist="50800" dir="13500000"><a:srgbClr val="000000"><a:alpha val="50000"/></a:srgbClr></a:innerShdw>\
            <a:softEdge rad="31750"/></a:effectLst>
            """)
        #expect(result.svg.contains("operator=\"dilate\" radius=\"31750.0\""))
        #expect(result.svg.contains("flood-color=\"#00B0F0\" flood-opacity=\"0.4\""))
        #expect(result.svg.contains("operator=\"erode\" radius=\"15875.0\""))
        #expect(result.svg.contains("tableValues=\"1 0\""))
        let effects = result.issues.filter { $0.code == .omittedEffect }
        #expect(effects.count == 1)
        #expect(effects.first?.impact == .approximation)
        #expect(effects.first?.message == "Shape effects (soft edge, inner shadow, glow) are approximated with SVG filters.")
    }

    @Test func outerShadowAloneKeepsItsMessage() throws {
        let result = try render(effects: "<a:effectLst><a:outerShdw blurRad=\"40000\" dist=\"20000\"><a:srgbClr val=\"000000\"/></a:outerShdw></a:effectLst>")
        #expect(result.issues.filter { $0.code == .omittedEffect }.map(\.message)
            == ["Shape outer shadow is approximated with an SVG Gaussian blur."])
    }

    @Test func undrawnEffectKeepsTheListAnOmission() throws {
        let result = try render(effects: "<a:effectLst><a:glow rad=\"63500\"><a:srgbClr val=\"00B0F0\"/></a:glow><a:reflection blurRad=\"6350\" stA=\"50000\"/></a:effectLst>")
        #expect(result.svg.contains("operator=\"dilate\""))   // the glow is still drawn
        #expect(result.issues.contains { $0.code == .omittedEffect && $0.impact == .omission })
    }

    @Test func zeroRadiusGlowIsNotCountedAsRendered() throws {
        let result = try render(effects: "<a:effectLst><a:glow rad=\"0\"><a:srgbClr val=\"00B0F0\"/></a:glow></a:effectLst>")
        #expect(!result.svg.contains("<filter"))
        #expect(result.issues.contains { $0.code == .omittedEffect && $0.impact == .omission })
    }

    @Test func customGeometryTextUsesItsResolvedTextRectangle() throws {
        let custom = """
            <a:custGeom><a:avLst/><a:gdLst><a:gd name="inset" fmla="*/ w 1 4"/><a:gd name="right" fmla="+- r 0 inset"/></a:gdLst>\
            <a:rect l="inset" t="t" r="right" b="b"/>\
            <a:pathLst><a:path><a:moveTo><a:pt x="l" y="t"/></a:moveTo><a:lnTo><a:pt x="r" y="t"/></a:lnTo>\
            <a:lnTo><a:pt x="r" y="b"/></a:lnTo><a:lnTo><a:pt x="l" y="b"/></a:lnTo><a:close/></a:path></a:pathLst></a:custGeom>
            """
        let inset = try render(effects: "", custom: custom, text: "Label")
        #expect(!inset.issues.contains { $0.message.contains("text rectangle is not resolved") })
        // Left-aligned text starts a quarter of the 1828800-EMU width in.
        #expect(inset.svg.contains("translate(1371600,"))

        let broken = try render(effects: "", custom: custom.replacingOccurrences(of: "*/ w 1 4", with: "*/ w 1 0"), text: "Label")
        #expect(broken.issues.contains { $0.message.contains("text rectangle is not resolved") })
    }
}
