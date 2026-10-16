import Foundation

/// Operation-local access for RostrumLayout. Resolve the grid and style regions
/// once, rather than searching the complete table separately for every cell.
package struct TableLayoutSource {
    package let columnWidths: [EMU]
    package let rowCount: Int
    package let merges: [TableMergeRegion]
    private let grid: TableGridSnapshot
    private let topology: TableMergeTopology
    private var styles: TableStyleResolver.FittingSession

    package init(table: Table, theme: Theme) throws {
        styles = TableStyleResolver.FittingSession(table: table, theme: theme)
        grid = styles.grid
        topology = try grid.topology(requireRectangular: true)
        merges = topology.regions
        columnWidths = grid.columns.map { EMU($0.coordinate("w") ?? 0) }
        rowCount = grid.rows.count
    }

    /// Only the top-left anchor contributes geometry. Zero columns marks any
    /// covered continuation, including the left edge of a vertical merge.
    package func span(row: Int, column: Int) -> (rows: Int, columns: Int) {
        guard let region = topology.region(row: row, column: column) else { return (1, 1) }
        return row == region.row && column == region.column ? (region.rowSpan, region.columnSpan) : (1, 0)
    }

    package mutating func cell(row: Int, column: Int, styleRow: Int? = nil,
                               styleRowCount: Int? = nil) -> TableLayoutCell {
        let cell = grid.cells[row][column]
        let effective = styles.effective(row: row, column: column, styleRow: styleRow, styleRowCount: styleRowCount)
        func inset(_ name: String, _ fallback: Int) -> Double {
            Double(effective.properties.coordinate(name) ?? fallback) / Double(EMU.perPoint)
        }
        return TableLayoutCell(body: cell.firstChild(named: "a:txBody") ?? XML.Element("a:txBody"),
            textStyle: effective.text,
            insets: (inset("marL", 91440), inset("marT", 45720), inset("marR", 91440), inset("marB", 45720)),
            direction: effective.properties[attribute: "vert"] ?? "horz",
            verticallyMerged: (topology.region(row: row, column: column)?.rowSpan ?? 1) > 1)
    }
}

package struct TableLayoutCell {
    package let body: XML.Element
    package let textStyle: XML.Element
    package let insets: (left: Double, top: Double, right: Double, bottom: Double)
    package let direction: String
    package let verticallyMerged: Bool
}

extension Table {
    package func layoutTheme(fallback: Theme) -> Theme {
        guard let package, let layout = try? part.related(by: RelType.slideLayout, in: package),
              let master = try? layout.related(by: RelType.slideMaster, in: package),
              let theme = try? master.related(by: RelType.theme, in: package) else { return fallback }
        return Theme(part: theme, master: master)
    }

    /// Use the authoring factory on a detached part. The package supplies native
    /// table styles, but neither its slides nor its relationships are modified.
    package static func layoutPrototype(contents: [[String]], width: EMU, font: String,
                                        size: Double, package: OPCPackage) throws -> Table {
        guard let columns = contents.first?.count, columns > 0,
              contents.allSatisfy({ $0.count == columns }) else {
            throw RostrumError.packageInvalid("Table content must be a nonempty rectangular grid")
        }
        let part = Part(uri: PackURI("/ppt/slides/table-layout-prototype.xml"), contentType: ContentType.slide,
            blob: Data("<p:sld><p:cSld><p:spTree/></p:cSld></p:sld>".utf8))
        let table = try ShapeCollection(part: part, package: package).addTable(rows: contents.count, columns: columns,
            frame: Rect(x: .zero, y: .zero, width: width, height: .points(30 * Double(contents.count))))
        table.setLayoutContents(contents, font: font, size: size)
        return table
    }

    package func setLayoutContents(_ contents: [[String]], font: String, size: Double) {
        setContents(contents)
        let grid = TableGridSnapshot(tbl)
        for row in grid.cells { for cell in row {
            let frame = TableCell(tc: cell, part: part, package: package).textFrame
            for paragraph in frame.paragraphs { for run in paragraph.runs {
                run.fontSize = size; run.fontName = font
            } }
        } }
    }
}
