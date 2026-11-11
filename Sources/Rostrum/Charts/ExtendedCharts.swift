import Foundation

extension ContentType {
    public static let extendedChart = "application/vnd.ms-office.chartex+xml"
}

extension RelType {
    public static let extendedChart = "http://schemas.microsoft.com/office/2014/relationships/chartEx"
}

/// Office 2016+ modern extended chart types (`cx:chartSpace` / `cx:series@layoutId`).
public enum ExtendedChartKind: String, Sendable, CaseIterable, Equatable {
    case waterfall
    case funnel
    case treemap
    case sunburst
    case histogram
    case boxWhisker
}

/// An Office 2016+ extended chart (`cx:chartSpace`, namespace
/// `http://schemas.microsoft.com/office/drawing/2014/chartex`).
public final class ExtendedChart {
    public static let namespace = "http://schemas.microsoft.com/office/drawing/2014/chartex"

    /// The chart part (`/ppt/charts/chartExN.xml`).
    public let part: Part
    let package: OPCPackage

    init(part: Part, package: OPCPackage) {
        self.part = part
        self.package = package
    }

    var root: XML.Element? { try? part.dom() }

    private var chartElement: XML.Element? {
        root?.firstChild(named: "cx:chart")
    }

    private var plotAreaRegion: XML.Element? {
        let plotArea = chartElement?.firstChild(named: "cx:plotArea")
        return plotArea?.firstChild(named: "cx:plotAreaRegion") ?? plotArea
    }

    var seriesElements: [XML.Element] {
        plotAreaRegion?.children(named: "cx:series") ?? []
    }

    var dataElements: [XML.Element] {
        root?.firstChild(named: "cx:chartData")?.children(named: "cx:data") ?? []
    }

    /// Raw `layoutId` attribute on the first `cx:series` (e.g. `"waterfall"`, `"funnel"`, `"treemap"`).
    public var rawLayoutId: String? {
        seriesElements.first?[attribute: "layoutId"]
    }

    /// Strongly-typed extended chart kind, when `rawLayoutId` is one of the known Office 2016+ kinds.
    public var kind: ExtendedChartKind? {
        rawLayoutId.flatMap(ExtendedChartKind.init(rawValue:))
    }

    /// The chart's title, if present (`cx:chart/cx:title`).
    public var title: String? {
        guard let titleEl = chartElement?.firstChild(named: "cx:title") else { return nil }
        if let tx = titleEl.firstChild(named: "cx:tx") {
            if let v = tx.firstChild(named: "cx:txData")?.firstChild(named: "cx:v")?.textContent, !v.isEmpty {
                return v
            }
            if let rich = tx.firstChild(named: "cx:rich") ?? tx.firstChild(named: "a:rich") {
                let text = rich.children(named: "a:p")
                    .map { $0.children(named: "a:r").map { $0.firstChild(named: "a:t")?.textContent ?? "" }.joined() }
                    .joined(separator: "\n")
                if !text.isEmpty { return text }
            }
        }
        return nil
    }

    /// Subtotal point indices declared on a waterfall chart (`cx:layoutPr/cx:subtotals/cx:idx@val`).
    public var subtotalIndices: [Int] {
        guard let subtotals = seriesElements.first?
            .firstChild(named: "cx:layoutPr")?
            .firstChild(named: "cx:subtotals") else { return [] }
        return subtotals.children(named: "cx:idx").compactMap { $0[attribute: "val"].flatMap(Int.init) }
    }

    /// Categories from `cx:chartData/cx:data/cx:strDim`.
    public var categories: [String] {
        for dataEl in dataElements {
            guard let strDim = dataEl.firstChild(named: "cx:strDim") else { continue }
            let pts = Self.readStringDimension(strDim)
            if !pts.isEmpty { return pts }
        }
        return []
    }

    /// Series values from `cx:series` paired with `cx:chartData/cx:data/cx:numDim`.
    public var series: [ChartData.Series] {
        let dataById: [String: XML.Element] = Dictionary(
            uniqueKeysWithValues: dataElements.compactMap { el in
                guard let id = el[attribute: "id"] else { return nil }
                return (id, el)
            }
        )
        return seriesElements.enumerated().map { index, ser in
            let name = ser.firstChild(named: "cx:tx")?
                .firstChild(named: "cx:txData")?
                .firstChild(named: "cx:v")?.textContent
                ?? ser.firstChild(named: "cx:tx")?.firstChild(named: "cx:v")?.textContent
                ?? ""
            let dataId = ser.firstChild(named: "cx:dataId")?[attribute: "val"]
            let dataEl = dataId.flatMap { dataById[$0] } ?? (index < dataElements.count ? dataElements[index] : nil)
            let values: [Double?]
            if let numDim = dataEl?.firstChild(named: "cx:numDim") {
                values = Self.readNumberDimension(numDim)
            } else {
                values = []
            }
            return ChartData.Series(name: name, values: values)
        }
    }

    /// Plotted `ChartData` when categories and series align.
    public var data: ChartData? {
        let cats = categories
        let sers = series
        guard !cats.isEmpty, !sers.isEmpty,
              sers.count <= 255,
              sers.allSatisfy({ $0.values.count == cats.count }) else { return nil }
        return ChartData(categories: cats, series: sers)
    }

    /// Embedded workbook part, when present (`cx:chartData/cx:externalData@r:id`).
    public var workbookPart: Part? {
        guard let rId = root?.firstChild(named: "cx:chartData")?
            .firstChild(named: "cx:externalData")?[attribute: "r:id"],
              let rel = part.rels.relationship(withId: rId), !rel.isExternal else { return nil }
        return try? package.part(at: PackURI.resolve(target: rel.target, relativeTo: part.uri.baseURI))
    }

    /// Replace data in place across `cx:chartData` and the embedded workbook.
    public func replaceData(_ newData: ChartData) throws {
        try newData.requireFiniteValues()
        let sers = seriesElements
        let datas = dataElements
        guard !sers.isEmpty, sers.count == newData.series.count, datas.count >= sers.count else {
            throw Chart.ReplacementProblem.seriesCountMismatch(chart: sers.count, replacement: newData.series.count)
        }
        for (index, ser) in sers.enumerated() {
            let entry = newData.series[index]
            if let tx = ser.firstChild(named: "cx:tx") {
                let txData = tx.getOrAddChild("cx:txData")
                let v = txData.getOrAddChild("cx:v")
                v.children = [.text(entry.name)]
            }
            let dataEl = datas[index]
            if let strDim = dataEl.firstChild(named: "cx:strDim") {
                Self.writeStringDimension(newData.categories, into: strDim)
            }
            if let numDim = dataEl.firstChild(named: "cx:numDim") {
                Self.writeNumberDimension(entry.values, into: numDim)
            }
        }
        part.markDirty()
        if let workbook = workbookPart {
            workbook.replaceBlob(try ChartWorkbook.make(data: newData))
        }
    }

    private static let pointLimit = 100_000

    private static func readStringDimension(_ dim: XML.Element) -> [String] {
        guard let lvl = dim.firstChild(named: "cx:lvl") else { return [] }
        return readPoints(in: lvl).map { $0 ?? "" }
    }

    private static func readNumberDimension(_ dim: XML.Element) -> [Double?] {
        guard let lvl = dim.firstChild(named: "cx:lvl") else { return [] }
        return readPoints(in: lvl).map { $0.flatMap(Double.init) }
    }

    private static func readPoints(in lvl: XML.Element) -> [String?] {
        let pts = lvl.children(named: "cx:pt")
        let declared = lvl[attribute: "ptCount"].flatMap(Int.init)
        let highest = pts.compactMap { $0[attribute: "idx"].flatMap(Int.init) }.max()
        let count = declared ?? highest.map { $0 < pointLimit ? $0 + 1 : 0 } ?? 0
        guard count > 0, count <= pointLimit else { return [] }
        var values = [String?](repeating: nil, count: count)
        for pt in pts {
            guard let idx = pt[attribute: "idx"].flatMap(Int.init),
                  values.indices.contains(idx) else { continue }
            values[idx] = pt.firstChild(named: "cx:v")?.textContent ?? pt.textContent
        }
        return values
    }

    private static func writeStringDimension(_ strings: [String], into dim: XML.Element) {
        let lvl = dim.getOrAddChild("cx:lvl")
        lvl[attribute: "ptCount"] = String(strings.count)
        lvl.removeChildren(named: "cx:pt")
        for (idx, text) in strings.enumerated() {
            lvl.appendElement(XML.Element("cx:pt", attributes: [("idx", String(idx))], children: [.text(text)]))
        }
    }

    private static func writeNumberDimension(_ numbers: [Double?], into dim: XML.Element) {
        let lvl = dim.getOrAddChild("cx:lvl")
        lvl[attribute: "ptCount"] = String(numbers.count)
        lvl.removeChildren(named: "cx:pt")
        for (idx, value) in numbers.enumerated() {
            guard let value else { continue }
            lvl.appendElement(XML.Element("cx:pt", attributes: [("idx", String(idx))], children: [.text(chartNumber(value))]))
        }
    }

    static func makeChartSpaceXML(
        kind: ExtendedChartKind,
        data: ChartData,
        colors: [Color]?,
        title: String?,
        subtotals: [Int]
    ) -> Data {
        let root = XML.Element("cx:chartSpace", attributes: [
            ("xmlns:cx", namespace),
            ("xmlns:a", "http://schemas.openxmlformats.org/drawingml/2006/main"),
            ("xmlns:r", "http://schemas.openxmlformats.org/officeDocument/2006/relationships"),
        ])

        let chartData = XML.Element("cx:chartData")
        chartData.appendElement(XML.Element("cx:externalData", attributes: [("r:id", "rId1")]))

        let lastRow = data.categories.count + 1
        for (seriesIndex, series) in data.series.enumerated() {
            let col = seriesColumn(seriesIndex)
            let dataEl = XML.Element("cx:data", attributes: [("id", String(seriesIndex))])

            let strDim = XML.Element("cx:strDim", attributes: [("type", "cat")])
            strDim.appendElement(XML.Element("cx:f", children: [.text("Sheet1!$A$2:$A$\(lastRow)")]))
            let strLvl = XML.Element("cx:lvl", attributes: [("ptCount", String(data.categories.count))])
            for (idx, cat) in data.categories.enumerated() {
                strLvl.appendElement(XML.Element("cx:pt", attributes: [("idx", String(idx))], children: [.text(cat)]))
            }
            strDim.appendElement(strLvl)
            dataEl.appendElement(strDim)

            let numDim = XML.Element("cx:numDim", attributes: [("type", "val")])
            numDim.appendElement(XML.Element("cx:f", children: [.text("Sheet1!$\(col)$2:$\(col)$\(lastRow)")]))
            let numLvl = XML.Element("cx:lvl", attributes: [("ptCount", String(series.values.count))])
            for (idx, val) in series.values.enumerated() {
                guard let val else { continue }
                numLvl.appendElement(XML.Element("cx:pt", attributes: [("idx", String(idx))], children: [.text(chartNumber(val))]))
            }
            numDim.appendElement(numLvl)
            dataEl.appendElement(numDim)

            chartData.appendElement(dataEl)
        }
        root.appendElement(chartData)

        let chart = XML.Element("cx:chart")
        if let title, !title.isEmpty {
            let titleEl = XML.Element("cx:title")
            let tx = XML.Element("cx:tx")
            let txData = XML.Element("cx:txData")
            txData.appendElement(XML.Element("cx:v", children: [.text(title)]))
            tx.appendElement(txData)
            titleEl.appendElement(tx)
            chart.appendElement(titleEl)
        }

        let plotArea = XML.Element("cx:plotArea")
        let region = XML.Element("cx:plotAreaRegion")
        for (seriesIndex, series) in data.series.enumerated() {
            let ser = XML.Element("cx:series", attributes: [("layoutId", kind.rawValue)])
            let tx = XML.Element("cx:tx")
            let txData = XML.Element("cx:txData")
            txData.appendElement(XML.Element("cx:v", children: [.text(series.name)]))
            tx.appendElement(txData)
            ser.appendElement(tx)

            if let colors, !colors.isEmpty {
                let color = colors[seriesIndex % colors.count]
                let spPr = XML.Element("cx:spPr")
                let solid = XML.Element("a:solidFill")
                solid.appendElement(color.srgbElement())
                spPr.appendElement(solid)
                ser.appendElement(spPr)
            }

            ser.appendElement(XML.Element("cx:dataId", attributes: [("val", String(seriesIndex))]))
            if kind == .waterfall, !subtotals.isEmpty {
                let layoutPr = XML.Element("cx:layoutPr")
                let subs = XML.Element("cx:subtotals")
                for idx in subtotals {
                    subs.appendElement(XML.Element("cx:idx", attributes: [("val", String(idx))]))
                }
                layoutPr.appendElement(subs)
                ser.appendElement(layoutPr)
            }
            region.appendElement(ser)
        }
        plotArea.appendElement(region)
        chart.appendElement(plotArea)
        root.appendElement(chart)

        return XML.document(root)
    }
}

public extension GraphicFrame {
    /// The relationship id of an Office 2016+ extended chart (`cx:chart@r:id`), when present.
    var extendedChartRelationshipID: String? {
        graphicData?.firstChild(named: "cx:chart")?[attribute: "r:id"]
    }

    /// The package part of an Office 2016+ extended chart (`cx:chartSpace`), when present.
    var extendedChartPart: Part? {
        guard let rId = extendedChartRelationshipID,
              let rel = part.rels.relationship(withId: rId),
              !rel.isExternal,
              let package else { return nil }
        let uri = PackURI.resolve(target: rel.target, relativeTo: part.uri.baseURI)
        return try? package.part(at: uri)
    }

    /// The Office 2016+ extended chart (`cx:chartSpace`) hosted by this graphic frame, when present.
    var extendedChart: ExtendedChart? {
        guard let chartPart = extendedChartPart, let package else { return nil }
        return ExtendedChart(part: chartPart, package: package)
    }
}

public extension Slide {
    /// Every Office 2016+ extended chart (`cx:chartSpace`) on this slide, including inside groups.
    var extendedCharts: [ExtendedChart] {
        Self.extendedCharts(in: shapes.all)
    }

    private static func extendedCharts(in shapes: [Shape]) -> [ExtendedChart] {
        shapes.flatMap { shape -> [ExtendedChart] in
            if let group = shape as? GroupShape { return extendedCharts(in: group.shapes) }
            return ((shape as? GraphicFrame)?.extendedChart).map { [$0] } ?? []
        }
    }
}

public extension Presentation {
    /// Every Office 2016+ extended chart (`cx:chartSpace`) in the presentation.
    var extendedCharts: [ExtendedChart] {
        slides.flatMap(\.extendedCharts)
    }
}

extension ShapeCollection {
    /// Add an Office 2016+ extended chart (`waterfall`, `funnel`, `treemap`, `sunburst`, `histogram`, `boxWhisker`).
    @discardableResult
    public func addExtendedChart(
        _ kind: ExtendedChartKind,
        data: ChartData,
        frame: Rect,
        colors: [Color]? = nil,
        title: String? = nil,
        subtotals: [Int] = []
    ) throws -> GraphicFrame {
        try data.requireFiniteValues()
        guard let package else {
            throw RostrumError.packageInvalid("this shape collection has no package attached")
        }

        var n = 1
        while package.parts[PackURI("/ppt/charts/chartEx\(n).xml")] != nil { n += 1 }
        let chartURI = PackURI("/ppt/charts/chartEx\(n).xml")
        var wbIndex = n
        while package.parts[PackURI("/ppt/embeddings/Microsoft_Excel_Sheet\(wbIndex).xlsx")] != nil { wbIndex += 1 }
        let workbookURI = PackURI("/ppt/embeddings/Microsoft_Excel_Sheet\(wbIndex).xlsx")

        let chartBytes = ExtendedChart.makeChartSpaceXML(
            kind: kind, data: data, colors: colors, title: title, subtotals: subtotals)
        let workbookBytes = try ChartWorkbook.make(data: data)

        let chartPart = package.addPart(
            uri: chartURI, contentType: ContentType.extendedChart, blob: chartBytes)
        package.contentTypes.setDefault(extension: "xlsx", contentType: ContentType.xlsx)
        package.addPart(uri: workbookURI, contentType: ContentType.xlsx, blob: workbookBytes)
        package.contentTypes.removeOverride(partName: workbookURI)
        chartPart.rels.add(
            type: RelType.package,
            target: chartURI.relativeReference(to: workbookURI))

        let rId = part.rels.add(
            type: RelType.extendedChart,
            target: part.uri.relativeReference(to: chartURI))

        let id = try Slide.nextShapeID(of: part)
        let graphicFrame = XML.Element("p:graphicFrame")
        let nvPr = XML.Element("p:nvGraphicFramePr")
        nvPr.appendElement(XML.Element("p:cNvPr", attributes: [
            ("id", String(id)), ("name", "Chart \(id)"),
        ]))
        let cNv = XML.Element("p:cNvGraphicFramePr")
        cNv.appendElement(XML.Element("a:graphicFrameLocks", attributes: [("noGrp", "1")]))
        nvPr.appendElement(cNv)
        nvPr.appendElement(XML.Element("p:nvPr"))
        graphicFrame.appendElement(nvPr)

        let xfrm = XML.Element("p:xfrm")
        xfrm.appendElement(XML.Element("a:off", attributes: [
            ("x", String(frame.x.rawValue)), ("y", String(frame.y.rawValue)),
        ]))
        xfrm.appendElement(XML.Element("a:ext", attributes: [
            ("cx", String(frame.width.rawValue)), ("cy", String(frame.height.rawValue)),
        ]))
        graphicFrame.appendElement(xfrm)

        let graphic = XML.Element("a:graphic")
        let graphicData = XML.Element("a:graphicData", attributes: [
            ("uri", ExtendedChart.namespace),
        ])
        graphicData.appendElement(XML.Element("cx:chart", attributes: [
            ("xmlns:cx", ExtendedChart.namespace),
            ("xmlns:r", "http://schemas.openxmlformats.org/officeDocument/2006/relationships"),
            ("r:id", rId),
        ]))
        graphic.appendElement(graphicData)
        graphicFrame.appendElement(graphic)

        try appendShapeElement(graphicFrame)
        part.markDirty()
        return GraphicFrame(element: graphicFrame, part: part, package: package)
    }
}
