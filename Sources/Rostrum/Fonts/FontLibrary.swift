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
    private var encodedSources: [FontFaceKey: String] = [:]
    private var encodedBytes = 0
    private let encodedByteLimit = 4 * 1024 * 1024

    /// Reuse immutable registered bytes across slides, with bounded retention.
    /// Registration invalidates the cache, including all aliases of a face.
    func encodedSource(for face: FontFaceKey) -> String? {
        if let cached = encodedSources[face] { return cached }
        guard let data = sourceData[face] else { return nil }
        let encoded = data.base64EncodedString()
        if encoded.utf8.count <= encodedByteLimit - encodedBytes {
            encodedSources[face] = encoded
            encodedBytes += encoded.utf8.count
        }
        return encoded
    }

    /// Optional host-provided glyph measurement for previews. It is never used
    /// to alter document XML or serialized bytes. Hosts must install the same
    /// adapter for deterministic previews; nil retains portable font metrics.
    public var previewAdvance: ((String, String, Double, Bool, Bool) -> Double?)?

    /// Explicit registered family to measure and draw when a requested preview
    /// family is missing. Nil retains portable estimates and viewer fallback.
    /// This is preview-only: exact lookup and serialized font names stay intact,
    /// and rendering reports the substitution as a missing-font fidelity issue.
    public var previewFallbackFamily: String?

    /// Ordered, explicitly registered families for standalone symbols missing
    /// from a preview's requested face. Empty disables symbol substitution.
    /// Text layout measures and paints the chosen face and reports substitution;
    /// document XML, authored fonts, and ordinary letters remain unchanged.
    public var previewSymbolFallbackFamilies: [String] = []

    func previewSymbolFace(for scalar: Unicode.Scalar, requested: FontFaceKey) -> FontFaceKey? {
        guard TextShaper.isStandaloneSymbol(scalar.value) else { return nil }
        for family in previewSymbolFallbackFamilies.prefix(8) {
            for face in [FontFaceKey(family: family, bold: requested.bold, italic: requested.italic), FontFaceKey(family: family)] {
                if let metrics = byFace[face], metrics.glyphID(for: scalar) != 0 { return face }
            }
        }
        return nil
    }

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
        try register(PreparedFont(data: data, fontIndex: fontIndex), aliases: aliases)
    }

    /// Explicit style metadata overrides font metadata (including embedded-face tags).
    @discardableResult
    public func register(_ data: Data, face: FontFaceKey, aliases: [String] = [],
                         fontIndex: Int = 0) throws -> String {
        try register(PreparedFont(data: data, fontIndex: fontIndex), face: face, aliases: aliases)
    }

    /// Register an already parsed snapshot with the same naming, style and
    /// replacement rules as raw-byte registration. Does not reread its file.
    @discardableResult
    public func register(_ font: PreparedFont, aliases: [String] = []) throws -> String {
        let metrics = font.metrics
        return try register(metrics, data: font.data, names: metrics.familyNames + aliases,
                            bold: metrics.isBold, italic: metrics.isItalic)
    }

    /// Register a prepared snapshot with explicit style metadata, as used by
    /// embedded-face tags. Metrics and bytes always come from the same snapshot.
    @discardableResult
    public func register(_ font: PreparedFont, face: FontFaceKey, aliases: [String] = []) throws -> String {
        try register(font.metrics, data: font.data, names: [face.family] + font.metrics.familyNames + aliases,
                            bold: face.bold, italic: face.italic)
    }

    private func register(_ metrics: FontMetrics, data: Data, names: [String], bold: Bool, italic: Bool) throws -> String {
        guard let primary = names.first else {
            throw RostrumError.fontCorrupt("font has no family name; pass aliases: when registering")
        }
        encodedSources.removeAll(); encodedBytes = 0
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

    /// A registered regular face is the deterministic source for synthetic
    /// styles when the family has no requested face (for example Arial Black
    /// with a bold run). The renderer reports this substitution explicitly.
    func previewFace(for face: FontFaceKey) -> FontFaceKey? {
        if byFace[face] != nil { return face }
        let regular = FontFaceKey(family: face.family)
        if byFace[regular] != nil { return regular }
        guard let family = previewFallbackFamily else { return nil }
        let fallback = FontFaceKey(family: family, bold: face.bold, italic: face.italic)
        if byFace[fallback] != nil { return fallback }
        let fallbackRegular = FontFaceKey(family: family)
        return byFace[fallbackRegular] != nil ? fallbackRegular : nil
    }

    /// Original explicit font bytes. Aliases share the same value; consumers
    /// must honor the font's OS/2 embedding restrictions when exporting them.
    public func data(for face: FontFaceKey) -> Data? { sourceData[face] }

    public var isEmpty: Bool { byFace.isEmpty }
}
