import Foundation
import Testing
@testable import Rostrum

@Suite struct ChartXYReadBackTests {
    private let frame = Rect(x: .inches(1), y: .inches(1), width: .inches(8), height: .inches(4))

    @Test func scatterSeriesReadBackAsPoints() throws {
        let deck = try Presentation()
        try deck.slides[0].shapes.addScatterChart(
            XYChartData(series: [
                .init(name: "Trial A", points: [(x: 1, y: 10), (x: 2, y: 20)]),
                .init(name: "Trial B", points: [(x: 3.5, y: 30)]),
            ]), frame: frame)
        let chart = try #require(try Presentation(data: try deck.serializedData()).charts.first)

        #expect(chart.isXY)
        // The category-shaped view stays honestly nil for an XY chart.
        #expect(chart.data == nil)
        #expect(chart.categories.isEmpty)

        let series = chart.xySeries
        #expect(series.map(\.name) == ["Trial A", "Trial B"])
        #expect(series[0].points.map(\.x) == [1, 2])
        #expect(series[0].points.map(\.y) == [10, 20])
        // Scatter has no size axis, and saying "0" would be a lie.
        #expect(series[0].points.allSatisfy { $0.size == nil })
        // Series read independently, so a shorter one stays short.
        #expect(series[1].points.count == 1)
        #expect(series[1].points[0] == Chart.XYPoint(x: 3.5, y: 30, size: nil))
    }

    @Test func bubbleSeriesCarrySizes() throws {
        let deck = try Presentation()
        try deck.slides[0].shapes.addBubbleChart(
            BubbleChartData(series: [
                .init(name: "Markets", points: [.init(x: 1, y: 2, size: 10),
                                                .init(x: 3, y: 4, size: 20)]),
            ]), frame: frame)
        let chart = try #require(try Presentation(data: try deck.serializedData()).charts.first)

        #expect(chart.isXY)
        let points = try #require(chart.xySeries.first).points
        #expect(points.map(\.size) == [10, 20])
        #expect(points.map(\.x) == [1, 3])
        #expect(points.map(\.y) == [2, 4])
    }

    @Test func aCategoryChartHasNoXYSeries() throws {
        let deck = try Presentation()
        try deck.slides[0].shapes.addChart(
            .barClustered,
            data: ChartData(categories: ["A", "B"], values: [1, 2]), frame: frame)
        let chart = try #require(try Presentation(data: try deck.serializedData()).charts.first)
        #expect(!chart.isXY)
        #expect(chart.xySeries.isEmpty)
    }

    @Test func textualXValuesAreReportedAsLabelsNotSilentNils() throws {
        // c:xVal is a choice; a scatter built over a text column carries a
        // c:strRef. Reading every x as nil without saying why is the kind of
        // silent hole this library exists to avoid.
        let deck = try Presentation()
        try deck.slides[0].shapes.addScatterChart(
            XYChartData(name: "S", points: [(x: 1, y: 10), (x: 2, y: 20)]), frame: frame)
        let chart = try #require(try Presentation(data: try deck.serializedData()).charts.first)
        let xVal = try #require(chart.seriesElements.first?.firstChild(named: "c:xVal"))

        let ref = XML.Element("c:strRef")
        let f = XML.Element("c:f")
        f.children = [.text("Sheet1!$A$2:$A$3")]
        ref.appendElement(f)
        let cache = XML.Element("c:strCache")
        cache.appendElement(XML.Element("c:ptCount", attributes: [("val", "2")]))
        for (index, label) in ["North", "South"].enumerated() {
            let pt = XML.Element("c:pt", attributes: [("idx", String(index))])
            let v = XML.Element("c:v")
            v.children = [.text(label)]
            pt.appendElement(v)
            cache.appendElement(pt)
        }
        ref.appendElement(cache)
        xVal.children = [.element(ref)]
        chart.part.markDirty()

        let series = try #require(chart.xySeries.first)
        #expect(series.xLabels == ["North", "South"])
        #expect(series.points.allSatisfy { $0.x == nil })
        #expect(series.points.map(\.y) == [10, 20])
    }

    @Test func gapsInAnXYCacheKeepTheirIndex() throws {
        let deck = try Presentation()
        try deck.slides[0].shapes.addScatterChart(
            XYChartData(name: "S", points: [(x: 1, y: 10), (x: 2, y: 20), (x: 3, y: 30)]),
            frame: frame)
        let chart = try #require(try Presentation(data: try deck.serializedData()).charts.first)
        let yVal = try #require(chart.seriesElements.first?.firstChild(named: "c:yVal"))
        let cache = try #require(Chart.numberCache(in: yVal))
        // Drop the middle point, as a blank cell does.
        for pt in cache.children(named: "c:pt") where pt[attribute: "idx"] == "1" {
            cache.removeChild(pt)
        }
        chart.part.markDirty()

        let points = try #require(chart.xySeries.first).points
        #expect(points.count == 3)
        #expect(points.map(\.y) == [10, nil, 30])
        #expect(points.map(\.x) == [1, 2, 3])
    }
}

@Suite struct ChartSeriesEditingTests {
    private let frame = Rect(x: .inches(1), y: .inches(1), width: .inches(8), height: .inches(4))

    private func deckWithChart(
        _ kind: ChartKind = .barClustered,
        data: ChartData = ChartData(categories: ["Q1", "Q2", "Q3"],
                                    series: [.init(name: "Revenue", values: [10, 20, 30]),
                                             .init(name: "Cost", values: [5, 8, 11])]),
        colors: [Color]? = nil,
        legend: LegendPosition? = nil
    ) throws -> Presentation {
        let deck = try Presentation()
        try deck.slides[0].shapes.addChart(
            kind, data: data, frame: frame, colors: colors,
            options: ChartOptions(title: "Results", legend: legend))
        return try Presentation(data: try deck.serializedData())
    }

    // MARK: - Adding

    @Test func addedSeriesShowsUpInTheChartAndTheWorkbook() throws {
        let deck = try deckWithChart()
        let chart = try #require(deck.charts.first)
        #expect(chart.addSeriesProblem(name: "Margin", values: [5, 12, 19]) == nil)
        try chart.addSeries(name: "Margin", values: [5, 12, 19])

        let reopened = try Presentation(data: try deck.serializedData())
        let saved = try #require(reopened.charts.first)
        let data = try #require(saved.data)
        #expect(data.series.map(\.name) == ["Revenue", "Cost", "Margin"])
        #expect(data.series[2].values == [5, 12, 19])
        #expect(data.categories == ["Q1", "Q2", "Q3"])
        // Existing series are untouched.
        #expect(data.series[0].values == [10, 20, 30])

        // The new series must address the next workbook column, or Edit Data
        // shows an empty column next to the plotted numbers.
        let added = try #require(saved.seriesElements.last)
        #expect(added.firstChild(named: "c:idx")?[attribute: "val"] == "2")
        #expect(added.firstChild(named: "c:order")?[attribute: "val"] == "2")
        let names = try #require(added.firstChild(named: "c:tx"))
        #expect(Chart.formula(in: names) == "Sheet1!$D$1")
        let values = try #require(added.firstChild(named: "c:val"))
        #expect(Chart.formula(in: values) == "Sheet1!$D$2:$D$4")
        #expect(try reopened.validate().isEmpty)
    }

    @Test func theEmbeddedWorkbookGainsTheNewColumn() throws {
        let deck = try deckWithChart()
        let chart = try #require(deck.charts.first)
        try chart.addSeries(name: "Margin", values: [5, 12, 19])

        let reopened = try Presentation(data: try deck.serializedData())
        let workbook = try #require(reopened.charts.first?.workbookPart)
        let sheet = try ZipReader(data: workbook.blob).data(forEntry: "xl/worksheets/sheet1.xml")
        let text = try #require(String(data: sheet, encoding: .utf8))
        // Column D holds the third series' values in rows 2–4.
        #expect(text.contains("<c r=\"D2\" s=\"1\"><v>5</v></c>"))
        #expect(text.contains("<c r=\"D4\" s=\"1\"><v>19</v></c>"))
        let strings = try ZipReader(data: workbook.blob).data(forEntry: "xl/sharedStrings.xml")
        let names = try #require(String(data: strings, encoding: .utf8))
        #expect(names.contains("<t>Margin</t>"))
    }

    @Test func addedSeriesDoesNotInheritItsSiblingsIdentity() throws {
        // Cloning the template wholesale would give the new series the same
        // explicit color and the same unique id as the one it was copied from.
        let deck = try deckWithChart(colors: [Color("18A999"), Color("FF6B5E")])
        let chart = try #require(deck.charts.first)
        let template = try #require(chart.seriesElements.last)
        // Give the template the extension list PowerPoint writes, so the test
        // proves it is dropped rather than that it was never there.
        let ext = XML.Element("c:extLst")
        ext.appendElement(XML.Element("c:ext", attributes: [("uri", "{C3380CC4}")]))
        template.appendElement(ext)
        #expect(template.firstChild(named: "c:spPr") != nil)

        try chart.addSeries(name: "Margin", values: [5, 12, 19])
        let added = try #require(chart.seriesElements.last)
        #expect(added.firstChild(named: "c:spPr") == nil,
                "an inherited spPr would paint the new series its sibling's color")
        #expect(added.firstChild(named: "c:extLst") == nil,
                "a duplicated series id is a repair prompt")
        #expect(added.firstChild(named: "c:tx") != nil)
    }

    @Test func addedSeriesKeepsThePerKindChildrenItsSiblingsHave() throws {
        // A line series ends with c:smooth; a new one without it renders
        // differently from the series beside it.
        let deck = try deckWithChart(.line)
        let chart = try #require(deck.charts.first)
        try chart.addSeries(name: "Margin", values: [5, 12, 19])
        let added = try #require(chart.seriesElements.last)
        #expect(added.firstChild(named: "c:smooth") != nil)
        #expect(added.firstChild(named: "c:marker") != nil)
        // And the c:ser run stays contiguous and ahead of the plot's own
        // children, or the part no longer matches the schema.
        let plot = try #require(chart.plots.first)
        let names = plot.childElements.map(\.name)
        let seriesPositions = names.enumerated().filter { $0.element == "c:ser" }.map(\.offset)
        let first = try #require(seriesPositions.first)
        let last = try #require(seriesPositions.last)
        let axis = try #require(names.firstIndex(of: "c:axId"))
        #expect(seriesPositions == Array(first...last), "the c:ser run must stay contiguous")
        #expect(axis > last, "series must precede the plot's own children")
    }

    @Test func addingAcceptsGapsAndReadsThemBack() throws {
        let deck = try deckWithChart()
        let chart = try #require(deck.charts.first)
        try chart.addSeries(name: "Sparse", values: [1, nil, 3])
        let reopened = try Presentation(data: try deck.serializedData())
        let saved = try #require(reopened.charts.first)
        #expect(saved.series.last?.values == [1, nil, 3])
    }

    // MARK: - Removing

    @Test func removingASeriesRenumbersTheSurvivors() throws {
        let deck = try deckWithChart(data: ChartData(
            categories: ["Q1", "Q2"],
            series: [.init(name: "A", values: [1, 2]),
                     .init(name: "B", values: [3, 4]),
                     .init(name: "C", values: [5, 6])]))
        let chart = try #require(deck.charts.first)
        #expect(chart.removeSeriesProblem(at: 1) == nil)
        try chart.removeSeries(at: 1)

        let reopened = try Presentation(data: try deck.serializedData())
        let saved = try #require(reopened.charts.first)
        #expect(saved.series.map(\.name) == ["A", "C"])
        #expect(saved.series[1].values == [5, 6])
        // The survivor must move into the column it now occupies, or Edit
        // Data shows a hole where B used to be.
        let indices = saved.seriesElements.map { $0.firstChild(named: "c:idx")?[attribute: "val"] }
        #expect(indices == ["0", "1"])
        let orders = saved.seriesElements.map { $0.firstChild(named: "c:order")?[attribute: "val"] }
        #expect(orders == ["0", "1"])
        let moved = try #require(saved.seriesElements.last)
        let movedName = try #require(moved.firstChild(named: "c:tx"))
        let movedValues = try #require(moved.firstChild(named: "c:val"))
        #expect(Chart.formula(in: movedName) == "Sheet1!$C$1")
        #expect(Chart.formula(in: movedValues) == "Sheet1!$C$2:$C$3")
        #expect(try reopened.validate().isEmpty)

        // And the chart still accepts its own data back — the invariant that
        // proves chart XML and workbook still agree.
        let survivingData = try #require(saved.data)
        #expect(saved.replacementProblem(for: survivingData) == nil)
    }

    @Test func theWorkbookLosesTheRemovedColumn() throws {
        let deck = try deckWithChart()
        let chart = try #require(deck.charts.first)
        try chart.removeSeries(at: 0)
        let workbook = try #require(chart.workbookPart)
        let strings = try ZipReader(data: workbook.blob).data(forEntry: "xl/sharedStrings.xml")
        let text = try #require(String(data: strings, encoding: .utf8))
        #expect(text.contains("<t>Cost</t>"))
        #expect(!text.contains("<t>Revenue</t>"))
    }

    @Test func removingShiftsLegendEntriesRatherThanStrandingThem() throws {
        let deck = try deckWithChart(data: ChartData(
            categories: ["Q1"],
            series: [.init(name: "A", values: [1]),
                     .init(name: "B", values: [2]),
                     .init(name: "C", values: [3])]),
            legend: .bottom)
        let chart = try #require(deck.charts.first)
        let legend = try #require(chart.root?.firstChild(named: "c:chart")?
            .firstChild(named: "c:legend"))
        for index in 0...2 {
            let entry = XML.Element("c:legendEntry")
            entry.appendElement(XML.Element("c:idx", attributes: [("val", String(index))]))
            entry.appendElement(XML.Element("c:delete", attributes: [("val", "0")]))
            legend.insertChild(entry, beforeAnyOf: ["c:layout", "c:overlay", "c:spPr", "c:txPr"])
        }

        try chart.removeSeries(at: 1)
        let remaining = legend.children(named: "c:legendEntry")
            .compactMap { $0.firstChild(named: "c:idx")?[attribute: "val"] }
        #expect(remaining == ["0", "1"],
                "entry 1 belonged to the removed series; entry 2 must slide down to 1")
        #expect(try deck.validate().isEmpty)
    }

    @Test func removingTheLastSeriesIsRefused() throws {
        let deck = try deckWithChart(data: ChartData(categories: ["Q1"], name: "Only", values: [1]))
        let chart = try #require(deck.charts.first)
        #expect(chart.removeSeriesProblem(at: 0) == .wouldLeaveNoSeries)
        #expect(throws: Chart.SeriesEditProblem.wouldLeaveNoSeries) { try chart.removeSeries(at: 0) }
    }

    @Test func anOutOfRangeIndexIsRefused() throws {
        let deck = try deckWithChart()
        let chart = try #require(deck.charts.first)
        #expect(chart.removeSeriesProblem(at: 7)
                == .seriesIndexOutOfRange(index: 7, count: 2))
        #expect(chart.removeSeriesProblem(at: -1)
                == .seriesIndexOutOfRange(index: -1, count: 2))
    }

    // MARK: - Refusals

    @Test func aValueCountThatDoesNotMatchTheCategoriesIsRefused() throws {
        let deck = try deckWithChart()
        let chart = try #require(deck.charts.first)
        #expect(chart.addSeriesProblem(name: "Short", values: [1, 2])
                == .valueCountMismatch(categories: 3, values: 2))
        #expect(throws: Chart.SeriesEditProblem.self) {
            try chart.addSeries(name: "Short", values: [1, 2])
        }
    }

    @Test func xyChartsAreRefused() throws {
        let deck = try Presentation()
        try deck.slides[0].shapes.addScatterChart(
            XYChartData(name: "S", points: [(x: 1, y: 2)]), frame: frame)
        let chart = try #require(try Presentation(data: try deck.serializedData()).charts.first)
        #expect(chart.addSeriesProblem(name: "T", values: [1]) == .notACategoryChart)
        #expect(chart.removeSeriesProblem(at: 0) == .notACategoryChart)
    }

    @Test func pieChartsRefuseASecondSeriesRatherThanHideIt() throws {
        // A pie plots its first series and ignores the rest, so "added" would
        // mean "written but never drawn".
        let deck = try deckWithChart(.pie, data: ChartData(categories: ["A", "B"], values: [1, 2]))
        let chart = try #require(deck.charts.first)
        #expect(chart.addSeriesProblem(name: "Second", values: [3, 4])
                == .chartTypePlotsOneSeries(plotType: "pieChart"))
    }

    @Test func doughnutChartsDoTakeASecondSeries() throws {
        // Unlike pie, a doughnut draws each series as its own ring. Colors are
        // passed so the template carries the c:dPt run a colored pie/doughnut
        // series gets: the added ring must not inherit ring 1's slice colors.
        let deck = try deckWithChart(.doughnut,
                                     data: ChartData(categories: ["A", "B"], values: [1, 2]),
                                     colors: [Color("18A999"), Color("FF6B5E")])
        let chart = try #require(deck.charts.first)
        let template = try #require(chart.seriesElements.first)
        #expect(!template.children(named: "c:dPt").isEmpty, "the fixture must have per-point fills")

        #expect(chart.addSeriesProblem(name: "Outer", values: [3, 4]) == nil)
        try chart.addSeries(name: "Outer", values: [3, 4])
        let added = try #require(chart.seriesElements.last)
        #expect(added.children(named: "c:dPt").isEmpty,
                "inherited per-slice colors would make the second ring a copy of the first")
        #expect(try Presentation(data: try deck.serializedData())
            .charts.first?.series.map(\.name) == ["Series 1", "Outer"])
    }

    @Test func nestedColorAndPerSeriesAnalysisAreStrippedFromTheClone() throws {
        // The identity strip has to reach one level down: PowerPoint stores a
        // line series' marker color in c:marker/c:spPr, and a c:ser can carry a
        // trendline and error bars that belong to that series alone.
        let deck = try deckWithChart(.line)
        let chart = try #require(deck.charts.first)
        let template = try #require(chart.seriesElements.last)
        let marker = try #require(template.firstChild(named: "c:marker"))
        marker.appendElement(XML.Element("c:spPr"))
        let labels = XML.Element("c:dLbls")
        labels.appendElement(XML.Element("c:dLbl"))
        labels.appendElement(XML.Element("c:spPr"))
        labels.appendElement(XML.Element("c:showVal", attributes: [("val", "1")]))
        template.insertChild(labels, beforeAnyOf: ["c:cat", "c:val"])
        template.insertChild(XML.Element("c:trendline"), beforeAnyOf: ["c:cat", "c:val"])
        template.insertChild(XML.Element("c:errBars"), beforeAnyOf: ["c:cat", "c:val"])
        chart.part.markDirty()

        try chart.addSeries(name: "Margin", values: [5, 12, 19])
        let added = try #require(chart.seriesElements.last)
        #expect(added.firstChild(named: "c:marker")?.firstChild(named: "c:spPr") == nil,
                "markers in the sibling's color are worse than plain inheritance")
        #expect(added.firstChild(named: "c:trendline") == nil)
        #expect(added.firstChild(named: "c:errBars") == nil)
        // The label *settings* are per-kind and stay; the per-point overrides
        // and the sibling's label styling do not.
        let addedLabels = try #require(added.firstChild(named: "c:dLbls"))
        #expect(addedLabels.firstChild(named: "c:showVal") != nil)
        #expect(addedLabels.firstChild(named: "c:dLbl") == nil)
        #expect(addedLabels.firstChild(named: "c:spPr") == nil)
        // The template itself must be untouched — deepCopy shares nothing.
        #expect(template.firstChild(named: "c:trendline") != nil)
        #expect(marker.firstChild(named: "c:spPr") != nil)
    }

    @Test func aSeriesWithoutACTxGetsOneRatherThanLosingItsName() throws {
        // c:tx is optional. Writing the name into the workbook while the chart
        // never gains it labels the series "Series N" and disagrees with Edit
        // Data — so the name element is synthesized instead.
        let deck = try deckWithChart()
        let chart = try #require(deck.charts.first)
        for series in chart.seriesElements { series.removeChildren(named: "c:tx") }
        chart.part.markDirty()

        try chart.addSeries(name: "Margin", values: [5, 12, 19])
        let reopened = try Presentation(data: try deck.serializedData())
        let saved = try #require(reopened.charts.first)
        #expect(saved.series.map(\.name) == ["", "", "Margin"])
        let added = try #require(saved.seriesElements.last)
        let tx = try #require(added.firstChild(named: "c:tx"))
        #expect(Chart.formula(in: tx) == "Sheet1!$D$1")
        // And it must land in its schema position, right after c:idx/c:order.
        let leading = Array(added.childElements.map(\.name).prefix(3))
        #expect(leading == ["c:idx", "c:order", "c:tx"])
        #expect(try reopened.validate().isEmpty)
    }

    @Test func stockChartsRefuseEditsThatBreakTheirFixedSeriesCount() throws {
        // CT_StockChart is the one plot type whose schema pins the series
        // count: minOccurs="3" maxOccurs="4" (high-low-close and
        // open-high-low-close). Rostrum cannot author one, so the fixture is a
        // renamed bar plot — eligibility keys on the plot element's name.
        func stockChart(seriesCount: Int) throws -> Chart {
            let series = (0..<seriesCount).map {
                ChartData.Series(name: "S\($0)", values: [Double($0), Double($0) + 1])
            }
            let deck = try deckWithChart(
                data: ChartData(categories: ["Mon", "Tue"], series: series))
            let chart = try #require(deck.charts.first)
            let plot = try #require(chart.plots.first)
            plot.name = "c:stockChart"
            chart.part.markDirty()
            return chart
        }

        let openHighLowClose = try stockChart(seriesCount: 4)
        #expect(openHighLowClose.addSeriesProblem(name: "Fifth", values: [1, 2])
                == .seriesCountFixedByChartType(plotType: "stockChart", allowed: 3...4))
        #expect(openHighLowClose.removeSeriesProblem(at: 0) == nil, "4 → 3 stays legal")

        let highLowClose = try stockChart(seriesCount: 3)
        #expect(highLowClose.removeSeriesProblem(at: 0)
                == .seriesCountFixedByChartType(plotType: "stockChart", allowed: 3...4))
        #expect(highLowClose.addSeriesProblem(name: "Fourth", values: [1, 2]) == nil,
                "3 → 4 stays legal")
    }

    @Test func aPlotHidingAFilteredSeriesIsRefused() throws {
        // PowerPoint 2013+ does not delete a series you filter out — it parks
        // it in the plot's c:extLst, still owning an index and a workbook
        // column that a new series would silently claim.
        let deck = try deckWithChart()
        let chart = try #require(deck.charts.first)
        let plot = try #require(chart.plots.first)
        let extensions = XML.Element("c:extLst")
        let ext = XML.Element("c:ext", attributes: [
            ("uri", "{02D57815-91ED-43cb-92C2-25804820EDAC}"),
        ])
        let filtered = XML.Element("c15:filteredBarSeries")
        filtered.appendElement(XML.Element("c15:ser"))
        ext.appendElement(filtered)
        extensions.appendElement(ext)
        plot.appendElement(extensions)
        chart.part.markDirty()

        #expect(chart.addSeriesProblem(name: "X", values: [1, 2, 3])
                == .filteredSeriesNotSupported)
        #expect(chart.removeSeriesProblem(at: 0) == .filteredSeriesNotSupported)
    }

    @Test func aDoughnutLegendIsLeftAloneBecauseItListsCategories() throws {
        // Pie-family legends enumerate data points, not series. Shifting their
        // entries when a ring goes away moves one category's formatting onto
        // its neighbour and strands the last one.
        let deck = try deckWithChart(.doughnut,
                                     data: ChartData(categories: ["A", "B", "C"],
                                                     values: [1, 2, 3]),
                                     legend: .bottom)
        let chart = try #require(deck.charts.first)
        try chart.addSeries(name: "Outer", values: [4, 5, 6])
        let legend = try #require(chart.root?.firstChild(named: "c:chart")?
            .firstChild(named: "c:legend"))
        for index in 0...2 {
            let entry = XML.Element("c:legendEntry")
            entry.appendElement(XML.Element("c:idx", attributes: [("val", String(index))]))
            entry.appendElement(
                XML.Element("c:delete", attributes: [("val", index == 1 ? "1" : "0")]))
            legend.insertChild(entry, beforeAnyOf: ["c:layout", "c:overlay", "c:spPr", "c:txPr"])
        }

        try chart.removeSeries(at: 0)
        let entries = legend.children(named: "c:legendEntry")
        let indices = entries.compactMap { $0.firstChild(named: "c:idx")?[attribute: "val"] }
        #expect(indices == ["0", "1", "2"],
                "removing a ring changes no category, so no entry may move")
        #expect(entries.count == 3)
        #expect(entries[1].firstChild(named: "c:delete")?[attribute: "val"] == "1",
                "the hidden category must stay the hidden category")
    }

    @Test func comboChartsAreRefused() throws {
        let deck = try deckWithChart()
        let chart = try #require(deck.charts.first)
        let plotArea = try #require(chart.root?.firstChild(named: "c:chart")?
            .firstChild(named: "c:plotArea"))
        let bar = try #require(plotArea.childElements.first { $0.name == "c:barChart" })
        let second = bar.children(named: "c:ser")[1]
        bar.removeChild(second)
        let line = XML.Element("c:lineChart")
        line.appendElement(second)
        plotArea.insertChild(line, beforeAnyOf: ["c:catAx", "c:valAx"])
        chart.part.markDirty()

        #expect(chart.addSeriesProblem(name: "X", values: [1, 2, 3])
                == .comboChartNotSupported(plotTypes: ["barChart", "lineChart"]))
        #expect(chart.removeSeriesProblem(at: 0)
                == .comboChartNotSupported(plotTypes: ["barChart", "lineChart"]))
    }

    @Test func aChartWhoseFormulasAreForeignIsRefused() throws {
        // Rewriting the workbook under formulas that describe someone else's
        // layout is exactly the corruption replaceData refuses; structural
        // edits must refuse it too.
        let deck = try deckWithChart()
        let chart = try #require(deck.charts.first)
        let val = try #require(chart.seriesElements.first?.firstChild(named: "c:val"))
        Chart.setFormula("'Other Sheet'!$Z$9:$Z$11", in: val)
        chart.part.markDirty()

        let problem = chart.addSeriesProblem(name: "X", values: [1, 2, 3])
        #expect(problem == .structureNotEditable(
            .workbookLayoutNotRecognized(formula: "'Other Sheet'!$Z$9:$Z$11")))
    }

    @Test func literalDataIsRefused() throws {
        // c:numLit has no c:f, so there is no column layout to renumber.
        let deck = try deckWithChart()
        let chart = try #require(deck.charts.first)
        let val = try #require(chart.seriesElements[1].firstChild(named: "c:val"))
        let lit = XML.Element("c:numLit")
        lit.appendElement(XML.Element("c:ptCount", attributes: [("val", "3")]))
        for (index, value) in [5.0, 8.0, 11.0].enumerated() {
            let pt = XML.Element("c:pt", attributes: [("idx", String(index))])
            let v = XML.Element("c:v")
            v.children = [.text(chartNumber(value))]
            pt.appendElement(v)
            lit.appendElement(pt)
        }
        val.children = [.element(lit)]
        chart.part.markDirty()

        #expect(chart.addSeriesProblem(name: "X", values: [1, 2, 3])
                == .literalDataNotSupported(index: 1))
    }

    @Test func aChartWithoutAnEmbeddedWorkbookIsRefused() throws {
        let deck = try deckWithChart()
        let chart = try #require(deck.charts.first)
        let root = try #require(chart.root)
        root.removeChildren(named: "c:externalData")
        chart.part.markDirty()
        #expect(chart.workbookPart == nil)
        #expect(chart.addSeriesProblem(name: "X", values: [1, 2, 3]) == .noEmbeddedWorkbook)
        #expect(chart.removeSeriesProblem(at: 0) == .noEmbeddedWorkbook)
    }

    @Test func aRefusedEditWritesNothingAtAll() throws {
        let deck = try deckWithChart()
        let chart = try #require(deck.charts.first)
        let chartBefore = try chart.part.dom().serialized()
        let workbookBefore = try #require(chart.workbookPart).blob

        #expect(throws: Chart.SeriesEditProblem.self) {
            try chart.addSeries(name: "Short", values: [1])
        }
        #expect(throws: Chart.SeriesEditProblem.self) { try chart.removeSeries(at: 9) }

        let workbookAfter = try #require(chart.workbookPart).blob
        #expect(try chart.part.dom().serialized() == chartBefore)
        #expect(workbookAfter == workbookBefore)
    }

    // MARK: - Invariants

    @Test func seriesEditsAreDeterministic() throws {
        func build() throws -> Data {
            let deck = try deckWithChart()
            let chart = try #require(deck.charts.first)
            try chart.addSeries(name: "Margin", values: [5, 12, 19])
            try chart.removeSeries(at: 0)
            return try deck.serializedData()
        }
        #expect(try build() == build())
    }

    @Test func editingOneChartLeavesTheRestOfTheDeckByteIdentical() throws {
        let deck = try deckWithChart()
        let before = try deck.serializedData()
        let chart = try #require(deck.charts.first)
        try chart.addSeries(name: "Margin", values: [5, 12, 19])
        let after = try deck.serializedData()

        let old = try ZipReader(data: before)
        let new = try ZipReader(data: after)
        let changed = try Set(old.entryNames).union(new.entryNames).filter { name in
            try old.data(forEntry: name) != new.data(forEntry: name)
        }
        #expect(changed == ["ppt/charts/chart1.xml", "ppt/embeddings/Microsoft_Excel_Sheet1.xlsx"],
                "only the chart and its workbook may change; got \(changed.sorted())")
    }

    @Test func addThenRemoveReturnsTheChartToItsOriginalShape() throws {
        let deck = try deckWithChart()
        let chart = try #require(deck.charts.first)
        let before = try chart.part.dom().serialized()
        try chart.addSeries(name: "Margin", values: [5, 12, 19])
        try chart.removeSeries(at: 2)
        // Formatting the added series never had cannot come back, but the
        // structure, indices and formulas must.
        #expect(try chart.part.dom().serialized() == before)
    }
}
