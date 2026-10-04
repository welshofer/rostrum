import Foundation
import Testing
@testable import Rostrum

@Suite struct SectionCompatibilityContextTests {
    private let mc = "http://schemas.openxmlformats.org/markup-compatibility/2006"
    private func fixture() throws -> (Presentation, XML.Element, XML.Element, XML.Element, XML.Element) {
        let deck = try Presentation()
        for _ in 0..<3 { _ = try deck.slides.add() }
        try deck.setSections([("First", 0), ("Last", 2)])
        let first = try deck.sections[0].element
        let last = try deck.sections[1].element
        let list = try #require(first.firstChild(named: "p14:sldIdLst"))
        let member = try #require(list.childElements.first)
        return (deck, first, last, list, member)
    }

    @Test func aliasesAndClosestXMLContextSurviveMoveTransferSplitAndReopen() throws {
        let (deck, first, last, list, member) = try fixture()
        first[attribute: "xmlns:compat"] = mc
        first[attribute: "xmlns:custom"] = "urn:custom"
        first[attribute: "compat:Ignorable"] = "custom"
        first[attribute: "compat:PreserveAttributes"] = "custom:*"
        first[attribute: "compat:PreserveElements"] = "custom:payload"
        first[attribute: "compat:ProcessContent"] = "custom:container"
        first[attribute: "xml:lang"] = "fr"
        list[attribute: "xml:lang"] = "fr-CA"
        list[attribute: "xml:space"] = "preserve"
        last[attribute: "xml:lang"] = "en"
        last[attribute: "xml:space"] = "default"
        member.appendElement(XML.Element("custom:payload", children: [.text(" retain ")]))
        deck.presentationPart.markDirty()
        try deck.slides.move(from: 0, to: 3)
        #expect(member[attribute: "xml:lang"] == "fr-CA")
        #expect(member[attribute: "xml:space"] == "preserve")
        #expect(member[attribute: "compat:Ignorable"] == "custom")
        #expect(member[attribute: "compat:PreserveAttributes"] == "custom:*")
        #expect(member[attribute: "compat:PreserveElements"] == "custom:payload")
        #expect(member[attribute: "compat:ProcessContent"] == "custom:container")
        try deck.sections.remove(at: 0)
        let split = try deck.addSection("Split", startingAtSlide: 2)
        #expect(split.element.childElements.first?.childElements.contains { $0 === member } == true)
        let bytes = try deck.serializedData()
        let reopened = try Presentation(data: bytes)
        let saved = try #require(try reopened.sections[1].element.childElements.first?.childElements.last)
        #expect(saved[attribute: "compat:Ignorable"] == "custom")
        #expect(saved[attribute: "xml:lang"] == "fr-CA")
        #expect(saved[attribute: "xml:space"] == "preserve")
        #expect(saved.firstChild(named: "custom:payload")?.textContent == " retain ")
        #expect(try reopened.serializedData() == bytes)
    }

    @Test func missingSourceLanguageAndSpaceAreResetLocally() throws {
        let (deck, _, last, _, member) = try fixture()
        last[attribute: "xml:lang"] = "en"
        last[attribute: "xml:space"] = "preserve"
        deck.presentationPart.markDirty()
        try deck.slides.move(from: 0, to: 3)
        #expect(member[attribute: "xml:lang"] == "")
        #expect(member[attribute: "xml:space"] == "default")
    }

    @Test func inheritedPolicyTokensKeepTheirDeclarationNamespaceDespiteRebinding() throws {
        let (deck, first, _, _, member) = try fixture()
        first[attribute: "xmlns:compat"] = mc
        first[attribute: "xmlns:custom"] = "urn:outer"
        first[attribute: "compat:Ignorable"] = "custom"
        first[attribute: "compat:PreserveElements"] = "custom:payload"
        member[attribute: "xmlns:custom"] = "urn:inner"
        member[attribute: "custom:opaque"] = "retain"
        deck.presentationPart.markDirty()
        try deck.slides.move(from: 0, to: 3)
        let prefix = try #require(member[attribute: "compat:Ignorable"])
        #expect(prefix != "custom")
        #expect(member[attribute: "xmlns:" + prefix] == "urn:outer")
        #expect(member[attribute: "compat:PreserveElements"] == prefix + ":payload")
        #expect(member[attribute: "xmlns:custom"] == "urn:inner")
        #expect(member[attribute: "custom:opaque"] == "retain")
    }

    @Test func ancestorPoliciesAccumulateWithoutLosingEarlierProcessContent() throws {
        let (deck, first, _, list, member) = try fixture()
        first[attribute: "xmlns:compat"] = mc
        first[attribute: "xmlns:one"] = "urn:one"
        first[attribute: "compat:Ignorable"] = "one"
        first[attribute: "compat:ProcessContent"] = "one:outer"
        list[attribute: "xmlns:two"] = "urn:two"
        list[attribute: "compat:Ignorable"] = "one two"
        list[attribute: "compat:ProcessContent"] = "two:inner"
        deck.presentationPart.markDirty()
        try deck.slides.move(from: 0, to: 3)
        #expect(member[attribute: "compat:Ignorable"] == "one two")
        #expect(member[attribute: "compat:ProcessContent"] == "one:outer two:inner")
    }

    @Test(arguments: ["Ignorable", "MustUnderstand", "ProcessContent", "UnknownPolicy"])
    func incompatibleOrUnsupportedPoliciesRefuseBeforeMutation(policy: String) throws {
        let (deck, first, last, _, _) = try fixture()
        let owner = policy == "UnknownPolicy" ? first : last
        owner[attribute: "xmlns:compat"] = mc
        owner[attribute: "xmlns:custom"] = "urn:destination-only"
        owner[attribute: "compat:" + policy] = policy == "ProcessContent" ? "custom:*" : "custom"
        if policy == "ProcessContent" {
            // The ignorable namespace is shared; only the processing policy
            // differs, and adding a local Ignorable cannot cancel that rule.
            first[attribute: "xmlns:compat"] = mc
            first[attribute: "xmlns:custom"] = "urn:destination-only"
            first[attribute: "compat:Ignorable"] = "custom"
            last[attribute: "compat:Ignorable"] = "custom"
        }
        deck.presentationPart.markDirty()
        let bytes = try deck.serializedData()
        #expect(throws: RostrumError.self) { try deck.slides.move(from: 0, to: 3) }
        #expect(throws: RostrumError.self) { try deck.sections.remove(at: 0) }
        #expect(try deck.serializedData() == bytes)
    }
}
