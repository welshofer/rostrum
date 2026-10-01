import Foundation
import Testing
@testable import Rostrum

@Suite struct TableFillAtomicityTests {
    @Test func failedImageFillPreservesExistingCellAndDirtyState() throws {
        let deck = try Presentation()
        let table = try deck.slides[0].shapes.addTable(rows: 1, columns: 1,
            frame: Rect(x: EMU(0), y: EMU(0), width: EMU(914400), height: EMU(914400)))
        let cell = try table.cell(0, 0)
        try cell.setFill(.solid(Color("AB1234")))
        _ = try deck.serializedData()
        let before = cell.tc.serialized()
        #expect(!cell.part.isDirty)
        #expect(throws: RostrumError.self) { try cell.setFill(.image(Data([1, 2, 3]), fit: .stretch)) }
        #expect(cell.tc.serialized() == before)
        #expect(!cell.part.isDirty)
        // A missing tcPr must also remain missing after the failure.
        cell.tc.removeChildren(named: "a:tcPr")
        let sparse = cell.tc.serialized()
        #expect(throws: RostrumError.self) { try cell.setFill(.image(Data(), fit: .stretch)) }
        #expect(cell.tc.serialized() == sparse)
        #expect(!cell.part.isDirty)
    }

    @Test func fillPrecedesHeadersAndExtensionsAfterReopen() throws {
        let deck = try Presentation()
        let table = try deck.slides[0].shapes.addTable(rows: 1, columns: 1,
            frame: Rect(x: EMU(0), y: EMU(0), width: EMU(914400), height: EMU(914400)))
        let cell = try table.cell(0, 0)
        cell.tcPr.appendElement(XML.Element("a:headers"))
        cell.tcPr.appendElement(XML.Element("a:extLst", children: [.comment("keep")]))
        try cell.setFill(.solid(Color("123456")))
        let reopened = try Presentation(data: deck.serializedData())
        let frame = try #require(reopened.slides[0].shapes.all.first as? TableFrame)
        let properties = try #require(frame.table?.cell(0, 0).tc.firstChild(named: "a:tcPr"))
        #expect(properties.childElements.map(\.name) == ["a:solidFill", "a:headers", "a:extLst"])
        #expect(properties.serialized().contains("<!--keep-->"))
    }
}
