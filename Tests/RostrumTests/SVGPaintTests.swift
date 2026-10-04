import Foundation
import Testing
@testable import Rostrum

@Suite struct SVGPaintTests {
    private func deck(fill: String, style: String = "") throws -> Presentation {
        let deck = try Presentation()
        let part = try deck.slides[0].part
        let shape = try XML.parse(Data("""
        <p:sp><p:nvSpPr><p:cNvPr id="42" name="Paint"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
        <p:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="4000000" cy="2000000"/></a:xfrm>
        <a:prstGeom prst="rect"/>\(fill)</p:spPr>\(style)</p:sp>
        """.utf8))
        try #require(Slide.existingSpTree(of: part)).appendElement(shape)
        part.markDirty()
        return deck
    }

    private func gradient(_ color: String, angle: Int = 0, scaled: Bool = false) -> String {
        """
        <a:gradFill><a:gsLst><a:gs pos="12345">\(color)</a:gs>
        <a:gs pos="100000"><a:srgbClr val="FFFFFF"/></a:gs></a:gsLst>
        <a:lin ang="\(angle)" scaled="\(scaled ? 1 : 0)"/></a:gradFill>
        """
    }

    @Test func stopsKeepPrecisionTransformsAndTransparencyWithoutMutatingSource() throws {
        let deck = try deck(fill: gradient("""
        <a:srgbClr val="FF0000"><a:tint val="50000"/><a:shade val="50000"/>
        <a:alpha val="50000"/><a:alphaMod val="50000"/><a:alphaOff val="10000"/></a:srgbClr>
        """))
        // DrawingML tint/shade resolve in linear light, as native Office does.
        let before = try deck.serializedData()
        let svg = try deck.renderSVG(slideAt: 0)
        #expect(svg.contains("offset=\"0.12345\" stop-color=\"rgba(188,137,137,0.35)\""))
        #expect(svg.contains("x1=\"0.0\" y1=\"1000000.0\" x2=\"4000000.0\" y2=\"1000000.0\""))
        #expect(try deck.serializedData() == before)
        #expect(try Presentation(data: before).renderSVG(slideAt: 0) == svg)
    }

    @Test func themePlaceholderRetainsReferenceAndStopTransformsInOrder() throws {
        let deck = try deck(fill: "", style: """
        <p:style><a:fillRef idx="2"><a:srgbClr val="FF0000"><a:shade val="50000"/>
        <a:alpha val="50000"/></a:srgbClr></a:fillRef></p:style>
        """)
        let scheme = try #require(try deck.theme.part.dom().firstChild(named: "a:themeElements")?.firstChild(named: "a:fmtScheme")?.firstChild(named: "a:fillStyleLst"))
        let custom = try XML.parse(Data(gradient("<a:schemeClr val=\"phClr\"><a:tint val=\"50000\"/><a:alphaMod val=\"50000\"/></a:schemeClr>").utf8))
        scheme.children[1] = .element(custom)
        deck.theme.part.markDirty()
        let before = try deck.serializedData()
        let svg = try deck.renderSVG(slideAt: 0)
        #expect(svg.contains("stop-color=\"rgba(225,188,188,0.25)\""))
        #expect(try deck.serializedData() == before)
    }

    @Test func saturationAndSystemFallbackApplyToSolidPaint() throws {
        let deck = try deck(fill: "<a:solidFill><a:sysClr val=\"windowText\" lastClr=\"FF0000\"><a:satMod val=\"0\"/><a:alpha val=\"25000\"/></a:sysClr></a:solidFill>")
        #expect(try deck.renderSVG(slideAt: 0).contains("fill=\"rgba(128,128,128,0.25)\""))
    }

    @Test func linearDirectionHonorsClockwiseAngleAndAspectScaling() throws {
        for (angle, expected) in [(5_400_000, "x1=\"2000000.0\" y1=\"0.0\" x2=\"2000000.0\" y2=\"2000000.0\""),
                                  (16_200_000, "x1=\"2000000.0\" y1=\"2000000.0\" x2=\"2000000.0\" y2=\"0.0\"")] {
            let deck = try deck(fill: gradient("<a:srgbClr val=\"FF0000\"/>", angle: angle))
            #expect(try deck.renderSVG(slideAt: 0).contains(expected))
        }
        let scaled = try XML.parse(Data("<a:lin ang=\"2700000\" scaled=\"1\"/>".utf8))
        let v = SVGPaint.gradientVector(scaled, frame: (0,0,4000,2000))
        #expect(abs(v.0) < 0.001 && abs(v.1) < 0.001)
        #expect(abs(v.2 - 4000) < 0.001 && abs(v.3 - 2000) < 0.001)
        scaled[attribute: "scaled"] = "0"
        let u = SVGPaint.gradientVector(scaled, frame: (0,0,4000,2000))
        #expect(abs(u.0 - 500) < 0.001 && abs(u.1 + 500) < 0.001)
    }

    @Test func malformedPaintCannotInjectMarkupOrNonfiniteValues() throws {
        let deck = try deck(fill: gradient("<a:srgbClr val=\"00FF00\"><a:tint val=\"9999999999999999999999999\"/><a:alpha val=\"NaN\"/><a:satMod val=\"-1\"/></a:srgbClr>", angle: Int.max))
        let svg = try deck.renderSVG(slideAt: 0)
        #expect(svg.contains("stop-color=\"#00FF00\""))
        #expect(!svg.contains("NaN") && !svg.contains("nan"))
        _ = try XML.parse(Data(svg.utf8))
    }

    @Test func definitionIDsArePerRenderAndIndependentOfPayloadLength() {
        var defs = SVGDefinitions()
        #expect(defs.nextID("g") == "g0")
        defs += String(repeating: "é", count: 1_000_000)
        #expect(defs.nextID("bg") == "bg1")
        #expect(defs.nextID("arrow") == "arrow2")
        var second = SVGDefinitions()
        #expect(second.nextID("g") == "g0")
    }
}
