import Foundation
import Testing
@testable import Rostrum

@Suite struct CommentsTests {
    @Test func commentRoundTripsWithAuthorAndReply() throws {
        let deck = try Presentation()
        let comment = try deck.slides[0].addComment(
            "Needs more cowbell.", author: "Jane Reviewer", at: (x: .inches(1), y: .inches(1)))
        try comment.addReply("Agreed, will fix.", author: "Sam Editor")

        let reopened = try Presentation(data: try deck.serializedData())
        let comments = try reopened.slides[0].comments
        #expect(comments.count == 1)
        #expect(comments[0].text == "Needs more cowbell.")
        #expect(comments[0].authorName == "Jane Reviewer")
        #expect(comments[0].replies.count == 1)
        #expect(comments[0].replies[0].text == "Agreed, will fix.")
        #expect(comments[0].replies[0].authorName == "Sam Editor")
    }

    @Test func strictChildOrderInsideCm() throws {
        let deck = try Presentation()
        let comment = try deck.slides[0].addComment("root", author: "A")
        try comment.addReply("reply", author: "B")

        let names = comment.cm.childElements.map(\.name)
        #expect(names == ["pc:sldMkLst", "p188:pos", "p188:replyLst", "p188:txBody"])
        // Anchor carries docMk then sldMk, with the slide's real sldId.
        let sldMk = comment.cm.firstChild(named: "pc:sldMkLst")!.children(named: "pc:sldMk")[0]
        #expect(sldMk[attribute: "sldId"] == "256")
    }

    @Test func partsRelsAndContentTypesAreModernFlavored() throws {
        let deck = try Presentation()
        try deck.slides[0].addComment("x", author: "A")
        let bytes = try deck.serializedData()

        let zip = try ZipReader(data: bytes)
        #expect(zip.contains("ppt/authors.xml"))
        #expect(zip.contains("ppt/comments/modernComment_1.xml"))

        let contentTypes = String(decoding: try zip.data(forEntry: "[Content_Types].xml"), as: UTF8.self)
        #expect(contentTypes.contains("application/vnd.ms-powerpoint.authors+xml"))
        #expect(contentTypes.contains("application/vnd.ms-powerpoint.comments+xml"))

        let reopened = try Presentation(data: bytes)
        // 2018/10 rel types; authors implicit from presentation, comments from slide.
        #expect(reopened.presentationPart.rels.first(ofType: ModernComments.authorsRelType)?.target == "authors.xml")
        #expect(try reopened.slides[0].part.rels.first(ofType: ModernComments.commentsRelType) != nil)

        // The in-slide commentRel ext is the LAST child of p:sld.
        let sld = try reopened.slides[0].part.dom()
        #expect(sld.childElements.last?.name == "p:extLst")
        let rId = sld.childElements.last?.firstChild(named: "p:ext")?
            .firstChild(named: "p188:commentRel")?[attribute: "r:id"]
        #expect(try reopened.slides[0].part.rels.relationship(withId: rId ?? "")?.type == ModernComments.commentsRelType)
    }

    @Test func oneAuthorsPartManyAuthorsGuidsWellFormed() throws {
        let deck = try Presentation()
        try deck.slides.add()
        try deck.slides[0].addComment("a", author: "Jane Reviewer")
        try deck.slides[1].addComment("b", author: "Jane Reviewer")
        try deck.slides[1].addComment("c", author: "Sam Editor")

        let authors = try deck.package.part(at: PackURI("/ppt/authors.xml")).dom()
            .children(named: "p188:author")
        #expect(authors.count == 2)
        for author in authors {
            let id = author[attribute: "id"]!
            #expect(id.hasPrefix("{") && id.hasSuffix("}") && id.count == 38)
            #expect(id == id.uppercased())
        }
        // Comment parts: one per slide with comments.
        let commentParts = deck.package.parts.keys.filter { $0.value.hasPrefix("/ppt/comments/") }
        #expect(commentParts.count == 2)
    }

    @Test func resolveMarksThread() throws {
        let deck = try Presentation()
        let comment = try deck.slides[0].addComment("open item", author: "A")
        comment.resolve()
        let reopened = try Presentation(data: try deck.serializedData())
        #expect(try reopened.slides[0].comments[0].isResolved)
    }
}
