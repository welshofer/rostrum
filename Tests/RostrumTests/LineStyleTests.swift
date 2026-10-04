import Foundation
import Testing
@testable import Rostrum

@Suite struct LineStyleTests {
    private let frame = Rect(x: .zero, y: .zero, width: .inches(2), height: .inches(1))

    @Test(arguments: [LineCompound.double, .thickThin], [LineDash.dash, .systemDot])
    func typedShapeAndTableStylesSurviveReopen(_ compound: LineCompound, _ dash: LineDash) throws {
        let deck = try Presentation()
        let slide = try deck.slides[0]
        let line = Line(color: Color("ABCDEF"), width: .points(3), compound: compound, dash: dash)
        let shape = try slide.shapes.addShape(.rectangle, frame: frame, fill: .solid(.white), line: line)
        let rounded = try slide.shapes.addRoundedRectangle(frame, cornerRadius: .points(4), fill: .solid(.white))
        rounded.setLine(line)
        let table = try slide.shapes.addTable(rows: 1, columns: 1, frame: frame)
        try table.cell(0, 0).setBorder(.top, line: line)
        for element in [shape.element.firstChild(named: "p:spPr")?.firstChild(named: "a:ln"),
                        rounded.element.firstChild(named: "p:spPr")?.firstChild(named: "a:ln"),
                        try table.cell(0, 0).tcPr.firstChild(named: "a:lnT")] {
            let element = try #require(element)
            #expect(element.childElements.map(\.name) == ["a:solidFill", "a:prstDash"])
        }
        let bytes = try deck.serializedData()
        #expect(try deck.serializedData() == bytes)
        let copy = try Presentation(data: bytes)
        let shapes = try copy.slides[0].shapes.all
        let copiedTable = try #require((shapes[2] as? TableFrame)?.table)
        let effective = try TableStyleResolver(table: copiedTable, theme: copy.theme).border(.top, row: 0, column: 0)
        #expect(effective?.compoundStyle == compound.rawValue)
        #expect(effective?.dashStyle == dash.rawValue)
        let borders = [shapes[0].line, shapes[1].line, try copiedTable.cell(0, 0).border(.top)]
        for border in borders {
            #expect(border?.color == Color("ABCDEF"))
            #expect(border?.width == .points(3))
            #expect(border?.compoundStyle == compound.rawValue)
            #expect(border?.dashStyle == dash.rawValue)
        }
    }

    @Test func effectiveStyleCompoundIsReadableBeforeExplicitOverride() throws {
        let deck = try Presentation()
        let table = try deck.slides[0].shapes.addTable(rows: 2, columns: 1, frame: frame)
        try table.setStyleDefinition(XML.parse(Data("""
        <a:tblStyle xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" styleId="{12345678-1234-1234-1234-123456789ABC}" styleName="Double">
          <a:wholeTbl><a:tcStyle><a:tcBdr><a:top><a:ln cmpd="dbl" w="38100"><a:solidFill><a:srgbClr val="112233"/></a:solidFill><a:prstDash val="sysDot"/></a:ln></a:top></a:tcBdr></a:tcStyle></a:wholeTbl>
        </a:tblStyle>
        """.utf8)))
        #expect(try table.cell(0, 0).border(.top) == nil)
        let inherited = try TableStyleResolver(table: table, theme: deck.theme).border(.top, row: 0, column: 0)
        #expect(inherited?.compoundStyle == "dbl")
        #expect(inherited?.dashStyle == "sysDot")
        try table.cell(0, 0).setBorder(.top, line: Line(color: .black, compound: .single, dash: .solid))
        let overridden = try TableStyleResolver(table: table, theme: deck.theme).border(.top, row: 0, column: 0)
        #expect(overridden?.compoundStyle == "sng")
        #expect(overridden?.dashStyle == "solid")
        #expect(overridden?.color == .black)
    }

    @Test func unspecifiedStylesAndOpaqueBorderDataRemainIntact() throws {
        let deck = try Presentation()
        let table = try deck.slides[0].shapes.addTable(rows: 1, columns: 1, frame: frame)
        let cell = try table.cell(0, 0)
        let border = try XML.parse(Data("""
        <a:lnL xmlns:x="urn:line-extension" w="12700" cmpd="futureCompound" cap="rnd" x:policy="keep">
          <a:solidFill><a:srgbClr val="112233"/></a:solidFill>
          <a:prstDash val="futureDash" x:pattern="keep"><a:extLst><a:ext uri="dash"><x:payload/></a:ext></a:extLst></a:prstDash>
          <a:round/><a:headEnd type="triangle"/><!--keep--><a:extLst><a:ext uri="border"><x:payload/></a:ext></a:extLst>
        </a:lnL>
        """.utf8))
        cell.tcPr.appendElement(border)
        let opaque = try #require(border.firstChild(named: "a:extLst")).serialized()
        let preset = try #require(border.firstChild(named: "a:prstDash"))
        let originalPreset = preset.serialized()
        let readBefore = cell.tc.serialized()
        #expect(cell.border(.left)?.compoundStyle == "futureCompound")
        #expect(cell.border(.left)?.dashStyle == "futureDash")
        #expect(cell.tc.serialized() == readBefore)
        cell.setBorder(.left, line: Line(color: .black, width: .points(2)))
        #expect(border[attribute: "cmpd"] == "futureCompound")
        #expect(preset.serialized() == originalPreset)
        // Compound and dash can each be changed independently.
        cell.setBorder(.left, line: Line(color: .black, compound: .double))
        #expect(preset.serialized() == originalPreset)
        cell.setBorder(.left, line: Line(color: .black, dash: .largeDashDot))
        #expect(border[attribute: "cmpd"] == "dbl")
        #expect(preset[attribute: "val"] == "lgDashDot")
        #expect(preset[attribute: "x:pattern"] == "keep")
        #expect(preset.firstChild(named: "a:extLst") != nil)
        cell.setBorder(.left, line: Line(color: .white, compound: .single, dash: .solid))
        #expect(border[attribute: "cmpd"] == "sng")
        #expect(preset[attribute: "val"] == "solid")
        #expect(border[attribute: "cap"] == "rnd")
        #expect(border[attribute: "x:policy"] == "keep")
        #expect(border.firstChild(named: "a:headEnd")?[attribute: "type"] == "triangle")
        #expect(border.firstChild(named: "a:extLst")?.serialized() == opaque)
        cell.setBorder(.left, line: nil)
        #expect(cell.border(.left)?.isNone == true)
        #expect(cell.border(.left)?.compoundStyle == "sng")
        #expect(cell.border(.left)?.dashStyle == "solid")
        let copy = try Presentation(data: deck.serializedData())
        let reopened = try #require((copy.slides[0].shapes.all[0] as? TableFrame)?.table).cell(0, 0)
        let final = try #require(reopened.tcPr.firstChild(named: "a:lnL"))
        #expect(reopened.border(.left)?.isNone == true)
        #expect(final[attribute: "x:policy"] == "keep")
        #expect(final.firstChild(named: "a:extLst")?.serialized() == opaque)
        #expect(final.firstChild(named: "a:prstDash")?[attribute: "x:pattern"] == "keep")
        #expect(final.children.contains { if case .comment("keep") = $0 { true } else { false } })
    }

    @Test func presetReplacesCustomChoiceInSchemaOrderAndUnspecifiedPreservesIt() throws {
        let deck = try Presentation()
        let table = try deck.slides[0].shapes.addTable(rows: 1, columns: 1, frame: frame)
        let cell = try table.cell(0, 0)
        cell.setBorder(.right, line: Line(color: .black))
        let border = try #require(cell.tcPr.firstChild(named: "a:lnR"))
        let custom = XML.Element("a:custDash", children: [.element(XML.Element("a:ds", attributes: [("d", "100000"), ("sp", "200000")]))])
        border.appendElement(custom)
        border.appendElement(XML.Element("a:miter", attributes: [("lim", "800000")]))
        border.appendElement(XML.Element("a:extLst", children: [.comment("keep")]))
        let customBefore = custom.serialized()
        cell.setBorder(.right, line: Line(color: .white))
        #expect(border.firstChild(named: "a:custDash")?.serialized() == customBefore)
        cell.setBorder(.right, line: Line(color: .black, dash: .solid))
        #expect(border.childElements.map(\.name) == ["a:solidFill", "a:prstDash", "a:miter", "a:extLst"])
        #expect(border.firstChild(named: "a:custDash") == nil)
        #expect(border.firstChild(named: "a:prstDash")?[attribute: "val"] == "solid")
    }

    @Test func unspecifiedNewLineAndUnsupportedPreviewContract() throws {
        let originalInitializer: (Color, EMU) -> Line = Line.init(color:width:)
        #expect(originalInitializer(.black, .points(1)) == Line(color: .black))
        let element = Line.makeElement(Line(color: .black))
        #expect(element[attribute: "cmpd"] == nil)
        #expect(element.firstChild(named: "a:prstDash") == nil)
        let deck = try Presentation()
        _ = try deck.slides[0].shapes.addShape(.rectangle, frame: frame, fill: .solid(.white),
            line: Line(color: .black, compound: .triple, dash: .largeDashDotDot))
        let before = try deck.serializedData()
        #expect(try deck.renderSVGReportingProblems(slideAt: 0).problems.fidelityIssues.contains { $0.code == .unsupportedBorder })
        #expect(throws: StrictRenderingError.self) { try deck.renderSVG(slideAt: 0, strictRendering: true) }
        #expect(try deck.serializedData() == before)
        let shape = try #require(deck.slides[0].shapes.all.first)
        shape.setLine(Line(color: .black, compound: .single, dash: .solid))
        #expect(try deck.renderSVGReportingProblems(slideAt: 0, strictRendering: true).problems.isEmpty)
        let copy = try Presentation(data: deck.serializedData())
        #expect(try copy.slides[0].shapes.all.first?.line?.compoundStyle == "sng")
        #expect(try copy.slides[0].shapes.all.first?.line?.dashStyle == "solid")
        #expect(try copy.renderSVGReportingProblems(slideAt: 0, strictRendering: true).problems.isEmpty)
    }
}
