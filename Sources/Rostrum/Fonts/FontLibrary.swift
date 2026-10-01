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
    /// Distinct styles never overwrite one another.
    private var byFace: [FontFaceKey: FontMetrics] = [:]
    private var sourceData: [FontFaceKey: Data] = [:]

    public init() {}

    /// Register a font from raw bytes under its own family names (`name`
    /// table IDs 1 and 16) plus any `aliases`. Returns the primary name it
    /// registered under. Throws when the font is unparseable, or when it has
    /// no name table and no aliases were given.
    ///
    /// Infers bold/italic from OS/2 fsSelection, falling back to head macStyle.
    /// Registering the same exact face again replaces it; other styles persist.
    @discardableResult
    public func register(_ data: Data, aliases: [String] = [], fontIndex: Int = 0) throws -> String {
        let metrics = try FontMetrics(data: data, fontIndex: fontIndex)
        return try register(metrics, data: data, names: metrics.familyNames + aliases,
                            bold: metrics.isBold, italic: metrics.isItalic)
    }

    /// Explicit style metadata overrides font metadata (including embedded-face tags).
    @discardableResult
    public func register(_ data: Data, face: FontFaceKey, aliases: [String] = [],
                         fontIndex: Int = 0) throws -> String {
        let metrics = try FontMetrics(data: data, fontIndex: fontIndex)
        return try register(metrics, data: data, names: [face.family] + metrics.familyNames + aliases,
                            bold: face.bold, italic: face.italic)
    }

    private func register(_ metrics: FontMetrics, data: Data, names: [String], bold: Bool, italic: Bool) throws -> String {
        guard let primary = names.first else {
            throw RostrumError.fontCorrupt("font has no family name; pass aliases: when registering")
        }
        for name in names {
            let key = FontFaceKey(family: name, bold: bold, italic: italic)
            byFace[key] = metrics
            sourceData[key] = data
        }
        return primary
    }

    /// Register a font file (`.ttf`, `.otf`, `.ttc`) from disk.
    @discardableResult
    public func register(contentsOf url: URL, aliases: [String] = [], fontIndex: Int = 0) throws -> String {
        try register(try Data(contentsOf: url), aliases: aliases, fontIndex: fontIndex)
    }

    /// Family-only compatibility lookup: regular, bold, italic, then bold-italic.
    /// This fixed preference is independent of registration order.
    public func metrics(for typeface: String) -> FontMetrics? {
        for (bold, italic) in [(false, false), (true, false), (false, true), (true, true)] {
            if let metrics = metrics(for: typeface, bold: bold, italic: italic) { return metrics }
        }
        return nil
    }

    /// Exact style lookup; nil means the requested face is not registered.
    public func metrics(for typeface: String, bold: Bool, italic: Bool) -> FontMetrics? {
        metrics(for: FontFaceKey(family: typeface, bold: bold, italic: italic))
    }

    public func metrics(for face: FontFaceKey) -> FontMetrics? { byFace[face] }

    /// Original explicit font bytes. Aliases share the same value; consumers
    /// must honor the font's OS/2 embedding restrictions when exporting them.
    public func data(for face: FontFaceKey) -> Data? { sourceData[face] }

    public var isEmpty: Bool { byFace.isEmpty }
}
