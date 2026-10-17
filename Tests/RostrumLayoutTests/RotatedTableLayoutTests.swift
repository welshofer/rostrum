import Foundation
import Testing
@testable import Rostrum
@testable import RostrumLayout

@Suite struct RotatedTableLayoutTests {
    private func fixture(_ rows: [[String]]) throws -> (Presentation, Table) {
        let deck = try Presentation()
        deck.theme.minorFont = "DejaVu Sans"
        try registerFonts(in: deck)
        let table = try deck.slides[0].shapes.addTable(rows: rows.count, columns: rows[0].count, frame: deck.bounds)
        table.setLayoutContents(rows, font: "DejaVu Sans", size: 18)
        table.clearBuiltInStyle()
        return (deck, table)
    }

    private func registerFonts(in deck: Presentation) throws {
        let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("RostrumTests/Fixtures/NativeGlyphPlacement/eligibility/fonts")
        for face in ["DejaVuSans", "DejaVuSans-Bold", "DejaVuSans-Oblique"] {
            try deck.fonts.register(contentsOf: directory.appendingPathComponent(face + ".ttf"))
        }
    }

    private func checkFits(_ plan: TableLayoutPlan, table: Table, deck: Presentation) throws {
        #expect(plan.fits)
        for cell in plan.cells where !cell.isMergeContinuation {
            let text = try #require(table.cell(cell.row, cell.column).existingTextFrame)
            let frame = Rect(x: .zero, y: .zero,
                width: plan.columnWidths[cell.column..<(cell.column + cell.columnSpan)].reduce(.zero, +),
                height: plan.rowHeights[cell.row..<(cell.row + cell.rowSpan)].reduce(.zero, +))
            #expect(text.fitText(in: frame, fonts: deck.fonts, theme: deck.theme).fits)
        }
    }

    @Test(arguments: [TableTextDirection.vertical, .vertical270])
    func rotationFitsAtFullSizeAndSurvivesSave(direction: TableTextDirection) throws {
        let words = "Rotated labels keep every original word"
        let (deck, table) = try fixture([[words, words, words]])
        try table.cell(0, 1).textDirection = direction
        try table.cell(0, 2).textDirection = direction
        try table.cell(0, 1).setPadding(left: .points(13), top: .points(3), right: .points(7), bottom: .points(11))
        try table.cell(0, 1).verticalAnchor = .bottom
        let before = try deck.serializedData()
        let engine = TableLayoutEngine(presentation: deck)
        let plan = try engine.plan(table, columnWidths: [.points(70), .points(70), .points(70)])
        try checkFits(plan, table: table, deck: deck)
        #expect(plan.cells[0].requiredHeight != plan.cells[2].requiredHeight)
        #expect(try deck.serializedData() == before)
        table.columnWidths(plan.columnWidths).rowHeights(plan.rowHeights)
        let svg = try deck.renderSVG(slideAt: 0)
        #expect(svg.contains(direction == .vertical ? "rotate(90)" : "rotate(-90)"))
        let bytes = try deck.serializedData(), reopened = try Presentation(data: bytes)
        // Register the same caller-selected faces for the reopened preview.
        try registerFonts(in: reopened)
        let saved = try #require((reopened.slides[0].shapes.all.first { $0 is TableFrame } as? TableFrame)?.table)
        #expect(try saved.cell(0, 1).textDirection == direction && saved.cell(0, 1).text == words)
        let again = try TableLayoutEngine(presentation: reopened).plan(saved)
        #expect(again.rowHeights == plan.rowHeights && again.cells.map(\.requiredHeight) == plan.cells.map(\.requiredHeight))
        try checkFits(again, table: saved, deck: reopened)
        #expect(try reopened.renderSVG(slideAt: 0) == svg)
        #expect(try reopened.serializedData() == bytes)
        #expect(try saved.cell(0, 1).textFrame.paragraphs[0].runs[0].fontSize == 18)
    }

    @Test func widerColumnsPermitShorterRotatedRowsWithoutShrinking() throws {
        let (deck, table) = try fixture([["Long rotated headers wrap at full font size into several lines"]])
        try table.cell(0, 0).textDirection = .vertical270
        let engine = TableLayoutEngine(presentation: deck)
        let narrow = try engine.plan(table, columnWidths: [.points(34)])
        let wide = try engine.plan(table, columnWidths: [.points(90)])
        try checkFits(narrow, table: table, deck: deck)
        try checkFits(wide, table: table, deck: deck)
        #expect(wide.totalHeight < narrow.totalHeight)
        #expect(try !engine.plan(table, columnWidths: [.points(34)], maximumHeight: narrow.totalHeight - EMU(1)).fits)
        try table.cell(0, 0).tc.firstChild(named: "a:txBody")?.firstChild(named: "a:bodyPr")?[attribute: "wrap"] = "none"
        let nowrap = try engine.plan(table, columnWidths: [.points(90)])
        try checkFits(nowrap, table: table, deck: deck)
        #expect(nowrap.totalHeight > wide.totalHeight)
    }

    @Test func shortRotatedLabelsAreNotSqueezedIntoSplitWords() throws {
        let (deck, table) = try fixture([["Source"]])
        try table.cell(0, 0).textDirection = .vertical
        let plan = try TableLayoutEngine(presentation: deck).plan(table, columnWidths: [.points(120)])
        try checkFits(plan, table: table, deck: deck)
        var source = try TableLayoutSource(table: table, theme: deck.theme)
        let input = try #require(TableCellInput.resolve(source: &source, row: 0, column: 0, pagination: false).first)
        let geometry = RotatedTableCellMeasurement.layout(input, width: plan.columnWidths[0],
            height: plan.totalHeight, fonts: deck.fonts, theme: deck.theme)
        #expect(geometry.lines.count == 1 && !geometry.usedEmergencyLineBreak)
        let tooShort = RotatedTableCellMeasurement.layout(input, width: plan.columnWidths[0],
            height: .points(35), fonts: deck.fonts, theme: deck.theme)
        #expect(tooShort.fits && tooShort.usedEmergencyLineBreak)
    }

    @Test func mixedRunsTabsBreaksAndIntersectionsRecheckTheFinalRectangle() throws {
        let (deck, table) = try fixture([["Alpha\t12.5\nBeta", "A neighbor changes the saved shared height"],
            ["", "Second ordinary cell"], ["Last", "Another"]])
        try table.merge(row: 0, column: 0, rowSpan: 2, columnSpan: 1)
        let anchor = try table.cell(0, 0)
        anchor.textDirection = .vertical
        let tail = try #require(anchor.textFrame.paragraphs.last).addRun(" mixed italic")
        tail.fontName = "DejaVu Sans"; tail.fontSize = 23; tail.italic = true
        try table.cell(1, 0).text = "Hidden continuation must not enter fitting"
        try table.cell(1, 0).textDirection = .eastAsianVertical
        let engine = TableLayoutEngine(presentation: deck)
        let reuse = try TableColumnMeasurements(table: table, theme: deck.theme)
        for widths in [[130.0, 80], [130, 250], [175, 100], [130, 80]] {
            let widths = widths.map { EMU.points($0) }
            let cached = try engine.plan(table, columnWidths: widths, minimumRowHeight: .points(35),
                theme: deck.theme, pagination: false, reuse: reuse)
            let fresh = try engine.plan(table, columnWidths: widths, minimumRowHeight: .points(35))
            try checkFits(cached, table: table, deck: deck)
            #expect(cached.rowHeights == fresh.rowHeights && cached.cells.map(\.issues) == fresh.cells.map(\.issues))
            #expect(cached.cells.map(\.diagnostics) == fresh.cells.map(\.diagnostics))
            #expect(cached.cells[2].isMergeContinuation && cached.cells[2].issues.isEmpty)
        }
        #expect(reuse.reusedCells > 0)
    }

    @Test func impossibleBlockWidthAndLineLimitRemainExplicit() throws {
        let (deck, table) = try fixture([["Too wide"], [Array(repeating: "Break", count: 65).joined(separator: "\n")]])
        for row in 0..<2 { try table.cell(row, 0).textDirection = .vertical }
        let engine = TableLayoutEngine(presentation: deck)
        let small = try engine.plan(table, columnWidths: [.points(8)])
        #expect(!small.fits && small.cells[0].issues.contains(.horizontalOverflow))
        let many = try engine.plan(table, columnWidths: [.points(3000)])
        #expect(!many.fits && many.cells[1].issues.contains(.lineLimit))
    }

    @Test func rectangularRotatedAnchorsUseBothColumnAndRowSpans() throws {
        let words = "A rotated rectangular anchor retains its original words"
        let (deck, table) = try fixture([[words, "", "Neighbor"], ["", "", "Another neighbor"]])
        try table.merge(row: 0, column: 0, rowSpan: 2, columnSpan: 2)
        try table.cell(0, 0).textDirection = .vertical270
        let plan = try TableLayoutEngine(presentation: deck).plan(table,
            columnWidths: [.points(30), .points(40), .points(140)])
        let (controlDeck, control) = try fixture([[words]])
        try control.cell(0, 0).textDirection = .vertical270
        let expected = try TableLayoutEngine(presentation: controlDeck).plan(control, columnWidths: [.points(70)])
        #expect(plan.cells[0].requiredHeight == expected.cells[0].requiredHeight)
        #expect(plan.cells.filter(\.isMergeContinuation).count == 3)
        try checkFits(plan, table: table, deck: deck)
        #expect(plan.totalHeight >= expected.totalHeight)
        // Native cell direction is supported; a conflicting body direction is
        // still refused instead of certifying a preview that ignores it.
        try table.cell(0, 0).tc.firstChild(named: "a:txBody")?.firstChild(named: "a:bodyPr")?[attribute: "vert"] = "vert270"
        #expect(try TableLayoutEngine(presentation: deck).plan(table).cells[0].issues == [.verticalText])
    }

    @Test func freshOperationsObserveFontContentAndDirectionChanges() throws {
        let (deck, table) = try fixture([["A long row label with several exact words"]])
        let cell = try table.cell(0, 0)
        cell.textDirection = .vertical270
        let run = try #require(cell.textFrame.paragraphs.first?.runs.first)
        run.fontName = "Registered later"
        let engine = TableLayoutEngine(presentation: deck), widths: [EMU] = [.points(50)]
        let missing = try engine.plan(table, columnWidths: widths)
        #expect(!missing.cells[0].diagnostics.isEmpty)
        let font = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("RostrumTests/Fixtures/Typography/DejaVuSans.ttf")
        try deck.fonts.register(contentsOf: font, aliases: ["Registered later"])
        let registered = try engine.plan(table, columnWidths: widths)
        #expect(!registered.cells[0].diagnostics.contains(.unsupportedLayoutFeature("Unregistered font face: Registered later")))
        cell.text = "Short"
        let short = try engine.plan(table, columnWidths: widths)
        #expect(short.totalHeight < registered.totalHeight)
        cell.textDirection = .eastAsianVertical
        #expect(try engine.plan(table, columnWidths: widths).cells[0].issues == [.verticalText])
    }

    @Test(arguments: [false, true])
    func templatesRepeatRotatedHeadersAndRemapBodyAnchors(measured: Bool) throws {
        let (deck, _) = try fixture([["Seed"]]), engine = TemplateLayoutEngine(presentation: deck)
        var rows = [["Source", "Evidence", "State"], ["", "Detail", ""]]
        var directions: [TableCellTextDirection] = [.init(row: 0, column: 0, direction: .vertical),
            .init(row: 0, column: 2, direction: .vertical270)]
        var merges: [TableMergeRegion] = [.init(row: 0, column: 0, rowSpan: 2, columnSpan: 1),
            .init(row: 0, column: 2, rowSpan: 2, columnSpan: 1)]
        for group in 0..<10 {
            let row = rows.count
            rows += [["Group \(group)", "All exact source evidence stays with its group.", "Ready"],
                     ["", "Another exact observation remains editable.", "Saved"]]
            merges.append(.init(row: row, column: 0, rowSpan: 2, columnSpan: 1))
            directions.append(.init(row: row, column: 0, direction: .vertical270))
        }
        let content = TemplateTableContent(rows: rows, columnWeights: [1, 6, 1],
            columnSizing: measured ? .measured() : .estimated, merges: merges,
            headerRowCount: 2, textDirections: directions)
        let plan = try engine.planTablePages(title: "Rotated cells", table: content, caption: "Exact source words.")
        #expect(plan.pages.count > 1)
        #expect(plan.pages.flatMap { Array($0.bodyRows) } == Array(2..<rows.count))
        let slides = try engine.composeTablePages(plan)
        let bytes = try deck.serializedData(), reopened = try Presentation(data: bytes)
        try registerFonts(in: reopened)
        for (index, page) in plan.pages.enumerated() {
            let sourceRows = [0, 1] + Array(page.bodyRows)
            let savedSlide = try reopened.slides[index + 1]
            let frame = try #require(savedSlide.shapes.all.compactMap { $0 as? TableFrame }.first)
            let table = try #require(frame.table)
            #expect(frame.frame.maxY + .points(8) <= (page.slide.captionFrame?.y ?? .zero))
            #expect(frame.frame.maxY <= reopened.bounds.height)
            let geometry = try #require(page.slide.tableLayout)
            try checkFits(geometry, table: table, deck: reopened)
            for (row, source) in sourceRows.enumerated() {
                for column in 0..<3 {
                    let cell = try table.cell(row, column)
                    #expect(cell.text == rows[source][column])
                    #expect(cell.textDirection == (directions.first { $0.row == source && $0.column == column }?.direction ?? .horizontal))
                }
            }
            #expect(try deck.renderSVG(slideAt: index + 1) == reopened.renderSVG(slideAt: index + 1))
        }
        #expect(slides.count == plan.pages.count)
        #expect(try reopened.serializedData() == bytes)
    }

    @Test func invalidDirectionOverridesFailBeforeMutation() throws {
        let (deck, _) = try fixture([["Seed"]]), engine = TemplateLayoutEngine(presentation: deck)
        let before = try deck.serializedData()
        for directions in [
            [TableCellTextDirection(row: -1, column: 0, direction: .vertical)],
            [.init(row: 0, column: 2, direction: .vertical)],
            [.init(row: 0, column: 0, direction: .vertical), .init(row: 0, column: 0, direction: .horizontal)],
            [.init(row: 0, column: 0, direction: .wordArtVertical)],
            [.init(row: 0, column: 1, direction: .vertical270)]
        ] {
            let content = TemplateTableContent(rows: [["Header", ""], ["A", "B"]],
                merges: [.init(row: 0, column: 0, rowSpan: 1, columnSpan: 2)], textDirections: directions)
            #expect(throws: LayoutError.self) { try engine.planTablePages(title: "Invalid", table: content) }
            #expect(try deck.serializedData() == before)
        }
    }
}
