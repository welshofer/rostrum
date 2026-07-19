import Foundation
import Testing
@testable import Rostrum

@Suite struct ColorMathTests {
    @Test func channelsDecodeHex() {
        let c = Color("18A999")
        #expect(c.red == 24 && c.green == 169 && c.blue == 153)
        // Round-trips the component initializer.
        #expect(Color(red: 24, green: 169, blue: 153) == c)
    }

    @Test func relativeLuminanceEndpointsAndOrder() {
        #expect(Color.white.relativeLuminance == 1.0)
        #expect(Color.black.relativeLuminance == 0.0)
        #expect(Color("222222").relativeLuminance < Color("DDDDDD").relativeLuminance)
    }

    @Test func contrastRatioKnownPairs() {
        #expect(Color.black.contrastRatio(with: .white) == 21.0)
        #expect(Color.white.contrastRatio(with: .white) == 1.0)
        // Symmetric.
        #expect(Color("18A999").contrastRatio(with: .white)
                == Color.white.contrastRatio(with: Color("18A999")))
        // WebAIM reference: #767676 on white is the 4.5:1 threshold gray.
        #expect(abs(Color("767676").contrastRatio(with: .white) - 4.54) < 0.1)
        // White on pure blue ≈ 8.59:1.
        #expect(abs(Color.white.contrastRatio(with: Color("0000FF")) - 8.59) < 0.05)
    }

    @Test func autoContrastPicksLegibleText() {
        #expect(Color.white.onColor() == .black)
        #expect(Color.black.onColor() == .white)
        #expect(Color("FFD02F").onColor() == .black)   // canary yellow → black text
        #expect(Color("4262FF").onColor() == .white)   // brand blue → white text
        #expect(Color.bestTextColor(on: Color("18A999")) == .black)
        #expect(Color.bestTextColor(on: Color("18A999"), options: []) == .black)
    }

    @Test func mixAndClamp() {
        #expect(Color.mix(.black, .white, amount: 0.5) == Color("808080"))
        #expect(Color.mix(.black, .white, amount: 0) == .black)
        #expect(Color.mix(.black, .white, amount: 1) == .white)
        #expect(Color.mix(.black, .white, amount: 2.0) == .white)    // clamped
        #expect(Color.mix(.black, .white, amount: -1.0) == .black)   // clamped
        #expect(Color("FF0000").mixed(with: Color("0000FF")) == Color("800080"))
    }

    @Test func lightenDarkenMatchThemeTransforms() {
        // Parity with the DrawingML tint/shade transforms (ThemeTests uses the
        // same pair): lighten(a) == tint value (1-a), etc.
        #expect(Color("808080").lighten(0.5) == Color("C0C0C0"))
        #expect(Color("808080").darken(0.5) == Color("404040"))
        #expect(Color("808080").tint(0.5) == Color("808080").lighten(0.5))
        #expect(Color("808080").shade(0.5) == Color("808080").darken(0.5))
        // Deterministic: repeated calls are byte-identical.
        #expect(Color("18A999").lighten(0.3) == Color("18A999").lighten(0.3))
    }
}
