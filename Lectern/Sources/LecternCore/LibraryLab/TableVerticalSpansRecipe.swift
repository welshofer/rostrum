import Foundation
import Rostrum
import RostrumLayout

enum TableVerticalSpansRecipe {
    static func append(to draft: LibraryLabDraft) throws -> LibraryLabDraft {
        var result = draft
        let input = try PlatformLabRecipes.require(draft.extraFiles["table-layout-template.potx"], "Row-span template missing")
        let deck = try Presentation.fromTemplate(data: input)
        _ = deck.registerEmbeddedFonts()
        let layout = try PlatformLabRecipes.require(deck.layout(type: "blank"), "Blank row-span layout missing")
        let slide = try deck.slides.add(layout: layout)
        let width = deck.bounds.width - .points(100)
        func text(_ value: String, y: Double, height: Double, size: Double) throws {
            let shape = try slide.shapes.addTextBox(Rect(x: .points(50), y: .points(y), width: width, height: .points(height)))
            shape.textFrame?.text = value
            for paragraph in shape.textFrame?.paragraphs ?? [] { for run in paragraph.runs {
                run.fontName = "DejaVu Sans"; run.fontSize = size
            } }
        }
        try text("Merged cells share row height", y: 30, height: 80, size: 32)
        let rows = [["Group", "Evidence", "State"],
            ["Research and validation", "Source facts stay intact.", "Ready"],
            ["", "A second observation remains editable.", "Ready"],
            ["One summary spans two rows and two columns without losing any original words.", "", "Review"],
            ["", "", "Saved"]]
        let merges = [TableMergeRegion(row: 1, column: 0, rowSpan: 2, columnSpan: 1),
            .init(row: 3, column: 0, rowSpan: 2, columnSpan: 2)]
        let frame = Rect(x: .points(50), y: .points(135), width: width, height: .points(200))
        let table = try slide.shapes.addTable(rows: rows.count, columns: 3, frame: frame)
        table.setContents(rows)
        for row in rows.indices { for column in rows[row].indices {
            try table.cell(row, column).setText(rows[row][column], style: .init(font: "DejaVu Sans",
                sizePt: 18, weight: 400, trackingPt: 0, lineHeight: 1, color: row == 0 ? .white : .black))
        } }
        for merge in merges {
            try table.merge(row: merge.row, column: merge.column, rowSpan: merge.rowSpan, columnSpan: merge.columnSpan)
        }
        let first = width * 0.22, second = width * 0.48
        let plan = try TableLayoutEngine(presentation: deck).plan(table,
            columnWidths: [first, second, width - first - second], minimumRowHeight: .points(32),
            maximumHeight: deck.bounds.height - .points(230))
        guard plan.fits else { throw LayoutError.cannotFit("Lab merged table exceeds its slide.") }
        table.columnWidths(plan.columnWidths).rowHeights(plan.rowHeights)
        try text("All source text remains editable. Merged groups stay on this slide.",
            y: deck.bounds.height.points - 65, height: 45, size: 14)
        try slide.setNotes("Vertical and rectangular merges use full-size cell measurement. The separate pagination example keeps connected row groups together. Native PowerPoint visual acceptance remains pending.")
        let page = draft.deck.slides.count, svg = try deck.renderSVG(slideAt: 0)
        try draft.deck.slides.importAll(from: deck)
        result.extraFiles["vertical-spans-output.pptx"] = try deck.serializedData()
        result.checks.append(.init("Merged cells share the complete measured row area", plan.fits
            && frame.y + plan.totalHeight <= deck.bounds.height - .points(95),
            "Full-size native cells fit within the slide with room for a separate caption; no text is shortened."))
        let original = draft.verify
        result.verify = { reopened in
            var checks = try original(reopened)
            _ = reopened.registerEmbeddedFonts()
            let savedSlide = try reopened.slides[page]
            let saved = try PlatformLabRecipes.require(savedSlide.shapes.all.compactMap { ($0 as? TableFrame)?.table }.first,
                "Saved multi-row table missing")
            let measured = try TableLayoutEngine(presentation: reopened).plan(saved, minimumRowHeight: .points(32))
            var retained = true, fit = true
            for row in rows.indices { for column in rows[row].indices {
                let cell = try saved.cell(row, column)
                retained = retained && cell.text == rows[row][column]
                let geometry = measured.cells[row * 3 + column]
                guard !geometry.isMergeContinuation else { continue }
                let body = try PlatformLabRecipes.require(cell.existingTextFrame, "Saved spanning text missing")
                fit = fit && body.fitText(in: Rect(x: .zero, y: .zero,
                    width: measured.columnWidths[column..<(column + geometry.columnSpan)].reduce(.zero, +),
                    height: measured.rowHeights[row..<(row + geometry.rowSpan)].reduce(.zero, +)),
                    fonts: reopened.fonts, theme: savedSlide.master?.theme).fits
            } }
            let topology = try saved.mergedRegions
            checks += [
                .init("Saved multi-row merges retain topology and source text", topology == merges && retained,
                    "Vertical and rectangular merges preserve every original cell and continuation after saving and reopening."),
                .init("Saved multi-row cells fit their combined area", measured.fits && fit
                    && measured.rowHeights == plan.rowHeights && measured.columnWidths == plan.columnWidths,
                    "Independent cell fitting accepts combined widths and row heights without shrinking the font."),
                .init("Saved multi-row table preview remains identical", try reopened.renderSVG(slideAt: page) == svg,
                    "Import and reopen reproduce the SVG. Native PowerPoint slide-view and export acceptance remain pending.")
            ]
            return checks
        }
        return result
    }
}
