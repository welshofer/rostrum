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
        for _ in 0..<columns {
            grid.appendElement(XML.Element("a:gridCol", attributes: [("w", String(colWidth))]))
        }
        tbl.appendElement(grid)

        let rowHeight = frame.height.rawValue / rows
        for _ in 0..<rows {
            let tr = XML.Element("a:tr", attributes: [("h", String(rowHeight))])
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
        return Table(tbl: tbl, part: part, graphicFrame: graphicFrame)
    }
}

/// A table (`a:tbl` inside a graphic frame).
public final class Table {
    /// PowerPoint's built-in "Medium Style 2 - Accent 1".
    static let defaultStyleGUID = "{5C22544A-7EE6-4342-B048-85BDC9FD1C3A}"
    /// The built-in "No Style, No Grid" — needs no tableStyles.xml part, so
    /// explicit per-cell fills are the single source of truth.
    static let noStyleGUID = "{5940675A-B579-460E-94D1-54222C63F5DA}"

    let tbl: XML.Element
    let part: Part
    /// The owning graphic frame, when known — so width/height helpers can keep
    /// its extent in sync. `nil` when reconstructed from a parsed table.
    let graphicFrame: XML.Element?

    init(tbl: XML.Element, part: Part, graphicFrame: XML.Element? = nil) {
        self.tbl = tbl
        self.part = part
        self.graphicFrame = graphicFrame
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
        for (i, h) in heights.enumerated() where i < rows.count { rows[i][attribute: "h"] = String(h.rawValue) }
        syncFrameExtent()
        part.markDirty()
        return self
    }

    /// Fill cell text row-major; tolerant of size mismatch.
    @discardableResult
    public func setContents(_ grid: [[String]]) -> Table {
        for (r, rowValues) in grid.enumerated() where r < rowCount {
            // Tolerant by contract, so a ragged foreign row simply has fewer
            // cells to fill rather than being an error.
            for (c, value) in rowValues.enumerated() where c < columnCount {
                if let cell = try? cell(r, c) { cell.text = value }
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
        tblPr.getOrAddChild("a:tableStyleId").children = [.text(Table.noStyleGUID)]
        part.markDirty()
        return self
    }

    /// Resize the graphic frame's extent to the sum of column widths / row
    /// heights, so the table never over/under-flows its frame.
    private func syncFrameExtent() {
        guard let ext = graphicFrame?.firstChild(named: "p:xfrm")?.firstChild(named: "a:ext") else { return }
        // Bounded: these are file-supplied on an opened deck, and a running
        // Int sum over unbounded widths overflows — which is a crash, not an
        // error the caller can handle.
        let cx = (tbl.firstChild(named: "a:tblGrid")?.children(named: "a:gridCol") ?? [])
            .reduce(0) { $0 + ($1.coordinate("w") ?? 0) }
        let cy = rows.reduce(0) { $0 + ($1.coordinate("h") ?? 0) }
        if cx > 0 { ext[attribute: "cx"] = String(cx) }
        if cy > 0 { ext[attribute: "cy"] = String(cy) }
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
        guard rows.indices.contains(row) else {
            throw RostrumError.packageInvalid("table row \(row) out of range 0..<\(rows.count)")
        }
        let cells = rows[row].children(named: "a:tc")
        guard cells.indices.contains(column) else {
            throw RostrumError.packageInvalid(
                "table row \(row) has \(cells.count) cells; column \(column) is out of range "
                    + "(the grid declares \(columnCount))")
        }
        return TableCell(tc: cells[column], part: part)
    }

    public func setColumnWidth(_ column: Int, _ width: EMU) {
        guard let cols = tbl.firstChild(named: "a:tblGrid")?.children(named: "a:gridCol"),
              cols.indices.contains(column) else { return }
        cols[column][attribute: "w"] = String(width.rawValue)
        part.markDirty()
    }

    public func setRowHeight(_ row: Int, _ height: EMU) {
        guard rows.indices.contains(row) else { return }
        rows[row][attribute: "h"] = String(height.rawValue)
        part.markDirty()
    }

    /// Header-row and banded-row style flags (rendering follows the table
    /// style).
    public var firstRowHeader: Bool {
        get { tbl.firstChild(named: "a:tblPr")?[attribute: "firstRow"] == "1" }
        set {
            tbl.getOrAddChild("a:tblPr", beforeAnyOf: ["a:tblGrid"])[attribute: "firstRow"] = newValue ? "1" : nil
            part.markDirty()
        }
    }

    public var bandedRows: Bool {
        get { tbl.firstChild(named: "a:tblPr")?[attribute: "bandRow"] == "1" }
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
        precondition(rowSpan >= 1 && columnSpan >= 1)
        var resolved: [(row: Int, column: Int, tc: XML.Element)] = []
        for r in row..<(row + rowSpan) {
            for c in column..<(column + columnSpan) {
                resolved.append((r, c, try cell(r, c).tc))
            }
        }
        for (r, c, tc) in resolved {
            if r == row && c == column {
                tc[attribute: "gridSpan"] = columnSpan > 1 ? String(columnSpan) : nil
                tc[attribute: "rowSpan"] = rowSpan > 1 ? String(rowSpan) : nil
            } else {
                if c > column { tc[attribute: "hMerge"] = "1" }
                if r > row { tc[attribute: "vMerge"] = "1" }
                if let txBody = tc.firstChild(named: "a:txBody") {
                    txBody.removeChildren(named: "a:p")
                    txBody.appendElement(XML.Element("a:p"))
                }
            }
        }
        part.markDirty()
    }
}

/// One table cell (`a:tc`).
public final class TableCell {
    let tc: XML.Element
    let part: Part

    init(tc: XML.Element, part: Part) {
        self.tc = tc
        self.part = part
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
        for name in Fill.choiceNames { tcPr.removeChildren(named: name) }
        // Table cells have no package handle; pure fills work, image fills throw.
        tcPr.appendElement(try fill.fillElement(embeddingInto: part, package: nil))
        part.markDirty()
    }

    public var verticalAnchor: VerticalAnchor {
        get { tcPr[attribute: "anchor"].flatMap(VerticalAnchor.init(rawValue:)) ?? .top }
        set {
            tcPr[attribute: "anchor"] = newValue.rawValue
            part.markDirty()
        }
    }
}
