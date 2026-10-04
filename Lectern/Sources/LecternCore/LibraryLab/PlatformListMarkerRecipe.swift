import Foundation
import Rostrum

struct ListMarkerReferences: Decodable {
    struct Face: Decodable { let id: String; let family: String; let bold: Bool; let sha256: String }
    struct Glyph: Decodable {
        let text: String
        let x: Double
        let baseline: Double
        let matchingSourceFaces: [String]
        let rawPDFPaintScale: [Double]
        let sourceGlyphBounds: [Double]
        let geometricInkBounds: [Double]
    }
    struct Sample: Decodable {
        let id: String
        let slide: Int
        let source: String
        let sourcePage: Int
        let sourceSHA256: String
        let nativePDFSHA256: String
        let x: Double
        let y: Double
        let width: Double
        let height: Double
        let textBodyXML: String
        let markerCount: Int
        let omittedMarkers: [String]
        let expectedVisibleScalars: Int
        let bodyLines: [String]
        let glyphs: [Glyph]
        var frame: Rect { .init(x: .points(x), y: .points(y), width: .points(width), height: .points(height)) }
    }
    let scope: String
    let faces: [Face]
    let cases: [Sample]
}

extension PlatformLabRecipes {
    static func listMarkerReferences() throws -> ListMarkerReferences {
        try JSONDecoder().decode(ListMarkerReferences.self, from: resource("ListMarkerReferences", "json"))
    }

    static func listMarkers(_ options: LibraryLabOptions) throws -> LibraryLabDraft {
        let referenceData = try resource("ListMarkerReferences", "json")
        let reference = try listMarkerReferences()
        let deck = try Presentation(data: resource("native-list-markers-v2", "pptx"))
        let before = try deck.serializedData()
        deck.registerEmbeddedFonts()
        let faces = try reference.faces.map { face in
            (FontFaceKey(family: face.family, bold: face.bold), try require(deck.fonts.data(for: .init(family: face.family, bold: face.bold)), "Marker font missing"))
        }
        let followup = try Presentation(data: resource("native-list-markers-followup-v1", "pptx"))
        _ = try deck.slides.importAll(from: followup)
        let names = Set(reference.cases.map(\.id))
        var originalBodies: [String: String] = [:]
        for sample in reference.cases {
            originalBodies[sample.id] = try paragraphBody(deck, named: sample.id, slideAt: sample.slide).serialized()
        }
        // Captured caption text is outside every native frame. Use a bundled
        // font for those captions; retain all specimen bodies and master chains.
        for slide in deck.slides {
            for shape in slide.shapes where !names.contains(shape.name) {
                for paragraph in shape.textFrame?.paragraphs ?? [] {
                    for run in paragraph.runs { run.fontName = "DejaVu Sans" }
                }
            }
        }
        let sourceMasters = try (0..<4).map { try deck.slides[$0].master?.part.uri }
        let fitSample = try require(reference.cases.first { $0.id == (options.alternative ? "wide-number-hang6" : "wide-number-hang18") }, "Fitting source missing")
        let fitSlide = try deck.slides.add()
        func caption(_ value: String, x: Double, y: Double, width: Double, size: Double) throws {
            let shape = try text(value, on: fitSlide, in: .init(x: .points(x), y: .points(y), width: .points(width), height: .points(60)))
            shape.textFrame?.paragraphs.first?.runs.first?.fontSize = size
        }
        try caption("List markers and hanging indents", x: 30, y: 28, width: 650, size: 26)
        try caption("The first four slides retain 24 native specimens. This slide compares computed fits in smaller frames.", x: 30, y: 90, width: 650, size: 16)
        var selections: [Autofit] = []
        var layouts: [[RichTextLine]] = []
        var fitBodies: [String: String] = [:]
        for (index, role) in ["Shape.fitText", "TextFrame.fitText"].enumerated() {
            let x = index == 0 ? 80.0 : 400.0
            let frame = Rect(x: .points(x), y: .points(250), width: .points(130), height: .points(45))
            try fitSlide.shapes.addShape(.rectangle, frame: frame, fill: .none, line: Line(color: Color("276D89")))
            let box = try fitSlide.shapes.addTextBox(frame)
            box.name = role + " marker copy"
            let body = try paragraphBody(deck, named: box.name, slideAt: 4)
            body.children = try XML.parse(Data(fitSample.textBodyXML.utf8)).children
            fitSlide.part.markDirty()
            let textFrame = try require(box.textFrame, "Marker text frame missing")
            let fit = index == 0 ? try require(box.fitText(fonts: deck.fonts, theme: deck.theme), "Marker shape fit missing")
                : textFrame.fitText(in: frame, fonts: deck.fonts, theme: deck.theme)
            let measured = try paragraphGeometry(deck, named: box.name, slideAt: 4)
            selections.append(fit); layouts.append(measured.lines)
            fitBodies[box.name] = body.serialized()
            try caption(role, x: x, y: 195, width: 260, size: 18)
            try caption("Computed: \(fit.fontScale)% / \(fit.lineSpacingReduction)% line reduction", x: x, y: 335, width: 260, size: 14)
        }
        try caption("Source: " + fitSample.id + "\nBoth copies keep the source paragraph and run properties. Computed fitting is not a claim about PowerPoint's chosen autofit scale.", x: 30, y: 450, width: 650, size: 15)
        try caption("Native references cover separate marker and body sizes, percentage and explicit sizes, actual bold numbering, inherited choices, three absent markers, and continuation lines returning to the paragraph margin.", x: 30, y: 560, width: 650, size: 15)
        var checks = try markerNativeChecks(deck, reference: reference)
        checks.append(.init("Marker public fits agree", selections.count == 2 && selections[0] == selections[1]
            && selections.allSatisfy(\.fits) && layouts[0] == layouts[1]
            && layouts.allSatisfy { $0.allSatisfy { $0.visibleWidth <= 130 } },
            "Both public APIs compute the same fit in 130 by 45 pt copies; original native specimens are untouched."))
        let saved = try deck.serializedData()
        let svgs = try (0..<5).map { try deck.renderSVG(slideAt: $0) }
        checks.append(.init("Marker rendering is read-only", try deck.serializedData() == saved,
                            "Rendering and native comparisons preserve package content."))
        return LibraryLabDraft(deck: deck, before: before, checks: checks,
            extraFiles: ["native-marker-reference.json": referenceData], verify: { reopened in
                reopened.registerEmbeddedFonts()
                var result = try markerNativeChecks(reopened, reference: reference, prefix: "Saved ")
                let bodiesPreserved = try reference.cases.allSatisfy { sample in
                    let shape = try require(reopened.slides[sample.slide].shapes.first { $0.name == sample.id }, "Saved marker specimen missing")
                    let body = try paragraphBody(reopened, named: sample.id, slideAt: sample.slide).serialized()
                    return shape.frame == sample.frame && body == originalBodies[sample.id]
                }
                let fitPreserved = try fitBodies.allSatisfy { name, body in
                    try paragraphBody(reopened, named: name, slideAt: 4).serialized() == body
                }
                let reopenedSVGs = try (0..<5).map { try reopened.renderSVG(slideAt: $0) }
                let reopenedMasters = try (0..<4).map { try reopened.slides[$0].master?.part.uri }
                result.append(.init("Marker bodies and inheritance survive", bodiesPreserved && fitPreserved && sourceMasters == reopenedMasters && sourceMasters[0] != sourceMasters[3], "Every specimen retains its frame, original XML and distinct imported master binding; computed settings survive."))
                let reopenedBytes = try reopened.serializedData()
                result.append(.init("Marker fonts and SVG survive", faces.allSatisfy { reopened.fonts.data(for: $0.0) == $0.1 } && reopenedSVGs == svgs && reopenedBytes == saved, "All three actual font faces and every rendered page survive reopening without mutation."))
                return result
            })
    }

    static func markerNativeChecks(_ deck: Presentation, reference: ListMarkerReferences, prefix: String = "") throws -> [LibraryLabCheck] {
        let before = try deck.serializedData()
        let rendered = try (0..<4).map { try deck.renderSVGReportingProblems(slideAt: $0) }
        let aliases = rendered.map { markerFaceAliases(svg: $0.svg, fonts: deck.fonts) }
        var checks = reference.cases.map { sample in
            LibraryLabCheck(prefix + "Native list marker: " + sample.id,
                markerGlyphsMatch(svg: rendered[sample.slide].svg, sample: sample, aliases: aliases[sample.slide]),
                "All marker/body glyphs and explicit omissions: x within 0.06 pt, baseline within 0.121 pt, paint and outline dimensions within 0.002 pt; no glyph stretching.")
        }
        let after = try deck.serializedData()
        checks.append(.init(prefix + "Marker native corpus complete", reference.cases.count == 24
            && Set(reference.cases.map(\.id)).count == 24
            && reference.cases.reduce(0) { $0 + $1.glyphs.count } == 277
            && reference.cases.reduce(0) { $0 + $1.omittedMarkers.count } == 3
            && rendered.allSatisfy { $0.problems.isEmpty } && after == before,
            "24 cases, 277 visible glyphs and three explicitly absent markers; original rendering has no findings and leaves the DOM unchanged."))
        return checks
    }

    static func markerFaceAliases(svg: String, fonts: FontLibrary) -> [String: String] {
        let faces: [(String, FontFaceKey)] = [("regular", .init(family: "DejaVu Sans")), ("bold", .init(family: "DejaVu Sans", bold: true)), ("serif", .init(family: "DejaVu Serif"))]
        guard let regex = try? NSRegularExpression(pattern: "@font-face\\{font-family:'([^']+)'[^}]*base64,([^)]*)") else { return [:] }
        let source = svg as NSString
        var aliases: [String: String] = [:]
        for match in regex.matches(in: svg, range: NSRange(location: 0, length: source.length)) {
            guard let bytes = Data(base64Encoded: source.substring(with: match.range(at: 2))),
                  let face = faces.first(where: { fonts.data(for: $0.1) == bytes }) else { continue }
            aliases[source.substring(with: match.range(at: 1))] = face.0
        }
        return aliases
    }

    static func markerGlyphsMatch(svg: String, sample: ListMarkerReferences.Sample, aliases: [String: String]) -> Bool {
        guard let root = try? XML.parse(Data(svg.utf8)) else { return false }
        var consumed = 0
        var bodyLines: [String] = []
        for node in DrawingLabFixtures.nodes(root, "text") {
            guard let transform = node[attribute: "transform"], transform.hasPrefix("translate(") else { continue }
            let values = transform.components(separatedBy: CharacterSet(charactersIn: "(), ")).compactMap(Double.init)
            guard values.count == 3, values[2] == Double(EMU.perPoint), abs(values[0] / Double(EMU.perPoint) - sample.x) < 0.001 else { continue }
            let baseline = values[1] / Double(EMU.perPoint) - sample.y
            guard baseline >= 0, baseline <= sample.height else { continue }
            var bodyText = ""
            for span in node.children(named: "tspan") {
                let scalars = Array(span.textContent.unicodeScalars)
                guard span[attribute: "textLength"] == nil, span[attribute: "lengthAdjust"] == nil,
                      let size = span[attribute: "font-size"].flatMap(Double.init),
                      let positions = span[attribute: "x"]?.split(whereSeparator: { $0.isWhitespace }).compactMap({ Double($0) }), positions.count == scalars.count else { return false }
                let family = span[attribute: "font-family"] ?? ""
                let alias = family.components(separatedBy: ",").first ?? ""
                guard let face = aliases[alias], span[attribute: "font-style"] != "italic" else { return false }
                for (scalar, x) in zip(scalars, positions) where scalar.value != 32 {
                    guard consumed < sample.glyphs.count else { return false }
                    let native = sample.glyphs[consumed]
                    if consumed >= sample.markerCount { bodyText += String(scalar) }
                    consumed += 1
                    guard native.rawPDFPaintScale.count == 2, native.sourceGlyphBounds.count == 4, native.geometricInkBounds.count == 4 else { return false }
                    let bounds = native.sourceGlyphBounds, ink = native.geometricInkBounds
                    let width = (bounds[2] - bounds[0]) * size / 2048
                    let height = (bounds[3] - bounds[1]) * size / 2048
                    guard String(scalar) == native.text, native.matchingSourceFaces.contains(face), abs(x - native.x) < 0.06,
                          abs(baseline - native.baseline) < 0.121, native.rawPDFPaintScale.allSatisfy({ abs(size - $0) < 0.002 }),
                          abs(width - (ink[2] - ink[0])) < 0.002, abs(height - (ink[3] - ink[1])) < 0.002 else { return false }
                }
            }
            bodyLines.append(bodyText)
        }
        return consumed == sample.glyphs.count && bodyLines == sample.bodyLines
            && consumed + sample.omittedMarkers.count == sample.expectedVisibleScalars
    }
}
