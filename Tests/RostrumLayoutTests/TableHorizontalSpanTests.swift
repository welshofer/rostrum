import Foundation
import Testing
@testable import Rostrum
@testable import RostrumLayout

@Suite struct TableHorizontalSpanTests {
    private func fixture() throws -> Presentation {
        let deck = try Presentation()
        deck.theme.minorFont = "DejaVu Sans"
        let fonts = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("RostrumTests/Fixtures/NativeGlyphPlacement/eligibility/fonts")
        for face in ["DejaVuSans", "DejaVuSans-Bold", "DejaVuSans-Oblique"] {
            try deck.fonts.register(contentsOf: fonts.appendingPathComponent(face + ".ttf"))
        }
        return deck
    }

    private func table(_ deck: Presentation, rows: [[String]]) throws -> Table {
        let table = try deck.slides[0].shapes.addTable(rows: rows.count, columns: rows[0].count, frame: deck.bounds)
        table.setLayoutContents(rows, font: "DejaVu Sans", size: 18)
        return table
    }

    private func equal(_ a: TableLayoutPlan, _ b: TableLayoutPlan) {
        #expect(a.columnWidths == b.columnWidths && a.rowHeights == b.rowHeights)
        #expect(a.fits == b.fits && a.totalHeight == b.totalHeight && a.cells.count == b.cells.count)
        for (x, y) in zip(a.cells, b.cells) {
            #expect(x.row == y.row && x.column == y.column && x.requiredHeight == y.requiredHeight)
            #expect(x.columnSpan == y.columnSpan && x.isMergeContinuation == y.isMergeContinuation)
            #expect(x.issues == y.issues && x.diagnostics == y.diagnostics)
        }
    }

    @Test func anchorUsesCombinedWidthAndCoveredCellsRemainLossless() throws {
        let deck = try fixture()
        let native = try table(deck, rows: [["A grouped heading with several exact words", "", "Status"]])
        try native.merge(row: 0, column: 0, rowSpan: 1, columnSpan: 2)
        let anchor = try native.cell(0, 0)
        anchor.setPadding(left: .points(19), top: .points(11), right: .points(13), bottom: .points(7))
        let paragraph = try #require(anchor.textFrame.paragraphs.first)
        paragraph.p.appendElement(XML.Element("a:br"))
        let tail = paragraph.addRun("Mixed italic text")
        tail.italic = true; tail.fontSize = 23; tail.fontName = "DejaVu Sans"
        // Foreign files may retain hidden continuation payload. It must neither
        // affect visible geometry nor be removed by read-only planning.
        let covered = try native.cell(0, 1)
        covered.text = Array(repeating: "Hidden", count: 80).joined(separator: "\n")
        covered.tc.getOrAddChild("a:tcPr")[attribute: "vert"] = "vert"
        let control = try table(deck, rows: [["", "Status"]])
        let cell = try control.cell(0, 0)
        cell.tc.children = anchor.tc.children.map { item in
            if case .element(let element) = item { return .element(element.deepCopy()) }
            return item
        }
        let before = try deck.serializedData()
        let engine = TableLayoutEngine(presentation: deck)
        let plan = try engine.plan(native, columnWidths: [.points(80), .points(140), .points(100)])
        let expected = try engine.plan(control, columnWidths: [.points(220), .points(100)])
        #expect(plan.fits && plan.rowHeights == expected.rowHeights)
        #expect(plan.cells[0].requiredHeight == expected.cells[0].requiredHeight && plan.cells[0].columnSpan == 2)
        #expect(plan.cells[1].isMergeContinuation && plan.cells[1].requiredHeight == .zero)
        #expect(plan.cells[1].issues.isEmpty && plan.cells[1].diagnostics.isEmpty)
        #expect(try deck.serializedData() == before)
        native.columnWidths(plan.columnWidths).rowHeights(plan.rowHeights)
        #expect(try #require(anchor.existingTextFrame).fitText(in: Rect(x: .zero, y: .zero,
            width: .points(220), height: plan.rowHeights[0]), fonts: deck.fonts, theme: deck.theme).fits)
    }

    @Test func widthTrialsInvalidateAnchorsWhenOnlyANeighborChanges() throws {
        let deck = try fixture()
        let native = try table(deck, rows: [["A repeated grouped heading needs enough room", "", "Value"],
            ["Long text across two columns wraps as their combined width changes", "", "42"],
            ["Identifier", "Another grouping with a different origin", ""], ["é e\u{301}", "日本語", "مرحبا"],
            ["A full width grouping uses three columns with a different span length at the same origin", "", ""]])
        try native.merge([.init(row: 0, column: 0, rowSpan: 1, columnSpan: 2),
            .init(row: 1, column: 0, rowSpan: 1, columnSpan: 2), .init(row: 2, column: 1, rowSpan: 1, columnSpan: 2),
            .init(row: 4, column: 0, rowSpan: 1, columnSpan: 3)])
        try native.setStyleDefinition(XML.parse(Data("""
        <a:tblStyle xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" styleId="\(Table.defaultStyleGUID)" styleName="Span bands">
          <a:wholeTbl><a:tcTxStyle b="off" i="off"/></a:wholeTbl>
          <a:band1H><a:tcTxStyle b="on"/></a:band1H><a:band2H><a:tcTxStyle i="on"/></a:band2H>
          <a:firstRow><a:tcTxStyle b="on"/></a:firstRow>
        </a:tblStyle>
        """.utf8)))
        let engine = TableLayoutEngine(presentation: deck)
        for pagination in [false, true] {
            let reuse = try TableColumnMeasurements(table: native, theme: deck.theme)
            var heights: [EMU] = []
            for values in [[80, 60, 260], [80, 160, 160], [110, 130, 160], [80, 60, 260], [80, 60, 160]] {
                let widths = values.map { EMU.points(Double($0)) }
                let actual = try engine.plan(native, columnWidths: widths, minimumRowHeight: .points(30),
                    theme: deck.theme, pagination: pagination, reuse: reuse)
                equal(actual, try engine.plan(native, columnWidths: widths, minimumRowHeight: .points(30),
                    theme: deck.theme, pagination: pagination))
                heights.append(actual.rowHeights[1])
            }
            #expect(heights[0] > heights[1] && heights[1] == heights[2] && heights[0] == heights[3])
            #expect(reuse.reusedCells > 0 && reuse.preparation.cellCount == 10)
        }
    }

    @Test func pagesRepeatMergedHeadersAndRemapBodySpansAfterReopening() throws {
        let deck = try fixture(), engine = TemplateLayoutEngine(presentation: deck)
        var rows = [["Grouped evidence", "", "Status"]]
        var merges = [TableMergeRegion(row: 0, column: 0, rowSpan: 1, columnSpan: 2)]
        for row in 1...37 {
            if row % 3 == 0 {
                rows.append(["Row \(row): exact merged words remain editable on their continuation page.", "", "Ready"])
                merges.append(.init(row: row, column: 0, rowSpan: 1, columnSpan: 2))
            } else { rows.append(["Row \(row)", "A longer observation retains every word and wraps at full size.", "Ready"]) }
        }
        let content = TemplateTableContent(rows: rows, columnSizing: .measured(), merges: merges)
        let before = try deck.serializedData()
        let plan = try engine.planTablePages(title: "Groups", table: content, caption: "Exact original source.")
        let estimated = try engine.planTablePages(title: "Groups", table: .init(rows: rows, merges: merges), caption: "Exact original source.")
        #expect(plan.pages.count > 1)
        #expect(plan.pages.count < estimated.pages.count)
        #expect(try deck.serializedData() == before)
        let slides = try engine.composeTablePages(plan)
        let bytes = try deck.serializedData(), reopened = try Presentation(data: bytes)
        // Retain the registered fixture faces for independent reopened measurement.
        var saved: [[String]] = []
        for (index, page) in plan.pages.enumerated() {
            let frame = try #require(reopened.slides[index + 1].shapes.all.compactMap { $0 as? TableFrame }.first)
            let native = try #require(frame.table), accepted = try #require(page.slide.tableLayout)
            let sourceRows = [0] + Array(page.bodyRows)
            let expected = sourceRows.enumerated().flatMap { local, source in
                merges.filter { $0.row == source }.map {
                    TableMergeRegion(row: local, column: $0.column, rowSpan: 1, columnSpan: $0.columnSpan)
                }
            }
            #expect(try native.mergedRegions == expected)
            let actual = try TableLayoutEngine(presentation: deck).plan(native, minimumRowHeight: .points(30))
            #expect(actual.fits && actual.columnWidths == accepted.columnWidths)
            #expect(zip(actual.rowHeights, accepted.rowHeights).allSatisfy { $0 <= $1 })
            #expect(frame.frame.maxY + .points(8) <= (try #require(page.slide.captionFrame)).y)
            for row in 0..<native.rowCount {
                let values = try (0..<3).map { try native.cell(row, $0).text }
                if row == 0 { #expect(values == rows[0]) } else { saved.append(values) }
            }
            #expect(try slides[index].shapes.all.compactMap { ($0 as? TableFrame)?.table }.first?.mergedRegions == expected)
        }
        #expect(saved == Array(rows.dropFirst()))
        #expect(try deck.serializedData() == bytes)
        deck.slideSize = (deck.slideSize.width, deck.slideSize.height * 2)
        let changed = try deck.serializedData()
        #expect(throws: LayoutError.self) { try engine.composeTablePages(plan) }
        #expect(try deck.serializedData() == changed)
    }

    @Test func invalidSpansAndCoveredWordsRefuseBeforeMutation() throws {
        let deck = try fixture(), engine = TemplateLayoutEngine(presentation: deck)
        let valid = TableMergeRegion(row: 0, column: 0, rowSpan: 1, columnSpan: 2)
        let variants = [
            [TableMergeRegion(row: -1, column: 0, rowSpan: 1, columnSpan: 2)],
            [.init(row: 2, column: 0, rowSpan: 1, columnSpan: 2)],
            [.init(row: 0, column: -1, rowSpan: 1, columnSpan: 2)],
            [.init(row: 0, column: 0, rowSpan: 2, columnSpan: 2)],
            [.init(row: 0, column: 0, rowSpan: 1, columnSpan: Int.max)],
            [.init(row: 0, column: Int.max, rowSpan: 1, columnSpan: 2)],
            [.init(row: 0, column: 0, rowSpan: 1, columnSpan: 1)], [valid, valid],
            [valid, .init(row: 0, column: 1, rowSpan: 1, columnSpan: 2)]
        ]
        let before = try deck.serializedData()
        for merges in variants {
            #expect(throws: LayoutError.self) {
                try engine.planTablePages(title: "Invalid", table: .init(rows: [["Heading", "", ""]], merges: merges))
            }
        }
        for covered in ["Original words", " ", "\n"] {
            #expect(throws: LayoutError.self) {
                try engine.plan(title: "Words", columns: [], preferredTypes: ["obj"], object: "tbl",
                    table: .init(rows: [["Heading", covered]], merges: [valid]))
            }
        }
        #expect(try deck.serializedData() == before)
        let native = try table(deck, rows: [["One", "Two", "Three"]])
        let pristine = try deck.serializedData()
        #expect(throws: RostrumError.self) { try native.merge([valid, valid]) }
        #expect(try deck.serializedData() == pristine)
    }

    @Test func headerOnlyAndSingleSlideRespectSpansAndFixedBounds() throws {
        let deck = try fixture(), engine = TemplateLayoutEngine(presentation: deck)
        let content = TemplateTableContent(rows: [["One grouped header", "", "Status"]],
            columnSizing: .measured(constraints: [.init(minimum: .points(70), maximum: .points(70)),
                .init(minimum: .points(100)), .init(minimum: .points(90), maximum: .points(90))]),
            merges: [.init(row: 0, column: 0, rowSpan: 1, columnSpan: 2)])
        let pages = try engine.planTablePages(title: "Header", table: content)
        #expect(pages.pages.count == 1 && pages.pages[0].bodyRows.isEmpty)
        let plan = try engine.plan(title: "Header", columns: [], preferredTypes: ["obj"], object: "tbl", table: content)
        let slide = try engine.compose(plan, title: "Header", columns: [])
        let tables = slide.shapes.all.compactMap { ($0 as? TableFrame)?.table }
        let native = try #require(tables.first)
        #expect(try native.mergedRegions == content.merges)
        let geometry = try #require(plan.tableLayout)
        #expect(geometry.columnWidths[0] == .points(70) && geometry.columnWidths[2] == .points(90))
        #expect(try TableLayoutEngine(presentation: deck).plan(native).fits)
    }

    @Test func verticalSpansFitButMalformedNativeSpansStillThrow() throws {
        let deck = try fixture(), native = try table(deck, rows: [["Vertical", "Other"], ["", "Cell"]])
        try native.merge(row: 0, column: 0, rowSpan: 2, columnSpan: 1)
        let engine = TableLayoutEngine(presentation: deck), before = try deck.serializedData()
        let plan = try engine.plan(native)
        #expect(plan.fits && plan.cells[0].rowSpan == 2 && plan.cells[2].isMergeContinuation)
        #expect(try deck.serializedData() == before)
        try native.cell(0, 0).tc[attribute: "gridSpan"] = String(Int.max)
        native.part.markDirty()
        let malformed = try deck.serializedData()
        #expect(throws: RostrumError.self) { try engine.plan(native) }
        #expect(try deck.serializedData() == malformed)
    }

    @Test func boundedSearchAndPreparationFallbackRetainCompleteSpans() throws {
        let deck = try fixture()
        let rows = (0..<3000).map { ["Grouped observation \($0) retains every original word while wrapping.", "", "Value \($0)"] }
        let merges = rows.indices.map { TableMergeRegion(row: $0, column: 0, rowSpan: 1, columnSpan: 2) }
        let content = TemplateTableContent(rows: rows, columnSizing: .measured(), merges: merges)
        let plan = try content.planned(in: deck, width: .points(500), font: "DejaVu Sans", size: 18,
            theme: deck.theme, pagination: true, availableHeight: .points(350))
        let search = try #require(plan.columnSearch)
        #expect(plan.fits && plan.cells.count == rows.count * 3 && plan.rowHeights.count == rows.count)
        #expect(search.evaluatedCandidates <= 24 && search.additionalCellMeasurements <= 32_768 && search.budgetExhausted)
        #expect(plan.cells.filter(\.isMergeContinuation).count == rows.count)
        let native = try table(deck, rows: rows)
        try native.merge(merges)
        let fresh = try TableLayoutEngine(presentation: deck).plan(native, columnWidths: plan.columnWidths,
            minimumRowHeight: .points(30), theme: deck.theme, pagination: true)
        equal(plan, fresh)
    }

    @Test func freshOperationsObserveAnchorTextFontsAndTopology() throws {
        let deck = try fixture(), native = try table(deck, rows: [["Grouped words", "", "Status"]])
        native.setLayoutContents([["Grouped words", "", "Status"]], font: "Registered later", size: 18)
        try native.merge(row: 0, column: 0, rowSpan: 1, columnSpan: 2)
        let engine = TableLayoutEngine(presentation: deck)
        let widths: [EMU] = [.points(60), .points(120), .points(100)]
        let before = try engine.plan(native, columnWidths: widths)
        let missing = ShapingDiagnostic.unsupportedLayoutFeature("Unregistered font face: Registered later")
        #expect(before.cells[0].diagnostics.contains(missing))
        let font = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("RostrumTests/Fixtures/Typography/DejaVuSans.ttf")
        try deck.fonts.register(contentsOf: font, aliases: ["Registered later"])
        let after = try engine.plan(native, columnWidths: widths)
        #expect(!after.cells[0].diagnostics.contains(missing))
        try native.cell(0, 0).text = "More exact original words now require substantially more space to wrap."
        let changed = try engine.plan(native, columnWidths: widths)
        #expect(changed.rowHeights[0] > after.rowHeights[0])
        try native.unmerge(row: 0, column: 0)
        let split = try engine.plan(native, columnWidths: widths)
        #expect(split.cells[0].columnSpan == 1 && !split.cells[1].isMergeContinuation)
        #expect(split.rowHeights[0] > changed.rowHeights[0])
    }
}
