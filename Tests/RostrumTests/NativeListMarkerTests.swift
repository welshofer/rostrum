import Foundation
import Testing
@testable import Rostrum

@Suite struct NativeListMarkerTests {
    private var root: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/NativeListMarkers")
    }
    private struct Input: Decodable {
        let name: String
        let page: Int
        let width: Double
        let height: Double
        let x: Double
        let y: Double
    }
    private struct Manifest: Decodable { let source: String; let caseCount: Int }
    private struct Capture: Decodable {
        struct Case: Decodable {
            struct Omission: Decodable { let text: String }
            struct Glyph: Decodable {
                let text: String
                let x: Double
                let baseline: Double
                let matchingSourceFaces: [String]
                let rawPDFPaintScale: [Double]
                let sourceGlyphBounds: [Double]
                let geometricInkBounds: [Double]
            }
            struct Line: Decodable { let visibleText: String }
            let name: String
            let expectedVisibleScalars: Int
            let consumedVisibleScalars: Int
            let explicitlyOmittedMarkers: [Omission]
            let markerGlyphs: [Glyph]
            let bodyGlyphs: [Glyph]
            let bodyLines: [Line]
        }
        let cases: [Case]
    }
    private func descendants(_ element: XML.Element) -> [XML.Element] {
        [element] + element.childElements.flatMap(descendants)
    }
    private func translation(_ element: XML.Element) -> (Double, Double)? {
        guard let value = element[attribute: "transform"], value.hasPrefix("translate("),
              let end = value.firstIndex(of: ")"), value.contains("scale(12700)") else { return nil }
        let parts = value[value.index(value.startIndex, offsetBy: 10)..<end].split(separator: ",").compactMap { Double($0) }
        guard parts.count == 2 else { return nil }
        return (parts[0] / 12700, parts[1] / 12700)
    }
    @Test func uncalibratedMarkerContextsKeepTheirPriorSizing() throws {
        let fonts = FontLibrary()
        for filename in ["DejaVuSans.ttf", "DejaVuSans-Bold.ttf"] {
            try fonts.register(Data(contentsOf: root.appendingPathComponent("fonts/" + filename)))
        }
        for (paragraphAttributes, marker, runAttributes) in [
            ("algn=\"r\"", "<a:buChar char=\"•\"/>", ""),
            ("rtl=\"1\"", "<a:buChar char=\"•\"/>", ""),
            ("", "<a:buChar char=\"AB\"/>", ""),
            ("", "<a:buAutoNum type=\"romanLcPeriod\"/>", ""),
            ("", "<a:buChar char=\"•\"/>", "spc=\"25\""),
            ("", "<a:buChar char=\"•\"/>", "kern=\"1200\"")
        ] {
            let xml = try XML.parse(Data("""
            <p:txBody><a:bodyPr lIns="0" tIns="0" rIns="0" bIns="0"><a:normAutofit fontScale="50000"/></a:bodyPr>
            <a:p><a:pPr \(paragraphAttributes)>\(marker)<a:defRPr sz="2900" kern="0"><a:latin typeface="DejaVu Sans"/></a:defRPr></a:pPr>
            <a:r><a:rPr \(runAttributes)/><a:t>BBBB</a:t></a:r></a:p></p:txBody>
            """.utf8))
            let layout = RichTextLayout(textBody: xml, width: 300, height: 100, fonts: fonts)
            let span = try #require(layout.lines.first?.spans.first)
            #expect(span.run.nativeSizing == nil && span.scalarPositions == nil)
            #expect(span.run.paintedPointSize == 14.5)
        }
    }
    @Test func invalidSizesAndLeadingControlsDeclineMarkerCalibration() throws {
        let fonts = FontLibrary()
        try fonts.register(Data(contentsOf: root.appendingPathComponent("fonts/DejaVuSans.ttf")))
        let sizes: [(String, Double)] = [
            ("<a:buSzPct val=\"0\"/>", 0),
            ("<a:buSzPct val=\"1000\"/>", 0.145),
            ("<a:buSzPct val=\"400001\"/>", 58),
            ("<a:buSzPct/>", 14.5),
            ("<a:buSzPct val=\"NaN\"/>", 14.5),
            ("<a:buSzPct val=\"25000.5\"/>", 14.5 * 25000.5 / 100000),
            ("<a:buSzPts val=\"1\"/>", 0.5),
            ("<a:buSzPts val=\"400001\"/>", 2000),
            ("<a:buSzPts/>", 9),
            ("<a:buSzPts val=\"infinity\"/>", 9)
        ]
        for (size, expected) in sizes {
            let xml = try XML.parse(Data("""
            <p:txBody><a:bodyPr><a:normAutofit fontScale="50000"/></a:bodyPr><a:p>
            <a:pPr>\(size)<a:buChar char="•"/><a:defRPr sz="2900"><a:latin typeface="DejaVu Sans"/></a:defRPr></a:pPr>
            <a:r><a:t>BBBB</a:t></a:r></a:p></p:txBody>
            """.utf8))
            let layout = RichTextLayout(textBody: xml, width: 300, height: 100, fonts: fonts)
            let marker = try #require(layout.lines.first?.spans.first)
            #expect(marker.run.nativeSizing == nil && marker.scalarPositions == nil)
            #expect(abs(marker.run.paintedPointSize - expected) < 1e-10)
        }
        for prefix in ["<a:br/>", "<a:r><a:t>&#9;</a:t></a:r>", "<a:r><a:t>&#10;</a:t></a:r>", "<a:r><a:t> </a:t></a:r>"] {
            let xml = try XML.parse(Data("""
            <p:txBody><a:bodyPr><a:normAutofit fontScale="50000"/></a:bodyPr><a:p>
            <a:pPr><a:buChar char="•"/><a:defRPr sz="2900"><a:latin typeface="DejaVu Sans"/></a:defRPr></a:pPr>
            \(prefix)<a:r><a:t>BBBB</a:t></a:r></a:p></p:txBody>
            """.utf8))
            let layout = RichTextLayout(textBody: xml, width: 300, height: 100, fonts: fonts)
            let marker = try #require(layout.lines.first?.spans.first)
            #expect(marker.run.nativeSizing == nil && marker.scalarPositions == nil)
            #expect(marker.run.paintedPointSize == 14.5)
        }
    }
    @Test(arguments: ["", "followup"])
    func nativeMarkerAndBodyGeometry(folder: String) throws {
        let directory = folder.isEmpty ? root : root.appendingPathComponent(folder)
        let manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: directory.appendingPathComponent("manifest.json")))
        let inputs = try JSONDecoder().decode([Input].self, from: Data(contentsOf: directory.appendingPathComponent("cases.json")))
        let native = try JSONDecoder().decode(Capture.self, from: Data(contentsOf: directory.appendingPathComponent("native-marker-metrics.json")))
        let deck = try Presentation(contentsOf: directory.appendingPathComponent(manifest.source))
        deck.registerEmbeddedFonts()
        let before = try deck.serializedData()
        let count = folder.isEmpty ? 18 : 6
        #expect(manifest.caseCount == count && inputs.count == count && native.cases.count == count)
        #expect(Set(inputs.map(\.name)).count == count)
        #expect(Set(native.cases.map(\.name)).count == count)
        let names = Set(inputs.map(\.name))
        #expect(deck.slides.flatMap(\.shapes).filter { names.contains($0.name) }.count == count)
        var svgPages: [XML.Element] = []
        for index in 0..<deck.slides.count {
            let svg = try deck.renderSVG(slideAt: index)
            #expect(try deck.renderSVG(slideAt: index) == svg)
            svgPages.append(try XML.parse(Data(svg.utf8)))
        }
        for (input, expected) in zip(inputs, native.cases) {
            #expect(input.name == expected.name)
            #expect(expected.expectedVisibleScalars == expected.consumedVisibleScalars + expected.explicitlyOmittedMarkers.count)
            let shape = try #require(deck.slides[input.page].shapes.first { $0.name == input.name })
            let frame = try #require(shape.textFrame)
            let inheritance = RichTextLayout.inheritedStyles(for: shape.element, owner: shape.part, package: deck.package)
            let layout = RichTextLayout(textBody: frame.txBody, width: input.width, height: input.height,
                fonts: deck.fonts, theme: try deck.slides[input.page].resolvedTheme, inheritedStyles: inheritance)
            #expect(layout.diagnostics.isEmpty, "\(input.name): diagnostics")
            let hasMarker = !expected.markerGlyphs.isEmpty
            var actualBodyLines: [String] = []
            var consumed = 0
            let expectedGlyphs = expected.markerGlyphs + expected.bodyGlyphs
            for (lineIndex, line) in layout.lines.enumerated() {
                var bodyText = ""
                for (spanIndex, span) in line.spans.enumerated() {
                    if !(hasMarker && lineIndex == 0 && spanIndex == 0) { bodyText += span.run.text }
                    let positions = span.scalarPositions ?? [span.x]
                    let scalars = Array(span.run.text.unicodeScalars)
                    #expect(positions.count == scalars.count, "\(input.name): all marker/body scalar origins")
                    guard positions.count == scalars.count else { continue }
                    let face = span.run.fontFamily == "DejaVu Serif" ? "serif" : span.run.bold ? "bold" : "regular"
                    for (scalar, x) in zip(scalars, positions) where scalar != " " {
                        guard consumed < expectedGlyphs.count else { Issue.record("\(input.name): extra visible scalar"); continue }
                        let glyph = expectedGlyphs[consumed]; consumed += 1
                        #expect(String(scalar) == glyph.text, "\(input.name): visible scalar")
                        #expect(glyph.matchingSourceFaces.contains(face), "\(input.name): actual marker/body face")
                        // Finite captured strings: PDF TJ/font-width quantization
                        // causes up to 0.043 pt drift in the bold body control.
                        #expect(abs(x - glyph.x) < 0.06, "\(input.name): glyph x")
                        #expect(abs(line.baseline - glyph.baseline) < 0.121, "\(input.name): baseline")
                        let paint = span.run.paintedPointSize
                        #expect(glyph.rawPDFPaintScale.allSatisfy { abs($0 - paint) < 0.002 }, "\(input.name): glyph paint")
                        let bounds = glyph.sourceGlyphBounds, ink = glyph.geometricInkBounds
                        let width = (bounds[2] - bounds[0]) * paint / 2048
                        let height = (bounds[3] - bounds[1]) * paint / 2048
                        #expect(abs(width - (ink[2] - ink[0])) < 0.002)
                        #expect(abs(height - (ink[3] - ink[1])) < 0.002)
                    }
                }
                actualBodyLines.append(bodyText.filter { !$0.isWhitespace })
            }
            #expect(actualBodyLines == expected.bodyLines.map(\.visibleText), "\(input.name): native body wrapping")
            #expect(consumed == expected.consumedVisibleScalars, "\(input.name): complete visible glyph consumption")
            #expect(layout.fits)
            let svgLines = descendants(svgPages[input.page]).filter { element in
                guard element.name == "text", let (x, y) = translation(element) else { return false }
                return abs(x - input.x) < 0.001 && y >= input.y && y < input.y + input.height
            }
            #expect(svgLines.count == expected.bodyLines.count)
            var drawn = 0
            for line in svgLines {
                for span in line.children(named: "tspan") {
                    #expect(span[attribute: "textLength"] == nil && span[attribute: "lengthAdjust"] == nil)
                    let positions = (span[attribute: "x"] ?? "").split(separator: " ").compactMap { Double($0) }
                    let scalars = Array(span.textContent.unicodeScalars)
                    #expect(positions.count == scalars.count)
                    let paint = try #require(span[attribute: "font-size"].flatMap(Double.init))
                    for (scalar, x) in zip(scalars, positions) where scalar != " " {
                        guard drawn < expectedGlyphs.count else { Issue.record("Extra SVG glyph"); continue }
                        let glyph = expectedGlyphs[drawn]; drawn += 1
                        #expect(String(scalar) == glyph.text)
                        #expect(abs(x - glyph.x) < 0.06)
                        #expect(glyph.rawPDFPaintScale.allSatisfy { abs($0 - paint) < 0.002 })
                    }
                }
            }
            #expect(drawn == expected.consumedVisibleScalars)
        }
        #expect(try deck.serializedData() == before)
        #expect(try Presentation(data: before).serializedData() == before)
    }
}
