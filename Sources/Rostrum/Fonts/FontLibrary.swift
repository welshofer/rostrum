import Foundation

/// The deck's font registry: typeface name → parsed `FontMetrics`, consulted
/// by the design layer's builders and the SVG renderer.
///
/// Registration is **explicit only**. The library never looks in platform
/// font directories — implicit lookup would make identical code produce
/// different bytes on different machines, and determinism is a feature.
/// A deck built with an empty library behaves exactly as before the metrics
/// engine existed (the builders' calibrated estimates).
public final class FontLibrary {
    /// Lowercased typeface name → metrics.
    private var byName: [String: FontMetrics] = [:]

    public init() {}

    /// Register a font from raw bytes under its own family names (`name`
    /// table IDs 1 and 16) plus any `aliases`. Returns the primary name it
    /// registered under. Throws when the font is unparseable, or when it has
    /// no name table and no aliases were given.
    @discardableResult
    public func register(_ data: Data, aliases: [String] = [], fontIndex: Int = 0) throws -> String {
        let metrics = try FontMetrics(data: data, fontIndex: fontIndex)
        let names = metrics.familyNames + aliases
        guard let primary = names.first else {
            throw RostrumError.fontCorrupt(
                "font has no family name; pass aliases: when registering")
        }
        for name in names {
            byName[name.lowercased()] = metrics
        }
        return primary
    }

    /// Register a font file (`.ttf`, `.otf`, `.ttc`) from disk.
    @discardableResult
    public func register(contentsOf url: URL, aliases: [String] = [], fontIndex: Int = 0) throws -> String {
        try register(try Data(contentsOf: url), aliases: aliases, fontIndex: fontIndex)
    }

    /// Metrics for a typeface name, case-insensitive; nil when unregistered.
    public func metrics(for typeface: String) -> FontMetrics? {
        byName[typeface.lowercased()]
    }

    public var isEmpty: Bool { byName.isEmpty }
}
