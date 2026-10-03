import Foundation
import Testing
@testable import Rostrum

@Suite struct ChartWorkbookReaderTests {
    private let frame = Rect(x: .zero, y: .zero, width: .inches(8), height: .inches(4))
    private let data = ChartData(categories: ["A", "B", "C"], series: [.init(name: "Sales", values: [10, nil, 30])])

    private func fixture() throws -> (Presentation, Chart) {
        let deck = try Presentation()
        try deck.slides[0].shapes.addChart(.barClustered, data: data, frame: frame)
        return (deck, try #require(deck.charts.first))
    }
    private func removeCaches(_ chart: Chart) throws {
        var stack = [try chart.part.dom()]
        while let element = stack.popLast() {
            element.removeChildren(named: "c:strCache")
            element.removeChildren(named: "c:numCache")
            stack.append(contentsOf: element.childElements)
        }
        chart.part.markDirty()
    }

    @Test func absentCachesReadEmbeddedDataAndKeepDeckBytesUnchanged() throws {
        let (deck, chart) = try fixture()
        let cachedPreview = try deck.renderSVG(slideAt: 0)
        try removeCaches(chart)
        let before = try deck.serializedData()
        #expect(chart.categories == ["A", "B", "C"])
        #expect(chart.series[0].name == "Sales")
        #expect(chart.series[0].values == [10, nil, 30])
        #expect(chart.data != nil)
        #expect(try deck.serializedData() == before)
        #expect(try deck.renderSVG(slideAt: 0) == cachedPreview)
        #expect(chart.replacementProblem(for: data) != nil)
    }

    @Test func missingXYCachesReadAllNumericAxesAndLinkedTitle() throws {
        let deck = try Presentation()
        try deck.slides[0].shapes.addBubbleChart(BubbleChartData(series: [
            .init(name: "Markets", points: [.init(x: 1,y: 2,size: 10), .init(x: 3,y: 4,size: 20)])]), frame: frame)
        let chart = try #require(deck.charts.first)
        try removeCaches(chart)
        #expect(chart.xySeries[0].name == "Markets")
        #expect(chart.xySeries[0].points == [.init(x: 1,y: 2,size: 10), .init(x: 3,y: 4,size: 20)])
        let title = try XML.parse(Data("<c:title xmlns:c=\"http://schemas.openxmlformats.org/drawingml/2006/chart\"><c:tx><c:strRef><c:f>Sheet1!$C$1</c:f></c:strRef></c:tx></c:title>".utf8))
        let chartElement = try #require(chart.root?.firstChild(named: "c:chart"))
        chartElement.removeChildren(named: "c:title")
        chartElement.insertChild(title)
        chart.part.markDirty()
        #expect(chart.title == "Markets")
    }

    @Test func cachePresenceTakesPrecedenceEvenWhenEmptyOrSparse() throws {
        let (_, chart) = try fixture()
        let wrapper = try #require(chart.seriesElements[0].firstChild(named: "c:val"))
        let cache = try #require(Chart.numberCache(in: wrapper))
        cache.removeChildren(named: "c:pt")
        #expect(chart.series[0].values == [nil, nil, nil])
        cache.firstChild(named: "c:ptCount")?[attribute: "val"] = "0"
        #expect(chart.series[0].values.isEmpty)
    }

    @Test func replacingWorkbookBytesInvalidatesTheReadSnapshot() throws {
        let (_, chart) = try fixture()
        try removeCaches(chart)
        #expect(chart.series[0].values == [10, nil, 30])
        let workbook = try #require(chart.workbookPart)
        workbook.replaceBlob(try ChartWorkbook.make(data: ChartData(categories: ["X", "Y", "Z"], series: [.init(name: "Updated", values: [1,2,3])])))
        #expect(chart.categories == ["X", "Y", "Z"])
        #expect(chart.series[0].name == "Updated")
        #expect(chart.series[0].values == [1,2,3])
    }

    @Test func externalAndMalformedWorkbooksStayUnreadableWithoutFollowingLinks() throws {
        let (_, chart) = try fixture()
        try removeCaches(chart)
        let workbook = try #require(chart.workbookPart)
        workbook.replaceBlob(Data("not a workbook".utf8))
        #expect(chart.series[0].values.isEmpty)
        let id = try #require(chart.root?.firstChild(named: "c:externalData")?[attribute: "r:id"])
        let old = try #require(chart.part.rels.relationship(withId: id))
        chart.part.rels.remove(rId: id)
        chart.part.rels.add(rId: id, type: old.type, target: old.target, isExternal: true)
        #expect(chart.workbookPart == nil)
        #expect(chart.categories.isEmpty)
    }

    @Test func rangeParserRejectsUnsupportedAndUnboundedFormulas() {
        for formula in ["Sheet1!A1:B3", "Sheet1!B3:B1", "Sheet1!A1:A1048576", "Sheet1!XFE1", "Sheet1!A0",
                        "'[remote.xlsx]Sheet1'!A1", "SUM(Sheet1!A1)", "NamedRange", "Sheet1!A:A", "Sheet1!A1,Sheet1!A3"] {
            #expect(ChartWorkbookReader.Range(formula) == nil, "accepted unsupported formula: \(formula)")
        }
        let range = ChartWorkbookReader.Range("'O''Brien Data'!$B$2:$D$2")
        #expect(range?.sheet == "O'Brien Data")
        #expect(range?.count == 3)
    }

    @Test func readsHorizontalQuotedSheetRangesAndTypedCells() throws {
        let package = try OPCPackage.read(data: ChartWorkbook.make(data: data))
        let workbook = try package.mainDocumentPart()
        let root = try workbook.dom()
        root.firstChild(named: "sheets")?.firstChild(named: "sheet")?[attribute: "name"] = "O'Brien Data"
        workbook.markDirty()
        let sheet = try package.part(at: PackURI("/xl/worksheets/sheet1.xml"))
        sheet.replaceBlob(Data("""
        <s:worksheet xmlns:s="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><s:sheetData><s:row r="2">
        <s:c r="A2" t="inlineStr"><s:is><s:r><s:t>Inline </s:t></s:r><s:r><s:t>label</s:t></s:r><s:rPh><s:t>ignored</s:t></s:rPh></s:is></s:c>
        <s:c r="B2"><s:f>5+7</s:f><s:v>12</s:v></s:c>
        <s:c r="C2" t="e"><s:v>#DIV/0!</s:v></s:c>
        <s:c r="D2" t="s"><s:v>0</s:v></s:c>
        <s:c r="E2" t="n"><s:v>NaN</s:v></s:c>
        </s:row></s:sheetData></s:worksheet>
        """.utf8))
        let reader = try ChartWorkbookReader(data: package.serialize())
        let cells = try #require(reader.cells(for: "'O''Brien Data'!A2:E2"))
        #expect(cells[0]?.text == "Inline label")
        #expect(cells[1]?.number == 12)
        #expect(cells[2] == nil)
        #expect(cells[3]?.text == "A")
        #expect(cells[4] == nil)
        #expect(reader.cells(for: "Missing!A1") == nil)
    }
}
