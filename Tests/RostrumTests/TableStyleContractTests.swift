import Foundation
import Testing
@testable import Rostrum

@Suite struct TableStyleContractTests {
    @Test func tableSolidBorderAndGradientApplyAlphaOnce() throws {
        let deck = try Presentation()
        let table = try deck.slides[0].shapes.addTable(rows: 1, columns: 2,
            frame: Rect(x: .zero, y: .zero, width: .points(200), height: .points(100)))
        table.clearBuiltInStyle()
        let translucent = "<a:srgbClr val=\"FF0000\"><a:alpha val=\"50000\"/></a:srgbClr>"
        let left = try table.cell(0, 0).tcPr
        left.appendElement(try XML.parse(Data("<a:solidFill>\(translucent)</a:solidFill>".utf8)))
        left.appendElement(try XML.parse(Data("<a:lnL w=\"12700\"><a:solidFill>\(translucent)</a:solidFill></a:lnL>".utf8)))
        try table.cell(0, 1).tcPr.appendElement(XML.parse(Data("<a:gradFill><a:gsLst><a:gs pos=\"0\">\(translucent)</a:gs><a:gs pos=\"100000\">\(translucent)</a:gs></a:gsLst><a:lin ang=\"0\"/></a:gradFill>".utf8)))
        let svg = try deck.renderSVG(slideAt: 0)
        #expect(svg.contains("fill=\"rgba(255,0,0,0.5)\""))
        #expect(svg.contains("stroke=\"rgba(255,0,0,0.5)\""))
        #expect(svg.contains("stop-color=\"rgba(255,0,0,0.5)\""))
        #expect(!svg.contains("fill-opacity="))
        #expect(!svg.contains("stroke-opacity="))
        #expect(!svg.contains("stop-opacity="))
    }
    private let styleXML = """
    <a:tblStyle xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" styleId="{11111111-2222-3333-4444-555555555555}" styleName="Contract">
      <a:wholeTbl><a:tcTxStyle b="on"><a:schemeClr val="tx1"/></a:tcTxStyle><a:tcStyle>
        <a:tcBdr><a:left><a:ln w="25400"><a:solidFill><a:schemeClr val="accent1"/></a:solidFill></a:ln></a:left><a:insideV><a:ln w="12700"><a:solidFill><a:srgbClr val="111111"/></a:solidFill></a:ln></a:insideV></a:tcBdr>
        <a:fill><a:solidFill><a:schemeClr val="accent1"><a:tint val="50000"/></a:schemeClr></a:solidFill></a:fill>
      </a:tcStyle></a:wholeTbl>
      <a:band1V><a:tcStyle><a:fill><a:solidFill><a:srgbClr val="222222"/></a:solidFill></a:fill></a:tcStyle></a:band1V>
      <a:band2V><a:tcStyle><a:fill><a:solidFill><a:srgbClr val="333333"/></a:solidFill></a:fill></a:tcStyle></a:band2V>
      <a:firstRow><a:tcStyle><a:fill><a:solidFill><a:srgbClr val="444444"/></a:solidFill></a:fill></a:tcStyle></a:firstRow>
      <a:firstCol><a:tcStyle><a:fill><a:solidFill><a:srgbClr val="555555"/></a:solidFill></a:fill></a:tcStyle></a:firstCol>
      <a:nwCell><a:tcStyle><a:fill><a:solidFill><a:srgbClr val="666666"/></a:solidFill></a:fill></a:tcStyle></a:nwCell>
      <a:extLst><!--preserve imported style extension--></a:extLst>
    </a:tblStyle>
    """

    private func make() throws -> (Presentation, Table) {
        let deck = try Presentation()
        let table = try deck.slides[0].shapes.addTable(rows: 3, columns: 3,
            frame: Rect(x: EMU(0), y: EMU(0), width: EMU(3000000), height: EMU(1500000)))
        table.clearBuiltInStyle()
        try table.setStyleDefinition(XML.parse(Data(styleXML.utf8)))
        return (deck, table)
    }
    private func color(_ fill: ReadFill?) -> Color? {
        if case .solid(let color, _) = fill { return color }; return nil
    }

    @Test func regionsThemeEditsExplicitOverridesAndStyleImportRoundTrip() throws {
        let (deck, table) = try make()
        deck.theme.setAccent(1, Color("000000"))
        table.firstRowHeader = true
        table.firstColumnHeader = true
        table.bandedColumns = true
        var resolver = TableStyleResolver(table: table, theme: deck.theme)
        #expect(resolver.hasStyleDefinition)
        #expect(color(try resolver.fill(row: 0, column: 0)) == Color("666666"))
        #expect(color(try resolver.fill(row: 0, column: 1)) == Color("444444"))
        #expect(color(try resolver.fill(row: 1, column: 0)) == Color("555555"))
        #expect(color(try resolver.fill(row: 1, column: 1)) == Color("222222"))
        #expect(color(try resolver.fill(row: 1, column: 2)) == Color("333333"))
        table.bandedColumns = false
        resolver = TableStyleResolver(table: table, theme: deck.theme)
        #expect(color(try resolver.fill(row: 2, column: 2)) == Color("808080"))
        deck.theme.setAccent(1, Color("FF0000"))
        resolver = TableStyleResolver(table: table, theme: deck.theme)
        #expect(color(try resolver.fill(row: 2, column: 2)) == Color("FF8080"))
        try table.cell(2, 2).setFill(.none)
        try table.cell(1, 0).setBorder(.left, line: nil)
        resolver = TableStyleResolver(table: table, theme: deck.theme)
        #expect(try resolver.fill(row: 2, column: 2) == .noFill)
        #expect(try resolver.border(.left, row: 1, column: 0)?.isNone == true)
        let reopened = try Presentation(data: deck.serializedData())
        let frame = try #require(reopened.slides[0].shapes.all.first as? TableFrame)
        let copied = try #require(frame.table)
        let copiedResolver = TableStyleResolver(table: copied, theme: reopened.theme)
        #expect(try copiedResolver.fill(row: 2, column: 2) == .noFill)
        #expect(color(try copiedResolver.fill(row: 1, column: 1)) == Color("FF8080"))
        let source = try #require(TableStyleResolver.definition(for: copied.tbl, package: copied.package).0)
        #expect(source.serialized().contains("preserve imported style extension"))
        let destination = try Presentation()
        let destTable = try destination.slides[0].shapes.addTable(rows: 1, columns: 1,
            frame: Rect(x: EMU(0), y: EMU(0), width: EMU(1000000), height: EMU(1000000)))
        try destTable.setStyleDefinition(source)
        let imported = try Presentation(data: destination.serializedData())
        let importedTable = try #require((imported.slides[0].shapes.all.first as? TableFrame)?.table)
        #expect(TableStyleResolver(table: importedTable, theme: imported.theme).hasStyleDefinition)
    }

    @Test func tableBackgroundShowsThroughAnExplicitNoFillCell() throws {
        let (deck, table) = try make()
        let fill = XML.Element("a:solidFill", children: [.element(Color("FEDCBA").srgbElement())])
        table.tbl.firstChild(named: "a:tblPr")?.insertChild(fill, beforeAnyOf: ["a:tableStyleId"])
        try table.cell(0, 0).setFill(.none)
        let before = table.tbl.serialized()
        let svg = try deck.renderSVG(slideAt: 0)
        #expect(svg.contains("width=\"3000000\" height=\"1500000\" fill=\"#FEDCBA\""))
        #expect(table.tbl.serialized() == before)
        let reopened = try Presentation(data: deck.serializedData())
        #expect(try reopened.renderSVG(slideAt: 0) == svg)
    }

    @Test func nativeStyleWithoutDefinitionIsReportedAndPreserved() throws {
        let (deck, table) = try make()
        table.styleID = "{99999999-8888-7777-6666-555555555555}"
        #expect(!TableStyleResolver(table: table, theme: deck.theme).hasStyleDefinition)
        let reopened = try Presentation(data: deck.serializedData())
        let copied = try #require((reopened.slides[0].shapes.all.first as? TableFrame)?.table)
        #expect(copied.styleID == "{99999999-8888-7777-6666-555555555555}")
    }

    @Test func customStyleWithUnresolvedRelationshipIsAtomic() throws {
        let (deck, table) = try make()
        let before = try deck.serializedData()
        let style = try XML.parse(Data(styleXML.utf8))
        style[attribute: "r:embed"] = "rIdForeign"
        #expect(throws: RostrumError.self) { try table.setStyleDefinition(style) }
        #expect(try deck.serializedData() == before)
    }

    @Test func imageAndGradientCellFillsRenderAndReopen() throws {
        let (deck, table) = try make()
        let png = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==")!
        try table.cell(0, 0).setFill(.image(png, fit: .stretch))
        try table.cell(0, 1).setFill(.gradient(GradientFill(from: .black, to: .white, angleDegrees: 0)))
        let svg = try deck.renderSVG(slideAt: 0)
        #expect(svg.contains("data:image/png;base64,"))
        #expect(svg.contains("<linearGradient"))
        #expect(svg.contains("stop-color=\"#000000\""))
        #expect(!svg.contains("#DDDDDD"))
        let reopened = try Presentation(data: deck.serializedData())
        #expect(try reopened.renderSVG(slideAt: 0) == svg)
        let copied = try #require((reopened.slides[0].shapes.all.first as? TableFrame)?.table)
        #expect(try copied.cell(0, 0).fill != nil)
        try copied.cell(1, 1).setFill(.image(png))
        #expect(reopened.package.parts.keys.filter { $0.value.hasPrefix("/ppt/media/") }.count == 1)
    }
}
