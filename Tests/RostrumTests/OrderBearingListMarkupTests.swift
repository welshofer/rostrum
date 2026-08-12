import Testing
import Foundation
@testable import Rostrum

/// Reordering an order-bearing list must not quietly discard the markup
/// Rostrum does not model.
///
/// The parser learned to carry comments and processing instructions through a
/// round trip, but `replaceChildElements` rebuilt `sldIdLst`-style lists from
/// their elements alone — so moving, duplicating or merging slides threw those
/// nodes away and the round-trip promise held only until someone touched the
/// deck. These pin the repair.
@Suite struct OrderBearingListMarkupTests {

    private func list(_ xml: String) throws -> XML.Element {
        try XML.parse(Data(xml.utf8))
    }

    @Test func reorderingKeepsAComment() throws {
        let root = try list("<p:sldIdLst><p:sldId id=\"1\"/><!-- keep me --><p:sldId id=\"2\"/></p:sldIdLst>")
        var entries = root.childElements
        entries.reverse()
        root.replaceChildElements(with: entries)

        #expect(root.serialized().contains("<!-- keep me -->"))
        #expect(root.childElements.map { $0[attribute: "id"] } == ["2", "1"])
    }

    @Test func reorderingKeepsAProcessingInstruction() throws {
        let root = try list("<p:sldIdLst><?deck note?><p:sldId id=\"1\"/><p:sldId id=\"2\"/></p:sldIdLst>")
        root.replaceChildElements(with: root.childElements)

        #expect(root.serialized().contains("<?deck note?>"))
    }

    @Test func removingAnEntryStillKeepsTheComment() throws {
        let root = try list("<p:sldIdLst><p:sldId id=\"1\"/><!-- c --><p:sldId id=\"2\"/></p:sldIdLst>")
        var entries = root.childElements
        entries.removeFirst()
        root.replaceChildElements(with: entries)

        #expect(root.serialized().contains("<!-- c -->"))
        #expect(root.childElements.count == 1)
    }

    /// Formatting whitespace is not markup we owe anybody — the writer lays
    /// the list out itself, so it should still be dropped.
    @Test func insignificantWhitespaceIsStillDropped() throws {
        let root = try list("<p:sldIdLst>\n  <p:sldId id=\"1\"/>\n</p:sldIdLst>")
        root.replaceChildElements(with: root.childElements)

        #expect(root.serialized() == "<p:sldIdLst><p:sldId id=\"1\"/></p:sldIdLst>")
    }

    /// The end-to-end shape of the bug: a real deck with a comment in its
    /// slide list, moved, then read back.
    @Test func movingASlideInARealDeckKeepsTheComment() throws {
        let deck = try Presentation()
        _ = try deck.slides.add()
        _ = try deck.slides.add()

        let root = try deck.presentationPart.dom()
        let list = try #require(root.firstChild(named: "p:sldIdLst"))
        list.children.append(.comment(" authored by hand "))
        deck.presentationPart.markDirty()

        try deck.slides.move(from: 0, to: 1)

        #expect(list.serialized().contains("<!-- authored by hand -->"))
    }

    /// The reviewer's point: preserving a comment is not the same as keeping
    /// it where it was. A rebuild that changes nothing must change no bytes.
    @Test func aNoOpRebuildIsByteIdentical() throws {
        let xml = "<p:sldIdLst><p:sldId id=\"1\"/><!-- middle --><p:sldId id=\"2\"/></p:sldIdLst>"
        let root = try list(xml)
        root.replaceChildElements(with: root.childElements)

        #expect(root.serialized() == xml)
    }

    @Test func aCommentKeepsItsSlotAcrossAReorder() throws {
        let root = try list("<p:sldIdLst><p:sldId id=\"1\"/><!-- middle --><p:sldId id=\"2\"/></p:sldIdLst>")
        var entries = root.childElements
        entries.reverse()
        root.replaceChildElements(with: entries)

        #expect(root.serialized()
            == "<p:sldIdLst><p:sldId id=\"2\"/><!-- middle --><p:sldId id=\"1\"/></p:sldIdLst>")
    }

    @Test func movingASlideToItsOwnPositionChangesNothing() throws {
        let deck = try Presentation()
        _ = try deck.slides.add()
        _ = try deck.slides.add()

        let root = try deck.presentationPart.dom()
        let list = try #require(root.firstChild(named: "p:sldIdLst"))
        list.children.insert(.comment(" pinned "), at: 1)
        let before = list.serialized()

        try deck.slides.move(from: 0, to: 0)

        #expect(list.serialized() == before)
    }

    /// The reviewer found the same element-only rebuild in two more places.
    /// `Sections.set` has a public seam, so it gets the integration test;
    /// `Theme.setColor` now routes through the same helper exercised above.
    @Test func reSectioningKeepsAComment() throws {
        let deck = try Presentation()
        _ = try deck.slides.add()
        try deck.sections.set([(name: "One", startSlide: 0)])

        let root = try deck.presentationPart.dom()
        let list = try #require(Self.find("p14:sectionLst", under: root))
        list.children.append(.comment(" hand written "))

        try deck.sections.set([(name: "Renamed", startSlide: 0)])

        #expect(list.serialized().contains("<!-- hand written -->"))
        #expect(list.serialized().contains("Renamed"))
    }

    private static func find(_ name: String, under element: XML.Element) -> XML.Element? {
        if element.name == name { return element }
        for case .element(let child) in element.children {
            if let hit = find(name, under: child) { return hit }
        }
        return nil
    }
}
