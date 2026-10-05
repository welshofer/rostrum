import Foundation
import Rostrum

/// A single parse per page, reused by all table specimens. Source glyph trace
/// origins are deliberately separate from the independent vector paint proof.
struct TableTransitionsSVGPage {
    typealias Stroke = TableDefaultsReferences.Stroke
    private let rects: [XML.Element]
    private let lines: [XML.Element]
    private let texts: [XML.Element]
    private let aliases: [String: String]
    private let supportedTransforms: Bool
    init(svg: String, fonts: FontLibrary) throws {
        let root = try XML.parse(Data(svg.utf8))
        rects = DrawingLabFixtures.nodes(root, "rect")
        lines = DrawingLabFixtures.nodes(root, "line")
        texts = DrawingLabFixtures.nodes(root, "text")
        aliases = PlatformLabRecipes.markerFaceAliases(svg: svg, fonts: fonts)
        supportedTransforms = DrawingLabFixtures.nodes(root, "g").allSatisfy { $0[attribute: "transform"] == nil }
            && (rects + lines).allSatisfy { $0[attribute: "transform"] == nil }
    }
    static func same(_ a: [Double], _ b: [Double], _ tolerance: Double) -> Bool {
        a.count == b.count && zip(a, b).allSatisfy { $0.isFinite && $1.isFinite && abs($0 - $1) < tolerance }
    }
    private func point(_ node: XML.Element, _ key: String) -> Double? {
        node[attribute: key].flatMap(Double.init).map { $0 / Double(EMU.perPoint) }
    }
    private func color(_ value: String?) -> [Double]? {
        guard let value, value.count == 7, value.first == "#", let n = UInt32(value.dropFirst(), radix: 16) else { return nil }
        return [Double(n >> 16), Double((n >> 8) & 255), Double(n & 255)].map { $0 / 255 }
    }
    /// Coalesce only touching, collinear, identically painted opaque segments.
    /// Gaps, overlaps, different widths/colors and opacity remain distinct.
    static func canonical(_ strokes: [Stroke]) -> [Stroke]? {
        var sorted: [Stroke] = []
        for var s in strokes {
            guard s.points.count == 4, s.color.count == 3, s.width > 0,
                  (s.points + s.color + [s.width, s.opacity]).allSatisfy(\.isFinite) else { return nil }
            let p = s.points
            guard abs(p[0] - p[2]) < 0.001 || abs(p[1] - p[3]) < 0.001 else { return nil }
            if p[0] > p[2] || (p[0] == p[2] && p[1] > p[3]) { s.points = [p[2], p[3], p[0], p[1]] }
            sorted.append(s)
        }
        func key(_ s: Stroke) -> [Double] {
            let p = s.points, v = abs(p[0] - p[2]) < 0.001
            return [v ? 1 : 0, v ? p[0] : p[1], s.width] + s.color + [s.opacity, v ? p[1] : p[0]]
        }
        sorted.sort { key($0).lexicographicallyPrecedes(key($1)) }
        var result: [Stroke] = []
        for s in sorted {
            if let p = result.last, s.opacity == 1, p.opacity == 1,
               s.color == p.color, s.width == p.width,
               same(Array(p.points.suffix(2)), Array(s.points.prefix(2)), 0.001),
               (abs(p.points[0] - p.points[2]) < 0.001) == (abs(s.points[0] - s.points[2]) < 0.001) {
                result[result.count - 1].points = [p.points[0], p.points[1], s.points[2], s.points[3]]
            } else { result.append(s) }
        }
        return result
    }
    func vectorsMatch(_ sample: TableDefaultsReferences.Sample) -> Bool {
        guard supportedTransforms else { return false }
        let selectedFills = rects.filter {
            guard let x = point($0, "x"), let y = point($0, "y") else { return false }
            return x >= sample.x - 0.001 && x < sample.x + sample.width && y >= sample.y - 0.001 && y < sample.y + sample.height
        }
        guard selectedFills.count == sample.fills.count else { return false }
        for (node, native) in zip(selectedFills, sample.fills) {
            guard let x = point(node, "x"), let y = point(node, "y"), let w = point(node, "width"), let h = point(node, "height"),
                  let c = color(node[attribute: "fill"]), Self.same([x, y, x + w, y + h], native.bounds, 0.001),
                  Self.same(c, native.color, 0.0001), (node[attribute: "fill-opacity"].flatMap(Double.init) ?? 1) == native.opacity else { return false }
        }
        let selected = lines.filter {
            guard let x = point($0, "x1"), let y = point($0, "y1") else { return false }
            return x >= sample.x - 6 && x <= sample.x + sample.width + 6 && y >= sample.y - 6 && y <= sample.y + sample.height + 6
        }
        var actual: [Stroke] = []
        for node in selected {
            let p = ["x1", "y1", "x2", "y2"].compactMap { point(node, $0) }
            guard p.count == 4, let c = color(node[attribute: "stroke"]), let width = point(node, "stroke-width"),
                  node[attribute: "stroke-dasharray"] == nil,
                  node[attribute: "stroke-linecap"] == nil || node[attribute: "stroke-linecap"] == "butt" else { return false }
            actual.append(.init(points: p, color: c, opacity: node[attribute: "stroke-opacity"].flatMap(Double.init) ?? 1, width: width))
        }
        guard let a = Self.canonical(actual), let b = Self.canonical(sample.lines), a.count == b.count else { return false }
        for (a, b) in zip(a, b) {
            guard Self.same(a.points, b.points, 0.001), Self.same(a.color, b.color, 0.0001), abs(a.width - b.width) < 0.001, a.opacity == b.opacity else { return false }
        }
        if sample.id == "merged-colored-rejection" {
            // Exact fallback sequence, deliberately not native paint acceptance.
            guard actual.count == sample.lines.count else { return false }
            for (a, b) in zip(actual, sample.lines) {
                guard a.points == b.points, a.color == b.color, a.width == b.width, a.opacity == b.opacity else { return false }
            }
        }
        return Self.orderedPaintMatches(actual: actual, expected: sample.lines)
    }
    /// Check every open rectangle from all stroke boundaries. This preserves
    /// final paint at terminals and same-axis overlaps as well as crossings.
    static func orderedPaintMatches(actual: [Stroke], expected: [Stroke]) -> Bool {
        func bounds(_ s: Stroke) -> [Double] {
            let p = s.points, h = s.width / 2
            return p[0] == p[2] ? [p[0] - h, min(p[1], p[3]), p[0] + h, max(p[1], p[3])]
                : [min(p[0], p[2]), p[1] - h, max(p[0], p[2]), p[1] + h]
        }
        guard (actual + expected).allSatisfy({ $0.opacity == 1 }) else { return false }
        let a = actual.map { (bounds($0), $0.color) }, b = expected.map { (bounds($0), $0.color) }
        let xs = Set((a + b).flatMap { [$0.0[0], $0.0[2]] }).sorted()
        let ys = Set((a + b).flatMap { [$0.0[1], $0.0[3]] }).sorted()
        func paint(_ lines: [([Double], [Double])], _ x: Double, _ y: Double) -> [Double]? {
            lines.last { x > $0.0[0] && x < $0.0[2] && y > $0.0[1] && y < $0.0[3] }?.1
        }
        for (l, r) in zip(xs, xs.dropFirst()) { for (t, btm) in zip(ys, ys.dropFirst()) {
            let x = (l + r) / 2, y = (t + btm) / 2
            switch (paint(a, x, y), paint(b, x, y)) {
            case (nil, nil): break
            case let (c?, d?): if !same(c, d, 0.0001) { return false }
            default: return false
            }
        } }
        return !expected.isEmpty
    }
    func glyphsMatch(_ sample: TableDefaultsReferences.Sample) -> Bool {
        guard supportedTransforms else { return false }
        let unsupportedPosition = ["y", "dy", "dx", "rotate", "baseline-shift", "text-anchor", "dominant-baseline", "alignment-baseline"]
        var glyphs: [(String, Double, Double, Double, [Double])] = []
        for node in texts {
            guard let transform = node[attribute: "transform"], transform.hasPrefix("translate("), transform.contains(") scale(") else { continue }
            let v = transform.components(separatedBy: CharacterSet(charactersIn: "(), ")).compactMap(Double.init)
            guard v.count == 3, v[2] == Double(EMU.perPoint) else { return false }
            let x = v[0] / Double(EMU.perPoint), y = v[1] / Double(EMU.perPoint)
            guard x >= sample.x - 0.001, x < sample.x + sample.width, y >= sample.y, y < sample.y + sample.height else { continue }
            guard node[attribute: "x"] == nil, unsupportedPosition.allSatisfy({ node[attribute: $0] == nil }) else { return false }
            for span in node.children(named: "tspan") {
                guard unsupportedPosition.allSatisfy({ span[attribute: $0] == nil }) else { return false }
                let scalars = Array(span.textContent.unicodeScalars)
                let positions = (span[attribute: "x"] ?? "").split(whereSeparator: \.isWhitespace).compactMap { Double($0) }
                let alias = (span[attribute: "font-family"] ?? "").components(separatedBy: ",").first ?? ""
                guard aliases[alias] == "regular", positions.count == scalars.count,
                      span[attribute: "textLength"] == nil, span[attribute: "lengthAdjust"] == nil,
                      span[attribute: "transform"] == nil, span[attribute: "font-style"] != "italic",
                      span[attribute: "font-weight"] == nil || span[attribute: "font-weight"] == "400",
                      let size = span[attribute: "font-size"].flatMap(Double.init), let c = color(span[attribute: "fill"]) else { return false }
                for (scalar, offset) in zip(scalars, positions) where scalar != " " { glyphs.append((String(scalar), x + offset, y, size, c)) }
            }
        }
        guard glyphs.count == sample.glyphs.count else { return false }
        // This fixture retains independently measured native print-grid y residuals.
        // S18's tighter two-axis bound remains unchanged in its own validator.
        for (a, b) in zip(glyphs, sample.glyphs) {
            guard a.0 == b.text, b.origin.count == 2, abs(a.1 - b.origin[0]) < 0.025,
                  abs(a.2 - b.origin[1]) < 0.121, abs(a.3 - b.size) < 0.002, Self.same(a.4, b.color, 0.0001) else { return false }
        }
        return true
    }
}

extension PlatformLabRecipes {
    static func tableTransitionsReferences() throws -> TableDefaultsReferences {
        try JSONDecoder().decode(TableDefaultsReferences.self, from: resource("TableTransitionsReferences", "json"))
    }
    static func tableTransitionsChecks(_ deck: Presentation, reference: TableDefaultsReferences, prefix: String = "") throws -> [LibraryLabCheck] {
        let rendered = try (0..<4).map { try deck.renderSVGReportingProblems(slideAt: $0) }
        let pages = try rendered.map { try TableTransitionsSVGPage(svg: $0.svg, fonts: deck.fonts) }
        var checks: [LibraryLabCheck] = []
        for sample in reference.cases {
            let excluded = sample.id == "merged-colored-rejection"
            checks.append(.init(prefix + (excluded ? "Excluded merged fallback: " : "Native transition paint: ") + sample.id,
                                pages[sample.slide].vectorsMatch(sample), excluded ? "Exact ordered pre-fix borders; no newly supported colored merge claim." : "Every border interval and complete ordered opaque paint subdivision match native within .001 pt and RGB .0001."))
            checks.append(.init(prefix + "Native transition glyphs: " + sample.id, pages[sample.slide].glyphsMatch(sample), "Exact face and scalar text; native trace x .025 pt, y .121 pt, size .002 pt. Not transformed outline ink."))
        }
        let admitted = reference.cases.filter { $0.id != "merged-colored-rejection" }
        checks.append(.init(prefix + "Transition corpus complete", admitted.count == 13 && reference.cases.count == 14
                            && reference.cases.reduce(0) { $0 + $1.glyphs.count } == 240
                            && admitted.reduce(0) { $0 + (TableTransitionsSVGPage.canonical($1.lines)?.count ?? -100) } == 107
                            && rendered.allSatisfy { $0.problems.isEmpty }, "Four pages, 13 admitted cases, 107 native intervals, one unchanged excluded merged control, and 240 glyph traces."))
        return checks
    }
    static func tableTransitions(_ options: LibraryLabOptions) throws -> LibraryLabDraft {
        let referenceData = try resource("TableTransitionsReferences", "json"), reference = try tableTransitionsReferences()
        let sources = try reference.sources.map { try Presentation(data: resource(String($0.source.dropLast(5)), "pptx")) }
        let nodes = try reference.cases.map { try tableDefaultsSpecimen(sources[$0.slide / 2], sample: $0, slideIndex: $0.slide % 2).serialized() }
        let deck = sources[0], before = try sources[0].serializedData()
        _ = try deck.slides.importAll(from: sources[1])
        deck.registerEmbeddedFonts()
        let font = try require(deck.fonts.data(for: .init(family: "DejaVu Sans")), "Transition face missing")
        let masters = try (0..<4).map { try deck.slides[$0].master?.part.uri }
        let names = Set(reference.cases.map(\.id))
        for slide in deck.slides { for shape in slide.shapes where !names.contains(shape.name) {
            for p in shape.textFrame?.paragraphs ?? [] { for run in p.runs { run.fontName = "DejaVu Sans" } }
        } }
        let slide = try deck.slides.add()
        func caption(_ value: String, y: Double, size: Double = 18, height: Double = 75) throws {
            let shape = try text(value, on: slide, in: .init(x: .points(30), y: .points(y), width: .points(660), height: .points(height)))
            for p in shape.textFrame?.paragraphs ?? [] { for run in p.runs { run.fontSize = size } }
        }
        try caption("Border transitions", y: 25, size: 28)
        try caption("Change color and width along a table edge. The first four pages retain native specimens; the colored merged control stays excluded.", y: 95)
        let table = try slide.shapes.addTable(rows: 2, columns: 2, frame: .init(x: .points(150), y: .points(230), width: .points(420), height: .points(220)))
        let frame = try require(slide.shapes.all.compactMap { $0 as? TableFrame }.last, "Transition control missing")
        frame.name = "Public transition control"; table.styleID = nil
        for row in 0..<2 { for column in 0..<2 {
            let cell = try table.cell(row, column)
            cell.setText("Agjp", style: .init(font: "DejaVu Sans", sizePt: 20, weight: 400, trackingPt: 0, lineHeight: 1, color: Color("000000")), align: .left)
            cell.setPadding(left: .points(14), top: .points(14), right: .points(14), bottom: .points(14))
            for edge in [TableCellBorder.left, .right] { cell.setBorder(edge, line: Line(color: Color(row == 0 ? "008800" : "CC0000"), width: .points(row == 0 ? 2 : 4))) }
            for edge in [TableCellBorder.top, .bottom] { cell.setBorder(edge, line: Line(color: Color(column == 0 ? "008800" : "CC0000"), width: .points(column == 0 ? 2 : 4))) }
        } }
        if options.alternative { try table.cell(0, 0).setBorder(.left, line: nil) }
        try caption(options.alternative ? "Upper left donor suppressed with noFill.\nOther colored edge transitions remain." : "All donors present. Green 2 pt and red 4 pt\nborders change along both grid axes.", y: 490)
        try caption("Public authoring control only, not a native fit choice. Native scope: unmerged LTR rectangles, opaque solid flat borders, agreeing adjacent declarations, and cells larger than the widest stroke. Colored merges and colored RTL remain outside this evidence.", y: 595, size: 15, height: 105)
        var checks = try tableTransitionsChecks(deck, reference: reference)
        checks.append(.init("Public transition option changes edge paint", try tableTransitionsControlMatches(deck, alternative: options.alternative), "Actual noFill/painted edge and public border reads match the selected option."))
        let bytes = try deck.serializedData(), svgs = try (0..<5).map { try deck.renderSVG(slideAt: $0) }
        checks.append(.init("Transition rendering preserves source", try deck.serializedData() == bytes, "Rendering and effective reads do not rewrite source."))
        return LibraryLabDraft(deck: deck, before: before, checks: checks, extraFiles: ["native-table-transitions-reference.json": referenceData], verify: { reopened in
            reopened.registerEmbeddedFonts()
            var result = try tableTransitionsChecks(reopened, reference: reference, prefix: "Saved ")
            let currentNodes = try reference.cases.map { try tableDefaultsSpecimen(reopened, sample: $0).serialized() }
            let currentMasters = try (0..<4).map { try reopened.slides[$0].master?.part.uri }
            result.append(.init("Transition specimens and inheritance survive", currentNodes == nodes && currentMasters == masters, "Entire fourteen table nodes and frames remain exact; outside captions alone use bundled DejaVu, so full pages are not byte-identical."))
            result.append(.init("Transition embedded face survives", reopened.fonts.data(for: .init(family: "DejaVu Sans")) == font, "Exact licensed source face bytes."))
            result.append(.init("Transition previews are deterministic", try (0..<5).map { try reopened.renderSVG(slideAt: $0) } == svgs, "All five saved SVGs remain byte-identical."))
            result.append(.init("Public transition option survives", try tableTransitionsControlMatches(reopened, alternative: options.alternative), "The authored border and actual paint reopen unchanged."))
            return result
        })
    }
    static func tableTransitionsControlMatches(_ deck: Presentation, alternative: Bool) throws -> Bool {
        let table = try require((deck.slides[4].shapes.first { $0.name == "Public transition control" } as? TableFrame)?.table, "Saved transition control missing")
        let left = try table.cell(0, 0).border(.left)
        guard alternative ? left?.isNone == true : left?.color == Color("008800") && left?.width == .points(2) else { return false }
        let svg = try XML.parse(Data(deck.renderSVG(slideAt: 4).utf8))
        func point(_ n: XML.Element, _ key: String) -> Double { (n[attribute: key].flatMap(Double.init) ?? .nan) / Double(EMU.perPoint) }
        let lines = DrawingLabFixtures.nodes(svg, "line")
        let upperLeft = lines.filter { point($0, "x1") == 150 && point($0, "x2") == 150 && point($0, "y1") < 300 }
        guard alternative ? upperLeft.isEmpty : upperLeft.count == 1 && upperLeft[0][attribute: "stroke"]?.uppercased() == "#008800" && point(upperLeft[0], "stroke-width") == 2 else { return false }
        return lines.contains { $0[attribute: "stroke"]?.uppercased() == "#CC0000" && point($0, "stroke-width") == 4 }
    }
}
