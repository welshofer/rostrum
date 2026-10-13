import Foundation
import Rostrum

/// Plain editable cells for a template object slot. The first row is a header;
/// native table styles supply its weight and theme references. Columns default
/// to half equal share, half text-length weight; supply weights to choose them.
public struct TemplateTableContent: Sendable {
    public var rows: [[String]]
    public var columnWeights: [Double]?
    public var columnSizing: TableColumnSizing
    /// Horizontal merges in source-grid coordinates (rowSpan == 1 and
    /// columnSpan >= 2). Covered cells must be empty; no words are discarded.
    /// Header merges repeat on every page; body merges move with their row.
    public var merges: [TableMergeRegion]
    public init(rows: [[String]], columnWeights: [Double]? = nil, columnSizing: TableColumnSizing = .estimated,
                merges: [TableMergeRegion] = []) {
        self.rows = rows; self.columnWeights = columnWeights; self.columnSizing = columnSizing
        self.merges = merges
    }

    var measuresColumns: Bool { if case .measured = columnSizing { return true }; return false }

    func widths(for width: EMU) throws -> [EMU] {
        let count = try validate()
        let weights: [Double]
        if let columnWeights {
            guard columnWeights.count == count, columnWeights.allSatisfy({ $0.isFinite && $0 > 0 }),
                  columnWeights.reduce(0, +).isFinite else {
                throw LayoutError.cannotFit("Table column weights must be finite, positive and match the grid.")
            }
            weights = columnWeights
        } else {
            let lengths = (0..<count).map { column in
                sqrt(Double(max(4, min(160, rows.map { $0[column].count }.max() ?? 4))))
            }
            let total = lengths.reduce(0, +)
            weights = lengths.map { 0.5 / Double(count) + 0.5 * $0 / total }
        }
        let total = weights.reduce(0, +)
        // Cumulative boundaries preserve the exact requested width after rounding.
        var offset = EMU.zero, cumulative = 0.0
        return weights.enumerated().map { index, weight in
            cumulative += weight
            let end = index == count - 1 ? width : width * (cumulative / total)
            defer { offset = end }
            return end - offset
        }
    }

    private func validate() throws -> Int {
        guard let count = rows.first?.count, count > 0, rows.allSatisfy({ $0.count == count }) else {
            throw LayoutError.cannotFit("Table content must be a nonempty rectangular grid.")
        }
        try validateMerges(columnCount: count)
        return count
    }

    private func validateMerges(columnCount: Int) throws {
        var previousRow = -1, previousEnd = 0
        for merge in merges.sorted(by: { $0.row == $1.row ? $0.column < $1.column : $0.row < $1.row }) {
            guard merge.row >= 0, merge.row < rows.count, merge.column >= 0, merge.column < columnCount,
                  merge.rowSpan == 1, merge.columnSpan >= 2, merge.columnSpan <= columnCount - merge.column,
                  merge.row != previousRow || merge.column >= previousEnd else {
                throw LayoutError.cannotFit("Table merges must be nonoverlapping horizontal spans inside the grid.")
            }
            let end = merge.column + merge.columnSpan
            guard rows[merge.row][(merge.column + 1)..<end].allSatisfy(\.isEmpty) else {
                throw LayoutError.cannotFit("Covered table cells must be empty; merging cannot discard source text.")
            }
            previousRow = merge.row; previousEnd = end
        }
    }

    func planned(in presentation: Presentation, width: EMU, font: String, size: Double,
                 theme: Theme, pagination: Bool = false, availableHeight: EMU? = nil,
                 fixedColumnWidths: [EMU]? = nil) throws -> TableLayoutPlan {
        guard size.isFinite, (1...4000).contains(size) else { throw LayoutError.cannotFit("Invalid table font size.") }
        // Validate content even when fresh composition uses the accepted widths.
        let widths: [EMU]
        if let fixedColumnWidths { _ = try validate(); widths = fixedColumnWidths }
        else { widths = try self.widths(for: width) }
        let prototype = try Table.layoutPrototype(contents: rows, width: width, font: font, size: size, package: presentation.package)
        try prototype.merge(merges)
        if fixedColumnWidths == nil, case .measured(let constraints) = columnSizing {
            return try TableColumnOptimizer(presentation: presentation, table: prototype, theme: theme,
                pagination: pagination, availableHeight: availableHeight).plan(initial: widths, constraints: constraints)
        }
        return try TableLayoutEngine(presentation: presentation).plan(prototype, columnWidths: widths,
            minimumRowHeight: .points(30), theme: theme, pagination: pagination)
    }
}
