import Foundation

/// Builds `c:chartSpace` documents, faithful to python-pptx's chart XML
/// templates (chart/xmlwriter.py). Element order is schema-enforced —
/// deviations trigger PowerPoint's repair dialog; see the research notes in
/// each builder.
enum ChartXML {
    static let nsC = "http://schemas.openxmlformats.org/drawingml/2006/chart"

    // Axis ids are arbitrary unique-in-part int32s; python-pptx's constants.
    static let barCatAxID = "-2068027336", barValAxID = "-2113994440"
    static let lineCatAxID = "2118791784", lineValAxID = "2140495176"

    static func chartSpace(kind: ChartKind, data: ChartData, colors: [Color]?) -> Data {
        let root = XML.Element("c:chartSpace", attributes: [
            ("xmlns:c", nsC),
            ("xmlns:a", MinimalTemplate.nsA),
            ("xmlns:r", MinimalTemplate.nsR),
        ])
        // Pie omits date1904 (faithful to the template).
        if kind != .pie {
            root.appendElement(V("c:date1904", "0"))
        }

        let chart = XML.Element("c:chart")
        chart.appendElement(V("c:autoTitleDeleted", "0"))

        let plotArea = XML.Element("c:plotArea")
        switch kind {
        case .barClustered:
            plotArea.appendElement(barChart(data: data, colors: colors))
            plotArea.appendElement(catAx(id: barCatAxID, crossing: barValAxID))
            plotArea.appendElement(valAx(id: barValAxID, crossing: barCatAxID))
        case .line:
            plotArea.appendElement(lineChart(data: data, colors: colors))
            plotArea.appendElement(catAx(id: lineCatAxID, crossing: lineValAxID))
            plotArea.appendElement(valAx(id: lineValAxID, crossing: lineCatAxID))
        case .pie:
            plotArea.appendElement(pieChart(data: data, colors: colors))
        }
        chart.appendElement(plotArea)

        if kind == .line {
            let legend = XML.Element("c:legend")
            legend.appendElement(V("c:legendPos", "r"))
            legend.appendElement(XML.Element("c:layout"))
            legend.appendElement(V("c:overlay", "0"))
            chart.appendElement(legend)
            chart.appendElement(V("c:plotVisOnly", "1"))
        }
        chart.appendElement(V("c:dispBlanksAs", "gap"))
        if kind == .line {
            chart.appendElement(V("c:showDLblsOverMax", "0"))
        }
        root.appendElement(chart)

        // Default text size; then externalData LAST (schema order).
        let txPr = XML.Element("c:txPr")
        txPr.appendElement(XML.Element("a:bodyPr"))
        txPr.appendElement(XML.Element("a:lstStyle"))
        let p = XML.Element("a:p")
        let pPr = XML.Element("a:pPr")
        pPr.appendElement(XML.Element("a:defRPr", attributes: [("sz", "1800")]))
        p.appendElement(pPr)
        p.appendElement(XML.Element("a:endParaRPr", attributes: [("lang", "en-US")]))
        txPr.appendElement(p)
        root.appendElement(txPr)

        let external = XML.Element("c:externalData", attributes: [("r:id", "rId1")])
        external.appendElement(V("c:autoUpdate", "0"))
        root.appendElement(external)

        return XML.document(root)
    }

    // MARK: - Plot builders

    private static func barChart(data: ChartData, colors: [Color]?) -> XML.Element {
        let bar = XML.Element("c:barChart")
        bar.appendElement(V("c:barDir", "col"))
        bar.appendElement(V("c:grouping", "clustered"))
        for (i, series) in data.series.enumerated() {
            bar.appendElement(ser(index: i, series: series, data: data) { serEl in
                if let color = colors?[safe: i] {
                    serEl.appendElement(solidSpPr(color))
                }
            })
        }
        bar.appendElement(V("c:axId", barCatAxID))
        bar.appendElement(V("c:axId", barValAxID))
        return bar
    }

    private static func lineChart(data: ChartData, colors: [Color]?) -> XML.Element {
        let line = XML.Element("c:lineChart")
        line.appendElement(V("c:grouping", "standard"))
        line.appendElement(V("c:varyColors", "0"))
        for (i, series) in data.series.enumerated() {
            line.appendElement(ser(index: i, series: series, data: data, trailing: [V("c:smooth", "0")]) { serEl in
                if let color = colors?[safe: i] {
                    // A line series' color is its outline, not its fill.
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
        line.appendElement(V("c:marker", "1"))
        line.appendElement(V("c:smooth", "0"))
        line.appendElement(V("c:axId", lineCatAxID))
        line.appendElement(V("c:axId", lineValAxID))
        return line
    }

    private static func pieChart(data: ChartData, colors: [Color]?) -> XML.Element {
        let pie = XML.Element("c:pieChart")
        pie.appendElement(V("c:varyColors", "1"))
        pie.appendElement(ser(index: 0, series: data.series[0], data: data) { serEl in
            // Per-slice colors ride on data points.
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
        return pie
    }

    /// One `c:ser`: idx, order, tx, [type-specific via `extra`], cat, val,
    /// then `trailing` (line's c:smooth).
    private static func ser(
        index: Int, series: ChartData.Series, data: ChartData,
        trailing: [XML.Element] = [], extra: (XML.Element) -> Void
    ) -> XML.Element {
        let serEl = XML.Element("c:ser")
        serEl.appendElement(V("c:idx", String(index)))
        serEl.appendElement(V("c:order", String(index)))

        let col = seriesColumn(index)
        let tx = XML.Element("c:tx")
        tx.appendElement(strRef(
            formula: "Sheet1!$\(col)$1", strings: [series.name]))
        serEl.appendElement(tx)

        extra(serEl)

        let cat = XML.Element("c:cat")
        cat.appendElement(strRef(
            formula: "Sheet1!$A$2:$A$\(data.categories.count + 1)",
            strings: data.categories))
        serEl.appendElement(cat)

        let val = XML.Element("c:val")
        val.appendElement(numRef(
            formula: "Sheet1!$\(col)$2:$\(col)$\(data.categories.count + 1)",
            values: series.values))
        serEl.appendElement(val)

        for t in trailing { serEl.appendElement(t) }
        return serEl
    }

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
            guard let value else { continue }  // gaps keep index, lose the pt
            let pt = XML.Element("c:pt", attributes: [("idx", String(i))])
            let v = XML.Element("c:v")
            v.children = [.text(chartNumber(value))]
            pt.appendElement(v)
            cache.appendElement(pt)
        }
        ref.appendElement(cache)
        return ref
    }

    // MARK: - Axes

    private static func catAx(id: String, crossing: String) -> XML.Element {
        let ax = XML.Element("c:catAx")
        ax.appendElement(V("c:axId", id))
        let scaling = XML.Element("c:scaling")
        scaling.appendElement(V("c:orientation", "minMax"))
        ax.appendElement(scaling)
        ax.appendElement(V("c:delete", "0"))
        ax.appendElement(V("c:axPos", "b"))
        ax.appendElement(V("c:majorTickMark", "out"))
        ax.appendElement(V("c:minorTickMark", "none"))
        ax.appendElement(V("c:tickLblPos", "nextTo"))
        ax.appendElement(V("c:crossAx", crossing))
        ax.appendElement(V("c:crosses", "autoZero"))
        ax.appendElement(V("c:auto", "1"))
        ax.appendElement(V("c:lblAlgn", "ctr"))
        ax.appendElement(V("c:lblOffset", "100"))
        ax.appendElement(V("c:noMultiLvlLbl", "0"))
        return ax
    }

    private static func valAx(id: String, crossing: String) -> XML.Element {
        let ax = XML.Element("c:valAx")
        ax.appendElement(V("c:axId", id))
        ax.appendElement(XML.Element("c:scaling"))
        ax.appendElement(V("c:delete", "0"))
        ax.appendElement(V("c:axPos", "l"))
        ax.appendElement(XML.Element("c:majorGridlines"))
        ax.appendElement(V("c:majorTickMark", "out"))
        ax.appendElement(V("c:minorTickMark", "none"))
        ax.appendElement(V("c:tickLblPos", "nextTo"))
        ax.appendElement(V("c:crossAx", crossing))
        ax.appendElement(V("c:crosses", "autoZero"))
        return ax
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
