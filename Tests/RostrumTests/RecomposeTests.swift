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
}
