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
        precondition(series.count <= 24, "series beyond column Z are not supported yet")
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
    /// Line chart, no markers.
    case line
    /// Pie chart (first series only).
    case pie
}

/// Invariant-locale minimal decimal formatting for c:v values ("19.2", "42").
func chartNumber(_ value: Double) -> String {
    if value == value.rounded(), abs(value) < 1e15 {
        return String(Int(value))
    }
    return String(format: "%.10g", value)
}

/// Spreadsheet column letter for series index 0 → "B", 1 → "C", …
func seriesColumn(_ index: Int) -> String {
    String(UnicodeScalar(UInt8(66 + index)))
}
