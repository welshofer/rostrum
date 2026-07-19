import Foundation
import Testing
@testable import Rostrum

@Suite struct TableStylingTests {
    private let frame = Rect(x: .inches(1), y: .inches(1), width: .inches(9), height: .inches(4))

    private func tableDOM(_ deck: Presentation) throws -> XML.Element {
        try deck.slides[0].part.dom().firstChild(named: "p:cSld")!.firstChild(named: "p:spTree")!
            .firstChild(named: "p:graphicFrame")!
    }
    private func tbl(_ gf: XML.Element) -> XML.Element {
        gf.firstChild(named: "a:graphic")!.firstChild(named: "a:graphicData")!.firstChild(named: "a:tbl")!
    }
    private func cellFill(_ t: XML.Element, _ r: Int, _ c: Int) -> String? {
        t.children(named: "a:tr")[r].children(named: "a:tc")[c]
            .firstChild(named: "a:tcPr")?.firstChild(named: "a:solidFill")?.firstChild(named: "a:srgbClr")?[attribute: "val"]
    }

    @Test func columnWidthsSetGridColsAndFrameExtent() throws {
        let deck = try Presentation()
        let table = try deck.slides[0].shapes.addTable(rows: 2, columns: 3, frame: frame)
        table.columnWidths([.inches(4), .inches(2.5), .inches(2.5)])
        let gf = try tableDOM(deck)
        let cols = tbl(gf).firstChild(named: "a:tblGrid")!.children(named: "a:gridCol")
        #expect(cols[0][attribute: "w"] == String(EMU.inches(4).rawValue))
        #expect(cols[2][attribute: "w"] == String(EMU.inches(2.5).rawValue))
        // The graphic frame's extent tracks the sum.
        let cx = gf.firstChild(named: "p:xfrm")!.firstChild(named: "a:ext")![attribute: "cx"]
        #expect(cx == String(EMU.inches(9).rawValue))
    }

    @Test func brandHeaderFillsPrimaryWithAutoContrastText() throws {
        let deck = try Presentation()
        let s = deck.style
        let table = try deck.slides[0].shapes.addTable(rows: 3, columns: 2, frame: frame)
        table.setContents([["Metric", "Value"], ["ARR", "18.4"], ["NPS", "47"]]).header(style: s)
        let t = tbl(try tableDOM(deck))
        #expect(cellFill(t, 0, 0) == s.primary.hex)
        // Header text auto-contrasts on the primary fill.
        let run = t.children(named: "a:tr")[0].children(named: "a:tc")[0]
            .firstChild(named: "a:txBody")!.firstChild(named: "a:p")!.firstChild(named: "a:r")!
        #expect(run.firstChild(named: "a:rPr")?.firstChild(named: "a:solidFill")?.firstChild(named: "a:srgbClr")?[attribute: "val"]
                == s.textColor(on: s.primary).hex)
        // Built-in style neutralized: no firstRow/bandRow flags.
        let tblPr = t.firstChild(named: "a:tblPr")!
        #expect(tblPr[attribute: "firstRow"] == nil && tblPr[attribute: "bandRow"] == nil)
        #expect(tblPr.firstChild(named: "a:tableStyleId")?.textContent == Table.noStyleGUID)
    }

    @Test func bandedRowsAlternateFills() throws {
        let deck = try Presentation()
        let s = deck.style
        let table = try deck.slides[0].shapes.addTable(rows: 5, columns: 2, frame: frame)
        table.styleBanded(style: s)
        let t = tbl(try tableDOM(deck))
        #expect(cellFill(t, 0, 0) == s.primary.hex)                                    // header
        let band1 = s.surface.hex
        let band2 = s.primary.mixed(with: s.surface, amount: 0.90).hex
        #expect(cellFill(t, 1, 0) == band1)
        #expect(cellFill(t, 2, 0) == band2)
        #expect(cellFill(t, 3, 0) == band1)
    }

    @Test func cellPaddingWritesMarginsAndKeepsSchemaOrder() throws {
        let deck = try Presentation()
        let table = try deck.slides[0].shapes.addTable(rows: 2, columns: 2, frame: frame)
        table.styleBanded(style: deck.style)
            .cellPadding(left: .points(6), top: .points(4), right: .points(6), bottom: .points(4))
        let tcPr = tbl(try tableDOM(deck)).children(named: "a:tr")[0].children(named: "a:tc")[0].firstChild(named: "a:tcPr")!
        #expect(tcPr[attribute: "marL"] == String(EMU.points(6).rawValue))
        #expect(tcPr[attribute: "marT"] == String(EMU.points(4).rawValue))
        // Fill is the only tcPr child (before any a:headers/a:extLst).
        #expect(tcPr.childElements.map(\.name) == ["a:solidFill"])
        // No schema violations anywhere.
        #expect(try deck.validate().isEmpty)
    }

    @Test func styledTableIsDeterministicAndReopens() throws {
        func build() throws -> Data {
            let deck = try Presentation()
            let table = try deck.slides[0].shapes.addTable(rows: 4, columns: 3, frame: frame)
            table.setContents([["Region", "2024", "Δ"], ["Arctic", "18.1", "−12%"],
                               ["Boreal", "22.4", "+3%"], ["Tropic", "31.0", "+1%"]])
                .columnWidths([.inches(4), .inches(2.5), .inches(2.5)])
                .cellPadding(deck.style.spacing.sm)
                .styleBanded(style: deck.style)
            return try deck.serializedData()
        }
        let a = try build(), b = try build()
        #expect(a == b)
        _ = try Presentation(data: a)
    }
}
