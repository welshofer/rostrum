import Foundation
import Testing
@testable import Rostrum

@Suite struct MeasuredChartLayoutTests {
    private let frame = Rect(x: .points(30), y: .points(25), width: .points(640), height: .points(350))
    private func descendants(_ node: XML.Element, _ name: String) -> [XML.Element] {
        (node.name == name ? [node] : []) + node.childElements.flatMap { descendants($0, name) }
    }
    private func make(_ kind: ChartKind = .barClustered, categories: [String] = ["A", "B"],
                      series: [ChartData.Series] = [.init(name: "Series", values: [25, 75])],
                      options: ChartOptions = .init()) throws -> Presentation {
        let deck = try Presentation()
        try deck.fonts.register(TestFont.standard(familyName: "Measured"))
        var options = options
        options.text = .init(font: "Measured", color: Color("112233"), sizePt: 12)
        try deck.slides[0].shapes.addChart(kind, data: ChartData(categories: categories, series: series), frame: frame, options: options)
        return deck
    }
    private func groups(_ deck: Presentation, role: String) throws -> [XML.Element] {
        descendants(try XML.parse(Data(deck.renderSVG(slideAt: 0).utf8)), "g").filter { $0[attribute: "data-rostrum-chart-role"] == role }
    }
    private func bounds(_ group: XML.Element) throws -> ChartTextRect {
        let values = try #require(group[attribute: "data-rostrum-chart-bounds"]).split(separator: " ").compactMap { Double($0) }
        #expect(values.count == 4)
        return ChartTextRect(x: values[0], y: values[1], width: values[2], height: values[3])
    }
    private func assertContained(_ deck: Presentation) throws {
        let svg = try XML.parse(Data(deck.renderSVG(slideAt: 0).utf8))
        let rect = ChartTextRect(x: 30 * 12700, y: 25 * 12700, width: 640 * 12700, height: 350 * 12700)
        for group in descendants(svg, "g") where group[attribute: "data-rostrum-chart-bounds"] != nil {
            #expect(rect.contains(try bounds(group)), "\(group.textContent)")
        }
    }

    @Test func registeredGlyphWidthsAndWholeWordsDetermineWrapping() throws {
        let fonts = FontLibrary()
        try fonts.register(TestFont.standard(familyName: "Measured"))
        let measurer = ChartTextMeasurer(fonts: fonts) { _, _, _ in }
        let style = ChartTextMeasurer.Style(face: FontFaceKey(family: "Measured"), size: 10 * 12700)
        let narrow = try #require(measurer.block("iiii iiii", style: style, width: 20 * 12700))
        let wide = try #require(measurer.block("WW WW", style: style, width: 20 * 12700))
        #expect(narrow.lines.map(\.text) == ["iiii iiii"])
        #expect(abs(narrow.width / 12700 - 18.5) < 0.001)
        #expect(wide.lines.map(\.text) == ["WW", "WW"])
        #expect(wide.lines.allSatisfy { abs($0.width / 12700 - 18) < 0.001 })
        #expect(wide.height > narrow.height)
    }

    @Test func compoundCategoriesBreakAtDashesAndKeepNonbreakingSpaces() throws {
        let fonts = FontLibrary()
        try fonts.register(TestFont.standard(familyName: "Measured"))
        let measure = ChartTextMeasurer(fonts: fonts) { _, _, _ in }
        let style = ChartTextMeasurer.Style(face: FontFaceKey(family: "Measured"), size: 10 * 12700)
        let compound = try #require(measure.block("Industry-academia", style: style, width: 65 * 12700))
        #expect(compound.lines.map(\.text) == ["Industry-", "academia"])
        let explicit = try #require(measure.block("First\r\nSecond", style: style, width: 65 * 12700))
        #expect(explicit.lines.map(\.text) == ["First", "Second"])
        #expect(measure.block("VeryLong\u{00A0}NonbreakingWord", style: style, width: 40 * 12700) == nil)
    }

    @Test func nativeAdvanceIsReusedWithinAnOperationButFreshOnTheNext() throws {
        let fonts = FontLibrary()
        try fonts.register(TestFont.standard(familyName: "Measured"))
        var calls = 0
        fonts.previewAdvance = { _, _, _, _, _ in calls += 1; return 25 }
        let style = ChartTextMeasurer.Style(face: FontFaceKey(family: "Measured"), size: 10 * 12700)
        let first = ChartTextMeasurer(fonts: fonts) { _, _, _ in }
        #expect(first.width("Value", style: style) == 25 * 12700)
        #expect(first.width("Value", style: style) == 25 * 12700)
        #expect(calls == 1)
        fonts.previewAdvance = { _, _, _, _, _ in calls += 1; return 35 }
        let second = ChartTextMeasurer(fonts: fonts) { _, _, _ in }
        #expect(second.width("Value", style: style) == 35 * 12700)
        #expect(calls == 2)
    }

    @Test func axesReserveMeasuredWidthsAndRereadFontChanges() throws {
        let deck = try make(categories: ["WWWWWWWWWWWWWW", "iiiiiiiiiiiiii"], options: .init(
            title: "A wide measured chart title", legend: .bottom,
            dataLabels: .init(showValue: true), valueAxis: .init(numberFormat: "0\" long units\"")))
        let part = try deck.package.part(at: PackURI("/ppt/charts/chart1.xml"))
        let root = try part.dom()
        let plot = try #require(descendants(root, "c:barChart").first)
        plot.firstChild(named: "c:barDir")?[attribute: "val"] = "bar"
        part.markDirty()
        let saved = try deck.serializedData()
        let before = try deck.renderSVG(slideAt: 0)
        let cats = try groups(deck, role: "category")
        #expect(cats.count == 2)
        let width = try bounds(cats[0]).width
        #expect(try width > bounds(cats[1]).width * 3)
        try assertContained(deck)
        // An operation must observe the replaced font file/alias, not stale widths.
        let altered = TestFont.assemble(tables: [
            ("head", TestFont.head(upem: 1000)),
            ("hhea", TestFont.hhea(ascender: 800, descender: -200, lineGap: 0, numberOfHMetrics: 96)),
            ("maxp", TestFont.maxp(numGlyphs: 96)),
            ("hmtx", TestFont.hmtx(advances: Array(repeating: 400, count: 96))),
            ("cmap", TestFont.cmapFormat4()), ("name", TestFont.nameTable(family: "Measured"))])
        try deck.fonts.register(Data(altered))
        #expect(try deck.renderSVG(slideAt: 0) != before)
        #expect(try deck.serializedData() == saved)
        #expect(try deck.renderSVG(slideAt: 0) == deck.renderSVG(slideAt: 0))
    }

    @Test func categoriesAndLegendsHaveNoArbitraryTwelveOrSixEntryCutoff() throws {
        let names = (1...16).map { "C\($0)" }
        let entries = (1...8).map { ChartData.Series(name: "Team \($0)", values: Array(repeating: Double($0), count: 16)) }
        for position in [LegendPosition.bottom, .right, .top, .left] {
            let deck = try make(categories: names, series: entries, options: .init(legend: position))
            #expect(try groups(deck, role: "category").count == 16)
            #expect(try groups(deck, role: "legend").count == 8)
            try assertContained(deck)
        }
    }

    @Test func lineLabelsKeepGapsAndPerPointOverridesAndStayOutsideTheClip() throws {
        let deck = try make(.line, categories: ["First", "Gap", "Third", "Last"],
            series: [.init(name: "S", values: [10, nil, 30, 20])], options: .init(
                dataLabels: .init(showValue: true, numberFormat: "0\" units\"", position: "t")))
        let chart = try deck.package.part(at: PackURI("/ppt/charts/chart1.xml"))
        let series = try #require(descendants(chart.dom(), "c:ser").first)
        series.appendElement(try XML.parse(Data("<c:dLbls><c:dLbl><c:idx val=\"3\"/><c:delete val=\"1\"/></c:dLbl></c:dLbls>".utf8)))
        chart.markDirty()
        let saved = try deck.serializedData()
        let reopened = try Presentation(data: saved)
        try reopened.fonts.register(TestFont.standard(familyName: "Measured"))
        let labels = try groups(reopened, role: "data-label")
        #expect(labels.map(\.textContent) == ["10 units", "30 units"])
        let svg = try XML.parse(Data(reopened.renderSVG(slideAt: 0).utf8))
        let clipped = descendants(svg, "svg").filter { $0[attribute: "overflow"] == "hidden" }
        #expect(!clipped.isEmpty)
        #expect(clipped.allSatisfy { descendants($0, "g").isEmpty })
        try assertContained(reopened)
        #expect(try reopened.serializedData() == saved)
    }

    @Test func pieLabelsRenderPercentagesAndPackWithoutCollisions() throws {
        for kind in [ChartKind.pie, .doughnut] {
            let deck = try make(kind, categories: ["First contribution", "Second contribution", "Third contribution", "Final contribution"],
                series: [.init(name: "Shares", values: [15, 25, 20, 40])], options: .init(
                    legend: .bottom, dataLabels: .init(showCategory: true, showPercent: true, numberFormat: "0%", position: "outEnd")))
            let labels = try groups(deck, role: "data-label")
            #expect(labels.count == 4)
            for percent in ["15%", "25%", "20%", "40%"] { #expect(labels.contains { $0.textContent.contains(percent) }) }
            for i in labels.indices {
                for j in labels.indices where i < j { #expect(try !bounds(labels[i]).intersects(bounds(labels[j]))) }
            }
            try assertContained(deck)
        }
    }

    @Test func denseDataLabelsAreDiagnosedRatherThanOverlapping() throws {
        let categories = (1...80).map { "Category \($0)" }
        let deck = try make(categories: categories, series: [.init(name: "S", values: Array(repeating: 50, count: 80))],
            options: .init(dataLabels: .init(showValue: true, numberFormat: "0\" points\"")))
        let result = try deck.renderSVGReportingProblems(slideAt: 0)
        #expect(result.problems.fidelityIssues.contains { $0.impact == .omission && $0.message.contains("data labels") })
        let labels = try groups(deck, role: "data-label")
        #expect(labels.count > 0 && labels.count < 80)
        for i in labels.indices {
            for j in labels.indices where i < j { #expect(try !bounds(labels[i]).intersects(bounds(labels[j]))) }
        }
        try assertContained(deck)
    }

    @Test func pieValueAndPercentLabelsKeepDistinctDefaultUnits() throws {
        let deck = try make(.pie, categories: ["A", "B"], series: [.init(name: "Shares", values: [30, 90])],
            options: .init(dataLabels: .init(showValue: true, showPercent: true, position: "outEnd")))
        let bytes = try deck.serializedData()
        let reopened = try Presentation(data: bytes)
        try reopened.fonts.register(TestFont.standard(familyName: "Measured"))
        #expect(Set(try groups(reopened, role: "data-label").map(\.textContent)) == ["30, 25%", "90, 75%"])
        #expect(try reopened.serializedData() == bytes)
    }

    @Test(arguments: [1.0, 1e306])
    func percentStackedGeometryUsesFractionalAxisUnits(multiplier: Double) throws {
        let deck = try make(.barPercentStacked, categories: ["Only"], series: [
            .init(name: "A", values: [25 * multiplier]), .init(name: "B", values: [75 * multiplier])], options: .init(
                valueAxis: .init(min: 0, max: 1, majorUnit: 0.25, numberFormat: "0%")))
        let svg = try XML.parse(Data(deck.renderSVG(slideAt: 0).utf8))
        let bars = descendants(svg, "rect").filter { $0[attribute: "fill"] != "#FFFFFF" }
        #expect(bars.count == 2)
        let heights = try bars.map { try #require(Double($0[attribute: "height"] ?? "")) }
        #expect(abs(heights[1] / heights[0] - 3) < 0.001)
        #expect(try groups(deck, role: "value-axis").contains { $0.textContent == "100%" })
    }

    @Test func inheritedKerningThresholdUsesTheFinalAxisFontSize() throws {
        let deck = try make()
        let root = try deck.package.part(at: PackURI("/ppt/charts/chart1.xml")).dom()
        let defaults = try #require(root.firstChild(named: "c:txPr")?.firstChild(named: "a:p")?
            .firstChild(named: "a:pPr")?.firstChild(named: "a:defRPr"))
        defaults[attribute: "kern"] = "1800"
        let axis = try #require(descendants(root, "c:valAx").first)
        axis.appendElement(try XML.parse(Data("<c:txPr><a:bodyPr/><a:lstStyle/><a:p><a:pPr><a:defRPr sz=\"2400\"/></a:pPr></a:p></c:txPr>".utf8)))
        let ticks = try groups(deck, role: "value-axis").flatMap { $0.children(named: "text") }
        let categories = try groups(deck, role: "category").flatMap { $0.children(named: "text") }
        #expect(!ticks.isEmpty && !categories.isEmpty)
        #expect(ticks.allSatisfy { $0[attribute: "font-kerning"] == "normal" })
        #expect(categories.allSatisfy { $0[attribute: "font-kerning"] == "none" })
    }

    @Test func hiddenAxesAndAuthoredTickSkippingAreRespected() throws {
        let names = (1...16).map { "C\($0)" }
        let deck = try make(categories: names, series: [.init(name: "S", values: Array(repeating: 3, count: 16))],
            options: .init(valueAxis: .init(title: "Hidden value title", hidden: true), categoryAxisTitle: "Visible category title"))
        let root = try deck.package.part(at: PackURI("/ppt/charts/chart1.xml")).dom()
        let axis = try #require(descendants(root, "c:catAx").first)
        axis.appendElement(XML.Element("c:tickLblSkip", attributes: [("val", "2")]))
        #expect(try groups(deck, role: "value-axis").isEmpty)
        let titles = try groups(deck, role: "axis-title").map(\.textContent)
        #expect(titles == ["Visible category title"])
        #expect(try groups(deck, role: "category").map(\.textContent) == stride(from: 1, through: 16, by: 2).map { "C\($0)" })
        #expect(try !deck.renderSVGReportingProblems(slideAt: 0).problems.fidelityIssues.contains {
            $0.impact == .omission && $0.message.contains("category labels")
        })
    }

    @Test func axisTitlesAndLongCategoriesSurviveSavedPreview() throws {
        let deck = try make(categories: ["First category with multiple words", "Second category with multiple words"],
            options: .init(valueAxis: .init(title: "Annual contribution in measured units"), categoryAxisTitle: "Survey groups"))
        let bytes = try deck.serializedData()
        let reopened = try Presentation(data: bytes)
        try reopened.fonts.register(TestFont.standard(familyName: "Measured"))
        #expect(try groups(reopened, role: "axis-title").count == 2)
        #expect(try groups(reopened, role: "category").count == 2)
        #expect(try !reopened.renderSVG(slideAt: 0).contains("…"))
        try assertContained(reopened)
        #expect(try reopened.serializedData() == bytes)
    }

    @Test func topEndpointTickClearsAnAuthoredFrameEdgeAnnotation() throws {
        let deck = try make(.line, categories: ["First", "Last"], series: [.init(name: "S", values: [8.5, 5.9])],
            options: .init(valueAxis: .init(min: 5, max: 9, majorUnit: 1, numberFormat: "0.0")))
        // The source deck's independent annotation begins above the chart and
        // extends into its top edge. Its position must not be rewritten.
        let annotation = ChartTextRect(x: 33 * 12700, y: 19 * 12700, width: 65 * 12700, height: 15 * 12700)
        let ticks = try groups(deck, role: "value-axis")
        #expect(ticks.count == 5)
        for tick in ticks { #expect(try !bounds(tick).intersects(annotation)) }
        try assertContained(deck)
    }
}
