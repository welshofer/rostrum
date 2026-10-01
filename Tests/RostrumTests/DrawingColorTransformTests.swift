import Foundation
import Testing
@testable import Rostrum

@Suite struct DrawingColorTransformTests {
    private func resolve(_ base: String, _ transforms: String) throws -> Color {
        let xml = try XML.parse(Data("<a:solidFill><a:srgbClr val=\"\(base)\">\(transforms)</a:srgbClr></a:solidFill>".utf8))
        return try #require(DrawingColor.resolve(in: xml, theme: nil)?.color)
    }

    @Test func drawingMLTintAndShadeUseLinearLightWithoutChangingDesignMixing() throws {
        #expect(try resolve("000000", "<a:tint val=\"20000\"/>") == Color("E7E7E7"))
        #expect(try resolve("808080", "<a:tint val=\"50000\"/>") == Color("CDCDCD"))
        #expect(try resolve("808080", "<a:shade val=\"50000\"/>") == Color("5C5C5C"))
        #expect(try resolve("FFFFFF", "<a:shade val=\"20000\"/>") == Color("7C7C7C"))
        #expect(Color("808080").lighten(0.5) == Color("C0C0C0"))
        #expect(Color("808080").darken(0.5) == Color("404040"))
        #expect(Color.mix(.black, .white) == Color("808080"))
    }

    @Test func oversaturatedNativeGradientStopsMatchPowerPoint() throws {
        // PowerPoint 16.113.3 exported the six native Themed Style 2 accent
        // slides at 1200x700. Flat endpoint probes at (187,102) yielded these
        // exact sRGB values. They distinguish clipping RGB after conversion
        // from incorrectly clipping HSL saturation to 100% first.
        // Semantics: ISO/IEC 29500-1 20.1.2.3.27 (satMod), Microsoft reference:
        // https://learn.microsoft.com/en-us/dotnet/api/documentformat.openxml.drawing.saturationmodulation?view=openxml-2.10.0
        let cases = [("4F81BD", "9BC1FF"), ("C0504D", "FF9A99"),
                     ("9BBB59", "DCFFA0"), ("8064A2", "C8B0ED"),
                     ("4BACC6", "95EEFF"), ("F79646", "FFB977")]
        for (base, expected) in cases {
            #expect(try resolve(base, "<a:tint val=\"50000\"/><a:shade val=\"100000\"/><a:satMod val=\"350000\"/>") == Color(expected))
        }
        #expect(try resolve("F79646", "<a:satMod val=\"130000\"/>") == Color("FF932B"))
    }

    @Test func transformOrderAndIntermediateChannelClippingRemainObservable() throws {
        let deck = try Presentation()
        deck.theme.setAccent(6, Color("F79646"))
        let transforms = "<a:tint val=\"50000\"/><a:satMod val=\"350000\"/><a:satMod val=\"50000\"/>"
        // Calculate the second modulation from the first transform's clipped
        // RGB, not an out-of-gamut intermediate or a prematurely rounded color.
        let result = try resolve("F79646", transforms)
        #expect(result == Color("DDBA99"))
        #expect(deck.theme.resolve(.accent6, transforms: [.tint(0.5), .satMod(3.5), .satMod(0.5)]) == result)
        #expect(try resolve("F79646", "<a:satMod val=\"350000\"/><a:tint val=\"50000\"/>") != Color("FFB977"))
        let xml = try XML.parse(Data("<a:solidFill><a:schemeClr val=\"accent6\">\(transforms)<a:alpha val=\"50000\"/></a:schemeClr></a:solidFill>".utf8))
        let before = xml.serialized()
        let resolved = try #require(DrawingColor.resolve(in: xml, theme: deck.theme))
        #expect(resolved.color == result && resolved.alpha == 0.5)
        #expect(xml.serialized() == before)
    }
}
