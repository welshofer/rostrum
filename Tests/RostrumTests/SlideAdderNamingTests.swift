import Foundation
import Testing
@testable import Rostrum

/// The two layout-based slide adders look nearly alike but do very different
/// things, which is exactly why their names have to say which is which:
///
///   - `add(clonedFrom:)` copies the layout's placeholder shapes onto the new
///     slide, so it comes out looking like the layout.
///   - `addBound(to:)` sets the same layout relationship but copies *nothing*,
///     leaving an empty slide for callers that draw their own shapes.
///
/// These tests pin that difference in place, so the distinction the rename made
/// obvious can't quietly collapse back into two look-alike names doing two
/// different things.
@Suite struct SlideAdderNamingTests {
    /// The cloning adder copies the layout's placeholders: the Title Slide
    /// layout's `ctrTitle` and `subTitle` arrive on the slide as real shapes,
    /// and the layout relationship is set.
    @Test func clonedFromCopiesTheLayoutsPlaceholders() throws {
        let deck = try Presentation()
        let layout = try #require(deck.layout(type: "title"))

        let slide = try deck.slides.add(clonedFrom: layout)

        // The layout relationship is set…
        #expect(slide.layout?.name == layout.name)
        // …and the layout's placeholder shapes were cloned onto the slide.
        let placeholders = slide.placeholders.compactMap(\.placeholder)
        #expect(placeholders.map(\.type) == ["ctrTitle", "subTitle"])
        #expect(placeholders.map(\.idx) == [0, 1])
        #expect(slide.title != nil)
    }

    /// The binding adder copies nothing: it sets the very same layout
    /// relationship, but not one of the layout's placeholder shapes comes
    /// across — the slide is empty.
    @Test func addBoundSetsTheLayoutButClonesNothing() throws {
        let deck = try Presentation()
        let layout = try #require(deck.layout(type: "title"))

        let slide = try deck.slides.addBound(to: layout)

        // The layout relationship is set, exactly as the cloning adder sets it…
        #expect(slide.layout?.name == layout.name)
        // …but the slide carries none of the layout's placeholder shapes.
        #expect(slide.placeholders.isEmpty)
        #expect(slide.shapes.all.isEmpty)
        #expect(slide.title == nil)
    }

    /// Side by side on the same layout: the whole reason for the rename is that
    /// these two produce genuinely different decks. Both point at the same
    /// layout, yet only the cloning adder carries its placeholders.
    @Test func theTwoAddersDifferOnTheSameLayout() throws {
        let deck = try Presentation()
        let layout = try #require(deck.layout(type: "title"))

        let cloned = try deck.slides.add(clonedFrom: layout)
        let bound = try deck.slides.addBound(to: layout)

        #expect(cloned.layout?.name == bound.layout?.name)
        #expect(!cloned.placeholders.isEmpty)
        #expect(bound.placeholders.isEmpty)
        #expect(cloned.placeholders.count > bound.placeholders.count)
    }
}
