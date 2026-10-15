import Foundation

/// An immutable snapshot of one parsed font face and its exact source bytes.
/// Validate `metrics`, then register this value in one or more font libraries
/// without parsing the same face again. No operating-system lookup, shared cache
/// or document embedding occurs. Retention is controlled by the caller.
///
/// For collections, `fontIndex` selects the measured face; `data` retains the
/// complete collection. Preparation does not make a collection embeddable in SVG
/// or bypass the source font's embedding restrictions.
public struct PreparedFont: Sendable {
    public let data: Data
    public let fontIndex: Int
    public let metrics: FontMetrics

    /// Parse the supplied bytes once. Subsequent changes to the caller's Data
    /// do not change this snapshot; prepare a new value for changed content.
    public init(data: Data, fontIndex: Int = 0) throws {
        metrics = try FontMetrics(data: data, fontIndex: fontIndex)
        self.data = data
        self.fontIndex = fontIndex
    }

    /// Read a fresh file snapshot and parse its selected face. This value does
    /// not watch the URL: construct a new one when the file may have changed.
    public init(contentsOf url: URL, fontIndex: Int = 0) throws {
        try self.init(data: Data(contentsOf: url), fontIndex: fontIndex)
    }
}
