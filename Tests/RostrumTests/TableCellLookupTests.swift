import Foundation
import Testing
@testable import Rostrum

@Suite struct TableCellLookupTests {
    private func make() throws -> (Presentation, Table) {
        let deck = try Presentation()
        let table = try deck.slides[0].shapes.addTable(rows: 3, columns: 3,
            frame: Rect(x: .zero, y: .zero, width: .inches(6), height: .inches(3)))
        table.setContents([["a", "b", "c"], ["d", "e", "f"], ["g", "h", "i"]])
        return (deck, table)
    }

    @Test func missingIndicesPreserveExactErrorsWithoutWriting() throws {
        let (deck, table) = try make()
        _ = try deck.serializedData()
        let before = table.tbl.serialized()
        for (row, column) in [(-1, 0), (0, -1), (3, 0), (0, 3),
                               (Int.min, Int.max), (Int.max, Int.min), (Int.max, Int.max)] {
            #expect(throws: RostrumError.packageInvalid("table cell (\(row), \(column)) is missing")) {
                try table.cell(row, column)
            }
        }
        #expect(table.tbl.serialized() == before)
        #expect(!table.part.isDirty)
    }

    @Test func physicalCellsIgnoreDeclaredColumnsAndNoncellSiblings() throws {
        let (_, table) = try make()
        let rows = table.tbl.children(named: "a:tr")
        let expected = rows[1].children(named: "a:tc")[2]
        let extra = Table.makeCell()
        rows[1].children.insert(.comment("keep comment"), at: 0)
        rows[1].children.insert(.element(XML.Element("a:extLst")), at: 1)
        rows[1].children.insert(.text(" \n"), at: 2)
        rows[1].appendElement(extra)
        table.tbl.children.insert(.element(XML.Element("x:tr")), at: 0)
        table.tbl.children.insert(.comment("not a row"), at: 1)
        // Missing or inaccurate grid metadata must not hide physical cells.
        table.tbl.removeChildren(named: "a:tblGrid")
        let before = table.tbl.serialized()
        #expect(try table.cell(1, 2).tc === expected)
        #expect(try table.cell(1, 3).tc === extra)
        #expect(try table.cell(1, 3).owner === table)
        #expect(try table.cell(1, 3).package === table.package)
        #expect(table.columnCount == 0)
        #expect(throws: RostrumError.packageInvalid("table cell (1, 4) is missing")) { try table.cell(1, 4) }
        #expect(table.tbl.serialized() == before)
        rows[0].removeChildren(named: "a:tc")
        #expect(throws: RostrumError.packageInvalid("table cell (0, 0) is missing")) { try table.cell(0, 0) }
        #expect(try table.cell(1, 2).tc === expected)
        rows[1].name = "x:tr"
        #expect(try table.cell(1, 2).text == "i")
        rows[1].name = "a:tr"
        #expect(try table.cell(1, 2).tc === expected)
        #expect(before.contains("keep comment"))
    }

    @Test func survivingIdentityAndFreshDOMStayLiveAcrossMutations() throws {
        let (deck, table) = try make()
        let cell = try table.cell(1, 1)
        let originalNode = cell.tc
        let retainedFrame = cell.textFrame
        try table.insertRow(at: 0); try table.insertColumn(at: 0)
        #expect(try table.cell(2, 2).tc === originalNode)
        try table.moveRow(from: 2, to: 0); try table.moveColumn(from: 2, to: 0)
        #expect(try table.cell(0, 0).tc === originalNode)
        try table.merge(row: 0, column: 0, rowSpan: 2, columnSpan: 2)
        #expect(try table.cell(0, 0).tc === originalNode)
        #expect(try table.cell(1, 1).tc !== originalNode)
        try table.unmerge(row: 1, column: 1)
        try table.cell(0, 0).text = "changed through fresh wrapper"
        #expect(retainedFrame.text == "changed through fresh wrapper")
        let firstRow = table.tbl.children(named: "a:tr")[0]
        let replacement = Table.makeCell()
        firstRow.children = firstRow.children.map {
            if case .element(let node) = $0, node === originalNode { return .element(replacement) }
            return $0
        }
        #expect(try table.cell(0, 0).tc === replacement)
        #expect(cell.tc === originalNode)
        firstRow.children.insert(.element(originalNode), at: 0)
        firstRow.appendElement(originalNode)
        #expect(try table.cell(0, 0).tc === originalNode)
        #expect(try table.cell(0, firstRow.children(named: "a:tc").count - 1).tc === originalNode)
        // A read must preserve ragged/aliased trees, including unmodeled nodes.
        firstRow.appendElement(XML.Element("a:extLst", children: [.comment("retained extension")]))
        let before = table.tbl.serialized()
        _ = try table.cell(0, 0).existingTextFrame
        #expect(table.tbl.serialized() == before)
        // Saved/reopened XML continues to expose the expected physical cells.
        let copy = try Presentation(data: deck.serializedData())
        let reopened = try #require((try copy.slides[0].shapes.all.first as? TableFrame)?.table)
        #expect(try reopened.cell(0, 0).text == cell.text)
    }
}
