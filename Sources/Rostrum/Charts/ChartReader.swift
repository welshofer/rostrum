import Foundation

/// A chart in an opened deck: what kind it is, the data it plots, and a
/// `replaceData` that refuses to corrupt it.
///
/// python-pptx's `replace_data` rewrites the chart XML from a fresh data
/// model and is well known to produce decks PowerPoint offers to repair when
/// the replacement's shape does not match the chart's structure. Rostrum
/// takes the opposite stance: the chart's own XML is the authority, the
/// replacement is validated against everything the write would touch, and any
/// mismatch throws before a single byte is written.
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

    /// The `c:plotArea` element, where the per-kind plots live.
    private var plotArea: XML.Element? {
        root?.firstChild(named: "c:chart")?.firstChild(named: "c:plotArea")
    }

    /// Every plot group in the plot area (`c:barChart`, `c:lineChart`, …).
    /// A combo chart legally holds several, and a reader that sees only the
    /// first reports half a chart.
    var plots: [XML.Element] {
        plotArea?.childElements.filter { $0.name.hasSuffix("Chart") } ?? []
    }

    /// The plot types present, in document order: `["barChart", "lineChart"]`
    /// for a combo chart. Kinds Rostrum cannot author still read back.
    public var plotTypes: [String] {
        plots.map { String($0.name.dropFirst(2)) }
    }

    /// The first plot type — the common single-plot case. Use `plotTypes`
    /// when a combo chart is possible.
    public var plotType: String? { plotTypes.first }

    /// True when this chart plots more than one group (a combo chart).
    public var isCombo: Bool { plots.count > 1 }

    /// The chart's title, from either a rich-text title or one linked to a
    /// workbook cell.
    public var title: String? {
        guard let tx = root?.firstChild(named: "c:chart")?
            .firstChild(named: "c:title")?.firstChild(named: "c:tx") else { return nil }
        if let rich = tx.firstChild(named: "c:rich") {
            let text = rich.children(named: "a:p")
                .map { $0.children(named: "a:r").map { $0.firstChild(named: "a:t")?.textContent ?? "" }.joined() }
                .joined(separator: "\n")
            return text.isEmpty ? nil : text
        }
        let linked = Self.strings(in: tx).first
        return (linked?.isEmpty ?? true) ? nil : linked
    }

    /// The `c:ser` elements across **every** plot group, in document order.
    var seriesElements: [XML.Element] { plots.flatMap { $0.children(named: "c:ser") } }

    /// The categories, read from the first series that carries a readable
    /// `c:cat`. Empty for charts with no category axis (scatter), for
    /// multi-level category axes, and for encodings Rostrum cannot read.
    public var categories: [String] {
        for element in seriesElements {
            guard let cat = element.firstChild(named: "c:cat") else { continue }
            let strings = Self.strings(in: cat)
            if !strings.isEmpty { return strings }
        }
        return []
    }

    /// The series across every plot group: name and values, read from the
    /// caches PowerPoint keeps in the chart XML (so no workbook parsing).
    public var series: [ChartData.Series] {
        seriesElements.map { element in
            let name = element.firstChild(named: "c:tx").map { Self.strings(in: $0).first ?? "" } ?? ""
            let values = element.firstChild(named: "c:val").map(Self.numbers(in:)) ?? []
            return ChartData.Series(name: name, values: values)
        }
    }

    /// The plotted data, or nil for a chart Rostrum cannot express as
    /// categories × series (scatter, multi-level categories, or series of
    /// differing lengths).
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

    /// Why a replacement was refused. Every case is checked *before* anything
    /// is written.
    public enum ReplacementProblem: Error, Equatable, CustomStringConvertible {
        /// The chart has no series elements to update.
        case noSeries
        /// The replacement has a different number of series than the chart.
        case seriesCountMismatch(chart: Int, replacement: Int)
        /// The replacement has a different number of categories.
        case categoryCountMismatch(chart: Int, replacement: Int)
        /// A series holds a different number of values than the replacement,
        /// so writing would resize it.
        case seriesValueCountMismatch(index: Int, chart: Int, replacement: Int)
        /// A series has no cache the new values could be written into.
        case seriesNotWritable(index: Int, missing: String)
        /// The category axis is numeric or date-typed; writing category
        /// *strings* into its numeric cache would corrupt the axis.
        case categoryAxisIsNotText(index: Int)
        /// The categories use an encoding Rostrum cannot read or rewrite
        /// (notably `c:multiLvlStrRef`, a grouped category axis).
        case categoryEncodingUnsupported(index: Int)
        /// The chart's data formulas do not describe the layout Rostrum's
        /// embedded workbook uses, so refreshing the workbook would leave
        /// Edit Data pointing at cells that no longer exist.
        case workbookLayoutNotRecognized(formula: String)

        public var description: String {
            switch self {
            case .noSeries:
                return "the chart has no series to replace"
            case .seriesCountMismatch(let chart, let replacement):
                return "chart plots \(chart) series but the replacement has \(replacement); "
                    + "add or remove series explicitly rather than replacing data"
            case .categoryCountMismatch(let chart, let replacement):
                return "chart has \(chart) categories but the replacement has \(replacement)"
            case .seriesValueCountMismatch(let index, let chart, let replacement):
                return "series \(index) holds \(chart) values but the replacement has \(replacement)"
            case .seriesNotWritable(let index, let missing):
                return "series \(index) has no \(missing) to write into"
            case .categoryAxisIsNotText(let index):
                return "series \(index) has a numeric or date category axis; "
                    + "writing text categories into it would corrupt the axis"
            case .categoryEncodingUnsupported(let index):
                return "series \(index) uses a category encoding Rostrum cannot rewrite "
                    + "(a multi-level category axis)"
            case .workbookLayoutNotRecognized(let formula):
                return "the chart's data references \(formula), which is not the layout "
                    + "Rostrum's embedded workbook uses; replacing the numbers would leave "
                    + "Edit Data pointing at cells that no longer exist"
            }
        }
    }

    /// Check whether `data` can replace this chart's data without changing
    /// its structure or breaking anything the write cannot round-trip.
    /// Returns nil when the replacement fits.
    public func replacementProblem(for data: ChartData) -> ReplacementProblem? {
        let elements = seriesElements
        guard !elements.isEmpty else { return .noSeries }
        guard elements.count == data.series.count else {
            return .seriesCountMismatch(chart: elements.count, replacement: data.series.count)
        }
        // Structural shape first: a chart with no c:val at all (scatter,
        // bubble) is not a category chart, and saying so is more useful than
        // reporting a category-count mismatch against zero.
        for (index, element) in elements.enumerated()
        where element.firstChild(named: "c:val") == nil {
            return .seriesNotWritable(index: index, missing: "c:val")
        }

        let existing = categories.count
        guard existing == data.categories.count else {
            return .categoryCountMismatch(chart: existing, replacement: data.categories.count)
        }

        for (index, element) in elements.enumerated() {
            // Values must be writable, and must not be resized.
            guard let val = element.firstChild(named: "c:val") else {
                return .seriesNotWritable(index: index, missing: "c:val")
            }
            guard Self.numberCache(in: val) != nil else {
                return .seriesNotWritable(index: index, missing: "a numeric cache in c:val")
            }
            let count = Self.numbers(in: val).count
            guard count == data.series[index].values.count else {
                return .seriesValueCountMismatch(
                    index: index, chart: count, replacement: data.series[index].values.count)
            }

            // The series name must be writable, or the rename silently vanishes.
            if let tx = element.firstChild(named: "c:tx"), Self.stringCache(in: tx) == nil {
                return .seriesNotWritable(index: index, missing: "a writable cache in c:tx")
            }

            // Categories must be text-encoded: writing strings into the
            // numeric cache of a date or numeric axis corrupts it.
            if let cat = element.firstChild(named: "c:cat") {
                if cat.firstChild(named: "c:multiLvlStrRef") != nil {
                    return .categoryEncodingUnsupported(index: index)
                }
                if Self.textCache(in: cat) == nil {
                    return Self.numberCache(in: cat) != nil
                        ? .categoryAxisIsNotText(index: index)
                        : .categoryEncodingUnsupported(index: index)
                }
            }
        }

        // The workbook is rewritten from Rostrum's canonical layout, so the
        // chart's surviving formulas must be that layout — otherwise the
        // refreshed workbook would not contain the cells they name.
        if workbookPart != nil,
           let formula = unrecognizedWorkbookFormula(for: data, in: elements) {
            return .workbookLayoutNotRecognized(formula: formula)
        }
        return nil
    }

    /// The first `c:f` that does not match the layout `ChartWorkbook.make`
    /// writes, or nil when every formula matches.
    private func unrecognizedWorkbookFormula(
        for data: ChartData, in elements: [XML.Element]
    ) -> String? {
        let lastRow = data.categories.count + 1
        for (index, element) in elements.enumerated() {
            let column = seriesColumn(index)
            let expected: [(String, String)] = [
                ("c:tx", "Sheet1!$\(column)$1"),
                ("c:cat", "Sheet1!$A$2:$A$\(lastRow)"),
                ("c:val", "Sheet1!$\(column)$2:$\(column)$\(lastRow)"),
            ]
            for (child, wanted) in expected {
                guard let wrapper = element.firstChild(named: child),
                      let formula = Self.formula(in: wrapper) else { continue }
                // Excel quotes sheet names that need it; accept both spellings.
                let normalized = formula.replacingOccurrences(of: "'", with: "")
                if normalized != wanted { return formula }
            }
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
    ///   chart's structure, resize a series, land in a cache that cannot hold
    ///   it, or desynchronize the embedded workbook from the chart's
    ///   formulas. Nothing is written in any of those cases.
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
        // Validation above proved the formulas describe exactly this layout.
        if let workbook = workbookPart {
            workbook.replaceBlob(ChartWorkbook.make(data: data))
        }
    }

    // MARK: - Cache reading and writing

    private static func formula(in wrapper: XML.Element) -> String? {
        for child in wrapper.childElements {
            if let f = child.firstChild(named: "c:f") { return f.textContent }
        }
        return nil
    }

    /// The strings cached in a `c:cat`/`c:tx` wrapper, in index order. Gaps
    /// come back as empty strings so positions line up with the values.
    /// Handles a bare `c:v` (a literal series name), which is legal.
    static func strings(in wrapper: XML.Element) -> [String] {
        if let literalName = wrapper.firstChild(named: "c:v") {
            return [literalName.textContent]
        }
        if let cache = textCache(in: wrapper) ?? numberCache(in: wrapper) {
            return points(in: cache).map { $0 ?? "" }
        }
        return []
    }

    /// The numbers cached in a `c:val` wrapper; omitted points are nil gaps.
    static func numbers(in wrapper: XML.Element) -> [Double?] {
        guard let cache = numberCache(in: wrapper) else { return [] }
        return points(in: cache).map { $0.flatMap(Double.init) }
    }

    /// `c:pt` values by index, sized to `c:ptCount` — or, when that optional
    /// element is absent, to the highest index actually present.
    private static func points(in cache: XML.Element) -> [String?] {
        let points = cache.children(named: "c:pt")
        let declared = cache.firstChild(named: "c:ptCount")?[attribute: "val"].flatMap { Int($0) }
        let highest = points.compactMap { $0[attribute: "idx"].flatMap { Int($0) } }.max()
        let count = declared ?? highest.map { $0 + 1 } ?? 0
        guard count > 0, count <= 1_000_000 else { return [] }
        var values = [String?](repeating: nil, count: count)
        for point in points {
            guard let index = point[attribute: "idx"].flatMap({ Int($0) }),
                  values.indices.contains(index) else { continue }
            values[index] = point.firstChild(named: "c:v")?.textContent
        }
        return values
    }

    /// A **text** cache: `c:strCache` or `c:strLit` only. Deliberately does
    /// not fall back to a numeric cache — writing category strings into one
    /// corrupts a date or numeric axis.
    static func textCache(in wrapper: XML.Element) -> XML.Element? {
        wrapper.firstChild(named: "c:strRef")?.firstChild(named: "c:strCache")
            ?? wrapper.firstChild(named: "c:strLit")
    }

    static func numberCache(in wrapper: XML.Element) -> XML.Element? {
        wrapper.firstChild(named: "c:numRef")?.firstChild(named: "c:numCache")
            ?? wrapper.firstChild(named: "c:numLit")
    }

    /// The cache a string write may target — text caches only.
    static func stringCache(in wrapper: XML.Element) -> XML.Element? {
        textCache(in: wrapper)
    }

    private static func setStrings(_ strings: [String], in wrapper: XML.Element) {
        guard let cache = textCache(in: wrapper) else { return }
        replacePoints(in: cache, count: strings.count) { strings[$0] }
    }

    private static func setNumbers(_ values: [Double?], in wrapper: XML.Element) {
        guard let cache = numberCache(in: wrapper) else { return }
        replacePoints(in: cache, count: values.count) {
            values[$0].map { chartNumber($0) }
        }
    }

    /// Replace a cache's `c:pt` run and its `c:ptCount`, preserving whatever
    /// else the cache carries — notably `c:formatCode`, and a trailing
    /// `c:extLst`, which the sequence requires the points to precede.
    private static func replacePoints(
        in cache: XML.Element, count: Int, value: (Int) -> String?
    ) {
        cache.removeChildren(named: "c:pt")
        let ptCount = cache.getOrAddChild("c:ptCount", beforeAnyOf: ["c:pt", "c:extLst"])
        ptCount[attribute: "val"] = String(count)
        for index in 0..<count {
            guard let text = value(index) else { continue }   // a gap
            let point = XML.Element("c:pt", attributes: [("idx", String(index))])
            let v = XML.Element("c:v")
            v.children = [.text(text)]
            point.appendElement(v)
            cache.insertChild(point, beforeAnyOf: ["c:extLst"])
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

public extension Slide {
    /// Every chart on this slide, including charts nested inside groups.
    var charts: [Chart] {
        Self.charts(in: shapes.all)
    }

    private static func charts(in shapes: [Shape]) -> [Chart] {
        shapes.flatMap { shape -> [Chart] in
            if let group = shape as? GroupShape { return charts(in: group.shapes) }
            return ((shape as? ChartFrame)?.chart).map { [$0] } ?? []
        }
    }
}

public extension Presentation {
    /// Every chart in the deck, in slide then z-order, including charts
    /// nested inside groups — the entry point for "open a styled template and
    /// swap the numbers".
    var charts: [Chart] {
        slides.flatMap(\.charts)
    }
}
