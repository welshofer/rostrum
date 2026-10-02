import Foundation
import Testing
@testable import Rostrum

@Suite struct MetadataPreservationTests {
    @Test func movedAndTransferredSectionMembersKeepExtensionsAndBindings() throws {
        let deck = try Presentation()
        _ = try deck.slides.add(); _ = try deck.slides.add()
        try deck.setSections([("A", 0), ("B", 1)])
        let first = try deck.sections[0].element
        let member = try #require(first.firstChild(named: "p14:sldIdLst")?.firstChild(named: "p14:sldId"))
        let id = try #require(member[attribute: "id"])
        first[attribute: "xmlns:custom"] = "urn:original-section"
        member[attribute: "custom:tag"] = "retain"
        member.appendElement(XML.Element("custom:extension", children: [.comment("retain")]))
        let second = try deck.sections[1].element
        second[attribute: "xmlns:custom"] = "urn:destination-section"
        deck.presentationPart.markDirty()
        try deck.slides.move(from: 0, to: 2)
        let moved = try #require(second.firstChild(named: "p14:sldIdLst")?.children(named: "p14:sldId").first { $0[attribute: "id"] == id })
        #expect(moved === member)
        #expect(moved[attribute: "custom:tag"] == "retain")
        #expect(moved[attribute: "xmlns:custom"] == "urn:original-section")
        #expect(moved.firstChild(named: "custom:extension") != nil)
        try deck.sections.remove(at: 1)
        let transferred = try #require(first.firstChild(named: "p14:sldIdLst")?.children(named: "p14:sldId").first { $0[attribute: "id"] == id })
        #expect(transferred === member)
        #expect(transferred.firstChild(named: "custom:extension")?.serialized().contains("<!--retain-->") == true)
        let reopened = try Presentation(data: try deck.serializedData())
        let final = try #require(try reopened.sections[0].element.firstChild(named: "p14:sldIdLst")?.children(named: "p14:sldId").first { $0[attribute: "id"] == id })
        #expect(final[attribute: "xmlns:custom"] == "urn:original-section")
    }

    @Test(arguments: [false, true]) func sourceAuthorRelationshipsCopyAndReopenWithoutMutation(legacy: Bool) throws {
        let source = try Presentation()
        let slide = try source.slides[0]
        if legacy { _ = try slide.addLegacyComment("text", author: "Source") }
        else { _ = try slide.addComment("text", author: "Source") }
        let type = legacy ? LegacyComments.authorsRelType : ModernComments.authorsRelType
        let authors = try source.presentationPart.related(by: type, in: source.package)
        let root = try authors.dom()
        let record = try #require(legacy ? LegacyComments.elements(root, named: "cmAuthor").first : AnnotationAuthorImport.authorElements(root).first)
        let payload = source.package.addPart(uri: PackURI("/ppt/custom/author-extra.xml"), contentType: "application/xml", blob: Data("<custom>keep</custom>".utf8))
        let id = authors.rels.add(type: "urn:author-extension", target: authors.uri.relativeReference(to: payload.uri))
        record.appendElement(XML.Element("custom:payload", attributes: [("xmlns:custom", "urn:review"), ("xmlns:r", MinimalTemplate.nsR), ("r:id", id)]))
        authors.markDirty()
        let sourceBytes = try source.serializedData()
        let dest = try Presentation()
        _ = try dest.slides.import(from: source, at: 0)
        let importedAuthors = try dest.presentationPart.related(by: type, in: dest.package)
        let rel = try #require(importedAuthors.rels.first(ofType: "urn:author-extension"))
        let importedPayload = try dest.package.part(at: PackURI.resolve(target: rel.target, relativeTo: importedAuthors.uri.baseURI))
        #expect(importedPayload.blob == payload.blob)
        #expect(try importedAuthors.dom().serialized().contains("r:id=\"" + rel.rId + "\""))
        let saved = try dest.serializedData()
        let reopened = try Presentation(data: saved)
        #expect(try reopened.serializedData() == saved)
        _ = try dest.slides.importAll(from: source)
        #expect(importedAuthors.rels.items.count == 1)
        #expect((legacy ? LegacyComments.elements(try importedAuthors.dom(), named: "cmAuthor") : AnnotationAuthorImport.authorElements(try importedAuthors.dom())).count == 1)
        #expect(try source.serializedData() == sourceBytes)
        // Duplication shares presentation-owned authors and retains their graph.
        _ = try source.slides.duplicate(at: 0)
        #expect(authors.rels.relationship(withId: id) != nil)
    }

}
