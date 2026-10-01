import Foundation

extension ShapeCollection {
    /// Add a table. Column widths and row heights start uniform within
    /// `frame`; adjust with `setColumnWidth`/`setRowHeight`.
    @discardableResult
    public func addTable(rows: Int, columns: Int, frame: Rect) throws -> Table {
        precondition(rows > 0 && columns > 0, "table needs at least 1×1 cells")
        let id = try Slide.nextShapeID(of: part)

        let graphicFrame = XML.Element("p:graphicFrame")
        let nvPr = XML.Element("p:nvGraphicFramePr")
        nvPr.appendElement(XML.Element("p:cNvPr", attributes: [
            ("id", String(id)), ("name", "Table \(id)"),
        ]))
        let cNv = XML.Element("p:cNvGraphicFramePr")
        cNv.appendElement(XML.Element("a:graphicFrameLocks", attributes: [("noGrp", "1")]))
        nvPr.appendElement(cNv)
        nvPr.appendElement(XML.Element("p:nvPr"))
        graphicFrame.appendElement(nvPr)

        // graphicFrame carries its transform directly (p:xfrm, not inside spPr).
        let xfrm = XML.Element("p:xfrm")
        xfrm.appendElement(XML.Element("a:off", attributes: [
            ("x", String(frame.x.rawValue)), ("y", String(frame.y.rawValue)),
        ]))
        xfrm.appendElement(XML.Element("a:ext", attributes: [
            ("cx", String(frame.width.rawValue)), ("cy", String(frame.height.rawValue)),
        ]))
        graphicFrame.appendElement(xfrm)

        let graphic = XML.Element("a:graphic")
        let graphicData = XML.Element("a:graphicData", attributes: [
            ("uri", "http://schemas.openxmlformats.org/drawingml/2006/table"),
        ])
        let tbl = XML.Element("a:tbl")
        let tblPr = XML.Element("a:tblPr", attributes: [("firstRow", "1"), ("bandRow", "1")])
        let styleId = XML.Element("a:tableStyleId")
        styleId.children = [.text(Table.defaultStyleGUID)]
        tblPr.appendElement(styleId)
        tbl.appendElement(tblPr)

        let grid = XML.Element("a:tblGrid")
        let colWidth = frame.width.rawValue / columns
        for column in 0..<columns {
            let width = column == columns - 1 ? frame.width.rawValue - colWidth * (columns - 1) : colWidth
            grid.appendElement(XML.Element("a:gridCol", attributes: [("w", String(width))]))
        }
        tbl.appendElement(grid)

        let rowHeight = frame.height.rawValue / rows
        for row in 0..<rows {
            let height = row == rows - 1 ? frame.height.rawValue - rowHeight * (rows - 1) : rowHeight
            let tr = XML.Element("a:tr", attributes: [("h", String(height))])
            for _ in 0..<columns {
                tr.appendElement(Table.makeCell())
            }
            tbl.appendElement(tr)
        }

        graphicData.appendElement(tbl)
        graphic.appendElement(graphicData)
        graphicFrame.appendElement(graphic)

        try Slide.spTree(of: part).appendElement(graphicFrame)
        part.markDirty()
        return Table(tbl: tbl, part: part, graphicFrame: graphicFrame, package: package)
    }
}

/// A table (`a:tbl` inside a graphic frame).
public final class Table {
    /// PowerPoint's built-in "Medium Style 2 - Accent 1".
    static let defaultStyleGUID = "{5C22544A-7EE6-4342-B048-85BDC9FD1C3A}"
    /// The built-in "No Style, No Grid" — needs no tableStyles.xml part, so
    /// explicit per-cell fills are the single source of truth.
    static let noStyleGUID = "{2D5ABB26-0587-4C30-8999-92F81FD0307C}"

    let tbl: XML.Element
    let part: Part
    /// The owning graphic frame, when known — so width/height helpers can keep
    /// its extent in sync. `nil` when reconstructed from a parsed table.
    let graphicFrame: XML.Element?

    let package: OPCPackage?

    init(tbl: XML.Element, part: Part, graphicFrame: XML.Element? = nil, package: OPCPackage? = nil) {
        self.tbl = tbl
        self.part = part
        self.graphicFrame = graphicFrame
        self.package = package
    }

    /// Set column widths (left to right) and resize the frame to match.
    @discardableResult
    public func columnWidths(_ widths: [EMU]) -> Table {
        let cols = tbl.firstChild(named: "a:tblGrid")?.children(named: "a:gridCol") ?? []
        for (i, w) in widths.enumerated() where i < cols.count { cols[i][attribute: "w"] = String(w.rawValue) }
        syncFrameExtent()
        part.markDirty()
        return self
    }

    /// Set row heights (top to bottom) and resize the frame to match.
    @discardableResult
    public func rowHeights(_ heights: [EMU]) -> Table {
        let rows = TableGridSnapshot(tbl).rows
        for (i, h) in heights.enumerated() where i < rows.count { rows[i][attribute: "h"] = String(h.rawValue) }
        syncFrameExtent()
        part.markDirty()
        return self
    }

    /// Fill cell text row-major; tolerant of size mismatch.
    @discardableResult
    public func setContents(_ grid: [[String]]) -> Table {
        let snapshot = TableGridSnapshot(tbl)
        for (r, rowValues) in grid.enumerated() where r < snapshot.rows.count {
            for (c, value) in rowValues.enumerated()
            where c < snapshot.columns.count && c < snapshot.cells[r].count {
                TableCell(tc: snapshot.cells[r][c], part: part, package: package).text = value
            }
        }
        return self
    }

    /// Switch to the built-in "No Style, No Grid" and clear the header/band
    /// flags, so explicit per-cell fills fully control the look.
    @discardableResult
    public func clearBuiltInStyle() -> Table {
        let tblPr = tbl.getOrAddChild("a:tblPr", beforeAnyOf: ["a:tblGrid"])
        for flag in ["firstRow", "lastRow", "firstCol", "lastCol", "bandRow", "bandCol"] {
            tblPr[attribute: flag] = nil
        }
        styleID = Table.noStyleGUID
        return self
    }

    /// Resize the graphic frame's extent to the sum of column widths / row
    /// heights, so the table never over/under-flows its frame.
    func syncFrameExtent() {
        guard let ext = graphicFrame?.firstChild(named: "p:xfrm")?.firstChild(named: "a:ext") else { return }
        // Bounded: these are file-supplied on an opened deck, and a running
        // Int sum over unbounded widths overflows — which is a crash, not an
        // error the caller can handle.
        let cx = (tbl.firstChild(named: "a:tblGrid")?.children(named: "a:gridCol") ?? [])
            .reduce(0) { $0 + ($1.coordinate("w") ?? 0) }
        let cy = rows.reduce(0) { $0 + ($1.coordinate("h") ?? 0) }
        ext[attribute: "cx"] = String(cx)
        ext[attribute: "cy"] = String(cy)
    }

    static func makeCell() -> XML.Element {
        let tc = XML.Element("a:tc")
        let txBody = XML.Element("a:txBody")
        txBody.appendElement(XML.Element("a:bodyPr"))
        txBody.appendElement(XML.Element("a:lstStyle"))
        txBody.appendElement(XML.Element("a:p"))
        tc.appendElement(txBody)
        tc.appendElement(XML.Element("a:tcPr"))
        return tc
    }

    private var rows: [XML.Element] { tbl.children(named: "a:tr") }

    public var rowCount: Int { rows.count }
    public var columnCount: Int {
        tbl.firstChild(named: "a:tblGrid")?.children(named: "a:gridCol").count ?? 0
    }

    /// The cell at `row`, `column`.
    ///
    /// Throws rather than trapping, because the indices a caller iterates
    /// (`0..<rowCount`, `0..<columnCount`) come from the file: `columnCount`
    /// reports what `a:tblGrid` declares, and a **ragged** table written
    /// elsewhere can have a row with fewer `a:tc` than that. Reading a foreign
    /// deck must never abort the host process, so this follows the same rule
    /// as `Slides.subscript`.
    public func cell(_ row: Int, _ column: Int) throws -> TableCell {
        let snapshot = TableGridSnapshot(tbl)
        return TableCell(tc: try snapshot.cell(row, column), part: part, package: package)
    }

    public func setColumnWidth(_ column: Int, _ width: EMU) {
        guard let cols = tbl.firstChild(named: "a:tblGrid")?.children(named: "a:gridCol"),
              cols.indices.contains(column) else { return }
        cols[column][attribute: "w"] = String(width.rawValue)
        syncFrameExtent()
        part.markDirty()
    }

    public func setRowHeight(_ row: Int, _ height: EMU) {
        let rows = TableGridSnapshot(tbl).rows
        guard rows.indices.contains(row) else { return }
        rows[row][attribute: "h"] = String(height.rawValue)
        syncFrameExtent()
        part.markDirty()
    }

    /// Header-row and banded-row style flags (rendering follows the table
    /// style).
    public var firstRowHeader: Bool {
        get { tbl.firstChild(named: "a:tblPr").map { TableMergeTopology.flag($0, "firstRow") } ?? false }
        set {
            tbl.getOrAddChild("a:tblPr", beforeAnyOf: ["a:tblGrid"])[attribute: "firstRow"] = newValue ? "1" : nil
            part.markDirty()
        }
    }

    public var bandedRows: Bool {
        get { tbl.firstChild(named: "a:tblPr").map { TableMergeTopology.flag($0, "bandRow") } ?? false }
        set {
            tbl.getOrAddChild("a:tblPr", beforeAnyOf: ["a:tblGrid"])[attribute: "bandRow"] = newValue ? "1" : nil
            part.markDirty()
        }
    }

    /// Merge a rectangular region. The origin cell absorbs the span; covered
    /// cells become merge continuations (their text is discarded).
    ///
    /// - Throws: if any cell in the region is missing — which a ragged foreign
    ///   table can be. Every cell is resolved *before* the first one is
    ///   modified, so a region that cannot be merged leaves the table exactly
    ///   as it was rather than half-merged with text already destroyed.
    public func merge(row: Int, column: Int, rowSpan: Int, columnSpan: Int) throws {
        let snapshot = TableGridSnapshot(tbl)
        let topology = try snapshot.topology()
        guard row >= 0, column >= 0, rowSpan > 0, columnSpan > 0,
              row < snapshot.rows.count, column < snapshot.columns.count,
              rowSpan <= snapshot.rows.count - row, columnSpan <= snapshot.columns.count - column else {
            throw RostrumError.packageInvalid("table merge region is out of range")
        }
        for r in row..<(row + rowSpan) { for c in column..<(column + columnSpan) {
            _ = try snapshot.cell(r, c)
            guard topology.region(row: r, column: c) == nil else {
                throw RostrumError.packageInvalid("table merge overlaps an existing merge; unmerge it first")
            }
        } }
        if rowSpan == 1 && columnSpan == 1 { return }
        let region = TableMergeRegion(row: row, column: column, rowSpan: rowSpan, columnSpan: columnSpan)
        TableMergeTopology.write(topology.regions + [region], cells: snapshot.cells)
        for r in row..<(row + rowSpan) { for c in column..<(column + columnSpan) {
            if r == row && c == column { continue }
            if let txBody = snapshot.cells[r][c].firstChild(named: "a:txBody") {
                txBody.removeChildren(named: "a:p")
                txBody.appendElement(XML.Element("a:p"))
            }
        } }
        part.markDirty()
    }

}

/// One table cell (`a:tc`).
public final class TableCell {
    let tc: XML.Element
    let part: Part

    let package: OPCPackage?

    init(tc: XML.Element, part: Part, package: OPCPackage? = nil) {
        self.tc = tc
        self.part = part
        self.package = package
    }

    /// The cell's text body, created if absent. Writing accessor: use
    /// `existingTextFrame` (or `text`) to read without touching the DOM.
    public var textFrame: TextFrame {
        TextFrame(txBody: tc.getOrAddChild("a:txBody", beforeAnyOf: ["a:tcPr"]), part: part)
    }

    /// The cell's text body if it has one — a pure read. `a:txBody` is
    /// optional in `CT_TableCell`, and reading a foreign deck's table must
    /// not invent one.
    public var existingTextFrame: TextFrame? {
        tc.firstChild(named: "a:txBody").map { TextFrame(txBody: $0, part: part) }
    }

    public var text: String {
        get { existingTextFrame?.text ?? "" }
        set {
            textFrame.text = newValue
            part.markDirty()
        }
    }

    /// tcPr children follow schema order: border lines first, then fill.
    var tcPr: XML.Element {
        tc.getOrAddChild("a:tcPr")
    }

    public func setFill(_ fill: Fill) throws {
        let element = try fill.fillElement(embeddingInto: part, package: package)
        for name in Fill.choiceNames { tcPr.removeChildren(named: name) }
        tcPr.insertChild(element, beforeAnyOf: ["a:headers", "a:extLst"])
        part.markDirty()
    }

    public var verticalAnchor: VerticalAnchor {
        get { tc.firstChild(named: "a:tcPr")?[attribute: "anchor"].flatMap(VerticalAnchor.init(rawValue:)) ?? .top }
        set {
            tcPr[attribute: "anchor"] = newValue.rawValue
            part.markDirty()
        }
    }
}
