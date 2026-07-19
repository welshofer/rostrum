import Foundation
import Testing
@testable import Rostrum

@Suite struct ThemeTests {
    @Test func readsDefaultPaletteAndFonts() throws {
        let deck = try Presentation()
        #expect(deck.theme.accent(1) == Color("4472C4"))
        #expect(deck.theme.accent(2) == Color("ED7D31"))
        // dk1/lt1 are sysClr; resolved via lastClr.
        #expect(deck.theme.color(.dk1) == Color("000000"))
        #expect(deck.theme.color(.lt1) == Color("FFFFFF"))
        #expect(deck.theme.majorFont == "Calibri Light")
        #expect(deck.theme.minorFont == "Calibri")
    }

    @Test func brandKitEditRoundTrips() throws {
        let deck = try Presentation()
        deck.theme.setAccent(1, Color("FF6B5B"))
        deck.theme.setAccent(2, Color("18A999"))
        deck.theme.majorFont = "Avenir Next"
        deck.theme.minorFont = "Avenir Next"

        let reopened = try Presentation(data: try deck.serializedData())
        #expect(reopened.theme.accent(1) == Color("FF6B5B"))
        #expect(reopened.theme.accent(2) == Color("18A999"))
        #expect(reopened.theme.majorFont == "Avenir Next")
    }

    @Test func schemeColorRoutesThroughClrMap() throws {
        let deck = try Presentation()
        // The standard clrMap swaps: bg1→lt1 (white), tx1→dk1 (black).
        #expect(deck.theme.resolve(.bg1) == Color("FFFFFF"))
        #expect(deck.theme.resolve(.tx1) == Color("000000"))
        // accents map identity.
        #expect(deck.theme.resolve(.accent1) == deck.theme.accent(1))
        // dk1/lt1 are direct (skip clrMap).
        #expect(deck.theme.resolve(.dk1) == Color("000000"))
        // phClr is unresolvable without style context.
        #expect(deck.theme.resolve(.phClr) == nil)
    }

    @Test func transformsLightenAndDarken() throws {
        let deck = try Presentation()
        deck.theme.setAccent(1, Color("808080"))
        // tint 0.5 mixes halfway to white; shade 0.5 halves toward black.
        #expect(deck.theme.resolve(.accent1, transforms: [.tint(0.5)]) == Color("C0C0C0"))
        #expect(deck.theme.resolve(.accent1, transforms: [.shade(0.5)]) == Color("404040"))
    }

    @Test func themeColorFillTracksTheme() throws {
        let deck = try Presentation()
        deck.theme.setAccent(3, Color("4262FF"))
        let shape = try deck.slides[0].shapes.addShape(
            .rectangle, frame: Rect(x: .zero, y: .zero, width: .inches(2), height: .inches(1)),
            fill: .themeColor(.accent3))
        // The fill references the theme, not a baked RGB.
        let clr = shape.element.firstChild(named: "p:spPr")?
            .firstChild(named: "a:solidFill")?.firstChild(named: "a:schemeClr")
        #expect(clr?[attribute: "val"] == "accent3")

        let reopened = try Presentation(data: try deck.serializedData())
        // Editing the theme recolors it: resolve accent3 → the brand blue.
        #expect(reopened.theme.resolve(.accent3) == Color("4262FF"))
    }
}
