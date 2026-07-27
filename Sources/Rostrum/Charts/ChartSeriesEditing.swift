import Foundation

// MARK: - XY read-back (scatter and bubble)

public extension Chart {
    /// One point of an XY series. `x` and `y` are nil where the cache has a
    /// gap; `size` is nil on scatter charts — only bubble carries a size axis.
    struct XYPoint: Sendable, Equatable {
        public let x: Double?
        public let y: Double?
        public let size: Double?

        public init(x: Double?, y: Double?, size: Double? = nil) {
            self.x = x
            self.y = y
            self.size = size
        }
    }

    /// A scatter or bubble series: a name and a list of points, read from the
    /// caches in the chart XML.
    struct XYSeries: Sendable {
        public let name: String
        public let points: [XYPoint]
        /// The x-axis labels when the chart encodes its x values as *text*
        /// (a `c:strRef` in `c:xVal`) — legal, and what PowerPoint writes for
        /// a scatter chart built over a text column. When this is non-empty
        /// every point's `x` is nil, and these are the labels in point order.
        public let xLabels: [String]

        public init(name: String, points: [XYPoint], xLabels: [String] = []) {
            self.name = name
            self.points = points
            self.xLabels = xLabels
        }
    }

    /// True when every plot group is an XY plot. Such a chart has no category
    /// axis, so `categories` is empty and `data` is nil by design — read it
    /// through `xySeries` instead.
    var isXY: Bool {
        let plots = self.plots
        return !plots.isEmpty && plots.allSatisfy {
            $0.name == "c:scatterChart" || $0.name == "c:bubbleChart"
        }
    }

    /// The XY series across every plot group, in document order. Empty for a
    /// chart whose series carry no `c:yVal` (i.e. any category chart).
    ///
    /// Series are read independently, so a bubble chart whose series have
    /// different point counts — legal, and what a hand-edited deck often has —
    /// reads back faithfully rather than collapsing to nil the way the
    /// category-shaped `data` does.
    var xySeries: [XYSeries] {
        seriesElements.compactMap { element in
            guard let yWrapper = element.firstChild(named: "c:yVal") else { return nil }
            let name = element.firstChild(named: "c:tx")
                .map { Chart.strings(in: $0).first ?? "" } ?? ""
            let xWrapper = element.firstChild(named: "c:xVal")
            // A c:xVal is a choice: numeric (the usual case) or text. Only one
            // of the two reads back, and which one it was must stay visible.
            let xValues = xWrapper.map { Chart.numbers(in: $0) } ?? []
            let xLabels = xValues.isEmpty
                ? (xWrapper.map { Chart.strings(in: $0) } ?? []) : []
            let yValues = Chart.numbers(in: yWrapper)
            let sizes = element.firstChild(named: "c:bubbleSize")
                .map { Chart.numbers(in: $0) } ?? []
            let count = max(max(xValues.count, xLabels.count), max(yValues.count, sizes.count))
            let points = (0..<count).map { index in
                XYPoint(x: index < xValues.count ? xValues[index] : nil,
                        y: index < yValues.count ? yValues[index] : nil,
                        size: index < sizes.count ? sizes[index] : nil)
            }
            return XYSeries(name: name, points: points, xLabels: xLabels)
        }
    }
}

// MARK: - Adding and removing series

public extension Chart {
    /// Why a series could not be added or removed. Like `ReplacementProblem`,
    /// every case is decided *before* anything is written.
    enum SeriesEditProblem: Error, Equatable, CustomStringConvertible {
        /// The chart is not a plain categories × series chart — scatter,
        /// bubble, a multi-level category axis, or series of differing lengths.
        case notACategoryChart
        /// The chart plots more than one group; which group a new series
        /// belongs to, and how the workbook columns interleave, is ambiguous.
        case comboChartNotSupported(plotTypes: [String])
        /// The chart's existing structure blocks any in-place write. Carries
        /// the same diagnosis `replacementProblem(for:)` gives.
        case structureNotEditable(ReplacementProblem)
        /// The chart has no embedded Edit-Data workbook, so its series
        /// reference something Rostrum did not write and cannot renumber.
        case noEmbeddedWorkbook
        /// A series stores its data inline (`c:strLit`/`c:numLit`) instead of
        /// referencing the workbook, so the column layout an edit depends on
        /// does not exist.
        case literalDataNotSupported(index: Int)
        /// This chart type plots only its first series, so an added one would
        /// be invisible.
        case chartTypePlotsOneSeries(plotType: String)
        /// The new series has a different number of values than the chart has
        /// categories.
        case valueCountMismatch(categories: Int, values: Int)
        /// `removeSeries(at:)` was given an index the chart does not have.
        case seriesIndexOutOfRange(index: Int, count: Int)
        /// Removing this series would leave the chart with none.
        case wouldLeaveNoSeries
        /// The chart would exceed the number of series a workbook column
        /// layout can address.
        case tooManySeries(limit: Int)

        public var description: String {
            switch self {
            case .notACategoryChart:
                return "this chart is not a categories × series chart, so a series cannot "
                    + "be added or removed by category values"
            case .comboChartNotSupported(let plotTypes):
                return "this chart plots \(plotTypes.joined(separator: " + ")); which group a "
                    + "series belongs to is ambiguous, so Rostrum refuses to guess"
            case .structureNotEditable(let problem):
                return "the chart cannot be edited in place: \(problem)"
            case .noEmbeddedWorkbook:
                return "the chart has no embedded Edit-Data workbook; its series reference "
                    + "data Rostrum did not write and must not renumber"
            case .literalDataNotSupported(let index):
                return "series \(index) stores its data inline rather than referencing the "
                    + "workbook, so there are no columns to renumber"
            case .chartTypePlotsOneSeries(let plotType):
                return "a \(plotType) plots only its first series, so an added one would "
                    + "never be drawn"
            case .valueCountMismatch(let categories, let values):
                return "the chart has \(categories) categories but the new series has "
                    + "\(values) values"
            case .seriesIndexOutOfRange(let index, let count):
                return "series \(index) does not exist; the chart has \(count)"
            case .wouldLeaveNoSeries:
                return "removing the last series would leave the chart with nothing to plot; "
                    + "delete the chart shape instead"
            case .tooManySeries(let limit):
                return "a chart can hold at most \(limit) series"
            }
        }
    }

    /// Check whether a series of `values` can be appended. Returns nil when it
    /// can. `name` is accepted for symmetry with `addSeries` and never itself
    /// a reason to refuse.
    func addSeriesProblem(name: String, values: [Double?]) -> SeriesEditProblem? {
        switch editableState() {
        case .blocked(let problem):
            return problem
        case .ok(let plot, let data):
            return Self.additionProblem(to: plot, data: data, values: values)
        }
    }

    /// Check whether the series at `index` can be removed. Returns nil when it
    /// can.
    func removeSeriesProblem(at index: Int) -> SeriesEditProblem? {
        switch editableState() {
        case .blocked(let problem):
            return problem
        case .ok(let plot, _):
            return Self.removalProblem(from: plot, at: index)
        }
    }

    /// Append a series to the chart, keeping every existing series exactly as
    /// it is.
    ///
    /// The new `c:ser` is cloned from the last existing one so it inherits the
    /// per-kind children its siblings have (`c:marker`, `c:smooth`,
    /// `c:invertIfNegative`, and any series-level `c:dLbls` settings), then
    /// four things are replaced: its index, its name, its values, and the
    /// workbook columns its formulas name. Identity-carrying formatting is
    /// *not* inherited — `c:spPr` (the sibling's explicit color), `c:dPt`
    /// (per-point overrides), the per-point `c:dLbl` entries inside `c:dLbls`,
    /// and `c:extLst` (which carries a unique series id that must not be
    /// duplicated) are dropped, so PowerPoint colors the new series from the
    /// theme the way it does when you add one by hand.
    ///
    /// The embedded workbook is rewritten so Edit Data shows the new column.
    ///
    /// - Throws: `SeriesEditProblem` when the chart's structure cannot take a
    ///   series without Rostrum having to guess. Nothing is written in that
    ///   case.
    func addSeries(name: String, values: [Double?]) throws {
        let plot: XML.Element
        let current: ChartData
        switch editableState() {
        case .blocked(let problem): throw problem
        case .ok(let element, let data):
            plot = element
            current = data
        }
        if let problem = Self.additionProblem(to: plot, data: current, values: values) {
            throw problem
        }

        let existing = plot.children(named: "c:ser")
        // additionProblem proved the chart has at least one series to clone.
        guard let template = existing.last else { throw SeriesEditProblem.notACategoryChart }
        let element = template.deepCopy()
        for identityBearing in ["c:spPr", "c:dPt", "c:extLst"] {
            element.removeChildren(named: identityBearing)
        }
        element.firstChild(named: "c:dLbls")?.removeChildren(named: "c:dLbl")

        let index = existing.count
        element.firstChild(named: "c:idx")?[attribute: "val"] = String(index)
        element.firstChild(named: "c:order")?[attribute: "val"] = String(index)
        Self.retarget(element, at: index, lastRow: current.categories.count + 1)
        if let tx = element.firstChild(named: "c:tx") { Self.setStrings([name], in: tx) }
        if let val = element.firstChild(named: "c:val") { Self.setNumbers(values, in: val) }

        // A c:ser run is contiguous and precedes the plot's own children
        // (c:dLbls, c:gapWidth, c:axId …), so "after the last one" is the only
        // schema-correct place for it.
        if let last = plot.children.lastIndex(where: {
            if case .element(let e) = $0 { return e.name == "c:ser" }
            return false
        }) {
            plot.children.insert(.element(element), at: last + 1)
        } else {
            plot.appendElement(element)
        }
        part.markDirty()

        let updated = ChartData(categories: current.categories,
                                series: current.series
                                    + [ChartData.Series(name: name, values: values)])
        workbookPart?.replaceBlob(ChartWorkbook.make(data: updated))
    }

    /// Append a series with no gaps.
    func addSeries(name: String, values: [Double]) throws {
        try addSeries(name: name, values: values.map { Optional($0) })
    }

    /// Remove the series at `index`, renumbering the survivors.
    ///
    /// Each surviving series keeps its own formatting but has its `c:idx`,
    /// `c:order` and workbook formulas rewritten to its new position, any
    /// `c:legendEntry` referring to the removed series is dropped and the
    /// later entries shifted down, and the embedded workbook is rewritten
    /// without the removed column.
    ///
    /// - Throws: `SeriesEditProblem`, including when this is the chart's last
    ///   series — an empty chart is a shape to delete, not a chart to write.
    ///   Nothing is written when it throws.
    func removeSeries(at index: Int) throws {
        let plot: XML.Element
        let current: ChartData
        switch editableState() {
        case .blocked(let problem): throw problem
        case .ok(let element, let data):
            plot = element
            current = data
        }
        if let problem = Self.removalProblem(from: plot, at: index) { throw problem }

        plot.removeChild(plot.children(named: "c:ser")[index])
        let lastRow = current.categories.count + 1
        for (position, element) in plot.children(named: "c:ser").enumerated() {
            element.firstChild(named: "c:idx")?[attribute: "val"] = String(position)
            element.firstChild(named: "c:order")?[attribute: "val"] = String(position)
            Self.retarget(element, at: position, lastRow: lastRow)
        }
        shiftLegendEntries(removing: index)
        part.markDirty()

        var series = current.series
        series.remove(at: index)
        workbookPart?.replaceBlob(
            ChartWorkbook.make(data: ChartData(categories: current.categories, series: series)))
    }
}

// MARK: - Eligibility

extension Chart {
    /// A chart that can take a structural edit, or the reason it cannot.
    enum EditableState {
        case ok(plot: XML.Element, data: ChartData)
        case blocked(SeriesEditProblem)
    }

    /// Chart types that draw their first series and ignore the rest.
    private static let singleSeriesPlots: Set<String> = [
        "c:pieChart", "c:pie3DChart", "c:ofPieChart",
    ]

    /// Everything a structural edit needs to be safe, checked once.
    ///
    /// The core test is deliberately the strictest one available: a chart is
    /// editable only if it could accept *its own data* back through
    /// `replaceData`. That single question covers writable caches, a text
    /// category axis, readable series, and — crucially — that the chart's
    /// formulas describe the workbook layout Rostrum rewrites, because after
    /// an add or a remove the workbook must still agree with them.
    func editableState() -> EditableState {
        let plots = self.plots
        guard plots.count <= 1 else {
            return .blocked(.comboChartNotSupported(plotTypes: plotTypes))
        }
        guard let plot = plots.first, let current = data else {
            return .blocked(.notACategoryChart)
        }
        if let problem = replacementProblem(for: current) {
            return .blocked(.structureNotEditable(problem))
        }
        guard workbookPart != nil else { return .blocked(.noEmbeddedWorkbook) }

        for (index, element) in plot.children(named: "c:ser").enumerated() {
            // Renumbering writes c:idx/c:order; a series without them is not
            // something we can reposition.
            for required in ["c:idx", "c:order"] where element.firstChild(named: required) == nil {
                return .blocked(.structureNotEditable(
                    .seriesNotWritable(index: index, missing: required)))
            }
            // Renumbering also rewrites formulas. Literal caches have none, so
            // their column layout is not ours to shift.
            for wrapper in ["c:tx", "c:cat", "c:val"] {
                guard let child = element.firstChild(named: wrapper) else { continue }
                if Chart.formula(in: child) == nil {
                    return .blocked(.literalDataNotSupported(index: index))
                }
            }
        }
        return .ok(plot: plot, data: current)
    }

    private static func additionProblem(
        to plot: XML.Element, data: ChartData, values: [Double?]
    ) -> SeriesEditProblem? {
        if singleSeriesPlots.contains(plot.name) {
            return .chartTypePlotsOneSeries(plotType: String(plot.name.dropFirst(2)))
        }
        let count = plot.children(named: "c:ser").count
        guard count > 0 else { return .notACategoryChart }
        guard count < 255 else { return .tooManySeries(limit: 255) }
        guard values.count == data.categories.count else {
            return .valueCountMismatch(categories: data.categories.count, values: values.count)
        }
        return nil
    }

    private static func removalProblem(
        from plot: XML.Element, at index: Int
    ) -> SeriesEditProblem? {
        let count = plot.children(named: "c:ser").count
        guard index >= 0, index < count else {
            return .seriesIndexOutOfRange(index: index, count: count)
        }
        guard count > 1 else { return .wouldLeaveNoSeries }
        return nil
    }

    /// Point a series' formulas at the workbook columns for `index`. The
    /// category range is shared by every series and never moves.
    private static func retarget(_ element: XML.Element, at index: Int, lastRow: Int) {
        let column = seriesColumn(index)
        if let tx = element.firstChild(named: "c:tx") {
            setFormula("Sheet1!$\(column)$1", in: tx)
        }
        if let val = element.firstChild(named: "c:val") {
            setFormula("Sheet1!$\(column)$2:$\(column)$\(lastRow)", in: val)
        }
    }

    /// `c:legendEntry` addresses a series by index, so a removal that does not
    /// shift them leaves formatting attached to the wrong series — or to one
    /// that no longer exists.
    private func shiftLegendEntries(removing index: Int) {
        guard let legend = root?.firstChild(named: "c:chart")?
            .firstChild(named: "c:legend") else { return }
        for entry in legend.children(named: "c:legendEntry") {
            guard let idx = entry.firstChild(named: "c:idx"),
                  let value = idx[attribute: "val"].flatMap({ Int($0) }) else { continue }
            if value == index {
                legend.removeChild(entry)
            } else if value > index {
                idx[attribute: "val"] = String(value - 1)
            }
        }
    }
}
