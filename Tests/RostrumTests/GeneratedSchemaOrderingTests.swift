import Foundation
import Testing
@testable import Rostrum

@Suite struct GeneratedSchemaOrderingTests {
    @Test func insertionWithoutExplicitSuccessorsUsesGeneratedTable() {
        // a:rPr's children order: …, a:solidFill, …, a:latin, … — inserting a
        // solidFill with NO explicit successor list must still land before an
        // existing a:latin, driven by OOXMLSchema.
        let rPr = XML.Element("a:rPr")
        rPr.appendElement(XML.Element("a:latin", attributes: [("typeface", "X")]))
        rPr.insertChild(XML.Element("a:solidFill"))   // no beforeAnyOf
        let names = rPr.childElements.map(\.name)
        #expect(names == ["a:solidFill", "a:latin"])
    }

    @Test func getOrAddChildOrdersByGeneratedTable() {
        // p:cSld children: p:bg, p:spTree, … — adding p:bg after spTree exists
        // must place it first.
        let cSld = XML.Element("p:cSld")
        cSld.appendElement(XML.Element("p:spTree"))
        _ = cSld.getOrAddChild("p:bg")
        #expect(cSld.childElements.first?.name == "p:bg")
    }

    @Test func generatedTableHasMeaningfulCoverage() {
        // Sanity: the extracted schema is substantial, not a stub.
        #expect(OOXMLSchema.childSuccessors.count >= 40)
        #expect(OOXMLSchema.elementTags.count >= 300)
        #expect(OOXMLSchema.requiredAttributes["a:off"]?.contains("x") == true)
        // p:sldSz must precede p:notesSz in a presentation.
        #expect(OOXMLSchema.childSuccessors["p:presentation"]?["p:sldSz"]?.contains("p:notesSz") == true)
    }

    @Test func freshDeckValidatesClean() throws {
        let deck = try Presentation()
        try deck.slides.add()
        try deck.slides[0].shapes.addTextBox(Rect(x: .zero, y: .zero, width: .inches(2), height: .inches(1)))
            .textFrame?.text = "hi"
        #expect(try deck.validate().isEmpty)
    }

    @Test func validateFlagsMissingRequiredAttribute() throws {
        let deck = try Presentation()
        // Remove a required attribute (a:off requires x) to prove validate catches it.
        let off = try deck.slides[0].part.dom()
            .firstChild(named: "p:cSld")!.firstChild(named: "p:spTree")!
            .firstChild(named: "p:grpSpPr")!.firstChild(named: "a:xfrm")!.firstChild(named: "a:off")!
        off[attribute: "x"] = nil
        deck.slides[0].part.markDirty()
        let issues = try deck.validate()
        #expect(issues.contains { $0.element == "a:off" && $0.message.contains("x") })
    }
}
