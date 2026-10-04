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

    @Test func duplicatedCommentsRetargetAnchorsAndKeepIndependentThreads() throws {
        let deck = try Presentation()
        let original = try deck.slides[0]
        let resolved = try original.addComment("resolved thread", author: "Reviewer")
        try resolved.addReply("reply", author: "Editor")
        resolved.resolve()
        let open = try original.addComment("open thread", author: "Reviewer")
        let unknown = XML.Element("foreign:payload", attributes: [
            ("xmlns:foreign", "urn:foreign"), ("id", "opaque-id"), ("sldId", "opaque-slide"),
        ], children: [.comment("retain comment"), .processingInstruction(target: "opaque", data: "value")])
        open.cm.appendElement(unknown)
        open.part.markDirty()
        let authors = try deck.package.part(at: PackURI("/ppt/authors.xml"))
        authors.flushIfDirty()
        let authorsBefore = authors.blob
        let originalIDs = Set(original.comments.flatMap { [$0.cm[attribute: "id"]!] + $0.replies.map { $0.cm[attribute: "id"]! } })
        let copy = try deck.slides.duplicate(at: 0)
        #expect(copy.comments.count == 2)
        #expect(copy.comments[0].isResolved)
        #expect(!copy.comments[1].isResolved)
        #expect(copy.comments[0].authorName == "Reviewer")
        #expect(copy.comments[0].replies[0].authorName == "Editor")
        #expect(copy.comments[1].cm.firstChild(named: "foreign:payload")?.serialized() == unknown.serialized())
        let copiedIDs = Set(copy.comments.flatMap { [$0.cm[attribute: "id"]!] + $0.replies.map { $0.cm[attribute: "id"]! } })
        #expect(copiedIDs.count == 3)
        #expect(originalIDs.isDisjoint(with: copiedIDs))
        #expect(authors.blob == authorsBefore)
        #expect(copy.comments[0].part.uri != resolved.part.uri)
        for comment in copy.comments {
            let mark = try #require(comment.cm.firstChild(named: "pc:sldMkLst")?.firstChild(named: "pc:sldMk"))
            #expect(mark[attribute: "sldId"] == String(try copy.slideID()))
        }
        copy.comments[1].resolve()
        try copy.comments[0].addReply("copy reply", author: "Editor")
        try original.comments[1].addReply("original reply", author: "Reviewer")
        let reopened = try Presentation(data: try deck.serializedData())
        #expect(try !reopened.slides[0].comments[1].isResolved)
        #expect(try reopened.slides[1].comments[1].isResolved)
        #expect(try reopened.slides[0].comments[0].replies.map(\.text) == ["reply"])
        #expect(try reopened.slides[1].comments[0].replies.map(\.text) == ["reply", "copy reply"])
        #expect(try reopened.slides[0].comments[1].replies.map(\.text) == ["original reply"])
        #expect(try reopened.slides[1].comments[1].replies.isEmpty)
        for slide in reopened.slides {
            for comment in slide.comments {
                #expect(comment.cm.firstChild(named: "pc:sldMkLst")?.firstChild(named: "pc:sldMk")?[attribute: "sldId"]
                    == String(try slide.slideID()))
            }
        }
    }

    @Test(arguments: [0, 1]) func deletingEitherDuplicatePreservesOtherComments(index: Int) throws {
        let deck = try Presentation()
        let comment = try deck.slides[0].addComment("thread", author: "Reviewer")
        try comment.addReply("reply", author: "Editor")
        try deck.slides.duplicate(at: 0)
        let removedURI = try deck.slides[index].comments[0].part.uri
        let survivingURI = try deck.slides[1 - index].comments[0].part.uri
        try deck.slides.remove(at: index)
        #expect(deck.package.parts[removedURI] == nil)
        #expect(deck.package.parts[survivingURI] != nil)
        let reopened = try Presentation(data: try deck.serializedData())
        #expect(try reopened.slides[0].comments[0].text == "thread")
        #expect(try reopened.slides[0].comments[0].replies[0].text == "reply")
        #expect(try reopened.slides[0].comments[0].authorName == "Reviewer")
        #expect(try reopened.validate().isEmpty)
    }

    @Test func duplicateUsesNamespaceAwareAnchorsAndDeterministicIDs() throws {
        let seed = try Presentation()
        let comment = try seed.slides[0].addComment("thread", author: "Reviewer")
        try comment.addReply("reply", author: "Editor")
        comment.part.flushIfDirty()
        let xml = String(decoding: comment.part.blob, as: UTF8.self)
            .replacingOccurrences(of: "p188", with: "modern")
            .replacingOccurrences(of: "pc:", with: "anchor:")
            .replacingOccurrences(of: "xmlns:pc", with: "xmlns:anchor")
        comment.part.replaceBlob(Data(xml.utf8))
        let seedBytes = try seed.serializedData()
        let first = try Presentation(data: seedBytes)
        let second = try Presentation(data: seedBytes)
        let duplicated = try first.slides.duplicate(at: 0)
        try second.slides.duplicate(at: 0)
        #expect(try first.serializedData() == second.serializedData())
        let part = try duplicated.part.related(by: ModernComments.commentsRelType, in: first.package)
        let root = try part.dom()
        let cm = try #require(root.firstChild(named: "modern:cm"))
        #expect(cm.firstChild(named: "anchor:sldMkLst")?.firstChild(named: "anchor:sldMk")?[attribute: "sldId"]
            == String(try duplicated.slideID()))
        let sourceRoot = try first.slides[0].part.related(by: ModernComments.commentsRelType, in: first.package).dom()
        #expect(cm[attribute: "id"] != sourceRoot.firstChild(named: "modern:cm")?[attribute: "id"])
        #expect(cm.firstChild(named: "modern:replyLst")?.firstChild(named: "modern:reply")?[attribute: "id"]
            != sourceRoot.firstChild(named: "modern:cm")?.firstChild(named: "modern:replyLst")?.firstChild(named: "modern:reply")?[attribute: "id"])
    }

}
