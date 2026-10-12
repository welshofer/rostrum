import Foundation
import Rostrum
import RostrumLayout

enum TablePaginationRecipe {
    static func append(to draft: LibraryLabDraft) throws -> LibraryLabDraft {
        var result = draft
        let input = try PlatformLabRecipes.require(draft.extraFiles["table-layout-template.potx"], "Pagination template missing")
        let deck = try Presentation.fromTemplate(data: input)
        _ = deck.registerEmbeddedFonts()
        let rows = [["Record", "Evidence", "State"]] + (1...19).map { row in
            ["Record \(row)", row % 3 == 0 ? "A longer observation wraps into several lines while retaining every original word." : "Exact source evidence \(row)", "Reviewed"]
        }
        let caption = "Repeated native header; full-size cells. Plain rectangular tables only. PowerPoint visual acceptance pending."
        let engine = TemplateLayoutEngine(presentation: deck)
        let plan = try engine.planTablePages(title: "Measured table continuations",
            table: TemplateTableContent(rows: rows, columnWeights: [1, 2.6, 1]), caption: caption)
        let slides = try engine.composeTablePages(plan)
        for slide in slides { try slide.setNotes("Original source notes retained on the continuation group.") }
        let first = draft.deck.slides.count
        let svgs = try slides.indices.map { try deck.renderSVG(slideAt: $0) }
        try draft.deck.slides.importAll(from: deck)
        result.extraFiles["paginated-table-output.pptx"] = try deck.serializedData()
        result.checks.append(.init("Measured pagination covers each source row exactly once", slides.count > 1
            && plan.pages.flatMap { Array($0.bodyRows) } == Array(1..<rows.count),
            "Every page repeats the header and reserves its own caption; row ranges preserve source order."))
        let original = draft.verify
        result.verify = { reopened in
            var checks = try original(reopened)
            _ = reopened.registerEmbeddedFonts()
            var retained: [[String]] = [], headers = true, fits = true, notes = true, previews = true
            for (index, page) in plan.pages.enumerated() {
                let slide = try reopened.slides[first + index]
                let frame = try PlatformLabRecipes.require(slide.shapes.all.compactMap { $0 as? TableFrame }.first, "Saved continuation missing")
                let table = try PlatformLabRecipes.require(frame.table, "Saved continuation table missing")
                let geometry = try PlatformLabRecipes.require(page.slide.tableLayout, "Pagination geometry missing")
                let actual = try TableLayoutEngine(presentation: reopened).plan(table, minimumRowHeight: .points(30),
                    maximumHeight: page.slide.objectFrame?.height)
                fits = fits && actual.fits && zip(actual.rowHeights, geometry.rowHeights).allSatisfy { $0 <= $1 }
                    && actual.columnWidths == geometry.columnWidths
                    && frame.frame.maxY + .points(8) <= (page.slide.captionFrame?.y ?? .zero)
                    && slide.shapes.all.contains { $0.textFrame?.text == caption }
                for row in 0...page.bodyRows.count {
                    let values = try geometry.columnWidths.indices.map { try table.cell(row, $0).text }
                    if row == 0 { headers = headers && values == rows[0] } else { retained.append(values) }
                }
                notes = notes && slide.notesText == "Original source notes retained on the continuation group."
                let svg = try reopened.renderSVG(slideAt: first + index)
                previews = previews && svg == svgs[index]
            }
            checks += [
                .init("Saved continuations preserve rows, headers and notes", headers && notes && retained == Array(rows.dropFirst()),
                    "Reopened native cell values reproduce the exact source sequence; repeated headers and caller-written notes remain intact."),
                .init("Saved continuations fit their reserved table areas", fits,
                    "Each native row fits its measured cell geometry, columns remain aligned and captions clear the table by eight points."),
                .init("Saved continuations retain every preview", previews,
                    "The inspector/export path reproduces every continuation SVG. Native PowerPoint acceptance remains separate.")
            ]
            return checks
        }
        return result
    }
}
