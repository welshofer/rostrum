import Foundation
import Testing
@testable import Rostrum

/// Finite native calibration of existing alignment; no new positioning formula.
@Suite struct NativeBodyAlignmentTests {
    private var root: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/NativeBodyAlignment")
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
    private struct Capture: Decodable {
        struct Case: Decodable {
            struct Glyph: Decodable {
                let text: String
                let x: Double
                let baseline: Double
                let rawPDFPaintScale: [Double]
                let sourceGlyphBounds: [Double]
                let geometricInkBounds: [Double]
                let sourceGlyphMatches: Bool
            }
            struct Line: Decodable {
                let visibleText: String
                let baseline: Double
                let characters: [Glyph]
            }
            let name: String
            let selectedFace: String
            let expectedVisibleScalars: Int
            let consumedVisibleScalars: Int
            let lines: [Line]
        }
        let cases: [Case]
    }
    private func descendants(_ element: XML.Element) -> [XML.Element] {
        [element] + element.childElements.flatMap(descendants)
    }
    private func translation(_ element: XML.Element) -> (x: Double, y: Double)? {
        guard let value = element[attribute: "transform"], value.hasPrefix("translate("),
              let end = value.firstIndex(of: ")"), value.contains("scale(12700)") else { return nil }
        let parts = value[value.index(value.startIndex, offsetBy: 10)..<end]
            .split(separator: ",").compactMap { Double($0) }
        guard parts.count == 2 else { return nil }
        return (parts[0] / 12700, parts[1] / 12700)
    }
    private func embeddedFonts(_ svg: XML.Element) throws -> [String: Data] {
        var result: [String: Data] = [:]
        for style in descendants(svg).filter({ $0.name == "style" }) {
            for rule in style.textContent.components(separatedBy: "@font-face{").dropFirst() {
                let familyStart = try #require(rule.range(of: "font-family:'")?.upperBound)
                let familyEnd = try #require(rule[familyStart...].firstIndex(of: "'"))
                let dataStart = try #require(rule.range(of: "base64,")?.upperBound)
                let dataEnd = try #require(rule[dataStart...].firstIndex(of: ")"))
                let decoded: Data? = Data(base64Encoded: String(rule[dataStart..<dataEnd]))
                let font = try #require(decoded)
                result[String(rule[familyStart..<familyEnd])] = font
            }
        }
        return result
    }
    @Test func nativeCenteredAndRightOriginsWrappingAndInk() throws {
        let inputs = try JSONDecoder().decode([Input].self, from: Data(contentsOf: root.appendingPathComponent("cases.json")))
        let native = try JSONDecoder().decode(Capture.self, from: Data(contentsOf: root.appendingPathComponent("native-alignment-metrics.json")))
        let deck = try Presentation(contentsOf: root.appendingPathComponent("native-body-alignment-v1.pptx"))
        #expect(Set(deck.registerEmbeddedFonts()) == ["DejaVu Sans", "DejaVu Serif"])
        let before = try deck.serializedData()
        #expect(inputs.count == 24 && native.cases.count == 24 && deck.slides.count == 4)
        let names = Set(inputs.map(\.name))
        #expect(names.count == 24 && Set(native.cases.map(\.name)) == names)
        #expect(deck.slides.flatMap(\.shapes).filter { names.contains($0.name) }.count == 24)
        let faces: [String: FontFaceKey] = ["regular": .init(family: "DejaVu Sans"),
            "bold": .init(family: "DejaVu Sans", bold: true), "serif": .init(family: "DejaVu Serif")]
        var pages: [XML.Element] = []
        var resources: [[String: Data]] = []
        for page in 0..<4 {
            let svg = try deck.renderSVG(slideAt: page)
            #expect(try deck.renderSVG(slideAt: page) == svg)
            let parsed = try XML.parse(Data(svg.utf8))
            // These unrotated specimens render in slide coordinates. Refuse a
            // future transformed container instead of silently ignoring it.
            #expect(descendants(parsed).filter { $0.name == "g" && $0[attribute: "transform"] != nil }.isEmpty)
            pages.append(parsed)
            resources.append(try embeddedFonts(parsed))
        }
        var allConsumed = 0
        for (input, expected) in zip(inputs, native.cases) {
            #expect(input.name == expected.name)
            #expect(expected.expectedVisibleScalars == expected.consumedVisibleScalars)
            let shape = try #require(deck.slides[input.page].shapes.first { $0.name == input.name })
            let body: XML.Element
            if input.table == true {
                body = try #require(descendants(shape.element).first { $0.name == "a:txBody" })
            } else { body = try #require(shape.textFrame).txBody }
            let inherited = RichTextLayout.inheritedStyles(for: shape.element, owner: shape.part, package: deck.package)
            let layout = RichTextLayout(textBody: body, width: input.width, height: input.height,
                fonts: deck.fonts, theme: try deck.slides[input.page].resolvedTheme, inheritedStyles: inherited,
                insets: input.table == true ? (0, 0, 0, 0) : nil,
                verticalAnchor: input.table == true ? "t" : nil, context: input.table == true ? .tableCell : .shape)
            let expectedLines = expected.lines.map(\.visibleText)
            let actualLines = layout.lines.map { $0.spans.map(\.run.text).joined().filter { !$0.isWhitespace } }
            #expect(actualLines == expectedLines, "\(input.name): native wrapping")
            let expectedDiagnostic: [ShapingDiagnostic] = input.table == true && input.name.contains("scale50")
                ? [.unsupportedLayoutFeature("Native table cells ignore stored fontScale; rendering at full size")] : []
            #expect(layout.diagnostics == expectedDiagnostic, "\(input.name): diagnostics")
            #expect(layout.fits)
            let lines = descendants(pages[input.page]).filter { element in
                guard element.name == "text", let t = translation(element) else { return false }
                return abs(t.x - input.x) < 0.001 && t.y >= input.y && t.y < input.y + input.height
            }
            #expect(lines.count == expected.lines.count)
            let expectedFace = try #require(faces[expected.selectedFace])
            let sourceBytes = try #require(deck.fonts.data(for: expectedFace))
            var consumed = 0
            for (line, reference) in zip(lines, expected.lines) {
                let origin = try #require(translation(line))
                #expect(abs(origin.y - input.y - reference.baseline) < 0.121, "\(input.name): baseline")
                let spans = line.children(named: "tspan")
                #expect(spans.map(\.textContent).joined().filter { !$0.isWhitespace } == reference.visibleText)
                var offset = 0
                for span in spans {
                    #expect(span[attribute: "textLength"] == nil && span[attribute: "lengthAdjust"] == nil)
                    let alias = try #require(span[attribute: "font-family"]?.components(separatedBy: ",").first)
                    #expect(resources[input.page][alias] == sourceBytes, "\(input.name): exact embedded actual face")
                    let positions = (span[attribute: "x"] ?? "").split(separator: " ").compactMap { Double($0) }
                    let scalars = Array(span.textContent.unicodeScalars)
                    #expect(positions.count == scalars.count)
                    guard positions.count == scalars.count else { continue }
                    let paint = try #require(span[attribute: "font-size"].flatMap(Double.init))
                    for (scalar, x) in zip(scalars, positions) where scalar != " " {
                        guard offset < reference.characters.count else { Issue.record("Extra native alignment scalar"); continue }
                        let glyph = reference.characters[offset]; offset += 1; consumed += 1
                        #expect(String(scalar) == glyph.text && glyph.sourceGlyphMatches)
                        // Existing finite captured-style bound; not a universal
                        // long-run guarantee against accumulating PDF TJ rounding.
                        #expect(abs(x - glyph.x) < 0.06, "\(input.name): scalar origin")
                        if offset == 1 {
                            // Keep the earlier regular span-start bound: this
                            // distinguishes raw centering from eighth-floor centering.
                            #expect(abs(x - glyph.x) < 0.025, "\(input.name): line start")
                        }
                        #expect(glyph.rawPDFPaintScale.allSatisfy { abs($0 - paint) < 0.002 })
                        let bounds = glyph.sourceGlyphBounds, ink = glyph.geometricInkBounds
                        let width = (bounds[2] - bounds[0]) * paint / 2048
                        let height = (bounds[3] - bounds[1]) * paint / 2048
                        #expect(abs(width - (ink[2] - ink[0])) < 0.002)
                        #expect(abs(height - (ink[3] - ink[1])) < 0.002)
                    }
                }
                #expect(offset == reference.characters.count)
            }
            #expect(consumed == expected.consumedVisibleScalars)
            allConsumed += consumed
        }
        #expect(allConsumed == 172)
        #expect(try deck.serializedData() == before)
        #expect(try Presentation(data: before).serializedData() == before)
    }
}
