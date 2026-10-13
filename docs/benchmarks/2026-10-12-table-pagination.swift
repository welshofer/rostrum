import Foundation
import Rostrum
import RostrumLayout

// Run from the repository root, linked with Release Rostrum/RostrumLayout.
// The prefix-search reference uses the existing single-slide fitting API.
var results: [[String: Any]] = []
for count in [100, 1000] { for distinct in [false, true] {
    for trial in 0..<5 {
        let deck = try Presentation()
        deck.theme.minorFont = "DejaVu Sans"
        for face in ["DejaVuSans", "DejaVuSans-Bold"] {
            try deck.fonts.register(contentsOf: URL(fileURLWithPath:
                "Tests/RostrumTests/Fixtures/NativeGlyphPlacement/eligibility/fonts/\(face).ttf"))
        }
        let engine = TemplateLayoutEngine(presentation: deck)
        let layout = deck.layout(type: "obj")!.part.uri.value
        let header = ["Item", "Evidence", "State"]
        let body = (1...count).map { row in
            [distinct ? "Item \(row)" : "Item", "Measured evidence retained in its original order.", "Reviewed"]
        }
        let table = TemplateTableContent(rows: [header] + body, columnWeights: [1, 3, 1])
        let start = ProcessInfo.processInfo.systemUptime
        let plan = try engine.planTablePages(title: "Table pagination", table: table,
            caption: "Source: fixed offline benchmark.", layoutURI: layout)
        let elapsed = ProcessInfo.processInfo.systemUptime - start
        precondition(plan.pages.flatMap { Array($0.bodyRows) } == Array(1...count))
        var item: [String: Any] = ["body_rows": count, "cells": (count + 1) * 3,
            "distinct_labels": distinct, "trial": trial, "plan_seconds": elapsed, "pages": plan.pages.count]
        if count == 100 {
            let referenceStart = ProcessInfo.processInfo.systemUptime
            let reference = try MeasuredPaginator.pages(body) { rows in
                do {
                    _ = try engine.plan(title: "Table pagination", columns: [], preferredTypes: ["obj"],
                        object: "tbl", objectCaption: "Source: fixed offline benchmark.", minimumObjectHeight: 0,
                        layoutURI: layout, table: TemplateTableContent(rows: [header] + rows, columnWeights: [1, 3, 1]))
                    return true
                } catch { return false }
            }
            item["prefix_reference_seconds"] = ProcessInfo.processInfo.systemUptime - referenceStart
            precondition(reference.map(\.count) == plan.pages.map { $0.bodyRows.count })
            item["same_page_boundaries"] = true
        }
        let composeStart = ProcessInfo.processInfo.systemUptime
        let pages = try engine.composeTablePages(plan)
        item["compose_with_preflight_seconds"] = ProcessInfo.processInfo.systemUptime - composeStart
        precondition(pages.count == plan.pages.count)
        results.append(item)
    }
} }
print(String(decoding: try JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted, .sortedKeys]), as: UTF8.self))
