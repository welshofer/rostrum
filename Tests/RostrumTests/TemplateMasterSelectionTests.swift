import Foundation
import Testing
@testable import Rostrum

@Suite struct TemplateMasterSelectionTests {
    @Test func masterAndLayoutIDListsDetermineSelectionInsteadOfRelationshipOrder() throws {
        let deck = try Presentation()
        deck.theme.majorFont = "Georgia"
        let other = try Presentation()
        other.theme.majorFont = "Courier New"
        _ = try deck.slides.importAll(from: other)
        let main = try deck.package.mainDocumentPart()
        main.rels.setItems(main.rels.items.reversed())
        let first = try #require(deck.slideMasters.first)
        first.part.rels.setItems(first.part.rels.items.reversed())
        let bytes = try deck.serializedData()
        let reopened = try Presentation(data: bytes)
        #expect(reopened.theme.majorFont == "Georgia")
        #expect(reopened.layouts.map(\.part.uri) == reopened.slideMasters.first?.layouts.map(\.part.uri))
        let blank = try reopened.slides.add()
        #expect(blank.layout?.part.uri == reopened.layouts.first?.part.uri)
        #expect(blank.master?.part.uri == reopened.slideMasters.first?.part.uri)
        let titled = try reopened.titleSlide("Consistent first master")
        #expect(titled.master?.part.uri == reopened.slideMasters.first?.part.uri)
        // Opening/accessing the reordered streams must not reorder them itself.
        #expect(try Presentation(data: bytes).serializedData() == bytes)
    }
}
