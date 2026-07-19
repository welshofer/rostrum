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
}
