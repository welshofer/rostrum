import Foundation
import Testing
@testable import Rostrum
@testable import RostrumLayout

@Suite struct TemplateTablePaginationTests {
    private func fixture() throws -> Presentation {
        let deck = try Presentation()
        deck.theme.minorFont = "DejaVu Sans"
        let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("RostrumTests/Fixtures/NativeGlyphPlacement/eligibility/fonts")
        for face in ["DejaVuSans", "DejaVuSans-Bold", "DejaVuSans-Oblique"] {
            try deck.fonts.register(contentsOf: directory.appendingPathComponent(face + ".ttf"))
        }
        return deck
    }

    private var rows: [[String]] {
        [["Item", "Evidence"]] + (1...37).map { row in
            ["Row \(row)", Array(repeating: "Exact words retained é e\u{301}", count: row % 4 + 1).joined(separator: "\n")]
        }
    }

    @Test func partitionsAtExactBoundariesWithoutEmptyContinuationPages() throws {
        let split = try TemplateLayoutEngine.tablePageRanges(heights: [10, 20, 30, 41, 1].map { EMU($0) }, available: EMU(61))
        #expect(split == [1..<3, 3..<5])
        #expect(try TemplateLayoutEngine.tablePageRanges(heights: [EMU(10)], available: EMU(10)) == [1..<1])
        #expect(throws: LayoutError.self) {
            try TemplateLayoutEngine.tablePageRanges(heights: [EMU(10), EMU(52)], available: EMU(61))
        }
        #expect(throws: LayoutError.self) {
            try TemplateLayoutEngine.tablePageRanges(heights: [EMU(62)], available: EMU(61))
        }
    }

    @Test func savedPagesRetainEveryRowHeaderCaptionAndTemplatePart() throws {
        let deck = try fixture(), engine = TemplateLayoutEngine(presentation: deck)
        let content = TemplateTableContent(rows: rows, columnWeights: [1, 3])
        let caption = "Source: original evidence. All rows remain editable."
        let before = try deck.serializedData()
        let protected = Dictionary(uniqueKeysWithValues: deck.package.parts.values.filter {
            $0.uri.value.hasPrefix("/ppt/slideLayouts/") || $0.uri.value.hasPrefix("/ppt/slideMasters/")
                || $0.uri.value.hasPrefix("/ppt/theme/") || $0.uri.value == "/ppt/slides/slide1.xml"
        }.map { ($0.uri, $0.blob) })
        let plan = try engine.planTablePages(title: "Evidence", table: content, caption: caption)
        #expect(plan.pages.count > 2)
        #expect(plan.pages.flatMap { Array($0.bodyRows) } == Array(1..<rows.count))
        #expect(try deck.serializedData() == before)
        let pages = try engine.composeTablePages(plan)
        for (index, slide) in pages.enumerated() { try slide.setNotes("Original notes; continuation \(index + 1)") }
        let bytes = try deck.serializedData()
        #expect(try deck.serializedData() == bytes)
        let reopened = try Presentation(data: bytes)
        #expect(reopened.slides.count == pages.count + 1)
        for (uri, data) in protected { #expect(reopened.package.parts[uri]?.blob == data) }
        var body: [[String]] = []
        for (pageIndex, page) in plan.pages.enumerated() {
            let slide = try reopened.slides[pageIndex + 1]
            let frames = slide.shapes.all.compactMap { $0 as? TableFrame }
            let frame = try #require(frames.first)
            let table = try #require(frame.table)
            let measured = try #require(page.slide.tableLayout)
            let actual = try TableLayoutEngine(presentation: deck).plan(table, minimumRowHeight: .points(30),
                maximumHeight: page.slide.objectFrame?.height)
            #expect(actual.fits)
            #expect(actual.columnWidths == plan.pages[0].slide.tableLayout?.columnWidths)
            #expect(zip(actual.rowHeights, measured.rowHeights).allSatisfy { $0 <= $1 })
            #expect(frame.frame.maxY + .points(8) <= (try #require(page.slide.captionFrame)).y)
            #expect(slide.notesText == "Original notes; continuation \(pageIndex + 1)")
            let captionShape = try #require(slide.shapes.all.first { $0.textFrame?.text == caption })
            #expect(try #require(captionShape.textFrame).fitText(in: captionShape.frame, fonts: deck.fonts, theme: slide.master?.theme).fits)
            for row in 0...page.bodyRows.count {
                let values = try measured.columnWidths.indices.map { try table.cell(row, $0).text }
                if row == 0 { #expect(values == rows[0]) } else { body.append(values) }
            }
        }
        #expect(body == Array(rows.dropFirst()))
    }

    @Test func tallRowHeaderCaptionAndMalformedGridRejectWithoutMutation() throws {
        let deck = try fixture(), engine = TemplateLayoutEngine(presentation: deck)
        let before = try deck.serializedData()
        let tall = Array(repeating: "Line", count: 60).joined(separator: "\n")
        for content in [TemplateTableContent(rows: [["Header"], [tall]]),
                        TemplateTableContent(rows: [[tall], ["Body"]]),
                        TemplateTableContent(rows: [["Header"], ["Ragged", "grid"]])] {
            #expect(throws: LayoutError.self) { try engine.planTablePages(title: "Table", table: content) }
        }
        #expect(throws: LayoutError.self) {
            try engine.planTablePages(title: "Table", table: TemplateTableContent(rows: [["Header"], ["Body"]]), caption: tall)
        }
        #expect(try deck.serializedData() == before)
    }

    @Test func stalePlanRejectsAllPagesBeforeInsertion() throws {
        let deck = try fixture(), engine = TemplateLayoutEngine(presentation: deck)
        let plan = try engine.planTablePages(title: "Table", table: TemplateTableContent(rows: rows))
        // The changed canvas doubles the object typography for every page.
        deck.slideSize = (width: deck.slideSize.width, height: deck.slideSize.height * 2)
        let before = try deck.serializedData()
        #expect(throws: LayoutError.self) { try engine.composeTablePages(plan) }
        #expect(try deck.serializedData() == before)
    }

    @Test func repeatedPageStylesRefreshBetweenCompositionCalls() throws {
        let deck = try fixture(), engine = TemplateLayoutEngine(presentation: deck)
        let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("RostrumTests/Fixtures/NativeGlyphPlacement/eligibility/fonts")
        for face in ["DejaVuSans", "DejaVuSans-Bold", "DejaVuSans-Oblique"] {
            try deck.fonts.register(contentsOf: directory.appendingPathComponent(face + ".ttf"),
                aliases: ["First body", "Second body"])
        }
        let caption = "A current template style on every continuation."
        let plan = try engine.planTablePages(title: "Styles", table: .init(rows: rows), caption: caption)
        #expect(plan.pages.count > 2)
        var groups: [(font: String, slides: [Slide])] = []
        // Same metrics, changed typeface identity: composition must resolve the
        // current theme even when the existing page geometry remains valid.
        for font in ["First body", "Second body"] {
            deck.theme.minorFont = font
            groups.append((font, try engine.composeTablePages(plan)))
        }
        let saved = try Presentation(data: deck.serializedData())
        var index = 1
        for group in groups {
            for _ in group.slides {
                let slide = try saved.slides[index]; index += 1
                let tables = slide.shapes.all.compactMap { ($0 as? TableFrame)?.table }
                let native = try #require(tables.first)
                for row in 0..<native.rowCount {
                    for column in 0..<native.columnCount {
                        let runs = try native.cell(row, column).textFrame.paragraphs.flatMap(\.runs)
                        #expect(!runs.isEmpty && runs.allSatisfy { $0.fontName == group.font })
                    }
                }
                let captionShape = slide.shapes.all.first { $0.textFrame?.text == caption }
                let text = try #require(captionShape?.textFrame)
                #expect(text.paragraphs.flatMap(\.runs).allSatisfy { $0.fontName == group.font })
            }
        }
    }

    @Test func headerOnlyAndSinglePageStayNative() throws {
        let deck = try fixture(), engine = TemplateLayoutEngine(presentation: deck)
        for values in [[["Header"]], [["Header"], ["Body"]]] {
            let plan = try engine.planTablePages(title: "Table", table: TemplateTableContent(rows: values))
            #expect(plan.pages.count == 1)
            let page = try #require(engine.composeTablePages(plan).first)
            let tables = page.shapes.all.compactMap { ($0 as? TableFrame)?.table }
            let table = try #require(tables.first)
            #expect(table.firstRowHeader)
            for row in values.indices { #expect(try table.cell(row, 0).text == values[row][0]) }
        }
    }

    @Test func bandTypographyIsSafeWhenRowsMoveToAnotherPage() throws {
        let deck = try fixture(), engine = TemplateLayoutEngine(presentation: deck)
        let table = try deck.slides[0].shapes.addTable(rows: 1, columns: 1, frame: deck.bounds)
        let definition = try XML.parse(Data("""
        <a:tblStyle xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" styleId="\(Table.defaultStyleGUID)" styleName="Band font test">
          <a:wholeTbl><a:tcTxStyle b="off" i="off"/></a:wholeTbl>
          <a:band1H><a:tcTxStyle b="on"/></a:band1H>
          <a:band2H><a:tcTxStyle i="on"/></a:band2H>
          <a:firstRow><a:tcTxStyle b="on"/></a:firstRow>
        </a:tblStyle>
        """.utf8))
        try table.setStyleDefinition(definition)
        let content = TemplateTableContent(rows: rows, columnWeights: [1, 2])
        let plan = try engine.planTablePages(title: "Bands", table: content)
        let pages = try engine.composeTablePages(plan)
        #expect(pages.count > 1)
        for (slide, page) in zip(pages, plan.pages) {
            let tables = slide.shapes.all.compactMap { ($0 as? TableFrame)?.table }
            let native = try #require(tables.first)
            let actual = try TableLayoutEngine(presentation: deck).plan(native, minimumRowHeight: .points(30))
            let accepted = try #require(page.slide.tableLayout)
            #expect(actual.fits && zip(actual.rowHeights, accepted.rowHeights).allSatisfy { $0 <= $1 })
            #expect(actual.totalHeight <= (try #require(page.slide.objectFrame)).height)
        }
    }
}
