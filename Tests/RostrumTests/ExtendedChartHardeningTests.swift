import Foundation
import Testing
@testable import Rostrum

@Suite struct ExtendedChartHardeningTests {
    @Test func duplicateDataIdsNeverTrapAcrossSeriesOutlineAndSVG() throws {
        let deck = try Presentation()
        let slide = try deck.slides[0]
        _ = try slide.shapes.addExtendedChart(
            .funnel,
            data: ChartData(categories: ["Stage 1", "Stage 2"], series: [
                .init(name: "Leads", values: [500, 120]),
                .init(name: "Closed", values: [80, 40]),
            ]),
            frame: Rect(x: .inches(1), y: .inches(1), width: .inches(5), height: .inches(3))
        )
        let chart = try #require(deck.extendedCharts.first)
        // Force duplicate cx:data@id="0" as seen in malformed foreign chartEx parts.
        for dataEl in chart.dataElements {
            dataEl[attribute: "id"] = "0"
        }
        chart.part.markDirty()

        let reopened = try Presentation(data: deck.serializedData())
        let reChart = try #require(reopened.extendedCharts.first)
        #expect(reChart.series.count == 2)
        #expect(reChart.series[0].values == [500, 120])

        let outline = reopened.outline()
        #expect(outline.slides[0].charts.count == 1)
        let svg = try reopened.renderSVG(slideAt: 0)
        #expect(svg.contains("<svg"))
    }

    @Test func replaceDataHonorsDataIdMappingUpdatesFormulasAndPrunesOutOfBoundsSubtotals() throws {
        let deck = try Presentation()
        let slide = try deck.slides[0]
        _ = try slide.shapes.addExtendedChart(
            .waterfall,
            data: ChartData(categories: ["Q1", "Q2", "Q3", "Total"], series: [
                .init(name: "Primary", values: [100, 30, -10, 120]),
                .init(name: "Comparison", values: [90, 20, -5, 105]),
            ]),
            frame: Rect(x: .inches(1), y: .inches(1), width: .inches(6), height: .inches(3.5)),
            subtotals: [1, 3]
        )
        let chart = try #require(deck.extendedCharts.first)
        // Swap cx:dataId so series 0 points at data id="1" and series 1 points at data id="0".
        chart.seriesElements[0].firstChild(named: "cx:dataId")?[attribute: "val"] = "1"
        chart.seriesElements[1].firstChild(named: "cx:dataId")?[attribute: "val"] = "0"

        // Series-count mismatch, post-init empty categories, or mismatched series length throw atomically without mutating.
        #expect(throws: Chart.ReplacementProblem.self) {
            try chart.replaceData(ChartData(categories: ["A", "B"], name: "OnlyOne", values: [1, 2]))
        }
        var badEmpty = ChartData(categories: ["A"], series: [
            .init(name: "Primary", values: [1]),
            .init(name: "Comparison", values: [2]),
        ])
        badEmpty.categories = []
        #expect(throws: Chart.ReplacementProblem.self) {
            try chart.replaceData(badEmpty)
        }
        var badMismatch = ChartData(categories: ["A", "B"], series: [
            .init(name: "Primary", values: [1, 2]),
            .init(name: "Comparison", values: [3, 4]),
        ])
        badMismatch.series[1].values = [3]
        #expect(throws: Chart.ReplacementProblem.self) {
            try chart.replaceData(badMismatch)
        }

        // Valid 3-category replacement updates mapped cx:data elements, rewrites cx:f to $4, and drops subtotal idx 3.
        try chart.replaceData(ChartData(categories: ["Jan", "Feb", "QTD"], series: [
            .init(name: "Net Flow", values: [40, 15, 55]),
            .init(name: "Prior Year", values: [35, 10, 45]),
        ]))

        #expect(chart.categories == ["Jan", "Feb", "QTD"])
        #expect(chart.series[0].name == "Net Flow")
        #expect(chart.series[0].values == [40, 15, 55])
        #expect(chart.series[1].name == "Prior Year")
        #expect(chart.series[1].values == [35, 10, 45])
        #expect(chart.subtotalIndices == [1])

        // Series 0 mapped to dataElements[1] (id="1") gets Sheet1!$B$2:$B$4; Series 1 mapped to dataElements[0] gets Sheet1!$C$2:$C$4.
        let data1 = chart.dataElements[1]
        let data0 = chart.dataElements[0]
        #expect(data1.firstChild(named: "cx:strDim")?.firstChild(named: "cx:f")?.textContent == "Sheet1!$A$2:$A$4")
        #expect(data1.firstChild(named: "cx:numDim")?.firstChild(named: "cx:f")?.textContent == "Sheet1!$B$2:$B$4")
        #expect(data0.firstChild(named: "cx:numDim")?.firstChild(named: "cx:f")?.textContent == "Sheet1!$C$2:$C$4")

        let wbPart = try #require(chart.workbookPart)
        let wbBytes = try wbPart.decodedData()
        let wbReader = try ChartWorkbookReader(data: wbBytes)
        #expect(wbReader.cells(for: "Sheet1!$A$2:$A$4")?.compactMap { $0?.text } == ["Jan", "Feb", "QTD"])
        #expect(wbReader.cells(for: "Sheet1!$B$2:$B$4")?.compactMap { $0?.number } == [40, 15, 55])
        #expect(wbReader.cells(for: "Sheet1!$C$2:$C$4")?.compactMap { $0?.number } == [35, 10, 45])
    }

    @Test func replaceDataRefusesForeignWorkbookFormulaLayoutWithoutMutating() throws {
        let deck = try Presentation()
        let slide = try deck.slides[0]
        _ = try slide.shapes.addExtendedChart(
            .treemap,
            data: ChartData(categories: ["A", "B"], name: "Share", values: [60, 40]),
            frame: Rect(x: .inches(1), y: .inches(1), width: .inches(4), height: .inches(3))
        )
        let chart = try #require(deck.extendedCharts.first)
        chart.dataElements[0].firstChild(named: "cx:numDim")?.firstChild(named: "cx:f")?.children = [.text("CustomTab!$D$5:$D$6")]

        #expect(throws: Chart.ReplacementProblem.self) {
            try chart.replaceData(ChartData(categories: ["A", "B"], name: "Share", values: [70, 30]))
        }
        #expect(chart.series[0].values == [60, 40])
    }

    @Test func replaceDataCleansDuplicateIdShadowsPreservesWorkbooklessFormulasAndRefusesMultiLevelCategories() throws {
        let deck = try Presentation()
        let slide = try deck.slides[0]
        _ = try slide.shapes.addExtendedChart(
            .funnel,
            data: ChartData(categories: ["OldA", "OldB"], name: "Count", values: [10, 20]),
            frame: Rect(x: .inches(1), y: .inches(1), width: .inches(4), height: .inches(3))
        )
        let chart = try #require(deck.extendedCharts.first)
        let chartDataEl = try #require(chart.root?.firstChild(named: "cx:chartData"))

        // Remove embedded workbook link and set a custom external formula on cx:numDim;
        // also append a duplicate <cx:data id="0"> shadow with stale values.
        chartDataEl.removeChildren(named: "cx:externalData")
        #expect(chart.workbookPart == nil)
        chart.dataElements[0].firstChild(named: "cx:numDim")?.firstChild(named: "cx:f")?.children = [.text("ExternalBook!$Z$10:$Z$11")]
        let shadow = chart.dataElements[0].deepCopy()
        chartDataEl.appendElement(shadow)
        #expect(chart.dataElements.count == 2)

        try chart.replaceData(ChartData(categories: ["NewA", "NewB", "NewC"], name: "Updated", values: [1, 2, 3]))
        #expect(chart.dataElements.count == 1)
        #expect(chart.categories == ["NewA", "NewB", "NewC"])
        #expect(chart.series[0].values == [1, 2, 3])
        #expect(chart.dataElements[0].firstChild(named: "cx:numDim")?.firstChild(named: "cx:f")?.textContent == "ExternalBook!$Z$10:$Z$11")

        // Multi-level cx:strDim (e.g. hierarchical sunburst categories) is refused without mutating.
        let strDim = try #require(chart.dataElements[0].firstChild(named: "cx:strDim"))
        strDim.appendElement(XML.Element("cx:lvl", attributes: [("ptCount", "3")]))
        #expect(throws: Chart.ReplacementProblem.self) {
            try chart.replaceData(ChartData(categories: ["X", "Y", "Z"], name: "Updated", values: [4, 5, 6]))
        }
        #expect(chart.series[0].values == [1, 2, 3])
    }
}
