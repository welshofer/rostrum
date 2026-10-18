import Foundation
import Testing
@testable import Rostrum

@Suite struct PreviewDiagnosticMessageTests {
    @Test func shapingDiagnosticsReadAsSentencesNamingTheCharacter() {
        let message = RenderDiagnosticCollector.message(for:)
        #expect(message(.unsupportedScript(scalar: 0x0E01)) == "Preview positions ‘ก’ (U+0E01) approximately; this script is not shaped natively.")
        #expect(message(.missingGlyph(scalar: 0x1F600)) == "No glyph for ‘😀’ (U+1F600) in the explicit face.")
        #expect(message(.unsupportedBidirectionalControl(scalar: 0x200F)) == "Preview ignores the bidirectional control U+200F.")
        #expect(message(.unsupportedLayoutFeature("Native advance rounding outside single-scalar left-to-right ASCII glyphs is not verified"))
            == "Preview spaces text containing non-ASCII characters approximately.")
        #expect(message(.unsupportedLayoutFeature("Mark attachment execution exceeds the bounded profile"))
            == "Mark attachment execution exceeds the bounded profile.")
        for diagnostic: ShapingDiagnostic in [.unsupportedCombiningSequence(scalarRange: 0..<2), .invalidPointSize] {
            #expect(!message(diagnostic).contains("("))
        }
    }

    /// Minus, arrows, geometric shapes and check marks are Common-script symbols.
    @Test func commonSymbolsAreNotReportedAsUnsupportedScripts() throws {
        let font = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/Typography/DejaVuSans.ttf")
        let metrics = try FontMetrics(contentsOf: font)
        for symbol in ["−", "→", "▲", "✓", "€", "≥", "™", "²"] {
            let run = TextShaper(metrics).shape("a\(symbol)b", pointSize: 12)
            #expect(!run.diagnostics.contains { if case .unsupportedScript = $0 { true } else { false } }, "\(symbol)")
        }
        let thai = TextShaper(metrics).shape("ก", pointSize: 12)
        #expect(thai.diagnostics.contains(.unsupportedScript(scalar: 0x0E01)))
    }
}
