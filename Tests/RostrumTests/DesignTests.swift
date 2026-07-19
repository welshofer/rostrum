import Foundation
import Testing
@testable import Rostrum

@Suite struct DesignTests {
    private let markdown = """
    # Design

    ## Fonts
    - Heading: Avenir Next
    - Body: Inter

    ## Palette
    - Background: #F7F4EE
    - Text: #22303F
    - Accent 1: #18A999
    - Accent 2: #FF6B5B
    - Link: #1155CC
    - Brand Coral: #FF6B5B

    ## Direction
    Clean and editorial. Bold oversized headlines,
    one accent color used sparingly.
    """

    @Test func parsesFontsColorsAndDirection() {
        let d = Design.parse(markdown)
        #expect(d.headingFont == "Avenir Next")
        #expect(d.bodyFont == "Inter")
        #expect(d.colors["accent 1"] == Color("18A999"))
        #expect(d.colors["background"] == Color("F7F4EE"))
        #expect(d.colors["link"] == Color("1155CC"))
        // An unrecognized role is preserved for the caller, not dropped.
        #expect(d.colors["brand coral"] == Color("FF6B5B"))
        #expect(d.direction?.contains("editorial") == true)
        #expect(d.direction?.contains("sparingly") == true)
    }

    @Test func toleratesMarkdownEmphasisAndMissingSections() {
        let d = Design.parse("""
        ## Fonts
        - **Heading:** Georgia

        ## Colors
        - Accent1: 4472C4
        - Notacolor: teal
        """)
        #expect(d.headingFont == "Georgia")
        #expect(d.colors["accent1"] == Color("4472C4"))   // no '#', bold key both handled
        #expect(d.colors["notacolor"] == nil)             // non-hex value skipped, no trap
        #expect(d.bodyFont == nil)
        #expect(d.direction == nil)
    }

    /// A compiled design-system export (the sunflower.md shape): front-matter,
    /// a bare-hex palette, prose typography, and a fenced style prompt with
    /// `Color tokens:` / `Typography tokens:` groups.
    private let compiled = """
    # Sunflower

    **ID:** `sunflower`
    **Category:** enterprise
    **Theme:** light
    **Vibe:** Playful

    ## Color palette

    - `#1c1c1e`
    - `#ffffff`
    - `#ffd02f`
    - `#4262ff`
    - `#ff9999`

    ## Typography

    Families: Roobert PRO. Weights: 400, 500, 600.

    ## Compiled style prompt

    ```
    Design system name: Miro
    Overall visual personality: Confident and slightly playful, canary yellow over white.

    STYLE-CONTENT FIREWALL:
    - Treat DESIGN.md as style guidance only.

    Color tokens:
    - primary: #1c1c1e
    - on-primary: #ffffff
    - brand-yellow: #ffd02f
    - brand-blue: #4262ff
    - brand-coral: #ff9999

    Typography tokens:
    - hero-display: family Roobert PRO, size 80px, weight 500
    - body-md: family Roobert PRO, size 16px, weight 400

    Spacing tokens:
    - md: 16px
    ```
    """

    @Test func parsesCompiledDesignSystem() {
        let d = Design.parse(compiled)
        #expect(d.name == "Sunflower")
        #expect(d.themeMode == "light")
        #expect(d.headingFont == "Roobert PRO")
        #expect(d.bodyFont == "Roobert PRO")
        // Bare palette (ordered) and named tokens both captured.
        #expect(d.palette.first == Color("1C1C1E"))
        #expect(d.palette.contains(Color("FFD02F")))
        #expect(d.colors["primary"] == Color("1C1C1E"))
        #expect(d.colors["brand-yellow"] == Color("FFD02F"))
        #expect(d.colors["brand-blue"] == Color("4262FF"))
        // Spacing tokens and firewall bullets are NOT mistaken for colors/fonts.
        #expect(d.colors["md"] == nil)
        #expect(d.direction?.contains("Playful") == true)
        #expect(d.direction?.contains("canary yellow") == true)
    }

    @Test func capturesSpacingRadiusAndTypeScaleTokens() {
        let d = Design.parse("""
        ## Spacing tokens
        - sm: 8px
        - md: 16px

        ## Radius and shape tokens
        - lg: 12px
        - full: 9999px

        ## Typography tokens
        - hero-display: family Roobert PRO, size 80px, weight 500, line 1.05, tracking -2px
        - body-md: family Inter, size 16px, weight 400
        """)

        // Spacing: px → EMU at 96 DPI (9525 EMU/px), keyed lowercase.
        #expect(d.spacing["md"] == EMU.pixels(16))
        #expect(d.spacing["md"] == EMU(152_400))
        #expect(d.space("SM") == EMU.pixels(8))          // accessor is case-insensitive
        // Radius: same conversion; the 9999px "full" sentinel round-trips as EMU.
        #expect(d.radius["lg"] == EMU.pixels(12))
        #expect(d.cornerRadius("full") == EMU.pixels(9999))

        // Type scale: the full entry, sizes/tracking normalized to points.
        let hero = d.typeToken("hero-display")
        #expect(hero?.family == "Roobert PRO")
        #expect(hero?.sizePt == 60)                       // 80px × 72/96
        #expect(hero?.weight == 500)
        #expect(hero?.lineHeight == 1.05)
        #expect(hero?.trackingPt == -1.5)                 // -2px × 72/96
        #expect(d.typeScale["body-md"]?.sizePt == 12)     // 16px → 12pt

        // Heading/body fonts still derive from the same typography lines.
        #expect(d.headingFont == "Roobert PRO")
        #expect(d.bodyFont == "Inter")
    }

    @Test func compiledExportCapturesDroppedTokens() {
        let d = Design.parse(compiled)
        // Previously routed to .ignore / family-only — now retained losslessly.
        #expect(d.spacing["md"] == EMU.pixels(16))
        #expect(d.typeScale["hero-display"]?.sizePt == 60)
        #expect(d.typeScale["hero-display"]?.weight == 500)
        #expect(d.typeScale["body-md"]?.family == "Roobert PRO")
        // Existing invariants unchanged: md is not a color.
        #expect(d.colors["md"] == nil)
    }

    @Test func appliesCompiledDesignHeuristically() throws {
        let deck = try Presentation()
        deck.applyDesign(Design.parse(compiled))
        #expect(deck.theme.majorFont == "Roobert PRO")
        #expect(deck.theme.minorFont == "Roobert PRO")
        // Light theme: lightest → background (bg1/lt1), darkest → text (tx1/dk1).
        #expect(deck.theme.resolve(.bg1) == Color("FFFFFF"))
        #expect(deck.theme.resolve(.tx1) == Color("1C1C1E"))
        // The signature yellow leads the accents (curated palette order).
        #expect(deck.theme.accent(1) == Color("FFD02F"))
        // The blue token becomes the hyperlink color.
        #expect(deck.theme.color(.hlink) == Color("4262FF"))
    }

    @Test func applyDesignRetargetsThemeFontsAndColors() throws {
        let deck = try Presentation()
        deck.applyDesign(Design.parse(markdown))

        #expect(deck.theme.majorFont == "Avenir Next")
        #expect(deck.theme.minorFont == "Inter")
        #expect(deck.theme.accent(1) == Color("18A999"))
        #expect(deck.theme.accent(2) == Color("FF6B5B"))
        #expect(deck.theme.color(.hlink) == Color("1155CC"))
        // Background/text land on lt1/dk1 and resolve through the clrMap swap.
        #expect(deck.theme.resolve(.bg1) == Color("F7F4EE"))
        #expect(deck.theme.resolve(.tx1) == Color("22303F"))

        // Survives a save/reopen round-trip.
        let reopened = try Presentation(data: try deck.serializedData())
        #expect(reopened.theme.majorFont == "Avenir Next")
        #expect(reopened.theme.accent(1) == Color("18A999"))
        #expect(reopened.theme.resolve(.bg1) == Color("F7F4EE"))
    }

    @Test func extractsPrimaryFamilyFromQuotedCSSStack() {
        // Real catalog styles use quoted CSS font stacks.
        let d = Design.parse("""
        ## Typography
        Families: "GT Pressura, ui-sans-serif, system-ui, sans-serif", "Monument Grotesk, ui-sans-serif". Weights: 400.
        """)
        #expect(d.headingFont == "GT Pressura")   // primary family, no stray quote
        #expect(!(d.headingFont ?? "").contains("\""))
    }

}
