import Foundation
import Testing
@testable import Rostrum

@Suite struct DeckOutlineTests {
    private let frame = Rect(x: .inches(1), y: .inches(1), width: .inches(6), height: .inches(3))

    /// The smallest legal PNG: enough for the sniffer to accept and for the
    /// package to carry, and nothing more.
    private static let png: Data = {
        func be32(_ value: Int) -> [UInt8] {
            [UInt8(value >> 24 & 0xFF), UInt8(value >> 16 & 0xFF),
             UInt8(value >> 8 & 0xFF), UInt8(value & 0xFF)]
        }
        var bytes: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        bytes += be32(13); bytes += Array("IHDR".utf8)
        bytes += be32(8); bytes += be32(8); bytes += [8, 6, 0, 0, 0]; bytes += be32(0)
        bytes += be32(0); bytes += Array("IEND".utf8); bytes += be32(0)
        return Data(bytes)
    }()

    private func scratchDirectory() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("rostrum-export-\(UUID().uuidString)", isDirectory: true)
    }

    // MARK: - Text

    @Test func classifiesTitleSubtitleAndBullets() throws {
        let deck = try Presentation()
        let slide = try deck.slides.add(clonedFrom: deck.layout(type: "title")!)
        slide.title?.textFrame?.text = "Quarterly review"
        slide.placeholder(idx: 1)?.textFrame?.text = "Fiscal 2026"

        let box = try slide.shapes.addTextBox(frame)
        let body = try #require(box.textFrame)
        body.clear()
        body.addParagraph().addRun("Revenue is up")
        let nested = body.addParagraph()
        nested.indentLevel = 1
        nested.addRun("Especially in EMEA")

        let outline = deck.outline().slides[1]
        #expect(outline.number == 2)
        #expect(outline.folderName == "slide-02")
        #expect(outline.title == "Quarterly review")
        #expect(outline.subtitle == "Fiscal 2026")
        #expect(outline.body.count == 1)
        #expect(outline.body[0].paragraphs.map(\.text) == ["Revenue is up", "Especially in EMEA"])
        #expect(outline.body[0].paragraphs.map(\.level) == [0, 1])
        #expect(outline.hasAttachments == false)
    }

    @Test func manualLineBreaksSurviveExtraction() throws {
        // The bug this guards: `runs` sees only a:r, so a line break between
        // two runs welds them into one word.
        let deck = try Presentation()
        let box = try deck.slides[0].shapes.addTextBox(frame)
        let text = try #require(box.textFrame)
        text.clear()
        let paragraph = text.addParagraph()
        paragraph.addRun("Q3")
        paragraph.p.appendElement(XML.Element("a:br"))
        paragraph.addRun("results")

        #expect(text.text == "Q3results")
        #expect(paragraph.plainText == "Q3\nresults")
        #expect(deck.outline().slides[0].body.first?.paragraphs.first?.text == "Q3\nresults")
    }

    @Test func speakerNotesAreExtracted() throws {
        let deck = try Presentation()
        try deck.slides[0].setNotes(["Open with the anecdote.", "Then the numbers."])
        #expect(deck.outline().slides[0].notes == ["Open with the anecdote.", "Then the numbers."])
    }

    @Test func tableCellsBecomeRows() throws {
        let deck = try Presentation()
        let table = try deck.slides[0].shapes.addTable(rows: 2, columns: 2, frame: frame)
        table.setContents([["Region", "Q1"], ["North", "10"]])
        #expect(deck.outline().slides[0].tables.first?.rows == [["Region", "Q1"], ["North", "10"]])
    }

    // MARK: - Charts

    @Test func chartsFlattenToAGrid() throws {
        let deck = try Presentation()
        try deck.slides[0].shapes.addChart(
            .barClustered,
            data: ChartData(categories: ["Q1", "Q2"],
                            series: [.init(name: "Revenue", values: [10, 20]),
                                     .init(name: "Cost", values: [5.5, 8])]),
            frame: frame,
            options: ChartOptions(title: "Results"))

        let slide = try Presentation(data: deck.serializedData()).outline().slides[0]
        let chart = try #require(slide.charts.first)
        #expect(chart.title == "Results")
        #expect(chart.kind == "barChart")
        #expect(chart.filename == "chart-1.csv")
        #expect(chart.grid == [["Category", "Revenue", "Cost"],
                               ["Q1", "10", "5.5"],
                               ["Q2", "20", "8"]])
        #expect(slide.hasAttachments)
    }

    @Test func numbersAreWrittenWithoutFalsePrecision() {
        #expect(SlideOutline.number(12) == "12")
        #expect(SlideOutline.number(-3) == "-3")
        #expect(SlideOutline.number(12.5) == "12.5")
        #expect(SlideOutline.number(nil) == "")
        #expect(SlideOutline.number(Double.nan) == "")
        #expect(SlideOutline.number(Double.infinity) == "")
    }

    // MARK: - CSV

    @Test func csvQuotesFieldsAndGuardsAgainstFormulas() {
        #expect(DeckExport.field("plain") == "plain")
        #expect(DeckExport.field("has,comma") == "\"has,comma\"")
        #expect(DeckExport.field("say \"hi\"") == "\"say \"\"hi\"\"\"")
        #expect(DeckExport.field("line\nbreak") == "\"line\nbreak\"")

        // A label from someone else's deck must not become a formula.
        #expect(DeckExport.field("=1+1") == "'=1+1")
        #expect(DeckExport.field("@SUM(A1)") == "'@SUM(A1)")
        #expect(DeckExport.field("+42") == "'+42")
        #expect(DeckExport.field("-cmd") == "'-cmd")
        // …but a negative number is a number, not an attack.
        #expect(DeckExport.field("-5") == "-5")
        #expect(DeckExport.field("-5.25") == "-5.25")

        #expect(DeckExport.csv([["a", "b"], ["1", "2"]]) == "a,b\r\n1,2\r\n")
    }

    // MARK: - Filenames

    @Test func filenamesFromForeignPackagesAreSafe() {
        #expect(SlideOutline.sanitized("image1.png", fallback: "x.bin") == "image1.png")
        #expect(SlideOutline.sanitized("../../etc/passwd", fallback: "x.bin") == "passwd")
        // A space is legal everywhere and is left alone; ":" and "*" are not.
        #expect(SlideOutline.sanitized("a b:c*.png", fallback: "x.bin") == "a b-c-.png")
        #expect(SlideOutline.sanitized("Q3 Review", fallback: "deck") == "Q3 Review")
        #expect(SlideOutline.sanitized("", fallback: "x.bin") == "x.bin")
        #expect(SlideOutline.sanitized("...", fallback: "x.bin") == "x.bin")
        #expect(SlideOutline.sanitized("   ", fallback: "x.bin") == "x.bin")
        // Legal in a package, unopenable on Windows.
        #expect(SlideOutline.sanitized("NUL.png", fallback: "x.bin") == "_NUL.png")
        #expect(SlideOutline.sanitized(String(repeating: "a", count: 200) + ".png",
                                       fallback: "x.bin").count <= 80)
        #expect(SlideOutline.appending(suffix: 2, to: "image1.png") == "image1-2.png")
        #expect(SlideOutline.appending(suffix: 3, to: "noext") == "noext-3")
    }

    // MARK: - Markdown

    /// A table on a slide is a table in the Markdown, not a run-on of cells.
    ///
    /// The exact bytes are asserted rather than "contains a pipe": a GitHub
    /// table is only a table if the header is followed by the `---` delimiter
    /// row, and that is precisely the line most easily lost.
    @Test func tablesExportAsMarkdownTables() throws {
        let deck = try Presentation()
        let table = try deck.slides[0].shapes.addTable(rows: 3, columns: 3, frame: frame)
        table.setContents([["Region", "Q1", "Q2"],
                           ["North", "10", "20"],
                           ["South", "5", "7"]])

        let markdown = deck.outline().markdown(title: "T")

        #expect(markdown.contains("""
        | Region | Q1 | Q2 |
        | --- | --- | --- |
        | North | 10 | 20 |
        | South | 5 | 7 |
        """))
        // A table needs a blank line ahead of it or it renders as a paragraph.
        #expect(markdown.contains("\n\n| Region | Q1 | Q2 |"))
    }

    /// A cell's own pipe must not become a column boundary, and a cell's own
    /// newline must not become a row boundary — either one silently reshapes
    /// the table into a different one.
    @Test func tableCellsCannotBreakOutOfTheirColumn() throws {
        let deck = try Presentation()
        let table = try deck.slides[0].shapes.addTable(rows: 2, columns: 2, frame: frame)
        table.setContents([["Region", "Split | Here"], ["North", "Two\nLines"]])

        let markdown = deck.outline().markdown(title: "T")

        #expect(markdown.contains("| Region | Split \\| Here |"))
        #expect(markdown.contains("| North | Two Lines |"))
        // Four rows of pipes and nothing more: header, delimiter, one body row.
        let rows = markdown.components(separatedBy: "\n").filter { $0.hasPrefix("|") }
        #expect(rows.count == 3)
    }

    /// Foreign decks routinely declare more grid columns than a row has cells.
    /// Every row still has to have the same number of columns or the table
    /// stops being one.
    @Test func raggedTableRowsArePaddedToOneWidth() {
        let lines = DeckOutline.table([["A", "B", "C"], ["only one"]])

        #expect(lines == ["| A | B | C |",
                          "| --- | --- | --- |",
                          "| only one |  |  |"])
    }

    @Test func markdownShowsSlideTextRatherThanRenderingItAsMarkup() throws {
        let deck = try Presentation()
        let box = try deck.slides[0].shapes.addTextBox(frame)
        box.textFrame?.text = "Use *args* and _kwargs_ | pipe"

        let markdown = deck.outline().markdown(title: "T")
        #expect(markdown.contains("\\*args\\*"))
        #expect(markdown.contains("\\_kwargs\\_"))
        #expect(markdown.contains("\\|"))
        #expect(markdown.hasPrefix("# T\n"))
    }

    // MARK: - Export

    @Test func exportWritesMarkdownAndOnlyTheFoldersItNeeds() throws {
        let deck = try Presentation()
        try deck.slides[0].setNotes("Say hello.")
        _ = try deck.slides[0].shapes.addPicture(Self.png, frame: frame)
        try deck.slides.add()   // text-only: earns no folder

        let root = scratchDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let summary = try DeckExport.write(deck, to: root, named: "Deck")

        #expect(summary.assetsWritten == 1)
        #expect(summary.chartsWritten == 0)
        #expect(summary.slideFolders == 1)
        #expect(summary.warnings.isEmpty)
        #expect(summary.markdownFile.lastPathComponent == "Deck.md")

        let manager = FileManager.default
        #expect(manager.fileExists(atPath: summary.markdownFile.path))
        #expect(manager.fileExists(atPath: root.appendingPathComponent("slide-01/image1.png").path))
        #expect(!manager.fileExists(atPath: root.appendingPathComponent("slide-02").path))

        #expect(try Data(contentsOf: root.appendingPathComponent("slide-01/image1.png")) == Self.png)
        let markdown = try String(contentsOf: summary.markdownFile, encoding: .utf8)
        #expect(markdown.contains("Say hello."))
        #expect(markdown.contains("`slide-01/image1.png`"))
    }

    /// The written `.md` carries the table too — a table that only survives
    /// in memory is not an export.
    @Test func tablesSurviveTheWrittenMarkdownFile() throws {
        let deck = try Presentation()
        let table = try deck.slides[0].shapes.addTable(rows: 2, columns: 2, frame: frame)
        table.setContents([["Region", "Q1"], ["North", "10"]])

        let root = scratchDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let summary = try DeckExport.write(deck, to: root, named: "Deck")

        let markdown = try String(contentsOf: summary.markdownFile, encoding: .utf8)
        #expect(markdown.contains("""
        | Region | Q1 |
        | --- | --- |
        | North | 10 |
        """))
        // A table is text, so it earns the slide no folder of its own.
        #expect(summary.slideFolders == 0)
    }

    @Test func chartDataLandsInACSVBesideTheSlide() throws {
        let deck = try Presentation()
        try deck.slides[0].shapes.addChart(
            .barClustered,
            data: ChartData(categories: ["Q1", "Q2"],
                            series: [.init(name: "Revenue", values: [10, 20])]),
            frame: frame,
            options: ChartOptions(title: "Revenue"))
        let reopened = try Presentation(data: deck.serializedData())

        let root = scratchDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let summary = try DeckExport.write(reopened, to: root, named: "Deck")

        #expect(summary.chartsWritten == 1)
        let csv = try String(contentsOf: root.appendingPathComponent("slide-01/chart-1.csv"),
                             encoding: .utf8)
        #expect(csv == "Category,Revenue\r\nQ1,10\r\nQ2,20\r\n")
    }

    @Test func theSameDeckExportsTheSameBytes() throws {
        let deck = try Presentation()
        _ = try deck.slides[0].shapes.addPicture(Self.png, frame: frame)
        try deck.slides[0].setNotes("Deterministic.")

        let first = scratchDirectory()
        let second = scratchDirectory()
        defer {
            try? FileManager.default.removeItem(at: first)
            try? FileManager.default.removeItem(at: second)
        }
        let a = try DeckExport.write(deck, to: first, named: "Deck")
        let b = try DeckExport.write(deck, to: second, named: "Deck")

        // Nothing from the clock or the destination path may reach the output.
        #expect(try Data(contentsOf: a.markdownFile) == Data(contentsOf: b.markdownFile))
    }

    @Test func exportingTwiceOverTheSameFolderLeavesStrangersAlone() throws {
        let deck = try Presentation()
        _ = try deck.slides[0].shapes.addPicture(Self.png, frame: frame)

        let root = scratchDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let bystander = root.appendingPathComponent("notes-of-my-own.txt")
        try Data("keep me".utf8).write(to: bystander)

        _ = try DeckExport.write(deck, to: root, named: "Deck")
        _ = try DeckExport.write(deck, to: root, named: "Deck")

        #expect(try String(contentsOf: bystander, encoding: .utf8) == "keep me")
    }
}
