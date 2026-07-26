import Foundation

/// A chart in an opened deck: what kind it is, the data it plots, and a
/// `replaceData` that refuses to corrupt it.
///
/// python-pptx's `replace_data` rewrites the chart XML from a fresh data
/// model and is well known to produce decks PowerPoint offers to repair when
/// the replacement's shape does not match the chart's structure. Rostrum
/// takes the opposite stance: the chart's own XML is the authority, the
/// replacement is validated against it first, and a mismatch throws before
/// anything is written.
public final class Chart {
    /// The chart part (`/ppt/charts/chartN.xml`).
    public let part: Part
    let package: OPCPackage

    init(part: Part, package: OPCPackage) {
        self.part = part
        self.package = package
    }

    /// The `c:chartSpace` root.
    private var root: XML.Element? { try? part.dom() }

    /// The `c:plotArea` element, where the per-kind plot lives.
    private var plotArea: XML.Element? {
        root?.firstChild(named: "c:chart")?.firstChild(named: "c:plotArea")
    }

    /// The plot element (`c:barChart`, `c:lineChart`, …) — the first child of
    /// the plot area whose name ends in "Chart".
    var plot: XML.Element? {
        plotArea?.childElements.first { $0.name.hasSuffix("Chart") }
    }

    /// The chart's kind as written, e.g. "barChart" or "scatterChart". Kinds
    /// Rostrum cannot author still read back.
    public var plotType: String? {
        plot.map { String($0.name.dropFirst(2)) }
    }

    /// The chart's title, when it has an explicit one.
    public var title: String? {
        let title = root?.firstChild(named: "c:chart")?.firstChild(named: "c:title")
        guard let rich = title?.firstChild(named: "c:tx")?.firstChild(named: "c:rich") else { return nil }
        let text = rich.children(named: "a:p")
            .map { $0.children(named: "a:r").map { $0.firstChild(named: "a:t")?.textContent ?? "" }.joined() }
            .joined(separator: "\n")
        return text.isEmpty ? nil : text
    }

    /// The `c:ser` elements in document order.
    var seriesElements: [XML.Element] { plot?.children(named: "c:ser") ?? [] }

    /// The categories, read from the first series' `c:cat` cache. Empty for
    /// charts with no category axis (scatter).
    public var categories: [String] {
        guard let cat = seriesElements.first?.firstChild(named: "c:cat") else { return [] }
        return Self.strings(in: cat)
    }

    /// The series: name and values, read from the caches PowerPoint keeps in
    /// the chart XML (so this works without opening the embedded workbook).
    public var series: [ChartData.Series] {
        seriesElements.map { element in
            let name = element.firstChild(named: "c:tx").map { Self.strings(in: $0).first ?? "" } ?? ""
            let values = element.firstChild(named: "c:val").map(Self.numbers(in:)) ?? []
            return ChartData.Series(name: name, values: values)
        }
    }

    /// The plotted data, or nil for a chart with no categories or no series
    /// (a scatter chart, or one Rostrum cannot model as category × series).
    public var data: ChartData? {
        let series = self.series
        let categories = self.categories
        guard !categories.isEmpty, !series.isEmpty,
              series.allSatisfy({ $0.values.count == categories.count }) else { return nil }
        return ChartData(categories: categories, series: series)
    }

    /// The embedded Edit-Data workbook, when the chart has one.
    public var workbookPart: Part? {
        guard let rId = root?.firstChild(named: "c:externalData")?[attribute: "r:id"],
              let rel = part.rels.relationship(withId: rId) else { return nil }
        return try? package.part(
            at: PackURI.resolve(target: rel.target, relativeTo: part.uri.baseURI))
    }

    // MARK: - Replacing data

    /// Why a replacement was refused.
    public enum ReplacementProblem: Error, Equatable, CustomStringConvertible {
        /// The chart has no series elements to update.
        case noSeries
        /// The replacement has a different number of series than the chart.
        case seriesCountMismatch(chart: Int, replacement: Int)
        /// The replacement has a different number of categories.
        case categoryCountMismatch(chart: Int, replacement: Int)
        /// A series in the chart has no `c:val` to write into.
        case seriesMissingValues(index: Int)

        public var description: String {
            switch self {
            case .noSeries:
                return "the chart has no series to replace"
            case .seriesCountMismatch(let chart, let replacement):
                return "chart plots \(chart) series but the replacement has \(replacement); "
                    + "add or remove series explicitly rather than replacing data"
            case .categoryCountMismatch(let chart, let replacement):
                return "chart has \(chart) categories but the replacement has \(replacement)"
            case .seriesMissingValues(let index):
                return "series \(index) has no c:val element to write into"
            }
        }
    }

    /// Check whether `data` can replace this chart's data without changing
    /// its structure. Returns nil when the replacement fits.
    ///
    /// The rule: same series count, same category count. Anything else is a
    /// structural edit, and silently reshaping a chart is exactly how a deck
    /// ends up needing repair.
    public func replacementProblem(for data: ChartData) -> ReplacementProblem? {
        let elements = seriesElements
        guard !elements.isEmpty else { return .noSeries }
        guard elements.count == data.series.count else {
            return .seriesCountMismatch(chart: elements.count, replacement: data.series.count)
        }
        let existing = categories.count
        guard existing == data.categories.count else {
            return .categoryCountMismatch(chart: existing, replacement: data.categories.count)
        }
        for (index, element) in elements.enumerated() where element.firstChild(named: "c:val") == nil {
            return .seriesMissingValues(index: index)
        }
        return nil
    }

    /// Replace the plotted numbers and labels in place, keeping the chart's
    /// structure, formatting and formulas exactly as they are.
    ///
    /// Only the caches and the series names change; `c:f` formulas, colors,
    /// axes, data labels and every element Rostrum does not model are left
    /// untouched. The embedded workbook is rewritten to match, so Edit Data
    /// in PowerPoint shows the new numbers.
    ///
    /// - Throws: `ReplacementProblem` when the replacement would change the
    ///   chart's structure — nothing is written in that case.
    public func replaceData(_ data: ChartData) throws {
        if let problem = replacementProblem(for: data) { throw problem }

        for (index, element) in seriesElements.enumerated() {
            let series = data.series[index]
            if let tx = element.firstChild(named: "c:tx") {
                Self.setStrings([series.name], in: tx)
            }
            if let cat = element.firstChild(named: "c:cat") {
                Self.setStrings(data.categories, in: cat)
            }
            if let val = element.firstChild(named: "c:val") {
                Self.setNumbers(series.values, in: val)
            }
        }
        part.markDirty()

        // Keep Edit Data honest: the workbook is what PowerPoint reopens.
        if let workbook = workbookPart {
            workbook.replaceBlob(ChartWorkbook.make(data: data))
        }
    }

    // MARK: - Cache reading and writing

    /// The strings cached in a `c:cat`/`c:tx` wrapper, in index order. Gaps
    /// (an omitted `c:pt`) come back as empty strings so positions line up
    /// with the values.
    private static func strings(in wrapper: XML.Element) -> [String] {
        guard let ref = wrapper.firstChild(named: "c:strRef") ?? wrapper.firstChild(named: "c:numRef"),
              let cache = ref.firstChild(named: "c:strCache") ?? ref.firstChild(named: "c:numCache")
        else {
            // A literal cache (`c:strLit`/`c:numLit`) is equally valid.
            guard let literal = wrapper.firstChild(named: "c:strLit") ?? wrapper.firstChild(named: "c:numLit")
            else { return [] }
            return points(in: literal).map { $0 ?? "" }
        }
        return points(in: cache).map { $0 ?? "" }
    }

    /// The numbers cached in a `c:val` wrapper; omitted points are nil gaps.
    private static func numbers(in wrapper: XML.Element) -> [Double?] {
        guard let ref = wrapper.firstChild(named: "c:numRef"),
              let cache = ref.firstChild(named: "c:numCache")
        else {
            guard let literal = wrapper.firstChild(named: "c:numLit") else { return [] }
            return points(in: literal).map { $0.flatMap(Double.init) }
        }
        return points(in: cache).map { $0.flatMap(Double.init) }
    }

    /// `c:pt` values by index, sized to `c:ptCount`, with gaps as nil.
    private static func points(in cache: XML.Element) -> [String?] {
        let count = cache.firstChild(named: "c:ptCount")?[attribute: "val"]
            .flatMap { Int($0) } ?? 0
        guard count > 0, count <= 1_000_000 else { return [] }
        var values = [String?](repeating: nil, count: count)
        for point in cache.children(named: "c:pt") {
            guard let index = point[attribute: "idx"].flatMap({ Int($0) }),
                  values.indices.contains(index) else { continue }
            values[index] = point.firstChild(named: "c:v")?.textContent
        }
        return values
    }

    /// Rewrite a string cache in place, leaving `c:f` untouched.
    private static func setStrings(_ strings: [String], in wrapper: XML.Element) {
        guard let cache = stringCache(in: wrapper) else { return }
        replacePoints(in: cache, count: strings.count) { strings[$0] }
    }

    /// Rewrite a numeric cache in place, leaving `c:f` and `c:formatCode`
    /// untouched.
    private static func setNumbers(_ values: [Double?], in wrapper: XML.Element) {
        guard let cache = numberCache(in: wrapper) else { return }
        replacePoints(in: cache, count: values.count) {
            values[$0].map { chartNumber($0) }
        }
    }

    private static func stringCache(in wrapper: XML.Element) -> XML.Element? {
        wrapper.firstChild(named: "c:strRef")?.firstChild(named: "c:strCache")
            ?? wrapper.firstChild(named: "c:numRef")?.firstChild(named: "c:numCache")
            ?? wrapper.firstChild(named: "c:strLit")
    }

    private static func numberCache(in wrapper: XML.Element) -> XML.Element? {
        wrapper.firstChild(named: "c:numRef")?.firstChild(named: "c:numCache")
            ?? wrapper.firstChild(named: "c:numLit")
    }

    /// Replace a cache's `c:pt` run and its `c:ptCount`, preserving whatever
    /// else the cache carries (notably `c:formatCode`).
    private static func replacePoints(
        in cache: XML.Element, count: Int, value: (Int) -> String?
    ) {
        cache.removeChildren(named: "c:pt")
        let ptCount = cache.getOrAddChild("c:ptCount")
        ptCount[attribute: "val"] = String(count)
        for index in 0..<count {
            guard let text = value(index) else { continue }   // a gap
            let point = XML.Element("c:pt", attributes: [("idx", String(index))])
            let v = XML.Element("c:v")
            v.children = [.text(text)]
            point.appendElement(v)
            cache.appendElement(point)
        }
    }
}

public extension ChartFrame {
    /// The chart itself — its kind, its plotted data, and `replaceData`.
    var chart: Chart? {
        guard let part = chartPart, let package else { return nil }
        return Chart(part: part, package: package)
    }
}

public extension Presentation {
    /// Every chart in the deck, in slide then z-order — the entry point for
    /// "open a styled template and swap the numbers".
    var charts: [Chart] {
        slides.flatMap { slide in
            slide.shapes.all.compactMap { ($0 as? ChartFrame)?.chart }
        }
    }
}
