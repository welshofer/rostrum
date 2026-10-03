import Foundation
import Testing
@testable import Rostrum

@Suite struct ParagraphJustificationTests {
    private func body(_ runs: String, attributes: String = "algn=\"just\"", properties: String = "") throws -> XML.Element {
        try XML.parse(Data("""
        <p:txBody><a:bodyPr lIns="0" rIns="0" tIns="0" bIns="0"/>
        <a:p><a:pPr \(attributes)>\(properties)<a:defRPr sz="1000"/></a:pPr>\(runs)</a:p></p:txBody>
        """.utf8))
    }
    private func layout(_ body: XML.Element, width: Double = 30, height: Double = 100,
                        inherited: [XML.Element] = [], maxLines: Int = 4096) throws -> RichTextLayout {
        RichTextLayout(textBody: body, width: width, height: height,
                       fallbackMetrics: try FontMetrics(data: TestFont.standard()),
                       inheritedStyles: inherited, maxLines: maxLines)
    }
    private func text(_ value: String) -> String { "<a:r><a:t>\(value)</a:t></a:r>" }

    @Test func wrappedLinesExpandWordSpacesWithoutStretchingLettersOrLastLine() throws {
        let result = try layout(body(text("AA BB CC")))
        #expect(result.lines.count == 2 && result.fits)
        #expect(result.lines[0].spans.map(\.run.text) == ["AA", " ", "BB "])
        #expect(result.lines[0].spans.map(\.x) == [0, 10, 20])
        #expect(result.lines[0].spans.map(\.width) == [10, 10, 12.5])
        #expect(result.lines[0].width == 32.5) // Includes the preserved trailing space.
        #expect(result.lines[1].spans.map(\.run.text) == ["CC"])
        #expect(result.lines[1].width == 10)
        #expect(result.diagnostics.isEmpty)
    }

    @Test(arguments: [75, -25], [true, false])
    func trackingAndKerningPreserveNaturalWordsAcrossJustification(trackingHundredths: Int, kerning: Bool) throws {
        let font = try FontMetrics(contentsOf: URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/Typography/DejaVuSans.ttf"))
        let tracking = Double(trackingHundredths) / 100
        let xml = try body("""
        <a:r><a:rPr sz="1200" spc="\(trackingHundredths)" kern="\(kerning ? 0 : 2400)"/><a:t>AV AV AV</a:t></a:r>
        """)
        let result = RichTextLayout(textBody: xml, width: 45, height: 100, fallbackMetrics: font)
        // Pinned DejaVuSans: A/V advances 1401 each, AV pair adjustment -131,
        // space advance 651, unitsPerEm 2048 (independent HarfBuzz fixture).
        let word = Double(2802 - (kerning ? 131 : 0)) * 12 / 2048 + 2 * tracking
        let space = 651.0 * 12 / 2048 + tracking
        #expect(result.lines.count == 2 && result.fits)
        let first = result.lines[0].spans
        #expect(first.map(\.run.text) == ["AV", " ", "AV "])
        #expect(abs(first[0].width - word) < 0.000001)
        #expect(abs(first[1].width - (45 - 2 * word)) < 0.000001)
        #expect(first[1].width > space)
        #expect(abs(first[2].width - (word + space)) < 0.000001)
        #expect(abs(first[2].x + word - 45) < 0.000001)
        #expect(first.allSatisfy { $0.run.tracking == tracking && $0.run.usesKerning == kerning })
        let last = try #require(result.lines.last?.spans.first)
        #expect(last.run.text == "AV" && last.x == 0)
        #expect(abs(last.width - word) < 0.000001)
        #expect(result.diagnostics.isEmpty)
    }

    @Test func inheritedAlignmentMixedRunsAndMarginsKeepWordGeometry() throws {
        let inherited = try XML.parse(Data("<a:lstStyle><a:lvl1pPr algn=\"just\"/></a:lstStyle>".utf8))
        let xml = try body(text("AA ") + "<a:r><a:rPr b=\"1\" i=\"1\"><a:solidFill><a:srgbClr val=\"FF0000\"/></a:solidFill></a:rPr><a:t>BB CC</a:t></a:r>", attributes: "marL=\"127000\" marR=\"63500\" indent=\"63500\"")
        let result = try layout(xml, width: 50, inherited: [inherited])
        #expect(result.lines[0].spans.map(\.x) == [15, 25, 35])
        #expect(result.lines[0].spans[2].run.bold && result.lines[0].spans[2].run.italic)
        #expect(result.lines[0].spans[2].run.color == "#FF0000")
        #expect(result.lines[1].spans[0].x == 10)
        try #require(xml.firstChild(named: "a:p")?.firstChild(named: "a:pPr"))[attribute: "algn"] = "l"
        let local = try layout(xml, width: 50, inherited: [inherited])
        #expect(local.lines[0].spans.map(\.x) == [15, 27.5])
    }

    @Test func leadingTrailingAndRepeatedSpacesDoNotBecomeEdgeExpansionSlots() throws {
        let result = try layout(body(text("  AA  BB CC  ")), width: 40)
        #expect(result.lines[0].spans.map(\.run.text) == ["  AA", " ", " ", "BB "])
        #expect(result.lines[0].spans.map(\.x) == [0, 15, 22.5, 30])
        #expect(result.lines[1].width == 15)
        #expect(result.fits)
    }

    @Test func singleWordsEmptyParagraphsNoWrapAndLineBoundDoNotInventSpacing() throws {
        let single = try layout(body(text("AAAAAAAA")))
        #expect(single.lines.map(\.width) == [30, 10])
        #expect(single.lines.allSatisfy { $0.spans.count == 1 })
        #expect(try layout(body("")).lines[0].width == 0)
        let xml = try body(text("AA BB CC"))
        try #require(xml.firstChild(named: "a:bodyPr"))[attribute: "wrap"] = "none"
        let nowrap = try layout(xml)
        #expect(nowrap.lines.count == 1 && !nowrap.fits && nowrap.lines[0].width == 35)
        let bounded = try layout(body(text("AA BB CC DD EE")), maxLines: 1)
        #expect(bounded.truncated && !bounded.fits && bounded.lines.count == 1)
    }

    @Test func bulletIsNotAJustificationSlot() throws {
        let xml = try body(text("AA BB CC"), attributes: "algn=\"just\" marL=\"127000\" indent=\"-127000\"", properties: "<a:buChar char=\"•\"/>")
        let result = try layout(xml, width: 40)
        #expect(result.lines[0].spans.map(\.x) == [0, 10, 20, 30])
        #expect(result.lines[0].spans[0].run.text == "• ")
        #expect(result.lines[1].spans[0].x == 10)
    }

    @Test func unsupportedModesTabsAndScriptsAreDiagnosed() throws {
        for mode in ["dist", "justLow", "thaiDist"] {
            let result = try layout(body(text("AA BB CC"), attributes: "algn=\"\(mode)\""))
            #expect(result.lines[0].width == 25)
            #expect(result.diagnostics.contains(.unsupportedLayoutFeature("Paragraph alignment '\(mode)' is not implemented; using left alignment")))
        }
        for (runs, attributes, reason) in [
            (text("AA\tBB CC"), "algn=\"just\"", "Justification with tabs"),
            (text("AA BB CC"), "algn=\"just\" rtl=\"true\"", "Justification of RTL"),
            (text("אב גד הו"), "algn=\"just\"", "Justification outside"),
            (text("中文 中文 中文"), "algn=\"just\"", "Justification outside")
        ] {
            let result = try layout(body(runs, attributes: attributes))
            #expect(result.diagnostics.contains { if case .unsupportedLayoutFeature(let value) = $0 { return value.hasPrefix(reason) }; return false })
        }
    }

    @Test func explicitBreakJustifiesButFinalAndEmptyLinesStayNatural() throws {
        let result = try layout(body(text("AA BB") + "<a:br/>" + text("CC") + "<a:br/>"))
        #expect(result.lines.map(\.width) == [30, 10, 0])
        #expect(result.lines[0].spans.map(\.x) == [0, 10, 20])
        #expect(result.diagnostics.isEmpty)
    }

    @Test func nativePowerPointWordPositionsAgreeWithIndependentNumericMetrics() throws {
        struct Capture: Decodable {
            struct Face: Decodable { let unitsPerEm: Int; let advances: [Int] }
            struct Case: Decodable {
                struct Word: Decodable { let text: String; let x: Double; let end: Double }
                let name: String; let words: [Word]
            }
            let fonts: [Face]; let cases: [Case]; let tolerancePoints: Double
        }
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/ParagraphJustification")
        let capture = try JSONDecoder().decode(Capture.self, from: Data(contentsOf: root.appendingPathComponent("native-word-geometry.json")))
        let fonts = FontLibrary()
        for (index, face) in capture.fonts.enumerated() {
            let advances = [face.unitsPerEm / 2] + face.advances
            var os2 = TestFont.os2(useTypoMetrics: false)
            os2.replaceSubrange(62..<64, with: TestFont.be16(index == 1 ? 0x20 : 0x40))
            let data = Data(TestFont.assemble(tables: [
                ("head", TestFont.head(upem: face.unitsPerEm)),
                ("hhea", TestFont.hhea(ascender: 1600, descender: -400, lineGap: 0, numberOfHMetrics: advances.count)),
                ("maxp", TestFont.maxp(numGlyphs: advances.count)),
                ("hmtx", TestFont.hmtx(advances: advances)),
                ("cmap", TestFont.cmapFormat4()), ("OS/2", os2)
            ]))
            try fonts.register(data, aliases: ["Arial"])
        }
        let deck = try Presentation(contentsOf: root.appendingPathComponent("paragraph-justification-v2.pptx"))
        for oracle in capture.cases {
            let shape = try #require(deck.slides[0].shapes.first { $0.name == oracle.name })
            let frame = try #require(shape.textFrame)
            let result = RichTextLayout(textBody: frame.txBody, width: 300, height: 94, fonts: fonts)
            let words = result.lines[0].spans.filter { !$0.run.text.trimmingCharacters(in: .whitespaces).isEmpty && $0.run.text != "• " }
            #expect(words.map { $0.run.text.trimmingCharacters(in: .whitespaces) } == oracle.words.map(\.text))
            #expect(words.count == oracle.words.count)
            for (span, word) in zip(words, oracle.words) {
                #expect(abs(span.x - word.x) <= capture.tolerancePoints, "\(oracle.name): \(word.text)")
            }
            #expect(result.diagnostics.isEmpty)
        }
    }

    @Test func fittingSVGAndSaveReopenAgreeAndUnknownXMLIsUntouched() throws {
        let deck = try Presentation()
        try deck.fonts.register(TestFont.standard(), aliases: ["Test"])
        let shape = try deck.slides[0].shapes.addTextBox(Rect(x: .zero, y: .zero, width: .points(30), height: .points(20)))
        let frame = try #require(shape.textFrame)
        frame.setMargins(left: .zero, top: .zero, right: .zero, bottom: .zero)
        frame.text = "AA BB CC"
        frame.paragraphs[0].runs[0].fontSize = 10
        frame.paragraphs[0].runs[0].fontName = "Test"
        let p = try #require(frame.txBody.firstChild(named: "a:p"))
        p.children.insert(.element(XML.Element("a:pPr", attributes: [("algn", "just")])), at: 0)
        let unknown = XML.Element("a:extLst")
        unknown.children.append(.element(XML.Element("a:ext", attributes: [("uri", "urn:justification-preserve"), ("custom", "verbatim")])))
        p.children.append(.element(unknown))
        let fit = frame.fitText(in: shape.frame, fonts: deck.fonts, theme: deck.theme)
        #expect(fit.fits && fit.fontScale == 100)
        let shared = RichTextLayout(textBody: frame.txBody, width: 30, height: 20, fonts: deck.fonts, theme: deck.theme)
        #expect(shared.fits && shared.lines[0].spans[2].x == 20)
        let before = try deck.serializedData()
        let report = try deck.renderSVGReportingProblems(slideAt: 0)
        #expect(!report.problems.fidelityIssues.contains { $0.code == .unsupportedTextProperty })
        let svg = try XML.parse(Data(report.svg.utf8))
        var pending = [svg], spans: [XML.Element] = []
        while let element = pending.popLast() {
            if element.name == "tspan" { spans.append(element) }
            pending.append(contentsOf: element.childElements.reversed())
        }
        #expect(spans.map { $0[attribute: "x"] } == ["0", "10", "20", "0"])
        #expect(spans.map { $0[attribute: "textLength"].flatMap(Double.init) } == [10, 10, 12.5, 10])
        #expect(try deck.serializedData() == before)
        let reopened = try Presentation(data: before)
        try reopened.fonts.register(TestFont.standard(), aliases: ["Test"])
        #expect(try reopened.renderSVG(slideAt: 0) == report.svg)
        #expect(try reopened.serializedData() == before)
    }
}
