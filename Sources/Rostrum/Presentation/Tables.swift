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
        return Table(tbl: tbl, part: part)
    }
}

/// A table (`a:tbl` inside a graphic frame).
public final class Table {
    /// PowerPoint's built-in "Medium Style 2 - Accent 1".
    static let defaultStyleGUID = "{5C22544A-7EE6-4342-B048-85BDC9FD1C3A}"

    let tbl: XML.Element
    let part: Part

    init(tbl: XML.Element, part: Part) {
        self.tbl = tbl
        self.part = part
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

    public func cell(_ row: Int, _ column: Int) -> TableCell {
        precondition(rows.indices.contains(row), "row \(row) out of range")
        let cells = rows[row].children(named: "a:tc")
        precondition(cells.indices.contains(column), "column \(column) out of range")
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
    public func merge(row: Int, column: Int, rowSpan: Int, columnSpan: Int) {
        precondition(rowSpan >= 1 && columnSpan >= 1)
        for r in row..<(row + rowSpan) {
            for c in column..<(column + columnSpan) {
                let tc = cell(r, c).tc
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

    public var textFrame: TextFrame {
        TextFrame(txBody: tc.getOrAddChild("a:txBody", beforeAnyOf: ["a:tcPr"]), part: part)
    }

    public var text: String {
        get { textFrame.text }
        set {
            textFrame.text = newValue
            part.markDirty()
        }
    }

    /// tcPr children follow schema order: border lines first, then fill.
    private var tcPr: XML.Element {
        tc.getOrAddChild("a:tcPr")
    }

    public func setFill(_ fill: Fill) {
        for name in Fill.choiceNames { tcPr.removeChildren(named: name) }
        tcPr.appendElement(fill.makeElement())
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
