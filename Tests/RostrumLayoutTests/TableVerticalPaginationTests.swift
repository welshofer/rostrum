import Foundation
import Testing
@testable import Rostrum
@testable import RostrumLayout

@Suite struct TableVerticalPaginationTests {
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

    private func content(groups: Int, measured: Bool = false) -> TemplateTableContent {
        var rows = [["Grouped evidence", "", "Record"]]
        var merges = [TableMergeRegion(row: 0, column: 0, rowSpan: 1, columnSpan: 2)]
        for group in 0..<groups {
            let row = rows.count
            rows += [["Group \(group + 1) first exact observation", "Opening", "R\(row)"],
                     ["", "The middle observation connects all four rows.", "R\(row + 1)"],
                     ["Group \(group + 1) second exact observation", "", "R\(row + 2)"],
                     ["", "Closing", "R\(row + 3)"]]
            merges += [.init(row: row, column: 0, rowSpan: 2, columnSpan: 1),
                       .init(row: row + 1, column: 1, rowSpan: 2, columnSpan: 1),
                       .init(row: row + 2, column: 0, rowSpan: 2, columnSpan: 1)]
        }
        return .init(rows: rows, columnWeights: [2, 2, 1],
            columnSizing: measured ? .measured() : .estimated, merges: merges)
    }

    @Test func connectedIntervalsKeepAdjacentGroupsSeparateAndAcceptExactFits() throws {
        let table = content(groups: 2)
        let groups = try TableRowGroups(merges: Array(table.merges.reversed()))
        #expect(groups.end(startingAt: 1) == 5 && groups.end(startingAt: 5) == 9)
        let heights = [EMU(10)] + Array(repeating: EMU(20), count: 8)
        #expect(try TemplateLayoutEngine.tablePageRanges(heights: heights, available: EMU(90), groups: groups) == [1..<5, 5..<9])
        #expect(try TemplateLayoutEngine.tablePageRanges(heights: heights, available: EMU(170), groups: groups) == [1..<9])
        #expect(throws: LayoutError.self) {
            try TemplateLayoutEngine.tablePageRanges(heights: heights, available: EMU(89), groups: groups)
        }
        #expect(groups.unplaceableCount(heights: heights, capacity: EMU(79)) == 2)
    }

    @Test func singleSlideCompositionSupportsRectanglesIncludingTheHeader() throws {
        let deck = try fixture(), engine = TemplateLayoutEngine(presentation: deck)
        let content = TemplateTableContent(rows: [["A complete two by two header block", "", "State"],
            ["", "", "Ready"], ["Original evidence", "Exact observation", "Saved"]], columnSizing: .measured(),
            merges: [.init(row: 0, column: 0, rowSpan: 2, columnSpan: 2)])
        let before = try deck.serializedData()
        let plan = try engine.plan(title: "Combined cells", columns: [], preferredTypes: ["obj"], object: "tbl", table: content)
        #expect(try deck.serializedData() == before)
        let slide = try engine.compose(plan, title: "Combined cells", columns: [])
        let tables = slide.shapes.all.compactMap { ($0 as? TableFrame)?.table }
        let table = try #require(tables.first)
        #expect(try table.mergedRegions == content.merges)
        let geometry = try #require(plan.tableLayout)
        #expect(geometry.cells[0].rowSpan == 2 && geometry.cells[0].columnSpan == 2)
        #expect(try TableLayoutEngine(presentation: deck).plan(table).fits)
        let reopened = try Presentation(data: deck.serializedData())
        let savedTables = try reopened.slides[1].shapes.all.compactMap { ($0 as? TableFrame)?.table }
        #expect(try savedTables.first?.mergedRegions == content.merges)
        for row in content.rows.indices { for column in content.rows[row].indices {
            #expect(try savedTables.first?.cell(row, column).text == content.rows[row][column])
        } }
        let composed = try deck.serializedData()
        #expect(throws: LayoutError.self) { try engine.planTablePages(title: "Header", table: content) }
        #expect(try deck.serializedData() == composed)
    }

    @Test(arguments: [false, true])
    func savedPagesKeepConnectedRowsWordsStylesAndNativeMerges(measured: Bool) throws {
        let deck = try fixture(), engine = TemplateLayoutEngine(presentation: deck)
        // Moving a group can change its band/edge styles. Measure the conservative
        // envelope, then independently check each saved cell's combined area.
        let styleTable = try deck.slides[0].shapes.addTable(rows: 1, columns: 1, frame: deck.bounds)
        try styleTable.setStyleDefinition(XML.parse(Data("""
        <a:tblStyle xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" styleId="\(Table.defaultStyleGUID)" styleName="Spanning bands">
          <a:wholeTbl><a:tcTxStyle b="off" i="off"/></a:wholeTbl>
          <a:band1H><a:tcTxStyle b="on"/></a:band1H><a:band2H><a:tcTxStyle i="on"/></a:band2H>
          <a:firstRow><a:tcTxStyle b="on"/></a:firstRow><a:lastRow><a:tcTxStyle i="on"/></a:lastRow>
        </a:tblStyle>
        """.utf8)))
        let table = content(groups: 7, measured: measured)
        let before = try deck.serializedData()
        let plan = try engine.planTablePages(title: "Connected groups", table: table, caption: "Exact source retained.")
        #expect(try deck.serializedData() == before)
        #expect(plan.pages.count > 1 && plan.pages.flatMap { Array($0.bodyRows) } == Array(1..<table.rows.count))
        for page in plan.pages {
            #expect((page.bodyRows.lowerBound - 1) % 4 == 0 && (page.bodyRows.upperBound - 1) % 4 == 0)
        }
        let slides = try engine.composeTablePages(plan)
        for slide in slides { try slide.setNotes("All original notes remain.") }
        let bytes = try deck.serializedData(), reopened = try Presentation(data: bytes)
        var retained: [[String]] = []
        for (index, page) in plan.pages.enumerated() {
            let slide = try reopened.slides[index + 1]
            let frames = slide.shapes.all.compactMap { $0 as? TableFrame }
            let frame = try #require(frames.first), native = try #require(frame.table)
            let accepted = try #require(page.slide.tableLayout)
            let actual = try TableLayoutEngine(presentation: deck).plan(native, minimumRowHeight: .points(30))
            let expected = table.merges.filter { $0.row == 0 || page.bodyRows.contains($0.row) }.map {
                TableMergeRegion(row: $0.row == 0 ? 0 : $0.row - page.bodyRows.lowerBound + 1,
                    column: $0.column, rowSpan: $0.rowSpan, columnSpan: $0.columnSpan)
            }
            #expect(try native.mergedRegions == expected)
            #expect(actual.fits && actual.columnWidths == accepted.columnWidths)
            let savedHeights = try (0..<native.rowCount).map { try native.rowHeight($0) }
            #expect(savedHeights == accepted.rowHeights)
            #expect(frame.frame.maxY + .points(8) <= (try #require(page.slide.captionFrame)).y)
            #expect(slide.notesText == "All original notes remain.")
            for cell in actual.cells where !cell.isMergeContinuation {
                let height = accepted.rowHeights[cell.row..<(cell.row + cell.rowSpan)].reduce(.zero, +)
                #expect(cell.requiredHeight <= height)
                #expect(accepted.cells[cell.row * 3 + cell.column].rowSpan == cell.rowSpan)
                let body = try #require(native.cell(cell.row, cell.column).existingTextFrame)
                let fit = body.fitText(in: Rect(x: .zero, y: .zero,
                    width: accepted.columnWidths[cell.column..<(cell.column + cell.columnSpan)].reduce(.zero, +),
                    height: height), fonts: deck.fonts, theme: slide.master?.theme)
                #expect(fit.fits)
            }
            for row in 0..<native.rowCount {
                let values = try (0..<3).map { try native.cell(row, $0).text }
                if row == 0 { #expect(values == table.rows[0]) } else { retained.append(values) }
            }
        }
        #expect(retained == Array(table.rows.dropFirst()))
        #expect(try deck.serializedData() == bytes)
        deck.slideSize = (deck.slideSize.width, deck.slideSize.height * 2)
        let changed = try deck.serializedData()
        #expect(throws: LayoutError.self) { try engine.composeTablePages(plan) }
        #expect(try deck.serializedData() == changed)
    }

    @Test func oversizedConnectedGroupRefusesBeforeAnySlideIsAdded() throws {
        let deck = try fixture(), engine = TemplateLayoutEngine(presentation: deck)
        let rows = [["Group", "Value"]] + (1...30).map { [$0 == 1 ? "One indivisible group" : "", "Row \($0)"] }
        let content = TemplateTableContent(rows: rows, merges: [.init(row: 1, column: 0, rowSpan: 30, columnSpan: 1)])
        let before = try deck.serializedData()
        // Every physical row would fit; their connected group cannot.
        #expect(throws: LayoutError.self) { try engine.planTablePages(title: "Too tall", table: content) }
        #expect(try deck.serializedData() == before)
    }

    @Test func invalidRectanglesAndCoveredWordsNeverMutateTheDeck() throws {
        let deck = try fixture(), engine = TemplateLayoutEngine(presentation: deck)
        let rows = [["Header", "Other"], ["Anchor", ""], ["", ""]]
        let valid = TableMergeRegion(row: 1, column: 0, rowSpan: 2, columnSpan: 2)
        let variants: [[TableMergeRegion]] = [
            [.init(row: 1, column: 0, rowSpan: Int.max, columnSpan: 1)],
            [.init(row: 1, column: 0, rowSpan: 0, columnSpan: 2)],
            [.init(row: 1, column: 0, rowSpan: 2, columnSpan: 0)],
            [.init(row: 1, column: 0, rowSpan: 2, columnSpan: Int.max)],
            [valid, .init(row: 2, column: 0, rowSpan: 1, columnSpan: 2)], [valid, valid]]
        let before = try deck.serializedData()
        for merges in variants {
            #expect(throws: LayoutError.self) {
                try engine.planTablePages(title: "Invalid", table: .init(rows: rows, merges: merges))
            }
        }
        for covered in ["Original words", " ", "\n"] {
            var changed = rows; changed[2][0] = covered
            #expect(throws: LayoutError.self) {
                try engine.plan(title: "Words", columns: [], preferredTypes: ["obj"], object: "tbl",
                    table: .init(rows: changed, merges: [valid]))
            }
        }
        #expect(try deck.serializedData() == before)
    }
}
