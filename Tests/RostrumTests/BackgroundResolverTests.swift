import Foundation
import Testing
@testable import Rostrum

/// What colour a slide actually is.
///
/// Almost nothing about a real deck's appearance is where a naive reader looks
/// for it. The theme's `lt1` is usually the untouched Office white, the slide
/// usually carries no `p:bg` at all, and the deck's near-black ground is
/// sitting on a *layout* as a `schemeClr` that only means near-black once the
/// master's `clrMap` has been applied. Code that reads one element gets white
/// for decks that are emphatically not white — which is exactly what shipped.
@Suite struct BackgroundResolverTests {

    /// Put a `p:bg` on a part by hand. The library has `setBackground` for
    /// slides only, and the whole point here is what happens when the
    /// background is somewhere *else*.
    func paint(_ part: Part, solidHex: String) throws {
        let cSld = try part.dom().getOrAddChild("p:cSld", beforeAnyOf: ["p:clrMapOvr", "p:timing"])
        cSld.removeChildren(named: "p:bg")
        let bg = XML.Element("p:bg")
        let bgPr = XML.Element("p:bgPr")
        let fill = XML.Element("a:solidFill")
        let clr = XML.Element("a:srgbClr")
        clr[attribute: "val"] = solidHex
        fill.appendElement(clr)
        bgPr.appendElement(fill)
        bgPr.appendElement(XML.Element("a:effectLst"))
        bg.appendElement(bgPr)
        cSld.children.insert(.element(bg), at: 0)
        part.markDirty()
    }

    func paintScheme(_ part: Part, scheme: String) throws {
        let cSld = try part.dom().getOrAddChild("p:cSld", beforeAnyOf: ["p:clrMapOvr", "p:timing"])
        cSld.removeChildren(named: "p:bg")
        let bg = XML.Element("p:bg")
        let bgPr = XML.Element("p:bgPr")
        let fill = XML.Element("a:solidFill")
        let clr = XML.Element("a:schemeClr")
        clr[attribute: "val"] = scheme
        fill.appendElement(clr)
        bgPr.appendElement(fill)
        bg.appendElement(bgPr)
        cSld.children.insert(.element(bg), at: 0)
        part.markDirty()
    }

    // MARK: - Where the background lives

    @Test func aSlideThatPaintsItsOwnGroundIsRead() throws {
        let deck = try Presentation()
        try deck.slides[0].setBackground(.solid(Color("101014")))
        let reopened = try Presentation(data: try deck.serializedData())

        #expect(try reopened.slides[0].effectiveBackgroundColor == Color("101014"))
    }

    /// The case that broke everything. `solidBackground` answers nil here —
    /// correctly, it is a narrower question — and anything relying on it
    /// concludes the deck is white.
    @Test func aGroundInheritedFromTheLayoutIsFound() throws {
        let deck = try Presentation()
        let slide = try deck.slides[0]
        let layout = try #require(slide.inheritanceParts.count > 1 ? slide.inheritanceParts[1] : nil)
        try paint(layout, solidHex: "1B1B22")

        #expect(slide.solidBackground == nil, "the slide itself sets nothing")
        #expect(slide.effectiveBackgroundColor == Color("1B1B22"))
    }

    @Test func aGroundInheritedFromTheMasterIsFound() throws {
        let deck = try Presentation()
        let slide = try deck.slides[0]
        guard slide.inheritanceParts.count > 2 else {
            Issue.record("the template has no master to inherit from"); return
        }
        try paint(slide.inheritanceParts[2], solidHex: "2A0E3F")

        #expect(slide.solidBackground == nil)
        #expect(slide.effectiveBackgroundColor == Color("2A0E3F"))
    }

    /// PowerPoint takes the first background in slide → layout → master, and
    /// so must this: a layout that overrides the master must win.
    @Test func theNearestGroundInTheChainWins() throws {
        let deck = try Presentation()
        let slide = try deck.slides[0]
        guard slide.inheritanceParts.count > 2 else {
            Issue.record("no full chain in the template"); return
        }
        try paint(slide.inheritanceParts[1], solidHex: "AAAAAA")
        try paint(slide.inheritanceParts[2], solidHex: "BBBBBB")

        #expect(slide.effectiveBackgroundColor == Color("AAAAAA"), "the layout, not the master")
    }

    @Test func theSlideBeatsTheLayout() throws {
        let deck = try Presentation()
        let slide = try deck.slides[0]
        guard slide.inheritanceParts.count > 1 else { Issue.record("no layout"); return }
        try paint(slide.inheritanceParts[1], solidHex: "AAAAAA")
        try slide.setBackground(.solid(Color("111111")))

        #expect(slide.effectiveBackgroundColor == Color("111111"))
    }

    // MARK: - How the colour is written

    /// A scheme colour is not a literal. `tx1` means whatever the master's
    /// `clrMap` says it means, and reading the raw value gets it wrong.
    @Test func aSchemeColourIsResolvedThroughTheTheme() throws {
        let deck = try Presentation()
        let slide = try deck.slides[0]
        guard slide.inheritanceParts.count > 1 else { Issue.record("no layout"); return }
        try paintScheme(slide.inheritanceParts[1], scheme: "accent1")

        let expected = deck.theme.resolve(.accent1)
        #expect(expected != nil, "the template has an accent1")
        #expect(slide.effectiveBackgroundColor == expected)
    }

    /// A declaration whose colour cannot be resolved changes nothing.
    ///
    /// It does not become white, or black, or the raw string coerced into
    /// something — the chain simply carries on as though that part had said
    /// nothing, which is the only answer that cannot invent a colour the deck
    /// does not have. Matching what `SVGRenderer` already does for the same
    /// case, so the two cannot disagree.
    @Test func anUnresolvableColourChangesNothing() throws {
        let deck = try Presentation()
        let slide = try deck.slides[0]
        guard slide.inheritanceParts.count > 1 else { Issue.record("no layout"); return }

        let before = slide.effectiveBackgroundColor
        try paintScheme(slide.inheritanceParts[1], scheme: "notAColour")

        #expect(slide.effectiveBackgroundColor == before)
    }

    /// `a:noFill` is a real answer, not a missing one: this part says there is
    /// no background, and the chain must not climb past it to report one the
    /// audience would never see.
    @Test func anExplicitNoFillStopsTheChain() throws {
        let deck = try Presentation()
        let slide = try deck.slides[0]
        guard slide.inheritanceParts.count > 2 else { Issue.record("no full chain"); return }
        try paint(slide.inheritanceParts[2], solidHex: "334455")

        let cSld = try slide.inheritanceParts[1].dom()
            .getOrAddChild("p:cSld", beforeAnyOf: ["p:clrMapOvr", "p:timing"])
        cSld.removeChildren(named: "p:bg")
        let bg = XML.Element("p:bg")
        let bgPr = XML.Element("p:bgPr")
        bgPr.appendElement(XML.Element("a:noFill"))
        bg.appendElement(bgPr)
        cSld.children.insert(.element(bg), at: 0)

        #expect(slide.effectiveBackground == SlideBackground.none)
    }

    // MARK: - Honest about what it cannot answer

    @Test func aPictureFillIsReportedAsOneRatherThanInvented() throws {
        let deck = try Presentation()
        let slide = try deck.slides[0]
        let cSld = try slide.part.dom()
            .getOrAddChild("p:cSld", beforeAnyOf: ["p:clrMapOvr", "p:timing"])
        let bg = XML.Element("p:bg")
        let bgPr = XML.Element("p:bgPr")
        bgPr.appendElement(XML.Element("a:blipFill"))
        bg.appendElement(bgPr)
        cSld.children.insert(.element(bg), at: 0)
        slide.part.markDirty()

        #expect(slide.effectiveBackground == .picture)
        #expect(slide.effectiveBackgroundColor == nil, "no single colour, so none is offered")
    }

    @Test func aDeckWithNoBackgroundAnywhereSaysSo() throws {
        let deck = try Presentation()
        // The stock template paints no p:bg at any level.
        let background = try deck.slides[0].effectiveBackground
        #expect(background == .none || background.color != nil,
                "either nothing is set, or something is and it resolves")
    }

    // MARK: - The deck's prevailing ground

    /// For a slide being *added*, which has nothing to inherit from. The
    /// honest answer is whatever its neighbours do.
    @Test func theDecksPrevailingGroundIsTheOneMostSlidesUse() throws {
        let deck = try Presentation()
        for _ in 0..<4 { _ = try deck.slides.add() }
        for index in 0..<deck.slides.count {
            try deck.slides[index].setBackground(.solid(Color("0E0E12")))
        }
        // One slide breaks the pattern.
        try deck.slides[0].setBackground(.solid(Color("FFFFFF")))

        #expect(deck.prevailingBackground == Color("0E0E12"))
    }

    /// The mode, not the first slide's. A title slide is very often the one
    /// slide that breaks the pattern, and taking it would dress every added
    /// slide as a title.
    @Test func theTitleSlideDoesNotDecideTheDecksLook() throws {
        let deck = try Presentation()
        for _ in 0..<3 { _ = try deck.slides.add() }
        try deck.slides[0].setBackground(.solid(Color("C4302B")))
        for index in 1..<deck.slides.count {
            try deck.slides[index].setBackground(.solid(Color("101014")))
        }

        #expect(deck.prevailingBackground == Color("101014"))
    }

    /// No majority means the deck has no single ground, and saying so lets the
    /// caller fall back rather than pick a colour half the deck disagrees with.
    @Test func aDeckWithNoMajorityGroundReportsNone() throws {
        let deck = try Presentation()
        for _ in 0..<3 { _ = try deck.slides.add() }
        let colours = ["111111", "222222", "333333", "444444"]
        for index in 0..<min(colours.count, deck.slides.count) {
            try deck.slides[index].setBackground(.solid(Color(colours[index])))
        }

        #expect(deck.prevailingBackground == nil)
    }
}
