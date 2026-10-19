import Foundation
import Testing
import Rostrum
@testable import LecternCore

@Suite struct SymbolFallbackPreviewTests {
    static let hasSystemSymbolFonts = ["Apple Symbols.ttf", "ZapfDingbats.ttf"].allSatisfy {
        FileManager.default.fileExists(atPath: "/System/Library/Fonts/" + $0)
    }

    /// Apple Symbols and Arial both lack U+2713; the preview must still draw it.
    @Test(.enabled(if: hasSystemSymbolFonts))
    func dingbatCheckmarkUsesZapfDingbats() throws {
        let deck = try Presentation()
        let box = try deck.slides[0].shapes.addTextBox(Rect(x: .inches(1), y: .inches(1), width: .inches(4), height: .inches(1)))
        let text = try #require(box.textFrame)
        text.clear()
        let run = text.addParagraph().addRun("\u{2713} HELD")
        run.fontName = "Arial"; run.fontSize = 16; run.bold = true

        let previews = try DeckPreviews.render(from: deck)
        let messages = previews.diagnostics.flatMap(\.issues).map(\.message)
        #expect(!messages.contains { $0.hasPrefix("No glyph for U+2713") }, "\(messages)")
        #expect(messages.contains { $0.contains("Preview symbol U+2713 uses registered Zapf Dingbats") }, "\(messages)")
        #expect(!messages.contains { $0.contains("zapf dingbats") }, "Face keys are case-folded; messages use the font's name.")
        #expect(messages.contains("OS/2 embedding restrictions prevent embedding Zapf Dingbats in SVG."), "\(messages)")
        // The restricted face is named, not embedded; CSS family matching is case-insensitive.
        #expect(try #require(previews.svgs.first).contains("font-family=\"zapf dingbats, sans-serif\""))
    }
}
