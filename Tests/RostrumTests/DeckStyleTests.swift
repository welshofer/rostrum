import Foundation
import Testing
@testable import Rostrum

@Suite struct DeckStyleTests {
    @Test func defaultStyleNoDesign() throws {
        let s = try Presentation().style
        #expect(s.background == .white)
        #expect(s.ink == .black)
        #expect(s.isDark == false)
        #expect(s.accents.count == 6)
        #expect(s.type(.title).sizePt == 34 && s.type(.title).bold)
        #expect(s.type(.body).sizePt == 18 && !s.type(.body).bold)
        #expect(s.type(.kicker).uppercase && s.type(.kicker).trackingPt == 2.0)
        #expect(s.spacing.md == EMU.pixels(16))
        #expect(s.spacing.md == EMU(152_400))
        #expect(s.radius.lg == EMU.pixels(12))
        #expect(s.radius("full") == EMU.pixels(9999))
    }

    @Test func pullsTypeAndSpacingTokensFromAppliedDesign() throws {
        let deck = try Presentation()
        deck.applyDesign(Design.parse("""
        ## Typography tokens
        - title: family Georgia, size 96px, weight 700, line 1.1, tracking -3px

        ## Spacing tokens
        - lg: 40px
        """))
        let s = deck.style
        #expect(s.type(.title).font == "Georgia")
        #expect(s.type(.title).sizePt == 72)          // 96px × 72/96
        #expect(s.type(.title).trackingPt == -2.25)   // -3px × 72/96
        #expect(s.spacing.lg == EMU.pixels(40))       // design overlays the default 24px
        #expect(s.spacing.md == EMU.pixels(16))       // untouched default remains
    }

    @Test func perFacetFallbackKeepsDefaults() throws {
        let deck = try Presentation()
        deck.applyDesign(Design.parse("""
        ## Fonts
        - Heading: Georgia
        """))
        // Only the family is known → size/weight/tracking stay at role defaults.
        #expect(deck.style.type(.heading).font == "Georgia")
        #expect(deck.style.type(.heading).sizePt == 22)
        #expect(deck.style.type(.heading).weight == 700)
    }

    @Test func colorsFollowThemeAndDarkIsDerived() throws {
        let deck = try Presentation()
        deck.applyDesign(Design.parse("""
        ## Palette
        - Background: #0B1D33
        - Text: #F7F4EE
        - Accent 1: #18A999
        """))
        let s = deck.style
        #expect(s.background == Color("0B1D33"))
        #expect(s.ink == Color("F7F4EE"))
        #expect(s.accent(1) == Color("18A999"))
        #expect(s.isDark == true)   // derived from resolved bg luminance, not themeMode
    }

    @Test func autoContrastAndAccentWrap() throws {
        let s = try Presentation().style
        // Text on any accent clears AA, and wrap is cyclic + non-trapping.
        #expect(s.textColor(on: s.accent(1)).contrastRatio(with: s.accent(1)) >= 4.5)
        #expect(s.accent(7) == s.accent(1))
        _ = s.accent(0)   // does not trap
    }

    @Test func overridesAreValueSemantics() throws {
        let deck = try Presentation()
        let big = deck.style.with(.title) { $0.sizePt = 54 }
        #expect(big.type(.title).sizePt == 54)
        #expect(deck.style.type(.title).sizePt == 34)   // original untouched
    }

    @Test func spacingRadiusFallbackAndValue() throws {
        let s = try Presentation().style
        #expect(s.spacing("nope") == s.spacing.md)   // unknown → md
        #expect(s.spacing.value("nope") == nil)      // no fallback here
        #expect(s.radius("full") == EMU.pixels(9999))
    }

    @Test func applyWritesRunInSchemaOrder() throws {
        let deck = try Presentation()
        let box = try deck.slides[0].shapes.addTextBox(
            Rect(x: .zero, y: .zero, width: .inches(4), height: .inches(1)))
        let run = box.textFrame!.addParagraph().addRun("hi")
        _ = run.apply(deck.style.type(.title))
        let rPr = run.r.firstChild(named: "a:rPr")!
        let names = rPr.childElements.map(\.name)
        #expect(names.firstIndex(of: "a:solidFill")! < names.firstIndex(of: "a:latin")!)
        #expect(rPr[attribute: "spc"] != nil)   // title tracking -0.5pt
    }

    @Test func persistenceBoundaryInMemoryOnly() throws {
        let deck = try Presentation()
        deck.applyDesign(Design.parse("""
        ## Typography tokens
        - title: family Georgia, size 96px, weight 700
        """))
        #expect(deck.style.type(.title).sizePt == 72)
        #expect(deck.style.headingFont == "Georgia")

        let reopened = try Presentation(data: try deck.serializedData())
        // Fonts persist (written into the theme DOM); type tokens do NOT (they
        // were never in the file). appliedDesign is not serialized.
        #expect(reopened.appliedDesign == nil)
        #expect(reopened.style.headingFont == "Georgia")
        #expect(reopened.style.type(.title).sizePt == 34)   // reverted to default
    }

    @Test func styledRunsAreDeterministic() throws {
        func build() throws -> Data {
            let deck = try Presentation()
            let box = try deck.slides[0].shapes.addTextBox(
                Rect(x: .zero, y: .zero, width: .inches(6), height: .inches(2)))
            box.textFrame!.addParagraph().addRun("Deterministic").apply(deck.style.type(.title))
            return try deck.serializedData()
        }
        #expect(try build() == build())
    }
}
