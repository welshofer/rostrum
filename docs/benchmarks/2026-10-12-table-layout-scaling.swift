import Foundation
@testable import Rostrum
import RostrumLayout

var results: [[String: Any]] = []
for rows in [100, 1000] { for unique in [false, true] {
    let deck = try Presentation()
    deck.theme.minorFont = "DejaVu Sans"
    try deck.fonts.register(contentsOf: URL(fileURLWithPath: "Tests/RostrumTests/Fixtures/Typography/DejaVuSans.ttf"))
    let table = try deck.slides[0].shapes.addTable(rows: rows, columns: 10,
        frame: Rect(x: .zero, y: .zero, width: .points(1400), height: .points(30 * Double(rows))))
    table.setContents((0..<rows).map { row in (0..<10).map { column in
        unique ? "Cell \(row)-\(column) ready for review" : "Ready for review"
    } })
    for trial in 0..<5 {
        let start = ProcessInfo.processInfo.systemUptime
        let plan = try TableLayoutEngine(presentation: deck).plan(table)
        let elapsed = ProcessInfo.processInfo.systemUptime - start
        let referenceStart = ProcessInfo.processInfo.systemUptime
        var heights: [Double] = []
        for row in 0..<rows {
            var height = 0.0
            for column in 0..<10 {
                let cell = try table.cell(row, column)
                let style = TableStyleResolver.fittingStyle(for: cell.tc, in: table, theme: deck.theme)!
                let geometry = RichTextLayout(textBody: cell.existingTextFrame!.txBody,
                    width: 140, height: 1_000_000, fonts: deck.fonts, theme: deck.theme,
                    inheritedStyles: [style.text], maxLines: 65,
                    insets: (7.2, 3.6, 7.2, 3.6), verticalAnchor: "t", context: .tableCell)
                height = max(height, geometry.contentHeight + 7.2)
                precondition(geometry.fits)
            }
            heights.append(height)
        }
        let referenceElapsed = ProcessInfo.processInfo.systemUptime - referenceStart
        precondition(plan.fits && zip(plan.rowHeights, heights).allSatisfy { abs($0.points - $1) < 0.0001 })
        results.append(["rows": rows, "cells": rows * 10, "unique": unique, "trial": trial,
            "plan_seconds": elapsed, "independent_cell_seconds": referenceElapsed, "same_geometry": true])
    }
} }
print(String(decoding: try JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted, .sortedKeys]), as: UTF8.self))
