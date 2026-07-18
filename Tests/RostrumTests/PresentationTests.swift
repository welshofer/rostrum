import Foundation
import Testing
@testable import Rostrum

@Suite struct PresentationTests {
    @Test func newDeckHasOneSlideAndWidescreenSize() throws {
        let deck = try Presentation()
        #expect(deck.slideCount == 1)
        let size = deck.slideSize
        #expect(size.width == MinimalTemplate.defaultSlideWidth)
        #expect(size.height == MinimalTemplate.defaultSlideHeight)
        #expect(abs(size.width.inches - 13.333333) < 0.001)
    }

    @Test func saveThenReopenRoundTrip() throws {
        let deck = try Presentation()
        let bytes = try deck.serializedData()

        let reopened = try Presentation(data: bytes)
        #expect(reopened.slideCount == 1)
        #expect(reopened.slideSize.width == deck.slideSize.width)

        // Every part survives the round trip.
        #expect(Set(reopened.package.parts.keys) == Set(deck.package.parts.keys))
    }

    @Test func slideSizeSetterPersists() throws {
        let deck = try Presentation()
        deck.slideSize = (width: .inches(10), height: .inches(7.5))

        let reopened = try Presentation(data: try deck.serializedData())
        #expect(reopened.slideSize.width == .inches(10))
        #expect(reopened.slideSize.height == .inches(7.5))
    }

    @Test func everyXMLPartParses() throws {
        let deck = try Presentation()
        let bytes = try deck.serializedData()
        let package = try OPCPackage.read(data: bytes)
        for (uri, part) in package.parts where uri.ext == "xml" {
            _ = try part.dom()
        }
    }

    @Test func requiredPresentationChildrenPresent() throws {
        let deck = try Presentation()
        let root = try deck.presentationPart.dom()
        #expect(root.name == "p:presentation")
        #expect(root.firstChild(named: "p:sldMasterIdLst") != nil)
        #expect(root.firstChild(named: "p:sldIdLst") != nil)
        #expect(root.firstChild(named: "p:sldSz") != nil)
        #expect(root.firstChild(named: "p:notesSz") != nil)
        // Every r:id in presentation.xml must resolve in its rels.
        let sldId = root.firstChild(named: "p:sldIdLst")!.childElements[0]
        let rId = sldId[attribute: "r:id"]!
        #expect(deck.presentationPart.rels.relationship(withId: rId)?.type == RelType.slide)
    }

    @Test func rejectsNonPresentationPackage() throws {
        let package = OPCPackage()
        package.addPart(
            uri: PackURI("/word/document.xml"),
            contentType: "application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml",
            blob: Data("<w:document xmlns:w=\"x\"/>".utf8))
        package.rels.add(type: RelType.officeDocument, target: "word/document.xml")
        let bytes = try package.serialize()
        #expect(throws: RostrumError.self) {
            _ = try Presentation(data: bytes)
        }
    }

    @Test func deterministicSerialization() throws {
        // Two serializations of the same in-memory deck are byte-identical.
        let deck = try Presentation()
        #expect(try deck.serializedData() == deck.serializedData())
    }
}
