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
        // Pass explicit colors: a default-written chart carries no a:srgbClr
        // at all, so asserting colors survive would otherwise be vacuous.
        let deck = try Presentation()
        try deck.slides[0].shapes.addChart(
            .barClustered,
            data: ChartData(categories: ["Q1", "Q2", "Q3"],
                            series: [.init(name: "Revenue", values: [10, 20, 30]),
                                     .init(name: "Cost", values: [5, 8, 11])]),
            frame: frame, colors: [Color("18A999"), Color("FF6B5E")],
            options: ChartOptions(title: "Results"))
        let reopened = try Presentation(data: try deck.serializedData())
        let chart = try #require(reopened.charts.first)
        let before = try #require(try chart.part.dom())
        let formulasBefore = Self.formulas(in: before)
        let colorsBefore = Self.colors(in: before)
        #expect(!formulasBefore.isEmpty)
        #expect(colorsBefore.contains("18A999") && colorsBefore.contains("FF6B5E"),
                "fixture must actually carry series colors for this test to mean anything")

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

    @Test func refusesWhenTheWorkbookLayoutIsForeign() throws {
        // The blocker case: a template chart whose formulas name another
        // sheet or range. Rewriting the workbook from Rostrum's canonical
        // layout would leave Edit Data pointing at cells that do not exist,
        // so the replacement must be refused before anything is written.
        let deck = try deckWithChart()
        let chart = try #require(deck.charts.first)
        let dom = try #require(try chart.part.dom())
        for f in Self.descendants(of: dom, named: "c:f") where f.textContent.contains("$A$") {
            f.children = [.text("Data!$C$5:$C$7")]
        }
        chart.part.markDirty()
        let before = XML.document(try chart.part.dom())

        let fitting = ChartData(categories: ["A", "B", "C"],
                                series: [.init(name: "One", values: [1, 2, 3]),
                                         .init(name: "Two", values: [4, 5, 6])])
        #expect(chart.replacementProblem(for: fitting)
                == .workbookLayoutNotRecognized(formula: "Data!$C$5:$C$7"))
        #expect(throws: Chart.ReplacementProblem.self) { try chart.replaceData(fitting) }
        #expect(XML.document(try chart.part.dom()) == before)
    }

    @Test func refusesANumericCategoryAxis() throws {
        // Writing category strings into a date/numeric axis's numeric cache
        // corrupts the axis; refuse instead.
        let deck = try deckWithChart()
        let chart = try #require(deck.charts.first)
        let dom = try #require(try chart.part.dom())
        for cat in Self.descendants(of: dom, named: "c:cat") {
            guard let ref = cat.firstChild(named: "c:strRef") else { continue }
            let numRef = XML.Element("c:numRef")
            for child in ref.childElements {
                numRef.appendElement(child.name == "c:strCache"
                                     ? Self.renamed(child, to: "c:numCache") : child)
            }
            cat.removeChildren(named: "c:strRef")
            cat.appendElement(numRef)
        }
        chart.part.markDirty()

        let replacement = ChartData(categories: ["A", "B", "C"],
                                    series: [.init(name: "One", values: [1, 2, 3]),
                                             .init(name: "Two", values: [4, 5, 6])])
        #expect(chart.replacementProblem(for: replacement) == .categoryAxisIsNotText(index: 0))
        #expect(throws: Chart.ReplacementProblem.self) { try chart.replaceData(replacement) }
    }

    @Test func refusesAMultiLevelCategoryAxis() throws {
        let deck = try deckWithChart()
        let chart = try #require(deck.charts.first)
        let dom = try #require(try chart.part.dom())
        for cat in Self.descendants(of: dom, named: "c:cat") {
            cat.children = [.element(XML.Element("c:multiLvlStrRef"))]
        }
        chart.part.markDirty()
        let replacement = ChartData(categories: ["A", "B", "C"],
                                    series: [.init(name: "One", values: [1, 2, 3]),
                                             .init(name: "Two", values: [4, 5, 6])])
        // Categories read as empty, but the refusal names the real reason
        // rather than a misleading count mismatch.
        #expect(chart.replacementProblem(for: replacement) != nil)
    }

    @Test func comboChartsSeeEveryPlotGroup() throws {
        // A plotArea may hold several plot groups; reading only the first
        // reports half a chart and would let replaceData half-update it.
        let deck = try deckWithChart()
        let chart = try #require(deck.charts.first)
        let dom = try #require(try chart.part.dom())
        let plotArea = try #require(dom.firstChild(named: "c:chart")?.firstChild(named: "c:plotArea"))
        let bar = try #require(plotArea.childElements.first { $0.name == "c:barChart" })
        // Move the second series into a new lineChart group, as a combo does.
        let secondSeries = bar.children(named: "c:ser")[1]
        bar.removeChild(secondSeries)
        let line = XML.Element("c:lineChart")
        line.appendElement(secondSeries)
        plotArea.insertChild(line, beforeAnyOf: ["c:catAx", "c:valAx"])
        chart.part.markDirty()

        #expect(chart.plotTypes == ["barChart", "lineChart"])
        #expect(chart.isCombo)
        #expect(chart.seriesElements.count == 2)
        #expect(chart.series.map(\.name) == ["Revenue", "Cost"])
        // And a fitting replacement updates BOTH groups.
        try chart.replaceData(ChartData(categories: ["A", "B", "C"],
                                        series: [.init(name: "One", values: [1, 2, 3]),
                                                 .init(name: "Two", values: [4, 5, 6])]))
        #expect(chart.series.map(\.name) == ["One", "Two"])
        #expect(chart.series[1].values == [4, 5, 6])
    }

    @Test func literalSeriesNameReadsBack() throws {
        // CT_SerTx is a choice: c:strRef OR a bare c:v.
        let deck = try deckWithChart()
        let chart = try #require(deck.charts.first)
        // The SERIES' c:tx specifically — the chart title has one too, and it
        // comes first in document order.
        let tx = try #require(chart.seriesElements.first?.firstChild(named: "c:tx"))
        let v = XML.Element("c:v")
        v.children = [.text("Literal name")]
        tx.children = [.element(v)]
        chart.part.markDirty()
        #expect(chart.series.first?.name == "Literal name")
        // And it is refused rather than silently skipped on write.
        let replacement = ChartData(categories: ["A", "B", "C"],
                                    series: [.init(name: "One", values: [1, 2, 3]),
                                             .init(name: "Two", values: [4, 5, 6])])
        #expect(chart.replacementProblem(for: replacement)
                == .seriesNotWritable(index: 0, missing: "a writable cache in c:tx"))
    }

    @Test func cachesWithoutPtCountStillRead() throws {
        let deck = try deckWithChart()
        let chart = try #require(deck.charts.first)
        let dom = try #require(try chart.part.dom())
        for cache in Self.descendants(of: dom, named: "c:numCache") {
            cache.removeChildren(named: "c:ptCount")
        }
        chart.part.markDirty()
        // c:ptCount is optional; sizing falls back to the highest c:pt index.
        #expect(chart.series[0].values == [10, 20, 30])
    }

    @Test func chartsInsideGroupsAreFound() throws {
        let deck = try deckWithChart()
        let slide = try deck.slides[0]
        let tree = try #require(Slide.existingSpTree(of: slide.part))
        let chartFrame = try #require(tree.childElements.first { $0.name == "p:graphicFrame" })
        // Wrap the chart in a group, as a real deck often does.
        tree.removeChild(chartFrame)
        let group = XML.Element("p:grpSp")
        let nv = XML.Element("p:nvGrpSpPr")
        nv.appendElement(XML.Element("p:cNvPr", attributes: [("id", "99"), ("name", "Group")]))
        nv.appendElement(XML.Element("p:cNvGrpSpPr"))
        nv.appendElement(XML.Element("p:nvPr"))
        group.appendElement(nv)
        group.appendElement(XML.Element("p:grpSpPr"))
        group.appendElement(chartFrame)
        tree.appendElement(group)
        slide.part.markDirty()

        #expect(deck.charts.count == 1, "a chart nested in a group must still be found")
        #expect(deck.charts.first?.categories == ["Q1", "Q2", "Q3"])
    }

    // MARK: - Helpers

    private static func renamed(_ element: XML.Element, to name: String) -> XML.Element {
        let copy = XML.Element(name, attributes: element.attributes.map { ($0.name, $0.value) })
        copy.children = element.children
        return copy
    }

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
