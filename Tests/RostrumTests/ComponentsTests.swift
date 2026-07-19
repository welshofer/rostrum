import Foundation
import Testing
@testable import Rostrum

@Suite struct ComponentsTests {
    private let r = Rect(x: .inches(1), y: .inches(1), width: .inches(4), height: .inches(2))

    private func sps(_ slide: Slide) throws -> [XML.Element] {
        try slide.part.dom().firstChild(named: "p:cSld")!.firstChild(named: "p:spTree")!.children(named: "p:sp")
    }
    private func lastSp(_ slide: Slide) throws -> XML.Element { try sps(slide).last! }
    private func labelRun(_ sp: XML.Element) -> XML.Element {
        sp.firstChild(named: "p:txBody")!.firstChild(named: "a:p")!.firstChild(named: "a:r")!
    }
    private func runColor(_ run: XML.Element) -> String? {
        run.firstChild(named: "a:rPr")?.firstChild(named: "a:solidFill")?.firstChild(named: "a:srgbClr")?[attribute: "val"]
    }

    @Test func cardIsRoundedSurfaceWithShadowAndPaddedContent() throws {
        let deck = try Presentation()
        let card = try deck.slides[0].addCard(in: r, style: deck.style)
        let spPr = try lastSp(deck.slides[0]).firstChild(named: "p:spPr")!
        #expect(spPr.firstChild(named: "a:prstGeom")?[attribute: "prst"] == "roundRect")
        #expect(spPr.firstChild(named: "a:solidFill")?.firstChild(named: "a:srgbClr")?[attribute: "val"]
                == deck.style.surface.hex)
        #expect(spPr.firstChild(named: "a:effectLst")?.firstChild(named: "a:outerShdw") != nil)
        #expect(card.content == r.inset(by: deck.style.spacing.lg))
        #expect(card.bounds == r)
    }

    @Test func buttonAutoContrastsLabelAndUsesOwnBody() throws {
        let deck = try Presentation()
        let before = deck.slides[0].shapes.count
        try deck.slides[0].addButton("Get started", in: r, style: deck.style, fill: .solid(Color("0E1116")))
        #expect(deck.slides[0].shapes.count == before + 1)   // label lives in the button, not a 2nd shape
        let dark = runColor(labelRun(try lastSp(deck.slides[0])))!
        #expect(Color(dark).relativeLuminance > 0.5)         // light label on dark button

        try deck.slides[0].addButton("Learn", in: r, style: deck.style, fill: .solid(Color("FFD400")))
        let light = runColor(labelRun(try lastSp(deck.slides[0])))!
        #expect(Color(light).relativeLuminance < 0.5)        // dark label on yellow button
        // Pill: adj clamped to 50%.
        #expect(try lastSp(deck.slides[0]).firstChild(named: "p:spPr")?
            .firstChild(named: "a:prstGeom")?.firstChild(named: "a:avLst")?
            .firstChild(named: "a:gd")?[attribute: "fmla"] == "val 50000")
    }

    @Test func chipTintsAndKickerUppercases() throws {
        let deck = try Presentation(); let s = deck.style
        try deck.slides[0].addChip("new", in: r, style: s)
        let chipFill = try lastSp(deck.slides[0]).firstChild(named: "p:spPr")!
            .firstChild(named: "a:solidFill")!.firstChild(named: "a:srgbClr")!
        #expect(chipFill.firstChild(named: "a:alpha")?[attribute: "val"] == "12000")

        try deck.slides[0].addKicker("highlights", in: r, style: s)
        let run = labelRun(try lastSp(deck.slides[0]))
        #expect(run.firstChild(named: "a:t")?.textContent == "HIGHLIGHTS")
        #expect(runColor(run) == s.accent(1).hex)
        #expect(run.firstChild(named: "a:rPr")?[attribute: "spc"] != nil)   // tracked
    }

    @Test func statTileTwoSizedParagraphs() throws {
        let deck = try Presentation()
        try deck.slides[0].addStatTile("47", caption: "NPS, up from 31", in: r, style: deck.style)
        let paras = try lastSp(deck.slides[0]).firstChild(named: "p:txBody")!.children(named: "a:p")
        #expect(paras.count == 2)
        // sz is hundredths of a point: stat 96pt, caption 14pt.
        #expect(paras[0].firstChild(named: "a:r")?.firstChild(named: "a:rPr")?[attribute: "sz"] == "9600")
        #expect(paras[1].firstChild(named: "a:r")?.firstChild(named: "a:rPr")?[attribute: "sz"] == "1400")
    }

    @Test func bulletListAutoShrinksAndBullets() throws {
        let deck = try Presentation()
        try deck.slides[0].addBulletList(Array(repeating: "item", count: 12), in: r, style: deck.style)
        let paras = try lastSp(deck.slides[0]).firstChild(named: "p:txBody")!.children(named: "a:p")
        #expect(paras.count == 12)
        // 12 items → body 18pt − 6 = 12pt (floor), each bulleted.
        #expect(paras[0].firstChild(named: "a:r")?.firstChild(named: "a:rPr")?[attribute: "sz"] == "1200")
        #expect(paras[0].firstChild(named: "a:pPr")?.firstChild(named: "a:buChar") != nil)
    }

    @Test func emptyBulletListStillHasAParagraph() throws {
        // A txBody with zero a:p is invalid OOXML (PowerPoint repairs it).
        let deck = try Presentation()
        try deck.slides[0].addBulletList([], in: r, style: deck.style)
        let paras = try lastSp(deck.slides[0]).firstChild(named: "p:txBody")!.children(named: "a:p")
        #expect(paras.count == 1)
        #expect(try deck.validate().isEmpty)
        _ = try Presentation(data: try deck.serializedData())
    }

    @Test func componentsValidateAndAreDeterministic() throws {
        func build() throws -> Data {
            let deck = try Presentation(); let s = deck.style
            let slide = deck.slides[0]
            let card = try slide.addCard(in: Rect(x: .inches(1), y: .inches(1), width: .inches(5), height: .inches(4)), style: s)
            try slide.addKicker("Q3", in: card.content, style: s)
            try slide.addButton("Details", in: Rect(x: .inches(1), y: .inches(5.5), width: .inches(2), height: .inches(0.6)), style: s)
            try slide.addChip("live", in: Rect(x: .inches(7), y: .inches(1), width: .inches(1.2), height: .inches(0.5)), style: s)
            try slide.addStatTile("18.4M", caption: "ARR", in: Rect(x: .inches(7), y: .inches(2), width: .inches(4), height: .inches(2)), style: s)
            try slide.addBulletList(["a", "b", "c"], in: Rect(x: .inches(7), y: .inches(4.5), width: .inches(5), height: .inches(2)), style: s)
            // No schema violations anywhere in the deck.
            #expect(try deck.validate().isEmpty)
            return try deck.serializedData()
        }
        let a = try build(), b = try build()
        #expect(a == b)                  // byte-deterministic
        _ = try Presentation(data: a)    // reopens
    }
}
