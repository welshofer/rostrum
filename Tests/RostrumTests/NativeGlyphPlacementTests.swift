import Foundation
import Testing
@testable import Rostrum

@Suite struct NativeGlyphPlacementTests {
    private var root: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/NativeGlyphPlacement")
    }
    private struct Input: Decodable {
        let name: String
        let page: Int
        let x: Double
        let y: Double
        let width: Double
        let height: Double
        let table: Bool?
    }
    private struct Manifest: Decodable { let source: String; let caseCount: Int }
    private struct Capture: Decodable {
        struct Case: Decodable {
            struct Line: Decodable {
                struct Glyph: Decodable {
                    let text: String
                    let x: Double
                    let baseline: Double
                    let rawPDFPaintScale: [Double]
                    let sourceGlyphBounds: [Double]
                    let geometricInkBounds: [Double]
                    let sourceGlyphMatches: Bool
                }
                let visibleText: String
                let baseline: Double
                let characters: [Glyph]
            }
            let name: String
            let expectedVisibleScalars: Int
            let consumedVisibleScalars: Int
            let lines: [Line]
        }
        let cases: [Case]
    }
    private func registerFaces(in fonts: FontLibrary) throws {
        let directory = root.appendingPathComponent("eligibility/fonts")
        for filename in ["DejaVuSans.ttf", "DejaVuSerif.ttf", "DejaVuSans-Bold.ttf", "DejaVuSans-Oblique.ttf"] {
            try fonts.register(Data(contentsOf: directory.appendingPathComponent(filename)))
        }
    }
    private func descendants(_ element: XML.Element) -> [XML.Element] {
        [element] + element.childElements.flatMap(descendants)
    }
    private func translation(_ element: XML.Element) -> (Double, Double)? {
        guard let value = element[attribute: "transform"], value.hasPrefix("translate("),
              let end = value.firstIndex(of: ")") else { return nil }
        let start = value.index(value.startIndex, offsetBy: 10)
        let parts = value[start..<end].split(separator: ",").compactMap { Double($0) }
        guard parts.count == 2, value.contains("scale(12700)") else { return nil }
        return (parts[0] / 12700, parts[1] / 12700)
    }
    @Test(arguments: ["primary", "autofit", "eligibility", "kerning"])
    func nativeScalarOriginsAndUndistortedInk(folder: String) throws {
        let directory = root.appendingPathComponent(folder)
        let manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: directory.appendingPathComponent("manifest.json")))
        let inputs = try JSONDecoder().decode([Input].self, from: Data(contentsOf: directory.appendingPathComponent("cases.json")))
        let capture = try JSONDecoder().decode(Capture.self, from: Data(contentsOf: directory.appendingPathComponent("native-paint-metrics.json")))
        let deck = try Presentation(contentsOf: directory.appendingPathComponent(manifest.source))
        try registerFaces(in: deck.fonts)
        let before = try deck.serializedData()
        let names = Set(inputs.map(\.name))
        #expect(inputs.count == manifest.caseCount && capture.cases.count == manifest.caseCount)
        #expect(names.count == inputs.count && Set(capture.cases.map(\.name)).count == inputs.count)
        #expect(deck.slides.flatMap(\.shapes).filter { names.contains($0.name) }.count == inputs.count)
        var rendered: [Int: XML.Element] = [:]
        for index in 0..<deck.slides.count {
            let svg = try deck.renderSVG(slideAt: index)
            #expect(try deck.renderSVG(slideAt: index) == svg)
            rendered[index] = try XML.parse(Data(svg.utf8))
        }
        for (input, native) in zip(inputs, capture.cases) {
            #expect(input.name == native.name)
            #expect(native.expectedVisibleScalars == native.consumedVisibleScalars)
            let svg = try #require(rendered[input.page])
            let lines = descendants(svg).filter { element in
                guard element.name == "text", let (x, y) = translation(element) else { return false }
                return abs(x - input.x) < 0.001 && y >= input.y && y < input.y + input.height
            }
            #expect(lines.count == native.lines.count, "\(input.name): native line count")
            var consumed = 0
            for (line, expected) in zip(lines, native.lines) {
                let position = try #require(translation(line))
                #expect(abs(position.1 - input.y - expected.baseline) < 0.121, "\(input.name): native baseline")
                let spans = line.children(named: "tspan")
                let visible = spans.map(\.textContent).joined().filter { !$0.isWhitespace }
                #expect(visible == expected.visibleText, "\(input.name): native line content")
                var glyphIndex = 0
                for span in spans {
                    #expect(span[attribute: "textLength"] == nil && span[attribute: "lengthAdjust"] == nil,
                            "\(input.name): native glyph outlines must not be stretched")
                    let points = (span[attribute: "x"] ?? "").split(whereSeparator: { $0 == " " || $0 == "," }).compactMap { Double($0) }
                    let scalars = Array(span.textContent.unicodeScalars)
                    #expect(points.count == scalars.count, "\(input.name): explicit scalar positions")
                    guard points.count == scalars.count else { continue }
                    let paint = try #require(span[attribute: "font-size"].flatMap(Double.init))
                    for (scalar, x) in zip(scalars, points) where scalar != " " && scalar != "\t" {
                        guard glyphIndex < expected.characters.count else { Issue.record("Extra SVG scalar"); break }
                        let glyph = expected.characters[glyphIndex]; glyphIndex += 1; consumed += 1
                        #expect(String(scalar) == glyph.text && glyph.sourceGlyphMatches)
                        // This is a finite captured glyph-origin bound. PDF /Widths,
                        // Tc and TJ rounding accumulates within styled runs; it is
                        // not a uniform guarantee for arbitrarily long strings.
                        let tolerance = folder == "primary" || folder == "autofit" ? 0.025 : 0.06
                        #expect(abs(x - glyph.x) < tolerance, "\(input.name): scalar origin")
                        #expect(glyph.rawPDFPaintScale.allSatisfy { abs($0 - paint) < 0.002 }, "\(input.name): paint size")
                        let bounds = glyph.sourceGlyphBounds
                        let expectedInk = glyph.geometricInkBounds
                        let inkWidth = (bounds[2] - bounds[0]) * paint / 2048
                        let inkHeight = (bounds[3] - bounds[1]) * paint / 2048
                        #expect(abs(inkWidth - (expectedInk[2] - expectedInk[0])) < 0.002, "\(input.name): ink width")
                        #expect(abs(inkHeight - (expectedInk[3] - expectedInk[1])) < 0.002, "\(input.name): ink height")
                    }
                }
                #expect(glyphIndex == expected.characters.count, "\(input.name): complete line consumption")
            }
            #expect(consumed == native.expectedVisibleScalars, "\(input.name): complete case consumption")
        }
        #expect(try deck.serializedData() == before)
        let reopened = try Presentation(data: before)
        #expect(try reopened.serializedData() == before)
    }
    private func body(_ paragraphs: String, scale: Int = 72500) throws -> XML.Element {
        try XML.parse(Data("<p:txBody><a:bodyPr lIns=\"0\" tIns=\"0\" rIns=\"0\" bIns=\"0\"><a:normAutofit fontScale=\"\(scale)\"/></a:bodyPr>\(paragraphs)</p:txBody>".utf8))
    }
    private func paragraph(_ text: String, family: String = "DejaVu Sans", properties: String = "", runProperties: String = "") -> String {
        "<a:p><a:pPr>\(properties)<a:defRPr sz=\"2000\"><a:latin typeface=\"\(family)\"/></a:defRPr></a:pPr><a:r><a:rPr \(runProperties)/><a:t>\(text)</a:t></a:r></a:p>"
    }

    @Test func absentAndInheritedKerningUseResolvedNativeMeasurementSize() throws {
        let fonts = FontLibrary(); try registerFaces(in: fonts)
        let xml = try body(paragraph("AVATAR ToTo"))
        let absent = RichTextLayout(textBody: xml, width: 300, height: 100, fonts: fonts)
        let inherited = try XML.parse(Data("<a:lstStyle><a:lvl1pPr><a:defRPr kern=\"1460\"/></a:lvl1pPr></a:lstStyle>".utf8))
        let enabled = RichTextLayout(textBody: xml, width: 300, height: 100, fonts: fonts, inheritedStyles: [inherited])
        let zero = RichTextLayout(textBody: try body(paragraph("AVATAR ToTo", runProperties: "kern=\"0\"")), width: 300, height: 100, fonts: fonts, inheritedStyles: [inherited])
        let offRun = try #require(absent.lines.first?.spans.first?.run)
        let onRun = try #require(enabled.lines.first?.spans.first?.run)
        #expect(!offRun.usesKerning && onRun.usesKerning)
        #expect(onRun.fontSize == 14.5 && onRun.measurementPointSize == 15 && onRun.paintedPointSize == 15)
        #expect(absent.lines.map(\.width) == zero.lines.map(\.width))
        #expect(absent.lines[0].spans[0].scalarPositions == zero.lines[0].spans[0].scalarPositions)
        #expect(enabled.lines[0].width < absent.lines[0].width)
        inherited.firstChild(named: "a:lvl1pPr")?.firstChild(named: "a:defRPr")?[attribute: "kern"] = "1510"
        let above = RichTextLayout(textBody: xml, width: 300, height: 100, fonts: fonts, inheritedStyles: [inherited])
        #expect(!above.lines[0].spans[0].run.usesKerning)
        #expect(above.lines.map(\.width) == absent.lines.map(\.width))
        #expect(above.lines[0].spans[0].scalarPositions == absent.lines[0].spans[0].scalarPositions)
    }

    @Test func rejectedParagraphDoesNotDisableEligibleNeighbors() throws {
        let fonts = FontLibrary(); try registerFaces(in: fonts)
        try fonts.register(TestFont.standard(cmap: TestFont.cmapFormat4RangeOffset()), aliases: ["OnlyABC"])
        let good = paragraph("BBBB"), rejected = paragraph("AZ", family: "OnlyABC")
        let reference = RichTextLayout(textBody: try body(good), width: 300, height: 100, fonts: fonts)
        for content in [good + rejected, rejected + good, rejected + good + rejected] {
            let layout = RichTextLayout(textBody: try body(content), width: 300, height: 300, fonts: fonts)
            let valid = try #require(layout.lines.first { $0.spans.map(\.run.text).joined() == "BBBB" })
            #expect(valid.spans == reference.lines[0].spans)
            let invalid = layout.lines.filter { $0.spans.map(\.run.text).joined() == "AZ" }
            #expect(!invalid.isEmpty && invalid.allSatisfy { $0.spans.allSatisfy { $0.run.nativeSizing == nil } })
            #expect(layout.diagnostics.contains(.unsupportedLayoutFeature("Native glyph paint rejected a paragraph with unsupported glyph mapping; retaining authored paint and measurement")))
        }
    }

    @Test func separateBulletMarkersResolveIndependentPaintAndWidth() throws {
        let fonts = FontLibrary(); try registerFaces(in: fonts)
        for marker in ["<a:buAutoNum type=\"arabicPeriod\" startAt=\"12\"/>",
                       "<a:buFont typeface=\"DejaVu Serif\"/><a:buSzPts val=\"1450\"/><a:buChar char=\"AB\"/>"] {
            let layout = RichTextLayout(textBody: try body(paragraph("BBBB", properties: marker)), width: 300, height: 100, fonts: fonts)
            let spans = try #require(layout.lines.first).spans
            let bullet = try #require(spans.first)
            #expect(bullet.run.text.count > 1 && bullet.width > 0)
            #expect(spans.last?.run.nativeSizing != nil)
            if marker.contains("buFont") {
                #expect(bullet.run.nativeSizing == nil && bullet.scalarPositions == nil)
                #expect(bullet.run.fontFamily == "DejaVu Serif")
                #expect(bullet.run.paintedPointSize == 10.5125)
            } else {
                // NativeListMarkers independently captures scaled Arabic numbering.
                #expect(bullet.run.paintedPointSize == 15)
                #expect(bullet.scalarPositions == [0, 9.5, 19, 23.75])
                #expect(spans.last?.x == 23.75)
            }
        }
    }

    @Test func paintedAttributeCacheDistinguishesAuthoredScaledAndGeneralRuns() throws {
        let cache = RenderTextAttributes()
        var run = ResolvedTextRun(text: "AV", fontFamily: "DejaVu Sans", fontSize: 14.5, bold: false, italic: false, color: "#000000", tracking: 0)
        var expected: [String] = []
        for policy: ResolvedTextRun.NativeSizing? in [nil, .authored, .scaled, nil] {
            run.nativeSizing = policy
            let text = cache.attributes(for: run, family: run.fontFamily)
            let element = try XML.parse(Data(("<tspan" + text + "/>").utf8))
            expected.append(try #require(element[attribute: "font-size"]))
        }
        #expect(expected == ["14.5000", "14", "15", "14.5000"])
    }
    @Test func cellContextIgnoresStoredScaleAndPublicFitIsReadOnly() throws {
        let deck = try Presentation(); try registerFaces(in: deck.fonts)
        let table = try deck.slides[0].shapes.addTable(rows: 1, columns: 1,
            frame: Rect(x: .points(0), y: .points(0), width: .points(120), height: .points(100)))
        table.clearBuiltInStyle()
        let cell = try table.cell(0, 0)
        let xml = try body(paragraph("BBBBBBBBBBBBZ"), scale: 67500)
        xml.name = "a:txBody"
        cell.tc.removeChildren(named: "a:txBody")
        cell.tc.insertChild(xml, beforeAnyOf: ["a:tcPr"])
        cell.setPadding(left: .points(0), top: .points(0), right: .points(0), bottom: .points(0))
        let frame = cell.textFrame
        let before = try deck.serializedData()
        let shape = RichTextLayout(textBody: xml, width: 120, height: 100, fonts: deck.fonts)
        let native = RichTextLayout(textBody: xml, width: 120, height: 100, fonts: deck.fonts, context: .tableCell)
        #expect(shape.lines[0].spans[0].run.fontSize == 13.5)
        #expect(native.lines[0].spans[0].run.fontSize == 20)
        #expect(native.lines.map { $0.spans.map(\.run.text).joined() } == ["BBBBBBBB", "BBBBZ"])
        #expect(shape.lines.map { $0.spans.map(\.run.text).joined() } == ["BBBBBBBBBBBB", "Z"])
        let override = RichTextLayout(textBody: xml, width: 120, height: 100, fonts: deck.fonts, fontScale: 67.5, context: .tableCell)
        #expect(override.lines == shape.lines)
        let small = Rect(x: .points(0), y: .points(0), width: .points(120), height: .points(22))
        let result = frame.fitText(in: small, fonts: deck.fonts)
        #expect(result.fontScale == 100 && result.lineSpacingReduction == 0 && !result.fits)
        #expect(try deck.serializedData() == before)
        let roomy = Rect(x: .points(0), y: .points(0), width: .points(120), height: .points(100))
        #expect(frame.fitText(in: roomy, fonts: deck.fonts).fits)
        cell.setPadding(left: .points(55), top: .points(0), right: .points(55), bottom: .points(0))
        #expect(!frame.fitText(in: roomy, fonts: deck.fonts).fits)
        cell.setPadding(left: .points(0), top: .points(0), right: .points(0), bottom: .points(0))
        xml.firstChild(named: "a:bodyPr")?.firstChild(named: "a:normAutofit")?[attribute: "lnSpcReduction"] = "10000"
        let reduced = RichTextLayout(textBody: xml, width: 120, height: 100, fonts: deck.fonts, context: .tableCell)
        #expect(reduced.lines.allSatisfy { $0.spans.allSatisfy { $0.run.nativeSizing == nil } })
        #expect(reduced.diagnostics.contains(.unsupportedLayoutFeature("Native table line-spacing reduction is not verified")))
        let beforeReducedFit = try deck.serializedData()
        #expect(!frame.fitText(in: roomy, fonts: deck.fonts).fits)
        #expect(try deck.serializedData() == beforeReducedFit)
    }

    @Test func trailingEmptyLineUsesEligibleEndFaceMeasurementPolicy() throws {
        let fonts = FontLibrary(); try registerFaces(in: fonts)
        func sample(_ end: String) throws -> RichTextLayout {
            let content = "<a:p><a:pPr><a:defRPr sz=\"1800\"><a:latin typeface=\"DejaVu Sans\"/></a:defRPr></a:pPr><a:r><a:t>A</a:t></a:r><a:br/><a:endParaRPr \(end)/></a:p>"
            return RichTextLayout(textBody: try body(content, scale: 75000), width: 300, height: 100, fonts: fonts)
        }
        // Policy consistency controls, not an additional independent native capture.
        let ordinary = try sample("sz=\"1800\"")
        #expect(ordinary.lines.count == 2)
        #expect(ordinary.lines[0].height == ordinary.lines[1].height)
        #expect(abs(ordinary.lines[1].height - 16.8) < 0.0001)
        let shifted = try sample("sz=\"1800\" baseline=\"1000\"")
        #expect(abs(shifted.lines[1].height - 16.2) < 0.0001)
        let missingXML = try body("<a:p><a:pPr><a:defRPr sz=\"1800\"><a:latin typeface=\"DejaVu Sans\"/></a:defRPr></a:pPr><a:r><a:t>A</a:t></a:r><a:br/><a:endParaRPr sz=\"1800\"><a:latin typeface=\"Unregistered End Face\"/></a:endParaRPr></a:p>", scale: 75000)
        let missing = RichTextLayout(textBody: missingXML, width: 300, height: 100, fonts: fonts)
        #expect(missing.lines[1].height == 18)
    }
    @Test func emptyInsertionStylesRequireTheirOwnResolvedFaceEligibility() throws {
        let fonts = FontLibrary()
        try fonts.register(Data(contentsOf: root.appendingPathComponent("eligibility/fonts/DejaVuSans.ttf")))
        for endProperties in [false, true] {
            for (attributes, family, expectedHeight) in [
                ("", "DejaVu Sans", 16.8), ("b=\"1\"", "DejaVu Sans", 16.2),
                ("i=\"1\"", "DejaVu Sans", 16.2), ("baseline=\"1000\"", "DejaVu Sans", 16.2),
                ("", "Missing Empty Face", 18.0),
            ] {
                let style = "sz=\"1800\" \(attributes)><a:latin typeface=\"\(family)\"/>"
                let content = endProperties
                    ? "<a:p><a:endParaRPr \(style)</a:endParaRPr></a:p>"
                    : "<a:p><a:pPr><a:defRPr \(style)</a:defRPr></a:pPr></a:p>"
                let xml = try body(content, scale: 75000)
                let layout = RichTextLayout(textBody: xml, width: 300, height: 100, fonts: fonts)
                #expect(layout.lines.count == 1 && layout.lines[0].spans.isEmpty)
                #expect(abs(layout.lines[0].height - expectedHeight) < 0.0001)
                let warning = ShapingDiagnostic.unsupportedLayoutFeature("Native glyph paint requires resolved scalar Latin faces without synthetic styles or baseline shifts")
                #expect(layout.diagnostics.contains(warning) == !attributes.isEmpty)
                #expect(layout.diagnostics.filter { $0 == warning }.count <= 1)
            }
        }
    }
}
