import Foundation
import Rostrum
import RostrumLayout
#if canImport(Glibc)
import Glibc
#else
import Darwin
#endif

// Arguments: rows, distinct|repeated|mixed, measured|estimated,
// iterations, plan|compose|profile|artifacts, optional artifact directory.
// profile toggles an external sampler with SIGUSR2 after runtime initialization.
let count = Int(CommandLine.arguments[1])!
let labels = CommandLine.arguments[2], measured = CommandLine.arguments[3] == "measured"
let iterations = Int(CommandLine.arguments[4])!, mode = CommandLine.arguments[5]
func milliseconds(_ clock: clockid_t) -> Double {
    var value = timespec()
    precondition(clock_gettime(clock, &value) == 0)
    return Double(value.tv_sec) * 1000 + Double(value.tv_nsec) / 1e6
}
let deck = try Presentation()
deck.theme.minorFont = "DejaVu Sans"
for face in ["DejaVuSans", "DejaVuSans-Bold", "DejaVuSans-Oblique"] {
    try deck.fonts.register(contentsOf: URL(fileURLWithPath:
        "Tests/RostrumTests/Fixtures/NativeGlyphPlacement/eligibility/fonts/\(face).ttf"))
}
let engine = TemplateLayoutEngine(presentation: deck)
let layout = deck.layout(type: "obj")!.part.uri.value
let scripts = ["é e\u{301}\t42\nExact words", "Δοκιμή κειμένου", "Проверка текста", "مرحبا بالعالم", "日本語の文章"]
let rows = [["ID", "Description", "Value"]] + (1...count).map { row in
    [labels == "repeated" ? "R" : "R\(row)", labels == "mixed" ? scripts[row % scripts.count] :
        (count == 100 ? "Ready" : "A detailed observation preserves every original word and needs room to wrap naturally."), "1,234"]
}
let content = TemplateTableContent(rows: rows, columnSizing: measured ? .measured() : .estimated)
func plan() throws -> TemplateTablePaginationPlan {
    try engine.planTablePages(title: "Measured columns", table: content,
        caption: "Source: fixed offline benchmark.", layoutURI: layout)
}
var samples: [[String: Any]] = []
if mode == "profile" {
    _ = try plan()
    raise(SIGUSR2)
}
for trial in 0..<iterations {
    let cpu = milliseconds(CLOCK_PROCESS_CPUTIME_ID), start = milliseconds(CLOCK_MONOTONIC)
    let accepted = try plan()
    var sample: [String: Any] = ["trial": trial, "plan_ms": milliseconds(CLOCK_MONOTONIC) - start,
        "plan_cpu_ms": milliseconds(CLOCK_PROCESS_CPUTIME_ID) - cpu, "pages": accepted.pages.count]
    if mode == "compose" || mode == "artifacts" {
        let cpu = milliseconds(CLOCK_PROCESS_CPUTIME_ID), start = milliseconds(CLOCK_MONOTONIC)
        let slides = try engine.composeTablePages(accepted)
        sample["compose_ms"] = milliseconds(CLOCK_MONOTONIC) - start
        sample["compose_cpu_ms"] = milliseconds(CLOCK_PROCESS_CPUTIME_ID) - cpu
        if mode == "artifacts" {
            let directory = URL(fileURLWithPath: CommandLine.arguments[6])
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let geometry = accepted.pages.map { page -> [String: Any] in
                let grid = page.slide.tableLayout!
                return ["body_rows": Array(page.bodyRows), "widths": grid.columnWidths.map(\.rawValue),
                    "heights": grid.rowHeights.map(\.rawValue), "fits": grid.fits,
                    "cells": grid.cells.map { ["row": $0.row, "column": $0.column,
                        "height": $0.requiredHeight.rawValue, "issues": $0.issues.map(\.rawValue),
                        "diagnostics": $0.diagnostics.map { String(describing: $0) }] as [String: Any] }]
            }
            try JSONSerialization.data(withJSONObject: geometry, options: [.sortedKeys])
                .write(to: directory.appendingPathComponent("geometry.json"))
            let saved = try deck.serializedData()
            try saved.write(to: directory.appendingPathComponent("saved.pptx"))
            for index in 0..<deck.slides.count {
                let rendered = try deck.renderSVGReportingProblems(slideAt: index)
                try Data(rendered.svg.utf8).write(to: directory.appendingPathComponent("slide-\(index).svg"))
                try JSONEncoder().encode(rendered.problems.fidelityIssues)
                    .write(to: directory.appendingPathComponent("slide-\(index)-issues.json"))
            }
            let afterRendering = try deck.serializedData()
            precondition(afterRendering == saved)
        }
        // Keep timings independent of previously composed slides.
        for _ in slides { try deck.slides.remove(at: deck.slides.count - 1) }
    }
    samples.append(sample)
}
if mode == "profile" { raise(SIGUSR2) }
print(String(decoding: try JSONSerialization.data(withJSONObject: samples, options: [.sortedKeys]), as: UTF8.self))
