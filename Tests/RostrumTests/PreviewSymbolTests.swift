import Foundation
import Testing
@testable import Rostrum

@Suite struct PreviewSymbolTests {
    private func fonts() throws -> FontLibrary {
        let fonts = FontLibrary()
        try fonts.register(TestFont.standard(), aliases: ["Primary"])
        let url = try #require(Bundle.module.url(forResource: "DejaVuSans", withExtension: "ttf", subdirectory: "Fixtures/Typography"))
        try fonts.register(Data(contentsOf: url), aliases: ["Symbols"])
        return fonts
    }
    private func body(_ text: String) throws -> XML.Element {
        try XML.parse(Data("""
        <p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:r><a:rPr sz="1600"><a:latin typeface="Primary"/></a:rPr><a:t>\(text)</a:t></a:r></a:p></p:txBody>
        """.utf8))
    }

    @Test func commonSymbolsAreNotMisclassifiedAsScriptsButCoverageRemainsChecked() throws {
        let fonts = try fonts(), text = "− → ▲ ✓"
        for name in ["Primary", "Symbols"] {
            let metrics = try #require(fonts.metrics(for: name))
            let shaped = TextShaper(metrics).shape(text, pointSize: 16)
            #expect(!shaped.diagnostics.contains { if case .unsupportedScript = $0 { return true }; return false })
            #expect(shaped.diagnostics.contains { if case .missingGlyph = $0 { return true }; return false } == (name == "Primary"))
        }
    }

    @Test func symbolFallbackIsExplicitMeasuredAndNeverChangesSource() throws {
        let fonts = try fonts(), xml = try body("Keep ✓ HELD → next"), before = XML.document(try body("Keep ✓ HELD → next"))
        let without = RichTextLayout(textBody: xml, width: 500, height: 100, fonts: fonts)
        #expect(without.diagnostics.contains(.missingGlyph(scalar: 0x2713)))
        fonts.previewSymbolFallbackFamilies = ["Missing", "Symbols"]
        let with = RichTextLayout(textBody: xml, width: 500, height: 100, fonts: fonts)
        let spans = with.lines.flatMap(\.spans)
        #expect(spans.map(\.run.text).joined() == "Keep ✓ HELD → next")
        #expect(spans.filter { $0.run.text.contains("✓") || $0.run.text.contains("→") }.allSatisfy { $0.run.fontFamily == "symbols" })
        #expect(spans.filter { $0.run.text.contains("Keep") || $0.run.text.contains("HELD") }.allSatisfy { $0.run.fontFamily == "Primary" })
        #expect(!with.diagnostics.contains { if case .missingGlyph = $0 { return true }; return false })
        #expect(with.diagnostics.contains { if case .unsupportedLayoutFeature(let message) = $0 { return message.contains("Preview symbol U+2713") }; return false })
        #expect(XML.document(xml) == before)
        // A new operation observes the new policy; no stale substitutions survive.
        fonts.previewSymbolFallbackFamilies = []
        #expect(RichTextLayout(textBody: xml, width: 500, height: 100, fonts: fonts).diagnostics == without.diagnostics)
    }

    @Test func emojiSequencesAndNonSymbolLettersAreNotSplitIntoFallbackFaces() throws {
        let fonts = try fonts(); fonts.previewSymbolFallbackFamilies = ["Symbols"]
        let layout = RichTextLayout(textBody: try body("✓\u{FE0F} Ω"), width: 500, height: 100, fonts: fonts)
        #expect(layout.lines.flatMap(\.spans).allSatisfy { $0.run.fontFamily == "Primary" })
        #expect(layout.diagnostics.contains { if case .unsupportedCombiningSequence = $0 { return true }; return false })
        #expect(layout.diagnostics.contains(.missingGlyph(scalar: 0x03A9)))
    }

    @Test func regularSymbolFallbackPaintsTheFaceThatWasMeasured() throws {
        let fonts = try fonts()
        try fonts.register(TestFont.standard(), face: FontFaceKey(family: "Primary", bold: true))
        fonts.previewSymbolFallbackFamilies = ["Symbols"]
        let xml = try body("HELD ✓")
        xml.firstChild(named: "a:p")?.firstChild(named: "a:r")?.firstChild(named: "a:rPr")?[attribute: "b"] = "1"
        let layout = RichTextLayout(textBody: xml, width: 500, height: 100, fonts: fonts)
        let spans = layout.lines.flatMap(\.spans)
        #expect(spans.filter { $0.run.text.contains("HELD") }.allSatisfy { $0.run.bold })
        let symbol = try #require(spans.first { $0.run.text == "✓" })
        #expect(symbol.run.fontFamily == "symbols")
        #expect(!symbol.run.bold && !symbol.run.italic)
        let metrics = try #require(fonts.metrics(for: FontFaceKey(family: "Symbols")))
        #expect(abs(symbol.width - TextShaper(metrics).shape("✓", pointSize: 16).width) < 0.001)
    }
}
