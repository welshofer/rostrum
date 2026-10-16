import Foundation
import Testing
@testable import Rostrum
@testable import RostrumLayout

@Suite struct TableVerticalSpanTests {
    private func fixture(_ rows: [[String]]) throws -> (Presentation, Table) {
        let deck = try Presentation()
        deck.theme.minorFont = "DejaVu Sans"
        let fonts = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("RostrumTests/Fixtures/NativeGlyphPlacement/eligibility/fonts")
        for face in ["DejaVuSans", "DejaVuSans-Bold", "DejaVuSans-Oblique"] {
            try deck.fonts.register(contentsOf: fonts.appendingPathComponent(face + ".ttf"))
        }
        let table = try deck.slides[0].shapes.addTable(rows: rows.count, columns: rows[0].count, frame: deck.bounds)
        table.setLayoutContents(rows, font: "DejaVu Sans", size: 18)
        table.clearBuiltInStyle()
        return (deck, table)
    }

    private func equal(_ lhs: TableLayoutPlan, _ rhs: TableLayoutPlan) {
        #expect(lhs.columnWidths == rhs.columnWidths && lhs.rowHeights == rhs.rowHeights)
        #expect(lhs.totalHeight == rhs.totalHeight && lhs.fits == rhs.fits && lhs.cells.count == rhs.cells.count)
        for (a, b) in zip(lhs.cells, rhs.cells) {
            #expect(a.row == b.row && a.column == b.column && a.requiredHeight == b.requiredHeight)
            #expect(a.rowSpan == b.rowSpan && a.columnSpan == b.columnSpan && a.isMergeContinuation == b.isMergeContinuation)
            #expect(a.issues == b.issues && a.diagnostics == b.diagnostics)
        }
    }

    @Test func oneAnchorUsesAllRowsAndIgnoresHiddenContinuationPayload() throws {
        let (deck, table) = try fixture([["Exact words wrap across the complete merged cell."], [""], [""]])
        try table.merge(row: 0, column: 0, rowSpan: 3, columnSpan: 1)
        let anchor = try table.cell(0, 0)
        anchor.setPadding(left: .points(13), top: .points(11), right: .points(9), bottom: .points(7))
        let paragraph = try #require(anchor.textFrame.paragraphs.first)
        paragraph.p.appendElement(XML.Element("a:br"))
        let tail = paragraph.addRun("Mixed italic tail")
        tail.italic = true; tail.fontSize = 23; tail.fontName = "DejaVu Sans"
        let covered = try table.cell(1, 0)
        covered.text = Array(repeating: "Hidden", count: 80).joined(separator: "\n")
        covered.tc.getOrAddChild("a:tcPr")[attribute: "vert"] = "vert"
        let before = try deck.serializedData(), engine = TableLayoutEngine(presentation: deck)
        let plan = try engine.plan(table, columnWidths: [.points(170)])
        #expect(plan.fits && plan.cells[0].rowSpan == 3 && plan.cells[0].columnSpan == 1)
        #expect(plan.totalHeight == plan.cells[0].requiredHeight)
        #expect((plan.rowHeights.max()! - plan.rowHeights.min()!).rawValue <= 1)
        for cell in plan.cells.dropFirst() {
            #expect(cell.isMergeContinuation && cell.requiredHeight == .zero && cell.issues.isEmpty && cell.diagnostics.isEmpty)
        }
        #expect(try deck.serializedData() == before)
        table.columnWidths(plan.columnWidths).rowHeights(plan.rowHeights)
        let savedBytes = try deck.serializedData(), reopened = try Presentation(data: savedBytes)
        let tables = try reopened.slides[0].shapes.all.compactMap { ($0 as? TableFrame)?.table }
        let saved = try #require(tables.first)
        equal(plan, try engine.plan(saved))
        #expect(try saved.cell(1, 0).text == covered.text)
        #expect(try saved.mergedRegions == table.mergedRegions)
        let text = try #require(saved.cell(0, 0).existingTextFrame)
        #expect(text.fitText(in: Rect(x: .zero, y: .zero, width: plan.columnWidths[0], height: plan.totalHeight),
            fonts: deck.fonts, theme: reopened.theme).fits)
        #expect(try reopened.serializedData() == savedBytes)
    }

    @Test func rectangularSpansUseCombinedWidthAndOrdinaryRowMinimums() throws {
        let words = "A rectangular merged cell keeps all these words at their original size."
        let (deck, table) = try fixture([[words, "", "One"], ["", "", "Two\nlines"], ["A", "B", "C"]])
        let engine = TableLayoutEngine(presentation: deck)
        try table.merge(row: 0, column: 0, rowSpan: 2, columnSpan: 2)
        let plan = try engine.plan(table, columnWidths: [.points(65), .points(115), .points(90)], minimumRowHeight: .points(30))
        let (other, control) = try fixture([[words]])
        let expected = try TableLayoutEngine(presentation: other).plan(control, columnWidths: [.points(180)])
        #expect(plan.fits && plan.cells[0].rowSpan == 2 && plan.cells[0].columnSpan == 2)
        #expect(plan.cells[0].requiredHeight == expected.cells[0].requiredHeight)
        #expect(plan.cells.filter(\.isMergeContinuation).count == 3)
        #expect(plan.rowHeights.prefix(2).reduce(.zero, +) >= expected.totalHeight)
        for cell in plan.cells where !cell.isMergeContinuation && cell.rowSpan == 1 {
            #expect(plan.rowHeights[cell.row] >= cell.requiredHeight)
        }
        #expect(plan.rowHeights.allSatisfy { $0 >= .points(30) })
        #expect(try engine.plan(table, columnWidths: plan.columnWidths, minimumRowHeight: .points(30), maximumHeight: plan.totalHeight).fits)
        #expect(try !engine.plan(table, columnWidths: plan.columnWidths, minimumRowHeight: .points(30), maximumHeight: plan.totalHeight - EMU(1)).fits)
    }

    @Test func intersectingRowRangesKeepEveryConstraintAndDeterministicRemainders() throws {
        let (deck, table) = try fixture([["First\nsecond\nthird\nfourth", "Short"], ["", "Other\nlong\nmerged\ntext\nblock"], ["Short", ""]])
        try table.merge([.init(row: 0, column: 0, rowSpan: 2, columnSpan: 1),
            .init(row: 1, column: 1, rowSpan: 2, columnSpan: 1)])
        let engine = TableLayoutEngine(presentation: deck)
        let plan = try engine.plan(table, columnWidths: [.points(120), .points(120)], minimumRowHeight: EMU(1))
        #expect(plan.fits)
        for cell in plan.cells where !cell.isMergeContinuation {
            #expect(plan.rowHeights[cell.row..<(cell.row + cell.rowSpan)].reduce(.zero, +) >= cell.requiredHeight)
        }
        equal(plan, try engine.plan(table, columnWidths: plan.columnWidths, minimumRowHeight: EMU(1)))
        // The same row constraints hold after writing/reopening the native grid.
        table.columnWidths(plan.columnWidths).rowHeights(plan.rowHeights)
        let reopened = try Presentation(data: deck.serializedData())
        let tables = try reopened.slides[0].shapes.all.compactMap { ($0 as? TableFrame)?.table }
        let saved = try #require(tables.first)
        equal(plan, try engine.plan(saved, minimumRowHeight: EMU(1)))
    }

    @Test func cachedWidthTrialsRecomputeCrossRowConstraints() throws {
        let (deck, table) = try fixture([["Long rectangular content must wrap across two columns and three rows.", "", "An ordinary neighbor also wraps when narrowed."],
            ["", "", "Two"], ["", "", "Three\nlines\nhere"],
            ["A second vertical span with distinct text.", "Neighboring ordinary cells change the shared row minima.", "Value"], ["", "Last", "End"]])
        try table.merge([.init(row: 0, column: 0, rowSpan: 3, columnSpan: 2),
            .init(row: 3, column: 0, rowSpan: 2, columnSpan: 1)])
        let engine = TableLayoutEngine(presentation: deck)
        let reuse = try TableColumnMeasurements(table: table, theme: deck.theme)
        var rowHeights: [[EMU]] = []
        for values in [[50, 60, 190], [50, 60, 50], [50, 140, 110], [100, 90, 110], [50, 60, 190]] {
            let widths = values.map { EMU.points(Double($0)) }
            let cached = try engine.plan(table, columnWidths: widths, minimumRowHeight: .points(20),
                theme: deck.theme, pagination: false, reuse: reuse)
            equal(cached, try engine.plan(table, columnWidths: widths, minimumRowHeight: .points(20)))
            #expect(cached.fits)
            rowHeights.append(cached.rowHeights)
        }
        #expect(rowHeights[0] != rowHeights[1] && rowHeights[0] == rowHeights[4])
        #expect(reuse.reusedCells > 0 && reuse.preparation.cellCount == 9)
        let pagination = try engine.plan(table, columnWidths: [.points(100), .points(100), .points(100)],
            minimumRowHeight: .zero, theme: deck.theme, pagination: true)
        #expect(!pagination.fits && pagination.cells[0].issues == [.mergedCell])
    }

    @Test func freshCallsObserveFontsTextStylesAndUnmerging() throws {
        let (deck, table) = try fixture([["Anchor"], [""]])
        table.setLayoutContents([["Anchor"], [""]], font: "Registered later", size: 18)
        try table.merge(row: 0, column: 0, rowSpan: 2, columnSpan: 1)
        let engine = TableLayoutEngine(presentation: deck), widths: [EMU] = [.points(130)]
        let before = try engine.plan(table, columnWidths: widths)
        let missing = ShapingDiagnostic.unsupportedLayoutFeature("Unregistered font face: Registered later")
        #expect(before.cells[0].diagnostics.contains(missing))
        let font = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("RostrumTests/Fixtures/Typography/DejaVuSans.ttf")
        try deck.fonts.register(contentsOf: font, aliases: ["Registered later"])
        let registered = try engine.plan(table, columnWidths: widths)
        #expect(!registered.cells[0].diagnostics.contains(missing))
        try table.cell(0, 0).text = "More original words need substantially more room to wrap at full size."
        let edited = try engine.plan(table, columnWidths: widths)
        #expect(edited.totalHeight > registered.totalHeight)
        try table.cell(0, 0).setPadding(left: .points(7.2), top: .points(31), right: .points(7.2), bottom: .points(29))
        let padded = try engine.plan(table, columnWidths: widths)
        #expect(padded.totalHeight > edited.totalHeight)
        try table.unmerge(row: 0, column: 0)
        let split = try engine.plan(table, columnWidths: widths)
        #expect(split.cells.allSatisfy { $0.rowSpan == 1 && !$0.isMergeContinuation })
        #expect(split.rowHeights[0] == padded.cells[0].requiredHeight)
    }

    @Test func metadataRetainsTheNativeSpanIntegerRange() {
        let limit = Int(Int32.max)
        let cell = TableCellLayout(row: 0, column: 0, requiredHeight: .zero,
            issues: [], diagnostics: [], columnSpan: limit, rowSpan: limit)
        #expect(cell.rowSpan == limit && cell.columnSpan == limit && !cell.isMergeContinuation)
        let covered = TableCellLayout(row: 1, column: 1, requiredHeight: .zero,
            issues: [], diagnostics: [], isMergeContinuation: true)
        #expect(covered.rowSpan == 1 && covered.columnSpan == 1 && covered.isMergeContinuation)
    }

    @Test func tallSpanRetainsMinimumsWithoutMultiplyingAnchorHeight() throws {
        let count = 2048
        let (deck, table) = try fixture([["One anchor"]] + Array(repeating: [""], count: count - 1))
        try table.merge(row: 0, column: 0, rowSpan: count, columnSpan: 1)
        let plan = try TableLayoutEngine(presentation: deck).plan(table, columnWidths: [.points(200)], minimumRowHeight: .points(2))
        #expect(plan.fits && plan.rowHeights == Array(repeating: .points(2), count: count))
        #expect(plan.totalHeight == .points(Double(count * 2)))
        #expect(plan.cells.filter(\.isMergeContinuation).count == count - 1)
    }
}
