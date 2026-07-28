import Foundation
import Testing
@testable import Rostrum

@Suite struct ComboChartTests {
    private let frame = Rect(x: .inches(1), y: .inches(1), width: .inches(8), height: .inches(4))

    private let columnsAndLine = ComboChartData(
        categories: ["Q1", "Q2", "Q3"],
        groups: [
            .init(kind: .barClustered,
                  series: [.init(name: "Revenue", values: [10, 20, 30]),
                           .init(name: "Cost", values: [5, 8, 11])]),
            .init(kind: .line, series: [.init(name: "Margin", values: [50, 60, 63])],
                  axis: .secondary),
        ])

    private func plotArea(of chart: Chart) throws -> XML.Element {
        let root = try chart.part.dom()
        return try #require(root.firstChild(named: "c:chart")?.firstChild(named: "c:plotArea"))
    }

    private func axisIDs(of plot: XML.Element) -> [String] {
        plot.children(named: "c:axId").compactMap { $0[attribute: "val"] }
    }

    private func axisPosition(of axis: XML.Element) -> String? {
        axis.firstChild(named: "c:axPos")?[attribute: "val"]
    }

    // MARK: - Structure

    @Test func aComboWritesOnePlotGroupPerGroupBeforeAnyAxis() throws {
        let deck = try Presentation()
        try deck.slides[0].shapes.addComboChart(columnsAndLine, frame: frame,
                                                options: ChartOptions(title: "Results"))
        let reopened = try Presentation(data: try deck.serializedData())
        let chart = try #require(reopened.charts.first)
        #expect(chart.plotTypes == ["barChart", "lineChart"])
        #expect(chart.isCombo)

        // CT_PlotArea is layout?, (plot group)+, (axis)*, … — every group must
        // precede every axis.
        let names = try plotArea(of: chart).childElements.map(\.name)
        let lastPlot = try #require(names.lastIndex { $0.hasSuffix("Chart") })
        let firstAxis = try #require(names.firstIndex { $0 == "c:catAx" || $0 == "c:valAx" })
        #expect(lastPlot < firstAxis)
        #expect(try reopened.validate().isEmpty)
    }

    @Test func seriesAreNumberedGloballyAcrossGroups() throws {
        // c:idx, c:order and the workbook column are the same fact. Restarting
        // the count per group would give two series idx 0 and point two series
        // at column B.
        let deck = try Presentation()
        try deck.slides[0].shapes.addComboChart(columnsAndLine, frame: frame)
        let reopened = try Presentation(data: try deck.serializedData())
        let chart = try #require(reopened.charts.first)

        let elements = chart.seriesElements
        #expect(elements.count == 3)
        #expect(elements.compactMap { $0.firstChild(named: "c:idx")?[attribute: "val"] }
                == ["0", "1", "2"])
        #expect(elements.compactMap { $0.firstChild(named: "c:order")?[attribute: "val"] }
                == ["0", "1", "2"])
        let columns = elements.compactMap { $0.firstChild(named: "c:val") }
            .compactMap { Chart.formula(in: $0) }
        #expect(columns == ["Sheet1!$B$2:$B$4", "Sheet1!$C$2:$C$4", "Sheet1!$D$2:$D$4"])
        // And the read side sees them in that order, across both groups.
        #expect(chart.series.map(\.name) == ["Revenue", "Cost", "Margin"])
        #expect(chart.series[2].values == [50, 60, 63])
    }

    @Test func everyGroupSharesTheOneCategoryAxisData() throws {
        let deck = try Presentation()
        try deck.slides[0].shapes.addComboChart(columnsAndLine, frame: frame)
        let chart = try #require(try Presentation(data: try deck.serializedData()).charts.first)
        let categoryFormulas = chart.seriesElements
            .compactMap { $0.firstChild(named: "c:cat") }
            .compactMap { Chart.formula(in: $0) }
        #expect(categoryFormulas == Array(repeating: "Sheet1!$A$2:$A$4", count: 3))
        #expect(chart.categories == ["Q1", "Q2", "Q3"])
    }

    // MARK: - Axes

    @Test func aSecondaryGroupGetsItsOwnAxisPairAndBothAxesExist() throws {
        // A c:axId naming an axis the plot area does not contain is a repair
        // trigger no schema check can see, so the deleted partner category axis
        // is structural, not decoration.
        let deck = try Presentation()
        try deck.slides[0].shapes.addComboChart(columnsAndLine, frame: frame)
        let chart = try #require(try Presentation(data: try deck.serializedData()).charts.first)
        let area = try plotArea(of: chart)

        let bar = try #require(area.firstChild(named: "c:barChart"))
        let line = try #require(area.firstChild(named: "c:lineChart"))
        #expect(axisIDs(of: bar) == [ChartXML.catAxID, ChartXML.valAxID])
        #expect(axisIDs(of: line) == [ChartXML.secondaryCatAxID, ChartXML.secondaryValAxID])

        let declared = Set(area.childElements
            .filter { $0.name == "c:catAx" || $0.name == "c:valAx" }
            .compactMap { $0.firstChild(named: "c:axId")?[attribute: "val"] })
        #expect(declared == [ChartXML.catAxID, ChartXML.valAxID,
                             ChartXML.secondaryCatAxID, ChartXML.secondaryValAxID])
        let referenced = Set(axisIDs(of: bar) + axisIDs(of: line))
        #expect(referenced.isSubset(of: declared), "every c:axId must name a real axis")

        // And every axis must cross an axis that exists, too.
        let crossings = Set(area.childElements
            .filter { $0.name == "c:catAx" || $0.name == "c:valAx" }
            .compactMap { $0.firstChild(named: "c:crossAx")?[attribute: "val"] })
        #expect(crossings.isSubset(of: declared))
    }

    @Test func theSecondaryValueAxisSitsRightWithNoGridlines() throws {
        let deck = try Presentation()
        try deck.slides[0].shapes.addComboChart(
            columnsAndLine, frame: frame,
            options: ChartOptions(valueAxis: AxisOptions(title: "Dollars"),
                                  secondaryValueAxis: AxisOptions(numberFormat: "0%",
                                                                  title: "Margin")))
        let chart = try #require(try Presentation(data: try deck.serializedData()).charts.first)
        let area = try plotArea(of: chart)
        let valueAxes = area.children(named: "c:valAx")
        #expect(valueAxes.count == 2)

        let primary = valueAxes[0], secondary = valueAxes[1]
        #expect(axisPosition(of: primary) == "l")
        #expect(primary.firstChild(named: "c:majorGridlines") != nil)
        #expect(primary.firstChild(named: "c:crosses")?[attribute: "val"] == "autoZero")

        #expect(axisPosition(of: secondary) == "r")
        #expect(secondary.firstChild(named: "c:majorGridlines") == nil,
                "two sets of gridlines would double-rule the plot")
        #expect(secondary.firstChild(named: "c:crosses")?[attribute: "val"] == "max")
        #expect(secondary.firstChild(named: "c:numFmt")?[attribute: "formatCode"] == "0%")
    }

    @Test func theSecondaryCategoryAxisIsDeletedAndDoesNotCross() throws {
        let deck = try Presentation()
        try deck.slides[0].shapes.addComboChart(columnsAndLine, frame: frame)
        let chart = try #require(try Presentation(data: try deck.serializedData()).charts.first)
        let categoryAxes = try plotArea(of: chart).children(named: "c:catAx")
        #expect(categoryAxes.count == 2)
        #expect(categoryAxes[0].firstChild(named: "c:delete")?[attribute: "val"] == "0")

        let hidden = categoryAxes[1]
        #expect(hidden.firstChild(named: "c:axId")?[attribute: "val"] == ChartXML.secondaryCatAxID)
        #expect(hidden.firstChild(named: "c:delete")?[attribute: "val"] == "1",
                "c:delete is what hides it; without this the labels are drawn twice")
        // Excel writes neither c:crosses nor c:crossesAt on this axis, and the
        // two are an either/or — emitting both would be invalid.
        #expect(hidden.firstChild(named: "c:crosses") == nil)
        #expect(hidden.firstChild(named: "c:crossesAt") == nil)
    }

    @Test func aComboWithNoSecondaryGroupDeclaresOnlyTwoAxes() throws {
        let shared = ComboChartData(
            categories: ["A", "B"],
            groups: [
                .init(kind: .barClustered, series: [.init(name: "Bar", values: [1, 2])]),
                .init(kind: .line, series: [.init(name: "Line", values: [3, 4])]),
            ])
        let deck = try Presentation()
        try deck.slides[0].shapes.addComboChart(shared, frame: frame)
        let chart = try #require(try Presentation(data: try deck.serializedData()).charts.first)
        let area = try plotArea(of: chart)
        #expect(area.children(named: "c:catAx").count == 1)
        #expect(area.children(named: "c:valAx").count == 1)
        // Both groups name the same pair.
        let bar = try #require(area.firstChild(named: "c:barChart"))
        let line = try #require(area.firstChild(named: "c:lineChart"))
        #expect(axisIDs(of: bar) == axisIDs(of: line))
        #expect(try Presentation(data: try deck.serializedData()).validate().isEmpty)
    }

    // MARK: - Per-group styling

    @Test func dataLabelsAndColorsBelongToTheirGroup() throws {
        let data = ComboChartData(
            categories: ["A", "B"],
            groups: [
                .init(kind: .barClustered, series: [.init(name: "Bar", values: [1, 2])],
                      colors: [Color("18A999")],
                      dataLabels: DataLabelOptions(showValue: true, position: "outEnd")),
                .init(kind: .line, series: [.init(name: "Line", values: [3, 4])],
                      axis: .secondary,
                      dataLabels: DataLabelOptions(showValue: true, position: "t")),
            ])
        let deck = try Presentation()
        try deck.slides[0].shapes.addComboChart(data, frame: frame)
        let chart = try #require(try Presentation(data: try deck.serializedData()).charts.first)
        let area = try plotArea(of: chart)

        let barLabels = try #require(area.firstChild(named: "c:barChart")?
            .firstChild(named: "c:dLbls"))
        #expect(barLabels.firstChild(named: "c:dLblPos")?[attribute: "val"] == "outEnd")
        let lineLabels = try #require(area.firstChild(named: "c:lineChart")?
            .firstChild(named: "c:dLbls"))
        #expect(lineLabels.firstChild(named: "c:dLblPos")?[attribute: "val"] == "t",
                "a line's positions are not a bar's")

        // Colors are indexed within the group, so the line group's first series
        // is not painted with the bar group's first color.
        let barSeries = try #require(area.firstChild(named: "c:barChart")?
            .firstChild(named: "c:ser"))
        #expect(barSeries.firstChild(named: "c:spPr") != nil)
        let lineSeries = try #require(area.firstChild(named: "c:lineChart")?
            .firstChild(named: "c:ser"))
        #expect(lineSeries.firstChild(named: "c:spPr") == nil)
    }

    // MARK: - Refusals

    @Test func groupKindsWithoutASharedCategoryAxisAreRefused() throws {
        for kind in [ChartKind.pie, .doughnut, .radar, .radarFilled] {
            let data = ComboChartData(
                categories: ["A"],
                groups: [
                    .init(kind: .barClustered, series: [.init(name: "Bar", values: [1])]),
                    .init(kind: kind, series: [.init(name: "Other", values: [2])]),
                ])
            #expect(data.authoringProblem()
                    == .comboGroupKindNotSupported(kind: String(describing: kind)))
            let deck = try Presentation()
            #expect(throws: ChartAuthoringProblem.self) {
                try deck.slides[0].shapes.addComboChart(data, frame: frame)
            }
            #expect(deck.package.parts[PackURI("/ppt/charts/chart1.xml")] == nil,
                    "a refused chart must not leave a part behind")
        }
    }

    @Test func aComboNeedsSomethingOnThePrimaryAxis() throws {
        let data = ComboChartData(
            categories: ["A"],
            groups: [.init(kind: .line, series: [.init(name: "Only", values: [1])],
                           axis: .secondary)])
        #expect(data.authoringProblem() == .comboNeedsAPrimaryGroup)
    }

    @Test func twoBarGroupsOnOneAxisAreRefusedRatherThanSilentlyMerged() throws {
        // PowerPoint clusters every bar group on an axis pair together, so the
        // rendered chart would not be the one described.
        let data = ComboChartData(
            categories: ["A"],
            groups: [
                .init(kind: .barClustered, series: [.init(name: "One", values: [1])]),
                .init(kind: .barStacked, series: [.init(name: "Two", values: [2])]),
            ])
        #expect(data.authoringProblem() == .comboDuplicateBarGroup(axis: .primary))

        // The same two groups on different axis pairs are fine.
        let split = ComboChartData(
            categories: ["A"],
            groups: [
                .init(kind: .barClustered, series: [.init(name: "One", values: [1])]),
                .init(kind: .barStacked, series: [.init(name: "Two", values: [2])],
                      axis: .secondary),
            ])
        #expect(split.authoringProblem() == nil)
    }

    // MARK: - Invariants

    @Test func aComboIsDeterministicAndSurvivesRoundTrip() throws {
        func build() throws -> Data {
            let deck = try Presentation()
            try deck.slides[0].shapes.addComboChart(columnsAndLine, frame: frame,
                                                    options: ChartOptions(title: "Results"))
            return try deck.serializedData()
        }
        let original = try build()
        let again = try build()
        #expect(original == again)
        let reopened = try Presentation(data: original)
        _ = reopened.charts.first?.series
        #expect(try reopened.serializedData() == original)
    }

    @Test func replaceDataUpdatesEveryGroupOfAComboRostrumWrote() throws {
        // The whole point of global numbering: the flattened series order the
        // writer used is the order the reader and replaceData see.
        let deck = try Presentation()
        try deck.slides[0].shapes.addComboChart(columnsAndLine, frame: frame)
        let reopened = try Presentation(data: try deck.serializedData())
        let chart = try #require(reopened.charts.first)
        let replacement = ChartData(
            categories: ["Q1", "Q2", "Q3"],
            series: [.init(name: "Rev", values: [1, 2, 3]),
                     .init(name: "Cost", values: [4, 5, 6]),
                     .init(name: "Margin", values: [7, 8, 9])])
        #expect(chart.replacementProblem(for: replacement) == nil)
        try chart.replaceData(replacement)
        #expect(chart.series.map(\.name) == ["Rev", "Cost", "Margin"])
        #expect(chart.series[2].values == [7, 8, 9])
    }

    @Test func structuralSeriesEditsStayRefusedOnCombos() throws {
        // Authoring a combo does not make its series list editable: an added
        // series would have to pick a group, and inserting into group 0 shifts
        // the global index and workbook column of every later group.
        let deck = try Presentation()
        try deck.slides[0].shapes.addComboChart(columnsAndLine, frame: frame)
        let chart = try #require(try Presentation(data: try deck.serializedData()).charts.first)
        #expect(chart.addSeriesProblem(name: "X", values: [1, 2, 3])
                == .comboChartNotSupported(plotTypes: ["barChart", "lineChart"]))
        #expect(chart.removeSeriesProblem(at: 0)
                == .comboChartNotSupported(plotTypes: ["barChart", "lineChart"]))
    }

    @Test func theWorkbookHoldsEveryGroupsSeriesInOneSheet() throws {
        let deck = try Presentation()
        try deck.slides[0].shapes.addComboChart(columnsAndLine, frame: frame)
        let workbook = try #require(deck.charts.first?.workbookPart)
        let sheet = try ZipReader(data: workbook.blob).data(forEntry: "xl/worksheets/sheet1.xml")
        let text = try #require(String(data: sheet, encoding: .utf8))
        // The line group's series occupies column D, after the two bar series.
        #expect(text.contains("<c r=\"D2\" s=\"1\"><v>50</v></c>"))
        #expect(text.contains("<c r=\"B2\" s=\"1\"><v>10</v></c>"))
    }
}

@Suite struct DataLabelPositionLegalityTests {
    private let sample = ChartData(categories: ["A", "B"],
                                   series: [.init(name: "S", values: [1, 2])])
    private let frame = Rect(x: .zero, y: .zero, width: .inches(5), height: .inches(4))

    /// The `c:dLbls` a chart of `kind` gets when `position` is requested.
    /// Returns the element rather than an optional so callers need no
    /// `#require` — the macro rewrites a top-level call into a non-throwing
    /// closure, so a throwing helper cannot be called from inside one.
    private func labels(of kind: ChartKind, position: String) throws -> XML.Element {
        let deck = try Presentation()
        try deck.slides[0].shapes.addChart(
            kind, data: sample, frame: frame,
            options: ChartOptions(dataLabels: DataLabelOptions(showValue: true,
                                                               position: position)))
        let plotArea = try deck.package.part(at: PackURI("/ppt/charts/chart1.xml")).dom()
            .firstChild(named: "c:chart")?.firstChild(named: "c:plotArea")
        let plot = try #require(plotArea?.childElements.first { $0.name.hasSuffix("Chart") })
        return try #require(plot.firstChild(named: "c:dLbls"))
    }

    @Test func aLegalPositionSurvives() throws {
        let d = try labels(of: .barClustered, position: "outEnd")
        #expect(d.firstChild(named: "c:dLblPos")?[attribute: "val"] == "outEnd")
    }

    @Test func aStackedBarHasNoOutsideEnd() throws {
        // The next segment is there, so PowerPoint rejects outEnd on a stack.
        let d = try labels(of: .barStacked, position: "outEnd")
        #expect(d.firstChild(named: "c:dLblPos") == nil)
        #expect(d.firstChild(named: "c:showVal")?[attribute: "val"] == "1",
                "only the position is dropped, not the labels")
        let inEnd = try labels(of: .barStacked, position: "inEnd")
        #expect(inEnd.firstChild(named: "c:dLblPos")?[attribute: "val"] == "inEnd")
    }

    @Test func areaAndRadarTakeNoPositionAtAll() throws {
        for kind in [ChartKind.area, .radar, .radarFilled, .doughnut] {
            let d = try labels(of: kind, position: "ctr")
            #expect(d.firstChild(named: "c:dLblPos") == nil,
                    "\(kind) rejects c:dLblPos; emitting one is a repair prompt")
            #expect(d.firstChild(named: "c:showVal") != nil)
        }
    }

    @Test func linePositionsAreLeftAlone() throws {
        // Rostrum has no corroborated table for line/scatter/bubble, so it
        // imposes no restriction rather than silently dropping a caller's
        // intent on a guess.
        let d = try labels(of: .line, position: "t")
        #expect(d.firstChild(named: "c:dLblPos")?[attribute: "val"] == "t")
    }

    @Test func aPieKeepsItsFourPositionsAndDropsTheRest() throws {
        // Unlike doughnut, a pie does place labels — this commit narrowed it
        // from "anything the caller asks for" to the four tokens it accepts,
        // so both directions need pinning: too strict silently loses labels a
        // pie legitimately supports.
        let outEnd = try labels(of: .pie, position: "outEnd")
        #expect(outEnd.firstChild(named: "c:dLblPos")?[attribute: "val"] == "outEnd")
        let bestFit = try labels(of: .pie, position: "bestFit")
        #expect(bestFit.firstChild(named: "c:dLblPos")?[attribute: "val"] == "bestFit")

        let sideways = try labels(of: .pie, position: "t")
        #expect(sideways.firstChild(named: "c:dLblPos") == nil,
                "a pie has no top/bottom/left/right label positions")
        #expect(sideways.firstChild(named: "c:showVal")?[attribute: "val"] == "1")
    }

    @Test func theLegalityTableCoversRowsNoChartKindCanReach() throws {
        // ChartKind cannot produce c:ofPieChart, c:bar3DChart or a
        // percentStacked-only assertion, so those rows are pinned by calling
        // the table directly. Otherwise they are unfalsifiable decoration.
        func legal(_ plot: String, _ grouping: String? = nil) -> Set<String>? {
            ChartXML.legalDataLabelPositions(plot: plot, grouping: grouping)
        }
        #expect(legal("c:ofPieChart") == ["bestFit", "ctr", "inEnd", "outEnd"])
        #expect(legal("c:pieChart") == legal("c:ofPieChart"))
        #expect(legal("c:bar3DChart", "clustered") == ["ctr", "inBase", "inEnd", "outEnd"])
        #expect(legal("c:barChart", "percentStacked") == ["ctr", "inBase", "inEnd"],
                "a percent-stacked bar has no outside end either")
        #expect(legal("c:barChart", "stacked") == legal("c:barChart", "percentStacked"))
        // A bar group with no grouping attribute at all is treated as clustered.
        #expect(legal("c:barChart", nil) == ["ctr", "inBase", "inEnd", "outEnd"])
        #expect(legal("c:doughnutChart")?.isEmpty == true)
        #expect(legal("c:lineChart") == nil, "no corroborated table means no restriction")
        #expect(legal("c:scatterChart") == nil)
        #expect(legal("c:bubbleChart") == nil)
        #expect(legal("c:stockChart") == nil)
    }
}
