import Foundation
import Testing
@testable import Rostrum

@Suite struct ChartCacheRepairTests {
    private let frame = Rect(x: .inches(1), y: .inches(1), width: .inches(8), height: .inches(4))
    private let data = ChartData(categories: ["A", "B", "C"], series: [.init(name: "Sales", values: [10, nil, 30])])

    private func fixture() throws -> (Presentation, Chart) {
        let deck = try Presentation()
        try deck.slides[0].shapes.addChart(.barClustered, data: data, frame: frame)
        let chart = try #require(deck.charts.first)
        try strip(chart)
        return (deck, chart)
    }
    private func strip(_ chart: Chart) throws {
        var stack = [try chart.part.dom()]
        while let node = stack.popLast() {
            node.removeChildren(named: "c:strCache"); node.removeChildren(named: "c:numCache")
            stack += node.childElements
        }
        chart.part.markDirty()
    }
    private func reference(_ chart: Chart, wrapper: String = "c:val", kind: String = "c:numRef") throws -> XML.Element {
        try #require(chart.seriesElements.first?.firstChild(named: wrapper)?.firstChild(named: kind))
    }
    private func editWorkbook(_ chart: Chart, uri: String = "/xl/worksheets/sheet1.xml",
                              _ transform: (String) -> String) throws {
        let part = try #require(chart.workbookPart)
        let package = try OPCPackage.read(data: part.blob)
        let target = try package.part(at: PackURI(uri))
        let original = String(decoding: target.blob, as: UTF8.self)
        let changed = transform(original)
        #expect(changed != original, "Workbook fixture edit must change its input")
        target.replaceBlob(Data(changed.utf8))
        part.replaceBlob(try package.serialize())
    }
    private func expectAtomicRefusal(_ deck: Presentation, _ chart: Chart) throws {
        let before = try deck.serializedData()
        let xml = try chart.part.dom().serialized()
        #expect(throws: (any Error).self) { try chart.rebuildMissingCachesFromWorkbook() }
        #expect(try chart.part.dom().serialized() == xml)
        #expect(try deck.serializedData() == before)
        #expect(!chart.part.isDirty)
    }

    @Test func explicitRepairAddsCachesAndOnlyChangesTheChartPart() throws {
        let (deck, chart) = try fixture()
        try deck.slides[0].setNotes("Keep these exact notes.")
        try deck.setSections([("Chart evidence", 0)])
        let preview = try deck.renderSVG(slideAt: 0)
        let before = try deck.serializedData()
        #expect(try Presentation(data: before).serializedData() == before) // no implicit repair
        let report = try chart.rebuildMissingCachesFromWorkbook()
        #expect(report.map(\.formula) == ["Sheet1!$B$1", "Sheet1!$A$2:$A$4", "Sheet1!$B$2:$B$4"])
        #expect(report.map(\.pointCount) == [1, 3, 3])
        #expect(report.map(\.numeric) == [false, false, true])
        let cache = try #require(reference(chart).firstChild(named: "c:numCache"))
        #expect(cache.firstChild(named: "c:formatCode")?.textContent == "General")
        #expect(cache.firstChild(named: "c:ptCount")?[attribute: "val"] == "3")
        #expect(cache.children(named: "c:pt").map { $0[attribute: "idx"] } == ["0", "2"])
        #expect(cache.children(named: "c:pt").map { $0.firstChild(named: "c:v")?.textContent } == ["10", "30"])
        let after = try deck.serializedData()
        let old = try ZipReader(data: before), new = try ZipReader(data: after)
        let changed = try Set(old.entryNames).union(new.entryNames).filter { try old.data(forEntry: $0) != new.data(forEntry: $0) }
        #expect(changed == ["ppt/charts/chart1.xml"])
        #expect(try deck.renderSVG(slideAt: 0) == preview)
        let saved = try Presentation(data: after)
        #expect(saved.charts[0].categories == ["A", "B", "C"])
        #expect(saved.charts[0].series[0].values == [10, nil, 30])
        #expect(saved.charts[0].series[0].name == "Sales")
        #expect(try saved.validate().isEmpty)
        #expect(try saved.charts[0].rebuildMissingCachesFromWorkbook().isEmpty)
        #expect(try saved.serializedData() == after)
    }

    @Test func existingEmptyCachesAreAuthoritativeAndNeedNoWorkbook() throws {
        let (deck, chart) = try fixture()
        let empty = XML.Element("c:numCache")
        empty.appendElement(XML.Element("c:ptCount", attributes: [("val", "0")]))
        try reference(chart).appendElement(empty)
        chart.part.markDirty()
        let original = empty.serialized()
        #expect(try chart.rebuildMissingCachesFromWorkbook().count == 2)
        #expect(empty.serialized() == original)
        #expect(chart.series[0].values.isEmpty)
        chart.workbookPart?.replaceBlob(Data("broken workbook".utf8))
        let before = try deck.serializedData()
        #expect(try chart.rebuildMissingCachesFromWorkbook().isEmpty)
        #expect(try deck.serializedData() == before)
    }

    @Test func freshOperationReadsReplacedWorkbookWithoutOverwritingExistingCaches() throws {
        let (_, chart) = try fixture()
        try chart.rebuildMissingCachesFromWorkbook()
        try reference(chart).removeChildren(named: "c:numCache")
        chart.part.markDirty()
        chart.workbookPart?.replaceBlob(try ChartWorkbook.make(data: ChartData(categories: ["X", "Y", "Z"],
            series: [.init(name: "Changed", values: [1, 2, 3])])))
        #expect(try chart.rebuildMissingCachesFromWorkbook().count == 1)
        #expect(chart.categories == ["A", "B", "C"])
        #expect(chart.series[0].name == "Sales")
        #expect(chart.series[0].values == [1, 2, 3])
    }

    @Test func linkedTitlesXYAndBubbleAxesUseTheirOwnReferences() throws {
        let deck = try Presentation()
        try deck.slides[0].shapes.addBubbleChart(.init(series: [.init(name: "Markets", points: [
            .init(x: 1, y: 2, size: 10), .init(x: 3, y: 4, size: 20)])]), frame: frame)
        let chart = try #require(deck.charts.first)
        try strip(chart)
        let title = try XML.parse(Data("<c:title><c:tx><c:strRef><c:f>Sheet1!$C$1</c:f></c:strRef></c:tx></c:title>".utf8))
        let native = try #require(chart.root?.firstChild(named: "c:chart"))
        native.removeChildren(named: "c:title"); native.insertChild(title); chart.part.markDirty()
        let preview = try deck.renderSVG(slideAt: 0)
        #expect(try chart.rebuildMissingCachesFromWorkbook().count == 5)
        #expect(chart.title == "Markets")
        #expect(chart.xySeries[0].points == [.init(x: 1,y: 2,size: 10), .init(x: 3,y: 4,size: 20)])
        #expect(try deck.renderSVG(slideAt: 0) == preview)
        #expect(try deck.validate().isEmpty)
    }

    @Test func horizontalQuotedRangesRichStringsAndStoredFormulaResults() throws {
        let (_, chart) = try fixture()
        try editWorkbook(chart, uri: "/xl/workbook.xml") { $0.replacingOccurrences(of: "name=\"Sheet1\"", with: "name=\"O'Brien Data\"") }
        try editWorkbook(chart) { _ in """
        <s:worksheet xmlns:s="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><s:sheetData>
        <s:row r="1"><s:c r="B1" t="inlineStr"><s:is><s:r><s:t>Rich </s:t></s:r><s:r><s:t>name</s:t></s:r></s:is></s:c></s:row>
        <s:row r="2"><s:c r="A2" t="str"><s:v>One</s:v></s:c><s:c r="B2"><s:f>2+5</s:f><s:v>7</s:v></s:c><s:c r="C2"><s:v>9</s:v></s:c></s:row>
        <s:row r="3"><s:c r="A3" t="str"><s:v>Two</s:v></s:c></s:row></s:sheetData></s:worksheet>
        """ }
        for (wrapper, kind, formula) in [("c:tx", "c:strRef", "'O''Brien Data'!$B$1"),
                                         ("c:cat", "c:strRef", "'O''Brien Data'!$A$2:$A$3"),
                                         ("c:val", "c:numRef", "'O''Brien Data'!$B$2:$C$2")] {
            try reference(chart, wrapper: wrapper, kind: kind).firstChild(named: "c:f")?.children = [.text(formula)]
        }
        chart.part.markDirty()
        try chart.rebuildMissingCachesFromWorkbook()
        #expect(chart.series[0].name == "Rich name")
        #expect(chart.categories == ["One", "Two"])
        #expect(chart.series[0].values == [7, 9])
    }

    @Test func booleanLabelsBlankIndicesAndCustomErrorValues() throws {
        let (deck, chart) = try fixture()
        try editWorkbook(chart) { _ in """
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>
        <row r="1"><c r="B1" t="str"><v>Flags</v></c></row>
        <row r="2"><c r="A2" t="b"><v>1</v></c><c r="B2"><v>10</v></c></row>
        <row r="4"><c r="A4" t="b"><v>0</v></c><c r="B4"><v>30</v></c></row>
        </sheetData></worksheet>
        """ }
        let errors = try XML.parse(Data("""
        <c:errBars><c:errDir val="y"/><c:errBarType val="plus"/><c:errValType val="cust"/>
        <c:plus><c:numRef><c:f>Sheet1!B2:B4</c:f></c:numRef></c:plus></c:errBars>
        """.utf8))
        chart.seriesElements[0].insertChild(errors); chart.part.markDirty()
        #expect(try chart.rebuildMissingCachesFromWorkbook().count == 4)
        let saved = try Presentation(data: deck.serializedData()).charts[0]
        #expect(saved.categories == ["TRUE", "", "FALSE"])
        #expect(saved.series[0].name == "Flags")
        let custom = try #require(saved.seriesElements[0].firstChild(named: "c:errBars")?
            .firstChild(named: "c:plus")?.firstChild(named: "c:numRef")?.firstChild(named: "c:numCache"))
        #expect(custom.children(named: "c:pt").map { $0[attribute: "idx"] } == ["0", "2"])
        #expect(custom.children(named: "c:pt").map { $0.firstChild(named: "c:v")?.textContent } == ["10", "30"])
    }

    @Test(arguments: ["NamedRange", "[remote.xlsx]Sheet1!A1", "SUM(Sheet1!A1)", "Sheet1!A1:B2", "Missing!A1"])
    func unsupportedReferencesRefuseAtomically(formula: String) throws {
        let (deck, chart) = try fixture()
        try reference(chart).firstChild(named: "c:f")?.children = [.text(formula)]
        chart.part.markDirty()
        try expectAtomicRefusal(deck, chart)
    }

    @Test(arguments: ["nan", "hex", "error", "no-formula-result", "duplicate-cell", "wrong-namespace", "bad-string", "format", "merged", "duplicate-sheet", "broken-zip"])
    func malformedOrUnsupportedWorkbookRefusesAtomically(variant: String) throws {
        let (deck, chart) = try fixture()
        switch variant {
        case "nan": try editWorkbook(chart) { $0.replacingOccurrences(of: "<v>30</v>", with: "<v>NaN</v>") }
        case "hex": try editWorkbook(chart) { $0.replacingOccurrences(of: "<v>30</v>", with: "<v>0x1p2</v>") }
        case "error": try editWorkbook(chart) { $0.replacingOccurrences(of: "<c r=\"B4\" s=\"1\"><v>30</v></c>", with: "<c r=\"B4\" t=\"e\"><v>#DIV/0!</v></c>") }
        case "no-formula-result": try editWorkbook(chart) { $0.replacingOccurrences(of: "<v>30</v>", with: "<f>30+1</f>") }
        case "duplicate-cell": try editWorkbook(chart) { $0.replacingOccurrences(of: "<c r=\"B4\" s=\"1\"><v>30</v></c>", with: "<c r=\"B4\" s=\"1\"><v>30</v></c><c r=\"B4\"><v>31</v></c>") }
        case "wrong-namespace": try editWorkbook(chart) { $0.replacingOccurrences(of: "<v>30</v>", with: "<v xmlns=\"urn:wrong\">30</v>") }
        case "bad-string": try editWorkbook(chart) { $0.replacingOccurrences(of: "<v>0</v>", with: "<v>99999</v>") }
        case "format": try editWorkbook(chart, uri: "/xl/styles.xml") { $0.replacingOccurrences(of: "numFmtId=\"0\"", with: "numFmtId=\"14\"") }
        case "merged": try editWorkbook(chart) { $0.replacingOccurrences(of: "</worksheet>", with: "<mergeCells><mergeCell ref=\"B2:B3\"/></mergeCells></worksheet>") }
        case "duplicate-sheet": try editWorkbook(chart, uri: "/xl/workbook.xml") { $0.replacingOccurrences(of: "</sheets>", with: "<sheet name=\"sheet1\" sheetId=\"2\" r:id=\"rId1\"/></sheets>") }
        default: chart.workbookPart?.replaceBlob(Data("not a zip".utf8))
        }
        try expectAtomicRefusal(deck, chart)
    }

    @Test(arguments: ["multilevel", "conditional", "two-formulas", "foreign-formula"])
    func ambiguousChartReferencesRefuseAtomically(variant: String) throws {
        let (deck, chart) = try fixture()
        let ref = try reference(chart)
        switch variant {
        case "multilevel":
            let category = try #require(chart.seriesElements[0].firstChild(named: "c:cat"))
            category.removeChildren(named: "c:strRef")
            category.appendElement(XML.Element("c:multiLvlStrRef"))
        case "conditional":
            try chart.part.dom().appendElement(XML.Element("mc:AlternateContent", attributes: [
                ("xmlns:mc", "http://schemas.openxmlformats.org/markup-compatibility/2006")]))
        case "two-formulas":
            let extra = XML.Element("c:f"); extra.append(.text("Sheet1!B2")); ref.appendElement(extra)
        default:
            try #require(ref.firstChild(named: "c:f"))[attribute: "xmlns:c"] = "urn:foreign"
        }
        chart.part.markDirty()
        try expectAtomicRefusal(deck, chart)
    }

    @Test func namespaceAliasesAndExtensionsArePreserved() throws {
        let (deck, chart) = try fixture()
        let ref = try reference(chart)
        let ext = XML.Element("c:extLst")
        ext.appendElement(try XML.parse(Data("<v:opaque xmlns:v=\"urn:vendor\">keep me</v:opaque>".utf8)))
        // Extension-owned references are opaque even when their prefix matches.
        ext.appendElement(try XML.parse(Data("<c:numRef><c:f>UnsupportedName</c:f></c:numRef>".utf8)))
        ref.append(.comment("keep this comment")); ref.appendElement(ext); chart.part.markDirty()
        var xml = try chart.part.dom().serialized()
        xml = xml.replacingOccurrences(of: "xmlns:c=", with: "xmlns:q=").replacingOccurrences(of: "<c:", with: "<q:").replacingOccurrences(of: "</c:", with: "</q:")
        chart.part.replaceBlob(Data(xml.utf8))
        try chart.rebuildMissingCachesFromWorkbook()
        let result = try chart.part.dom().serialized()
        #expect(result.contains("keep this comment"))
        #expect(result.contains("keep me"))
        #expect(result.contains("</c:numCache><q:extLst>"))
        #expect(try Presentation(data: deck.serializedData()).serializedData() == deck.serializedData())
    }

    @Test func externalWorkbookAndTotalPointBudgetRefuseAtomically() throws {
        let (deck, chart) = try fixture()
        let relation = try #require(chart.part.rels.first(ofType: RelType.package))
        chart.part.rels.remove(rId: relation.rId)
        chart.part.rels.add(rId: relation.rId, type: relation.type, target: "https://example.invalid/data.xlsx", isExternal: true)
        try expectAtomicRefusal(deck, chart)
        chart.part.rels.remove(rId: relation.rId)
        chart.part.rels.add(rId: relation.rId, type: relation.type, target: relation.target)
        try reference(chart).firstChild(named: "c:f")?.children = [.text("Sheet1!B2:B100001")]
        chart.part.markDirty()
        let before = try deck.serializedData()
        #expect(throws: Chart.CacheRepairProblem.limitExceeded) { try chart.rebuildMissingCachesFromWorkbook() }
        #expect(try deck.serializedData() == before)
    }
}
