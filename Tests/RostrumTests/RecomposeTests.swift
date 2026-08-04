import Foundation
import Testing
@testable import Rostrum

/// Rebuilding a deck on a template's layouts — the difference between pointing
/// a slide at a layout and actually using it.
@Suite struct RecomposeTests {
    private func template() throws -> Presentation {
        let template = try Presentation()
        template.theme.majorFont = "Papyrus"
        return template
    }

    /// Relaying alone leaves the deck drawing its own text at its own
    /// coordinates, on top of whatever the layout puts there. Rebuilding moves
    /// the words into the placeholders the template designed for them.
    @Test func aFreeformSlideIsRebuiltIntoTheLayoutsPlaceholders() throws {
        let deck = try Presentation()
        try deck.titleSlide("The Headline", subtitle: "and the supporting line")
        _ = try deck.applyTemplate(from: try template())

        let report = try deck.recomposeOntoLayouts()
        let index = deck.slides.count - 1
        #expect(report.rebuilt.contains(index))

        let slide = try deck.slides.slide(at: index)
        #expect(slide.title?.textFrame?.text == "The Headline")
        // Every shape left is a placeholder: the old composition is gone, which
        // is what stops it colliding with the template's.
        #expect(slide.shapes.all.allSatisfy { $0.placeholder != nil })
        #expect(slide.shapes.all.count == slide.placeholders.count)
        // And it no longer paints over the template's background.
        #expect(try slide.part.dom().firstChild(named: "p:cSld")?
            .firstChild(named: "p:bg") == nil)
        #expect(try deck.validate().isEmpty)
    }

    /// The words have to survive. A slide is only rebuilt when everything on it
    /// has somewhere to go.
    @Test func noWordsAreLostWhenASlideIsRebuilt() throws {
        let deck = try Presentation()
        try deck.titleSlide("Keep me", subtitle: "and me too")
        _ = try deck.applyTemplate(from: try template())
        _ = try deck.recomposeOntoLayouts()

        let text = try deck.slides.slide(at: deck.slides.count - 1)
            .shapes.compactMap { $0.textFrame?.text }.joined(separator: " ")
        #expect(text.contains("Keep me"))
        #expect(text.contains("and me too"))
    }

    /// A chart has no counterpart in a text placeholder, so the slide keeps its
    /// own composition rather than losing the chart. Staying off-brand beats
    /// dropping content.
    @Test func aSlideCarryingAChartIsLeftAlone() throws {
        let deck = try Presentation()
        try deck.chartSlide("Revenue", .line,
                            ChartData(categories: ["Q1", "Q2"], name: "ARR", values: [1, 2]))
        _ = try deck.applyTemplate(from: try template())

        let index = deck.slides.count - 1
        let report = try deck.recomposeOntoLayouts()

        #expect(!report.rebuilt.contains(index))
        #expect(report.leftAlone.contains { $0.slide == index && $0.why.contains("chart") })
        #expect(try deck.slides.slide(at: index).shapes.all.count > 1,
                "the chart slide was stripped anyway")
    }

    /// A dark deck inverts dk1/lt1 — that is how it is dark. Rebinding its
    /// blacks and whites to bg1/tx1 and then adopting a normally polarised
    /// template turns the deck inside out, while every literal that matched
    /// nothing stays put: dark cards keep their dark fill and the now-black
    /// text on them is unreadable. This is the failure that reached a user.
    @Test func adarkDeckKeepsItsPolarityUnderALightTemplate() throws {
        let deck = try Presentation()
        deck.theme.setColor(.dk1, Color("FFFFFF"))
        deck.theme.setColor(.lt1, Color("000000"))
        let slide = try deck.slides.add()
        try slide.setBackground(.solid(Color("000000")))
        try slide.addText("White on black", in: Rect(x: .inches(1), y: .inches(1),
                                                     width: .inches(6), height: .inches(1)),
                          role: .title, style: deck.style, color: Color("FFFFFF"))

        let template = try Presentation()
        template.theme.setColor(.dk1, Color("000000"))
        template.theme.setColor(.lt1, Color("FFFFFF"))

        let report = try deck.applyTemplate(from: template, rebindingDirectFormatting: true)

        #expect(report.keptPolarity, "the polarity flip went undetected")
        #expect(report.backgroundsAdopted == 0, "a dark slide was dropped onto a light background")
        // The blacks and whites stay literal, so they still mean what they did.
        let xml = try slide.part.dom().serialized()
        #expect(xml.contains("FFFFFF"), "white text was rebound and will invert")
        #expect(try slide.part.dom().firstChild(named: "p:cSld")?
            .firstChild(named: "p:bg") != nil, "the dark slide lost its background")
    }

    /// Two decks the same way up still rebind everything — the guard must not
    /// quietly switch rebinding off for the ordinary case.
    @Test func matchingPolarityStillRebinds() throws {
        let deck = try Presentation()
        try deck.titleSlide("Title", subtitle: "sub")
        let report = try deck.applyTemplate(from: try template(),
                                            rebindingDirectFormatting: true)
        #expect(!report.keptPolarity)
        #expect(report.rebind.colors > 0, "nothing rebound at matching polarity")
    }

    /// A running footer is furniture, not content — the template brings its own.
    /// Sweeping it in makes it the last bullet on every single slide.
    @Test func aRunningFooterIsNotSweptIntoTheBody() throws {
        let deck = try Presentation()
        let slide = try deck.slides.add()
        try slide.addText("The Headline", in: Rect(x: .inches(1), y: .inches(0.5),
                                                   width: .inches(8), height: .inches(1)),
                          role: .title, style: deck.style.with(.title) { $0.sizePt = 40 })
        try slide.addText("Real body copy that belongs in the placeholder.",
                          in: Rect(x: .inches(1), y: .inches(2),
                                   width: .inches(8), height: .inches(2)),
                          role: .body, style: deck.style)
        try slide.addText("PaperBanana: Automating Academic Illustration",
                          in: Rect(x: .inches(1), y: .inches(7),
                                   width: .inches(8), height: .inches(0.4)),
                          role: .caption, style: deck.style)

        _ = try deck.applyTemplate(from: try template())
        _ = try deck.recomposeOntoLayouts()

        let text = try deck.slides.slide(at: deck.slides.count - 1)
            .shapes.compactMap { $0.textFrame?.text }.joined(separator: " ")
        #expect(text.contains("Real body copy"))
        #expect(!text.contains("PaperBanana"), "the footer became content")
    }
}
