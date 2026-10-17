import Foundation
import Testing
@testable import Rostrum
@testable import RostrumLayout

@Suite struct TableRepeatedHeaderTests {
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
        var rows = [["Grouped source evidence", "", "State"], ["", "", ""], ["Record", "Evidence", ""]]
        var merges: [TableMergeRegion] = [.init(row: 0, column: 0, rowSpan: 2, columnSpan: 2),
            .init(row: 0, column: 2, rowSpan: 3, columnSpan: 1)]
        for group in 0..<groups {
            let row = rows.count
            rows += [["Group \(group + 1)", "The first exact observation for source \(group + 1).", "Ready"],
                     ["", "The second exact observation stays with its group.", "Saved"]]
            merges.append(.init(row: row, column: 0, rowSpan: 2, columnSpan: 1))
        }
        return .init(rows: rows, columnWeights: [1, 3, 1],
            columnSizing: measured ? .measured() : .estimated, merges: merges, headerRowCount: 3)
    }

    @Test func wholeHeaderUsesCapacityAndPreservesExactGroupBoundaries() throws {
        let content = content(groups: 2)
        let groups = try TableRowGroups(merges: content.merges, headerRowCount: 3)
        let heights = [10, 15, 20, 20, 20, 20, 20].map { EMU($0) }
        #expect(try TemplateLayoutEngine.tablePageRanges(heights: heights, available: EMU(85),
            groups: groups, headerRowCount: 3) == [3..<5, 5..<7])
        #expect(try TemplateLayoutEngine.tablePageRanges(heights: heights, available: EMU(125),
            groups: groups, headerRowCount: 3) == [3..<7])
        #expect(throws: LayoutError.self) {
            try TemplateLayoutEngine.tablePageRanges(heights: heights, available: EMU(84), groups: groups, headerRowCount: 3)
        }
        #expect(groups.unplaceableCount(heights: heights, capacity: EMU(39), startingAt: 3) == 2)
        #expect(try TemplateLayoutEngine.tablePageRanges(heights: Array(heights.prefix(3)),
            available: EMU(45), headerRowCount: 3) == [3..<3])
        // Reject overflowing or invalid prefixes without trapping or emitting an empty continuation.
        for values in [[EMU(Int.max), EMU(1)], [EMU(1), .zero], [EMU(1), EMU(-1)]] {
            #expect(throws: LayoutError.self) {
                try TemplateLayoutEngine.tablePageRanges(heights: values, available: EMU(Int.max), headerRowCount: 2)
            }
        }
    }

    @Test(arguments: [false, true])
    func savedPagesRepeatHeaderRectanglesAndKeepBodyGroups(measured: Bool) throws {
        let deck = try fixture(), engine = TemplateLayoutEngine(presentation: deck)
        let style = try deck.slides[0].shapes.addTable(rows: 1, columns: 1, frame: deck.bounds)
        try style.setStyleDefinition(XML.parse(Data("""
        <a:tblStyle xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" styleId="\(Table.defaultStyleGUID)" styleName="Repeated header bands">
          <a:wholeTbl><a:tcTxStyle b="off" i="off"/></a:wholeTbl>
          <a:band1H><a:tcTxStyle b="on"/></a:band1H><a:band2H><a:tcTxStyle i="on"/></a:band2H>
          <a:firstRow><a:tcTxStyle b="on"/></a:firstRow><a:lastRow><a:tcTxStyle i="on"/></a:lastRow>
        </a:tblStyle>
        """.utf8)))
        let content = content(groups: 12, measured: measured), caption = "Exact sources remain editable."
        let before = try deck.serializedData()
        let protected = Dictionary(uniqueKeysWithValues: deck.package.parts.values.filter {
            $0.uri.value.hasPrefix("/ppt/slideLayouts/") || $0.uri.value.hasPrefix("/ppt/slideMasters/")
                || $0.uri.value.hasPrefix("/ppt/theme/")
        }.map { ($0.uri, $0.blob) })
        let plan = try engine.planTablePages(title: "Grouped headers", table: content, caption: caption)
        #expect(try deck.serializedData() == before)
        #expect(plan.pages.count > 1)
        #expect(plan.pages.flatMap { Array($0.bodyRows) } == Array(3..<content.rows.count))
        let slides = try engine.composeTablePages(plan)
        for slide in slides { try slide.setNotes("Original notes retained.") }
        let bytes = try deck.serializedData(), reopened = try Presentation(data: bytes)
        for (uri, data) in protected { #expect(reopened.package.parts[uri]?.blob == data) }
        var body: [[String]] = []
        for (index, page) in plan.pages.enumerated() {
            #expect(page.headerRowCount == 3 && (page.bodyRows.lowerBound - 3) % 2 == 0 && page.bodyRows.count % 2 == 0)
            let slide = try reopened.slides[index + 1]
            let frame = try #require(slide.shapes.all.compactMap { $0 as? TableFrame }.first)
            let table = try #require(frame.table), accepted = try #require(page.slide.tableLayout)
            let expected = content.merges.filter { $0.row < 3 || page.bodyRows.contains($0.row) }.map {
                TableMergeRegion(row: $0.row < 3 ? $0.row : $0.row - page.bodyRows.lowerBound + 3,
                    column: $0.column, rowSpan: $0.rowSpan, columnSpan: $0.columnSpan)
            }
            #expect(try table.mergedRegions == expected)
            #expect(table.firstRowHeader) // Native firstRow styling still applies only to row zero.
            #expect(try (0..<table.rowCount).map { try table.rowHeight($0) } == accepted.rowHeights)
            #expect(accepted.columnWidths == plan.pages[0].slide.tableLayout?.columnWidths)
            #expect(frame.frame.maxY + .points(8) <= (try #require(page.slide.captionFrame)).y)
            let actual = try TableLayoutEngine(presentation: deck).plan(table, minimumRowHeight: .points(30))
            #expect(actual.fits)
            for cell in actual.cells where !cell.isMergeContinuation {
                #expect(cell.requiredHeight <= accepted.rowHeights[cell.row..<(cell.row + cell.rowSpan)].reduce(.zero, +))
            }
            for row in 0..<table.rowCount {
                let values = try (0..<3).map { try table.cell(row, $0).text }
                if row < 3 { #expect(values == content.rows[row]) } else { body.append(values) }
            }
            #expect(slide.notesText == "Original notes retained.")
            #expect(slide.shapes.all.contains { $0.textFrame?.text == caption })
        }
        #expect(body == Array(content.rows.dropFirst(3)))
        #expect(try deck.serializedData() == bytes)
        deck.slideSize = (deck.slideSize.width, deck.slideSize.height * 2)
        let changed = try deck.serializedData()
        #expect(throws: LayoutError.self) { try engine.composeTablePages(plan) }
        #expect(try deck.serializedData() == changed)
    }

    @Test func headerOnlyRetainsAllNativeRowsAndMerges() throws {
        let deck = try fixture(), engine = TemplateLayoutEngine(presentation: deck)
        let content = content(groups: 0, measured: true)
        let plan = try engine.planTablePages(title: "Header", table: content)
        #expect(plan.pages.count == 1 && plan.pages[0].bodyRows == 3..<3)
        _ = try engine.composeTablePages(plan)
        let saved = try Presentation(data: deck.serializedData())
        let tables = try saved.slides[1].shapes.all.compactMap { ($0 as? TableFrame)?.table }
        let table = try #require(tables.first)
        #expect(table.rowCount == 3)
        #expect(try table.mergedRegions == content.merges)
    }

    @Test func widthSearchReservesEveryHeaderRowBeforeScoringBodyFit() throws {
        let deck = try fixture()
        let rows = [["A", "B"], ["A long observation header", "C"], ["Source", "Value"]]
        let content = TemplateTableContent(rows: rows, columnWeights: [1, 1],
            columnSizing: .measured(constraints: [.init(preferred: .points(280)), .init()]), headerRowCount: 2)
        let plan = try content.planned(in: deck, width: .points(400), font: "DejaVu Sans", size: 18,
            theme: deck.theme, pagination: true, availableHeight: .points(100))
        #expect(plan.fits)
        #expect(plan.columnWidths[0] > .points(200))
        #expect(try TemplateLayoutEngine.tablePageRanges(heights: plan.rowHeights, available: .points(100),
            headerRowCount: 2) == [2..<3])
    }

    @Test func invalidCountsCrossingMergesAndOversizedPrefixesRefuseAtomically() throws {
        let deck = try fixture(), engine = TemplateLayoutEngine(presentation: deck)
        let before = try deck.serializedData()
        for count in [-1, 0, 4, Int.max] {
            let content = TemplateTableContent(rows: [["A"], ["B"], ["C"]], headerRowCount: count)
            #expect(throws: LayoutError.self) { try engine.planTablePages(title: "Invalid", table: content) }
            #expect(throws: LayoutError.self) {
                try engine.plan(title: "Invalid", columns: [], preferredTypes: ["obj"], object: "tbl", table: content)
            }
        }
        let crossing = TemplateTableContent(rows: [["A"], ["B"], [""]],
            merges: [.init(row: 1, column: 0, rowSpan: 2, columnSpan: 1)], headerRowCount: 2)
        #expect(throws: LayoutError.self) { try engine.planTablePages(title: "Crossing", table: crossing) }
        let tall = TemplateTableContent(rows: Array(repeating: ["Header"], count: 30), headerRowCount: 30)
        #expect(throws: LayoutError.self) { try engine.planTablePages(title: "Tall", table: tall) }
        #expect(try deck.serializedData() == before)
    }
}
