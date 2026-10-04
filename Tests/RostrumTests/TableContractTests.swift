import Foundation
import Testing
@testable import Rostrum

@Suite struct TableContractTests {
    private func make(_ rows: Int = 3, _ columns: Int = 3) throws -> (Presentation, Table) {
        let deck = try Presentation()
        let table = try deck.slides[0].shapes.addTable(rows: rows, columns: columns,
            frame: Rect(x: EMU(1000), y: EMU(2000), width: EMU(columns * 1000000), height: EMU(rows * 500000)))
        return (deck, table)
    }
    private func reopen(_ deck: Presentation) throws -> (Presentation, Table) {
        let copy = try Presentation(data: deck.serializedData())
        let frame = try #require(copy.slides[0].shapes.all.first as? TableFrame)
        return (copy, try #require(frame.table))
    }

    @Test func overlapAndMalformedTopologyRefuseAtomically() throws {
        let (deck, table) = try make()
        table.setContents([["origin", "discard"], ["discard", "discard"]])
        try table.merge(row: 0, column: 0, rowSpan: 2, columnSpan: 2)
        _ = try deck.serializedData()
        let before = table.tbl.serialized()
        #expect(throws: RostrumError.self) { try table.merge(row: 1, column: 1, rowSpan: 2, columnSpan: 2) }
        #expect(throws: RostrumError.self) { try table.merge(row: 0, column: 0, rowSpan: Int.max, columnSpan: 1) }
        #expect(table.tbl.serialized() == before)
        #expect(!table.part.isDirty)
        let (_, copy) = try reopen(deck)
        #expect(try copy.mergeInfo(row: 1, column: 1) == TableMergeRegion(row: 0, column: 0, rowSpan: 2, columnSpan: 2))
        #expect(try copy.cell(0, 1).tc[attribute: "rowSpan"] == "2")
        #expect(try copy.cell(1, 0).tc[attribute: "gridSpan"] == "2")
        try table.cell(2, 2).tc[attribute: "hMerge"] = "true"
        let malformed = table.tbl.serialized()
        #expect(throws: RostrumError.self) { try table.insertRow(at: 0) }
        #expect(table.tbl.serialized() == malformed)
    }

    @Test func unmergeFromContinuationRetainsOriginAndUnknownXML() throws {
        let (deck, table) = try make()
        table.setContents([["kept", "discarded"]])
        let origin = try table.cell(0, 0)
        origin.tc.appendElement(XML.Element("a:extLst", children: [.comment("opaque extension")]))
        try table.merge(row: 0, column: 0, rowSpan: 2, columnSpan: 2)
        try table.unmerge(row: 1, column: 1)
        let (_, copy) = try reopen(deck)
        #expect(try copy.mergedRegions.isEmpty)
        #expect(try copy.cell(0, 0).text == "kept")
        #expect(try copy.cell(0, 1).text == "")
        #expect(try copy.cell(0, 0).tc.serialized().contains("opaque extension"))
    }

    @Test func insertionRemovalAndDimensionChangesStayCoherent() throws {
        let (deck, table) = try make()
        table.columnWidths([EMU(100000), EMU(200000), EMU(300000)])
        table.rowHeights([EMU(100000), EMU(200000), EMU(300000)])
        try table.merge(row: 0, column: 0, rowSpan: 2, columnSpan: 2)
        try table.insertRow(at: 1, height: EMU(700000))
        try table.insertColumn(at: 1, width: EMU(800000))
        #expect(try table.mergeInfo(row: 2, column: 2)?.rowSpan == 3)
        #expect(try table.mergeInfo(row: 2, column: 2)?.columnSpan == 3)
        try table.removeRow(at: 0)
        try table.removeColumn(at: 0)
        table.setColumnWidth(2, EMU(900000))
        table.setRowHeight(2, EMU(1000000))
        let (_, copy) = try reopen(deck)
        #expect(try copy.mergeInfo(row: 1, column: 1) == TableMergeRegion(row: 0, column: 0, rowSpan: 2, columnSpan: 2))
        let extent = try #require(copy.graphicFrame?.firstChild(named: "p:xfrm")?.firstChild(named: "a:ext"))
        #expect(extent[attribute: "cx"] == "1900000")
        #expect(extent[attribute: "cy"] == "1900000")
    }

    @Test func reorderingMovesRichCellObjectsAndRejectsSplitMerges() throws {
        let (deck, table) = try make(4, 3)
        table.setContents([["a", "b", "c"], ["d", "e", "f"], ["g", "h", "i"], ["j", "k", "l"]])
        let rich = try table.cell(2, 0).textFrame.paragraphs[0]
        rich.addRun(" rich").bold = true
        try table.merge(row: 0, column: 1, rowSpan: 2, columnSpan: 2)
        let before = table.tbl.serialized()
        #expect(throws: RostrumError.self) { try table.reorderRows([0, 2, 1, 3]) }
        #expect(throws: RostrumError.self) { try table.reorderColumns([1, 0, 2]) }
        #expect(table.tbl.serialized() == before)
        try table.reorderRows([2, 3, 0, 1])
        try table.reorderColumns([1, 2, 0])
        let (_, copy) = try reopen(deck)
        #expect(try copy.cell(0, 2).text == "g rich")
        #expect(try copy.cell(0, 2).existingTextFrame?.paragraphs[0].runs.last?.bold == true)
        #expect(try copy.mergeInfo(row: 3, column: 1)?.row == 2)
        #expect(try copy.mergeInfo(row: 3, column: 1)?.column == 0)
    }

    @Test func raggedBulkOperationsRemainTolerantButStructuralEditsRefuse() throws {
        let (_, table) = try make()
        let row = table.tbl.children(named: "a:tr")[1]
        row.removeChildren(named: "a:tc")
        table.setContents([["a"], ["ignored"], ["c"]]).cellPadding(EMU(40))
        #expect(try table.cell(2, 0).text == "c")
        let before = table.tbl.serialized()
        #expect(throws: RostrumError.self) { try table.insertColumn(at: 0) }
        #expect(table.tbl.serialized() == before)
    }

    @Test func bordersAndPureReadsSurviveReopen() throws {
        let (deck, table) = try make(1, 1)
        let cell = try table.cell(0, 0)
        cell.tc.removeChildren(named: "a:tcPr")
        let before = cell.tc.serialized()
        #expect(cell.verticalAnchor == .top)
        #expect(cell.textDirection == .horizontal)
        #expect(cell.border(.left) == nil)
        #expect(cell.tc.serialized() == before)
        cell.setBorders(nil).setBorder(.diagonalDown, line: Line(color: Color("AABBCC"), width: EMU(20000)))
        cell.tcPr.appendElement(XML.Element("a:extLst", children: [.comment("keep")]))
        cell.setBorder(.top, line: Line(color: .black))
        cell.textDirection = .vertical270
        let (_, copy) = try reopen(deck)
        let copied = try copy.cell(0, 0)
        #expect(copied.border(.left)?.isNone == true)
        #expect(copied.border(.top)?.color == .black)
        #expect(copied.border(.diagonalDown)?.width == EMU(20000))
        #expect(copied.textDirection == .vertical270)
        #expect(copied.tcPr.childElements.last?.name == "a:extLst")
    }

    @Test func mergedRenderingUsesSpansBordersAndRTLWithoutMutating() throws {
        let (deck, table) = try make(2, 3)
        table.clearBuiltInStyle().columnWidths([EMU(100000), EMU(200000), EMU(300000)])
        table.rightToLeft = true
        try table.merge(row: 0, column: 0, rowSpan: 2, columnSpan: 2)
        let cell = try table.cell(0, 0)
        cell.setFill(Color("123456"))
        cell.setBorder(.diagonalDown, line: Line(color: Color("ABCDEF")))
        let before = table.tbl.serialized()
        let svg = try deck.renderSVG(slideAt: 0)
        #expect(svg.contains("<rect x=\"301000\" y=\"2000\" width=\"300000\" height=\"1000000\" fill=\"#123456\""))
        #expect(svg.contains("x1=\"301000\" y1=\"2000\" x2=\"601000\" y2=\"1002000\""))
        #expect(!svg.contains("#DDDDDD"))
        #expect(svg.components(separatedBy: "fill=\"#123456\"").count == 2)
        #expect(table.tbl.serialized() == before)
        let (copy, _) = try reopen(deck)
        #expect(try copy.renderSVG(slideAt: 0) == svg)
    }
}
