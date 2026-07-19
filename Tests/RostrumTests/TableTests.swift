import Foundation
import Testing
@testable import Rostrum

@Suite struct TableTests {
    private func makeTable(rows: Int = 3, cols: Int = 3) throws -> (Presentation, Table) {
        let deck = try Presentation()
        let table = try deck.slides[0].shapes.addTable(
            rows: rows, columns: cols,
            frame: Rect(x: .inches(1), y: .inches(1), width: .inches(9), height: .inches(3)))
        return (deck, table)
    }

    @Test func cellTextRoundTrips() throws {
        let (deck, table) = try makeTable()
        table.cell(0, 0).text = "Region"
        table.cell(0, 1).text = "2024"
        table.cell(1, 0).text = "Arctic"
        table.cell(2, 2).text = "−12.2%"

        let reopened = try Presentation(data: try deck.serializedData())
        let tbl = try #require(reopened.slides[0].spTree()
            .firstChild(named: "p:graphicFrame")?
            .firstChild(named: "a:graphic")?
            .firstChild(named: "a:graphicData")?
            .firstChild(named: "a:tbl"))
        let rtable = Table(tbl: tbl, part: reopened.slides[0].part)
        #expect(rtable.rowCount == 3 && rtable.columnCount == 3)
        #expect(rtable.cell(0, 0).text == "Region")
        #expect(rtable.cell(2, 2).text == "−12.2%")
        #expect(rtable.cell(1, 1).text == "")
    }

    @Test func uniformGridThenAdjust() throws {
        let (_, table) = try makeTable(rows: 2, cols: 3)
        #expect(table.columnCount == 3)
        table.setColumnWidth(0, .inches(4))
        table.setRowHeight(1, .inches(2))
        let grid = table.tbl.firstChild(named: "a:tblGrid")!
        #expect(grid.children(named: "a:gridCol")[0][attribute: "w"] == String(EMU.inches(4).rawValue))
        #expect(table.tbl.children(named: "a:tr")[1][attribute: "h"] == String(EMU.inches(2).rawValue))
    }

    @Test func mergeSetsSpansAndContinuations() throws {
        let (_, table) = try makeTable(rows: 3, cols: 3)
        table.cell(1, 1).text = "will vanish"
        table.merge(row: 0, column: 0, rowSpan: 2, columnSpan: 2)

        let origin = table.cell(0, 0).tc
        #expect(origin[attribute: "gridSpan"] == "2" && origin[attribute: "rowSpan"] == "2")
        #expect(table.cell(0, 1).tc[attribute: "hMerge"] == "1")
        #expect(table.cell(1, 0).tc[attribute: "vMerge"] == "1")
        let corner = table.cell(1, 1).tc
        #expect(corner[attribute: "hMerge"] == "1" && corner[attribute: "vMerge"] == "1")
        #expect(table.cell(1, 1).text == "")
        // Untouched cell unaffected.
        #expect(table.cell(2, 2).tc[attribute: "hMerge"] == nil)
    }

    @Test func styleFlagsAndFill() throws {
        let (deck, table) = try makeTable()
        table.bandedRows = false
        #expect(!table.bandedRows && table.firstRowHeader)
        try table.cell(0, 0).setFill(.solid(Color("18A999")))
        table.cell(0, 0).verticalAnchor = .middle

        let reopened = try Presentation(data: try deck.serializedData())
        let tcPr = try #require(reopened.slides[0].spTree()
            .firstChild(named: "p:graphicFrame")?
            .firstChild(named: "a:graphic")?.firstChild(named: "a:graphicData")?
            .firstChild(named: "a:tbl")?.children(named: "a:tr")[0]
            .children(named: "a:tc")[0].firstChild(named: "a:tcPr"))
        #expect(tcPr.firstChild(named: "a:solidFill")?.firstChild(named: "a:srgbClr")?[attribute: "val"] == "18A999")
        #expect(tcPr[attribute: "anchor"] == "ctr")
    }
}
