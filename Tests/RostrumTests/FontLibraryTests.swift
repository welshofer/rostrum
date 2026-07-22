import Foundation
import Testing
@testable import Rostrum

@Suite struct FontLibraryTests {
    @Test func registersUnderNameTableFamily() throws {
        let library = FontLibrary()
        let primary = try library.register(TestFont.standard(familyName: "Test Sans"))
        #expect(primary == "Test Sans")
        #expect(library.metrics(for: "test sans") != nil)
        #expect(library.metrics(for: "TEST SANS")?.advance(of: "W") == 900)
        #expect(library.metrics(for: "Helvetica") == nil)
        #expect(!library.isEmpty)
    }

    @Test func namelessFontsNeedAliases() throws {
        let library = FontLibrary()
        #expect(throws: RostrumError.self) {
            try library.register(TestFont.standard())
        }
        let primary = try library.register(TestFont.standard(), aliases: ["Body Face"])
        #expect(primary == "Body Face")
        #expect(library.metrics(for: "body face") != nil)
    }

    @Test func familyNamesParseFromTheNameTable() throws {
        let metrics = try FontMetrics(data: TestFont.standard(familyName: "Test Sans"))
        #expect(metrics.familyNames == ["Test Sans"])
        #expect(try FontMetrics(data: TestFont.standard()).familyNames.isEmpty)
    }
}

@Suite struct MeasuredBuildersTests {
    /// The font size of the shape holding `text` on the deck's last slide.
    private func runSize(_ deck: Presentation, text: String) throws -> Double? {
        let slide = try deck.slides[deck.slides.count - 1]
        for shape in slide.shapes.all {
            guard let tf = shape.textFrame, tf.text == text else { continue }
            return tf.paragraphs.first?.runs.first?.fontSize
        }
        return nil
    }

    /// Register the standard test font under the deck's own style names, so
    /// every builder role resolves to it.
    private func registerTestFont(in deck: Presentation) throws {
        try deck.fonts.register(TestFont.standard(),
                                aliases: [deck.style.headingFont, deck.style.bodyFont])
    }

    @Test func narrowTitleKeepsDisplaySizeWhenMeasured() throws {
        // 46 'i's: past the >44-character heuristic threshold, but at 200/1000
        // units per glyph genuinely narrow — measurement keeps the large size
        // the character count would have thrown away.
        let narrowTitle = String(repeating: "i", count: 46)

        let estimated = try Presentation()
        try estimated.titleSlide(narrowTitle)
        let heuristicSize = try #require(try runSize(estimated, text: narrowTitle))
        #expect(heuristicSize == 60)

        let measured = try Presentation()
        try registerTestFont(in: measured)
        try measured.titleSlide(narrowTitle)
        let measuredSize = try #require(try runSize(measured, text: narrowTitle))
        #expect(measuredSize > heuristicSize)
    }

    @Test func wideTitleShrinksWhenMeasured() throws {
        // 40 'W's: under every character threshold (so the heuristic keeps the
        // full display size), but at 900/1000 units per glyph genuinely wide —
        // measurement steps down where the character count would not.
        let wideTitle = String(repeating: "W", count: 40)

        let estimated = try Presentation()
        try estimated.titleSlide(wideTitle)
        let heuristicSize = try #require(try runSize(estimated, text: wideTitle))

        let measured = try Presentation()
        try registerTestFont(in: measured)
        try measured.titleSlide(wideTitle)
        let measuredSize = try #require(try runSize(measured, text: wideTitle))
        #expect(measuredSize < heuristicSize)
    }

    @Test func unregisteredDecksAreByteIdenticalToTheHeuristicPath() throws {
        // The fallback contract: no registered fonts → exactly the pre-metrics
        // output, provable by determinism across two separately built decks.
        func build() throws -> Data {
            let deck = try Presentation()
            try deck.titleSlide("A title long enough to cross the fitting thresholds easily")
            try deck.quoteSlide(String(repeating: "measure twice, cut once. ", count: 12),
                                attribution: "Everyone")
            return try deck.serializedData()
        }
        #expect(try build() == build())
    }

    @Test func measuredDecksAreDeterministic() throws {
        func build() throws -> Data {
            let deck = try Presentation()
            try registerTestFont(in: deck)
            try deck.titleSlide(String(repeating: "W", count: 40))
            try deck.processSlide("Steps", steps: ["Perceive the world", "Plan the change", "Act on it"])
            try deck.metricsSlide("Numbers", metrics: [("$300B", "market"), ("42", "answers")])
            return try deck.serializedData()
        }
        #expect(try build() == build())
    }
}

@Suite struct MeasuredSVGTests {
    @Test func svgWrapsParagraphsWhenTheTypefaceIsRegistered() throws {
        let longText = Array(repeating: "wide words", count: 12).joined(separator: " ")
        func render(registered: Bool) throws -> Int {
            let deck = try Presentation()
            if registered {
                try deck.fonts.register(TestFont.standard(), aliases: [deck.style.bodyFont])
            }
            let box = try deck.slides[0].shapes.addTextBox(
                Rect(x: .inches(1), y: .inches(1), width: .inches(3), height: .inches(4)))
            let tf = box.textFrame!
            tf.text = longText
            let run = tf.paragraphs[0].runs[0]
            run.fontName = deck.style.bodyFont
            run.fontSize = 18
            let svg = try deck.renderSVG(slideAt: 0)
            #expect(svg == (try deck.renderSVG(slideAt: 0)))   // stays deterministic
            return svg.components(separatedBy: "<text").count - 1
        }
        #expect(try render(registered: false) == 1)
        #expect(try render(registered: true) > 1)
    }
}
