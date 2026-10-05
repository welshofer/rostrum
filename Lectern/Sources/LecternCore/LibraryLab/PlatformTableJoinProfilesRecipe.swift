import Foundation
import Rostrum

/// A single parse per page, reused by all table specimens. Source glyph trace
/// origins are deliberately separate from the independent vector paint proof.
struct TableJoinProfilesSVGPage {
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
            return x >= sample.x - 3 && x <= sample.x + sample.width + 3 && y >= sample.y - 3 && y <= sample.y + sample.height + 3
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
        if sample.id.hasPrefix("colored-") {
            guard Self.orderedCrossingsMatch(actual: actual, native: sample.lines) else { return false }
        }
        return true
    }
    /// Geometry union alone cannot establish which color paints an overlap.
    /// Independently check every positive-area crossing in the native sequence.
    static func orderedCrossingsMatch(actual: [Stroke], native: [Stroke]) -> Bool {
        func bounds(_ line: Stroke) -> [Double] {
            let p = line.points, half = line.width / 2
            return p[0] == p[2] ? [p[0] - half, min(p[1], p[3]), p[0] + half, max(p[1], p[3])]
                : [min(p[0], p[2]), p[1] - half, max(p[0], p[2]), p[1] + half]
        }
        func paint(_ lines: [Stroke], _ x: Double, _ y: Double) -> [Double]? {
            lines.last { let b = bounds($0); return x >= b[0] && x <= b[2] && y >= b[1] && y <= b[3] }?.color
        }
        var count = 0
        for i in native.indices {
            for second in native.dropFirst(i + 1) where !same(native[i].color, second.color, 0.0001) {
                let f = bounds(native[i]), s = bounds(second)
                let l = max(f[0], s[0]), t = max(f[1], s[1]), r = min(f[2], s[2]), b = min(f[3], s[3])
                guard l < r && t < b else { continue }
                count += 1
                let x = (l + r) / 2, y = (t + b) / 2
                guard let expected = paint(native, x, y), let observed = paint(actual, x, y), same(expected, observed, 0.0001) else { return false }
            }
        }
        return count == 9
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
        for (a, b) in zip(glyphs, sample.glyphs) {
            guard a.0 == b.text, b.origin.count == 2, abs(a.1 - b.origin[0]) < 0.025,
                  abs(a.2 - b.origin[1]) < 0.025, abs(a.3 - b.size) < 0.002, Self.same(a.4, b.color, 0.0001) else { return false }
        }
        return true
    }
}

extension PlatformLabRecipes {
    static func tableJoinProfilesReferences() throws -> TableDefaultsReferences {
        try JSONDecoder().decode(TableDefaultsReferences.self, from: resource("TableJoinProfilesReferences", "json"))
    }
    static func tableJoinProfilesChecks(_ deck: Presentation, reference: TableDefaultsReferences, prefix: String = "") throws -> [LibraryLabCheck] {
        let rendered = try (0..<2).map { try deck.renderSVGReportingProblems(slideAt: $0) }
        let pages = try rendered.map { try TableJoinProfilesSVGPage(svg: $0.svg, fonts: deck.fonts) }
        var checks: [LibraryLabCheck] = []
        for sample in reference.cases {
            checks.append(.init(prefix + "Native profile vectors: " + sample.id, pages[sample.slide].vectorsMatch(sample), "All intervals within .001 pt and RGB .0001; colored cases additionally verify nine native crossing paint orders."))
            checks.append(.init(prefix + "Native profile glyphs: " + sample.id, pages[sample.slide].glyphsMatch(sample), "Exact embedded regular face and scalar text; all trace origins within .025 pt and size .002 pt. No outline-ink claim."))
        }
        checks.append(.init(prefix + "Join profile corpus complete", reference.cases.count == 8 && reference.cases.reduce(0) { $0 + $1.glyphs.count } == 112 && rendered.allSatisfy { $0.problems.isEmpty }, "Eight native tables and 112 glyph traces on two pages; nine ordered crossings in each colored specimen."))
        return checks
    }
    static func tableJoinProfiles(_ options: LibraryLabOptions) throws -> LibraryLabDraft {
        let referenceData = try resource("TableJoinProfilesReferences", "json"), reference = try tableJoinProfilesReferences()
        let deck = try Presentation(data: resource("native-table-joins18-v1", "pptx"))
        let before = try deck.serializedData()
        let originalNodes = try reference.cases.map { try tableDefaultsSpecimen(deck, sample: $0).serialized() }
        let masters = try (0..<2).map { try deck.slides[$0].master?.part.uri }
        deck.registerEmbeddedFonts()
        let font = try require(deck.fonts.data(for: .init(family: "DejaVu Sans")), "Table profile font missing")
        let names = Set(reference.cases.map(\.id))
        for slide in deck.slides { for shape in slide.shapes where !names.contains(shape.name) {
            for p in shape.textFrame?.paragraphs ?? [] { for r in p.runs { r.fontName = "DejaVu Sans" } }
        } }
        let slide = try deck.slides.add()
        func caption(_ value: String, y: Double, size: Double = 18, height: Double = 80) throws {
            let shape = try text(value, on: slide, in: .init(x: .points(30), y: .points(y), width: .points(660), height: .points(height)))
            for p in shape.textFrame?.paragraphs ?? [] { for r in p.runs { r.fontSize = size } }
        }
        try caption("Table join profiles", y: 25, size: 28)
        try caption("The first two pages preserve native specimens. These three tables use public direction, border and merge APIs. The option changes only the right table.", y: 95)
        for index in 0..<3 {
            let table = try slide.shapes.addTable(rows: 2, columns: 2, frame: .init(x: .points(Double(30 + 240 * index)), y: .points(250), width: .points(180), height: .points(160)))
            let frame = try require(slide.shapes.all.compactMap { $0 as? TableFrame }.last, "Public table missing")
            frame.name = ["Public RTL control", "Public axis-color control", "Public merge control"][index]
            table.styleID = nil
            table.columnWidths([.points(70), .points(110)]).rowHeights([.points(60), .points(100)])
            table.rightToLeft = index == 0
            for row in 0..<2 { for column in 0..<2 {
                let cell = try table.cell(row, column)
                cell.setText("Agjp", style: .init(font: "DejaVu Sans", sizePt: 14.5, weight: 400, trackingPt: 0, lineHeight: 1, color: Color("000000")), align: .center)
                for (edge, width) in zip([TableCellBorder.left, .right, .top, .bottom], [1.0, 2, 3, 4]) {
                    let vertical = edge == .left || edge == .right
                    cell.setBorder(edge, line: Line(color: Color(index == 1 ? (vertical ? "CC2200" : "0044CC") : "000000"), width: .points(width)))
                }
            } }
            if index == 2 { try table.merge(row: 0, column: 0, rowSpan: options.alternative ? 2 : 1, columnSpan: options.alternative ? 1 : 2) }
        }
        try caption(options.alternative ? "Left: RTL. Center: colors by axis.\nRight: vertical merge." : "Left: RTL. Center: colors by axis.\nRight: horizontal merge.", y: 435)
        try caption("Native scope: single-color unmerged RTL; axis-uniform two-color unmerged LTR; single-color LTR merges with one orientation across the grid. Cells exceed the widest stroke; opaque solid centered borders, no diagonals.", y: 530, size: 16, height: 105)
        try caption("Combined profiles and mixed merge orientations remain outside this evidence. Custom-style default borders are a separate limitation. No universal table parity claim.", y: 640, size: 14, height: 70)
        var checks = try tableJoinProfilesChecks(deck, reference: reference)
        checks.append(.init("Public join controls applied", try tableJoinProfilesControlsMatch(deck, alternative: options.alternative), "The third page retains live RTL, axis-color borders and the selected merge topology."))
        let bytes = try deck.serializedData(), svgs = try (0..<3).map { try deck.renderSVG(slideAt: $0) }
        checks.append(.init("Join rendering leaves source unchanged", try deck.serializedData() == bytes, "Rendering and native checks do not mutate the saved source."))
        return LibraryLabDraft(deck: deck, before: before, checks: checks, extraFiles: ["native-table-join-profiles-reference.json": referenceData], verify: { reopened in
            reopened.registerEmbeddedFonts()
            var result = try tableJoinProfilesChecks(reopened, reference: reference, prefix: "Saved ")
            let nodes = try reference.cases.map { try tableDefaultsSpecimen(reopened, sample: $0).serialized() }
            let currentMasters = try (0..<2).map { try reopened.slides[$0].master?.part.uri }
            result.append(.init("Join specimens and inheritance survive", nodes == originalNodes && masters == currentMasters, "Entire native table nodes, frames and master bindings survive; only outside captions use the bundled font."))
            result.append(.init("Join embedded face survives", reopened.fonts.data(for: .init(family: "DejaVu Sans")) == font, "The exact licensed regular face reopens unchanged."))
            result.append(.init("Join previews are deterministic", try (0..<3).map { try reopened.renderSVG(slideAt: $0) } == svgs, "All three saved pages reproduce identical SVG."))
            result.append(.init("Public join controls survive", try tableJoinProfilesControlsMatch(reopened, alternative: options.alternative), "Direction, merge topology and actual colored paint survive saving."))
            return result
        })
    }
    static func tableJoinProfilesControlsMatch(_ deck: Presentation, alternative: Bool) throws -> Bool {
        let tables = try ["Public RTL control", "Public axis-color control", "Public merge control"].map { name in
            try require((deck.slides[2].shapes.first { $0.name == name } as? TableFrame)?.table, "Saved public table missing")
        }
        let merged = try tables[2].mergedRegions
        let svg = try XML.parse(Data(deck.renderSVG(slideAt: 2).utf8))
        let colored = DrawingLabFixtures.nodes(svg, "line").filter {
            guard let x = $0[attribute: "x1"].flatMap(Double.init) else { return false }
            return x >= 267 * Double(EMU.perPoint) && x <= 453 * Double(EMU.perPoint)
        }
        return tables[0].rightToLeft && !tables[1].rightToLeft && !tables[2].rightToLeft
            && merged.count == 1 && merged[0].rowSpan == (alternative ? 2 : 1) && merged[0].columnSpan == (alternative ? 1 : 2)
            && !colored.isEmpty && colored.allSatisfy {
                let vertical = $0[attribute: "x1"] == $0[attribute: "x2"]
                return $0[attribute: "stroke"]?.uppercased() == (vertical ? "#CC2200" : "#0044CC")
            }
    }
}
