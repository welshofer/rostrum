import Foundation
import Testing
@testable import Rostrum

@Suite struct SectionContextReviewTests {
    private func context(of target: XML.Element, in root: XML.Element) -> [String: String] {
        var pending: [(XML.Element, [String: String])] = [(root, [:])]
        while let (element, inherited) = pending.popLast() {
            var context = inherited
            for attribute in element.attributes where ["xml:lang", "xml:space", "mc:Ignorable"].contains(attribute.name) {
                context[attribute.name] = attribute.value
            }
            if element === target { return context }
            for child in element.childElements { pending.append((child, context)) }
        }
        return [:]
    }
    @Test func movedMemberKeepsInheritedCompatibilityAndXMLContext() throws {
        let deck = try Presentation()
        for _ in 0..<3 { _ = try deck.slides.add() }
        try deck.setSections([("First", 0), ("Last", 2)])
        let root = try deck.presentationPart.dom()
        let first = try deck.sections[0].element
        let last = try deck.sections[1].element
        first[attribute: "xmlns:mc"] = "http://schemas.openxmlformats.org/markup-compatibility/2006"
        first[attribute: "xmlns:custom"] = "urn:vendor"
        first[attribute: "mc:Ignorable"] = "custom"
        first[attribute: "xml:lang"] = "fr"
        first[attribute: "xml:space"] = "preserve"
        last[attribute: "xml:lang"] = "en"
        last[attribute: "xml:space"] = "default"
        let member = try #require(first.firstChild(named: "p14:sldIdLst")?.childElements.first)
        member[attribute: "custom:label"] = " keep "
        deck.presentationPart.markDirty()
        let before = context(of: member, in: root)
        try deck.slides.move(from: 0, to: 3)
        #expect(context(of: member, in: root) == before)
    }
}
