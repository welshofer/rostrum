import Foundation
import Rostrum
import RostrumLayout
#if canImport(Glibc)
import Glibc
#else
import Darwin
#endif

// Arguments: even row count, repeated|distinct, iterations, optional output folder.
// Large grids are measurement workloads, not paginated slide demonstrations.
let count = Int(CommandLine.arguments[1])!, labels = CommandLine.arguments[2]
let iterations = Int(CommandLine.arguments[3])!
precondition(count > 0 && count % 2 == 0)
func milliseconds(_ clock: clockid_t) -> Double {
    var time = timespec()
    precondition(clock_gettime(clock, &time) == 0)
    return Double(time.tv_sec) * 1000 + Double(time.tv_nsec) / 1e6
}
let deck = try Presentation()
deck.theme.minorFont = "DejaVu Sans"
for face in ["DejaVuSans", "DejaVuSans-Bold", "DejaVuSans-Oblique"] {
    try deck.fonts.register(contentsOf: URL(fileURLWithPath:
        "Tests/RostrumTests/Fixtures/NativeGlyphPlacement/eligibility/fonts/\(face).ttf"))
}
var rows: [[String]] = []
for row in 0..<count {
    let anchor = row % 2 == 0
    let rectangular = row / 2 % 2 == 0
    rows.append([anchor ? "\(labels == "repeated" ? "Group" : "Group \(row)") keeps every original word while wrapping at full size." : "",
                 rectangular ? "" : "Evidence \(labels == "repeated" ? "value" : String(row))", "Ready"])
}
let table = try deck.slides[0].shapes.addTable(rows: count, columns: 3,
    frame: Rect(x: .points(50), y: .points(100), width: .points(540), height: .points(200)))
table.setContents(rows)
for row in rows.indices { for column in 0..<3 {
    try table.cell(row, column).setText(rows[row][column], style: .init(font: "DejaVu Sans",
        sizePt: 18, weight: 400, trackingPt: 0, lineHeight: 1, color: .black))
} }
for row in stride(from: 0, to: count, by: 2) {
    try table.merge(row: row, column: 0, rowSpan: 2, columnSpan: row / 2 % 2 == 0 ? 2 : 1)
}
let engine = TableLayoutEngine(presentation: deck)
var samples: [[String: Any]] = []
for trial in 0..<iterations {
    let cpu = milliseconds(CLOCK_PROCESS_CPUTIME_ID), start = milliseconds(CLOCK_MONOTONIC)
    let plan = try engine.plan(table, columnWidths: [.points(160), .points(270), .points(110)], minimumRowHeight: .points(30))
    samples.append(["trial": trial, "plan_ms": milliseconds(CLOCK_MONOTONIC) - start,
        "plan_cpu_ms": milliseconds(CLOCK_PROCESS_CPUTIME_ID) - cpu, "height": plan.totalHeight.rawValue])
    precondition(plan.fits)
    for cell in plan.cells where !cell.isMergeContinuation {
        precondition(plan.rowHeights[cell.row..<(cell.row + cell.rowSpan)].reduce(.zero, +) >= cell.requiredHeight)
    }
    if CommandLine.arguments.count > 4 && trial == 0 {
        let directory = URL(fileURLWithPath: CommandLine.arguments[4])
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let geometry: [String: Any] = ["widths": plan.columnWidths.map(\.rawValue), "heights": plan.rowHeights.map(\.rawValue),
            "cells": plan.cells.map { ["row": $0.row, "column": $0.column, "height": $0.requiredHeight.rawValue,
                "rowSpan": $0.rowSpan, "columnSpan": $0.columnSpan, "covered": $0.isMergeContinuation,
                "issues": $0.issues.map(\.rawValue), "diagnostics": $0.diagnostics.map { String(describing: $0) }] as [String: Any] }]
        try JSONSerialization.data(withJSONObject: geometry, options: [.sortedKeys])
            .write(to: directory.appendingPathComponent("geometry.json"))
        table.columnWidths(plan.columnWidths).rowHeights(plan.rowHeights)
        try deck.save(to: directory.appendingPathComponent("saved.pptx"))
        let rendered = try deck.renderSVGReportingProblems(slideAt: 0)
        try Data(rendered.svg.utf8).write(to: directory.appendingPathComponent("slide.svg"))
        try JSONEncoder().encode(rendered.problems.fidelityIssues).write(to: directory.appendingPathComponent("issues.json"))
    }
}
print(String(decoding: try JSONSerialization.data(withJSONObject: samples, options: [.sortedKeys]), as: UTF8.self))
