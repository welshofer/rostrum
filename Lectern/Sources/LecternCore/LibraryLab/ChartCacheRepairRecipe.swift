import Foundation
import Rostrum

/// A saved before/after pair for explicit cache materialization. This is never
/// invoked by ordinary inspection or export of the user's documents.
enum ChartCacheRepairRecipe {
    static func make(_ options: LibraryLabOptions) throws -> LibraryLabDraft {
        let deck = try LibraryLabSupport.deck(title: "Missing chart caches")
        let slide = try deck.slides[0]
        try LibraryLabSupport.text("Rebuild missing chart caches", on: slide)
        let count = min(12, max(2, options.sampleSize))
        let categories = (1...count).map { "Item \($0)" }
        let values: [Double?] = (1...count).map { $0 == 2 ? nil : Double($0 * 7) }
        let points = (1...count).map { (x: Double($0), y: Double($0 * 7)) }
        let expectedPoints = points.map { Chart.XYPoint(x: $0.x, y: $0.y) }
        let frame = LibraryLabSupport.frame(0.6, 1.2, 12, 4.8)
        if options.alternative {
            try slide.shapes.addScatterChart(.init(series: [.init(name: options.text, points: points)]), frame: frame)
        } else {
            try slide.shapes.addChart(.barClustered, data: .init(categories: categories,
                series: [.init(name: options.text, values: values)]), frame: frame)
        }
        try LibraryLabSupport.text("Stored workbook values; native PowerPoint review pending.", on: slide,
                                   frame: LibraryLabSupport.frame(0.6, 6.3, 12, 0.6))
        try slide.setNotes("Keep these chart notes.\n" + options.text)
        try deck.setSections([("Chart cache repair", 0)])
        guard let chart = slide.charts.first, let workbook = chart.workbookPart else {
            throw RostrumError.packageInvalid("Recipe chart/workbook missing")
        }
        let workbookBytes = workbook.blob
        var stack = [try chart.part.dom()]
        while let node = stack.popLast() {
            node.children.removeAll {
                if case .element(let child) = $0 { return ["c:strCache", "c:numCache"].contains(child.name) }
                return false
            }
            stack += node.childElements
        }
        chart.part.markDirty()
        let before = try deck.serializedData()
        let preview = try deck.renderSVG(slideAt: 0)
        let report = try chart.rebuildMissingCachesFromWorkbook()
        let after = try deck.serializedData()
        let original = try ZipReader(data: before), repaired = try ZipReader(data: after)
        let changed = try Set(original.entryNames).union(repaired.entryNames).filter {
            try original.data(forEntry: $0) != repaired.data(forEntry: $0)
        }
        let checks: [LibraryLabCheck] = [
            .init("Three absent references repaired", report.count == 3,
                  "Series name and category/value or X/Y caches are materialized explicitly."),
            .init("Only chart XML changed", changed == [String(chart.part.uri.value.dropFirst())],
                  "Workbook, notes, sections, slide, relationships and all unrelated parts retain their bytes."),
            .init("Preview retains workbook values", try deck.renderSVG(slideAt: 0) == preview,
                  "The read-only workbook fallback and rebuilt caches produce identical SVGs."),
            try atomicRefusal(before)
        ]
        let detail = report.map { "\($0.numeric ? "numeric" : "text"): \($0.formula) (\($0.pointCount) points)" }.joined(separator: "\n")
        return LibraryLabDraft(deck: deck, before: before, checks: checks,
            extraFiles: ["rebuilt-caches.txt": Data((detail + "\n").utf8)]) { saved in
                guard let savedChart = saved.charts.first else { throw RostrumError.packageInvalid("Saved chart missing") }
                let contentMatches = options.alternative
                    ? savedChart.xySeries.first?.points == expectedPoints
                    : savedChart.categories == categories && savedChart.series.first?.values == values
                let bytes = try saved.serializedData()
                let repeated = try savedChart.rebuildMissingCachesFromWorkbook()
                return [
                    .init("Stored chart data reopened", contentMatches && savedChart.series.first?.name == options.text,
                          "Exact source values, gaps and series name survive saving."),
                    .init("Workbook bytes retained", savedChart.workbookPart?.blob == workbookBytes,
                          "The embedded workbook is not rewritten."),
                    .init("Notes and section retained", try saved.slides[0].notesText == "Keep these chart notes.\n" + options.text
                          && Array(saved.sections).first?.name == "Chart cache repair",
                          "Repair preserves speaker notes and slide membership."),
                    .init("Repeated repair is a no-op", try repeated.isEmpty && saved.serializedData() == bytes,
                          "Existing caches remain authoritative, including empty ones.")
                ]
            }
    }

    private static func atomicRefusal(_ input: Data) throws -> LibraryLabCheck {
        let deck = try Presentation(data: input)
        guard let chart = deck.charts.first else { throw RostrumError.packageInvalid("Refusal chart missing") }
        var stack = [try chart.part.dom()]
        var changed = false
        while let node = stack.popLast() {
            if node.name == "c:numRef", let formula = node.firstChild(named: "c:f") {
                formula.children = [.text("UnsupportedNamedRange")]; changed = true; break
            }
            stack += node.childElements
        }
        chart.part.markDirty()
        let before = try deck.serializedData()
        var refused = false
        do { try chart.rebuildMissingCachesFromWorkbook() }
        catch Chart.CacheRepairProblem.unsupportedReference { refused = true }
        return .init("Unsupported reference refuses atomically", try changed && refused && deck.serializedData() == before,
                     "A named range leaves the complete saved deck unchanged.")
    }
}
