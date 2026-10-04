import Foundation
import Rostrum

struct TextAlignmentReferences: Decodable {
    struct Face: Decodable { let id: String; let family: String; let bold: Bool; let sha256: String }
    struct Glyph: Decodable {
        let text: String; let x: Double; let baseline: Double
        let rawPDFPaintScale: [Double]; let sourceGlyphBounds: [Double]; let geometricInkBounds: [Double]
        let sourceGlyphMatches: Bool
    }
    struct Line: Decodable { let visibleText: String; let baseline: Double; let glyphs: [Glyph] }
    struct Sample: Decodable {
        let id: String; let slide: Int; let source: String
        let x: Double; let y: Double; let width: Double; let height: Double
        let table: Bool; let face: String; let alignment: String
        let expectedVisibleScalars: Int; let lines: [Line]
        var frame: Rect { .init(x: .points(x), y: .points(y), width: .points(width), height: .points(height)) }
    }
    let scope: String; let source: String; let sourceSHA256: String; let nativePDFSHA256: String
    let casesSHA256: String; let metricsSHA256: String
    let faces: [Face]; let cases: [Sample]
}

/// Parse each rendered page once. Case checks reuse the parsed text nodes and
/// aliases resolved against the actual embedded font bytes.
struct TextAlignmentSVGPage {
    let textNodes: [XML.Element]
    let aliases: [String: String]
    let untransformed: Bool

    init(svg: String, fonts: FontLibrary) throws {
        let root = try XML.parse(Data(svg.utf8))
        textNodes = DrawingLabFixtures.nodes(root, "text")
        aliases = PlatformLabRecipes.markerFaceAliases(svg: svg, fonts: fonts)
        untransformed = DrawingLabFixtures.nodes(root, "g").allSatisfy { $0[attribute: "transform"] == nil }
    }

    func matches(_ sample: TextAlignmentReferences.Sample) -> Bool {
        guard untransformed else { return false }
        let lines: [(XML.Element, Double)] = textNodes.compactMap { node in
            guard let t = node[attribute: "transform"], t.hasPrefix("translate(") else { return nil }
            let v = t.components(separatedBy: CharacterSet(charactersIn: "(), ")).compactMap(Double.init)
            guard v.count == 3, v[2] == Double(EMU.perPoint), abs(v[0] / Double(EMU.perPoint) - sample.x) < 0.001 else { return nil }
            let baseline = v[1] / Double(EMU.perPoint) - sample.y
            return baseline >= 0 && baseline < sample.height ? (node, baseline) : nil
        }
        guard lines.count == sample.lines.count else { return false }
        var total = 0
        for ((node, baseline), expected) in zip(lines, sample.lines) {
            guard abs(baseline - expected.baseline) < 0.121 else { return false }
            let spans = node.children(named: "tspan")
            guard spans.map(\.textContent).joined().filter({ !$0.isWhitespace }) == expected.visibleText else { return false }
            var consumed = 0
            for span in spans {
                let scalars = Array(span.textContent.unicodeScalars)
                let positions = (span[attribute: "x"] ?? "").split(whereSeparator: \.isWhitespace).compactMap { Double($0) }
                let alias = (span[attribute: "font-family"] ?? "").components(separatedBy: ",").first ?? ""
                guard span[attribute: "textLength"] == nil, span[attribute: "lengthAdjust"] == nil,
                      positions.count == scalars.count, aliases[alias] == sample.face, span[attribute: "font-style"] != "italic",
                      let paint = span[attribute: "font-size"].flatMap(Double.init) else { return false }
                for (scalar, x) in zip(scalars, positions) where scalar != " " {
                    guard consumed < expected.glyphs.count else { return false }
                    let g = expected.glyphs[consumed]
                    let tolerance = consumed == 0 ? 0.025 : 0.06
                    consumed += 1; total += 1
                    guard g.sourceGlyphMatches, String(scalar) == g.text, abs(x - g.x) < tolerance,
                          abs(baseline - g.baseline) < 0.121, g.rawPDFPaintScale.count == 2,
                          g.rawPDFPaintScale.allSatisfy({ abs($0 - paint) < 0.002 }),
                          g.sourceGlyphBounds.count == 4, g.geometricInkBounds.count == 4 else { return false }
                    let b = g.sourceGlyphBounds, ink = g.geometricInkBounds
                    guard abs((b[2] - b[0]) * paint / 2048 - (ink[2] - ink[0])) < 0.002,
                          abs((b[3] - b[1]) * paint / 2048 - (ink[3] - ink[1])) < 0.002 else { return false }
                }
            }
            guard consumed == expected.glyphs.count else { return false }
        }
        return total == sample.expectedVisibleScalars
    }
}

extension PlatformLabRecipes {
    static func textAlignmentReferences() throws -> TextAlignmentReferences {
        try JSONDecoder().decode(TextAlignmentReferences.self, from: resource("TextAlignmentReferences", "json"))
    }

    static func alignmentSpecimen(_ deck: Presentation, sample: TextAlignmentReferences.Sample) throws -> XML.Element {
        let tree = try require(deck.slides[sample.slide].part.dom().firstChild(named: "p:cSld")?.firstChild(named: "p:spTree"), "Alignment shape tree missing")
        return try require(tree.childElements.first { node in
            DrawingLabFixtures.nodes(node, "p:cNvPr").first?[attribute: "name"] == sample.id
        }, "Alignment specimen missing: " + sample.id)
    }

    static func alignmentNativeChecks(_ deck: Presentation, reference: TextAlignmentReferences, prefix: String = "") throws -> [LibraryLabCheck] {
        let rendered = try (0..<4).map { try deck.renderSVGReportingProblems(slideAt: $0) }
        let pages = try rendered.map { try TextAlignmentSVGPage(svg: $0.svg, fonts: deck.fonts) }
        var checks = reference.cases.map { sample in
            LibraryLabCheck(prefix + "Native text alignment: " + sample.id, pages[sample.slide].matches(sample),
                  "Independent line text, exact face, first origin, every scalar, baseline and painted outline dimensions.")
        }
        let issues = rendered.flatMap { $0.problems.fidelityIssues }
        checks.append(.init(prefix + "Alignment corpus and limits", reference.cases.count == 24
            && Set(reference.cases.map(\.id)).count == 24
            && reference.cases.reduce(0) { $0 + $1.expectedVisibleScalars } == 172
            && issues.count == 2 && issues.allSatisfy {
                $0.code == .unsupportedTextProperty && $0.location.slideIndex == 3
                    && $0.message.contains("Native table cells ignore stored fontScale")
            }, "All 24 cases and 172 glyphs are checked; exactly the two stored 50% table scales remain diagnosed."))
        return checks
    }

    static func textAlignment(_ options: LibraryLabOptions) throws -> LibraryLabDraft {
        let references = try resource("TextAlignmentReferences", "json")
        let reference = try textAlignmentReferences()
        let source = try resource("native-body-alignment-v1", "pptx")
        let deck = try Presentation(data: source)
        deck.registerEmbeddedFonts()
        let originals = try reference.cases.map { try alignmentSpecimen(deck, sample: $0).serialized() }
        let names = Set(reference.cases.map(\.id))
        // Only outside-frame captions change face. All 24 actual specimens,
        // including table properties and positive kerning, remain untouched.
        for slide in deck.slides {
            for shape in slide.shapes where !names.contains(shape.name) {
                for p in shape.textFrame?.paragraphs ?? [] {
                    for run in p.runs { run.fontName = "DejaVu Sans" }
                }
            }
        }
        let masters = try (0..<4).map { try deck.slides[$0].master?.part.uri }
        let faces = try reference.faces.map { face in
            (FontFaceKey(family: face.family, bold: face.bold), try require(deck.fonts.data(for: .init(family: face.family, bold: face.bold)), "Alignment embedded face missing"))
        }
        let slide = try deck.slides.add()
        func caption(_ value: String, y: Double, size: Double = 18) throws {
            let box = try text(value, on: slide, in: .init(x: .points(30), y: .points(y), width: .points(660), height: .points(75)))
            box.textFrame?.paragraphs.first?.runs.first?.fontSize = size
        }
        let alignment: TextAlignment = options.alternative ? .right : .center
        let name = options.alternative ? "Right" : "Center"
        try caption("Text alignment: " + name.lowercased(), y: 25, size: 28)
        try caption("Four reference pages retain native bodies and frames. Here, the same public text authoring uses three separate boxes.", y: 90)
        let bodyText = "Agjp BBBBBBBBBBBBZ Agjp BBBBBBBBBBBBZ"
        var fits: [Autofit] = []
        var fitBodies: [String: String] = [:]
        for (index, role) in ["Original", "Shape.fitText", "TextFrame.fitText"].enumerated() {
            let x = 35.0 + Double(index) * 225
            let frame = Rect(x: .points(x), y: .points(255), width: .points(190), height: .points(index == 0 ? 180 : 70))
            try slide.shapes.addShape(.rectangle, frame: frame, fill: .none, line: Line(color: Color("276D89")))
            let box = try slide.shapes.addTextBox(frame)
            box.name = role + " alignment copy"
            let tf = try require(box.textFrame, "Alignment text frame missing")
            tf.text = bodyText
            let paragraph = try require(tf.paragraphs.first, "Alignment paragraph missing")
            paragraph.alignment = alignment
            for run in paragraph.runs { run.fontName = "DejaVu Sans"; run.fontSize = 28; run.color = .black }
            tf.setAutoFit(fontScale: 1)
            if index > 0 {
                let fit = index == 1 ? try require(box.fitText(fonts: deck.fonts, theme: deck.theme), "Alignment shape fit missing")
                    : tf.fitText(in: frame, fonts: deck.fonts, theme: deck.theme)
                fits.append(fit)
                let measured = try text("Computed: \(fit.fontScale)% font scale\n\(fit.lineSpacingReduction)% line reduction", on: slide,
                    in: .init(x: .points(x), y: .points(350), width: .points(190), height: .points(65)))
                for p in measured.textFrame?.paragraphs ?? [] {
                    for run in p.runs { run.fontSize = 14 }
                }
            }
            // Parsing canonicalizes attribute order while retaining every
            // authored value; reopening performs the same normalization.
            fitBodies[box.name] = try XML.parse(Data(paragraphBody(deck, named: box.name, slideAt: 4).serialized().utf8)).serialized()
            let label = try text(role, on: slide, in: .init(x: .points(x), y: .points(200), width: .points(205), height: .points(45)))
            label.textFrame?.paragraphs.first?.runs.first?.fontSize = 17
        }
        try caption("Original: authored 28 pt. The two smaller copies use computed fitting. Both APIs keep the same words and alignment.", y: 460, size: 17)
        try caption("Native references cover finite Latin text, actual font faces, fractional widths, spaces, padding, kerning and table cells. Stored table scale stays diagnosed. Computed fit scales are not PowerPoint autofit choices.", y: 555, size: 16)
        let layouts = try ["Shape.fitText", "TextFrame.fitText"].map { try paragraphGeometry(deck, named: $0 + " alignment copy", slideAt: 4) }
        var checks = try alignmentNativeChecks(deck, reference: reference)
        checks.append(.init("Alignment public fits agree", fits.count == 2 && fits[0] == fits[1] && fits.allSatisfy(\.fits)
                            && fits.allSatisfy { $0.fontScale < 100 } && layouts[0].lines == layouts[1].lines,
                            "Both public APIs fit publicly authored text with the selected center/right alignment; originals remain separate."))
        let saved = try deck.serializedData()
        let svgs = try (0..<5).map { try deck.renderSVG(slideAt: $0) }
        checks.append(.init("Alignment rendering is read-only", try deck.serializedData() == saved, "Rendering preserves the saved source."))
        return LibraryLabDraft(deck: deck, before: source, checks: checks,
            extraFiles: ["native-alignment-reference.json": references], verify: { reopened in
                reopened.registerEmbeddedFonts()
                var result = try alignmentNativeChecks(reopened, reference: reference, prefix: "Saved ")
                let bodies = try reference.cases.map { try alignmentSpecimen(reopened, sample: $0).serialized() }
                let currentMasters = try (0..<4).map { try reopened.slides[$0].master?.part.uri }
                result.append(.init("Alignment bodies and inheritance survive", bodies == originals && currentMasters == masters,
                                    "All 24 entire specimen nodes preserve source bodies, frames, table properties and inherited master linkage."))
                result.append(.init("Alignment embedded faces survive", faces.allSatisfy { reopened.fonts.data(for: $0.0) == $0.1 }, "All three actual bundled font faces reopen byte-for-byte."))
                let fitsPreserved = try fitBodies.allSatisfy { name, body in
                    try paragraphBody(reopened, named: name, slideAt: 4).serialized() == body
                }
                let reopenedLayouts = try ["Shape.fitText", "TextFrame.fitText"].map { try paragraphGeometry(reopened, named: $0 + " alignment copy", slideAt: 4) }
                result.append(.init("Alignment computed fits survive", fitsPreserved && zip(layouts, reopenedLayouts).allSatisfy { $0.lines == $1.lines && $1.fits }, "Exact authored properties and chosen fit attributes reopen with matching geometry."))
                let rendered = try (0..<5).map { try reopened.renderSVG(slideAt: $0) }
                result.append(.init("Alignment SVG is deterministic", rendered == svgs, "All saved/reopened pages reproduce exact SVG bytes."))
                return result
            })
    }
}
