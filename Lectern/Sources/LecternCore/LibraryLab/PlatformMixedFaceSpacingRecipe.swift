import Foundation
import Rostrum

struct MixedFaceSpacingReferences: Decodable {
    struct Face: Decodable { let id: String; let family: String; let bold: Bool; let sha256: String; let windowsSignature: [Double] }
    struct Glyph: Decodable {
        let text: String; let sourceFace: String; let x: Double; let baseline: Double
        let rawPDFPaintScale: [Double]; let sourceGlyphBounds: [Double]; let geometricInkBounds: [Double]
        let sourceGlyphMatches: Bool
    }
    struct Line: Decodable { let visibleText: String; let baseline: Double; let glyphs: [Glyph] }
    struct Sample: Decodable {
        let id: String; let slide: Int; let source: String
        let x: Double; let y: Double; let width: Double; let height: Double
        let sourceGroup: String
        let expectedVisibleScalars: Int; let lines: [Line]
        var frame: Rect { .init(x: .points(x), y: .points(y), width: .points(width), height: .points(height)) }
    }
    struct Source: Decodable { let group: String; let source: String; let sourceSHA256: String; let nativePDFSHA256: String }
    let scope: String; let sources: [Source]
    let faces: [Face]; let cases: [Sample]
}

/// Parse each rendered page once. Case checks reuse the parsed text nodes and
/// aliases resolved against the actual embedded font bytes.
struct MixedFaceSpacingSVGPage {
    let textNodes: [XML.Element]
    let aliases: [String: String]
    let untransformed: Bool

    init(svg: String, fonts: FontLibrary) throws {
        let root = try XML.parse(Data(svg.utf8))
        textNodes = DrawingLabFixtures.nodes(root, "text")
        aliases = PlatformLabRecipes.markerFaceAliases(svg: svg, fonts: fonts)
        untransformed = DrawingLabFixtures.nodes(root, "g").allSatisfy { $0[attribute: "transform"] == nil }
    }

    func matches(_ sample: MixedFaceSpacingReferences.Sample) -> Bool {
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
                      positions.count == scalars.count, span[attribute: "font-style"] != "italic",
                      let paint = span[attribute: "font-size"].flatMap(Double.init) else { return false }
                for (scalar, x) in zip(scalars, positions) where scalar != " " {
                    guard consumed < expected.glyphs.count else { return false }
                    let g = expected.glyphs[consumed]
                    let tolerance = consumed == 0 ? 0.025 : 0.06
                    consumed += 1; total += 1
                    guard g.sourceGlyphMatches, aliases[alias] == g.sourceFace, String(scalar) == g.text, abs(x - g.x) < tolerance,
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
    static func mixedSpacingReferences() throws -> MixedFaceSpacingReferences {
        try JSONDecoder().decode(MixedFaceSpacingReferences.self, from: resource("MixedFaceSpacingReferences", "json"))
    }

    /// Read only the two actual sfnt Windows fields used by the source proof.
    /// No line position or fit result is computed by this resource guard.
    static func mixedSpacingSignature(_ data: Data) -> [Double]? {
        let bytes = [UInt8](data)
        func u16(_ i: Int) -> Int { Int(bytes[i]) * 256 + Int(bytes[i + 1]) }
        func u32(_ i: Int) -> Int { u16(i) * 65536 + u16(i + 2) }
        guard bytes.count >= 12 else { return nil }
        let count = u16(4)
        guard count <= (bytes.count - 12) / 16 else { return nil }
        var tables: [String: (offset: Int, length: Int)] = [:]
        for i in 0..<count {
            let start = 12 + i * 16, offset = u32(12 + i * 16 + 8), length = u32(12 + i * 16 + 12)
            guard offset <= bytes.count, length <= bytes.count - offset else { return nil }
            tables[String(decoding: bytes[start..<(start + 4)], as: UTF8.self)] = (offset, length)
        }
        guard let head = tables["head"], head.length >= 20,
              let os2 = tables["OS/2"], os2.length >= 78 else { return nil }
        let units = u16(head.offset + 18), ascent = u16(os2.offset + 74), descent = u16(os2.offset + 76)
        guard units > 0, ascent > 0, ascent + descent > 0 else { return nil }
        return [Double(ascent) / Double(ascent + descent), Double(ascent + descent) / Double(units)]
    }

    static func mixedSpacingSpecimen(_ deck: Presentation, sample: MixedFaceSpacingReferences.Sample) throws -> XML.Element {
        let tree = try require(deck.slides[sample.slide].part.dom().firstChild(named: "p:cSld")?.firstChild(named: "p:spTree"), "Mixed spacing shape tree missing")
        return try require(tree.children(named: "p:sp").first {
            $0.firstChild(named: "p:nvSpPr")?.firstChild(named: "p:cNvPr")?[attribute: "name"] == sample.id
        }, "Mixed spacing specimen missing: " + sample.id)
    }

    static func mixedSpacingNativeChecks(_ deck: Presentation, reference: MixedFaceSpacingReferences, prefix: String = "") throws -> [LibraryLabCheck] {
        let rendered = try (0..<2).map { try deck.renderSVGReportingProblems(slideAt: $0) }
        let pages = try rendered.map { try MixedFaceSpacingSVGPage(svg: $0.svg, fonts: deck.fonts) }
        var checks = reference.cases.map { sample in
            LibraryLabCheck(prefix + "Native mixed-face spacing: " + sample.id, pages[sample.slide].matches(sample),
                "Exact per-glyph face and line text; first x .025 pt, other x .06 pt, baseline .121 pt, paint and ink dimensions .002 pt.")
        }
        checks.append(.init(prefix + "Mixed spacing corpus complete", reference.cases.count == 12
            && Set(reference.cases.map(\.id)).count == 12
            && reference.cases.reduce(0) { $0 + $1.expectedVisibleScalars } == 96
            && rendered.allSatisfy { $0.problems.isEmpty }, "Both native pages cover 12 cases and 96 glyphs without findings."))
        return checks
    }

    static func mixedFaceSpacing(_ options: LibraryLabOptions) throws -> LibraryLabDraft {
        let referenceData = try resource("MixedFaceSpacingReferences", "json")
        let reference = try mixedSpacingReferences()
        let source = try resource("native-mixed-face-spacing-v1", "pptx")
        let deck = try Presentation(data: source)
        let followup = try Presentation(data: resource("native-mixed-face-spacing-anchors-v1", "pptx"))
        _ = try deck.slides.importAll(from: followup)
        deck.registerEmbeddedFonts()
        let originalNodes = try reference.cases.map { try mixedSpacingSpecimen(deck, sample: $0).serialized() }
        let masters = try (0..<2).map { try deck.slides[$0].master?.part.uri }
        let names = Set(reference.cases.map(\.id))
        // The two full pages are not byte-identical: only captions outside
        // native specimen frames switch from Calibri to the bundled face.
        for slide in deck.slides {
            for shape in slide.shapes where !names.contains(shape.name) {
                for paragraph in shape.textFrame?.paragraphs ?? [] {
                    for run in paragraph.runs { run.fontName = "DejaVu Sans" }
                }
            }
        }
        let fonts = try reference.faces.map { face in
            (FontFaceKey(family: face.family, bold: face.bold), try require(deck.fonts.data(for: .init(family: face.family, bold: face.bold)), "Mixed spacing font missing"))
        }
        let signatures = fonts.map { mixedSpacingSignature($0.1) }
        let fontGuard = fonts.count == 2 && fonts[0].1 != fonts[1].1 && signatures[0] != nil
            && signatures[0] == signatures[1] && zip(signatures, reference.faces).allSatisfy { $0 == $1.windowsSignature }
        let sourceBody = try paragraphBody(deck, named: "exact18-sans12-serif24", slideAt: 0).serialized()
        let slide = try deck.slides.add()
        func caption(_ value: String, x: Double = 30, y: Double, width: Double = 660, height: Double = 70, size: Double = 18) throws {
            let shape = try text(value, on: slide, in: .init(x: .points(x), y: .points(y), width: .points(width), height: .points(height)))
            for p in shape.textFrame?.paragraphs ?? [] { for run in p.runs { run.fontSize = size } }
        }
        try caption("Mixed faces, exact line spacing", y: 25, size: 28)
        try caption("Two different font resources share the same normalized Windows vertical metrics. The first two pages retain 12 native specimens.", y: 95)
        let anchor: VerticalAnchor = options.alternative ? .bottom : .top
        try caption("Computed comparison: " + (options.alternative ? "bottom" : "top") + " anchored, 40 pt frame", y: 165, height: 35, size: 17)
        var fits: [Autofit] = [], layouts: [RichTextLayout] = []
        var bodies: [String: String] = [:]
        for (index, role) in ["Shape.fitText", "TextFrame.fitText"].enumerated() {
            let x = index == 0 ? 30.0 : 380.0
            let frame = Rect(x: .points(x), y: .points(270), width: .points(290), height: .points(40))
            // The outlined shape owns its painted body, avoiding an empty
            // furniture text node with platform-dependent fallback metrics.
            let box = try slide.shapes.addShape(.rectangle, frame: frame, fill: .none, line: Line(color: Color("276D89")))
            box.name = role + " mixed spacing copy"
            let body = try paragraphBody(deck, named: box.name, slideAt: 2)
            body.children = try XML.parse(Data(sourceBody.utf8)).children
            slide.part.markDirty()
            let tf = try require(box.textFrame, "Mixed spacing text frame missing")
            tf.verticalAnchor = anchor
            let fit = index == 0 ? try require(box.fitText(fonts: deck.fonts, theme: deck.theme), "Mixed spacing shape fit missing")
                : tf.fitText(in: frame, fonts: deck.fonts, theme: deck.theme)
            fits.append(fit)
            layouts.append(try paragraphGeometry(deck, named: box.name, slideAt: 2))
            bodies[box.name] = try XML.parse(Data(body.serialized().utf8)).serialized()
            try caption(role, x: x, y: 225, width: 290, height: 35)
            try caption("Computed: \(fit.fontScale)% scale / \(fit.lineSpacingReduction)% line reduction\nContent extent: \(String(format: "%.6f", layouts[index].contentHeight)) pt", x: x, y: 335, width: 290, height: 85, size: 15)
        }
        try caption("Source: exact18-sans12-serif24\n12 pt Sans + 24 pt Serif, repeated on two lines with exact 18 pt spacing. Both public fit APIs preserve every paragraph and run property.", y: 440, height: 95, size: 17)
        try caption("Supported here: actual faces with equal normalized Windows metrics, shape text, exact point spacing and zero line reduction. Unequal metrics, mixed-face percentage spacing, table context and incompatible spacing remain outside this native proof. Computed fits are not PowerPoint-selected autofit.", y: 560, height: 110, size: 15)
        var checks = try mixedSpacingNativeChecks(deck, reference: reference)
        checks.append(.init("Mixed spacing actual metrics agree", fontGuard, "Two distinct actual font byte resources have the independently pinned Windows ascent share and height."))
        checks.append(.init("Mixed spacing public fits agree", fits.count == 2 && fits[0] == fits[1]
            && fits.allSatisfy { $0.fits && $0.fontScale == 100 && $0.lineSpacingReduction == 0 }
            && layouts[0].lines == layouts[1].lines && layouts.allSatisfy {
                $0.fits && $0.diagnostics.isEmpty && abs($0.contentHeight - 37.33489932885906) < 1e-9
            }, "Both public APIs compute 100%/0% in 40 pt frames from the native-constrained unrounded extent; no native fit-choice claim."))
        let saved = try deck.serializedData()
        let svgs = try (0..<3).map { try deck.renderSVG(slideAt: $0) }
        checks.append(.init("Mixed spacing rendering is read-only", try deck.serializedData() == saved, "Native checks and rendering preserve package state."))
        return LibraryLabDraft(deck: deck, before: source, checks: checks,
            extraFiles: ["native-mixed-spacing-reference.json": referenceData], verify: { reopened in
                reopened.registerEmbeddedFonts()
                var result = try mixedSpacingNativeChecks(reopened, reference: reference, prefix: "Saved ")
                let nodes = try reference.cases.map { try mixedSpacingSpecimen(reopened, sample: $0).serialized() }
                let currentMasters = try (0..<2).map { try reopened.slides[$0].master?.part.uri }
                result.append(.init("Mixed spacing specimens and inheritance survive", nodes == originalNodes && currentMasters == masters,
                                    "All 12 entire specimen nodes preserve native frames, bodies and master linkage; caption changes are separate."))
                result.append(.init("Mixed spacing embedded faces survive", fonts.allSatisfy { reopened.fonts.data(for: $0.0) == $0.1 }, "Both licensed actual faces reopen byte-for-byte."))
                let recovered = try ["Shape.fitText", "TextFrame.fitText"].map { try paragraphGeometry(reopened, named: $0 + " mixed spacing copy", slideAt: 2) }
                let bodiesMatch = try bodies.allSatisfy { name, body in try paragraphBody(reopened, named: name, slideAt: 2).serialized() == body }
                result.append(.init("Mixed spacing computed fits survive", bodiesMatch && zip(layouts, recovered).allSatisfy { $0.lines == $1.lines && $1.fits }, "Exact authored properties and computed fit attributes reopen with matching geometry."))
                result.append(.init("Mixed spacing SVG is deterministic", try (0..<3).map { try reopened.renderSVG(slideAt: $0) } == svgs, "Every saved/reopened page reproduces exact SVG."))
                return result
            })
    }
}
