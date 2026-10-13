import Foundation
import Rostrum
import RostrumLayout

// Run from the repository root, linked with Release Rostrum/RostrumLayout.
// Optional output directory retains the two 24-row specimen decks for review.
var results: [[String: Any]] = []
for count in [24, 1000, 100] { for distinct in [false, true] {
    let short = count == 100
    for trial in 0..<5 { for measured in (trial.isMultiple(of: 2) ? [false, true] : [true, false]) {
        let deck = try Presentation()
        deck.theme.minorFont = "DejaVu Sans"
        for face in ["DejaVuSans", "DejaVuSans-Bold"] {
            try deck.fonts.register(contentsOf: URL(fileURLWithPath:
                "Tests/RostrumTests/Fixtures/NativeGlyphPlacement/eligibility/fonts/\(face).ttf"))
        }
        let engine = TemplateLayoutEngine(presentation: deck)
        let layout = deck.layout(type: "obj")!.part.uri.value
        let rows = [["ID", "Description", "Value"]] + (1...count).map { row in
            [distinct ? "R\(row)" : "R", short ? "Ready" :
                "A detailed observation preserves every original word and needs room to wrap naturally.", "1,234"]
        }
        let content = TemplateTableContent(rows: rows, columnSizing: measured ? .measured() : .estimated)
        let start = ProcessInfo.processInfo.systemUptime
        let plan = try engine.planTablePages(title: "Measured columns", table: content,
            caption: "Source: fixed offline benchmark.", layoutURI: layout)
        let elapsed = ProcessInfo.processInfo.systemUptime - start
        precondition(plan.pages.flatMap { Array($0.bodyRows) } == Array(1...count))
        let geometry = plan.pages[0].slide.tableLayout!
        var item: [String: Any] = ["body_rows": count, "distinct_labels": distinct,
            "short_cells": short, "measured": measured, "trial": trial,
            "plan_seconds": elapsed, "pages": plan.pages.count,
            "widths_points": geometry.columnWidths.map(\.points)]
        if let search = geometry.columnSearch {
            item["evaluated_candidates"] = search.evaluatedCandidates
            item["additional_cell_measurements"] = search.additionalCellMeasurements
            item["reused_cell_measurements"] = search.reusedCellMeasurements
            item["budget_exhausted"] = search.budgetExhausted
        }
        let composeStart = ProcessInfo.processInfo.systemUptime
        _ = try engine.composeTablePages(plan)
        item["compose_with_preflight_seconds"] = ProcessInfo.processInfo.systemUptime - composeStart
        if count == 24, distinct, trial == 1, CommandLine.arguments.count > 1 {
            let directory = URL(fileURLWithPath: CommandLine.arguments[1])
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent(measured ? "measured.pptx" : "estimated.pptx")
            try deck.serializedData().write(to: url)
            let reopened = try Presentation(data: Data(contentsOf: url))
            for face in ["DejaVuSans", "DejaVuSans-Bold"] {
                try reopened.fonts.register(contentsOf: URL(fileURLWithPath:
                    "Tests/RostrumTests/Fixtures/NativeGlyphPlacement/eligibility/fonts/\(face).ttf"))
            }
            var retained: [[String]] = []
            for index in plan.pages.indices {
                let frame = try reopened.slides[index + 1].shapes.all.compactMap { $0 as? TableFrame }.first!
                let table = frame.table!
                let saved = try TableLayoutEngine(presentation: reopened).plan(table,
                    minimumRowHeight: .points(30), maximumHeight: plan.pages[index].slide.objectFrame!.height)
                precondition(saved.fits && saved.columnWidths == geometry.columnWidths)
                precondition(zip(saved.rowHeights, plan.pages[index].slide.tableLayout!.rowHeights).allSatisfy { $0 <= $1 })
                let header = try (0..<table.columnCount).map { try table.cell(0, $0).text }
                precondition(header == rows[0])
                for row in 1..<table.rowCount {
                    retained.append(try (0..<table.columnCount).map { try table.cell(row, $0).text })
                }
            }
            precondition(retained == Array(rows.dropFirst()))
        }
        results.append(item)
    } }
} }
print(String(decoding: try JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted, .sortedKeys]), as: UTF8.self))
