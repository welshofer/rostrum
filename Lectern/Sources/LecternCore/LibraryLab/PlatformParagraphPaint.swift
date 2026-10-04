import Foundation
import Rostrum

/// Source glyph outlines and PDF matrices are independent of the SVG renderer.
struct ParagraphPaintReferences: Decodable {
    struct Glyph: Decodable {
        let text: String
        let x: Double
        let baseline: Double
        let rawPDFPaintScale: [Double]
        let geometricInkBounds: [Double]
        let sourceGlyphBounds: [Double]
    }
    struct Line: Decodable {
        let baseline: Double
        let visibleText: String
        let characters: [Glyph]
    }
    struct Sample: Decodable {
        let id: String
        let alternative: Bool
        let title: String
        let widthPoints: Double
        let heightPoints: Double
        let source: String
        let sourcePage: Int
        let sourceSHA256: String
        let nativePDF: String
        let nativePDFSHA256: String
        let fontSHA256: String
        let unitsPerEm: Double
        let textBodyXML: String
        let nativeLines: [Line]
    }
    let scope: String
    let cases: [Sample]
}

struct ParagraphPaintGlyph: Equatable {
    let text: String
    let x: Double
    let baseline: Double
    let size: Double
}

extension PlatformLabRecipes {
    static func paragraphPaintReferences() throws -> ParagraphPaintReferences {
        try JSONDecoder().decode(ParagraphPaintReferences.self, from: resource("ParagraphPaintReferences", "json"))
    }

    static func paragraphPaint(_ deck: Presentation, alternative: Bool) throws -> (checks: [LibraryLabCheck], verify: (Presentation) throws -> [LibraryLabCheck]) {
        let samples = try paragraphPaintReferences().cases.filter { $0.alternative == alternative }
        let slide = try deck.slides.add()
        let title = try text("Glyph size and placement follow native painting", on: slide,
                             in: LibraryLabSupport.frame(0.6, 0.3, 12, 0.6))
        title.textFrame?.paragraphs.first?.runs.first?.fontSize = 26
        var checks: [LibraryLabCheck] = []
        var originals: [String: Rect] = [:]
        var fitted: [String: [RichTextLine]] = [:]
        var fits: [String: Autofit] = [:]
        for (index, sample) in samples.enumerated() {
            let x = [0.6, 4.8, 9.0][index % 3], y = index < 3 ? 1.5 : 4.2
            let heading = try text(sample.title, on: slide,
                                   in: LibraryLabSupport.frame(x, y - 0.4, 4, 0.35))
            heading.textFrame?.paragraphs.first?.runs.first?.fontSize = 14
            let rect = Rect(x: .inches(x), y: .inches(y), width: .points(sample.widthPoints), height: .points(sample.heightPoints))
            let original = try paintBox(sample, deck: deck, slide: slide, frame: rect, role: "original")
            originals[sample.id] = original.frame
            let observed = sample.nativeLines.map(\.visibleText).joined(separator: " / ")
            let note = try text("Native: " + observed, on: slide,
                                in: LibraryLabSupport.frame(x + 0.08, y + 0.58, 3.9, 0.35))
            note.textFrame?.paragraphs.first?.runs.first?.fontSize = 11
            var selections: [Autofit] = []
            var fitLayouts: [RichTextLayout] = []
            for (offset, role) in [(0.08, "shape fit"), (2.15, "frame fit")] {
                // These are independent computed examples, not native oracle boxes.
                // Distinct x positions keep public-SVG selection unambiguous.
                let fitRect = Rect(x: .inches(x + offset), y: .inches(y + 1.25), width: .points(100), height: .points(20))
                let box = try paintBox(sample, deck: deck, slide: slide, frame: fitRect, role: role)
                let frame = try require(box.textFrame, "Paint fitting frame missing")
                let selected = role == "shape fit"
                    ? try require(box.fitText(fonts: deck.fonts, theme: deck.theme), "Paint shape fit missing")
                    : frame.fitText(in: box.frame, fonts: deck.fonts, theme: deck.theme)
                let layout = try paragraphGeometry(deck, named: box.name, slideAt: 6)
                selections.append(selected); fitLayouts.append(layout)
                fits[box.name] = selected; fitted[box.name] = layout.lines
                let label = try text(role == "shape fit" ? "Shape.fitText" : "TextFrame.fitText", on: slide,
                                     in: LibraryLabSupport.frame(x + offset, y + 0.92, 1.75, 0.3))
                label.textFrame?.paragraphs.first?.runs.first?.fontSize = 11
                let scale = try text("Computed: \(selected.fontScale)%", on: slide,
                                     in: LibraryLabSupport.frame(x + offset, y + 1.66, 1.75, 0.3))
                scale.textFrame?.paragraphs.first?.runs.first?.fontSize = 11
            }
            let expectedText = sample.nativeLines.map(\.visibleText).joined()
            checks.append(.init("Glyph specimen public fits: \(sample.id)",
                selections[0] == selections[1] && selections.allSatisfy(\.fits)
                    && fitLayouts[0].lines == fitLayouts[1].lines
                    && fitLayouts.allSatisfy { $0.fits && $0.diagnostics.isEmpty && $0.contentHeight <= 20
                        && $0.lines.allSatisfy { $0.visibleWidth <= 100 }
                        && boundaryLineStrings($0).joined().filter { !$0.isWhitespace } == expectedText },
                "Both public paths compute the same fit in separate 100 by 20 pt boxes without replacing authored run sizes."))
        }
        let footer = try text("Original boxes retain native text bodies and frame sizes. Glyph ink and origins are checked against independent PDF outlines.\nRegular DejaVu Sans and calibrated ASCII only. Separate fit copies show computed choices, not native autofit selection.", on: slide,
                              in: LibraryLabSupport.frame(0.6, 6.65, 12.1, 0.6))
        footer.textFrame?.paragraphs.first?.runs.first?.fontSize = 12
        footer.fitText(fonts: deck.fonts)
        let rendered = try deck.renderSVGReportingProblems(slideAt: 6)
        for sample in samples {
            let layout = try paragraphGeometry(deck, named: sample.id + " paint original", slideAt: 6)
            let frame = try require(originals[sample.id], "Original paint frame missing")
            checks.append(.init("Native glyph painting: \(sample.id)",
                paintGlyphsMatch(svg: rendered.svg, frame: frame, sample: sample)
                    && paintLinesMatch(layout, sample: sample) && layout.fits && layout.diagnostics.isEmpty,
                "Visible scalar origins agree within 0.025 pt, baselines within 0.121 pt, and paint size and source-outline ink dimensions within 0.002 pt; no glyph stretching."))
        }
        checks.append(.init("Glyph preview has no findings", rendered.problems.isEmpty,
                            "All six original specimens and their separately labeled fitting copies render without fallback diagnostics."))
        return (checks, { reopened in
            let saved = try reopened.renderSVGReportingProblems(slideAt: 6)
            var result: [LibraryLabCheck] = []
            for sample in samples {
                let layout = try paragraphGeometry(reopened, named: sample.id + " paint original", slideAt: 6)
                let frame = try require(originals[sample.id], "Saved paint frame missing")
                let properties = try paintPropertiesMatch(reopened, sample: sample, role: "original", fit: nil)
                let fitProperties = try ["shape fit", "frame fit"].allSatisfy { role in
                    let name = sample.id + " paint " + role
                    return try paintPropertiesMatch(reopened, sample: sample, role: role, fit: fits[name])
                        && paragraphGeometry(reopened, named: name, slideAt: 6).lines == fitted[name]
                }
                result.append(.init("Saved native glyph painting: \(sample.id)",
                    paintGlyphsMatch(svg: saved.svg, frame: frame, sample: sample)
                        && paintLinesMatch(layout, sample: sample) && properties && fitProperties,
                    "Native glyph dimensions, origins, exact original text bodies and frame sizes survive; fitted copies retain run properties and computed fitting settings."))
            }
            result.append(.init("Glyph SVG survives reopening", saved.svg == rendered.svg && saved.problems.isEmpty,
                                "The saved seventh-slide SVG is byte-identical and retains zero findings."))
            return result
        })
    }

    private static func paintBox(_ sample: ParagraphPaintReferences.Sample, deck: Presentation, slide: Slide, frame: Rect, role: String) throws -> Shape {
        try slide.shapes.addShape(.rectangle, frame: frame, fill: .none, line: Line(color: Color("276D89")))
        let box = try slide.shapes.addTextBox(frame)
        box.name = sample.id + " paint " + role
        let imported = try XML.parse(Data(sample.textBodyXML.utf8))
        try paragraphBody(deck, named: box.name, slideAt: 6).children = imported.children
        slide.part.markDirty()
        return box
    }

    static func paintLinesMatch(_ layout: RichTextLayout, sample: ParagraphPaintReferences.Sample) -> Bool {
        layout.lines.map { $0.spans.map(\.run.text).joined().filter { !$0.isWhitespace } } == sample.nativeLines.map(\.visibleText)
    }

    /// Parse the actual public SVG, not layout's internal advances. The admitted
    /// contract supplies one x per scalar and paints at its own font-size.
    static func paintGlyphs(svg: String, frame: Rect) -> [ParagraphPaintGlyph]? {
        guard let root = try? XML.parse(Data(svg.utf8)) else { return nil }
        var glyphs: [ParagraphPaintGlyph] = []
        for node in DrawingLabFixtures.nodes(root, "text") {
            guard let transform = node[attribute: "transform"], transform.hasPrefix("translate(") else { continue }
            let values = transform.components(separatedBy: CharacterSet(charactersIn: "(), ")).compactMap(Double.init)
            guard values.count == 3, values[2] == Double(EMU.perPoint),
                  abs(values[0] - Double(frame.x.rawValue)) < 0.001 else { continue }
            let baseline = values[1] / Double(EMU.perPoint) - frame.y.points
            guard baseline >= 0, baseline <= frame.height.points else { continue }
            for span in node.children(named: "tspan") {
                let scalars = Array(span.textContent.unicodeScalars)
                guard span[attribute: "textLength"] == nil, span[attribute: "lengthAdjust"] == nil,
                      let size = span[attribute: "font-size"].flatMap(Double.init),
                      let positions = span[attribute: "x"]?.split(whereSeparator: { $0.isWhitespace }).compactMap({ Double($0) }),
                      positions.count == scalars.count else { return nil }
                for (scalar, x) in zip(scalars, positions) where scalar.value != 32 {
                    glyphs.append(.init(text: String(scalar), x: x, baseline: baseline, size: size))
                }
            }
        }
        return glyphs
    }

    static func paintGlyphsMatch(svg: String, frame: Rect, sample: ParagraphPaintReferences.Sample) -> Bool {
        guard let actual = paintGlyphs(svg: svg, frame: frame) else { return false }
        let expected = sample.nativeLines.flatMap(\.characters)
        return actual.count == expected.count && zip(actual, expected).allSatisfy { glyph, native in
            guard native.rawPDFPaintScale.count == 2, native.sourceGlyphBounds.count == 4,
                  native.geometricInkBounds.count == 4 else { return false }
            let bounds = native.sourceGlyphBounds, ink = native.geometricInkBounds
            let width = (bounds[2] - bounds[0]) * glyph.size / sample.unitsPerEm
            let height = (bounds[3] - bounds[1]) * glyph.size / sample.unitsPerEm
            return glyph.text == native.text && abs(glyph.x - native.x) <= 0.025
                && abs(glyph.baseline - native.baseline) <= 0.121
                && native.rawPDFPaintScale.allSatisfy { abs(glyph.size - $0) <= 0.002 }
                && abs(width - (ink[2] - ink[0])) <= 0.002
                && abs(height - (ink[3] - ink[1])) <= 0.002
        }
    }

    static func paintPropertiesMatch(_ deck: Presentation, sample: ParagraphPaintReferences.Sample, role: String, fit: Autofit?) throws -> Bool {
        let name = sample.id + " paint " + role
        let shape = try require(deck.slides[6].shapes.all.first { $0.name == name }, "Saved paint shape missing")
        let body = try paragraphBody(deck, named: name, slideAt: 6)
        let source = try XML.parse(Data(sample.textBodyXML.utf8))
        guard let fit else {
            return body.childElements.map { $0.serialized() } == source.childElements.map { $0.serialized() }
                && shape.frame.width == .points(sample.widthPoints) && shape.frame.height == .points(sample.heightPoints)
        }
        let norm = body.firstChild(named: "a:bodyPr")?.firstChild(named: "a:normAutofit")
        let scale = Double(norm?[attribute: "fontScale"] ?? "100000").map { $0 / 1000 }
        let reduction = Double(norm?[attribute: "lnSpcReduction"] ?? "0").map { $0 / 1000 }
        return norm != nil && scale == fit.fontScale && reduction == fit.lineSpacingReduction
            && shape.frame.width == .points(100) && shape.frame.height == .points(20)
            && body.children(named: "a:p").map { $0.serialized() } == source.children(named: "a:p").map { $0.serialized() }
    }
}
