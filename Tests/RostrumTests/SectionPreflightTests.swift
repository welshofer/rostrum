import Foundation
import Testing
@testable import Rostrum

@Suite struct SectionPreflightTests {
    private func sectionedDeck(containerPrefix: String) throws
        -> (deck: Presentation, container: XML.Element, extensionElement: XML.Element, list: XML.Element) {
        let deck = try Presentation()
        for _ in 0..<2 { _ = try deck.slides.add() }
        try deck.setSections([("First", 0), ("Last", 2)])
        let root = try deck.presentationPart.dom()
        let container = try #require(root.firstChild(named: "p:extLst"))
        let ext = try #require(container.children(named: "p:ext").first { $0[attribute: "uri"] == SectionExt.uri })
        let list = try #require(ext.firstChild(named: "p14:sectionLst"))
        let prefix = containerPrefix.isEmpty ? "" : containerPrefix + ":"
        container.name = prefix + "extLst"
        container[attribute: containerPrefix.isEmpty ? "xmlns" : "xmlns:" + containerPrefix] = MinimalTemplate.nsP
        ext.name = prefix + "ext"
        deck.presentationPart.markDirty()
        return (deck, container, ext, list)
    }

    @Test(arguments: ["pres", ""])
    func aliasedAndDefaultNamespaceContainersStillMaintainMembership(prefix: String) throws {
        let fixture = try sectionedDeck(containerPrefix: prefix)
        let deck = fixture.deck
        let containerName = fixture.container.name
        let extensionName = fixture.extensionElement.name
        let beforeRead = try deck.serializedData()
        #expect(deck.sections.count == 2)
        #expect(try deck.sections.membership() != nil)
        #expect(try deck.serializedData() == beforeRead)

        _ = try deck.slides.add()
        #expect(try deck.sections[0].slideIndices == [0, 1])
        #expect(try deck.sections[1].slideIndices == [2, 3])
        #expect(fixture.container.name == containerName)
        #expect(fixture.extensionElement.name == extensionName)
        #expect(fixture.extensionElement.childElements.contains { $0 === fixture.list })
        let reopened = try Presentation(data: try deck.serializedData())
        #expect(Array(reopened.sections).flatMap(\.slideIndices) == [0, 1, 2, 3])
        #expect(try reopened.sections[1].slideIndices == [2, 3])
    }

    @Test(arguments: ["duplicate-extension", "duplicate-list", "wrong-namespace", "undeclared"])
    func potentialMalformedSectionsStillRefuseSlideMutationsAtomically(kind: String) throws {
        let fixture = try sectionedDeck(containerPrefix: "pres")
        let deck = fixture.deck
        switch kind {
        case "duplicate-extension":
            fixture.container.appendElement(fixture.extensionElement.deepCopy())
        case "duplicate-list":
            fixture.extensionElement.appendElement(fixture.list.deepCopy())
        case "wrong-namespace":
            fixture.list.name = "other:sectionLst"
            fixture.list[attribute: "xmlns:other"] = "urn:wrong"
        default:
            fixture.list.name = "undeclared:sectionLst"
        }
        deck.presentationPart.markDirty()
        let before = try deck.serializedData()
        #expect(throws: RostrumError.self) { _ = try deck.slides.add() }
        #expect(throws: RostrumError.self) { try deck.slides.remove(at: 0) }
        #expect(throws: RostrumError.self) { try deck.slides.move(from: 0, to: 2) }
        #expect(throws: RostrumError.self) { _ = try deck.slides.duplicate(at: 0) }
        #expect(throws: RostrumError.self) { _ = try deck.slides.importAll(from: Presentation()) }
        #expect(deck.slides.count == 3)
        #expect(try deck.serializedData() == before)
    }

    @Test(arguments: ["absent", "empty", "unrelated"])
    func sectionlessReadsAndSlideAddsPreserveUnrelatedExtensionMarkup(kind: String) throws {
        let deck = try Presentation()
        let root = try deck.presentationPart.dom()
        var container: XML.Element?
        if kind != "absent" {
            let extList = XML.Element("p:extLst", children: [
                .comment("keep extension-list comment"),
                .processingInstruction(target: "keep", data: "extension-list instruction"),
            ])
            if kind == "unrelated" {
                let payload = XML.Element("foreign:payload", attributes: [("xmlns:foreign", "urn:opaque")],
                                          children: [.text(" retain whitespace ")])
                // A nested lookalike is opaque payload, not the presentation's
                // section extension, even though its URI is the section URI.
                payload.appendElement(XML.Element("p:ext", attributes: [("uri", SectionExt.uri)],
                                                  children: [.element(XML.Element("foreign:sectionLst"))]))
                extList.appendElement(XML.Element("p:ext", attributes: [("uri", "urn:unrelated")],
                                                  children: [.element(payload)]))
            }
            root.appendElement(extList)
            container = extList
            deck.presentationPart.markDirty()
        }
        let extensionMarkup = container?.serialized()
        let beforeRead = try deck.serializedData()
        #expect(deck.sections.count == 0)
        #expect(try deck.sections.membership() == nil)
        #expect(try deck.serializedData() == beforeRead)

        _ = try deck.slides.add()
        #expect(deck.slides.count == 2)
        #expect(deck.sections.count == 0)
        #expect(try deck.sections.membership() == nil)
        #expect(root.firstChild(named: "p:extLst")?.serialized() == extensionMarkup)
        if let container {
            #expect(root.childElements.contains { $0 === container })
        }
        let reopened = try Presentation(data: try deck.serializedData())
        #expect(reopened.slides.count == 2)
        #expect(reopened.sections.count == 0)
        #expect(try reopened.presentationPart.dom().firstChild(named: "p:extLst")?.serialized() == extensionMarkup)
    }

    @Test func publicDOMCanGainSectionsAfterAnAbsentLookup() throws {
        let deck = try Presentation()
        let slides = deck.slides
        let sections = deck.sections
        #expect(try sections.membership() == nil)
        _ = try slides.add()
        #expect(try sections.membership() == nil)

        // Install section XML through the exposed DOM, without a section API
        // call that could invalidate a cached absence on either retained view.
        let source = try Presentation()
        _ = try source.slides.add()
        try source.setSections([("All", 0)])
        let sourceRoot = try source.presentationPart.dom()
        let extensionXML = try #require(sourceRoot.firstChild(named: "p:extLst"))
        try deck.presentationPart.dom().appendElement(extensionXML.deepCopy())
        deck.presentationPart.markDirty()
        _ = try slides.add()
        #expect(slides.count == 3)
        #expect(sections.count == 1)
        #expect(try sections[0].slideIndices == [0, 1, 2])
        let reopened = try Presentation(data: try deck.serializedData())
        #expect(try reopened.sections[0].slideIndices == [0, 1, 2])
    }
}
