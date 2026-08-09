import Foundation
import Testing
@testable import Rostrum

@Suite struct ChartTests {
    private var sample: ChartData {
        ChartData(categories: ["East", "West", "Midwest"], values: [19.2, 21.4, 16.7])
    }

    @Test func barChartCreatesPartsAndWiring() throws {
        let deck = try Presentation()
        try deck.slides[0].shapes.addChart(
            .barClustered, data: sample,
            frame: Rect(x: .inches(1), y: .inches(1), width: .inches(8), height: .inches(5)))

        let reopened = try Presentation(data: try deck.serializedData())
        let chartPart = try reopened.package.part(at: PackURI("/ppt/charts/chart1.xml"))
        #expect(chartPart.contentType == ContentType.chart)
        #expect(reopened.package.parts[PackURI("/ppt/embeddings/Microsoft_Excel_Sheet1.xlsx")] != nil)

        // Slide rel scope: graphicFrame r:id resolves to the chart part.
        let frame = try reopened.slides[0].spTree().firstChild(named: "p:graphicFrame")!
        let rId = frame.firstChild(named: "a:graphic")!
            .firstChild(named: "a:graphicData")!
            .firstChild(named: "c:chart")![attribute: "r:id"]!
        #expect(try reopened.slides[0].part.rels.relationship(withId: rId)?.type == RelType.chart)

        // Chart-part rel scope: rId1 → the workbook.
        #expect(chartPart.rels.relationship(withId: "rId1")?.type == RelType.package)

        // Structure: axes paired.
        let space = try chartPart.dom()
        let plotArea = space.firstChild(named: "c:chart")!.firstChild(named: "c:plotArea")!
        let bar = plotArea.firstChild(named: "c:barChart")!
        let axIds = bar.children(named: "c:axId").compactMap { $0[attribute: "val"] }
        let catAx = plotArea.firstChild(named: "c:catAx")!
        let valAx = plotArea.firstChild(named: "c:valAx")!
        #expect(axIds == [catAx.firstChild(named: "c:axId")![attribute: "val"],
                          valAx.firstChild(named: "c:axId")![attribute: "val"]])
        #expect(catAx.firstChild(named: "c:crossAx")![attribute: "val"] == axIds[1])
        #expect(valAx.firstChild(named: "c:crossAx")![attribute: "val"] == axIds[0])
        // externalData is the last child of chartSpace.
        #expect(space.childElements.last?.name == "c:externalData")
    }

    @Test func nonFiniteValuesAreRefusedBeforeAnythingIsWritten() throws {
        // `nan`/`inf` serialize as invalid xsd:double in `c:v`, which
        // PowerPoint answers with a repair prompt. Every write boundary
        // refuses instead — and refuses BEFORE creating any part, so a failed
        // add leaves the deck byte-identical to one that never tried.
        let deck = try Presentation()
        let frame = Rect(x: .inches(1), y: .inches(1), width: .inches(8), height: .inches(5))
        let before = try deck.serializedData()

        #expect(throws: RostrumError.self) {
            try deck.slides[0].shapes.addChart(
                .barClustered,
                data: ChartData(categories: ["A", "B"], values: [1.0, .nan]), frame: frame)
        }
        #expect(throws: RostrumError.self) {
            try deck.slides[0].shapes.addScatterChart(
                XYChartData(points: [(x: 1, y: .infinity)]), frame: frame)
        }
        #expect(throws: RostrumError.self) {
            try deck.slides[0].shapes.addBubbleChart(
                BubbleChartData(points: [.init(x: 1, y: 2, size: -.infinity)]), frame: frame)
        }
        #expect(throws: RostrumError.self) {
            try deck.slides[0].shapes.addChart(
                .line, data: ChartData(categories: ["A"], values: [1.0]), frame: frame,
                options: ChartOptions(valueAxis: AxisOptions(max: .nan)))
        }
        #expect(try deck.serializedData() == before)

        // A valid chart, then a refused replacement: the file keeps the old
        // numbers, exactly as `replaceData`'s never-corrupt contract promises.
        try deck.slides[0].shapes.addChart(
            .barClustered, data: ChartData(categories: ["A", "B"], values: [1, 2]), frame: frame)
        let written = try deck.serializedData()
        let chart = try #require(deck.charts.first)
        #expect(throws: RostrumError.self) {
            try chart.replaceData(ChartData(categories: ["A", "B"], values: [3, .nan]))
        }
        #expect(try deck.serializedData() == written)
    }

    @Test func cachesCarryData() throws {
        let deck = try Presentation()
        try deck.slides[0].shapes.addChart(
            .line,
            data: ChartData(categories: ["A", "B"], series: [
                .init(name: "S1", values: [1.5, 2.5]),
                .init(name: "S2 & Co", values: [3.0, nil]),
            ]),
            frame: Rect(x: .zero, y: .zero, width: .inches(6), height: .inches(4)))

        let space = try deck.package.part(at: PackURI("/ppt/charts/chart1.xml")).dom()
        let sers = space.firstChild(named: "c:chart")!
            .firstChild(named: "c:plotArea")!.firstChild(named: "c:lineChart")!
            .children(named: "c:ser")
        #expect(sers.count == 2)
        // Second series references column C and escapes its name.
        let tx2 = sers[1].firstChild(named: "c:tx")!.firstChild(named: "c:strRef")!
        #expect(tx2.firstChild(named: "c:f")!.textContent == "Sheet1!$C$1")
        #expect(tx2.firstChild(named: "c:strCache")!.textContent.contains("S2 & Co"))
        // The nil value drops its pt but ptCount stays 2.
        let cache2 = sers[1].firstChild(named: "c:val")!
            .firstChild(named: "c:numRef")!.firstChild(named: "c:numCache")!
        #expect(cache2.firstChild(named: "c:ptCount")![attribute: "val"] == "2")
        #expect(cache2.children(named: "c:pt").count == 1)
    }

    @Test func embeddedWorkbookIsValidZipWithExpectedCells() throws {
        let workbook = try ChartWorkbook.make(data: sample)
        let zip = try ZipReader(data: workbook)
        #expect(zip.contains("xl/workbook.xml") && zip.contains("xl/worksheets/sheet1.xml")
                && zip.contains("[Content_Types].xml") && zip.contains("xl/sharedStrings.xml"))
        let sheet = String(decoding: try zip.data(forEntry: "xl/worksheets/sheet1.xml"), as: UTF8.self)
        #expect(sheet.contains("<c r=\"B2\" s=\"1\"><v>19.2</v></c>"))
        let strings = String(decoding: try zip.data(forEntry: "xl/sharedStrings.xml"), as: UTF8.self)
        #expect(strings.contains("<si><t>Midwest</t></si>") && strings.contains("uniqueCount=\"4\""))
    }

    @Test func pieHasNoAxesAndVariedColors() throws {
        let deck = try Presentation()
        try deck.slides[0].shapes.addChart(
            .pie, data: sample,
            frame: Rect(x: .zero, y: .zero, width: .inches(5), height: .inches(5)),
            colors: [Color("FF6B5B"), Color("FFB454"), Color("18A999")])
        let space = try deck.package.part(at: PackURI("/ppt/charts/chart1.xml")).dom()
        let plotArea = space.firstChild(named: "c:chart")!.firstChild(named: "c:plotArea")!
        #expect(plotArea.firstChild(named: "c:catAx") == nil)
        let pie = plotArea.firstChild(named: "c:pieChart")!
        #expect(pie.firstChild(named: "c:varyColors")![attribute: "val"] == "1")
        #expect(pie.firstChild(named: "c:ser")!.children(named: "c:dPt").count == 3)
    }

    @Test func numberFormattingIsMinimal() {
        #expect(chartNumber(19.2) == "19.2")
        #expect(chartNumber(42) == "42")
        #expect(chartNumber(0.1 + 0.2) == "0.3")
        #expect(chartNumber(-1.55) == "-1.55")
    }
}
