import Foundation
import Testing
@testable import Rostrum

@Suite struct SectionNamespaceTests {
    private func fixture(prefix: String = "sec", inherited: Bool = false) throws -> (Presentation, XML.Element) {
        let deck = try Presentation()
        for _ in 0..<3 { _ = try deck.slides.add() }
        try deck.setSections([("First", 0), ("Last", 2)])
        let root = try deck.presentationPart.dom()
        let ext = try #require(root.firstChild(named: "p:extLst")?.children(named: "p:ext").first { $0[attribute: "uri"] == SectionExt.uri })
        let list = try #require(ext.firstChild(named: "p14:sectionLst"))
        var stack = [list]
        while let node = stack.popLast() {
            node.name = (prefix.isEmpty ? "" : prefix + ":") + String(node.name.dropFirst(4))
            stack.append(contentsOf: node.childElements)
        }
        list[attribute: "xmlns:p14"] = nil
        (inherited ? ext : list)[attribute: prefix.isEmpty ? "xmlns" : "xmlns:" + prefix] = SectionExt.ns
        deck.presentationPart.markDirty()
        return (deck, list)
    }

    private func assertPartition(_ deck: Presentation) throws {
        #expect(Array(deck.sections).flatMap(\.slideIndices) == Array(0..<deck.slides.count))
        #expect(try deck.sections.membership() != nil)
    }

    @Test(arguments: ["sec", ""]) func aliasesSupportEverySlideAndSectionLifecycle(prefix: String) throws {
        let (deck, list) = try fixture(prefix: prefix, inherited: true)
        let first = try deck.sections[0]
        let last = try deck.sections[1]
        let originalIDs = [first.id, last.id]
        let opaque = XML.Element("foreign:section", attributes: [("xmlns:foreign", "urn:opaque"), ("name", "untouched")], children: [.comment("keep"), .processingInstruction(target: "keep", data: "value")])
        let opaqueBytes = opaque.serialized()
        list.appendElement(opaque)
        first.element.appendElement(XML.Element("foreign:extension", attributes: [("xmlns:foreign", "urn:opaque")], children: [.comment("section payload")]))
        deck.presentationPart.markDirty()
        let beforeRead = try deck.serializedData()
        #expect(deck.sections.count == 2)
        #expect(first.slideCount == 2)
        #expect(first.slides.count == 2)
        #expect(try deck.serializedData() == beforeRead)
        _ = try deck.slides.duplicate(at: 1)
        #expect(first.slideIndices == [0, 1, 2])
        _ = try deck.slides.add()
        try deck.slides.move(from: 0, to: 4)
        try deck.slides.remove(at: 1)
        _ = try deck.slides.import(from: Presentation(), at: 0, insertAt: 1)
        _ = try deck.slides.importAll(from: Presentation())
        try assertPartition(deck)
        #expect(Array(deck.sections).map(\.id) == originalIDs)
        let split = try deck.addSection("Split", startingAtSlide: 2)
        #expect(deck.sections.count == 3)
        #expect(split.element.name == (prefix.isEmpty ? "section" : prefix + ":section"))
        try deck.sections.move(from: 2, to: 0)
        try assertPartition(deck)
        try deck.sections.remove(at: 1)
        try assertPartition(deck)
        #expect(list.childElements.contains { $0 === opaque })
        #expect(opaque.serialized() == opaqueBytes)
        let bytes = try deck.serializedData()
        let reopened = try Presentation(data: bytes)
        try assertPartition(reopened)
        #expect(try reopened.serializedData() == bytes)
        #expect(Array(reopened.sections).map(\.id) == Array(deck.sections).map(\.id))
        try deck.setSections([("Reset", 0), ("Finish", 2)])
        try assertPartition(deck)
        #expect(list.childElements.contains { $0 === opaque })
        #expect(try deck.sections[0].element.name == (prefix.isEmpty ? "section" : prefix + ":section"))
    }

    @Test func transfersAndSplitsRetainClosestBindingsAndMixedPrefixes() throws {
        let (deck, list) = try fixture()
        let first = try deck.sections[0].element
        let second = try deck.sections[1].element
        let members = try #require(first.firstChild(named: "sec:sldIdLst"))
        first[attribute: "xmlns:custom"] = "urn:outer"
        members[attribute: "xmlns:custom"] = "urn:inner"
        members[attribute: "xmlns:m"] = SectionExt.ns
        members.name = "m:sldIdLst"
        members[attribute: "xmlns"] = "urn:opaque-default"
        second[attribute: "xmlns:custom"] = "urn:destination"
        let member = try #require(members.childElements.first)
        member.name = "m:sldId"
        member[attribute: "custom:tag"] = "keep"
        member.appendElement(XML.Element("payload", children: [.comment("inherit default")]))
        let id = try #require(member[attribute: "id"])
        deck.presentationPart.markDirty()
        try deck.slides.move(from: 0, to: 3)
        #expect(member[attribute: "xmlns:custom"] == "urn:inner")
        #expect(member[attribute: "xmlns"] == "urn:opaque-default")
        #expect(member[attribute: "xmlns:m"] == SectionExt.ns)
        #expect(member.name == "m:sldId")
        try deck.sections.remove(at: 0)
        let split = try deck.addSection("Split", startingAtSlide: 2)
        #expect(split.slideIndices == [2, 3])
        #expect(split.element.childElements.first?.childElements.contains { $0 === member } == true)
        #expect(list.childElements.contains { $0 === second })
        let reopened = try Presentation(data: try deck.serializedData())
        try assertPartition(reopened)
        let final = try #require(try reopened.sections[1].element.childElements.first?.childElements.first { $0[attribute: "id"] == id })
        #expect(final.name == "m:sldId")
        #expect(final[attribute: "xmlns:custom"] == "urn:inner")
        #expect(final[attribute: "xmlns"] == "urn:opaque-default")
        #expect(final.firstChild(named: "payload")?.serialized().contains("inherit default") == true)
    }

    @Test func reboundKnownQNameLookalikesRemainOpaque() throws {
        let (deck, list) = try fixture()
        let fakeSection = XML.Element("sec:section", attributes: [("xmlns:sec", "urn:foreign")], children: [.comment("opaque section")])
        let first = try deck.sections[0].element
        let members = try #require(first.firstChild(named: "sec:sldIdLst"))
        let fakeMember = XML.Element("sec:sldId", attributes: [("xmlns:sec", "urn:foreign"), ("id", "999999")])
        let fakeList = XML.Element("sec:sldIdLst", attributes: [("xmlns:sec", "urn:foreign")])
        list.appendElement(fakeSection)
        first.appendElement(fakeList)
        members.appendElement(fakeMember)
        let opaque = [fakeSection, fakeList, fakeMember].map { $0.serialized() }
        deck.presentationPart.markDirty()
        #expect(deck.sections.count == 2)
        #expect(try deck.sections[0].slideCount == 2)
        _ = try deck.slides.duplicate(at: 0)
        try deck.slides.remove(at: 0)
        try deck.sections.move(from: 0, to: 1)
        try assertPartition(deck)
        #expect([fakeSection, fakeList, fakeMember].map { $0.serialized() } == opaque)
        #expect(list.childElements.contains { $0 === fakeSection })
        #expect(first.childElements.contains { $0 === fakeList })
        #expect(members.childElements.contains { $0 === fakeMember })
    }

    @Test(arguments: ["stale", "duplicate", "member-namespace", "list-namespace", "undeclared"])
    func invalidPartitionsAndNamespacesRefuseAtomically(kind: String) throws {
        let (deck, list) = try fixture()
        let first = try deck.sections[0].element
        let members = try #require(first.firstChild(named: "sec:sldIdLst"))
        switch kind {
        case "stale": members.appendElement(XML.Element("sec:sldId", attributes: [("id", "999")]))
        case "duplicate": first.appendElement(XML.Element("sec:sldIdLst"))
        case "member-namespace": members[attribute: "xmlns:sec"] = "urn:wrong"
        case "list-namespace": list[attribute: "xmlns:sec"] = "urn:wrong"
        default: list[attribute: "xmlns:sec"] = nil
        }
        deck.presentationPart.markDirty()
        let before = try deck.serializedData()
        #expect(throws: RostrumError.self) { _ = try deck.slides.add() }
        #expect(throws: RostrumError.self) { try deck.slides.remove(at: 0) }
        #expect(throws: RostrumError.self) { try deck.slides.move(from: 0, to: 3) }
        #expect(throws: RostrumError.self) { _ = try deck.slides.duplicate(at: 0) }
        #expect(throws: RostrumError.self) { _ = try deck.slides.importAll(from: Presentation()) }
        #expect(throws: RostrumError.self) { try deck.sections.move(from: 0, to: 1) }
        #expect(throws: RostrumError.self) { try deck.sections.remove(at: 0) }
        if kind != "stale" {
            #expect(throws: RostrumError.self) { _ = try deck.addSection("Refuse", startingAtSlide: 1) }
            #expect(throws: RostrumError.self) { try deck.setSections([("Refuse", 0)]) }
        }
        #expect(try deck.serializedData() == before)
    }

    @Test func resettingSectionsRetainsOriginalMemberPayloadAndListMarkup() throws {
        let (deck, list) = try fixture(prefix: "", inherited: true)
        let member = try #require(try deck.sections[0].element.firstChild(named: "sldIdLst")?.childElements.first)
        member[attribute: "extra"] = "retained"
        member.appendElement(XML.Element("foreign:payload", attributes: [("xmlns:foreign", "urn:opaque")]))
        list.children.insert(.processingInstruction(target: "keep", data: "list"), at: 0)
        let opaque = XML.Element("foreign:payload", attributes: [("xmlns:foreign", "urn:opaque")])
        list.appendElement(opaque)
        deck.presentationPart.markDirty()
        try deck.setSections([("Reset", 0)])
        let entries = try #require(try deck.sections[0].element.firstChild(named: "sldIdLst"))
        #expect(entries.childElements.contains { $0 === member })
        #expect(member[attribute: "extra"] == "retained")
        #expect(member.firstChild(named: "foreign:payload") != nil)
        #expect(list.childElements.contains { $0 === opaque })
        #expect(list.serialized().contains("<?keep list?>"))
        try assertPartition(try Presentation(data: try deck.serializedData()))
    }
}
