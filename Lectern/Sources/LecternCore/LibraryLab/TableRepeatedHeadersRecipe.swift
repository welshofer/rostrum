import Foundation
import Rostrum
import RostrumLayout

enum TableRepeatedHeadersRecipe {
    static func append(to draft: LibraryLabDraft) throws -> LibraryLabDraft {
        var result = draft
        let input = try PlatformLabRecipes.require(draft.extraFiles["table-layout-template.potx"], "Repeated header template missing")
        let deck = try Presentation.fromTemplate(data: input)
        _ = deck.registerEmbeddedFonts()
        let headerRowCount = 2
        var rows = [["Source", "Evidence", "", "State"], ["", "Observation", "Detail", ""]]
        var merges: [TableMergeRegion] = [
            .init(row: 0, column: 0, rowSpan: 2, columnSpan: 1),
            .init(row: 0, column: 1, rowSpan: 1, columnSpan: 2),
            .init(row: 0, column: 3, rowSpan: 2, columnSpan: 1)]
        for group in 1...8 {
            let row = rows.count
            rows += [["Group \(group)", "Observation \(group).1", "Exact source evidence.", "Ready"],
                     ["", "Observation \(group).2", "Every word stays editable.", "Saved"]]
            merges.append(.init(row: row, column: 0, rowSpan: 2, columnSpan: 1))
        }
        let caption = "Complete headers repeat. Connected source rows stay together."
        let engine = TemplateLayoutEngine(presentation: deck)
        let plan = try engine.planTablePages(title: "Grouped headers on every page", table: .init(rows: rows,
            columnWeights: [1, 2, 2, 1], columnSizing: .measured(), merges: merges, headerRowCount: headerRowCount), caption: caption)
        let slides = try engine.composeTablePages(plan)
        for slide in slides { try slide.setNotes("Original source notes remain on every continuation. Two header rows repeat with native spans. First-row styling still applies only to row zero; oversized headers/groups and merges across the header/body boundary are refused. Native PowerPoint visual acceptance remains pending.") }
        let first = draft.deck.slides.count
        let svgs = try slides.indices.map { try deck.renderSVG(slideAt: $0) }
        try draft.deck.slides.importAll(from: deck)
        result.extraFiles["repeated-headers-output.pptx"] = try deck.serializedData()
        result.checks.append(.init("Repeated headers preserve complete body groups", slides.count > 1
            && plan.pages.flatMap { Array($0.bodyRows) } == Array(headerRowCount..<rows.count)
            && plan.pages.allSatisfy { $0.headerRowCount == headerRowCount && ($0.bodyRows.lowerBound - headerRowCount) % 2 == 0 && $0.bodyRows.count % 2 == 0 },
            "Connected rows remain together at full text size; headers and captions repeat."))
        let original = draft.verify
        result.verify = { reopened in
            var checks = try original(reopened)
            _ = reopened.registerEmbeddedFonts()
            var retained: [[String]] = [], topology = true, fits = true, previews = true, headers = true, notes = true
            for (index, page) in plan.pages.enumerated() {
                let slide = try reopened.slides[first + index]
                let frame = try PlatformLabRecipes.require(slide.shapes.all.compactMap { $0 as? TableFrame }.first, "Saved repeated header continuation missing")
                let table = try PlatformLabRecipes.require(frame.table, "Saved repeated header table missing")
                let accepted = try PlatformLabRecipes.require(page.slide.tableLayout, "Repeated header geometry missing")
                let actual = try TableLayoutEngine(presentation: reopened).plan(table, minimumRowHeight: .points(30))
                let expected = merges.filter { $0.row < headerRowCount || page.bodyRows.contains($0.row) }.map {
                    TableMergeRegion(row: $0.row < headerRowCount ? $0.row : $0.row - page.bodyRows.lowerBound + headerRowCount, column: $0.column,
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
                    let values = try (0..<4).map { try table.cell(row, $0).text }
                    if row < headerRowCount { headers = headers && values == rows[row] } else { retained.append(values) }
                }
                notes = notes && slide.notesText.contains("Original source notes remain on every continuation.")
                let svg = try reopened.renderSVG(slideAt: first + index)
                previews = previews && svg == svgs[index]
            }
            checks += [
                .init("Saved repeated headers retain topology and source", topology && headers && notes && retained == Array(rows.dropFirst(headerRowCount)),
                    "Repeated headers, all source cells, native row/column spans and notes survive reopening in their original order."),
                .init("Saved repeated headers and body groups fit", fits,
                    "Every anchor fits its complete saved rectangle; tables and captions stay inside the slide."),
                .init("Saved repeated header previews remain identical", previews,
                    "Production inspection/export preserves each continuation SVG. Native PowerPoint acceptance remains separate.")
            ]
            return checks
        }
        return result
    }
}
