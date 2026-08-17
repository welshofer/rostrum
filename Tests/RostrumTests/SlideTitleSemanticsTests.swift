import Foundation
import Testing
@testable import Rostrum

/// A deck of positioned text boxes looks right and has no titles at all as far
/// as PowerPoint is concerned: nothing in the outline view, nothing in the
/// slide navigator, nothing for a screen reader, and nothing for our own
/// inspector, which reported every slide as "(untitled)".
@Suite struct SlideTitleSemanticsTests {

    @Test func aTitleSlideHasARealTitlePlaceholder() throws {
        let deck = try Presentation()
        let slide = try deck.titleSlide("Quarterly Review", subtitle: "Northwind")

        let title = try #require(slide.title)
        #expect(title.placeholder?.type == "ctrTitle")
        #expect(title.textFrame?.text == "Quarterly Review")

        let subtitle = slide.placeholders.first { $0.placeholder?.type == "subTitle" }
        #expect(subtitle?.textFrame?.text == "Northwind")
    }

    @Test func aContentSlideHasARealTitlePlaceholder() throws {
        let deck = try Presentation()
        let slide = try deck.bulletSlide("Highlights", ["ARR up", "NPS up"])

        let title = try #require(slide.title)
        #expect(title.placeholder?.type == "title")
        #expect(title.textFrame?.text == "Highlights")
    }

    /// The symptom the user saw: every slide untitled in a Lectern-made deck.
    @Test func everySlideInABuiltDeckIsTitled() throws {
        let deck = try Presentation()
        try deck.titleSlide("Opening", subtitle: "sub")
        try deck.bulletSlide("Second", ["a"])
        try deck.bulletSlide("Third", ["b"])

        // `Presentation()` opens with one blank slide; Lectern drops it after
        // building (DeckRenderer), so the builders' own slides are what matter.
        try deck.slides.remove(at: 0)

        let reopened = try Presentation(data: deck.serializedData())
        let titles = reopened.outline().slides.map(\.title)
        #expect(titles == ["Opening", "Second", "Third"])
        #expect(!titles.contains { $0 == nil })
    }

    /// Slides must be bound to a layout that declares a title, or the binding
    /// has nothing to inherit from — this is what "Blank" was doing wrong.
    @Test func slidesAreBoundToALayoutThatDeclaresATitle() throws {
        let deck = try Presentation()
        try deck.titleSlide("T")
        try deck.bulletSlide("B", [])
        try deck.slides.remove(at: 0)   // the default blank slide, as Lectern does

        let reopened = try Presentation(data: deck.serializedData())
        for index in 0..<reopened.slides.count {
            let slide = try reopened.slides.slide(at: index)
            let layout = try #require(slide.layout?.name)
            #expect(layout != "Blank", "slide \(index + 1) is still on the Blank layout")
        }
    }

    /// One `p:ph` per shape: marking twice would produce invalid XML that
    /// PowerPoint repairs on open.
    @Test func markingTwiceLeavesOnePlaceholder() throws {
        let deck = try Presentation()
        let slide = try deck.bulletSlide("Once", [])
        let title = try #require(slide.title)

        title.markAsPlaceholder(type: "title")
        title.markAsPlaceholder(type: "title")

        let nvPr = try #require(title.element.firstChild(named: "p:nvSpPr")?
            .firstChild(named: "p:nvPr"))
        #expect(nvPr.children(named: "p:ph").count == 1)
    }

    @Test func theWrittenDeckStillPassesRostrumsOwnLint() throws {
        let deck = try Presentation()
        try deck.titleSlide("T", subtitle: "S")
        try deck.bulletSlide("B", ["one", "two"])
        let reopened = try Presentation(data: deck.serializedData())
        #expect(try reopened.validate().isEmpty)
    }

    @Test func theSameDeckStillSerializesToTheSameBytes() throws {
        func build() throws -> Data {
            let deck = try Presentation()
            try deck.titleSlide("T", subtitle: "S")
            try deck.bulletSlide("B", ["one"])
            return try deck.serializedData()
        }
        #expect(try build() == build())
    }
}
