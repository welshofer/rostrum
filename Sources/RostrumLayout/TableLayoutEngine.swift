import Foundation
import Rostrum

public enum TableLayoutIssue: String, Sendable {
    case mergedCell, verticalText, rotatedText, multipleTextColumns, dynamicField, lineSpacingReduction
    case horizontalOverflow, lineLimit, invalidInsets, heightLimit
}

public struct TableCellLayout: Sendable {
    public let row: Int
    public let column: Int
    /// Full height required by this visible cell, across all rowSpan rows.
    /// Merge continuations contribute zero.
    public let requiredHeight: EMU
    public let issues: [TableLayoutIssue]
    public let diagnostics: [ShapingDiagnostic]
    /// Rows measured together at a merge's anchor, otherwise one.
    public var rowSpan: Int { Int(rows) }
    /// Columns measured together at a merge's anchor, otherwise one.
    public var columnSpan: Int { Int(max(1, span)) }
    /// Covered cells contribute no height, issues or diagnostics.
    /// Their source XML remains untouched by planning.
    public var isMergeContinuation: Bool { span == 0 }
    // OOXML rowSpan/gridSpan are positive xsd:int values. Keep both in the
    // original metadata word so ordinary cell arrays/caches do not grow.
    // Zero columns marks a continuation. The planner validates the range.
    private let rows: Int32
    private let span: Int32

    init(row: Int, column: Int, requiredHeight: EMU, issues: [TableLayoutIssue], diagnostics: [ShapingDiagnostic],
         columnSpan: Int = 1, rowSpan: Int = 1, isMergeContinuation: Bool = false) {
        self.row = row; self.column = column; self.requiredHeight = requiredHeight
        self.issues = issues; self.diagnostics = diagnostics
        rows = Int32(rowSpan)
        span = isMergeContinuation ? 0 : Int32(columnSpan)
    }
}

/// A read-only measurement of native cells with horizontal text, including row
/// and column spans. Cells remain in physical row-major order. Apply
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
    struct Key: Hashable { let column: Int; let width: EMU; var spanWidths: [EMU] = [] }
    struct Column {
        let cells: [TableCellLayout]; let occupiedWidth: EMU
        var spanningOccupiedWidths: [Int: EMU] = [:]
    }
    var source: TableLayoutSource
    private(set) var columns: [Key: Column] = [:]
    var occupiedWidths: [EMU] = []
    var measuredCells = 0, reusedCells = 0
    private var remainingCells = 32_768
    private let spans: [Int: [Int]]
    var hasSpans: Bool { !spans.isEmpty }
    let preparation = TableCellPreparation()
    init(table: Table, theme: Theme) throws {
        source = try TableLayoutSource(table: table, theme: theme)
        var spans: [Int: Set<Int>] = [:]
        for region in source.merges where region.columnSpan > 1 {
            spans[region.column, default: []].insert(region.columnSpan)
        }
        self.spans = spans.mapValues { $0.sorted() }
    }
    func keys(for widths: [EMU]) -> [Key] {
        widths.indices.map { column in
            Key(column: column, width: widths[column], spanWidths: (spans[column] ?? []).map {
                widths[column..<(column + $0)].reduce(.zero, +)
            })
        }
    }
    func missingCells(for widths: [EMU]) -> Int {
        keys(for: widths).filter { columns[$0] == nil }.count * source.rowCount
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
    /// Ordinary cells and minimumRowHeight establish row minima. Multi-row
    /// anchors then share any height deficit equally across their rows, in
    /// row-major order; indivisible EMUs go to earlier rows. Saved heights are
    /// not minima. This is deterministic fitting, not PowerPoint native autofit.
    public func plan(_ table: Table, columnWidths: [EMU]? = nil,
                     minimumRowHeight: EMU = .zero, maximumHeight: EMU? = nil,
                     theme: Theme? = nil) throws -> TableLayoutPlan {
        try plan(table, columnWidths: columnWidths, minimumRowHeight: minimumRowHeight,
                 maximumHeight: maximumHeight, theme: theme, pagination: false)
    }

    // Pagination keeps native first-row styling and may move body rows between
    // band/edge regions. Additional header rows use the same conservative envelope. Measure each distinct effective style once per cell, reserving
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
              source.merges.allSatisfy({ $0.rowSpan <= Int(Int32.max) && $0.columnSpan <= Int(Int32.max) }),
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
        // The physical grid is already validated. Allocate once instead of
        // repeatedly copying cell metadata as every width trial grows its array.
        cells.reserveCapacity(source.rowCount * widths.count)
        let columnKeys = reuse?.keys(for: widths)
        let cachedColumns = reuse.map { reuse in columnKeys!.map { reuse.columns[$0] } }
        var occupiedWidths = reuse.map { _ in [EMU](repeating: .zero, count: widths.count) } ?? []
        var occupiedSpans = reuse?.hasSpans == true
            ? cachedColumns!.map { $0?.spanningOccupiedWidths ?? [:] } : []
        let hasSpans = !source.merges.isEmpty
        let hasRowSpans = source.merges.contains { $0.rowSpan > 1 }
        for row in 0..<source.rowCount { for column in widths.indices {
            if let cached = cachedColumns?[column] {
                let cell = cached.cells[row]
                if !hasRowSpans || cell.rowSpan == 1 { heights[row] = max(heights[row], cell.requiredHeight) }
                cells.append(cell); occupiedWidths[column] = cached.occupiedWidth
                continue
            }
            let extent = hasSpans ? source.span(row: row, column: column) : (rows: 1, columns: 1)
            let span = extent.columns
            if span == 0 {
                cells.append(TableCellLayout(row: row, column: column, requiredHeight: .zero,
                    issues: [], diagnostics: [], isMergeContinuation: true))
                continue
            }
            let cellWidth = span == 1 ? widths[column] : widths[column..<(column + span)].reduce(.zero, +)
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
                    let key = Key(input: input.key!, width: cellWidth)
                    if let cached = cache[key] { measurement = cached }
                    else {
                        let geometry = RichTextLayout(textBody: input.body, width: cellWidth.points, height: limit.points,
                            fonts: presentation.fonts, theme: theme, inheritedStyles: [input.style], maxLines: 65,
                            insets: margins, verticalAnchor: "t", context: .tableCell, preparation: input.preparation)
                        if geometry.truncated || geometry.lines.count > 64 { issues.append(.lineLimit) }
                        if !geometry.fits { issues.append(.horizontalOverflow) }
                        if margins.left + margins.right >= cellWidth.points { issues.append(.horizontalOverflow) }
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
                if reuse != nil {
                    if span == 1 { occupiedWidths[column] = max(occupiedWidths[column], measurement.occupiedWidth) }
                    else { occupiedSpans[column][span] = max(occupiedSpans[column][span] ?? .zero, measurement.occupiedWidth) }
                }
                for issue in measurement.issues where !cellIssues.contains(issue) { cellIssues.append(issue) }
                for diagnostic in measurement.diagnostics where !diagnostics.contains(diagnostic) { diagnostics.append(diagnostic) }
            }
            if !hasRowSpans || extent.rows == 1 { heights[row] = max(heights[row], cellHeight) }
            cells.append(TableCellLayout(row: row, column: column, requiredHeight: cellHeight,
                issues: cellIssues, diagnostics: diagnostics, columnSpan: span, rowSpan: extent.rows))
        } }
        if hasRowSpans {
            // Recompute after every width trial, including column-cache hits:
            // a span's deficit depends on ordinary cells in other columns too.
            // Only grow rows, so intersecting row ranges retain earlier fits.
            // Disjoint merge rectangles bound total visits by physical cells.
            for cell in cells where cell.rowSpan > 1 {
                let rows = cell.row..<(cell.row + cell.rowSpan)
                var deficit = cell.requiredHeight
                for row in rows { deficit -= min(deficit, heights[row]) }
                guard deficit > .zero else { continue }
                let share = deficit.rawValue / cell.rowSpan, remainder = deficit.rawValue % cell.rowSpan
                for row in rows {
                    heights[row] += EMU(share + (row - cell.row < remainder ? 1 : 0))
                }
            }
        }
        if let reuse, let cachedColumns {
            for column in widths.indices {
                if cachedColumns[column] != nil { reuse.reusedCells += source.rowCount }
                else {
                    reuse.measuredCells += source.rowCount
                    reuse.retain(.init(cells: (0..<source.rowCount).map { cells[$0 * widths.count + column] },
                        occupiedWidth: occupiedWidths[column],
                        spanningOccupiedWidths: occupiedSpans.isEmpty ? [:] : occupiedSpans[column]), at: columnKeys![column])
                }
            }
            // A span constrains the combined width, not each constituent column.
            // Reserve any unmet demand in the column with the greatest ordinary
            // text demand, leaving short columns free to donate within a span.
            // These deterministic hints only seed trials; actual wrapping still
            // decides fit and score. Recompute them even on column-cache hits.
            let ordinaryWidths = occupiedWidths
            for column in occupiedSpans.indices {
                for span in occupiedSpans[column].keys.sorted() {
                    let occupied = occupiedSpans[column][span]!
                    let columns = column..<(column + span)
                    var remaining = occupied
                    for index in columns { remaining -= min(remaining, occupiedWidths[index]) }
                    guard remaining > .zero else { continue }
                    let receiver = columns.max {
                        ordinaryWidths[$0] == ordinaryWidths[$1] ? $0 > $1 : ordinaryWidths[$0] < ordinaryWidths[$1]
                    }!
                    occupiedWidths[receiver] += remaining
                }
            }
            reuse.occupiedWidths = occupiedWidths
        }
        let total = heights.reduce(0.0) { $0 + $1.points }
        let totalHeight = EMU.points(min(total, limit.points))
        return TableLayoutPlan(columnWidths: widths, rowHeights: heights, cells: cells, totalHeight: totalHeight,
            fits: total <= limit.points && cells.allSatisfy { $0.issues.isEmpty }
                && (maximumHeight.map { totalHeight <= $0 } ?? true))
    }
}
