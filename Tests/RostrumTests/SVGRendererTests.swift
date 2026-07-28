import Foundation
import Testing
@testable import Rostrum

@Suite struct SVGRendererTests {
    private var png: Data {
        var b: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        func be32(_ v: Int) -> [UInt8] { [UInt8(v >> 24 & 0xFF), UInt8(v >> 16 & 0xFF), UInt8(v >> 8 & 0xFF), UInt8(v & 0xFF)] }
        b += be32(13); b += Array("IHDR".utf8); b += be32(8); b += be32(8); b += [8, 6, 0, 0, 0]; b += be32(0)
        b += be32(0); b += Array("IEND".utf8); b += be32(0)
        return Data(b)
    }

    @Test func rendersDeterministicWellFormedSVG() throws {
        let deck = try Presentation()
        deck.applyDesign(Design.parse("## Palette\n- Background: #0B1D33\n- Text: #F7F4EE\n- Accent 1: #18A999"))
        try deck.titleSlide("Rendered", subtitle: "to SVG", kicker: "P4")

        let svg = try deck.renderSVG(slideAt: 1)
        #expect(svg == (try deck.renderSVG(slideAt: 1)))          // deterministic
        #expect(svg.hasPrefix("<svg"))
        #expect(svg.contains("viewBox=\"0 0 12192000 6858000\""))  // 16:9 in EMU
        #expect(svg.contains("#0B1D33"))                            // background color
        #expect(svg.contains("<text"))                             // title text present
        #expect(svg.contains(">Rendered<") || svg.contains("Rendered"))
        _ = try XML.parse(Data(svg.utf8))                          // valid XML
    }

    /// Text too wide for its shape wraps; it does not get truncated behind an
    /// ellipsis. The unmeasured branch used to emit a single clipped line, so
    /// a headline came back silently rewritten — the one thing a preview must
    /// not do.
    @Test func longTextWrapsRatherThanBeingClippedAway() throws {
        let deck = try Presentation()
        // No fonts registered, so this takes the estimated path deliberately.
        #expect(deck.fonts.isEmpty)
        let headline = "Why Native Rendering Wins Over Server Round Trips Every Single Time"
        try deck.titleSlide(headline)

        let svg = try deck.renderSVG(slideAt: 1)
        // Every word survives somewhere in the output, on whatever line the
        // estimate put it.
        for word in headline.split(separator: " ") {
            #expect(svg.contains(word), "dropped \"\(word)\"")
        }
        #expect(svg == (try deck.renderSVG(slideAt: 1)))   // still deterministic
        _ = try XML.parse(Data(svg.utf8))
    }

    /// The wrap is bounded. `renderSVG` is a pure read API pointed at files we
    /// did not write, and a one-EMU-wide shape holding a lot of text must not
    /// turn into a line per character.
    @Test func estimatedWrapIsBoundedOnAbsurdGeometry() throws {
        let deck = try Presentation()
        let slide = try deck.slides[0]
        let box = try slide.shapes.addShape(
            .rectangle,
            frame: Rect(x: .zero, y: .zero, width: EMU(1), height: .inches(5)),
            fill: .solid(Color("FFFFFF")))
        box.textFrame?.text = String(repeating: "overflow ", count: 20_000)

        let svg = try deck.renderSVG(slideAt: 0)
        let lines = svg.components(separatedBy: "<text").count - 1
        #expect(lines <= 64, "emitted \(lines) text lines")
        _ = try XML.parse(Data(svg.utf8))
    }

    @Test func rendersShapesTextImageAndTable() throws {
        let deck = try Presentation()
        let slide = try deck.slides[0]
        try slide.setBackground(.solid(Color("0B1D33")))
        try slide.shapes.addShape(.ellipse, frame: Rect(x: .inches(1), y: .inches(1), width: .inches(2), height: .inches(2)), fill: .solid(Color("18A999")))
        try slide.shapes.addShape(.roundedRectangle, frame: Rect(x: .inches(4), y: .inches(1), width: .inches(3), height: .inches(1.5)), fill: .gradient(GradientFill(from: Color("FF6B5B"), to: Color("0B1D33"))))
        try slide.shapes.addPicture(png, x: .inches(8), y: .inches(1))
        let t = try slide.shapes.addTable(rows: 2, columns: 2, frame: Rect(x: .inches(1), y: .inches(4), width: .inches(6), height: .inches(2)))
        t.setContents([["A", "B"], ["1", "2"]]).styleBanded(style: deck.style)

        let svg = try deck.renderSVG(slideAt: 0)
        #expect(svg.contains("<ellipse"))
        #expect(svg.contains("rx="))                       // rounded-rect corner radius
        #expect(svg.contains("<linearGradient") || svg.contains("url(#"))
        #expect(svg.contains("<image") && svg.contains("data:image/png;base64,"))
        _ = try XML.parse(Data(svg.utf8))                  // valid XML incl. embedded image
        // Determinism across the whole complex slide.
        #expect(svg == (try deck.renderSVG(slideAt: 0)))
    }

    @Test func rendersEveryFeatureDeckWithoutCrashingIntoValidSVG() throws {
        // Every slide of a feature-diverse deck renders to valid, deterministic SVG.
        let deck = try Presentation()
        deck.applyDesign(Design.parse("## Palette\n- Background: #0B1D33\n- Accent 1: #18A999"))
        try deck.titleSlide("T", subtitle: "S", kicker: "K")
        try deck.sectionSlide("Sec", number: 1)
        try deck.comparisonSlide("C", leftHeader: "L", left: ["a"], rightHeader: "R", right: ["b"])
        try deck.chartSlide("Ch", .barClustered, ChartData(categories: ["A", "B"], name: "s", values: [1, 2]))
        try deck.calloutSlide(stat: "47", caption: "NPS")
        try deck.quoteSlide("Quote", attribution: "someone")
        try deck.slides[0].shapes.addPicture(png, x: .inches(1), y: .inches(1))
        for i in 0..<deck.slides.count {
            let svg = try deck.renderSVG(slideAt: i)
            _ = try XML.parse(Data(svg.utf8))                     // valid XML
            #expect(svg == (try deck.renderSVG(slideAt: i)))      // deterministic
        }
    }

    @Test func exportsOneSVGPerSlide() throws {
        let deck = try Presentation()
        try deck.titleSlide("One")
        try deck.bulletSlide("Two", ["x"])
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("rostrum-svg-\(UInt64(bitPattern: Int64(deck.slides.count)))")
        defer { try? FileManager.default.removeItem(at: dir) }
        let urls = try deck.exportSVG(to: dir)
        #expect(urls.count == deck.slides.count)
        for url in urls { #expect(FileManager.default.fileExists(atPath: url.path)) }
    }
}
