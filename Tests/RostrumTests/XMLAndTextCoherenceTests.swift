import Foundation
import Testing
@testable import Rostrum

@Suite("XMLAndTextCoherenceTests")
struct XMLAndTextCoherenceTests {

    @Test func disallowedXMLControlAndNoncharacterScalarsAreOmittedWhileValidScalarsRoundTrip() throws {
        let deck = try Presentation()
        let slide = try deck.slides[0]
        let box = try slide.shapes.addTextBox(
            Rect(x: .inches(1), y: .inches(1), width: .inches(6), height: .inches(2)))
        let tf = try #require(box.textFrame)
        tf.clear()
        let p = tf.addParagraph()
        _ = p.addRun("Line1\u{000B}Line2\u{0000}\u{000C}\u{001F}\u{FFFE}\u{FFFF} \u{F900}\u{FEFF}日本🎉\t\n\rEnd")
        box.name = "Box\u{000B}\u{0000}\u{FFFF}Name\tAlt"

        let dom = try slide.part.dom()
        dom.append(.comment("x-\u{000B}-y-\u{0000}"))
        dom.append(.processingInstruction(target: "mso\u{000B}app", data: "a?\u{000B}>b\u{FFFF}"))
        dom.append(.processingInstruction(target: "\u{000B}\u{0000}", data: "ignored"))
        slide.part.markDirty()

        let data = try deck.serializedData()
        let reopened = try Presentation(data: data)
        #expect(try reopened.validate().isEmpty)

        let reopenedSlide = try reopened.slides[0]
        let reopenedShape = reopenedSlide.shapes[0]
        #expect(reopenedShape.name == "BoxName\tAlt")
        let reopenedText = try #require(reopenedShape.textFrame).paragraphs[0].runs[0].text
        #expect(reopenedText == "Line1Line2 \u{F900}\u{FEFF}日本🎉\t\n\rEnd")

        let reopenedDOM = try reopenedSlide.part.dom()
        var comments: [String] = []
        var instructions: [(String, String?)] = []
        for node in reopenedDOM.children {
            switch node {
            case .comment(let body): comments.append(body)
            case .processingInstruction(let target, let payload): instructions.append((target, payload))
            default: break
            }
        }
        #expect(comments == ["x- -y- "])
        #expect(instructions.count == 1)
        #expect(instructions[0].0 == "msoapp")
        #expect(instructions[0].1 == "a? >b")
    }

    @Test func runAndTextFrameGettersDoNotMutateDOMOrDirtyCleanParts() throws {
        let slideXML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>\r
        <p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" \
        xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" \
        xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">\
        <p:cSld><p:spTree>\
        <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>\
        <p:grpSpPr/>\
        <p:sp>\
        <p:nvSpPr><p:cNvPr id="2" name="Bare"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>\
        <p:spPr/>\
        <p:txBody><a:p><a:r><a:t>Hello</a:t></a:r></a:p></p:txBody>\
        </p:sp>\
        </p:spTree></p:cSld></p:sld>
        """
        let part = Part(
            uri: PackURI("/ppt/slides/slide1.xml"),
            contentType: ContentType.slide,
            blob: Data(slideXML.utf8)
        )
        let root = try part.dom()
        let beforeXML = root.serialized()
        #expect(!part.isDirty)

        let sp = try #require(root.firstChild(named: "p:cSld")?.firstChild(named: "p:spTree")?.firstChild(named: "p:sp"))
        let txBody = try #require(sp.firstChild(named: "p:txBody"))
        let tf = TextFrame(txBody: txBody, part: part, shapeElement: sp)

        #expect(tf.wordWrap == true)
        #expect(tf.shapeAutoFit == false)
        #expect(tf.verticalAnchor == .top)
        #expect(tf.textDirection == .horizontal)
        #expect(tf.columnCount == 1)
        #expect(tf.columnSpacing == .zero)

        let run = tf.paragraphs[0].runs[0]
        #expect(run.text == "Hello")
        #expect(run.fontSize == nil)
        #expect(run.bold == false)
        #expect(run.italic == false)
        #expect(run.letterSpacing == nil)
        #expect(run.caps == nil)
        #expect(run.fontName == nil)
        #expect(run.color == nil)
        #expect(run.underline == false)
        #expect(run.strikethrough == false)
        #expect(run.strikethroughStyle == .none)
        #expect(run.baselinePercent == nil)
        #expect(run.hyperlink == nil)

        #expect(!part.isDirty)
        #expect(txBody.firstChild(named: "a:bodyPr") == nil)
        #expect(run.r.firstChild(named: "a:rPr") == nil)
        #expect(root.serialized() == beforeXML)
    }

    @Test func paragraphAddRunInsertsBeforeEndParaRPr() throws {
        let deck = try Presentation()
        let slide = try deck.slides[0]
        let box = try slide.shapes.addTextBox(
            Rect(x: .inches(1), y: .inches(1), width: .inches(5), height: .inches(2)))
        let tf = try #require(box.textFrame)
        tf.clear()
        let paragraph = tf.addParagraph()
        paragraph.alignment = .center
        _ = paragraph.addRun("First ")
        paragraph.p.appendElement(XML.Element("a:endParaRPr", attributes: [("lang", "ja-JP")]))

        let second = paragraph.addRun("Second")
        second.bold = true

        let childNames = paragraph.p.childElements.map(\.name)
        #expect(childNames == ["a:pPr", "a:r", "a:r", "a:endParaRPr"])
        #expect(second.r.childElements.map(\.name) == ["a:rPr", "a:t"])

        let reopened = try Presentation(data: try deck.serializedData())
        let reopenedSlide = try reopened.slides[0]
        let reopenedP = try #require(reopenedSlide.shapes[0].textFrame).paragraphs[0]
        #expect(reopenedP.p.childElements.map(\.name) == ["a:pPr", "a:r", "a:r", "a:endParaRPr"])
        #expect(reopenedP.plainText == "First Second")
    }

    @Test func clearedTextBodiesRestoreSchemaValidParagraphOnSerializeAndSave() throws {
        let deck = try Presentation()
        let slide = try deck.slides[0]
        let box = try slide.shapes.addTextBox(
            Rect(x: .inches(1), y: .inches(1), width: .inches(4), height: .inches(1)))
        let clearedTF = try #require(box.textFrame)
        clearedTF.txBody.removeChildren(named: "a:bodyPr")
        clearedTF.clear()
        #expect(clearedTF.txBody.children(named: "a:p").isEmpty)

        let populatedBox = try slide.shapes.addTextBox(
            Rect(x: .inches(1), y: .inches(2.5), width: .inches(4), height: .inches(1)))
        populatedBox.textFrame?.text = "Single paragraph"

        let table = try slide.shapes.addTable(
            rows: 1, columns: 1,
            frame: Rect(x: .inches(1), y: .inches(4), width: .inches(4), height: .inches(1)))
        let cell = try table.cell(0, 0)
        cell.textFrame.clear()

        let reopenedFromBytes = try Presentation(data: try deck.serializedData())
        #expect(try reopenedFromBytes.validate().isEmpty)
        let s0 = try reopenedFromBytes.slides[0]
        let reopenedCleared = try #require(s0.shapes[0].textFrame)
        #expect(reopenedCleared.txBody.childElements.map(\.name) == ["a:bodyPr", "a:lstStyle", "a:p"])
        #expect(reopenedCleared.paragraphs.count == 1)
        #expect(reopenedCleared.text == "")

        let reopenedPopulated = try #require(s0.shapes[1].textFrame)
        #expect(reopenedPopulated.paragraphs.count == 1)
        #expect(reopenedPopulated.text == "Single paragraph")

        let reopenedTableFrame = try #require(s0.shapes[2] as? TableFrame)
        let reopenedTable = try #require(reopenedTableFrame.table)
        let reopenedCell = try reopenedTable.cell(0, 0)
        #expect(reopenedCell.textFrame.paragraphs.count == 1)

        // Verify save(to:) repairs dirty cleared text bodies installed after the first serialize.
        let secondBoxTF = try #require(populatedBox.textFrame)
        secondBoxTF.clear()
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("rostrum-rel1-\(UUID().uuidString).pptx")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        try deck.save(to: tempURL)
        let reopenedFromDisk = try Presentation(contentsOf: tempURL)
        let diskSlide = try reopenedFromDisk.slides[0]
        let diskClearedTF = try #require(diskSlide.shapes[1].textFrame)
        #expect(diskClearedTF.paragraphs.count == 1)
    }
}
