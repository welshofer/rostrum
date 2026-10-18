import Foundation
import Rostrum

/// Read-back acceptance checks for offline regression runs. Text is checked in
/// its original slide's continuation group; notes cannot satisfy visible text.
/// This detects omissions and changed data, not clipping or visual quality.
public struct RenderContentCheck: Sendable, Codable {
    public var issues: [String] = []
    public var checkedSlides = 0
    public var checkedTextFragments = 0
    public var checkedCharts = 0
    public var checkedTables = 0
    public var checkedNotes = 0

    public static func inspect(_ url: URL, expected: DeckIR, notesEnabled: Bool = true) throws -> Self {
        let presentation = try Presentation(contentsOf: url)
        let outline = presentation.outline()
        var result = Self()
        result.issues = outline.warnings.map { "Read-back: \($0)" }
        let originals = Set(expected.slides.map(\.id))
        let roots = originals.sorted { $0.count == $1.count ? $0 < $1 : $0.count > $1.count }
        var groups: [String: [SlideOutline]] = [:]
        for page in outline.slides {
            let name = try presentation.slides[page.number - 1].part.dom()
                .firstChild(named: "p:cSld")?[attribute: "name"] ?? ""
            guard name.hasPrefix("Lectern:") else { continue }
            let id = String(name.dropFirst("Lectern:".count))
            let root = originals.contains(id) ? id : roots.first {
                id.hasPrefix($0 + "-continued-") || id.hasPrefix($0 + "-source-notes") || id.hasPrefix($0 + "-notes-")
            }
            if let root { groups[root, default: []].append(page) }
        }
        for slide in expected.slides {
            try Task.checkCancellation()
            result.checkedSlides += 1
            guard let pages = groups[slide.id], !pages.isEmpty else {
                result.issues.append("Slide \(slide.id): no rendered slide group."); continue
            }
            var text: [String] = []
            for page in pages {
                text += [page.title, page.subtitle].compactMap { $0 }
                text += page.body.flatMap { $0.paragraphs.map(\.text) }
                text += page.tables.flatMap { $0.rows.flatMap { $0 } }
                text += page.diagrams.flatMap { $0 }
                for chart in page.charts {
                    if let title = chart.title { text.append(title) }
                    text += chart.grid.flatMap { $0 }
                }
            }
            // A paragraph may span pages with repeated titles between its
            // pieces. Ordered tokens tolerate this without normalizing words.
            let tokens = text.flatMap(words)
            var fragments: [(String, String)] = []
            if let title = slide.title { fragments.append(("title", title)) }
            if let body = slide.body {
                let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(body))
                collect(json, path: "body", into: &fragments)
            }
            for (path, value) in fragments where !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                result.checkedTextFragments += 1
                if !containsInOrder(words(value), in: tokens) {
                    result.issues.append("Slide \(slide.id): missing or changed text at \(path).")
                }
            }
            if notesEnabled, let notes = slide.notes, !notes.isEmpty {
                result.checkedNotes += 1
                if !pages.contains(where: { containsInOrder(words(notes), in: $0.notes.flatMap(words)) }) {
                    result.issues.append("Slide \(slide.id): missing or changed speaker notes.")
                }
            }
            if let chart = slide.body?.chart {
                result.checkedCharts += 1
                let match = pages.flatMap(\.charts).contains { output in
                    guard output.grid.count == chart.categories.count + 1,
                          output.grid.first?.dropFirst().map({ $0 }) == chart.series.map(\.name) else { return false }
                    return zip(output.grid.dropFirst(), chart.categories.indices).allSatisfy { row, index in
                        row.first == chart.categories[index] && row.count == chart.series.count + 1
                        && zip(row.dropFirst(), chart.series).allSatisfy { cell, series in
                            series.values.indices.contains(index) && Double(cell) == series.values[index]
                        }
                    }
                }
                if !match { result.issues.append("Slide \(slide.id): native chart categories, series or values changed.") }
            }
            if let table = slide.body?.table {
                result.checkedTables += 1
                let width = table.grid.map(\.count).max() ?? 0
                let grid = table.grid.map { row in
                    row.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } + Array(repeating: "", count: width - row.count)
                }
                let tables = pages.flatMap(\.tables)
                let headersMatch = !tables.isEmpty && tables.allSatisfy { Array($0.rows.prefix(table.headerRowCount)) == Array(grid.prefix(table.headerRowCount)) }
                let body = tables.flatMap { $0.rows.dropFirst(table.headerRowCount) }
                if !headersMatch || body != Array(grid.dropFirst(table.headerRowCount)) {
                    result.issues.append("Slide \(slide.id): native table cells changed.")
                }
                // Ordinary tables keep their existing read-back behavior. Rich
                // inputs additionally verify topology and every anchor direction.
                if table.additionalHeaders != nil || table.merges != nil || table.textDirections != nil {
                    if try !tableStructureMatches(table, pages: pages, in: presentation) {
                        result.issues.append("Slide \(slide.id): native table merges or text directions changed.")
                    }
                }
            }
        }
        return result
    }

    private static func tableStructureMatches(_ expected: IRTable, pages: [SlideOutline], in deck: Presentation) throws -> Bool {
        guard expected.structureProblem == nil else { return false }
        let grid = try expected.layoutContent().rows
        var cursor = expected.headerRowCount
        var found = false
        for page in pages {
            for table in try deck.slides[page.number - 1].shapes.all.compactMap({ ($0 as? TableFrame)?.table }) {
                found = true
                let count = table.rowCount - expected.headerRowCount
                guard count > 0, cursor <= grid.count, count <= grid.count - cursor else { return false }
                let local = expected.page(bodyRows: cursor..<(cursor + count), paddedGrid: grid)
                let regions = try table.mergedRegions
                let actualMerges = regions.map { IRTableMerge(row: $0.row, column: $0.column, rowSpan: $0.rowSpan, columnSpan: $0.columnSpan) }
                func ordered(_ values: [IRTableMerge]) -> [IRTableMerge] {
                    values.sorted { $0.row == $1.row ? $0.column < $1.column : $0.row < $1.row }
                }
                guard ordered(actualMerges) == ordered(local.merges ?? []) else { return false }
                let directions = Dictionary(grouping: local.textDirections ?? [], by: \.row)
                for row in local.grid.indices {
                    for column in local.grid[row].indices {
                        if let merge = regions.first(where: { row >= $0.row && row < $0.row + $0.rowSpan && column >= $0.column && column < $0.column + $0.columnSpan }),
                           row != merge.row || column != merge.column { continue }
                        let direction = directions[row]?.first { $0.column == column }?.direction.native ?? .horizontal
                        if try table.cell(row, column).textDirection != direction { return false }
                    }
                }
                cursor += count
            }
        }
        return found && cursor == grid.count
    }

    private static func words(_ value: String) -> [String] {
        value.split(whereSeparator: \.isWhitespace).map(String.init)
    }
    private static func containsInOrder(_ expected: [String], in actual: [String]) -> Bool {
        var index = 0
        for word in actual where index < expected.count {
            if word == expected[index] { index += 1 }
        }
        return index == expected.count
    }
    private static func collect(_ value: Any, path: String, into output: inout [(String, String)]) {
        if let string = value as? String { output.append((path, string)) }
        else if let array = value as? [Any] {
            for (index, item) in array.enumerated() { collect(item, path: "\(path)[\(index)]", into: &output) }
        } else if let object = value as? [String: Any] {
            for key in object.keys.sorted() where key != "kind" && !(path == "body.table" && key == "textDirections") {
                collect(object[key]!, path: "\(path).\(key)", into: &output)
            }
        }
    }
}
