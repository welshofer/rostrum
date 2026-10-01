import Foundation
import Testing
@testable import Rostrum

@Suite struct BackgroundAccuracyTests {
    private func background(_ slide: Slide, _ xml: String) throws {
        let c = try slide.cSld(); c.removeChildren(named: "p:bg")
        c.children.insert(.element(try XML.parse(Data(xml.utf8))), at: 0)
        slide.part.markDirty()
    }
    @Test func colorTransformsAffectPublicAndRenderedColors() throws {
        let p = try Presentation(); let slide = try p.slides[0]
        try background(slide, "<p:bg><p:bgPr><a:solidFill><a:srgbClr val=\"808080\"><a:shade val=\"50000\"/></a:srgbClr></a:solidFill></p:bgPr></p:bg>")
        #expect(slide.solidBackground == Color("404040"))
        #expect(slide.effectiveBackgroundColor == Color("404040"))
        #expect(try p.renderSVG(slideAt: 0).contains("fill=\"#404040\""))
        try background(slide, "<p:bg><p:bgPr><a:solidFill><a:schemeClr val=\"accent1\"/></a:solidFill></p:bgPr></p:bg>")
        #expect(slide.solidBackground == p.theme.resolve(.accent1))
    }
    @Test func nearestColorMapAndExplicitMasterReset() throws {
        let p = try Presentation(); let slide = try p.slides[0]
        p.theme.setColor(.accent1, Color("112233")); p.theme.setColor(.accent2, Color("AABBCC"))
        let layout = slide.inheritanceParts[1]
        try slide.part.dom().removeChildren(named: "p:clrMapOvr")
        try layout.dom().removeChildren(named: "p:clrMapOvr")
        let map = XML.Element("p:clrMapOvr")
        map.appendElement(XML.Element("a:overrideClrMapping", attributes: [("accent1", "accent2")]))
        try layout.dom().appendElement(map)
        try background(slide, "<p:bg><p:bgPr><a:solidFill><a:schemeClr val=\"accent1\"/></a:solidFill></p:bgPr></p:bg>")
        #expect(slide.effectiveBackgroundColor == Color("AABBCC"))
        let own = XML.Element("p:clrMapOvr"); own.appendElement(XML.Element("a:masterClrMapping"))
        try slide.part.dom().removeChildren(named: "p:clrMapOvr")
        try slide.part.dom().appendElement(own)
        #expect(slide.effectiveBackgroundColor == Color("112233"))
    }
    @Test func referenceIndexSelectsActualPaint() throws {
        let p = try Presentation(); let slide = try p.slides[0]
        for index in [0, 1000, 9999] {
            try background(slide, "<p:bg><p:bgRef idx=\"\(index)\"><a:srgbClr val=\"FF0000\"/></p:bgRef></p:bg>")
            #expect(slide.effectiveBackground == .none)
        }
        let matrix = try #require(p.theme.part.dom().firstChild(named: "a:themeElements")?.firstChild(named: "a:fmtScheme"))
        let list = matrix.getOrAddChild("a:bgFillStyleLst")
        list.children = [.element(try XML.parse(Data("<a:gradFill><a:gsLst><a:gs pos=\"0\"><a:schemeClr val=\"phClr\"><a:shade val=\"50000\"/></a:schemeClr></a:gs><a:gs pos=\"100000\"><a:srgbClr val=\"FFFFFF\"/></a:gs></a:gsLst><a:lin ang=\"0\"/></a:gradFill>".utf8)))]
        try background(slide, "<p:bg><p:bgRef idx=\"1001\"><a:srgbClr val=\"808080\"/></p:bgRef></p:bg>")
        #expect(slide.effectiveBackground == .gradient(Color("404040")))
        let svg = try p.renderSVG(slideAt: 0)
        #expect(svg.contains("linearGradient") && svg.contains("#404040"))
    }
    @Test func luminanceTransformsUseHSL() throws {
        let p = try Presentation(); p.theme.setColor(.accent1, Color("FF0000"))
        #expect(p.theme.resolve(.accent1, transforms: [.lumOff(0.25)]) == Color("FF8080"))
        #expect(p.theme.resolve(.accent1, transforms: [.lumMod(0.5)]) == Color("800000"))
    }
}
