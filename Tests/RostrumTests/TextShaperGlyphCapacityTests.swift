import Foundation
import Testing
@testable import Rostrum

@Suite struct TextShaperGlyphCapacityTests {
    private func shaper() throws -> TextShaper {
        let font = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/Typography/DejaVuSans.ttf")
        return TextShaper(try FontMetrics(contentsOf: font))
    }

    @Test func canonicalExpansionKeepsBothGlyphsAndOriginalRange() throws {
        // NFC expands one U+0344 source scalar into two emitting marks.
        let run = try shaper().shape("\u{344}", pointSize: 2048, kerning: false)
        #expect(run == ShapedGlyphRun(glyphs: [
            ShapedGlyph(glyphID: 697, scalarRange: 0..<1, advance: 0, xOffset: 0, yOffset: 0, bidiLevel: 0),
            ShapedGlyph(glyphID: 690, scalarRange: 0..<1, advance: 0, xOffset: 0, yOffset: 409, bidiLevel: 0),
        ], breaks: [], diagnostics: [.unsupportedCombiningSequence(scalarRange: 0..<1)], direction: .leftToRight))
    }

    @Test func nonEmittingControlsKeepBreaksWithoutGlyphs() throws {
        let run = try shaper().shape("\r\n\u{200B}\n\r", pointSize: 2048)
        #expect(run == ShapedGlyphRun(glyphs: [], breaks: [
            TextBreakOpportunity(scalarOffset: 2, mandatory: true),
            TextBreakOpportunity(scalarOffset: 3, mandatory: false),
            TextBreakOpportunity(scalarOffset: 4, mandatory: true),
            TextBreakOpportunity(scalarOffset: 5, mandatory: true),
        ], diagnostics: [], direction: .leftToRight))
    }

    @Test func normalizedMarksAndMissingGlyphPreserveDiagnosticOrderAcrossControls() throws {
        let run = try shaper().shape("A\u{344}\r\n\u{200B}\u{10FFFF}", pointSize: 2048, kerning: false)
        #expect(run == ShapedGlyphRun(glyphs: [
            ShapedGlyph(glyphID: 134, scalarRange: 0..<2, advance: 1401, xOffset: 0, yOffset: 0, bidiLevel: 0),
            ShapedGlyph(glyphID: 690, scalarRange: 0..<2, advance: 0, xOffset: 0, yOffset: 0, bidiLevel: 0),
            ShapedGlyph(glyphID: 0, scalarRange: 5..<6, advance: 1229, xOffset: 0, yOffset: 0, bidiLevel: 0),
        ], breaks: [
            TextBreakOpportunity(scalarOffset: 4, mandatory: true),
            TextBreakOpportunity(scalarOffset: 5, mandatory: false),
        ], diagnostics: [
            .unsupportedScript(scalar: 0x10FFFF),
            .missingGlyph(scalar: 0x10FFFF),
            .unsupportedLayoutFeature("Latin ccmp changes this residual combining sequence; composition shaping is unsupported"),
            .unsupportedCombiningSequence(scalarRange: 0..<2),
        ], direction: .leftToRight))
    }
}
