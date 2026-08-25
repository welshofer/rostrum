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

    /// The slide the overlap was actually reported on. `sectionSlide` always
    /// leaves room for a side image, but its subtitle ran nine columns wide
    /// while the picture went down at 55% of the slide — so the caption sat
    /// under the photograph. It had no regression test; it does now.
    @Test func aSectionSlideSubtitleStaysClearOfTheImagePanel() throws {
        let deck = try Presentation()
        let panel = deck.sideImagePanel()
        try deck.sectionSlide("Part two",
                              subtitle: "A subtitle long enough that it would once have run "
                                  + "the full nine columns and straight under the picture",
                              number: 2)

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

    // MARK: - Inheritance

    /// A slide is not the whole picture. The logo, the photo panel and the
    /// coloured field a brand puts on its layouts live on the layout and the
    /// master, and a renderer that draws only the slide's own shapes shows none
    /// of them — so applying any template looks like nothing but a colour swap,
    /// however much of it actually landed in the file.
    @Test func aSlideRendersItsLayoutsBackgroundAndFurniture() throws {
        let deck = try Presentation()
        let layout = try #require(deck.layout(type: "title"))
        let cSld = try #require(try layout.part.dom().firstChild(named: "p:cSld"))

        let bg = XML.Element("p:bg")
        let bgPr = XML.Element("p:bgPr")
        let bgFill = XML.Element("a:solidFill")
        bgFill.appendElement(XML.Element("a:srgbClr", attributes: [("val", "FF6700")]))
        bgPr.appendElement(bgFill)
        bg.appendElement(bgPr)
        cSld.insertChild(bg, beforeAnyOf: ["p:spTree"])

        let deco = XML.Element("p:sp")
        let nv = XML.Element("p:nvSpPr")
        nv.appendElement(XML.Element("p:cNvPr", attributes: [("id", "42"), ("name", "Bar 42")]))
        nv.appendElement(XML.Element("p:cNvSpPr"))
        nv.appendElement(XML.Element("p:nvPr"))
        deco.appendElement(nv)
        let spPr = XML.Element("p:spPr")
        let xfrm = XML.Element("a:xfrm")
        xfrm.appendElement(XML.Element("a:off", attributes: [("x", "0"), ("y", "0")]))
        xfrm.appendElement(XML.Element("a:ext", attributes: [("cx", "914400"), ("cy", "914400")]))
        spPr.appendElement(xfrm)
        let fill = XML.Element("a:solidFill")
        fill.appendElement(XML.Element("a:srgbClr", attributes: [("val", "123456")]))
        spPr.appendElement(fill)
        deco.appendElement(spPr)
        try Slide.spTree(of: layout.part).appendElement(deco)
        layout.part.markDirty()

        _ = try deck.slides.add(clonedFrom: layout)
        let svg = try deck.renderSVG(slideAt: deck.slides.count - 1)

        #expect(svg.contains("#FF6700"), "the layout's background never reached the render")
        #expect(svg.contains("#123456"), "the layout's furniture never reached the render")
    }

    /// A placeholder cloned from a layout carries no transform and no run
    /// properties of its own — that is the point, it inherits them. A renderer
    /// that does not follow the chain puts every one of them at the top-left
    /// corner in its own default 18pt grey, which makes a deck rebuilt on a
    /// template's layouts look broken rather than rebranded.
    @Test func aPlaceholderInheritsItsFrameAndTypeFromTheLayout() throws {
        let deck = try Presentation()
        let layout = try #require(deck.layout(type: "title"))
        let tree = try Slide.spTree(of: layout.part)
        let titleSp = try #require(tree.children(named: "p:sp").first {
            Placeholders.phElement(of: $0)?[attribute: "type"] == "ctrTitle"
        })
        let lstStyle = try #require(titleSp.firstChild(named: "p:txBody")?
            .firstChild(named: "a:lstStyle"))
        let lvl1 = XML.Element("a:lvl1pPr")
        let defRPr = XML.Element("a:defRPr", attributes: [("sz", "8000")])
        let color = XML.Element("a:solidFill")
        color.appendElement(XML.Element("a:srgbClr", attributes: [("val", "FF0000")]))
        defRPr.appendElement(color)
        lvl1.appendElement(defRPr)
        lstStyle.appendElement(lvl1)
        layout.part.markDirty()

        let slide = try deck.slides.add(clonedFrom: layout)
        let title = try #require(slide.title)
        _ = try #require(title.textFrame).addParagraph().addRun("Inherited")

        let svg = try deck.renderSVG(slideAt: deck.slides.count - 1)

        #expect(svg.contains("Inherited"))
        #expect(svg.contains("#FF0000"), "the run fell back to the renderer's default colour")
        #expect(svg.contains("font-size=\"80\""), "the run fell back to the renderer's default size")
        // The layout puts ctrTitle at x=1524000; a shape rendered without
        // inheritance lands at 0. Text is positioned by `transform`, so the
        // origin case reads `translate(0,` — checking for an `x="0"` attribute
        // here would pass without testing anything.
        #expect(!svg.contains("translate(0,"), "the placeholder rendered at the origin")
    }

    /// Browsers clamp computed `font-size` to a five-digit maximum before the
    /// viewBox transform is applied, so a size emitted in EMU (a 68pt title is
    /// 863600) is clamped and then scaled down to about a pixel: text present,
    /// correctly placed, and invisible. Sizes therefore go out in points, under
    /// a per-text `scale(12700)` that restores EMU space.
    @Test func textIsSizedInPointsSoBrowsersDoNotClampItAway() throws {
        let deck = try Presentation()
        let slide = try deck.slides[0]
        let shape = try slide.shapes.addTextBox(Rect(x: EMU(914_400), y: EMU(914_400),
                                                     width: EMU(5_486_400), height: EMU(1_828_800)))
        let frame = try #require(shape.textFrame)
        frame.text = "Sized"

        let svg = try deck.renderSVG(slideAt: 0)

        let sizes = matches(of: "font-size=\"([0-9.]+)\"", in: svg)
        #expect(!sizes.isEmpty, "nothing was rendered to size")
        for size in sizes {
            let value = try #require(Double(size))
            #expect(value < 10_000,
                    "font-size \(value) is in the range browsers clamp — EMU leaked back in")
        }
        #expect(svg.contains("scale(12700)"), "text was not scaled back into EMU space")
    }

    /// The renderer resolves a run's typeface to choose wrapping metrics; if it
    /// does not also say so in the markup, every deck renders in the viewer's
    /// default serif no matter what its brand font is.
    @Test func aResolvedTypefaceIsNamedInTheMarkup() throws {
        let deck = try Presentation()
        let slide = try deck.slides[0]
        let shape = try slide.shapes.addTextBox(Rect(x: EMU(914_400), y: EMU(914_400),
                                                     width: EMU(5_486_400), height: EMU(1_828_800)))
        let frame = try #require(shape.textFrame)
        let run = frame.addParagraph().addRun("Branded")
        run.fontName = "Georgia"

        let svg = try deck.renderSVG(slideAt: 0)

        #expect(svg.contains("font-family=\"Georgia"), "the resolved typeface never reached the markup")
    }

    /// Regex-free attribute scrape: the renderer's output is the contract, and
    /// a test that parsed it with the library's own XML would hide a malformed
    /// emission.
    private func matches(of pattern: String, in text: String) -> [String] {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = text as NSString
        return re.matches(in: text, range: NSRange(location: 0, length: ns.length))
            .compactMap { $0.numberOfRanges > 1 ? ns.substring(with: $0.range(at: 1)) : nil }
    }
}
