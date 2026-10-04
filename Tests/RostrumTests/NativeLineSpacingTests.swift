import Foundation
import Testing
@testable import Rostrum

@Suite struct NativeLineSpacingTests {
    private var root: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/NativeLineSpacing")
    }
    private struct Input: Decodable {
        let name: String
        let page: Int
        let width: Double
        let height: Double
        let table: Bool?
        let font: String?
    }
    private struct Manifest: Decodable { let source: String }
    private struct Capture: Decodable {
        struct Case: Decodable {
            struct Marker: Decodable {
                let text: String
                let x: Double
                let baseline: Double
                let sourceGlyphMatches: Bool
            }
            let name: String
            let markers: [Marker]
        }
        let cases: [Case]
    }
    private func fonts() throws -> FontLibrary {
        let result = FontLibrary()
        try result.register(Data(contentsOf: root.deletingLastPathComponent()
            .appendingPathComponent("Typography/DejaVuSans.ttf")), aliases: ["DejaVu Sans"])
        return result
    }
    @Test(arguments: ["base", "followup", "compatibility", "descent", "scale", "fractional", "reduction", "reduction-anchor", "percentage-anchor"])
    func independentNativeExplicitSpacing(folder: String) throws {
        let directory = root.appendingPathComponent(folder)
        let manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: directory.appendingPathComponent("manifest.json")))
        let inputs = try JSONDecoder().decode([Input].self, from: Data(contentsOf: directory.appendingPathComponent("cases.json")))
        let capture = try JSONDecoder().decode(Capture.self, from: Data(contentsOf: directory.appendingPathComponent("native-metrics.json")))
        let deck = try Presentation(contentsOf: directory.appendingPathComponent(manifest.source))
        let fontLibrary = try fonts()
        let arialURL = URL(fileURLWithPath: "/System/Library/Fonts/Supplemental/Arial.ttf")
        let hasArial = FileManager.default.fileExists(atPath: arialURL.path)
        if hasArial { try fontLibrary.register(Data(contentsOf: arialURL), aliases: ["Arial"]) }
        let before = try deck.serializedData()
        let expectedCount = folder == "base" ? 37 : folder == "followup" ? 12 : ["descent", "reduction-anchor", "percentage-anchor"].contains(folder) ? 4 : 6
        #expect(inputs.count == expectedCount && capture.cases.count == expectedCount)
        #expect(Set(inputs.map(\.name)).count == expectedCount)
        #expect(Set(capture.cases.map(\.name)).count == expectedCount)
        let names = Set(inputs.map(\.name))
        #expect(deck.slides.flatMap(\.shapes).filter { names.contains($0.name) }.count == expectedCount)
        for (input, native) in zip(inputs, capture.cases) {
            #expect(input.name == native.name)
            // The two system-Arial research controls run only where that exact
            // face is available. All 83 bundled-font cases run on every platform.
            if input.font == "Arial", !hasArial { continue }
            let shape = try #require(deck.slides[input.page].shapes.first { $0.name == input.name })
            let frame: TextFrame
            if input.table == true {
                frame = try (try #require((shape as? TableFrame)?.table)).cell(0, 0).textFrame
            } else { frame = try #require(shape.textFrame) }
            let layout = RichTextLayout(textBody: frame.txBody, width: input.width, height: input.height, fonts: fontLibrary)
            #expect(layout.diagnostics.isEmpty)
            let visible = layout.lines.flatMap { line in line.spans.map { ($0, line.baseline) } }
            #expect(visible.count == native.markers.count)
            for ((span, baseline), marker) in zip(visible, native.markers) {
                #expect(span.run.text == marker.text)
                #expect(marker.sourceGlyphMatches)
                #expect(abs(span.x - marker.x) < 0.121)
                #expect(abs(baseline - marker.baseline) < 0.121, "\(input.name): \(baseline) vs \(marker.baseline)")
            }
        }
        #expect(try deck.serializedData() == before)
        let reopened = try Presentation(data: before)
        #expect(try reopened.serializedData() == before)
        try deck.fonts.register(Data(contentsOf: root.deletingLastPathComponent()
            .appendingPathComponent("Typography/DejaVuSans.ttf")), aliases: ["DejaVu Sans"])
        for index in 0..<deck.slides.count {
            let svg = try deck.renderSVG(slideAt: index)
            #expect(try deck.renderSVG(slideAt: index) == svg)
        }
        #expect(try deck.serializedData() == before)
    }

    private func body(_ content: String, spacing: String = "<a:lnSpc><a:spcPct val=\"150000\"/></a:lnSpc>",
                      attributes: String = "", paragraphAttributes: String = "", autofit: String = "") throws -> XML.Element {
        try XML.parse(Data("""
        <a:txBody><a:bodyPr lIns="0" rIns="0" tIns="0" bIns="0" \(attributes)>\(autofit)</a:bodyPr>
        <a:p><a:pPr \(paragraphAttributes)>\(spacing)<a:defRPr sz="1800"><a:latin typeface="DejaVu Sans"/></a:defRPr></a:pPr>
        \(content)</a:p></a:txBody>
        """.utf8))
    }
    private var threeLines: String {
        "<a:r><a:t>A</a:t></a:r><a:br/><a:r><a:t>B</a:t></a:r><a:br/><a:r><a:t>Z</a:t></a:r>"
    }
    @Test func compatibilityBooleanAndInheritedSpacingPreservePrecedence() throws {
        let library = try fonts()
        let zero = try body(threeLines, attributes: "compatLnSpc=\"0\"")
        let falseValue = try body(threeLines, attributes: "compatLnSpc=\"false\"")
        let zeroLayout = RichTextLayout(textBody: zero, width: 290, height: 160, fonts: library)
        #expect(zeroLayout.lines.map(\.baseline) == [24, 55, 86])
        #expect(RichTextLayout(textBody: falseValue, width: 290, height: 160, fonts: library).lines == zeroLayout.lines)
        let inherited = try XML.parse(Data("<a:lstStyle><a:lvl1pPr><a:lnSpc><a:spcPct val=\"150000\"/></a:lnSpc></a:lvl1pPr></a:lstStyle>".utf8))
        let xml = try body(threeLines, spacing: "")
        let before = xml.serialized()
        let layout = RichTextLayout(textBody: xml, width: 290, height: 160, fonts: library, inheritedStyles: [inherited])
        #expect(layout.lines.map(\.baseline) == [24, 57, 89])
        #expect(xml.serialized() == before)
        let own = try #require(xml.firstChild(named: "a:p")?.firstChild(named: "a:pPr"))
        own.appendElement(try XML.parse(Data("<a:lnSpc><a:spcPts val=\"1440\"/></a:lnSpc>".utf8)))
        #expect(RichTextLayout(textBody: xml, width: 290, height: 160, fonts: library, inheritedStyles: [inherited]).lines.map(\.baseline) == [11, 25, 39])
    }
    @Test func unsupportedParagraphsAndTinyScaledSizesKeepFiniteLegacyMetrics() throws {
        let library = try fonts()
        for (content, attributes) in [("<a:r><a:t>A</a:t></a:r>", "rtl=\"1\""), ("<a:r><a:t>é</a:t></a:r>", "")] {
            let xml = try body(content, paragraphAttributes: attributes)
            let layout = RichTextLayout(textBody: xml, width: 290, height: 160, fonts: library)
            #expect(layout.lines[0].baseline == 17)
            #expect(abs(layout.lines[0].height - 32.4) < 1e-9)
        }
        let tiny = try body(threeLines, autofit: "<a:normAutofit fontScale=\"100\"/>")
        let layout = RichTextLayout(textBody: tiny, width: 290, height: 160, fonts: library)
        #expect(layout.lines.count == 3)
        #expect(layout.contentHeight.isFinite)
        #expect(layout.lines.allSatisfy { $0.baseline.isFinite && $0.height > 0 })
        #expect(abs(layout.lines[0].height - 0.0324) < 1e-12)
    }
    @Test func aliasesAndLiveResolutionDoNotLeakMetricEligibility() throws {
        let library = try fonts()
        let data = try Data(contentsOf: root.deletingLastPathComponent().appendingPathComponent("Typography/DejaVuSans.ttf"))
        try library.register(data, aliases: ["Spacing Alias"])
        let content = "<a:r><a:rPr><a:latin typeface=\"Spacing Alias\"/></a:rPr><a:t>AB</a:t></a:r>"
        let xml = try body(content)
        let known = RichTextLayout(textBody: xml, width: 290, height: 160, fonts: library)
        #expect(known.lines[0].baseline == 24 && known.diagnostics.isEmpty)
        let latin = try #require(xml.firstChild(named: "a:p")?.children(named: "a:r").last?.firstChild(named: "a:rPr")?.firstChild(named: "a:latin"))
        latin[attribute: "typeface"] = "Missing Spacing Face"
        let missing = RichTextLayout(textBody: xml, width: 290, height: 160, fonts: library)
        #expect(missing.lines[0].baseline == 18)
        #expect(!missing.diagnostics.isEmpty)
        latin[attribute: "typeface"] = "Spacing Alias"
        #expect(RichTextLayout(textBody: xml, width: 290, height: 160, fonts: library).lines == known.lines)
        let mixed = try body("<a:r><a:t>A</a:t></a:r>" + content)
        let mixedLayout = RichTextLayout(textBody: mixed, width: 290, height: 160, fonts: library)
        #expect(mixedLayout.lines[0].baseline == 17)
        #expect(mixedLayout.diagnostics.contains(.unsupportedLayoutFeature("Native explicit line spacing with multiple font faces on one line is not verified")))
    }
    private func syntheticWindowsFont(ascent: Int, cmap: [UInt8] = TestFont.cmapFormat4()) -> Data {
        var os2 = TestFont.os2(useTypoMetrics: false)
        os2.replaceSubrange(74..<76, with: TestFont.be16(ascent))
        os2.replaceSubrange(76..<78, with: TestFont.be16(1000 - ascent))
        return TestFont.standard(cmap: cmap, os2: os2, familyName: "Same Internal Name")
    }
    @Test func resolvedRegistryFacesOverrideIdenticalInternalMetadata() throws {
        let library = FontLibrary()
        try library.register(syntheticWindowsFont(ascent: 800), face: FontFaceKey(family: "First Face"))
        try library.register(syntheticWindowsFont(ascent: 600), face: FontFaceKey(family: "Second Face"))
        let xml = try body("<a:r><a:rPr><a:latin typeface=\"First Face\"/></a:rPr><a:t>A</a:t></a:r><a:r><a:rPr><a:latin typeface=\"Second Face\"/></a:rPr><a:t>B</a:t></a:r>")
        let layout = RichTextLayout(textBody: xml, width: 290, height: 160, fonts: library)
        #expect(layout.lines[0].baseline == 14)
        #expect(layout.diagnostics.contains(.unsupportedLayoutFeature("Native explicit line spacing with multiple font faces on one line is not verified")))
        let collector = RenderDiagnosticCollector()
        collector.text(layout)
        #expect(collector.issues.contains { $0.code == .unsupportedTextProperty && $0.message.hasPrefix("Native explicit line spacing") })
        #expect(!collector.issues.contains { $0.code == .unsupportedShaping && $0.message.contains("Native explicit line spacing") })
    }
    @Test func rejectedAdvanceProfileAlsoRejectsExplicitVerticalCalibration() throws {
        let library = try fonts()
        for text in ["A\u{0001}", "A\u{007f}"] {
            let xml = try body("<a:r><a:t>A</a:t></a:r>")
            // XML loading rejects C0; exercise an unsaved live DOM as well as DEL.
            let textNode = try #require(xml.firstChild(named: "a:p")?.firstChild(named: "a:r")?.firstChild(named: "a:t"))
            textNode.children = [.text(text)]
            let layout = RichTextLayout(textBody: xml, width: 290, height: 160, fonts: library)
            #expect(layout.lines[0].baseline == 17)
            #expect(!layout.diagnostics.isEmpty)
        }
        // A missing glyph on the final line rejects the paragraph before emit;
        // earlier lines must not be partially calibrated.
        let metrics = try FontMetrics(data: syntheticWindowsFont(ascent: 800, cmap: TestFont.cmapFormat4RangeOffset()))
        let layout = RichTextLayout(textBody: try body(threeLines), width: 290, height: 160, fallbackMetrics: metrics)
        #expect(layout.lines.map(\.baseline) == [17, 50, 82])
        #expect(!layout.diagnostics.isEmpty)
    }
    @Test func publicFittingPersistsComputedSharedSpacingWithoutChangingParagraphs() throws {
        let source = root.appendingPathComponent("compatibility/native-spacing-final-v1.pptx")
        var results: [Autofit] = []
        for useShapeAPI in [false, true] {
            let deck = try Presentation(contentsOf: source)
            try deck.fonts.register(Data(contentsOf: root.deletingLastPathComponent().appendingPathComponent("Typography/DejaVuSans.ttf")))
            let shape = try #require(deck.slides[0].shapes.first { $0.name == "pct150-18-four-compat1" })
            let originalFrame = shape.frame
            shape.frame = Rect(x: originalFrame.x, y: originalFrame.y, width: originalFrame.width, height: .points(65))
            let frame = try #require(shape.textFrame)
            let paragraphs = frame.txBody.children(named: "a:p").map { $0.serialized() }
            let fit = useShapeAPI ? try #require(shape.fitText(fonts: deck.fonts))
                : frame.fitText(in: shape.frame, fonts: deck.fonts)
            results.append(fit)
            // This is the library's computed ladder choice, not a native-chosen
            // scale. Independent stored-scale/reduction captures calibrate the
            // shared vertical geometry used to assess each candidate.
            #expect(fit.fits && fit.fontScale == 55 && fit.lineSpacingReduction == 20)
            let layout = RichTextLayout(textBody: frame.txBody, width: 290, height: 65, fonts: deck.fonts)
            #expect(layout.fits && layout.diagnostics.isEmpty)
            #expect(layout.lines.map(\.baseline) == [12, 27, 43, 59])
            #expect(frame.txBody.children(named: "a:p").map { $0.serialized() } == paragraphs)
            let saved = try deck.serializedData()
            let svg = try deck.renderSVG(slideAt: 0)
            #expect(try deck.renderSVG(slideAt: 0) == svg)
            #expect(try deck.serializedData() == saved)
            let reopened = try Presentation(data: saved)
            let reopenedShape = try #require(reopened.slides[0].shapes.first { $0.name == shape.name })
            let auto = try #require(reopenedShape.textFrame?.txBody.firstChild(named: "a:bodyPr")?.firstChild(named: "a:normAutofit"))
            #expect(auto[attribute: "fontScale"] == "55000")
            #expect(auto[attribute: "lnSpcReduction"] == "20000")
            #expect(try reopened.serializedData() == saved)
        }
        #expect(results[0] == results[1])
    }

}
