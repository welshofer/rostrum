import Foundation
import Rostrum
import RostrumLayout

enum TableVerticalPaginationRecipe {
    static func append(to draft: LibraryLabDraft) throws -> LibraryLabDraft {
        var result = draft
        let input = try PlatformLabRecipes.require(draft.extraFiles["table-layout-template.potx"], "Merged pagination template missing")
        let deck = try Presentation.fromTemplate(data: input)
        _ = deck.registerEmbeddedFonts()
        var rows = [["Group", "Evidence", "State"]]
        var merges: [TableMergeRegion] = []
        for group in 1...6 {
            let row = rows.count
            rows += [["Group \(group)", "Exact source observation \(group).", "Ready"],
                     ["", "Every original word stays editable.", "Reviewed"],
                     ["A connected summary preserves the complete source for group \(group).", "", ""],
                     ["", "", "Saved"]]
            merges += [.init(row: row, column: 0, rowSpan: 2, columnSpan: 1),
                       .init(row: row + 1, column: 2, rowSpan: 2, columnSpan: 1),
                       .init(row: row + 2, column: 0, rowSpan: 2, columnSpan: 2)]
        }
        let caption = "Merged cells stay together. All source text remains editable."
        let engine = TemplateLayoutEngine(presentation: deck)
        let plan = try engine.planTablePages(title: "Merged groups stay together", table: .init(rows: rows,
            columnWeights: [1, 2.5, 1], columnSizing: .measured(), merges: merges), caption: caption)
        let slides = try engine.composeTablePages(plan)
        for slide in slides { try slide.setNotes("Original source notes remain on every continuation. Single repeated header; oversized merged groups are refused. Native PowerPoint visual acceptance remains pending.") }
        let first = draft.deck.slides.count
        let svgs = try slides.indices.map { try deck.renderSVG(slideAt: $0) }
        try draft.deck.slides.importAll(from: deck)
        result.extraFiles["vertical-pagination-output.pptx"] = try deck.serializedData()
        result.checks.append(.init("Merged pagination covers every source row", slides.count > 1
            && plan.pages.flatMap { Array($0.bodyRows) } == Array(1..<rows.count)
            && plan.pages.allSatisfy { ($0.bodyRows.lowerBound - 1) % 4 == 0 && ($0.bodyRows.upperBound - 1) % 4 == 0 },
            "Connected rows remain together at full text size; headers and captions repeat."))
        let original = draft.verify
        result.verify = { reopened in
            var checks = try original(reopened)
            _ = reopened.registerEmbeddedFonts()
            var retained: [[String]] = [], topology = true, fits = true, previews = true, headers = true, notes = true
            for (index, page) in plan.pages.enumerated() {
                let slide = try reopened.slides[first + index]
                let frame = try PlatformLabRecipes.require(slide.shapes.all.compactMap { $0 as? TableFrame }.first, "Saved merged continuation missing")
                let table = try PlatformLabRecipes.require(frame.table, "Saved merged table missing")
                let accepted = try PlatformLabRecipes.require(page.slide.tableLayout, "Merged pagination geometry missing")
                let actual = try TableLayoutEngine(presentation: reopened).plan(table, minimumRowHeight: .points(30))
                let expected = merges.filter { page.bodyRows.contains($0.row) }.map {
                    TableMergeRegion(row: $0.row - page.bodyRows.lowerBound + 1, column: $0.column,
                        rowSpan: $0.rowSpan, columnSpan: $0.columnSpan)
                }
                let savedMerges = try table.mergedRegions
                topology = topology && savedMerges == expected
                fits = fits && actual.fits && actual.columnWidths == accepted.columnWidths
                    && frame.frame.maxY + .points(8) <= (page.slide.captionFrame?.y ?? .zero)
                    && frame.frame.maxY <= reopened.bounds.height
                    && slide.shapes.all.contains { $0.textFrame?.text == caption }
                for cell in actual.cells where !cell.isMergeContinuation {
                    let height = accepted.rowHeights[cell.row..<(cell.row + cell.rowSpan)].reduce(.zero, +)
                    let body = try PlatformLabRecipes.require(table.cell(cell.row, cell.column).existingTextFrame, "Saved spanning body missing")
                    fits = fits && cell.requiredHeight <= height && body.fitText(in: Rect(x: .zero, y: .zero,
                        width: accepted.columnWidths[cell.column..<(cell.column + cell.columnSpan)].reduce(.zero, +),
                        height: height), fonts: reopened.fonts, theme: slide.master?.theme).fits
                }
                for row in 0..<table.rowCount {
                    let values = try (0..<3).map { try table.cell(row, $0).text }
                    if row == 0 { headers = headers && values == rows[0] } else { retained.append(values) }
                }
                notes = notes && slide.notesText.contains("Original source notes remain on every continuation.")
                let svg = try reopened.renderSVG(slideAt: first + index)
                previews = previews && svg == svgs[index]
            }
            checks += [
                .init("Saved merged pages retain topology and source", topology && headers && notes && retained == Array(rows.dropFirst()),
                    "Repeated headers, all source cells, native row/column spans and notes survive reopening in their original order."),
                .init("Saved merged pages fit their combined cell areas", fits,
                    "Every anchor fits its complete saved rectangle; tables and captions stay inside the slide."),
                .init("Saved merged page previews remain identical", previews,
                    "Production inspection/export preserves each continuation SVG. Native PowerPoint acceptance remains separate.")
            ]
            return checks
        }
        return result
    }
}
