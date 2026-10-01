import Foundation
import Testing
@testable import Rostrum

@Suite struct CommentEditingTests {
    @Test func modernTextReopenDeleteAndInvalidReplyOperationsPreserveFields() throws {
        let deck = try Presentation()
        let comment = try deck.slides[0].addComment("first\nsecond", author: "Reviewer")
        let reply = try comment.addReply("reply", author: "Editor")
        let timestamp = comment.createdTimestamp
        let id = comment.id
        let author = comment.author
        let extensionXML = XML.Element("custom:data", attributes: [("xmlns:custom", "urn:comment"), ("value", "keep")])
        comment.cm.appendElement(extensionXML)
        comment.cm[attribute: "title"] = "task metadata"
        comment.cm[attribute: "dueDate"] = "2026-10-12T00:00:00Z"
        comment.part.markDirty()
        #expect(comment.textParagraphs == ["first", "second"])
        try comment.setText("edited first\nedited second\nthird")
        try reply.setText("edited reply")
        #expect(comment.resolve())
        #expect(comment.isResolved)
        #expect(comment.reopen())
        #expect(!comment.isResolved)
        let before = try deck.serializedData()
        #expect(!reply.resolve())
        #expect(!reply.reopen())
        #expect(throws: RostrumError.self) { try reply.addReply("invalid", author: "New Author") }
        #expect(throws: RostrumError.self) { try reply.setAnchor(.slide(slideID: 256)) }
        #expect(throws: RostrumError.self) { try reply.setPosition(x: .zero, y: .zero) }
        #expect(try deck.serializedData() == before)
        #expect(reply.cm[attribute: "status"] == nil)
        #expect(comment.id == id && comment.createdTimestamp == timestamp && comment.author == author)
        #expect(comment.cm[attribute: "title"] == "task metadata")
        #expect(comment.cm[attribute: "dueDate"] == "2026-10-12T00:00:00Z")
        #expect(comment.cm.firstChild(named: "custom:data")?.serialized() == extensionXML.serialized())
        let reopened = try Presentation(data: try deck.serializedData())
        let saved = try reopened.slides[0].comments[0]
        #expect(saved.text == "edited first\nedited second\nthird")
        #expect(saved.replies[0].text == "edited reply")
        try saved.replies[0].delete()
        #expect(saved.replies.isEmpty)
        try saved.delete()
        #expect(try reopened.slides[0].comments.isEmpty)
        #expect(throws: RostrumError.self) { try saved.delete() }
    }

    @Test func slideShapeAndTextAnchorsRoundTripAndRejectInvalidTargetsAtomically() throws {
        let deck = try Presentation()
        let slide = try deck.slides[0]
        let box = try slide.shapes.addTextBox(Rect(x: .zero, y: .zero, width: .inches(3), height: .inches(1)))
        box.textFrame?.text = "Hello 😀 world"
        let shapeID = try #require(box.element.childElements.first?.firstChild(named: "p:cNvPr")?[attribute: "id"].flatMap(Int.init))
        let comment = try slide.addComment("shape", author: "Reviewer", anchoredTo: .shape(slideID: 256, shapeID: shapeID))
        #expect(comment.anchor == .shape(slideID: 256, shapeID: shapeID))
        try comment.setAnchor(.text(slideID: 256, shapeID: shapeID, start: 6, length: 2))
        try comment.setPosition(x: .inches(2), y: .inches(1))
        #expect(comment.position?.x == .inches(2))
        let before = try deck.serializedData()
        #expect(throws: RostrumError.self) { try comment.setAnchor(.text(slideID: 256, shapeID: shapeID, start: Int.max, length: 1)) }
        #expect(throws: RostrumError.self) { try comment.setAnchor(.shape(slideID: 999, shapeID: shapeID)) }
        #expect(throws: RostrumError.self) { try comment.setAnchor(.shape(slideID: 256, shapeID: 999)) }
        #expect(throws: RostrumError.self) { try slide.addComment("bad", author: "Not Added", anchoredTo: .shape(slideID: 256, shapeID: 999)) }
        #expect(try deck.serializedData() == before)
        let reopened = try Presentation(data: before)
        #expect(try reopened.slides[0].comments[0].anchor == .text(slideID: 256, shapeID: shapeID, start: 6, length: 2))
        let copy = try reopened.slides.duplicate(at: 0)
        #expect(copy.comments[0].anchor == .text(slideID: try copy.slideID(), shapeID: shapeID, start: 6, length: 2))
        let dest = try Presentation()
        let imported = try dest.slides.import(from: reopened, at: 0)
        #expect(imported.comments[0].anchor == .text(slideID: try imported.slideID(), shapeID: shapeID, start: 6, length: 2))
        try imported.comments[0].setAnchor(.slide(slideID: imported.slideID()))
        #expect(imported.comments[0].anchor == .slide(slideID: try imported.slideID()))
    }

    @Test func alternatePrefixesAndAuthorsSupportEditingAndReplies() throws {
        let deck = try Presentation()
        let comment = try deck.slides[0].addComment("first\nsecond", author: "Reviewer")
        comment.part.flushIfDirty()
        comment.part.replaceBlob(Data(String(decoding: comment.part.blob, as: UTF8.self)
            .replacingOccurrences(of: "p188", with: "modern")
            .replacingOccurrences(of: "a:", with: "drawing:")
            .replacingOccurrences(of: "xmlns:a", with: "xmlns:drawing").utf8))
        let actual = try deck.slides[0].comments[0]
        #expect(actual.textParagraphs == ["first", "second"])
        try actual.setText("single edited paragraph")
        try actual.addReply("first reply\nsecond paragraph", author: "Editor")
        let reopened = try Presentation(data: try deck.serializedData())
        #expect(try reopened.slides[0].comments[0].text == "single edited paragraph")
        #expect(try reopened.slides[0].comments[0].replies[0].textParagraphs == ["first reply", "second paragraph"])
        #expect(try reopened.validate().isEmpty)
    }

    @Test func deletingUnknownParagraphDataIsRefusedWithoutMutation() throws {
        let deck = try Presentation()
        let comment = try deck.slides[0].addComment("first\nsecond", author: "Reviewer")
        let body = try #require(comment.children("txBody").first)
        let paragraphs = comment.children("p", in: body, namespace: MinimalTemplate.nsA)
        paragraphs[1].appendElement(XML.Element("custom:opaque", attributes: [("xmlns:custom", "urn:opaque")]))
        comment.part.markDirty()
        let before = try deck.serializedData()
        #expect(throws: RostrumError.self) { try comment.setText("one paragraph") }
        #expect(try deck.serializedData() == before)
    }

    @Test func realPowerPointModernCommentCanBeEditedAndReopened() throws {
        let url = (Bundle.module.resourceURL ?? Bundle.module.bundleURL)
            .appendingPathComponent("Fixtures/RealDecks/MovieAndComments.pptx")
        let deck = try Presentation(data: Data(contentsOf: url))
        let slide = try #require(Array(deck.slides).first { !$0.comments.isEmpty })
        let comment = try #require(slide.comments.first)
        let id = comment.id
        let author = comment.author
        let anchor = comment.anchor
        try comment.setText("Edited Office comment\nSecond paragraph")
        #expect(comment.resolve())
        let reopened = try Presentation(data: try deck.serializedData())
        let saved = try #require(Array(reopened.slides).flatMap(\.comments).first { $0.id == id })
        #expect(saved.textParagraphs == ["Edited Office comment", "Second paragraph"])
        #expect(saved.author == author)
        #expect(saved.anchor == anchor)
        #expect(saved.isResolved)
    }
}

@Suite struct LegacyCommentTests {
    private func independentFixture() throws -> Presentation {
        let deck = try Presentation()
        let authors = deck.package.addPart(uri: PackURI("/custom/legacyAuthors.xml"),
            contentType: LegacyComments.authorsContentType, blob: Data("""
            <?xml version="1.0"?><?producer legacy?>
            <q:cmAuthorLst xmlns:q="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:f="urn:legacy-unknown"><q:cmAuthor id="0" name="Fixture Author" initials="FA" lastIdx="7" clrIdx="3"><f:identity token="keep"/></q:cmAuthor></q:cmAuthorLst>
            """.utf8))
        deck.presentationPart.rels.add(type: LegacyComments.authorsRelType,
                                      target: deck.presentationPart.uri.relativeReference(to: authors.uri))
        let comments = deck.package.addPart(uri: PackURI("/custom/legacyComments.xml"), contentType: LegacyComments.contentType,
            blob: Data("""
            <?xml version="1.0"?><?producer comments?>
            <q:cmLst xmlns:q="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:f="urn:legacy-unknown"><q:cm authorId="0" dt="2006-01-30T22:45:13.597Z" idx="7"><q:pos x="914400" y="1828800"/><q:text>Original legacy text<!--text marker--></q:text><q:extLst><q:ext uri="fixture"><f:data flag="keep"/></q:ext></q:extLst></q:cm></q:cmLst>
            """.utf8))
        let slide = try deck.slides[0]
        slide.part.rels.add(type: LegacyComments.commentsRelType, target: slide.part.uri.relativeReference(to: comments.uri))
        return deck
    }

    @Test func independentLegacyFixtureSupportsEditSaveReopenAndDeletion() throws {
        let deck = try independentFixture()
        let comment = try deck.slides[0].legacyComments[0]
        #expect(comment.authorName == "Fixture Author")
        #expect(comment.id == "7")
        #expect(comment.createdTimestamp == "2006-01-30T22:45:13.597Z")
        #expect(comment.anchor == .slide(slideID: 256))
        #expect(comment.position?.x == .inches(1))
        let oldID = comment.id
        let timestamp = comment.createdTimestamp
        try comment.setText("Edited legacy\nSecond line")
        try comment.setPosition(x: .inches(3), y: .inches(2))
        #expect(comment.cm.firstChild(named: "q:text")?.serialized().contains("<!--text marker-->") == true)
        let reopened = try Presentation(data: try deck.serializedData())
        let saved = try reopened.slides[0].legacyComments[0]
        #expect(saved.text == "Edited legacy\nSecond line")
        #expect(saved.id == oldID && saved.createdTimestamp == timestamp)
        #expect(saved.authorName == "Fixture Author")
        #expect(saved.cm.firstChild(named: "q:extLst")?.serialized().contains("flag=\"keep\"") == true)
        try saved.delete()
        #expect(try reopened.slides[0].legacyComments.isEmpty)
        #expect(throws: RostrumError.self) { try saved.delete() }
    }

    @Test func legacyCreationDuplicationAndImportAllocateIndependentIndices() throws {
        let source = try independentFixture()
        let added = try source.slides[0].addLegacyComment("new legacy", author: "Fixture Author", initials: "FA")
        #expect(added.id == "8")
        let copy = try source.slides.duplicate(at: 0)
        #expect(copy.legacyComments.map(\.text) == ["Original legacy text", "new legacy"])
        #expect(Set(copy.legacyComments.compactMap(\.id)).isDisjoint(with: Set(try source.slides[0].legacyComments.compactMap(\.id))))
        try copy.legacyComments[0].setText("copy only")
        #expect(try source.slides[0].legacyComments[0].text == "Original legacy text")
        let dest = try Presentation()
        try dest.slides[0].addLegacyComment("destination", author: "Different Author")
        let imported = try dest.slides.import(from: source, at: 0)
        #expect(imported.legacyComments[0].authorName == "Fixture Author")
        let originalAuthor = try dest.slides[0].legacyComments[0].authorID
        #expect(imported.legacyComments[0].authorID != originalAuthor)
        let second = try dest.slides.import(from: source, at: 0)
        #expect(imported.legacyComments[0].authorID == second.legacyComments[0].authorID)
        #expect(imported.legacyComments[0].id != second.legacyComments[0].id)
        let authors = try LegacyComments.authorPart(in: dest.package)
        #expect(LegacyComments.elements(try authors.dom(), named: "cmAuthor").count == 2)
        let saved = try dest.serializedData()
        let reopened = try Presentation(data: saved)
        #expect(try reopened.slides[1].legacyComments[0].authorName == "Fixture Author")
        #expect(try reopened.serializedData() == saved)
        #expect(try reopened.validate().isEmpty)
    }

    @Test func legacyMissingAuthorIsAnAtomicImportFailure() throws {
        let source = try independentFixture()
        let comment = try source.slides[0].legacyComments[0]
        comment.cm[attribute: "authorId"] = "999"
        comment.part.markDirty()
        let dest = try Presentation()
        let before = try dest.serializedData()
        #expect(throws: RostrumError.self) { try dest.slides.import(from: source, at: 0) }
        #expect(try dest.serializedData() == before)
    }
}
