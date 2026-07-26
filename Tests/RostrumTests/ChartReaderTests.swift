import Foundation
import Testing
@testable import Rostrum

@Suite struct ChartReaderTests {
    private let frame = Rect(x: .inches(1), y: .inches(1), width: .inches(8), height: .inches(4))

    private func deckWithChart(
        _ kind: ChartKind = .barClustered,
        data: ChartData = ChartData(categories: ["Q1", "Q2", "Q3"],
                                    series: [.init(name: "Revenue", values: [10, 20, 30]),
                                             .init(name: "Cost", values: [5, 8, 11])])
    ) throws -> Presentation {
        let deck = try Presentation()
        try deck.slides[0].shapes.addChart(kind, data: data, frame: frame,
                                           options: ChartOptions(title: "Results"))
        return try Presentation(data: try deck.serializedData())
    }

    @Test func readsBackCategoriesSeriesAndTitle() throws {
        let chart = try #require(deckWithChart().charts.first)
        #expect(chart.plotType == "barChart")
        #expect(chart.title == "Results")
        #expect(chart.categories == ["Q1", "Q2", "Q3"])
        #expect(chart.series.map(\.name) == ["Revenue", "Cost"])
        #expect(chart.series[0].values == [10, 20, 30])
        #expect(chart.series[1].values == [5, 8, 11])

        let data = try #require(chart.data)
        #expect(data.categories == ["Q1", "Q2", "Q3"])
        #expect(data.series.count == 2)
    }

    @Test func readsEveryChartKindItCanWrite() throws {
        for kind in [ChartKind.barClustered, .barStacked, .barPercentStacked,
                     .line, .area, .pie, .doughnut] {
            let chart = try #require(deckWithChart(kind).charts.first)
            #expect(chart.plotType != nil, "\(kind) has no readable plot type")
            #expect(chart.categories == ["Q1", "Q2", "Q3"], "\(kind) categories")
            #expect(chart.series.first?.values == [10, 20, 30], "\(kind) values")
        }
    }

    @Test func gapsKeepTheirIndex() throws {
        let data = ChartData(categories: ["A", "B", "C"],
                             series: [.init(name: "S", values: [1, nil, 3])])
        let chart = try #require(deckWithChart(.line, data: data).charts.first)
        #expect(chart.series[0].values == [1, nil, 3])
    }

    @Test func chartsAreReachableFromTheShapeTree() throws {
        let deck = try deckWithChart()
        let frameShape = try #require(deck.slides[0].shapes.all.first { $0.kind == .chart } as? ChartFrame)
        #expect(frameShape.chart?.categories == ["Q1", "Q2", "Q3"])
        #expect(deck.charts.count == 1)
    }

    @Test func readingAChartDoesNotMutateIt() throws {
        let deck = try deckWithChart()
        let original = try deck.serializedData()
        let reopened = try Presentation(data: original)
        for chart in reopened.charts {
            _ = (chart.plotType, chart.title, chart.categories, chart.series, chart.data,
                 chart.workbookPart?.uri)
        }
        #expect(try reopened.serializedData() == original)
    }

    // MARK: - replaceData

    @Test func replaceDataUpdatesValuesNamesAndWorkbook() throws {
        let deck = try deckWithChart()
        let chart = try #require(deck.charts.first)
        let workbookBefore = try #require(chart.workbookPart?.blob)

        try chart.replaceData(ChartData(
            categories: ["FY24", "FY25", "FY26"],
            series: [.init(name: "Net revenue", values: [11, 22, 33]),
                     .init(name: "Net cost", values: [6, 9, 12])]))

        let reopened = try Presentation(data: try deck.serializedData())
        let updated = try #require(reopened.charts.first)
        #expect(updated.categories == ["FY24", "FY25", "FY26"])
        #expect(updated.series.map(\.name) == ["Net revenue", "Net cost"])
        #expect(updated.series[0].values == [11, 22, 33])
        #expect(updated.series[1].values == [6, 9, 12])
        // Edit Data must show the new numbers, not the old ones.
        #expect(updated.workbookPart?.blob != workbookBefore)
        #expect(try reopened.validate().isEmpty)
    }

    @Test func replaceDataPreservesFormattingAndFormulas() throws {
        let deck = try deckWithChart()
        let chart = try #require(deck.charts.first)
        let before = try #require(try chart.part.dom())
        let formulasBefore = Self.formulas(in: before)
        let colorsBefore = Self.colors(in: before)
        #expect(!formulasBefore.isEmpty)

        try chart.replaceData(ChartData(categories: ["A", "B", "C"],
                                        series: [.init(name: "One", values: [1, 2, 3]),
                                                 .init(name: "Two", values: [4, 5, 6])]))

        let after = try #require(try chart.part.dom())
        #expect(Self.formulas(in: after) == formulasBefore, "c:f formulas must survive untouched")
        #expect(Self.colors(in: after) == colorsBefore, "series colors must survive untouched")
        #expect(after.firstChild(named: "c:chart")?.firstChild(named: "c:title") != nil)
    }

    @Test func replaceDataRefusesStructuralChanges() throws {
        let deck = try deckWithChart()
        let chart = try #require(deck.charts.first)
        let before = XML.document(try chart.part.dom())

        // Too few series.
        let fewer = ChartData(categories: ["Q1", "Q2", "Q3"],
                              series: [.init(name: "Only", values: [1, 2, 3])])
        #expect(chart.replacementProblem(for: fewer)
                == .seriesCountMismatch(chart: 2, replacement: 1))
        #expect(throws: Chart.ReplacementProblem.self) { try chart.replaceData(fewer) }

        // Wrong category count.
        let shorter = ChartData(categories: ["Q1", "Q2"],
                                series: [.init(name: "Revenue", values: [1, 2]),
                                         .init(name: "Cost", values: [3, 4])])
        #expect(chart.replacementProblem(for: shorter)
                == .categoryCountMismatch(chart: 3, replacement: 2))
        #expect(throws: Chart.ReplacementProblem.self) { try chart.replaceData(shorter) }

        // Nothing was written on either refusal — this is the whole point:
        // python-pptx's equivalent writes first and corrupts on mismatch.
        #expect(XML.document(try chart.part.dom()) == before)
        #expect(try deck.validate().isEmpty)
    }

    @Test func replaceDataAcceptsAFittingReplacement() throws {
        let deck = try deckWithChart()
        let chart = try #require(deck.charts.first)
        let fitting = ChartData(categories: ["X", "Y", "Z"],
                                series: [.init(name: "A", values: [1, 2, 3]),
                                         .init(name: "B", values: [4, 5, 6])])
        #expect(chart.replacementProblem(for: fitting) == nil)
        try chart.replaceData(fitting)
        #expect(chart.categories == ["X", "Y", "Z"])
    }

    @Test func replaceDataIsDeterministic() throws {
        func build() throws -> Data {
            let deck = try deckWithChart()
            try deck.charts.first!.replaceData(ChartData(
                categories: ["A", "B", "C"],
                series: [.init(name: "One", values: [1.5, 2.25, 3]),
                         .init(name: "Two", values: [4, nil, 6])]))
            return try deck.serializedData()
        }
        #expect(try build() == build())
    }

    @Test func replaceDataRoundTripsThroughPythonPptxShapedXML() throws {
        // Gaps must stay gaps, and ptCount must match the new length.
        let deck = try deckWithChart()
        let chart = try #require(deck.charts.first)
        try chart.replaceData(ChartData(categories: ["A", "B", "C"],
                                        series: [.init(name: "One", values: [1, nil, 3]),
                                                 .init(name: "Two", values: [nil, nil, nil])]))
        let reopened = try Presentation(data: try deck.serializedData())
        let updated = try #require(reopened.charts.first)
        #expect(updated.series[0].values == [1, nil, 3])
        #expect(updated.series[1].values == [nil, nil, nil])

        let dom = try #require(try updated.part.dom())
        for cache in Self.descendants(of: dom, named: "c:numCache") {
            let ptCount = cache.firstChild(named: "c:ptCount")?[attribute: "val"]
            #expect(ptCount == "3", "ptCount not updated with the new data")
        }
    }

    // MARK: - Helpers

    private static func descendants(of element: XML.Element, named name: String) -> [XML.Element] {
        var found: [XML.Element] = []
        if element.name == name { found.append(element) }
        for child in element.childElements { found += descendants(of: child, named: name) }
        return found
    }

    private static func formulas(in dom: XML.Element) -> [String] {
        descendants(of: dom, named: "c:f").map(\.textContent)
    }

    private static func colors(in dom: XML.Element) -> [String] {
        descendants(of: dom, named: "a:srgbClr").compactMap { $0[attribute: "val"] }
    }
}
