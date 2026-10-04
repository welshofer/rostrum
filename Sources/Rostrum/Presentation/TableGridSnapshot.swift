import Foundation

/// An operation-local view of a table. Never retained across calls: callers can
/// mutate the public XML tree, so a persistent cache would become stale.
struct TableGridSnapshot {
    let columns: [XML.Element]
    let rows: [XML.Element]
    let cells: [[XML.Element]]

    init(_ table: XML.Element) {
        columns = table.firstChild(named: "a:tblGrid")?.children(named: "a:gridCol") ?? []
        rows = table.children(named: "a:tr")
        cells = rows.map { $0.children(named: "a:tc") }
    }

    func cell(_ row: Int, _ column: Int) throws -> XML.Element {
        guard cells.indices.contains(row), cells[row].indices.contains(column) else {
            throw RostrumError.packageInvalid("table cell (\(row), \(column)) is missing")
        }
        return cells[row][column]
    }

    func topology(requireRectangular: Bool = false) throws -> TableMergeTopology {
        try TableMergeTopology(grid: self, requireRectangular: requireRectangular)
    }
}

/// The complete rectangular region of a merged cell, including its origin.
public struct TableMergeRegion: Equatable, Sendable {
    public let row: Int
    public let column: Int
    public let rowSpan: Int
    public let columnSpan: Int

    public init(row: Int, column: Int, rowSpan: Int, columnSpan: Int) {
        self.row = row; self.column = column
        self.rowSpan = rowSpan; self.columnSpan = columnSpan
    }
}

struct TableCellPosition: Hashable { let row: Int; let column: Int }

struct TableMergeTopology {
    let regions: [TableMergeRegion]
    let owners: [TableCellPosition: Int]

    init(grid: TableGridSnapshot, requireRectangular: Bool) throws {
        var regions: [TableMergeRegion] = []
        var owners: [TableCellPosition: Int] = [:]
        func invalid() -> RostrumError { .packageInvalid("invalid or overlapping table merge topology") }
        func span(_ cell: XML.Element, _ name: String) throws -> Int {
            guard let raw = cell[attribute: name] else { return 1 }
            guard let value = Int(raw), value > 0 else { throw invalid() }
            return value
        }
        for (r, cells) in grid.cells.enumerated() {
            if requireRectangular && cells.count != grid.columns.count { throw invalid() }
            for (c, cell) in cells.enumerated() {
                let rs = try span(cell, "rowSpan"), cs = try span(cell, "gridSpan")
                if Self.flag(cell, "hMerge") || Self.flag(cell, "vMerge") { continue }
                guard rs > 1 || cs > 1 else { continue }
                // Subtraction avoids an overflow from hostile span attributes.
                guard c < grid.columns.count, rs <= grid.rows.count - r,
                      cs <= grid.columns.count - c else { throw invalid() }
                let region = TableMergeRegion(row: r, column: c, rowSpan: rs, columnSpan: cs)
                for rr in r..<(r + rs) {
                    guard grid.cells[rr].count >= c + cs else { throw invalid() }
                    for cc in c..<(c + cs) {
                        let position = TableCellPosition(row: rr, column: cc)
                        guard owners[position] == nil else { throw invalid() }
                        owners[position] = regions.count
                    }
                }
                regions.append(region)
            }
        }
        for (r, cells) in grid.cells.enumerated() {
            for (c, cell) in cells.enumerated() {
                let horizontal = Self.flag(cell, "hMerge"), vertical = Self.flag(cell, "vMerge")
                guard let index = owners[TableCellPosition(row: r, column: c)] else {
                    if horizontal || vertical { throw invalid() }
                    continue
                }
                let region = regions[index]
                guard horizontal == (c > region.column), vertical == (r > region.row) else { throw invalid() }
                let rs = try span(cell, "rowSpan"), cs = try span(cell, "gridSpan")
                // Office writes rowSpan on the entire top edge and gridSpan
                // down the left edge. Also accept older Rostrum's origin-only
                // spans; neither representation changes the region geometry.
                if rs > 1 && (r != region.row || rs != region.rowSpan) { throw invalid() }
                if cs > 1 && (c != region.column || cs != region.columnSpan) { throw invalid() }
            }
        }
        self.regions = regions; self.owners = owners
    }

    static func flag(_ cell: XML.Element, _ name: String) -> Bool {
        cell[attribute: name] == "1" || cell[attribute: name] == "true"
    }

    func region(row: Int, column: Int) -> TableMergeRegion? {
        owners[TableCellPosition(row: row, column: column)].map { regions[$0] }
    }

    static func write(_ regions: [TableMergeRegion], cells: [[XML.Element]]) {
        for row in cells { for cell in row {
            for attribute in ["rowSpan", "gridSpan", "hMerge", "vMerge"] { cell[attribute: attribute] = nil }
        } }
        for region in regions {
            for r in region.row..<(region.row + region.rowSpan) {
                for c in region.column..<(region.column + region.columnSpan) {
                    let cell = cells[r][c]
                    if r == region.row && region.rowSpan > 1 { cell[attribute: "rowSpan"] = String(region.rowSpan) }
                    if c == region.column && region.columnSpan > 1 { cell[attribute: "gridSpan"] = String(region.columnSpan) }
                    if c > region.column { cell[attribute: "hMerge"] = "1" }
                    if r > region.row { cell[attribute: "vMerge"] = "1" }
                }
            }
        }
    }
}
