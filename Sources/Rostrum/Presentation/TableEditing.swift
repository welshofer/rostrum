import Foundation

public extension Table {
    func columnWidth(_ column: Int) throws -> EMU {
        let grid = TableGridSnapshot(tbl)
        guard grid.columns.indices.contains(column) else { throw RostrumError.packageInvalid("table column out of range") }
        return EMU(grid.columns[column].coordinate("w") ?? 0)
    }

    func rowHeight(_ row: Int) throws -> EMU {
        let grid = TableGridSnapshot(tbl)
        guard grid.rows.indices.contains(row) else { throw RostrumError.packageInvalid("table row out of range") }
        return EMU(grid.rows[row].coordinate("h") ?? 0)
    }

    /// All merges in document order. Invalid foreign topology throws without
    /// changing XML. Individual, unmerged cells are not included.
    var mergedRegions: [TableMergeRegion] { get throws { try TableGridSnapshot(tbl).topology().regions } }

    /// The merge containing a physical cell, or nil for an unmerged cell.
    func mergeInfo(row: Int, column: Int) throws -> TableMergeRegion? {
        let grid = TableGridSnapshot(tbl)
        _ = try grid.cell(row, column)
        return try grid.topology().region(row: row, column: column)
    }

    /// Split the merge containing this cell. The origin keeps its content;
    /// text discarded by the original merge cannot be recovered.
    func unmerge(row: Int, column: Int) throws {
        let grid = TableGridSnapshot(tbl)
        _ = try grid.cell(row, column)
        let topology = try grid.topology()
        guard let region = topology.region(row: row, column: column) else { return }
        TableMergeTopology.write(topology.regions.filter { $0 != region }, cells: grid.cells)
        part.markDirty()
    }

    /// Insert a blank row; insertion strictly inside a merge expands that
    /// merge. Inserting at either boundary leaves that merge unchanged.
    func insertRow(at index: Int, height: EMU = .inches(0.3)) throws {
        try editAxis(rows: true, insertion: index, removal: nil, order: nil, dimension: height)
    }

    func insertColumn(at index: Int, width: EMU = .inches(1)) throws {
        try editAxis(rows: false, insertion: index, removal: nil, order: nil, dimension: width)
    }

    /// Remove a row and its content. Intersected merges shrink, and a 1×1
    /// remainder becomes unmerged. The last row cannot be removed.
    func removeRow(at index: Int) throws {
        try editAxis(rows: true, insertion: nil, removal: index, order: nil, dimension: nil)
    }

    func removeColumn(at index: Int) throws {
        try editAxis(rows: false, insertion: nil, removal: index, order: nil, dimension: nil)
    }

    /// Permutation of old row indices in their new order. A merge must remain
    /// contiguous and retain its internal row order; split it first otherwise.
    func reorderRows(_ order: [Int]) throws {
        try editAxis(rows: true, insertion: nil, removal: nil, order: order, dimension: nil)
    }

    func reorderColumns(_ order: [Int]) throws {
        try editAxis(rows: false, insertion: nil, removal: nil, order: order, dimension: nil)
    }

    func moveRow(from source: Int, to destination: Int) throws {
        try reorderRows(moving(source, to: destination, count: rowCount))
    }

    func moveColumn(from source: Int, to destination: Int) throws {
        try reorderColumns(moving(source, to: destination, count: columnCount))
    }

    private func moving(_ source: Int, to destination: Int, count: Int) throws -> [Int] {
        guard (0..<count).contains(source), (0..<count).contains(destination) else {
            throw RostrumError.packageInvalid("table move index out of range")
        }
        var order = Array(0..<count)
        order.insert(order.remove(at: source), at: destination)
        return order
    }

    private func editAxis(rows editingRows: Bool, insertion: Int?, removal: Int?,
                          order: [Int]?, dimension: EMU?) throws {
        let grid = TableGridSnapshot(tbl)
        let topology = try grid.topology(requireRectangular: true)
        guard let gridElement = tbl.firstChild(named: "a:tblGrid"),
              !grid.rows.isEmpty, !grid.columns.isEmpty else {
            throw RostrumError.packageInvalid("structural edits require a nonempty rectangular table")
        }
        let count = editingRows ? grid.rows.count : grid.columns.count
        if let insertion, !(0...count).contains(insertion) {
            throw RostrumError.packageInvalid("table insertion index out of range")
        }
        if let removal, (!(0..<count).contains(removal) || count <= 1) {
            throw RostrumError.packageInvalid("table removal index out of range or removes final dimension")
        }
        if let dimension, dimension.rawValue <= 0 || dimension.rawValue > (1 << 40) {
            throw RostrumError.packageInvalid("table dimension must be positive and bounded")
        }
        var inverse = [Int](repeating: 0, count: count)
        if let order {
            guard order.count == count, Set(order) == Set(0..<count) else {
                throw RostrumError.packageInvalid("table reorder requires a complete permutation")
            }
            for (new, old) in order.enumerated() { inverse[old] = new }
        }
        var regions: [TableMergeRegion] = []
        for region in topology.regions {
            var start = editingRows ? region.row : region.column
            var span = editingRows ? region.rowSpan : region.columnSpan
            if let insertion {
                if insertion <= start { start += 1 }
                else if insertion < start + span { span += 1 }
            }
            if let removal {
                if removal < start { start -= 1 }
                else if removal < start + span { span -= 1 }
            }
            if order != nil {
                let mapped = (start..<(start + span)).map { inverse[$0] }
                guard mapped == Array(mapped[0]..<(mapped[0] + span)) else {
                    throw RostrumError.packageInvalid("table reorder would split or reverse a merged region")
                }
                start = mapped[0]
            }
            guard span > 0 else { continue }
            let replacement = TableMergeRegion(
                row: editingRows ? start : region.row,
                column: editingRows ? region.column : start,
                rowSpan: editingRows ? span : region.rowSpan,
                columnSpan: editingRows ? region.columnSpan : span)
            if replacement.rowSpan > 1 || replacement.columnSpan > 1 { regions.append(replacement) }
        }
        // Everything that can fail is checked above. Preserve the surviving
        // elements themselves, including extensions, comments and rich text.
        var rows = grid.rows, columns = grid.columns, cells = grid.cells
        if editingRows {
            if let insertion {
                let row = XML.Element("a:tr", attributes: [("h", String(dimension!.rawValue))])
                let newCells = columns.map { _ in Table.makeCell() }
                newCells.forEach { row.appendElement($0) }
                rows.insert(row, at: insertion); cells.insert(newCells, at: insertion)
            }
            if let removal { rows.remove(at: removal); cells.remove(at: removal) }
            if let order { rows = order.map { grid.rows[$0] }; cells = order.map { grid.cells[$0] } }
            Self.replaceTableChildren(of: tbl, named: "a:tr", with: rows)
        } else {
            if let insertion {
                columns.insert(XML.Element("a:gridCol", attributes: [("w", String(dimension!.rawValue))]), at: insertion)
                for r in cells.indices { cells[r].insert(Table.makeCell(), at: insertion) }
            }
            if let removal {
                columns.remove(at: removal)
                for r in cells.indices { cells[r].remove(at: removal) }
            }
            if let order {
                columns = order.map { grid.columns[$0] }
                cells = grid.cells.map { row in order.map { row[$0] } }
            }
            Self.replaceTableChildren(of: gridElement, named: "a:gridCol", with: columns)
            for r in rows.indices { Self.replaceTableChildren(of: rows[r], named: "a:tc", with: cells[r]) }
        }
        TableMergeTopology.write(regions, cells: cells)
        syncFrameExtent()
        part.markDirty()
    }
}

extension Table {
    /// Replace only the named slots; unknown siblings and markup survive.
    static func replaceTableChildren(of parent: XML.Element, named name: String, with replacements: [XML.Element]) {
        var next = 0
        var nodes: [XML.Node] = []
        var lastSlot = 0
        for node in parent.children {
            if case .element(let element) = node, element.name == name {
                if next < replacements.count { nodes.append(.element(replacements[next])); next += 1 }
                lastSlot = nodes.count
            } else { nodes.append(node) }
        }
        if next < replacements.count {
            nodes.insert(contentsOf: replacements[next...].map(XML.Node.element), at: lastSlot)
        }
        parent.children = nodes
    }
}
