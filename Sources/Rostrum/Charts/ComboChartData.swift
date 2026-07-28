import Foundation

/// Which of a combo chart's two axis pairs a plot group is drawn against.
///
/// `.secondary` gets its own value axis on the right — and, less obviously, its
/// own category axis, which is emitted deleted. A plot group's `c:axId` pair
/// must name axes that exist in the plot area, so the hidden category axis is
/// structural rather than cosmetic.
public enum ChartAxisGroup: Sendable, Hashable {
    case primary, secondary
}

/// A chart whose plot area holds several plot groups — a column-and-line combo
/// being the common case.
///
/// Categories are shared by every group: one array, so the category axis cannot
/// disagree with itself. Series are numbered globally in group order, which is
/// also their column order in the embedded workbook, so an opened combo reads
/// back through `chart.series` in exactly the order it was written.
public struct ComboChartData: Sendable {
    /// One plot group: a run of series drawn the same way, against one axis pair.
    public struct Group: Sendable {
        /// Only the kinds with a shared category axis may appear in a combo:
        /// `.barClustered`, `.barStacked`, `.barPercentStacked`, `.line` and
        /// `.area`. Pie and doughnut carry no axes at all and radar's axes are
        /// polar, so `addComboChart` refuses them by name.
        public var kind: ChartKind
        public var series: [ChartData.Series]
        public var axis: ChartAxisGroup
        /// Colors this group's series, indexed from 0 *within the group*.
        public var colors: [Color]?
        /// Data labels for this group alone. There is no chart-level data-label
        /// element in the format, and one position token is rarely legal for
        /// both a bar group and a line group, so labels belong to the group.
        public var dataLabels: DataLabelOptions?

        public init(kind: ChartKind, series: [ChartData.Series],
                    axis: ChartAxisGroup = .primary,
                    colors: [Color]? = nil, dataLabels: DataLabelOptions? = nil) {
            precondition(!series.isEmpty, "a plot group needs at least one series")
            self.kind = kind
            self.series = series
            self.axis = axis
            self.colors = colors
            self.dataLabels = dataLabels
        }
    }

    public var categories: [String]
    public var groups: [Group]

    public init(categories: [String], groups: [Group]) {
        precondition(!categories.isEmpty, "chart needs at least one category")
        precondition(!groups.isEmpty, "combo chart needs at least one plot group")
        for group in groups {
            for series in group.series {
                precondition(series.values.count == categories.count,
                             "series \"\(series.name)\" has \(series.values.count) values "
                                 + "for \(categories.count) categories")
            }
        }
        self.categories = categories
        self.groups = groups
    }

    /// Every group's series concatenated in emit order — the order `c:idx`,
    /// `c:order` and the workbook columns all follow.
    public var flattened: ChartData {
        ChartData(categories: categories, series: groups.flatMap(\.series))
    }

    /// The index in `flattened` at which `groups[index]`'s series begin.
    func firstSeriesIndex(ofGroup index: Int) -> Int {
        groups[..<index].reduce(0) { $0 + $1.series.count }
    }
}

/// Why a chart could not be authored. Checked before any XML is built, in the
/// same spirit as `Chart.ReplacementProblem`: a chart Rostrum cannot express
/// correctly is refused rather than written and hoped for.
public enum ChartAuthoringProblem: Error, Equatable, CustomStringConvertible {
    /// A combo group asked for a chart kind that has no shared category axis.
    case comboGroupKindNotSupported(kind: String)
    /// Every group was put on the secondary axis, leaving the primary axis pair
    /// with nothing plotted against it.
    case comboNeedsAPrimaryGroup
    /// Two bar groups share one axis pair. PowerPoint merges them into a single
    /// cluster, so the chart it draws would not be the one that was described.
    case comboDuplicateBarGroup(axis: ChartAxisGroup)
    /// More series than the workbook column layout can address.
    case tooManySeries(limit: Int)

    public var description: String {
        switch self {
        case .comboGroupKindNotSupported(let kind):
            return "a \(kind) plot cannot share a combo chart's category axis"
        case .comboNeedsAPrimaryGroup:
            return "every group is on the secondary axis; at least one must be primary"
        case .comboDuplicateBarGroup(let axis):
            return "two bar groups on the \(axis == .primary ? "primary" : "secondary") axis "
                + "would be merged into one cluster by PowerPoint; combine their series into "
                + "a single group instead"
        case .tooManySeries(let limit):
            return "a chart can hold at most \(limit) series"
        }
    }
}

extension ComboChartData {
    /// The kinds a combo group may use. Everything else is refused by name
    /// rather than discovered in PowerPoint's repair dialog.
    static let supportedGroupKinds: Set<ChartKind> = [
        .barClustered, .barStacked, .barPercentStacked, .line, .area,
    ]

    static func isBar(_ kind: ChartKind) -> Bool {
        kind == .barClustered || kind == .barStacked || kind == .barPercentStacked
    }

    /// Everything that must hold before any XML is built. Returns nil when the
    /// combo can be written.
    func authoringProblem() -> ChartAuthoringProblem? {
        for group in groups where !Self.supportedGroupKinds.contains(group.kind) {
            return .comboGroupKindNotSupported(kind: String(describing: group.kind))
        }
        guard groups.contains(where: { $0.axis == .primary }) else {
            return .comboNeedsAPrimaryGroup
        }
        for axis in [ChartAxisGroup.primary, .secondary] {
            let bars = groups.filter { $0.axis == axis && Self.isBar($0.kind) }
            if bars.count > 1 { return .comboDuplicateBarGroup(axis: axis) }
        }
        let total = groups.reduce(0) { $0 + $1.series.count }
        guard total <= 255 else { return .tooManySeries(limit: 255) }
        return nil
    }
}
