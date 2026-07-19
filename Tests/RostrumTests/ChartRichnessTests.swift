import Foundation
import Testing
@testable import Rostrum

@Suite struct ChartRichnessTests {
    private var sample: ChartData {
        ChartData(categories: ["A", "B", "C"], name: "Series 1", values: [3, 2, 4])
    }

    private func chartDOM(_ shape: Shape, in deck: Presentation) throws -> XML.Element {
        // The graphic frame's c:chart r:id → the chart part.
        try deck.package.part(at: PackURI("/ppt/charts/chart1.xml")).dom()
    }

    @Test func customTitleSuppressesAutoTitle() throws {
        let deck = try Presentation()
        let s = try deck.slides[0].shapes.addChart(
            .barClustered, data: sample, frame: Rect(x: .zero, y: .zero, width: .inches(6), height: .inches(4)),
            options: ChartOptions(title: "Quarterly revenue"))
        let chart = try chartDOM(s, in: deck).firstChild(named: "c:chart")!
        // Title first, then autoTitleDeleted=0.
        #expect(chart.childElements.first?.name == "c:title")
        #expect(chart.firstChild(named: "c:title")?.textContent.contains("Quarterly revenue") == true)
        #expect(chart.firstChild(named: "c:autoTitleDeleted")?[attribute: "val"] == "0")
    }

    @Test func dataLabelsShowFlagsInOrder() throws {
        let deck = try Presentation()
        try deck.slides[0].shapes.addChart(
            .barClustered, data: sample, frame: Rect(x: .zero, y: .zero, width: .inches(6), height: .inches(4)),
            options: ChartOptions(dataLabels: DataLabelOptions(showValue: true, numberFormat: "#,##0")))
        let bar = try deck.package.part(at: PackURI("/ppt/charts/chart1.xml")).dom()
            .firstChild(named: "c:chart")!.firstChild(named: "c:plotArea")!.firstChild(named: "c:barChart")!
        let d = bar.firstChild(named: "c:dLbls")!
        #expect(d.firstChild(named: "c:numFmt")?[attribute: "formatCode"] == "#,##0")
        #expect(d.firstChild(named: "c:showVal")?[attribute: "val"] == "1")
        // show* flags are in the mandated sequence.
        let names = d.childElements.map(\.name)
        let order = ["c:showLegendKey", "c:showVal", "c:showCatName", "c:showSerName", "c:showPercent", "c:showBubbleSize"]
        let present = names.filter { order.contains($0) }
        #expect(present == order)
    }

    @Test func valueAxisMinMaxOrderAndTitle() throws {
        let deck = try Presentation()
        try deck.slides[0].shapes.addChart(
            .line, data: sample, frame: Rect(x: .zero, y: .zero, width: .inches(6), height: .inches(4)),
            options: ChartOptions(valueAxis: AxisOptions(min: 0, max: 10, majorUnit: 2, title: "Units")))
        let valAx = try deck.package.part(at: PackURI("/ppt/charts/chart1.xml")).dom()
            .firstChild(named: "c:chart")!.firstChild(named: "c:plotArea")!.firstChild(named: "c:valAx")!
        let scaling = valAx.firstChild(named: "c:scaling")!.childElements.map(\.name)
        // orientation, then max BEFORE min.
        #expect(scaling == ["c:orientation", "c:max", "c:min"])
        #expect(valAx.firstChild(named: "c:title")?.textContent.contains("Units") == true)
        #expect(valAx.firstChild(named: "c:majorUnit")?[attribute: "val"] == "2")
    }

    @Test func stackedBarHasOverlap() throws {
        let deck = try Presentation()
        let multi = ChartData(categories: ["A", "B"], series: [
            .init(name: "X", values: [1, 2]), .init(name: "Y", values: [3, 4]),
        ])
        try deck.slides[0].shapes.addChart(.barStacked, data: multi,
            frame: Rect(x: .zero, y: .zero, width: .inches(6), height: .inches(4)))
        let bar = try deck.package.part(at: PackURI("/ppt/charts/chart1.xml")).dom()
            .firstChild(named: "c:chart")!.firstChild(named: "c:plotArea")!.firstChild(named: "c:barChart")!
        #expect(bar.firstChild(named: "c:grouping")?[attribute: "val"] == "stacked")
        #expect(bar.firstChild(named: "c:overlap")?[attribute: "val"] == "100")
    }

    @Test func doughnutHasHoleNoAxes() throws {
        let deck = try Presentation()
        try deck.slides[0].shapes.addChart(.doughnut, data: sample,
            frame: Rect(x: .zero, y: .zero, width: .inches(5), height: .inches(5)))
        let plot = try deck.package.part(at: PackURI("/ppt/charts/chart1.xml")).dom()
            .firstChild(named: "c:chart")!.firstChild(named: "c:plotArea")!
        let d = plot.firstChild(named: "c:doughnutChart")!
        #expect(d.firstChild(named: "c:holeSize")?[attribute: "val"] == "50")
        #expect(plot.firstChild(named: "c:valAx") == nil)
    }

    @Test func scatterUsesXYValNoCat() throws {
        let deck = try Presentation()
        try deck.slides[0].shapes.addScatterChart(
            XYChartData(series: [.init(name: "cloud", points: [(1, 2), (3, 5), (4, 4)])]),
            frame: Rect(x: .zero, y: .zero, width: .inches(6), height: .inches(5)))
        let plot = try deck.package.part(at: PackURI("/ppt/charts/chart1.xml")).dom()
            .firstChild(named: "c:chart")!.firstChild(named: "c:plotArea")!
        let ser = plot.firstChild(named: "c:scatterChart")!.firstChild(named: "c:ser")!
        #expect(ser.firstChild(named: "c:xVal") != nil)
        #expect(ser.firstChild(named: "c:yVal") != nil)
        #expect(ser.firstChild(named: "c:cat") == nil)
        // Two value axes cross-referencing each other.
        let valAxes = plot.children(named: "c:valAx")
        #expect(valAxes.count == 2)
        // Workbook is a valid zip.
        let wb = try #require(deck.package.parts[PackURI("/ppt/embeddings/Microsoft_Excel_Sheet1.xlsx")])
        _ = try ZipReader(data: wb.blob)
    }

    @Test func everyKindProducesWellFormedChartAndOpens() throws {
        // A quick structural smoke test: each kind serializes, reparses, and
        // its externalData is the last child of chartSpace (schema order).
        let kinds: [ChartKind] = [.barClustered, .barStacked, .barPercentStacked, .line, .area, .pie, .doughnut]
        for kind in kinds {
            let deck = try Presentation()
            try deck.slides[0].shapes.addChart(kind, data: sample,
                frame: Rect(x: .zero, y: .zero, width: .inches(6), height: .inches(4)),
                options: ChartOptions(title: "T", legend: .bottom, dataLabels: DataLabelOptions(showValue: true)))
            let reopened = try Presentation(data: try deck.serializedData())
            let space = try reopened.package.part(at: PackURI("/ppt/charts/chart1.xml")).dom()
            #expect(space.childElements.last?.name == "c:externalData", "\(kind): externalData not last")
        }
    }
}
