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

/// `XML.Node` sits in every element's `children` array, so its stride is
/// multiplied by every node in every document Rostrum touches.
///
/// Adding the processing-instruction case with an inline `(String, String?)`
/// payload pushed the stride from 24 bytes to 40 — a two-thirds increase paid
/// on every child of every element — and that was enough to exhaust memory on
/// Linux while the suite built two 100,000-node trees in parallel. The case is
/// `indirect` now. This pins the size so it cannot drift back.
@Suite struct XMLNodeFootprintTests {

    @Test func aNodeStaysTheSizeOfItsLargestUnboxedPayload() {
        // One word of class reference or a String's two words, plus the tag.
        #expect(MemoryLayout<XML.Node>.stride == 24)
    }

    @Test func aProcessingInstructionStillRoundTripsThroughTheBox() throws {
        let root = try XML.parse(Data("<a><?deck note?><b/><?bare?></a>".utf8))
        #expect(root.serialized() == "<a><?deck note?><b/><?bare?></a>")
    }
}

/// A processing instruction with no data — `<?target?>` — is a NULL dereference
/// inside libxml2 on swift-corelibs-foundation: the process dies with SIGSEGV
/// before any Rostrum code runs, so no caller can defend against it. Rostrum
/// parses files it did not write, which makes that a denial of service rather
/// than a curiosity.
///
/// `XML.parseDocument` now gives every such instruction a payload before the
/// parser sees it, and turns that payload back into `nil` on the way out. These
/// pin both halves: it must not crash, and the original spelling must survive.
@Suite struct DatalessProcessingInstructionTests {

    private func roundTrip(_ xml: String) throws -> String {
        let document = try XML.parseDocument(Data(xml.utf8))
        let out = String(decoding: XML.document(document), as: UTF8.self)
        let declaration = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\r\n"
        return out.hasPrefix(declaration) ? String(out.dropFirst(declaration.count)) : out
    }

    @Test func theThreeSpellingsAreAllDistinctAndAllSurvive() throws {
        #expect(try roundTrip("<a><?t?></a>") == "<a><?t?></a>")
        #expect(try roundTrip("<a><?t ?></a>") == "<a><?t ?></a>")
        #expect(try roundTrip("<a><?t d?></a>") == "<a><?t d?></a>")
    }

    @Test func datalessInstructionsSurviveAnywhereTheyAreLegal() throws {
        #expect(try roundTrip("<?before?><a/>") == "<?before?><a/>")
        #expect(try roundTrip("<a/><?after?>") == "<a/><?after?>")
        #expect(try roundTrip("<a><b><?deep?></b></a>") == "<a><b><?deep?></b></a>")
        #expect(try roundTrip("<a><?one?><?two?></a>") == "<a><?one?><?two?></a>")
    }

    @Test func theNilDataIsWhatDistinguishesTheDatalessForm() throws {
        let bare = try XML.parse(Data("<a><?t?></a>".utf8))
        let spaced = try XML.parse(Data("<a><?t ?></a>".utf8))
        guard case .processingInstruction(_, let bareData) = bare.children[0],
              case .processingInstruction(_, let spacedData) = spaced.children[0] else {
            Issue.record("expected processing instructions")
            return
        }
        #expect(bareData == nil)
        #expect(spacedData == "")
    }

    /// The rewrite must not reach inside a comment or a CDATA section — what
    /// looks like an instruction there is content, and turning it into one would
    /// change the document's meaning.
    @Test func lookalikesInsideCommentsAndCDATAAreLeftAlone() throws {
        #expect(try roundTrip("<a><!-- <?t?> --></a>") == "<a><!-- <?t?> --></a>")

        // CDATA is folded into text by design (see `cdataAdjacentToTextCoalesces`),
        // so the assertion here is that the lookalike stayed *text* rather than
        // being promoted to a processing instruction by the rewrite.
        let cdata = try XML.parse(Data("<a><![CDATA[<?t?>]]></a>".utf8))
        guard case .text(let content) = cdata.children[0] else {
            Issue.record("expected the CDATA to survive as text, got \(cdata.children[0])")
            return
        }
        #expect(content == "<?t?>")
    }

    /// The token is only introduced when there is something to fix, so an
    /// ordinary document takes the untouched path.
    @Test func documentsWithoutOneAreNotRewrittenAtAll() {
        let plain = Data("<?xml version=\"1.0\"?><a><?t d?></a>".utf8)
        #expect(XML.neutralizingDatalessInstructions(plain) == nil)
    }
}
