import Foundation
import Testing
@testable import Rostrum

@Suite struct SVGStyleFidelityTests {
    private func shape(_ deck: Presentation, properties: String = "", style: String = "", text: String = "<a:p><a:r><a:t>Inherited font</a:t></a:r></a:p>", placeholder: String = "") throws {
        let part = try deck.slides[0].part
        let xml = """
        <p:sp><p:nvSpPr><p:cNvPr id="77" name="Test"/><p:cNvSpPr/><p:nvPr>\(placeholder)</p:nvPr></p:nvSpPr>
        <p:spPr><a:xfrm><a:off x="1000000" y="1000000"/><a:ext cx="4000000" cy="2000000"/></a:xfrm>
        <a:prstGeom prst="rect"/><a:solidFill><a:srgbClr val="FF0000"/></a:solidFill>\(properties)</p:spPr>
        \(style)<p:txBody><a:bodyPr/><a:lstStyle/>\(text)</p:txBody></p:sp>
        """
        try #require(Slide.existingSpTree(of: part)).appendElement(XML.parse(Data(xml.utf8)))
        part.markDirty()
    }

    private func paint(_ transforms: String, base: String = "FF0000") throws -> SVGPaint {
        let deck = try Presentation()
        let element = try XML.parse(Data("<a:solidFill><a:srgbClr val=\"\(base)\">\(transforms)</a:srgbClr></a:solidFill>".utf8))
        return try #require(SVGPaint.resolve(in: element, theme: deck.theme))
    }

    @Test func luminanceUsesHSLRatherThanScalingRGBChannels() throws {
        #expect(try paint("<a:lumMod val=\"150000\"/>").color == Color("FF8080"))
        #expect(try paint("<a:lumOff val=\"25000\"/>").color == Color("FF8080"))
        #expect(try paint("<a:lumMod val=\"50000\"/>", base: "FF8080").color == Color("C00000"))
        let deck = try Presentation()
        deck.theme.setAccent(1, Color("FF0000"))
        #expect(deck.theme.resolve(.accent1, transforms: [.lumMod(1.5)]) == Color("FF8080"))
    }

    @Test func hueSaturationAndChannelTransformsRespectOrderAndClamp() throws {
        #expect(try paint("<a:hueOff val=\"7200000\"/>").color == Color("00FF00"))
        #expect(try paint("<a:comp/>").color == Color("00FFFF"))
        #expect(try paint("<a:inv/>").color == Color("00FFFF"))
        #expect(try paint("<a:sat val=\"0\"/>").color == Color("808080"))
        #expect(try paint("<a:redMod val=\"50000\"/><a:greenOff val=\"50000\"/><a:blue val=\"100000\"/>").color == Color("8080FF"))
        #expect(try paint("<a:redOff val=\"2147483647\"/><a:greenMod val=\"2147483647\"/>").color == Color("FF0000"))
        #expect(try paint("<a:invGamma/><a:gamma/>", base: "427AB9").color == Color("427AB9"))
    }

    @Test func ordinaryTextUsesMasterOtherStyleWithoutRegisteredMetrics() throws {
        let deck = try Presentation()
        deck.theme.minorFont = "Arial"
        try shape(deck)
        let before = try deck.serializedData()
        let svg = try deck.renderSVG(slideAt: 0)
        #expect(svg.contains("font-family=\"Arial, sans-serif\""))
        #expect(try deck.serializedData() == before)
        #expect(try Presentation(data: before).renderSVG(slideAt: 0) == svg)
    }

    @Test func paragraphLevelsAndPartialLayoutOverridesKeepInheritedFont() throws {
        let deck = try Presentation()
        let slide = try deck.slides[0]
        let master = try #require(slide.master)
        let styles = XML.Element("p:txStyles")
        try master.part.dom().appendElement(styles)
        styles.removeChildren(named: "p:bodyStyle")
        styles.appendElement(try XML.parse(Data("""
        <p:bodyStyle><a:lvl1pPr><a:defRPr sz="2400"><a:latin typeface="Georgia"/></a:defRPr></a:lvl1pPr>
        <a:lvl2pPr><a:defRPr sz="1600"><a:latin typeface="Arial"/></a:defRPr></a:lvl2pPr></p:bodyStyle>
        """.utf8)))
        master.part.markDirty()
        let layout = try #require(slide.layout)
        let layoutShape = try XML.parse(Data("""
        <p:sp><p:nvSpPr><p:cNvPr id="999" name="Body"/><p:cNvSpPr/><p:nvPr><p:ph type="body" idx="999"/></p:nvPr></p:nvSpPr>
        <p:spPr/><p:txBody><a:bodyPr/><a:lstStyle><a:lvl2pPr><a:defRPr b="1"/></a:lvl2pPr></a:lstStyle><a:p/></p:txBody></p:sp>
        """.utf8))
        try #require(Slide.existingSpTree(of: layout.part)).appendElement(layoutShape)
        layout.part.markDirty()
        try shape(deck, text: "<a:p><a:pPr lvl=\"1\"/><a:r><a:t>Level two</a:t></a:r></a:p>", placeholder: "<p:ph type=\"body\" idx=\"999\"/>")
        let svg = try deck.renderSVG(slideAt: 0)
        #expect(svg.contains("font-family=\"Arial, sans-serif\""))
        #expect(svg.contains("font-size=\"16\""))
        #expect(svg.contains("font-weight=\"bold\""))
    }

    @Test func localDefaultParagraphRunPropertiesOverrideInheritedStyles() throws {
        let deck = try Presentation()
        try shape(deck)
        let part = try deck.slides[0].part
        let sp = try #require(Slide.existingSpTree(of: part)?.children(named: "p:sp").last)
        let list = try #require(sp.firstChild(named: "p:txBody")?.firstChild(named: "a:lstStyle"))
        list.appendElement(try XML.parse(Data("<a:defPPr><a:defRPr sz=\"3200\"><a:latin typeface=\"Georgia\"/></a:defRPr></a:defPPr>".utf8)))
        part.markDirty()
        let svg = try deck.renderSVG(slideAt: 0)
        #expect(svg.contains("font-family=\"Georgia, sans-serif\""))
        #expect(svg.contains("font-size=\"32\""))
    }

    @Test func shapeFontReferenceOverridesGlobalDefaultsButNotLocalFormatting() throws {
        let deck = try Presentation()
        let master = try #require(try deck.slides[0].master)
        try master.part.dom().appendElement(XML.parse(Data("""
        <p:txStyles><p:otherStyle><a:lvl1pPr><a:defRPr><a:solidFill><a:srgbClr val="000000"/></a:solidFill>
        <a:latin typeface="Georgia"/></a:defRPr></a:lvl1pPr></p:otherStyle></p:txStyles>
        """.utf8)))
        master.part.markDirty()
        let style = "<p:style><a:fontRef idx=\"minor\"><a:schemeClr val=\"lt1\"/></a:fontRef></p:style>"
        try shape(deck, style: style)
        var svg = try deck.renderSVG(slideAt: 0)
        #expect(svg.contains("fill=\"#FFFFFF\""))
        #expect(svg.contains("font-family=\"Calibri, sans-serif\""))
        let part = try deck.slides[0].part
        let sp = try #require(Slide.existingSpTree(of: part)?.children(named: "p:sp").last)
        let run = try #require(sp.firstChild(named: "p:txBody")?.firstChild(named: "a:p")?.firstChild(named: "a:r"))
        run.appendElement(try XML.parse(Data("<a:rPr><a:solidFill><a:srgbClr val=\"112233\"/></a:solidFill><a:latin typeface=\"Arial\"/></a:rPr>".utf8)))
        part.markDirty()
        svg = try deck.renderSVG(slideAt: 0)
        #expect(svg.contains("fill=\"#112233\""))
        #expect(svg.contains("font-family=\"Arial, sans-serif\""))
    }

    private let shadow = """
    <a:outerShdw blurRad="40000" dist="20000" dir="5400000"><a:srgbClr val="112233"><a:alpha val="38000"/></a:srgbClr></a:outerShdw>
    """

    @Test func directShadowHasBlurOffsetColorAndUnclippedFilterBounds() throws {
        let deck = try Presentation()
        try shape(deck, properties: "<a:effectLst>\(shadow)</a:effectLst>")
        let before = try deck.serializedData()
        let svg = try deck.renderSVG(slideAt: 0)
        #expect(svg.contains("stdDeviation=\"20000.0\""))
        #expect(svg.contains("dx=\"0.0\" dy=\"20000.0\""))
        #expect(svg.contains("flood-color=\"#112233\" flood-opacity=\"0.38\""))
        #expect(svg.contains("filterUnits=\"userSpaceOnUse\""))
        #expect(svg.contains("filter=\"url(#shadow0)\""))
        // Source content is outside the bounded shadow filter so overflow is visible.
        #expect(svg.contains("</text></g><rect"))
        #expect(!svg.contains("feMergeNode"))
        #expect(try deck.serializedData() == before)
        _ = try XML.parse(Data(svg.utf8))
    }

    private func themeShadow(_ deck: Presentation) throws {
        let format = try #require(try deck.theme.part.dom().firstChild(named: "a:themeElements")?.firstChild(named: "a:fmtScheme"))
        format.removeChildren(named: "a:effectStyleLst")
        format.appendElement(try XML.parse(Data("<a:effectStyleLst><a:effectStyle><a:effectLst>\(shadow)</a:effectLst></a:effectStyle></a:effectStyleLst>".utf8)))
        deck.theme.part.markDirty()
    }

    @Test func explicitEmptyEffectsSuppressThemeShadow() throws {
        let deck = try Presentation()
        let style = "<p:style><a:effectRef idx=\"1\"><a:schemeClr val=\"accent1\"/></a:effectRef></p:style>"
        try themeShadow(deck)
        try shape(deck, style: style)
        #expect(try deck.renderSVG(slideAt: 0).contains("<filter "))
        let second = try Presentation()
        try themeShadow(second)
        try shape(second, properties: "<a:effectLst/>", style: style)
        #expect(try !second.renderSVG(slideAt: 0).contains("<filter "))
    }

    @Test func unsupportedShadowGeometryIsDiagnosedAndMalformedNumbersStayFinite() throws {
        let deck = try Presentation()
        try shape(deck, properties: "<a:effectLst>\(shadow.replacingOccurrences(of: "blurRad=", with: "sx=\"50000\" blurRad="))</a:effectLst>")
        let result = try deck.renderSVGReportingProblems(slideAt: 0)
        #expect(result.problems.messages.contains { $0.contains("scaled or skewed") })
        let bad = try Presentation()
        try shape(bad, properties: "<a:effectLst>\(shadow.replacingOccurrences(of: "40000", with: "999999999999999999999999"))</a:effectLst>")
        let svg = try bad.renderSVG(slideAt: 0)
        #expect(!svg.contains("nan") && !svg.contains("inf"))
        _ = try XML.parse(Data(svg.utf8))
    }
}
