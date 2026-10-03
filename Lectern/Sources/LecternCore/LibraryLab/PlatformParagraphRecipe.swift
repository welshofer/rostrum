import Foundation
import Rostrum

extension PlatformLabRecipes {
    static let paragraphSentence = "Careful spacing makes each line easy to follow while preserving the words and their individual colors. "

    static func paragraphLayout(_ options: LibraryLabOptions) throws -> LibraryLabDraft {
        let deck = try LibraryLabSupport.deck(title: "Paragraph spacing and justification")
        let before = try deck.serializedData(), font = try resource("DejaVuSans", "ttf")
        try deck.fonts.register(font)
        try deck.embedFont("DejaVu Sans", faces: .init(regular: font))
        let slide = try deck.slides[0]
        let title = try text(label(options), on: slide, in: LibraryLabSupport.frame(0.6, 0.3, 12, 0.6))
        title.fitText(fonts: deck.fonts)
        let width = options.alternative ? 4.5 : 5.7
        let body = Array(repeating: paragraphSentence, count: options.sampleSize).joined() + "A short final line."
        var fits: [Autofit] = []
        for (index, alignment) in [TextAlignment.left, .justified].enumerated() {
            let x = index == 0 ? 0.6 : 7.0
            let heading = try text(index == 0 ? "Left aligned" : "Justified interior spaces", on: slide,
                                   in: LibraryLabSupport.frame(x, 1.0, width, 0.5))
            heading.fitText(fonts: deck.fonts)
            let box = try slide.shapes.addTextBox(LibraryLabSupport.frame(x, 1.65, width, 4.6))
            box.name = index == 0 ? "Left paragraph" : "Justified paragraph"
            let frame = try require(box.textFrame, "Paragraph frame missing")
            paragraphContent(frame, body: body, alignment: alignment)
            // Exercise both public fitting entry points against identical content.
            fits.append(index == 0
                ? try require(box.fitText(fonts: deck.fonts, theme: deck.theme), "Shape fitting missing")
                : frame.fitText(in: box.frame, fonts: deck.fonts, theme: deck.theme))
        }
        let footnote = try text("\(options.sampleSize) sentences · \(width)-inch columns · regular DejaVu Sans\nFinal paragraph lines retain natural spacing. Bounded left-to-right Latin text only.",
                                on: slide, in: LibraryLabSupport.frame(0.6, 6.5, 12, 0.65))
        footnote.textFrame?.paragraphs.first?.runs.first?.fontSize = 14
        footnote.fitText(fonts: deck.fonts)

        let tableSlide = try deck.slides.add()
        try text("The same paragraph engine inside a table", on: tableSlide)
        let table = try tableSlide.shapes.addTable(rows: 1, columns: 1,
            frame: LibraryLabSupport.frame(0.7, 1.7, width, 3.8))
        table.clearBuiltInStyle()
        let cell = try table.cell(0, 0)
        cell.setPadding(left: .zero, top: .zero, right: .zero, bottom: .zero)
        cell.setBorders(Line(color: Color("276D89")))
        paragraphContent(cell.textFrame, body: paragraphSentence + "The last line remains natural.", alignment: .justified)
        let note = try text("Supported sample: Latin words, ordinary spaces, mixed sizes and colors.\n\nTabs, right-to-left and non-Latin justification remain diagnosed limitations. Distributed and low justification are not demonstrated as supported.\n\nSave/reopen checks compare exact measured span positions; this is not a general Office pixel-parity claim.",
            on: tableSlide, in: LibraryLabSupport.frame(7, 1.7, 5.4, 4.5))
        note.textFrame?.paragraphs.first?.runs.first?.fontSize = 18
        note.fitText(fonts: deck.fonts)

        let left = try paragraphGeometry(deck, named: "Left paragraph")
        let justified = try paragraphGeometry(deck, named: "Justified paragraph")
        let tableLayout = try paragraphTableGeometry(deck, width: width)
        let svg = try deck.renderSVG(slideAt: 0)
        let extraction = try exportedFiles(deck)
        return LibraryLabDraft(deck: deck, before: before, checks: [
            .init("Both public fit paths agree", fits.allSatisfy(\.fits) && fits[0] == fits[1], "Shape.fitText and TextFrame.fitText select the same fitting step for equal content."),
            .init("Interior spaces expand", paragraphExpansion(left: left, justified: justified), "Wrapped lines expand; the final paragraph line retains the left-aligned width."),
            .init("Mixed formatting remains measurable", Set(justified.lines.flatMap(\.spans).map { $0.run.color }).count == 2 && Set(justified.lines.flatMap(\.spans).map { $0.run.fontSize }).count == 2 && justified.diagnostics.isEmpty, "Two sizes and colors retain their run styles with the exact regular font."),
            .init("Table uses justified layout", tableLayout.lines.count > 1 && abs(paragraphVisibleWidth(tableLayout.lines[0], fonts: deck.fonts) - width * 72) < 0.01 && tableLayout.diagnostics.isEmpty, "A zero-padding table cell fills the same bounded width."),
            .init("Preview and extraction produced", svg.contains("<svg") && !extraction.files.isEmpty, "Real SVG and DeckExport artifacts accompany the editable PPTX.")
        ], extraFiles: extraction.files, verify: { reopened in
            let registered = reopened.registerEmbeddedFonts()
            let readLeft = try paragraphGeometry(reopened, named: "Left paragraph")
            let readJustified = try paragraphGeometry(reopened, named: "Justified paragraph")
            let readTable = try paragraphTableGeometry(reopened, width: width)
            return [
                .init("Regular face recovered", registered == ["DejaVu Sans"] && reopened.fonts.data(for: .init(family: "DejaVu Sans")) == font, "Embedded font bytes survive the saved-file path."),
                .init("Paragraph positions survive reopening", left.lines == readLeft.lines && justified.lines == readJustified.lines && paragraphExpansion(left: readLeft, justified: readJustified), "Every span, baseline, width and style matches the authored layout."),
                .init("Table positions survive reopening", tableLayout.lines == readTable.lines, "The table cell reproduces all justified spans."),
                .init("Saved SVG is deterministic", try reopened.renderSVG(slideAt: 0) == svg, "The reopened preview matches the original byte-for-byte.")
            ]
        })
    }

    private static func paragraphContent(_ frame: TextFrame, body: String, alignment: TextAlignment) {
        frame.clear()
        frame.setMargins(left: .zero, top: .zero, right: .zero, bottom: .zero)
        frame.wordWrap = true
        let paragraph = frame.addParagraph()
        paragraph.alignment = alignment
        paragraph.setNoBullet()
        for (text, size, color) in [("Readable paragraphs. ", 20.0, "276D89"), (body, 18.0, "263445")] {
            let run = paragraph.addRun(text)
            run.fontName = "DejaVu Sans"; run.fontSize = size; run.color = Color(color)
        }
    }

    /// Public owned-DOM inspection keeps this recipe outside Rostrum internals.
    static func paragraphGeometry(_ deck: Presentation, named name: String) throws -> RichTextLayout {
        let slide = try deck.slides[0]
        let shape = try require(slide.shapes.all.first { $0.name == name }, "Paragraph shape missing")
        let tree = try require(slide.part.dom().firstChild(named: "p:cSld")?.firstChild(named: "p:spTree"), "Shape tree missing")
        let node = try require(tree.children(named: "p:sp").first {
            $0.firstChild(named: "p:nvSpPr")?.firstChild(named: "p:cNvPr")?[attribute: "name"] == name
        }, "Owned paragraph DOM missing")
        let body = try require(node.firstChild(named: "p:txBody"), "Paragraph body missing")
        return RichTextLayout(textBody: body, width: shape.frame.width.points, height: shape.frame.height.points,
                              fonts: deck.fonts, theme: deck.theme)
    }

    static func paragraphTableGeometry(_ deck: Presentation, width: Double) throws -> RichTextLayout {
        let root = try deck.slides[1].part.dom()
        let body = try require(DrawingLabFixtures.nodes(root, "a:txBody").first, "Table body missing")
        return RichTextLayout(textBody: body, width: width * 72, height: 3.8 * 72,
            fonts: deck.fonts, theme: deck.theme, insets: (0, 0, 0, 0))
    }

    /// RichTextLine.width preserves trailing spaces; visible ink ends before them.
    static func paragraphVisibleWidth(_ line: RichTextLine, fonts: FontLibrary) -> Double {
        var trailing = 0.0
        for span in line.spans.reversed() {
            let spaces = span.run.text.reversed().prefix { $0 == " " }.count
            if let metrics = fonts.metrics(for: span.run.fontFamily ?? "DejaVu Sans") {
                trailing += Double(spaces) * (metrics.width(of: " ", pointSize: span.run.fontSize) + span.run.tracking)
            }
            if spaces != span.run.text.count { break }
        }
        return line.width - trailing
    }

    static func paragraphExpansion(left: RichTextLayout, justified: RichTextLayout) -> Bool {
        guard left.lines.count > 1, left.lines.count == justified.lines.count,
              let leftLast = left.lines.last, let justLast = justified.lines.last else { return false }
        return zip(left.lines.dropLast(), justified.lines.dropLast()).contains { $1.width > $0.width + 0.1 }
            && abs(leftLast.width - justLast.width) < 0.01 && left.fits && justified.fits
    }
}
