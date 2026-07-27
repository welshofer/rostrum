import Foundation

/// Builds `c:chartSpace` documents. Every added element sits at its
/// schema-mandated position (the CT_*_tag_seq order) — a deviation triggers
/// PowerPoint's repair dialog, so the ordering here is load-bearing.
enum ChartXML {
    static let nsC = "http://schemas.openxmlformats.org/drawingml/2006/chart"

    // Axis ids need only be unique within one chart part.
    static let catAxID = "111111111", valAxID = "222222222"
    static let xValAxID = "333333333", yValAxID = "444444444"
    /// A combo chart's secondary axis pair. Fixed constants rather than a
    /// counter: there are at most two pairs, and a counter would make the
    /// output depend on construction order.
    static let secondaryCatAxID = "555555555", secondaryValAxID = "666666666"

    /// What a plot group needs to know beyond its own series: where those
    /// series sit in the chart's global numbering (which is also their workbook
    /// column), which axis pair it is drawn against, and its own data labels.
    ///
    /// The defaults reproduce the single-plot case exactly, so the existing
    /// builders are unchanged by the combo work.
    struct PlotContext {
        var firstSeriesIndex = 0
        var categoryAxisID = ChartXML.catAxID
        var valueAxisID = ChartXML.valAxID
        var dataLabels: DataLabelOptions?
    }

    // MARK: - Category charts (bar / line / area / pie / doughnut)

    static func chartSpace(kind: ChartKind, data: ChartData, colors: [Color]?,
                           options: ChartOptions) -> Data {
        let root = chartRoot()
        if kind != .pie && kind != .doughnut {
            root.appendElement(V("c:date1904", "0"))
        }
        let chart = XML.Element("c:chart")
        appendTitle(options.title, to: chart)

        let plotArea = XML.Element("c:plotArea")
        let axed = kind != .pie && kind != .doughnut
        switch kind {
        case .barClustered, .barStacked, .barPercentStacked:
            plotArea.appendElement(barChart(kind: kind, data: data, colors: colors, options: options))
        case .line:
            plotArea.appendElement(lineChart(data: data, colors: colors, options: options))
        case .area:
            plotArea.appendElement(areaChart(data: data, colors: colors, options: options))
        case .pie:
            plotArea.appendElement(pieChart(kind: kind, data: data, colors: colors, options: options))
        case .doughnut:
            plotArea.appendElement(pieChart(kind: kind, data: data, colors: colors, options: options))
        case .radar, .radarFilled:
            plotArea.appendElement(radarChart(kind: kind, data: data, colors: colors, options: options))
        }
        if axed {
            plotArea.appendElement(catAx(id: catAxID, crossing: valAxID, title: options.categoryAxisTitle))
            plotArea.appendElement(valAx(id: valAxID, crossing: catAxID, options: options.valueAxis,
                                         crossBetween: kind == .area ? "midCat" : nil))
        }
        chart.appendElement(plotArea)

        let legendPos = options.legend ?? (kind == .line && data.series.count > 1 ? .right : nil)
        appendLegend(legendPos, to: chart)
        chart.appendElement(V("c:plotVisOnly", "1"))
        chart.appendElement(V("c:dispBlanksAs", "gap"))
        root.appendElement(chart)

        appendDefaultTextAndData(to: root)
        return XML.document(root)
    }

    // MARK: - Combo (several plot groups in one plot area)

    /// Build a combo chart. `CT_PlotArea` is `layout?, (plot group)+, (axis)*,
    /// dTable?, spPr?`, so every group is emitted before any axis — which is
    /// also what the single-plot path already does.
    ///
    /// Series are numbered globally across groups, because `c:idx`/`c:order`
    /// and the workbook column are the same fact: the flattened series order is
    /// exactly the layout `ChartWorkbook.make` writes.
    static func comboChartSpace(data: ComboChartData, options: ChartOptions) -> Data {
        let root = chartRoot()
        root.appendElement(V("c:date1904", "0"))
        let chart = XML.Element("c:chart")
        appendTitle(options.title, to: chart)

        let flattened = data.flattened
        let plotArea = XML.Element("c:plotArea")
        for (index, group) in data.groups.enumerated() {
            let secondary = group.axis == .secondary
            let context = PlotContext(
                firstSeriesIndex: data.firstSeriesIndex(ofGroup: index),
                categoryAxisID: secondary ? secondaryCatAxID : catAxID,
                valueAxisID: secondary ? secondaryValAxID : valAxID,
                dataLabels: group.dataLabels)
            plotArea.appendElement(plot(for: group, data: flattened,
                                        options: options, context: context))
        }

        // Primary pair, then — when anything is drawn against it — the
        // secondary value axis and the deleted category axis its plot groups
        // name. A c:axId naming an axis that is not in the plot area is a
        // repair trigger no schema check would catch.
        plotArea.appendElement(catAx(id: catAxID, crossing: valAxID,
                                     title: options.categoryAxisTitle))
        plotArea.appendElement(valAx(id: valAxID, crossing: catAxID,
                                     options: options.valueAxis,
                                     crossBetween: crossBetween(of: data, on: .primary)))
        if data.groups.contains(where: { $0.axis == .secondary }) {
            plotArea.appendElement(valAx(id: secondaryValAxID, crossing: secondaryCatAxID,
                                         axPos: "r", options: options.secondaryValueAxis,
                                         crossBetween: crossBetween(of: data, on: .secondary),
                                         gridlines: false, crosses: "max"))
            plotArea.appendElement(catAx(id: secondaryCatAxID, crossing: secondaryValAxID,
                                         title: nil, deleted: true, crosses: nil))
        }
        chart.appendElement(plotArea)

        appendLegend(options.legend ?? (flattened.series.count > 1 ? .right : nil), to: chart)
        chart.appendElement(V("c:plotVisOnly", "1"))
        chart.appendElement(V("c:dispBlanksAs", "gap"))
        root.appendElement(chart)

        appendDefaultTextAndData(to: root)
        return XML.document(root)
    }

    /// An area group puts its category ticks mid-category; everything else
    /// inherits the consumer default, which Rostrum expresses by omitting the
    /// element exactly as the single-plot path does.
    private static func crossBetween(of data: ComboChartData,
                                     on axis: ChartAxisGroup) -> String? {
        data.groups.contains { $0.axis == axis && $0.kind == .area } ? "midCat" : nil
    }

    private static func plot(for group: ComboChartData.Group, data: ChartData,
                             options: ChartOptions, context: PlotContext) -> XML.Element {
        switch group.kind {
        case .barClustered, .barStacked, .barPercentStacked:
            return barChart(kind: group.kind, data: data, colors: group.colors,
                            options: options, series: group.series, context: context)
        case .line:
            return lineChart(data: data, colors: group.colors, options: options,
                             series: group.series, context: context)
        default:
            // ComboChartData.authoringProblem() refuses every other kind before
            // this is reached; area is the only remaining case.
            return areaChart(data: data, colors: group.colors, options: options,
                             series: group.series, context: context)
        }
    }

    // MARK: - Scatter

    static func scatterChartSpace(data: XYChartData, colors: [Color]?,
                                  options: ChartOptions) -> Data {
        let root = chartRoot()
        root.appendElement(V("c:date1904", "0"))
        let chart = XML.Element("c:chart")
        appendTitle(options.title, to: chart)

        let plotArea = XML.Element("c:plotArea")
        let scatter = XML.Element("c:scatterChart")
        scatter.appendElement(V("c:scatterStyle", "lineMarker"))
        scatter.appendElement(V("c:varyColors", "0"))
        for (i, series) in data.series.enumerated() {
            scatter.appendElement(scatterSeries(index: i, series: series, color: colors?[safe: i]))
        }
        if let d = options.dataLabels { scatter.appendElement(dLbls(d, plot: "c:scatterChart")) }
        scatter.appendElement(V("c:axId", xValAxID))
        scatter.appendElement(V("c:axId", yValAxID))
        plotArea.appendElement(scatter)
        // Scatter's category axis is itself a value axis (axPos b).
        plotArea.appendElement(valAx(id: xValAxID, crossing: yValAxID, axPos: "b",
                                     options: AxisOptions(), gridlines: false))
        plotArea.appendElement(valAx(id: yValAxID, crossing: xValAxID, axPos: "l",
                                     options: options.valueAxis))
        chart.appendElement(plotArea)

        appendLegend(options.legend ?? (data.series.count > 1 ? .right : nil), to: chart)
        chart.appendElement(V("c:plotVisOnly", "1"))
        chart.appendElement(V("c:dispBlanksAs", "gap"))
        root.appendElement(chart)

        appendDefaultTextAndData(to: root)
        return XML.document(root)
    }

    // MARK: - Bubble

    static func bubbleChartSpace(data: BubbleChartData, colors: [Color]?,
                                 options: ChartOptions) -> Data {
        let root = chartRoot()
        root.appendElement(V("c:date1904", "0"))
        let chart = XML.Element("c:chart")
        appendTitle(options.title, to: chart)

        let plotArea = XML.Element("c:plotArea")
        let bubble = XML.Element("c:bubbleChart")
        bubble.appendElement(V("c:varyColors", "0"))
        for (i, series) in data.series.enumerated() {
            bubble.appendElement(bubbleSeries(index: i, series: series, color: colors?[safe: i]))
        }
        if let d = options.dataLabels { bubble.appendElement(dLbls(d, plot: "c:bubbleChart")) }
        // Sizes are areas, not radii — PowerPoint's own default.
        bubble.appendElement(V("c:bubbleScale", "100"))
        bubble.appendElement(V("c:showNegBubbles", "0"))
        bubble.appendElement(V("c:axId", xValAxID))
        bubble.appendElement(V("c:axId", yValAxID))
        plotArea.appendElement(bubble)
        plotArea.appendElement(valAx(id: xValAxID, crossing: yValAxID, axPos: "b",
                                     options: AxisOptions(), gridlines: false))
        plotArea.appendElement(valAx(id: yValAxID, crossing: xValAxID, axPos: "l",
                                     options: options.valueAxis))
        chart.appendElement(plotArea)

        appendLegend(options.legend ?? (data.series.count > 1 ? .right : nil), to: chart)
        chart.appendElement(V("c:plotVisOnly", "1"))
        chart.appendElement(V("c:dispBlanksAs", "gap"))
        root.appendElement(chart)

        appendDefaultTextAndData(to: root)
        return XML.document(root)
    }

    /// One bubble `c:ser`: idx, order, tx, spPr, xVal, yVal, bubbleSize.
    /// Three workbook columns per series, so the name sits above the y column.
    private static func bubbleSeries(index: Int, series: BubbleChartData.Series,
                                     color: Color?) -> XML.Element {
        let serEl = XML.Element("c:ser")
        serEl.appendElement(V("c:idx", String(index)))
        serEl.appendElement(V("c:order", String(index)))
        let xCol = seriesColumn(index * 3)
        let yCol = seriesColumn(index * 3 + 1)
        let sizeCol = seriesColumn(index * 3 + 2)
        let tx = XML.Element("c:tx")
        tx.appendElement(strRef(formula: "Sheet1!$\(yCol)$1", strings: [series.name]))
        serEl.appendElement(tx)
        if let color { serEl.appendElement(solidSpPr(color)) }
        let n = series.points.count
        let xVal = XML.Element("c:xVal")
        xVal.appendElement(numRef(formula: "Sheet1!$\(xCol)$2:$\(xCol)$\(n + 1)",
                                  values: series.points.map(\.x)))
        serEl.appendElement(xVal)
        let yVal = XML.Element("c:yVal")
        yVal.appendElement(numRef(formula: "Sheet1!$\(yCol)$2:$\(yCol)$\(n + 1)",
                                  values: series.points.map(\.y)))
        serEl.appendElement(yVal)
        let sizes = XML.Element("c:bubbleSize")
        sizes.appendElement(numRef(formula: "Sheet1!$\(sizeCol)$2:$\(sizeCol)$\(n + 1)",
                                   values: series.points.map(\.size)))
        serEl.appendElement(sizes)
        serEl.appendElement(V("c:bubble3D", "0"))
        return serEl
    }

    // MARK: - Shared root / title / legend / trailing

    private static func chartRoot() -> XML.Element {
        XML.Element("c:chartSpace", attributes: [
            ("xmlns:c", nsC), ("xmlns:a", MinimalTemplate.nsA), ("xmlns:r", MinimalTemplate.nsR),
        ])
    }

    /// A custom title suppresses the auto title; no title keeps PowerPoint's
    /// auto behaviour (which surfaces the series name) to preserve prior decks.
    private static func appendTitle(_ title: String?, to chart: XML.Element) {
        if let title {
            let t = XML.Element("c:title")
            t.appendElement(richTx(title, size: 1400, bold: true))
            t.appendElement(V("c:overlay", "0"))
            chart.appendElement(t)
            chart.appendElement(V("c:autoTitleDeleted", "0"))
        } else {
            chart.appendElement(V("c:autoTitleDeleted", "0"))
        }
    }

    private static func appendLegend(_ pos: LegendPosition?, to chart: XML.Element) {
        guard let pos else { return }
        let legend = XML.Element("c:legend")
        legend.appendElement(V("c:legendPos", pos.rawValue))
        legend.appendElement(XML.Element("c:layout"))
        legend.appendElement(V("c:overlay", "0"))
        chart.appendElement(legend)
    }

    private static func appendDefaultTextAndData(to root: XML.Element) {
        let txPr = XML.Element("c:txPr")
        txPr.appendElement(XML.Element("a:bodyPr"))
        txPr.appendElement(XML.Element("a:lstStyle"))
        let p = XML.Element("a:p")
        let pPr = XML.Element("a:pPr")
        pPr.appendElement(XML.Element("a:defRPr", attributes: [("sz", "1400")]))
        p.appendElement(pPr)
        p.appendElement(XML.Element("a:endParaRPr", attributes: [("lang", "en-US")]))
        txPr.appendElement(p)
        root.appendElement(txPr)

        let external = XML.Element("c:externalData", attributes: [("r:id", "rId1")])
        external.appendElement(V("c:autoUpdate", "0"))
        root.appendElement(external)
    }

    /// The `c:dLblPos` tokens a plot type accepts, or nil where Rostrum has no
    /// evidence of a restriction and so imposes none.
    ///
    /// An illegal position is a classic repair trigger — this table started as
    /// a one-line doughnut guard after PowerPoint refused a deck. Only rows
    /// corroborated by another implementation's exporter are listed; the rest
    /// return nil rather than silently dropping a position a caller may be
    /// relying on. An empty set means the element permits no position at all.
    static func legalDataLabelPositions(plot: String, grouping: String?) -> Set<String>? {
        switch plot {
        case "c:pieChart", "c:ofPieChart":
            return ["bestFit", "ctr", "inEnd", "outEnd"]
        case "c:doughnutChart", "c:areaChart", "c:radarChart":
            return []
        case "c:barChart", "c:bar3DChart":
            // A stacked bar has no "outside end" — the next segment is there.
            return grouping == "stacked" || grouping == "percentStacked"
                ? ["ctr", "inBase", "inEnd"]
                : ["ctr", "inBase", "inEnd", "outEnd"]
        default:
            return nil
        }
    }

    private static func dLbls(_ o: DataLabelOptions, plot: String,
                              grouping: String? = nil) -> XML.Element {
        // Order: numFmt, spPr, txPr, dLblPos, then the show* flags in sequence.
        let d = XML.Element("c:dLbls")
        if let fmt = o.numberFormat {
            d.appendElement(XML.Element("c:numFmt", attributes: [("formatCode", fmt), ("sourceLinked", "0")]))
        }
        let legal = legalDataLabelPositions(plot: plot, grouping: grouping)
        if let pos = o.position, legal?.contains(pos) ?? true {
            d.appendElement(V("c:dLblPos", pos))
        }
        d.appendElement(V("c:showLegendKey", "0"))
        d.appendElement(V("c:showVal", o.showValue ? "1" : "0"))
        d.appendElement(V("c:showCatName", o.showCategory ? "1" : "0"))
        d.appendElement(V("c:showSerName", o.showSeriesName ? "1" : "0"))
        d.appendElement(V("c:showPercent", o.showPercent ? "1" : "0"))
        d.appendElement(V("c:showBubbleSize", "0"))
        return d
    }

    // MARK: - Plot builders

    private static func barChart(kind: ChartKind, data: ChartData, colors: [Color]?,
                                 options: ChartOptions,
                                 series seriesList: [ChartData.Series]? = nil,
                                 context: PlotContext = PlotContext()) -> XML.Element {
        let grouping: String
        switch kind {
        case .barStacked: grouping = "stacked"
        case .barPercentStacked: grouping = "percentStacked"
        default: grouping = "clustered"
        }
        let bar = XML.Element("c:barChart")
        bar.appendElement(V("c:barDir", "col"))
        bar.appendElement(V("c:grouping", grouping))
        for (i, series) in (seriesList ?? data.series).enumerated() {
            bar.appendElement(ser(index: context.firstSeriesIndex + i, series: series,
                                  data: data) { serEl in
                if let color = colors?[safe: i] { serEl.appendElement(solidSpPr(color)) }
            })
        }
        if let d = context.dataLabels ?? options.dataLabels {
            bar.appendElement(dLbls(d, plot: "c:barChart", grouping: grouping))
        }
        if grouping != "clustered" { bar.appendElement(V("c:overlap", "100")) }
        bar.appendElement(V("c:axId", context.categoryAxisID))
        bar.appendElement(V("c:axId", context.valueAxisID))
        return bar
    }

    private static func lineChart(data: ChartData, colors: [Color]?,
                                  options: ChartOptions,
                                  series seriesList: [ChartData.Series]? = nil,
                                  context: PlotContext = PlotContext()) -> XML.Element {
        let line = XML.Element("c:lineChart")
        line.appendElement(V("c:grouping", "standard"))
        line.appendElement(V("c:varyColors", "0"))
        for (i, series) in (seriesList ?? data.series).enumerated() {
            line.appendElement(ser(index: context.firstSeriesIndex + i, series: series,
                                   data: data, trailing: [V("c:smooth", "0")]) { serEl in
                if let color = colors?[safe: i] {
                    let spPr = XML.Element("c:spPr")
                    let ln = XML.Element("a:ln", attributes: [("w", "28575")])
                    let fill = XML.Element("a:solidFill")
                    fill.appendElement(color.srgbElement())
                    ln.appendElement(fill)
                    spPr.appendElement(ln)
                    serEl.appendElement(spPr)
                }
                let marker = XML.Element("c:marker")
                marker.appendElement(V("c:symbol", "none"))
                serEl.appendElement(marker)
            })
        }
        if let d = context.dataLabels ?? options.dataLabels {
            line.appendElement(dLbls(d, plot: "c:lineChart"))
        }
        line.appendElement(V("c:marker", "1"))
        line.appendElement(V("c:axId", context.categoryAxisID))
        line.appendElement(V("c:axId", context.valueAxisID))
        return line
    }

    /// `c:radarChart`: a category axis wrapped into a circle. `c:radarStyle`
    /// selects line-with-markers or a filled area per series.
    private static func radarChart(kind: ChartKind, data: ChartData, colors: [Color]?,
                                   options: ChartOptions) -> XML.Element {
        let radar = XML.Element("c:radarChart")
        radar.appendElement(V("c:radarStyle", kind == .radarFilled ? "filled" : "marker"))
        radar.appendElement(V("c:varyColors", "0"))
        for (i, series) in data.series.enumerated() {
            radar.appendElement(ser(index: i, series: series, data: data) { serEl in
                guard let color = colors?[safe: i] else { return }
                if kind == .radarFilled {
                    serEl.appendElement(solidSpPr(color))
                } else {
                    let spPr = XML.Element("c:spPr")
                    let ln = XML.Element("a:ln", attributes: [("w", "28575")])
                    let fill = XML.Element("a:solidFill")
                    fill.appendElement(color.srgbElement())
                    ln.appendElement(fill)
                    spPr.appendElement(ln)
                    serEl.appendElement(spPr)
                }
            })
        }
        if let d = options.dataLabels { radar.appendElement(dLbls(d, plot: "c:radarChart")) }
        radar.appendElement(V("c:axId", catAxID))
        radar.appendElement(V("c:axId", valAxID))
        return radar
    }

    private static func areaChart(data: ChartData, colors: [Color]?,
                                  options: ChartOptions,
                                  series seriesList: [ChartData.Series]? = nil,
                                  context: PlotContext = PlotContext()) -> XML.Element {
        let area = XML.Element("c:areaChart")
        area.appendElement(V("c:grouping", "standard"))
        area.appendElement(V("c:varyColors", "0"))
        for (i, series) in (seriesList ?? data.series).enumerated() {
            area.appendElement(ser(index: context.firstSeriesIndex + i, series: series,
                                   data: data) { serEl in
                if let color = colors?[safe: i] { serEl.appendElement(solidSpPr(color)) }
            })
        }
        if let d = context.dataLabels ?? options.dataLabels {
            area.appendElement(dLbls(d, plot: "c:areaChart"))
        }
        area.appendElement(V("c:axId", context.categoryAxisID))
        area.appendElement(V("c:axId", context.valueAxisID))
        return area
    }

    private static func pieChart(kind: ChartKind, data: ChartData, colors: [Color]?,
                                 options: ChartOptions) -> XML.Element {
        let el = XML.Element(kind == .doughnut ? "c:doughnutChart" : "c:pieChart")
        el.appendElement(V("c:varyColors", "1"))
        el.appendElement(ser(index: 0, series: data.series[0], data: data) { serEl in
            if let colors {
                for (i, color) in colors.enumerated() where i < data.categories.count {
                    let dPt = XML.Element("c:dPt")
                    dPt.appendElement(V("c:idx", String(i)))
                    dPt.appendElement(V("c:bubble3D", "0"))
                    dPt.appendElement(solidSpPr(color))
                    serEl.appendElement(dPt)
                }
            }
        })
        if let d = options.dataLabels {
            // Doughnut rejects dLblPos entirely (only "best fit" applies) and
            // pie accepts only four of the tokens — both handled by the
            // legality table, which grew out of this very repair prompt.
            el.appendElement(dLbls(d, plot: el.name))
        }
        if kind == .doughnut {
            el.appendElement(V("c:firstSliceAng", "0"))
            el.appendElement(V("c:holeSize", "50"))
        }
        return el
    }

    // MARK: - Series

    /// One category `c:ser`: idx, order, tx, spPr(via extra)/dPt(via extra),
    /// cat, val, then `trailing` (line's c:smooth).
    private static func ser(
        index: Int, series: ChartData.Series, data: ChartData,
        trailing: [XML.Element] = [], extra: (XML.Element) -> Void
    ) -> XML.Element {
        let serEl = XML.Element("c:ser")
        serEl.appendElement(V("c:idx", String(index)))
        serEl.appendElement(V("c:order", String(index)))
        let col = seriesColumn(index)
        let tx = XML.Element("c:tx")
        tx.appendElement(strRef(formula: "Sheet1!$\(col)$1", strings: [series.name]))
        serEl.appendElement(tx)
        extra(serEl)
        let cat = XML.Element("c:cat")
        cat.appendElement(strRef(formula: "Sheet1!$A$2:$A$\(data.categories.count + 1)",
                                 strings: data.categories))
        serEl.appendElement(cat)
        let val = XML.Element("c:val")
        val.appendElement(numRef(formula: "Sheet1!$\(col)$2:$\(col)$\(data.categories.count + 1)",
                                 values: series.values))
        serEl.appendElement(val)
        for t in trailing { serEl.appendElement(t) }
        return serEl
    }

    /// One scatter `c:ser`: idx, order, tx, spPr, marker, xVal, yVal.
    private static func scatterSeries(index: Int, series: XYChartData.Series, color: Color?) -> XML.Element {
        let serEl = XML.Element("c:ser")
        serEl.appendElement(V("c:idx", String(index)))
        serEl.appendElement(V("c:order", String(index)))
        let xCol = seriesColumn(index * 2), yCol = seriesColumn(index * 2 + 1)
        let tx = XML.Element("c:tx")
        tx.appendElement(strRef(formula: "Sheet1!$\(yCol)$1", strings: [series.name]))
        serEl.appendElement(tx)
        if let color {
            let spPr = XML.Element("c:spPr")
            let ln = XML.Element("a:ln", attributes: [("w", "19050")])
            let fill = XML.Element("a:solidFill")
            fill.appendElement(color.srgbElement())
            ln.appendElement(fill)
            spPr.appendElement(ln)
            serEl.appendElement(spPr)
        }
        let n = series.points.count
        let xVal = XML.Element("c:xVal")
        xVal.appendElement(numRef(formula: "Sheet1!$\(xCol)$2:$\(xCol)$\(n + 1)",
                                  values: series.points.map { $0.x }))
        serEl.appendElement(xVal)
        let yVal = XML.Element("c:yVal")
        yVal.appendElement(numRef(formula: "Sheet1!$\(yCol)$2:$\(yCol)$\(n + 1)",
                                  values: series.points.map { $0.y }))
        serEl.appendElement(yVal)
        serEl.appendElement(V("c:smooth", "0"))
        return serEl
    }

    // MARK: - References

    private static func strRef(formula: String, strings: [String]) -> XML.Element {
        let ref = XML.Element("c:strRef")
        ref.appendElement(f(formula))
        let cache = XML.Element("c:strCache")
        cache.appendElement(V("c:ptCount", String(strings.count)))
        for (i, s) in strings.enumerated() {
            let pt = XML.Element("c:pt", attributes: [("idx", String(i))])
            let v = XML.Element("c:v")
            v.children = [.text(s)]
            pt.appendElement(v)
            cache.appendElement(pt)
        }
        ref.appendElement(cache)
        return ref
    }

    private static func numRef(formula: String, values: [Double?]) -> XML.Element {
        let ref = XML.Element("c:numRef")
        ref.appendElement(f(formula))
        let cache = XML.Element("c:numCache")
        let format = XML.Element("c:formatCode")
        format.children = [.text("General")]
        cache.appendElement(format)
        cache.appendElement(V("c:ptCount", String(values.count)))
        for (i, value) in values.enumerated() {
            guard let value else { continue }
            let pt = XML.Element("c:pt", attributes: [("idx", String(i))])
            let v = XML.Element("c:v")
            v.children = [.text(chartNumber(value))]
            pt.appendElement(v)
            cache.appendElement(pt)
        }
        ref.appendElement(cache)
        return ref
    }

    private static func numRef(formula: String, values: [Double]) -> XML.Element {
        numRef(formula: formula, values: values.map { Optional($0) })
    }

    // MARK: - Axes

    /// A category axis. `deleted` marks the invisible partner axis a secondary
    /// plot group's `c:axId` pair has to name — `c:delete` is what suppresses
    /// it, and Excel writes no `c:crosses` on that one, which is why `crosses`
    /// is optional rather than a fixed string.
    private static func catAx(id: String, crossing: String, title: String?,
                              deleted: Bool = false,
                              crosses: String? = "autoZero") -> XML.Element {
        let ax = XML.Element("c:catAx")
        ax.appendElement(V("c:axId", id))
        let scaling = XML.Element("c:scaling")
        scaling.appendElement(V("c:orientation", "minMax"))
        ax.appendElement(scaling)
        ax.appendElement(V("c:delete", deleted ? "1" : "0"))
        ax.appendElement(V("c:axPos", "b"))
        if let title { ax.appendElement(axisTitle(title)) }
        ax.appendElement(V("c:majorTickMark", "out"))
        ax.appendElement(V("c:minorTickMark", "none"))
        ax.appendElement(V("c:tickLblPos", "nextTo"))
        ax.appendElement(V("c:crossAx", crossing))
        if let crosses { ax.appendElement(V("c:crosses", crosses)) }
        ax.appendElement(V("c:auto", "1"))
        ax.appendElement(V("c:lblAlgn", "ctr"))
        ax.appendElement(V("c:lblOffset", "100"))
        ax.appendElement(V("c:noMultiLvlLbl", "0"))
        return ax
    }

    private static func valAx(id: String, crossing: String, axPos: String = "l",
                              options: AxisOptions, crossBetween: String? = nil,
                              gridlines: Bool = true,
                              crosses: String = "autoZero") -> XML.Element {
        let ax = XML.Element("c:valAx")
        ax.appendElement(V("c:axId", id))
        // scaling: orientation, then max BEFORE min.
        let scaling = XML.Element("c:scaling")
        scaling.appendElement(V("c:orientation", "minMax"))
        if let mx = options.max { scaling.appendElement(V("c:max", chartNumber(mx))) }
        if let mn = options.min { scaling.appendElement(V("c:min", chartNumber(mn))) }
        ax.appendElement(scaling)
        ax.appendElement(V("c:delete", "0"))
        ax.appendElement(V("c:axPos", axPos))
        if gridlines { ax.appendElement(XML.Element("c:majorGridlines")) }
        if let title = options.title { ax.appendElement(axisTitle(title)) }
        if let fmt = options.numberFormat {
            ax.appendElement(XML.Element("c:numFmt", attributes: [("formatCode", fmt), ("sourceLinked", "0")]))
        }
        ax.appendElement(V("c:majorTickMark", "out"))
        ax.appendElement(V("c:minorTickMark", "none"))
        ax.appendElement(V("c:tickLblPos", "nextTo"))
        ax.appendElement(V("c:crossAx", crossing))
        ax.appendElement(V("c:crosses", crosses))
        if let crossBetween { ax.appendElement(V("c:crossBetween", crossBetween)) }
        if let unit = options.majorUnit { ax.appendElement(V("c:majorUnit", chartNumber(unit))) }
        return ax
    }

    /// An axis title (c:title = tx, overlay).
    private static func axisTitle(_ text: String) -> XML.Element {
        let t = XML.Element("c:title")
        t.appendElement(richTx(text, size: 1000, bold: false))
        t.appendElement(V("c:overlay", "0"))
        return t
    }

    // MARK: - Rich text (titles)

    private static func richTx(_ text: String, size: Int, bold: Bool) -> XML.Element {
        let tx = XML.Element("c:tx")
        let rich = XML.Element("c:rich")
        rich.appendElement(XML.Element("a:bodyPr"))
        rich.appendElement(XML.Element("a:lstStyle"))
        let p = XML.Element("a:p")
        let pPr = XML.Element("a:pPr")
        pPr.appendElement(XML.Element("a:defRPr", attributes: [("sz", String(size)), ("b", bold ? "1" : "0")]))
        p.appendElement(pPr)
        let run = XML.Element("a:r")
        run.appendElement(XML.Element("a:rPr", attributes: [("lang", "en-US")]))
        let t = XML.Element("a:t")
        t.children = [.text(text)]
        run.appendElement(t)
        p.appendElement(run)
        rich.appendElement(p)
        tx.appendElement(rich)
        return tx
    }

    // MARK: - Helpers

    private static func V(_ name: String, _ val: String) -> XML.Element {
        XML.Element(name, attributes: [("val", val)])
    }

    private static func f(_ formula: String) -> XML.Element {
        let el = XML.Element("c:f")
        el.children = [.text(formula)]
        return el
    }

    private static func solidSpPr(_ color: Color) -> XML.Element {
        let spPr = XML.Element("c:spPr")
        let fill = XML.Element("a:solidFill")
        fill.appendElement(color.srgbElement())
        spPr.appendElement(fill)
        return spPr
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
