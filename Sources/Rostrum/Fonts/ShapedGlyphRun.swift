import Foundation

public enum TextDirection: String, Sendable { case automatic, leftToRight, rightToLeft }

/// A precise warning: advances remain available for an explicitly approximate
/// preview, but callers must not silently treat an unsupported run as exact.
public enum ShapingDiagnostic: Hashable, Sendable {
    case unsupportedScript(scalar: UInt32)
    case unsupportedCombiningSequence(scalarRange: Range<Int>)
    case unsupportedBidirectionalControl(scalar: UInt32)
    case unsupportedLayoutFeature(String)
    case missingGlyph(scalar: UInt32)
    case invalidPointSize
}

public struct ShapedGlyph: Equatable, Sendable {
    public let glyphID: Int
    /// Original text's Unicode scalar offsets, including all ligature components.
    public let scalarRange: Range<Int>
    public var advance: Double
    public var xOffset: Double
    public var yOffset: Double
    public let bidiLevel: Int
}

public struct TextBreakOpportunity: Equatable, Sendable {
    /// Offset immediately after the break, measured in original Unicode scalars.
    public let scalarOffset: Int
    public let mandatory: Bool
}

/// Visual-order glyphs for one horizontal line, in points. Original scalar
/// ranges remain logical-order indices even after ligatures and bidi reordering.
/// This contract does not claim full Unicode/OpenType conformance: inspect
/// diagnostics and the documented TextShaper profile before using exact fitting.
public struct ShapedGlyphRun: Equatable, Sendable {
    public let glyphs: [ShapedGlyph]
    public let breaks: [TextBreakOpportunity]
    public let diagnostics: [ShapingDiagnostic]
    public let direction: TextDirection
    public var width: Double { glyphs.reduce(0) { $0 + $1.advance } }
    public var isSupported: Bool { diagnostics.isEmpty }
}
