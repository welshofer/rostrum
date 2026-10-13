import Foundation
import Rostrum
import RostrumLayout

enum TableColumnsRecipe {
    static func append(to draft: LibraryLabDraft) throws -> LibraryLabDraft {
        var result = draft
        let input = try PlatformLabRecipes.require(draft.extraFiles["table-layout-template.potx"], "Column sizing template missing")
        let rows = [["ID", "Description", "Value"]] + (1...24).map {
            ["R\($0)", "A detailed observation preserves every original word and needs room to wrap naturally.", "1,234"]
        }
        let title = "Columns follow measured text"
        let caption = "Bounded width search; full-size native cells. Plain tables only. PowerPoint visual acceptance pending."
        let control = try Presentation.fromTemplate(data: input)
        _ = control.registerEmbeddedFonts()
        let controlEngine = TemplateLayoutEngine(presentation: control)
        let baseline = try controlEngine.planTablePages(title: title, table: .init(rows: rows), caption: caption)
        _ = try controlEngine.composeTablePages(baseline)

        let deck = try Presentation.fromTemplate(data: input)
        _ = deck.registerEmbeddedFonts()
        let engine = TemplateLayoutEngine(presentation: deck)
        let content = TemplateTableContent(rows: rows, columnSizing: .measured(constraints: [
            .init(minimum: .points(40), maximum: .points(120)), .init(minimum: .points(200)),
            .init(minimum: .points(55), maximum: .points(140), preferred: .points(75))
        ]))
        let plan = try engine.planTablePages(title: title, table: content, caption: caption)
        let pages = try engine.composeTablePages(plan)
        let geometry = try PlatformLabRecipes.require(plan.pages.first?.slide.tableLayout, "Measured column geometry missing")
        let search = try PlatformLabRecipes.require(geometry.columnSearch, "Column search summary missing")
        let first = draft.deck.slides.count
        let previews = try pages.indices.map { try deck.renderSVG(slideAt: $0) }
        try draft.deck.slides.importAll(from: deck)
        result.extraFiles["column-sizing-baseline.pptx"] = try control.serializedData()
        result.extraFiles["measured-columns-output.pptx"] = try deck.serializedData()
        result.checks.append(.init("Measured columns honor bounds with no extra pages", pages.count <= baseline.pages.count
            && geometry.columnWidths[0] >= .points(40) && geometry.columnWidths[0] <= .points(120)
            && geometry.columnWidths[1] >= .points(200)
            && geometry.columnWidths[2] >= .points(55) && geometry.columnWidths[2] <= .points(140)
            && search.evaluatedCandidates <= 24 && search.additionalCellMeasurements <= 32_768,
            "Estimated: \(baseline.pages.count) pages; measured: \(pages.count). The default heuristic remains available and both decks are retained."))
        let original = draft.verify
        result.verify = { reopened in
            var checks = try original(reopened)
            _ = reopened.registerEmbeddedFonts()
            var retained: [[String]] = [], fits = true, sameSVG = true, headers = true
            for (index, page) in plan.pages.enumerated() {
                let slide = try reopened.slides[first + index]
                let frames = slide.shapes.all.compactMap { $0 as? TableFrame }
                let frame = try PlatformLabRecipes.require(frames.first, "Saved measured table missing")
                let table = try PlatformLabRecipes.require(frame.table, "Saved cells missing")
                let accepted = try PlatformLabRecipes.require(page.slide.tableLayout, "Saved column plan missing")
                let actual = try TableLayoutEngine(presentation: reopened).plan(table, minimumRowHeight: .points(30),
                    maximumHeight: page.slide.objectFrame?.height)
                fits = fits && actual.fits && actual.columnWidths == geometry.columnWidths
                    && zip(actual.rowHeights, accepted.rowHeights).allSatisfy { $0 <= $1 }
                    && frame.frame.maxY + .points(8) <= (page.slide.captionFrame?.y ?? .zero)
                    && slide.shapes.all.contains { $0.textFrame?.text == caption }
                for row in 0..<table.rowCount {
                    let values = try (0..<table.columnCount).map { try table.cell(row, $0).text }
                    if row == 0 { headers = headers && values == rows[0] } else { retained.append(values) }
                }
                let svg = try reopened.renderSVG(slideAt: first + index)
                sameSVG = sameSVG && svg == previews[index]
            }
            checks += [
                .init("Saved measured columns retain every cell and header", headers && retained == Array(rows.dropFirst()),
                    "Width search preserves the complete ordered source grid, including numeric strings."),
                .init("Saved measured columns reproduce fit and previews", fits && sameSVG,
                    "Independent saved-cell measurements fit the written grid, captions keep their gap, and every exported slide SVG is identical.")
            ]
            return checks
        }
        return result
    }
}
