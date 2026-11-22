import Foundation
import Testing
@testable import Rostrum

@Suite struct OutlineTableAndCommentPerfTests {
    @Test func largeRaggedTableOutlineExtractsExactCellsWithoutRescanningRows() throws {
        let deck = try Presentation()
        let slide = try deck.slides[0]
        let rowCount = 200
        let columnCount = 50
        let table = try slide.shapes.addTable(
            rows: rowCount,
            columns: columnCount,
            frame: Rect(x: .inches(0.5), y: .inches(0.5), width: .inches(12), height: .inches(6))
        )

        var expected: [[String]] = []
        expected.reserveCapacity(rowCount)
        let snapshot = TableGridSnapshot(table.tbl)
        for r in 0..<rowCount {
            var expectedRow: [String] = []
            expectedRow.reserveCapacity(columnCount)
            for c in 0..<columnCount {
                let val = "R\(r)C\(c)\nLine2  "
                TableCell(tc: snapshot.cells[r][c], part: table.part, package: table.package, owner: table).text = "  \(val)"
                expectedRow.append("R\(r)C\(c)\nLine2")
            }
            expected.append(expectedRow)
        }

        // Make row 137 ragged (drop trailing 10 <a:tc> elements while keeping 50 grid columns)
        // and omit <a:txBody> on one cell in row 42 to verify pure-read blank handling.
        let raggedRow = snapshot.rows[137]
        var kept = 0
        raggedRow.children.removeAll { node in
            guard case .element(let el) = node, el.name == "a:tc" else { return false }
            defer { kept += 1 }
            return kept >= 40
        }
        for c in 40..<columnCount {
            expected[137][c] = ""
        }
        snapshot.cells[42][7].removeChildren(named: "a:txBody")
        expected[42][7] = ""
        slide.part.markDirty()

        let outline = deck.outline()
        #expect(outline.warnings.isEmpty)
        let extracted = try #require(outline.slides.first?.tables.first?.rows)
        #expect(extracted == expected)
    }

    @Test func oneHundredNamespaceAliasedCommentsReadEditReplyAndFilterDeleteCleanly() throws {
        let deck = try Presentation()
        let slide = try deck.slides[0]
        let shape = try slide.shapes.addTextBox(
            Rect(x: .inches(1), y: .inches(1), width: .inches(4), height: .inches(1))
        )
        shape.textFrame?.text = "Target shape text for comment anchors"
        let shapeID = try #require(
            shape.element.childElements.first?.firstChild(named: "p:cNvPr")?[attribute: "id"].flatMap(Int.init)
        )
        let slideID = try slide.slideID()

        let count = 100
        for i in 0..<count {
            let anchor: CommentAnchor = (i % 3 == 0)
                ? .slide(slideID: slideID)
                : (i % 3 == 1)
                    ? .shape(slideID: slideID, shapeID: shapeID)
                    : .text(slideID: slideID, shapeID: shapeID, start: 0, length: 6)
            let c = try slide.addComment(
                "Thread \(i) line 1\nThread \(i) line 2",
                author: "Reviewer \(i % 5)",
                at: (x: .inches(0.5), y: .inches(0.5)),
                anchoredTo: anchor
            )
            // Immediate read + reply + reply edit during authoring loop (PERF-2-BF1 case 1 & 2).
            #expect(c.text.hasPrefix("Thread \(i)"))
            if i % 4 == 0 {
                let r = try c.addReply("Initial reply \(i)", author: "Editor")
                try r.setText("Reply to \(i)")
            }
        }

        let commentPart = try #require(
            slide.part.rels.items.first(where: { $0.type == ModernComments.commentsRelType }).flatMap {
                try? deck.package.part(at: PackURI.resolve(target: $0.target, relativeTo: slide.part.uri.baseURI))
            }
        )
        commentPart.flushIfDirty()
        let aliasedXML = String(decoding: commentPart.blob, as: UTF8.self)
            .replacingOccurrences(of: " xmlns:p188=\"\(ModernComments.ns)\"", with: "")
            .replacingOccurrences(of: " xmlns:a=\"\(MinimalTemplate.nsA)\"", with: "")
            .replacingOccurrences(of: " xmlns:pc=\"\(ModernComments.nsPC)\"", with: "")
            .replacingOccurrences(of: " xmlns:ac=\"\(ModernComments.nsAC)\"", with: "")
            .replacingOccurrences(
                of: "<p188:cmLst",
                with: "<mod:cmLst xmlns:mod=\"\(ModernComments.ns)\" xmlns:dml=\"\(MinimalTemplate.nsA)\" xmlns:cmdp=\"\(ModernComments.nsPC)\" xmlns:cmdd=\"\(ModernComments.nsAC)\""
            )
            .replacingOccurrences(of: "</p188:cmLst>", with: "</mod:cmLst>")
            .replacingOccurrences(of: "p188:", with: "mod:")
            .replacingOccurrences(of: "a:", with: "dml:")
            .replacingOccurrences(of: "pc:", with: "cmdp:")
            .replacingOccurrences(of: "ac:", with: "cmdd:")
        commentPart.replaceBlob(Data(aliasedXML.utf8))

        let comments = slide.comments
        #expect(comments.count == count)

        for (i, comment) in comments.enumerated() {
            #expect(comment.textParagraphs == ["Thread \(i) line 1", "Thread \(i) line 2"])
            #expect(comment.position?.x == .inches(0.5))
            let expectedAnchor: CommentAnchor = (i % 3 == 0)
                ? .slide(slideID: slideID)
                : (i % 3 == 1)
                    ? .shape(slideID: slideID, shapeID: shapeID)
                    : .text(slideID: slideID, shapeID: shapeID, start: 0, length: 6)
            #expect(comment.anchor == expectedAnchor)
            try comment.setText("Updated \(i)")
            if i % 4 == 0 {
                #expect(comment.replies.count == 1)
                #expect(comment.replies[0].text == "Reply to \(i)")
                try comment.replies[0].setText("Updated reply \(i)")
            } else if i % 4 == 1 {
                let added = try comment.addReply("Added reply \(i)", author: "Editor")
                try added.setText("Edited added reply \(i)")
                #expect(comment.text == "Updated \(i)")
            }
        }

        // Reply deletion across threads + forward front-deletion loop (PERF-2-BF1 case 3 & PERF-2-BF2).
        for (i, comment) in comments.enumerated() where i % 4 == 1 {
            for reply in comment.replies {
                try reply.delete()
            }
            #expect(comment.replies.isEmpty)
        }
        for i in 0..<20 {
            try comments[i].delete()
            #expect(comments[i].textParagraphs.isEmpty)
            #expect(comments[i].anchor == nil)
        }
        #expect(throws: RostrumError.self) { try comments[0].setText("detached") }
        #expect(throws: RostrumError.self) { try comments[0].delete() }

        let reopened = try Presentation(data: try deck.serializedData())
        let reopenedComments = try reopened.slides[0].comments
        #expect(reopenedComments.count == count - 20)
        #expect(reopenedComments[0].text == "Updated 20")
        #expect(reopenedComments[0].replies[0].text == "Updated reply 20")
        #expect(reopenedComments[1].replies.isEmpty)
        #expect(reopenedComments[count - 21].text == "Updated 99")
        #expect(try reopened.validate().isEmpty)
    }
}
