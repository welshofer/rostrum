import Foundation

/// Categories × series data for a chart. `nil` values are gaps (the point is
/// omitted from the cache but keeps its index, python-pptx semantics).
public struct ChartData: Sendable {
    public struct Series: Sendable {
        public var name: String
        public var values: [Double?]

        public init(name: String, values: [Double?]) {
            self.name = name
            self.values = values
        }

        public init(name: String, values: [Double]) {
            self.name = name
            self.values = values.map { $0 }
        }
    }

    public var categories: [String]
    public var series: [Series]

    public init(categories: [String], series: [Series]) {
        precondition(!categories.isEmpty, "chart needs at least one category")
        precondition(!series.isEmpty, "chart needs at least one series")
        precondition(series.count <= 255, "too many series")
        for s in series {
            precondition(s.values.count == categories.count,
                         "series \"\(s.name)\" has \(s.values.count) values for \(categories.count) categories")
        }
        self.categories = categories
        self.series = series
    }

    /// Single-series convenience.
    public init(categories: [String], name: String = "Series 1", values: [Double]) {
        self.init(categories: categories, series: [Series(name: name, values: values)])
    }
}

public enum ChartKind: Sendable {
    /// Clustered column chart.
    case barClustered
    /// Stacked column chart.
    case barStacked
    /// 100%-stacked column chart.
    case barPercentStacked
    /// Line chart, no markers.
    case line
    /// Area chart.
    case area
    /// Pie chart (first series only).
    case pie
    /// Doughnut chart (first series only).
    case doughnut
    /// Radar (spider) chart with a line per series and a marker per point.
    case radar
    /// Radar chart with each series' area filled.
    case radarFilled
}

/// Categories × series data for a bubble chart: each point carries an x, a y
/// and a size. The size axis is what distinguishes it from scatter.
public struct BubbleChartData: Sendable {
    public struct Point: Sendable {
        public var x: Double
        public var y: Double
        public var size: Double

        public init(x: Double, y: Double, size: Double) {
            self.x = x
            self.y = y
            self.size = size
        }
    }

    public struct Series: Sendable {
        public var name: String
        public var points: [Point]

        public init(name: String, points: [Point]) {
            self.name = name
            self.points = points
        }
    }

    public var series: [Series]

    public init(series: [Series]) {
        precondition(!series.isEmpty, "bubble chart needs at least one series")
        precondition(series.count <= 255, "too many bubble series")
        self.series = series
    }

    public init(name: String = "Series 1", points: [Point]) {
        self.init(series: [Series(name: name, points: points)])
    }
}

/// Legend placement (`c:legendPos`). Absence of a legend is `nil`.
public enum LegendPosition: String, Sendable {
    case bottom = "b", topRight = "tr", left = "l", right = "r", top = "t"
}

/// Data-label controls (`c:dLbls`). All flags default off.
public struct DataLabelOptions: Sendable {
    public var showValue: Bool
    public var showCategory: Bool
    public var showSeriesName: Bool
    /// Only renders on pie/doughnut.
    public var showPercent: Bool
    /// Number format (e.g. "0.0%", "#,##0"); nil inherits the workbook format.
    public var numberFormat: String?
    /// Label position token (ctr/outEnd/inEnd/bestFit/…); nil = chart default.
    /// Only emit a value valid for the chart kind, or PowerPoint repairs.
    public var position: String?

    public init(showValue: Bool = false, showCategory: Bool = false,
                showSeriesName: Bool = false, showPercent: Bool = false,
                numberFormat: String? = nil, position: String? = nil) {
        self.showValue = showValue
        self.showCategory = showCategory
        self.showSeriesName = showSeriesName
        self.showPercent = showPercent
        self.numberFormat = numberFormat
        self.position = position
    }
}

/// Value-axis controls.
public struct AxisOptions: Sendable {
    public var min: Double?
    public var max: Double?
    public var majorUnit: Double?
    public var numberFormat: String?
    public var title: String?

    public init(min: Double? = nil, max: Double? = nil, majorUnit: Double? = nil,
                numberFormat: String? = nil, title: String? = nil) {
        self.min = min
        self.max = max
        self.majorUnit = majorUnit
        self.numberFormat = numberFormat
        self.title = title
    }
}

/// Optional presentation controls for a chart. Defaults reproduce the prior
/// behaviour (auto title from the series name, legend only on multi-series
/// line charts).
public struct ChartOptions: Sendable {
    public var title: String?
    public var legend: LegendPosition?
    public var dataLabels: DataLabelOptions?
    public var valueAxis: AxisOptions
    public var categoryAxisTitle: String?

    public init(title: String? = nil, legend: LegendPosition? = nil,
                dataLabels: DataLabelOptions? = nil, valueAxis: AxisOptions = AxisOptions(),
                categoryAxisTitle: String? = nil) {
        self.title = title
        self.legend = legend
        self.dataLabels = dataLabels
        self.valueAxis = valueAxis
        self.categoryAxisTitle = categoryAxisTitle
    }
}

/// XY (scatter) data: each series is a set of (x, y) points; scatter has no
/// shared categories.
public struct XYChartData: Sendable {
    public struct Series: Sendable {
        public var name: String
        public var points: [(x: Double, y: Double)]
        public init(name: String, points: [(x: Double, y: Double)]) {
            self.name = name
            self.points = points
        }
    }
    public var series: [Series]
    public init(series: [Series]) {
        precondition(!series.isEmpty, "scatter chart needs at least one series")
        // Scatter uses two columns per series; seriesColumn now spans multi-
        // letter Excel columns, so the practical bound is just sanity.
        precondition(series.count <= 255, "too many scatter series")
        self.series = series
    }
    public init(name: String = "Series 1", points: [(x: Double, y: Double)]) {
        self.init(series: [Series(name: name, points: points)])
    }
}

/// Invariant-locale minimal decimal formatting for c:v values ("19.2", "42").
func chartNumber(_ value: Double) -> String {
    if value == value.rounded(), abs(value) < 1e15 {
        return String(Int(value))
    }
    return String(format: "%.10g", value)
}

/// Spreadsheet column letter for series index 0 → "B", 1 → "C", … 24 → "Z",
/// 25 → "AA", … — proper multi-letter Excel columns (column A holds the
/// categories/x-values). A single-letter `65 + index` would overflow past "Z"
/// into invalid columns like "[" for scatter charts, which pack two columns
/// per series and so reach index 25+ well before 24 series.
func seriesColumn(_ index: Int) -> String {
    var column = index + 1  // 0-based spreadsheet column: A=0, B=1, …
    var letters = ""
    repeat {
        letters = String(UnicodeScalar(UInt8(65 + column % 26))) + letters
        column = column / 26 - 1
    } while column >= 0
    return letters
}
