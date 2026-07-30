import Foundation
import Testing
@testable import Rostrum

/// How a chart *looks*: the typography it draws its own text in, whether a
/// labelled chart still carries a redundant scale, and — the regression that
/// prompted all three — whether a label printed inside a dark segment can
/// actually be read.
@Suite struct ChartAppearanceTests {
    private let frame = Rect(x: .inches(1), y: .inches(1), width: .inches(6), height: .inches(4))
    private var sample: ChartData {
        ChartData(categories: ["A", "B"],
                  series: [ChartData.Series(name: "one", values: [3, 5]),
                           ChartData.Series(name: "two", values: [2, 4])])
    }

    private func chartDOM(_ kind: ChartKind, colors: [Color]? = nil,
                          options: ChartOptions) throws -> XML.Element {
        let deck = try Presentation()
        try deck.slides[0].shapes.addChart(kind, data: sample, frame: frame,
                                           colors: colors, options: options)
        return try deck.package.part(at: PackURI("/ppt/charts/chart1.xml")).dom()
    }

    private func plot(_ dom: XML.Element) throws -> XML.Element {
        let plotArea = dom.firstChild(named: "c:chart")?.firstChild(named: "c:plotArea")
        return try #require(plotArea?.childElements.first { $0.name.hasSuffix("Chart") })
    }

    /// The bug: a stacked bar labels inside its own segment, and the label
    /// inherited the chart's text color. On a dark series that printed
    /// black-on-black and the numbers simply vanished from the deck.
    @Test func labelsInsideADarkSegmentAreLightEnoughToRead() throws {
        let dark = Color("1A1A1A")
        let light = Color("EDEDED")
        let dom = try chartDOM(.barStacked, colors: [dark, light],
                               options: ChartOptions(dataLabels: DataLabelOptions(showValue: true,
                                                                                  position: "ctr")))
        let series = try plot(dom).children(named: "c:ser")
        #expect(series.count == 2)
        // Each series carries its own labels so each can contrast with the fill
        // it is printed on.
        let colors = series.map { ser in
            ser.firstChild(named: "c:dLbls")?.firstChild(named: "c:txPr")?
                .firstChild(named: "a:p")?.firstChild(named: "a:pPr")?
                .firstChild(named: "a:defRPr")?.firstChild(named: "a:solidFill")?
                .firstChild(named: "a:srgbClr")?[attribute: "val"]
        }
        let onDark = try #require(colors[0])
        let onLight = try #require(colors[1])
        #expect(Color(onDark).contrastRatio(with: dark) >= 4.5)
        #expect(Color(onLight).contrastRatio(with: light) >= 4.5)
        #expect(onDark != onLight, "both segments got the same label color")
    }

    /// A label beside the bar sits on the slide, not on the fill, so it keeps
    /// one set of labels for the whole plot.
    @Test func labelsOutsideTheBarStayAtPlotLevel() throws {
        let dom = try chartDOM(.barClustered,
                               options: ChartOptions(dataLabels: DataLabelOptions(showValue: true,
                                                                                  position: "outEnd")))
        let bar = try plot(dom)
        #expect(bar.firstChild(named: "c:dLbls") != nil)
        #expect(bar.children(named: "c:ser").allSatisfy { $0.firstChild(named: "c:dLbls") == nil })
    }

    @Test func chartTextCarriesTheDecksTypefaceAndSize() throws {
        let dom = try chartDOM(.barClustered,
                               options: ChartOptions(text: ChartTextStyle(font: "Baton Turbo",
                                                                          color: Color("556677"),
                                                                          sizePt: 11)))
        let defRPr = try #require(dom.firstChild(named: "c:txPr")?.firstChild(named: "a:p")?
            .firstChild(named: "a:pPr")?.firstChild(named: "a:defRPr"))
        #expect(defRPr[attribute: "sz"] == "1100")
        #expect(defRPr.firstChild(named: "a:latin")?[attribute: "typeface"] == "Baton Turbo")
        #expect(defRPr.firstChild(named: "a:solidFill")?
            .firstChild(named: "a:srgbClr")?[attribute: "val"] == "556677")
    }

    @Test func aLabelledChartCanDropItsRedundantScale() throws {
        let axis = AxisOptions(hidden: true, gridlines: false)
        let dom = try chartDOM(.barClustered, options: ChartOptions(valueAxis: axis))
        let valAx = try #require(dom.firstChild(named: "c:chart")?
            .firstChild(named: "c:plotArea")?.firstChild(named: "c:valAx"))
        #expect(valAx.firstChild(named: "c:delete")?[attribute: "val"] == "1")
        #expect(valAx.firstChild(named: "c:majorGridlines") == nil)

        // Default stays as it was: the scale is only dropped when asked for.
        let plain = try chartDOM(.barClustered, options: ChartOptions())
        let plainAx = try #require(plain.firstChild(named: "c:chart")?
            .firstChild(named: "c:plotArea")?.firstChild(named: "c:valAx"))
        #expect(plainAx.firstChild(named: "c:delete")?[attribute: "val"] == "0")
    }

    /// Whatever the styling does, the file still has to open without PowerPoint
    /// offering to repair it.
    @Test func styledChartsStillValidate() throws {
        for kind in [ChartKind.barClustered, .barStacked, .barPercentStacked, .line, .area] {
            let deck = try Presentation()
            try deck.chartSlide("T", kind, sample,
                                options: ChartOptions(dataLabels: DataLabelOptions(showValue: true,
                                                                                   position: "ctr"),
                                                      valueAxis: AxisOptions(hidden: true)))
            #expect(try deck.validate().isEmpty, "\(kind) needed repair")
        }
    }

    /// Chart text is drawn on the slide, so it has to clear the slide's own
    /// background. Muted ink reads as "quiet" on a light deck and as
    /// "invisible" on a dark one.
    @Test func chartTextClearsContrastOnLightAndDarkDecks() throws {
        for background in ["FFFFFF", "000000", "0B1D33"] {
            let deck = try Presentation()
            deck.applyDesign(Design.parse("## Palette\n- Background: #\(background)\n- Accent 1: #18A999"))
            try deck.chartSlide("T", .barClustered, sample)
            let chart = try deck.package.part(at: PackURI("/ppt/charts/chart1.xml")).dom()
            let hex = try #require(chart.firstChild(named: "c:txPr")?.firstChild(named: "a:p")?
                .firstChild(named: "a:pPr")?.firstChild(named: "a:defRPr")?
                .firstChild(named: "a:solidFill")?.firstChild(named: "a:srgbClr")?[attribute: "val"])
            #expect(Color(hex).contrastRatio(with: Color(background)) >= 4.5,
                    "chart text #\(hex) is unreadable on #\(background)")
        }
    }
    /// Chart fills are graphical objects, so WCAG's bar is 3:1 against the
    /// background — and many designs use their later accents as *surface
    /// tints*, which is fine behind a card and invisible as a bar.
    @Test func plotColorsClearContrastEvenWhenTheAccentsAreSurfaceTints() throws {
        let deck = try Presentation()
        deck.applyDesign(Design.parse(
            "## Palette\n- Background: #FFFFFF\n- Text: #1A1A1A\n"
            + "- Accent 1: #E7E0D3\n- Accent 2: #C0186D\n- Accent 3: #F2E4EC"))
        let style = deck.style
        // The tints are genuinely invisible as bars to begin with.
        #expect(style.accent(1).contrastRatio(with: style.background) < 3)
        #expect(style.accent(3).contrastRatio(with: style.background) < 3)

        for (i, color) in style.plotColors.enumerated() {
            #expect(color.contrastRatio(with: style.background) >= 3,
                    "plot color \(i + 1) (#\(color.hex)) is invisible on the canvas")
        }
        // An accent that already carries is left exactly as the designer set it.
        #expect(style.plotColors[1] == style.accent(2))
    }

    @Test func chartSeriesUseThePlotColorsNotTheRawAccents() throws {
        let deck = try Presentation()
        deck.applyDesign(Design.parse(
            "## Palette\n- Background: #FFFFFF\n- Text: #1A1A1A\n- Accent 1: #E7E0D3"))
        try deck.chartSlide("T", .barClustered, sample)
        let chart = try deck.package.part(at: PackURI("/ppt/charts/chart1.xml")).dom()
        let fills = (chart.firstChild(named: "c:chart")?.firstChild(named: "c:plotArea")?
            .firstChild(named: "c:barChart")?.children(named: "c:ser") ?? [])
            .compactMap { $0.firstChild(named: "c:spPr")?.firstChild(named: "a:solidFill")?
                .firstChild(named: "a:srgbClr")?[attribute: "val"] }
        #expect(!fills.isEmpty)
        #expect(fills[0] != "E7E0D3", "the invisible accent went straight onto the chart")
        #expect(Color(fills[0]).contrastRatio(with: Color("FFFFFF")) >= 3)
    }
}
