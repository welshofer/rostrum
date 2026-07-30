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
}
