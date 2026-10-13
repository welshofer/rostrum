import Foundation
import Rostrum

public enum TableLayoutIssue: String, Sendable {
    case mergedCell, verticalText, rotatedText, multipleTextColumns, dynamicField, lineSpacingReduction
    case horizontalOverflow, lineLimit, invalidInsets, heightLimit
}

public struct TableCellLayout: Sendable {
    public let row: Int
    public let column: Int
    public let requiredHeight: EMU
    public let issues: [TableLayoutIssue]
    public let diagnostics: [ShapingDiagnostic]
}

/// A read-only measurement of unmerged, horizontal native table cells. Apply
/// columnWidths and rowHeights only after checking fits. No font shrinking or
/// pagination is implied; diagnostics retain font substitution information.
public struct TableLayoutPlan: Sendable {
    public let columnWidths: [EMU]
    public let rowHeights: [EMU]
    public let cells: [TableCellLayout]
    public let totalHeight: EMU
    public let fits: Bool
    /// Present only when measured column sizing was requested.
    public internal(set) var columnSearch: TableColumnSearchSummary? = nil
}

/// Operation-local reuse for column trials on one immutable prospective table.
/// No entry survives changes to content, styles, themes or registered fonts.
final class TableColumnMeasurements {
    struct Key: Hashable { let column: Int; let width: EMU }
    struct Column { let cells: [TableCellLayout]; let occupiedWidth: EMU }
    var source: TableLayoutSource
    private(set) var columns: [Key: Column] = [:]
    var occupiedWidths: [EMU] = []
    var measuredCells = 0, reusedCells = 0
    private var remainingCells = 32_768
    let preparation = TableCellPreparation()
    init(table: Table, theme: Theme) throws { source = try TableLayoutSource(table: table, theme: theme) }
    func missingCells(for widths: [EMU]) -> Int {
        widths.indices.filter { columns[Key(column: $0, width: widths[$0])] == nil }.count * source.rowCount
    }
    func retain(_ column: Column, at key: Key) {
        guard columns.count < 128, column.cells.count <= remainingCells else { return }
        columns[key] = column; remainingCells -= column.cells.count
    }
}

public final class TableLayoutEngine {
    public let presentation: Presentation
    public init(presentation: Presentation) { self.presentation = presentation }

    /// Uses registered fonts and the table's owning theme (or an explicit theme).
    /// Fixed column widths are caller supplied; nil retains the saved grid.
    /// Invalid grids/dimensions throw. Unsupported cells produce a non-fitting
    /// plan with cell coordinates and issues, without changing the document.
    public func plan(_ table: Table, columnWidths: [EMU]? = nil,
                     minimumRowHeight: EMU = .zero, maximumHeight: EMU? = nil,
                     theme: Theme? = nil) throws -> TableLayoutPlan {
        try plan(table, columnWidths: columnWidths, minimumRowHeight: minimumRowHeight,
                 maximumHeight: maximumHeight, theme: theme, pagination: false)
    }

    // Pagination repeats row zero and may move body rows between band/edge
    // regions. Measure each distinct effective style once per cell, reserving
    // the largest height. This bounded envelope keeps partitioning linear.
    func plan(_ table: Table, columnWidths: [EMU]?, minimumRowHeight: EMU,
              maximumHeight: EMU? = nil, theme: Theme?, pagination: Bool,
              reuse: TableColumnMeasurements? = nil) throws -> TableLayoutPlan {
        let theme = theme ?? table.layoutTheme(fallback: presentation.theme)
        var source = try reuse?.source ?? TableLayoutSource(table: table, theme: theme)
        defer { reuse?.source = source }
        let widths = columnWidths ?? source.columnWidths
        let limit = EMU.points(1_000_000)
        guard !widths.isEmpty, source.rowCount > 0, widths.count == source.columnWidths.count,
              widths.allSatisfy({ $0 > .zero && $0 <= limit }),
              widths.reduce(0.0, { $0 + $1.points }) <= limit.points,
              minimumRowHeight >= .zero, minimumRowHeight <= limit,
              maximumHeight.map({ $0 >= .zero && $0 <= limit }) ?? true else {
            throw LayoutError.cannotFit("Table dimensions must be positive, bounded and match its grid.")
        }
        struct Key: Hashable {
            let input: TableCellInput.Key
            let width: EMU
        }
        struct Measurement { let height: EMU; let occupiedWidth: EMU; let issues: [TableLayoutIssue]; let diagnostics: [ShapingDiagnostic] }
        // Exact bytes avoid Swift String's canonical-equivalence aliasing. This
        // cache belongs to one operation: edits and newly registered fonts are live.
        var cache: [Key: Measurement] = [:], remainingBytes = 262_144
        var heights = [EMU](repeating: minimumRowHeight, count: source.rowCount)
        var cells: [TableCellLayout] = []
        let cachedColumns = reuse.map { reuse in widths.indices.map { reuse.columns[.init(column: $0, width: widths[$0])] } }
        var occupiedWidths = reuse.map { _ in [EMU](repeating: .zero, count: widths.count) } ?? []
        for row in 0..<source.rowCount { for column in widths.indices {
            if let cached = cachedColumns?[column] {
                let cell = cached.cells[row]
                heights[row] = max(heights[row], cell.requiredHeight)
                cells.append(cell); occupiedWidths[column] = cached.occupiedWidth
                continue
            }
            let inputs = reuse?.preparation.inputs(source: &source, row: row, column: column, pagination: pagination,
                prepareText: (reuse?.measuredCells ?? 0) > 0)
                ?? TableCellInput.resolve(source: &source, row: row, column: column, pagination: pagination)
            var cellHeight = EMU.zero
            var cellIssues: [TableLayoutIssue] = [], diagnostics: [ShapingDiagnostic] = []
            for input in inputs {
                let margins = input.insets
                var issues = input.issues
                let measurement: Measurement
                if !issues.isEmpty { measurement = Measurement(height: .zero, occupiedWidth: .zero, issues: issues, diagnostics: []) }
                else {
                    let key = Key(input: input.key!, width: widths[column])
                    if let cached = cache[key] { measurement = cached }
                    else {
                        let geometry = RichTextLayout(textBody: input.body, width: widths[column].points, height: limit.points,
                            fonts: presentation.fonts, theme: theme, inheritedStyles: [input.style], maxLines: 65,
                            insets: margins, verticalAnchor: "t", context: .tableCell, preparation: input.preparation)
                        if geometry.truncated || geometry.lines.count > 64 { issues.append(.lineLimit) }
                        if !geometry.fits { issues.append(.horizontalOverflow) }
                        if margins.left + margins.right >= widths[column].points { issues.append(.horizontalOverflow) }
                        let required = geometry.contentHeight + margins.top + margins.bottom
                        if !required.isFinite || required > limit.points { issues.append(.heightLimit) }
                        // Round upwards at EMU precision so serialization cannot make
                        // a measured cell shorter than the accepted line geometry.
                        measurement = Measurement(height: .points(ceil(required * Double(EMU.perPoint)) / Double(EMU.perPoint)),
                            occupiedWidth: reuse == nil ? .zero : .points(ceil((geometry.lines.map(\.width).max() ?? 0)
                                + margins.left + margins.right)),
                            issues: issues, diagnostics: geometry.diagnostics)
                        let cost = key.input.body.count + key.input.style.count + 256
                        if cache.count < 64 && cost <= remainingBytes {
                            cache[key] = measurement; remainingBytes -= cost
                        }
                    }
                }
                cellHeight = max(cellHeight, measurement.height)
                if reuse != nil { occupiedWidths[column] = max(occupiedWidths[column], measurement.occupiedWidth) }
                for issue in measurement.issues where !cellIssues.contains(issue) { cellIssues.append(issue) }
                for diagnostic in measurement.diagnostics where !diagnostics.contains(diagnostic) { diagnostics.append(diagnostic) }
            }
            heights[row] = max(heights[row], cellHeight)
            cells.append(TableCellLayout(row: row, column: column, requiredHeight: cellHeight,
                issues: cellIssues, diagnostics: diagnostics))
        } }
        if let reuse, let cachedColumns {
            reuse.occupiedWidths = occupiedWidths
            for column in widths.indices {
                if cachedColumns[column] != nil { reuse.reusedCells += source.rowCount }
                else {
                    reuse.measuredCells += source.rowCount
                    reuse.retain(.init(cells: (0..<source.rowCount).map { cells[$0 * widths.count + column] },
                        occupiedWidth: occupiedWidths[column]), at: .init(column: column, width: widths[column]))
                }
            }
        }
        let total = heights.reduce(0.0) { $0 + $1.points }
        let totalHeight = EMU.points(min(total, limit.points))
        return TableLayoutPlan(columnWidths: widths, rowHeights: heights, cells: cells, totalHeight: totalHeight,
            fits: total <= limit.points && cells.allSatisfy { $0.issues.isEmpty }
                && (maximumHeight.map { totalHeight <= $0 } ?? true))
    }
}
