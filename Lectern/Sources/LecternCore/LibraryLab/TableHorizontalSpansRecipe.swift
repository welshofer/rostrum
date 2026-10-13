import Foundation
import Rostrum
import RostrumLayout

enum TableHorizontalSpansRecipe {
    static func append(to draft: LibraryLabDraft) throws -> LibraryLabDraft {
        var result = draft
        let input = try PlatformLabRecipes.require(draft.extraFiles["table-layout-template.potx"], "Span template missing")
        let deck = try Presentation.fromTemplate(data: input)
        _ = deck.registerEmbeddedFonts()
        var rows = [["Grouped evidence", "", "State"]]
        var merges = [TableMergeRegion(row: 0, column: 0, rowSpan: 1, columnSpan: 2)]
        for row in 1...17 {
            if row % 4 == 0 {
                rows.append(["Record \(row): this observation spans two columns and keeps every original word.", "", "Reviewed"])
                merges.append(.init(row: row, column: 0, rowSpan: 1, columnSpan: 2))
            } else { rows.append(["Record \(row)", "Exact source evidence remains editable and wraps at full size.", "Ready"]) }
        }
        let caption = "Horizontal spans only; row spans unsupported. PowerPoint visual acceptance pending."
        let content = TemplateTableContent(rows: rows, columnSizing: .measured(), merges: merges)
        let engine = TemplateLayoutEngine(presentation: deck)
        let plan = try engine.planTablePages(title: "Grouped headers stay editable", table: content, caption: caption)
        let pages = try engine.composeTablePages(plan)
        for slide in pages { try slide.setNotes("Original source notes; horizontal merges move with their rows.") }
        let first = draft.deck.slides.count
        let previews = try pages.indices.map { try deck.renderSVG(slideAt: $0) }
        try draft.deck.slides.importAll(from: deck)
        result.extraFiles["horizontal-spans-output.pptx"] = try deck.serializedData()
        result.checks.append(.init("Horizontal spans paginate within the search budget", pages.count > 1
            && plan.pages.flatMap { Array($0.bodyRows) } == Array(1..<rows.count)
            && plan.pages.allSatisfy { page in
                guard let search = page.slide.tableLayout?.columnSearch else { return false }
                return search.evaluatedCandidates <= 24 && search.additionalCellMeasurements <= 32_768
            }, "Merged headers repeat; body spans remain attached to their complete source row at full text size."))
        let original = draft.verify
        result.verify = { reopened in
            var checks = try original(reopened)
            _ = reopened.registerEmbeddedFonts()
            var saved: [[String]] = [], topology = true, fit = true, sameSVG = true
            for (index, page) in plan.pages.enumerated() {
                let slide = try reopened.slides[first + index]
                let frame = try PlatformLabRecipes.require(slide.shapes.all.compactMap { $0 as? TableFrame }.first, "Saved span table missing")
                let table = try PlatformLabRecipes.require(frame.table, "Saved span cells missing")
                let accepted = try PlatformLabRecipes.require(page.slide.tableLayout, "Saved span plan missing")
                let sourceRows = [0] + Array(page.bodyRows)
                let expected = sourceRows.enumerated().flatMap { localRow, sourceRow in
                    merges.filter { $0.row == sourceRow }.map {
                        TableMergeRegion(row: localRow, column: $0.column, rowSpan: 1, columnSpan: $0.columnSpan)
                    }
                }
                let actual = try TableLayoutEngine(presentation: reopened).plan(table, minimumRowHeight: .points(30),
                    maximumHeight: page.slide.objectFrame?.height)
                let actualMerges = try table.mergedRegions
                topology = topology && actualMerges == expected
                fit = fit && actual.fits && actual.columnWidths == accepted.columnWidths
                    && zip(actual.rowHeights, accepted.rowHeights).allSatisfy { $0 <= $1 }
                    && frame.frame.maxY + .points(8) <= (page.slide.captionFrame?.y ?? .zero)
                    && slide.shapes.all.contains { $0.textFrame?.text == caption }
                    && slide.notesText == "Original source notes; horizontal merges move with their rows."
                for row in 0..<table.rowCount {
                    let values = try (0..<table.columnCount).map { try table.cell(row, $0).text }
                    if row == 0 { topology = topology && values == rows[0] } else { saved.append(values) }
                }
                let svg = try reopened.renderSVG(slideAt: first + index)
                sameSVG = sameSVG && svg == previews[index]
            }
            checks += [
                .init("Saved horizontal merges retain topology and every source word", topology && saved == Array(rows.dropFirst()),
                    "Reopened gridSpan/hMerge regions match each source row; covered cells stay empty and grouped headers repeat."),
                .init("Saved spanning cells fit the written grid", fit,
                    "Independent native-cell measurement accepts combined widths and written heights; captions and notes remain intact."),
                .init("Saved merged-table previews remain identical", sameSVG,
                    "Import, export and reopen reproduce every SVG through the inspector path. Native PowerPoint acceptance is separate.")
            ]
            return checks
        }
        return result
    }
}
