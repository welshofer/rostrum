import Foundation
import Rostrum

extension PlatformLabRecipes {
    static let tabSamples = ["12.50", "7.125", "123.4", "8", "45.67", "901.2", "3.141", "62.5", "104.75", "9.8", "27", "314.16"]
    static let tabModes: [(String, TextTabAlignment)] = [("Left", .left), ("Center", .center), ("Right", .right), ("Decimal", .decimal)]
    static let tabSentence = "\tCareful spacing keeps each column readable while ordinary spaces expand across wrapped Latin lines. The last line remains natural."

    static func tabLayout(_ options: LibraryLabOptions) throws -> LibraryLabDraft {
        let deck = try LibraryLabSupport.deck(title: "Tab stops and justified fields")
        let before = try deck.serializedData(), font = try resource("DejaVuSans", "ttf")
        try deck.fonts.register(font)
        try deck.embedFont("DejaVu Sans", faces: .init(regular: font))
        let slide = try deck.slides[0]
        let title = try text(label(options), on: slide, in: LibraryLabSupport.frame(0.5, 0.3, 12.2, 0.6))
        title.fitText(fonts: deck.fonts)
        let stop = options.alternative ? 1.8 : 1.4
        for (index, mode) in tabModes.enumerated() {
            let x = 0.5 + Double(index) * 3.15
            let heading = try text(mode.0 + " stop", on: slide, in: LibraryLabSupport.frame(x, 1.1, 2.9, 0.5))
            heading.textFrame?.paragraphs.first?.runs.first?.fontSize = 20
            try tabGuide(on: slide, x: x + stop, y: 1.8, height: 3.9, color: options.accentHex, name: mode.0 + " stop guide")
            let box = try slide.shapes.addTextBox(LibraryLabSupport.frame(x, 1.8, 2.9, 4.2))
            box.name = mode.0 + " tab fields"
            let frame = try require(box.textFrame, "Tab field frame missing")
            tabFrame(frame)
            for value in tabSamples.prefix(options.sampleSize) {
                let paragraph = frame.addParagraph()
                tabParagraph(paragraph, text: "\t" + value, stop: stop, mode: mode.1)
                paragraph.setSpacing(afterPoints: 3)
            }
        }
        let footnote = try text("\(options.sampleSize) rows per column · stops at \(stop) inches · regular DejaVu Sans\nThe guide marks the field's start, center, end, or period. Integers align their end at a decimal stop.", on: slide, in: LibraryLabSupport.frame(0.5, 6.2, 12.3, 0.85))
        footnote.textFrame?.paragraphs.first?.runs.first?.fontSize = 15
        footnote.fitText(fonts: deck.fonts)

        let second = try deck.slides.add()
        try text("Tabs and Latin justification", on: second, in: LibraryLabSupport.frame(0.5, 0.3, 12, 0.6))
        let justifiedStop = options.alternative ? 1.25 : 0.75
        for (index, alignment) in [TextAlignment.left, .justified].enumerated() {
            let x = index == 0 ? 0.6 : 7.0
            let heading = try text(index == 0 ? "Natural word spaces" : "Justified after the tab", on: second, in: LibraryLabSupport.frame(x, 1.1, 5.7, 0.5))
            heading.textFrame?.paragraphs.first?.runs.first?.fontSize = 20
            try tabGuide(on: second, x: x + justifiedStop, y: 1.8, height: 1.8, color: options.accentHex, name: "Paragraph stop guide \(index)")
            let box = try second.shapes.addTextBox(LibraryLabSupport.frame(x, 1.8, 5.7, 2.0))
            box.name = index == 0 ? "Natural tab paragraph" : "Justified tab paragraph"
            let frame = try require(box.textFrame, "Justified tab frame missing")
            tabFrame(frame)
            tabParagraph(frame.addParagraph(), text: tabSentence, stop: justifiedStop, mode: .left, alignment: alignment)
        }
        let table = try second.shapes.addTable(rows: 1, columns: 1, frame: LibraryLabSupport.frame(0.6, 4.2, 5.7, 2))
        table.clearBuiltInStyle()
        let cell = try table.cell(0, 0)
        cell.setPadding(left: .zero, top: .zero, right: .zero, bottom: .zero)
        cell.setBorders(Line(color: Color(options.accentHex)))
        tabFrame(cell.textFrame)
        tabParagraph(cell.textFrame.addParagraph(), text: tabSentence, stop: justifiedStop, mode: .left, alignment: .justified)
        let note = try text("The table cell uses the same tab-aware layout.\n\nBounded left-to-right Latin and period-decimal fields only. Final paragraph lines retain natural spacing. RTL, non-Latin and distributed justification are outside this demonstration.\n\nSave/reopen checks compare exact spans; no general Office pixel-parity claim.", on: second, in: LibraryLabSupport.frame(7, 4.2, 5.7, 2.5))
        note.textFrame?.paragraphs.first?.runs.first?.fontSize = 14
        note.fitText(fonts: deck.fonts)

        let fields = try tabModes.map { try tabGeometry(deck, named: $0.0 + " tab fields") }
        let natural = try tabGeometry(deck, named: "Natural tab paragraph", slideAt: 1)
        let justified = try tabGeometry(deck, named: "Justified tab paragraph", slideAt: 1)
        let tableLayout = try tabTableGeometry(deck)
        let svgs = try (0..<2).map { try deck.renderSVG(slideAt: $0) }
        return LibraryLabDraft(deck: deck, before: before, checks: [
            .init("All four stops anchor numeric fields", try tabAnchorsMatch(fields, count: options.sampleSize, stop: stop, fonts: deck.fonts), "Start, center, right edge and period positions match the visible guides, including integers at decimal stops."),
            .init("Tabs preserve anchors during justification", tabJustificationMatches(natural: natural, justified: justified, stop: justifiedStop), "The first field remains anchored while wrapped lines expand ordinary spaces after the last tab; the final line stays natural."),
            .init("Table shares the tab layout", tableLayout.lines == justified.lines && tableLayout.diagnostics.isEmpty, "Equal text, tab stops, font and available width produce identical table-cell spans."),
            .init("Tab sample fits without diagnostics", (fields + [natural, justified, tableLayout]).allSatisfy { $0.fits && $0.diagnostics.isEmpty }, "All numeric rows and bounded Latin paragraphs fit with the bundled regular font.")
        ], extraFiles: try exportedFiles(deck).files, verify: { reopened in
            let registered = reopened.registerEmbeddedFonts()
            let readFields = try tabModes.map { try tabGeometry(reopened, named: $0.0 + " tab fields") }
            let readNatural = try tabGeometry(reopened, named: "Natural tab paragraph", slideAt: 1)
            let readJustified = try tabGeometry(reopened, named: "Justified tab paragraph", slideAt: 1)
            let propertiesMatch = try tabModes.allSatisfy { mode in
                let shape = try require(reopened.slides[0].shapes.all.first { $0.name == mode.0 + " tab fields" }, "Reopened tab fields missing")
                return shape.textFrame?.paragraphs.count == options.sampleSize && shape.textFrame?.paragraphs.allSatisfy {
                    $0.tabStops == [TextTabStop(position: .inches(stop), alignment: mode.1)] && $0.defaultTabInterval == .inches(0.5)
                } == true
            }
            return [
                .init("Tab font recovered", registered == ["DejaVu Sans"] && reopened.fonts.data(for: .init(family: "DejaVu Sans")) == font, "The licensed embedded font survives the saved-file path."),
                .init("Public tab properties survive reopening", propertiesMatch, "Every numeric paragraph retains its stop position, alignment and default interval."),
                .init("Tab positions survive reopening", zip(fields, readFields).allSatisfy { $0.lines == $1.lines } && natural.lines == readNatural.lines && justified.lines == readJustified.lines, "Every span position, width, baseline and style matches the authored layout."),
                .init("Table tab positions survive reopening", try tabTableGeometry(reopened).lines == tableLayout.lines, "The saved table reproduces all tab-aware justified spans."),
                .init("Tab SVGs are deterministic", try (0..<2).map { try reopened.renderSVG(slideAt: $0) } == svgs, "Both reopened slide previews match their originals byte-for-byte.")
            ]
        })
    }

    private static func tabFrame(_ frame: TextFrame) {
        frame.clear()
        frame.setMargins(left: .zero, top: .zero, right: .zero, bottom: .zero)
        frame.wordWrap = true
    }

    private static func tabParagraph(_ paragraph: Paragraph, text: String, stop: Double, mode: TextTabAlignment, alignment: TextAlignment = .left) {
        paragraph.alignment = alignment
        paragraph.setNoBullet()
        paragraph.tabStops = [TextTabStop(position: .inches(stop), alignment: mode)]
        paragraph.defaultTabInterval = .inches(0.5)
        let run = paragraph.addRun(text)
        run.fontName = "DejaVu Sans"; run.fontSize = 16; run.color = Color("263445")
    }

    private static func tabGuide(on slide: Slide, x: Double, y: Double, height: Double, color: String, name: String) throws {
        let guide = try slide.shapes.addShape(.rectangle, frame: LibraryLabSupport.frame(x - 0.004, y, 0.008, height), fill: .solid(Color(color)))
        guide.name = name
    }

    static func tabGeometry(_ deck: Presentation, named name: String, slideAt index: Int = 0) throws -> RichTextLayout {
        let slide = try deck.slides[index]
        let shape = try require(slide.shapes.all.first { $0.name == name }, "Tab sample missing")
        let tree = try require(slide.part.dom().firstChild(named: "p:cSld")?.firstChild(named: "p:spTree"), "Shape tree missing")
        let node = try require(tree.children(named: "p:sp").first {
            $0.firstChild(named: "p:nvSpPr")?.firstChild(named: "p:cNvPr")?[attribute: "name"] == name
        }, "Owned tab body missing")
        let body = try require(node.firstChild(named: "p:txBody"), "Tab body missing")
        return RichTextLayout(textBody: body, width: shape.frame.width.points, height: shape.frame.height.points, fonts: deck.fonts, theme: deck.theme)
    }

    static func tabTableGeometry(_ deck: Presentation) throws -> RichTextLayout {
        let root = try deck.slides[1].part.dom()
        let body = try require(DrawingLabFixtures.nodes(root, "a:txBody").first, "Table tab body missing")
        return RichTextLayout(textBody: body, width: EMU.inches(5.7).points, height: EMU.inches(2).points, fonts: deck.fonts, theme: deck.theme, insets: (0, 0, 0, 0))
    }

    static func tabAnchorsMatch(_ layouts: [RichTextLayout], count: Int, stop: Double, fonts: FontLibrary) throws -> Bool {
        _ = try require(fonts.metrics(for: "DejaVu Sans"), "Numeric font metrics missing")
        guard layouts.count == 4, layouts.allSatisfy({ $0.lines.count == count }) else { return false }
        return layouts.enumerated().allSatisfy { index, layout in
            layout.lines.enumerated().allSatisfy { row, line in
                let visible = line.spans.filter { !$0.run.text.isEmpty && $0.run.text != "\t" }
                guard let first = visible.first, let last = visible.last else { return false }
                let end = last.x + last.width
                let anchor: Double
                switch index {
                case 0: anchor = first.x
                case 1: anchor = (first.x + end) / 2
                case 2: anchor = end
                default:
                    let prefix = String(tabSamples[row].prefix { $0 != "." })
                    anchor = first.x + tabPrefixWidth(prefix, fonts: fonts)
                }
                return abs(anchor - stop * 72) < 0.01
            }
        }
    }

    /// Measure the numeric prefix through the shared paragraph engine rather
    /// than assuming raw font advances match its native-calibrated placement.
    /// This detached read-only probe matches the recipe's regular 16 pt face,
    /// zero tracking and omitted kerning; it never changes the saved document.
    static func tabPrefixWidth(_ prefix: String, fonts: FontLibrary) -> Double {
        let body = XML.Element("a:txBody", children: [
            .element(XML.Element("a:bodyPr", attributes: [("lIns", "0"), ("rIns", "0"), ("tIns", "0"), ("bIns", "0"), ("wrap", "none")])),
            .element(XML.Element("a:p", children: [
                .element(XML.Element("a:pPr", attributes: [("algn", "l")])),
                .element(XML.Element("a:r", children: [
                    .element(XML.Element("a:rPr", attributes: [("sz", "1600"), ("spc", "0")], children: [
                        .element(XML.Element("a:latin", attributes: [("typeface", "DejaVu Sans")]))
                    ])),
                    .element(XML.Element("a:t", children: [.text(prefix)]))
                ]))
            ]))
        ])
        return RichTextLayout(textBody: body, width: 1_000, height: 100, fonts: fonts).lines.first?.visibleWidth ?? .infinity
    }

    static func tabJustificationMatches(natural: RichTextLayout, justified: RichTextLayout, stop: Double) -> Bool {
        guard paragraphExpansion(left: natural, justified: justified),
              let first = justified.lines.first,
              let visible = first.spans.first(where: { !$0.run.text.isEmpty && $0.run.text != "\t" }) else { return false }
        return abs(visible.x - stop * 72) < 0.01
    }
}
