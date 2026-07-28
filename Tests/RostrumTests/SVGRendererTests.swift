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

    /// The ellipsis marks *discarded* text. A paragraph that happens to fill
    /// exactly the line bound with every word intact must not get one — and
    /// must not have a real character deleted to make room for it, which is
    /// the same silent rewriting the wrap replaced.
    @Test func exactlyFillingTheLineBoundIsNotTreatedAsTruncation() throws {
        let deck = try Presentation()
        // 1.25in at 18pt: approxCharWidth 114300 EMU, so maxChars is exactly 10.
        let box = try deck.slides[0].shapes.addTextBox(
            Rect(x: .inches(1), y: .inches(1), width: .inches(1.25), height: .inches(6)))
        let frame = try #require(box.textFrame)
        // 64 ten-character words: one per line, filling the bound precisely.
        frame.text = Array(repeating: String(repeating: "A", count: 10), count: 64)
            .joined(separator: " ")
        frame.paragraphs[0].runs[0].fontSize = 18

        let svg = try deck.renderSVG(slideAt: 0)
        #expect(!svg.contains("…"), "claimed a truncation that did not happen")
        #expect(svg.components(separatedBy: "<text").count - 1 == 64)
        // Every word intact — none shortened to fit an ellipsis.
        #expect(!svg.contains(">AAAAAAAAA<"))
        _ = try XML.parse(Data(svg.utf8))
    }

    /// One more word than fits: the bound really does bite, and says so.
    @Test func overflowingTheLineBoundIsMarkedWithAnEllipsis() throws {
        let deck = try Presentation()
        let box = try deck.slides[0].shapes.addTextBox(
            Rect(x: .inches(1), y: .inches(1), width: .inches(1.25), height: .inches(6)))
        let frame = try #require(box.textFrame)
        frame.text = Array(repeating: String(repeating: "A", count: 10), count: 90)
            .joined(separator: " ")
        frame.paragraphs[0].runs[0].fontSize = 18

        let svg = try deck.renderSVG(slideAt: 0)
        #expect(svg.contains("…"), "dropped text without saying so")
        #expect(svg.components(separatedBy: "<text").count - 1 == 64)
        _ = try XML.parse(Data(svg.utf8))
    }

    // MARK: - Side image reservation

    /// A slide that reserves the side panel must keep every piece of its text
    /// clear of it. Lectern computed its panel from slide fractions while the
    /// builder reserved grid columns, and the two did not line up — the
    /// picture landed on `sectionSlide`'s subtitle. Both now read one grid, so
    /// the only way that recurs is if this stops holding.
    @Test func reservedTextNeverEntersTheSideImagePanel() throws {
        let deck = try Presentation()
        let panel = deck.sideImagePanel()
        try deck.bulletSlide("A headline long enough that it would want the whole width",
                             ["first point that is also rather long",
                              "second point", "third point"],
                             reservingSideImage: true)

        for shape in try deck.slides[1].shapes {
            let frame = shape.frame
            guard frame.width.rawValue > 0 else { continue }
            #expect(frame.maxX.rawValue <= panel.minX.rawValue,
                    "\"\(shape.name)\" runs to \(frame.maxX.rawValue), panel starts at \(panel.minX.rawValue)")
        }
    }

    /// Not reserving is the default, and must be unchanged — a text-only deck
    /// should not lose a fifth of its width because the feature exists.
    @Test func notReservingKeepsTheFullWidth() throws {
        let deck = try Presentation()
        let panel = deck.sideImagePanel()
        try deck.bulletSlide("Title", ["a point"])

        let widest = try deck.slides[1].shapes.map(\.frame.maxX.rawValue).max() ?? 0
        #expect(widest > panel.minX.rawValue, "text was narrowed without being asked")
    }

    // MARK: - Charts

    /// A chart slide used to preview as a grey "[chart]" box, which tells the
    /// viewer nothing about their deck. The plot is a thumbnail — the shape of
    /// the data, not a second chart engine — but it has to be a real plot.
    @Test func chartsPlotTheirDataInsteadOfAPlaceholder() throws {
        let deck = try Presentation()
        try deck.chartSlide("Revenue", .barClustered,
                            ChartData(categories: ["Q1", "Q2", "Q3"],
                                      series: [ChartData.Series(name: "ARR", values: [3, 7, 5])]))
        let svg = try deck.renderSVG(slideAt: 1)

        #expect(!svg.contains("[chart]"))
        // Three bars plus a baseline; a placeholder would have neither.
        #expect(svg.components(separatedBy: "<rect").count - 1 >= 4)
        #expect(svg == (try deck.renderSVG(slideAt: 1)))    // deterministic
        _ = try XML.parse(Data(svg.utf8))
    }

    @Test func lineAndPieChartsPlotToo() throws {
        let deck = try Presentation()
        try deck.chartSlide("Trend", .line,
                            ChartData(categories: ["a", "b", "c"],
                                      series: [ChartData.Series(name: "s", values: [1, 4, 2])]))
        try deck.chartSlide("Split", .pie,
                            ChartData(categories: ["x", "y"],
                                      series: [ChartData.Series(name: "s", values: [30, 70])]))

        let line = try deck.renderSVG(slideAt: 1)
        #expect(line.contains("<polyline"))
        #expect(!line.contains("[chart]"))

        let pie = try deck.renderSVG(slideAt: 2)
        #expect(pie.contains("<path"))
        #expect(!pie.contains("[chart]"))
        _ = try XML.parse(Data(line.utf8))
        _ = try XML.parse(Data(pie.utf8))
    }

    /// Chart values come out of a file, and `Int(_: Double)` traps on an
    /// out-of-range double. The plot must survive whatever the numbers are and
    /// stay valid XML.
    ///
    /// These go in through the authoring path, so they are values Rostrum will
    /// actually write: all-zero (no scale to divide by), negative, a magnitude
    /// past the guard, and one small enough to round to nothing. `NaN` and
    /// infinity are excluded here because they would exercise the chart
    /// *writer* rather than this renderer — the renderer's guards against them
    /// are reached from foreign decks, which `FuzzTests` drives through
    /// `renderSVG` directly.
    @Test func chartPlottingSurvivesHostileValues() throws {
        for values in [[1e308, 1], [-5, 5], [0, 0], [Double.leastNonzeroMagnitude, 1]] {
            let deck = try Presentation()
            try deck.chartSlide("Hostile", .barClustered,
                                ChartData(categories: values.map { _ in "c" },
                                          series: [ChartData.Series(name: "s", values: values)]))
            let svg = try deck.renderSVG(slideAt: 1)
            _ = try XML.parse(Data(svg.utf8))
            #expect(svg == (try deck.renderSVG(slideAt: 1)))
        }
    }

    /// SmartArt and OLE still get a placeholder — but one that names what it
    /// could not draw, rather than "[object]".
    @Test func unplottableFramesSayWhatTheyAre() throws {
        let deck = try Presentation()
        try deck.smartArtSlide("Diagram", kind: .blockList, items: ["one", "two"])
        let svg = try deck.renderSVG(slideAt: 1)
        #expect(svg.contains("[SmartArt]") || !svg.contains("[object]"))
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
