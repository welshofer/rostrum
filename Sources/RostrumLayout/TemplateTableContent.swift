import Foundation
import Rostrum

/// Plain editable cells for a template object slot. The first row is a header;
/// native table styles supply its weight and theme references. Columns default
/// to half equal share, half text-length weight; supply weights to choose them.
public struct TemplateTableContent: Sendable {
    public var rows: [[String]]
    public var columnWeights: [Double]?
    public var columnSizing: TableColumnSizing
    public init(rows: [[String]], columnWeights: [Double]? = nil, columnSizing: TableColumnSizing = .estimated) {
        self.rows = rows; self.columnWeights = columnWeights; self.columnSizing = columnSizing
    }

    var measuresColumns: Bool { if case .measured = columnSizing { return true }; return false }

    func widths(for width: EMU) throws -> [EMU] {
        guard let count = rows.first?.count, count > 0, rows.allSatisfy({ $0.count == count }) else {
            throw LayoutError.cannotFit("Table content must be a nonempty rectangular grid.")
        }
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

    func planned(in presentation: Presentation, width: EMU, font: String, size: Double,
                 theme: Theme, pagination: Bool = false, availableHeight: EMU? = nil,
                 fixedColumnWidths: [EMU]? = nil) throws -> TableLayoutPlan {
        guard size.isFinite, (1...4000).contains(size) else { throw LayoutError.cannotFit("Invalid table font size.") }
        let widths = try fixedColumnWidths ?? widths(for: width)
        let prototype = try Table.layoutPrototype(contents: rows, width: width, font: font, size: size, package: presentation.package)
        if fixedColumnWidths == nil, case .measured(let constraints) = columnSizing {
            return try TableColumnOptimizer(presentation: presentation, table: prototype, theme: theme,
                pagination: pagination, availableHeight: availableHeight).plan(initial: widths, constraints: constraints)
        }
        return try TableLayoutEngine(presentation: presentation).plan(prototype, columnWidths: widths,
            minimumRowHeight: .points(30), theme: theme, pagination: pagination)
    }
}
