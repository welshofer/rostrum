import Foundation
import Rostrum
import RostrumLayout

extension IRTable {
    /// Used by both model validation and rendering (replay can bypass the model).
    /// Bounds checks precede arithmetic so hostile coordinates cannot overflow.
    var structureProblem: String? {
        guard !headers.isEmpty, !rows.isEmpty else { return "table requires headers and at least one body row" }
        guard !(additionalHeaders ?? []).contains(where: \.isEmpty) else { return "Additional header rows cannot be empty" }
        let grid = grid, width = grid.map(\.count).max() ?? 0
        let headerCount = headerRowCount
        struct Cell: Hashable { let row: Int; let column: Int }
        var occupied = Set<Cell>(), covered = Set<Cell>()
        for merge in merges ?? [] {
            guard merge.row >= 0, merge.row < grid.count, merge.column >= 0, merge.column < width,
                  merge.rowSpan > 0, merge.rowSpan <= grid.count - merge.row,
                  merge.columnSpan > 0, merge.columnSpan <= width - merge.column,
                  merge.rowSpan > 1 || merge.columnSpan > 1 else { return "Table merges must be rectangles inside the complete grid" }
            if merge.row < headerCount && merge.rowSpan > headerCount - merge.row {
                return "Table merges cannot cross the header/body boundary"
            }
            for row in merge.row..<(merge.row + merge.rowSpan) {
                for column in merge.column..<(merge.column + merge.columnSpan) {
                    let cell = Cell(row: row, column: column)
                    guard occupied.insert(cell).inserted else { return "Table merges cannot overlap" }
                    if row != merge.row || column != merge.column {
                        covered.insert(cell)
                        if grid[row].indices.contains(column), !grid[row][column].isEmpty {
                            return "Covered table cells must be empty; merging cannot discard words"
                        }
                    }
                }
            }
        }
        var directions = Set<Cell>()
        for cell in textDirections ?? [] {
            let position = Cell(row: cell.row, column: cell.column)
            guard cell.row >= 0, cell.row < grid.count, cell.column >= 0, cell.column < width,
                  directions.insert(position).inserted else { return "Text directions require unique coordinates inside the complete grid" }
            guard !covered.contains(position) else { return "Set text direction on a merge anchor, not a covered cell" }
        }
        return nil
    }

    func layoutContent() throws -> TemplateTableContent {
        if let problem = structureProblem { throw LayoutError.cannotFit(problem) }
        let grid = grid, width = grid.map(\.count).max() ?? 0
        return TemplateTableContent(rows: grid.map { $0 + Array(repeating: "", count: width - $0.count) },
            columnSizing: .measured(), merges: (merges ?? []).map {
                TableMergeRegion(row: $0.row, column: $0.column, rowSpan: $0.rowSpan, columnSpan: $0.columnSpan)
            }, headerRowCount: headerRowCount, textDirections: (textDirections ?? []).map {
                TableCellTextDirection(row: $0.row, column: $0.column, direction: $0.direction.native)
            })
    }

    /// Remap source anchors into a continuation's local grid. The library plan
    /// guarantees that every connected merge group belongs wholly to one page.
    func page(bodyRows: Range<Int>, paddedGrid: [[String]]) -> IRTable {
        let headerCount = headerRowCount
        func local(_ row: Int) -> Int? {
            row < headerCount ? row : (bodyRows.contains(row) ? headerCount + row - bodyRows.lowerBound : nil)
        }
        return IRTable(headers: paddedGrid[0], rows: bodyRows.map { paddedGrid[$0] },
            additionalHeaders: additionalHeaders.map { _ in Array(paddedGrid[1..<headerCount]) },
            merges: merges.map { $0.compactMap { merge in
                local(merge.row).map { IRTableMerge(row: $0, column: merge.column, rowSpan: merge.rowSpan, columnSpan: merge.columnSpan) }
            } }, textDirections: textDirections.map { $0.compactMap { cell in
                local(cell.row).map { IRTableTextDirection(row: $0, column: cell.column, direction: cell.direction) }
            } })
    }
}

extension IRTableTextDirection.Direction {
    var native: TableTextDirection {
        switch self {
        case .horizontal: .horizontal
        case .vertical: .vertical
        case .vertical270: .vertical270
        }
    }
}
