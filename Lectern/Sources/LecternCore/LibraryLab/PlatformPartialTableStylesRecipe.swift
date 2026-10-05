import Foundation
import Rostrum

/// A single parse per page, reused by all table specimens. Source glyph trace
/// origins are deliberately separate from the independent vector paint proof.
struct PartialTableStylesSVGPage {
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
        if let first = sample.lines.first, !sample.lines.allSatisfy({ Self.same($0.color, first.color, 0.0001) }) {
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
        return count > 0
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
    static func partialTableStylesReferences() throws -> TableDefaultsReferences {
        try JSONDecoder().decode(TableDefaultsReferences.self, from: resource("PartialTableStylesReferences", "json"))
    }
    static func partialTableStylesChecks(_ deck: Presentation, reference: TableDefaultsReferences, prefix: String = "") throws -> [LibraryLabCheck] {
        let rendered = try (0..<2).map { try deck.renderSVGReportingProblems(slideAt: $0) }
        let pages = try rendered.map { try PartialTableStylesSVGPage(svg: $0.svg, fonts: deck.fonts) }
        var result: [LibraryLabCheck] = []
        for sample in reference.cases {
            result.append(.init(prefix + "Native partial-style paint: " + sample.id, pages[sample.slide].vectorsMatch(sample), "All fills and border intervals within .001 pt / RGB .0001, preserving different-color crossing order."))
            result.append(.init(prefix + "Native partial-style glyphs: " + sample.id, pages[sample.slide].glyphsMatch(sample), "Exact embedded face and scalar text. Native trace x .025 pt, y .121 pt (print-grid residual), size .002 pt; not outline ink."))
        }
        let intervals = reference.cases.reduce(0) { $0 + (PartialTableStylesSVGPage.canonical($1.lines)?.count ?? -100) }
        result.append(.init(prefix + "Partial-style corpus complete", reference.cases.count == 12 && reference.cases.reduce(0) { $0 + $1.glyphs.count } == 72 && intervals == 49 && reference.cases.reduce(0) { $0 + $1.fills.count } == 15 && rendered.allSatisfy { $0.problems.isEmpty }, "Twelve native tables, 72 glyphs, 49 border intervals and 15 fills on two pages."))
        result.append(.init(prefix + "Effective and authored style reads stay distinct", try partialTableStyleReadsMatch(deck), "Referenced and inline missing edges resolve to black 1 pt without materializing cell edges; present empty/noFill and direct paint remain distinct."))
        return result
    }
    static func partialTableStyleDefinitions(_ deck: Presentation) throws -> [String: String] {
        let part = try deck.package.mainDocumentPart().related(by: RelType.tableStyles, in: deck.package)
        let root = try part.dom()
        // Native fixture definitions use ns0, while authored controls use a.
        // Resolve the namespace instead of assuming a particular XML prefix.
        return Dictionary(uniqueKeysWithValues: root.childElements.compactMap { node -> (String, String)? in
            let components = node.name.split(separator: ":", omittingEmptySubsequences: false)
            guard components.last == "tblStyle", components.count <= 2 else { return nil }
            let declaration = components.count == 2 ? "xmlns:" + components[0] : "xmlns"
            guard (node[attribute: declaration] ?? root[attribute: declaration]) == "http://schemas.openxmlformats.org/drawingml/2006/main",
                  let id = node[attribute: "styleId"] else { return nil }
            return (id, node.serialized())
        })
    }
    static func partialTableStyleReadsMatch(_ deck: Presentation) throws -> Bool {
        func table(_ name: String, page: Int = 0) throws -> Table {
            try require((deck.slides[page].shapes.first { $0.name == name } as? TableFrame)?.table, "Partial style specimen missing")
        }
        for (name, page) in [("absent-cell-style", 0), ("empty-cell-style", 0), ("empty-cell-borders", 0), ("referenced-fill-only", 0), ("inline-fill-only", 1)] {
            let value = try table(name, page: page), cell = try value.cell(0, 0)
            let resolver = TableStyleResolver(table: value, theme: deck.theme)
            for edge in [TableCellBorder.left, .right, .top, .bottom] {
                let line = try resolver.border(edge, row: 0, column: 0)
                guard cell.border(edge) == nil, line?.color == Color("000000"), line?.width == .points(1), line?.isNone == false else { return false }
            }
        }
        let emptyTable = try table("style-empty-left-line")
        let empty = try TableStyleResolver(table: emptyTable, theme: deck.theme).border(.left, row: 0, column: 0)
        let none = try table("style-left-noFill", page: 1)
        let direct = try table("fill-direct-left", page: 1)
        return try empty != nil && empty?.width == nil && empty?.color == nil && empty?.isNone == false
            && (TableStyleResolver(table: none, theme: deck.theme).border(.left, row: 0, column: 0)?.isNone == true)
            && (direct.cell(0, 0).border(.left)?.width == .points(4))
            && (TableStyleResolver(table: direct, theme: deck.theme).border(.left, row: 0, column: 0)?.color == Color("0044CC"))
    }
    static func partialTableStyles(_ options: LibraryLabOptions) throws -> LibraryLabDraft {
        let referenceData = try resource("PartialTableStylesReferences", "json"), reference = try partialTableStylesReferences()
        let deck = try Presentation(data: resource("native-table-style-fallback19-v1", "pptx"))
        let before = try deck.serializedData()
        let originalNodes = try reference.cases.map { try tableDefaultsSpecimen(deck, sample: $0).serialized() }
        let originalStyles = try partialTableStyleDefinitions(deck)
        let masters = try (0..<2).map { try deck.slides[$0].master?.part.uri }
        deck.registerEmbeddedFonts()
        let font = try require(deck.fonts.data(for: .init(family: "DejaVu Sans")), "Partial style font missing")
        let names = Set(reference.cases.map(\.id))
        for slide in deck.slides { for shape in slide.shapes where !names.contains(shape.name) {
            for p in shape.textFrame?.paragraphs ?? [] { for r in p.runs { r.fontName = "DejaVu Sans" } }
        } }
        let slide = try deck.slides.add()
        func caption(_ value: String, x: Double = 30, y: Double, width: Double = 660, size: Double = 18, height: Double = 70) throws {
            let shape = try text(value, on: slide, in: .init(x: .points(x), y: .points(y), width: .points(width), height: .points(height)))
            for p in shape.textFrame?.paragraphs ?? [] { for r in p.runs { r.fontSize = size } }
        }
        try caption("Partial table styles", y: 25, size: 28)
        try caption("Missing edges inherit black 1 pt from resolved custom styles. Empty lines and noFill suppress an edge. Direct cell borders override the style.", y: 95)
        for index in 0..<4 {
            let x = index % 2 == 0 ? 30.0 : 390.0, y = index < 2 ? 190.0 : 410.0
            let table = try slide.shapes.addTable(rows: 1, columns: 1, frame: .init(x: .points(x), y: .points(y), width: .points(290), height: .points(120)))
            let frame = try require(slide.shapes.all.compactMap { $0 as? TableFrame }.last, "Public partial-style table missing")
            frame.name = "Public partial-style control \(index)"
            let left = index == 1 ? "<a:left><a:ln/></a:left>" : index == 2 ? "<a:left><a:ln><a:noFill/></a:ln></a:left>" : ""
            let id = "{19000000-0000-4000-9000-00000000010\(index)}"
            let definition = try XML.parse(Data("<a:tblStyle xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" styleId=\"\(id)\" styleName=\"Lectern partial style \(index)\"><a:wholeTbl><a:tcStyle><a:tcBdr>\(left)</a:tcBdr><a:fill><a:solidFill><a:srgbClr val=\"CC44AA\"/></a:solidFill></a:fill></a:tcStyle></a:wholeTbl></a:tblStyle>".utf8))
            try table.setStyleDefinition(definition)
            let cell = try table.cell(0, 0)
            cell.setText("Agjp", style: .init(font: "DejaVu Sans", sizePt: 18, weight: 400, trackingPt: 0, lineHeight: 1, color: Color("000000")), align: .center)
            cell.setPadding(left: .points(12), top: .points(12), right: .points(12), bottom: .points(12))
            if index == 3 {
                cell.setBorder(.left, line: Line(color: Color("0044CC"), width: .points(4)))
                cell.setBorder(.right, line: nil)
                if options.alternative { cell.clearBorder(.left) }
            }
        }
        try caption("Referenced fill-only style:\nall four edges inherit black 1 pt.", y: 325, width: 290, size: 16)
        try caption("Present empty left line:\nleft edge stays unpainted.", x: 390, y: 325, width: 290, size: 16)
        try caption("Explicit noFill left line:\nleft edge stays unpainted.", y: 545, width: 290, size: 16)
        try caption(options.alternative ? "Direct left override cleared:\nblack 1 pt restored; right suppressed." : "Direct blue 4 pt left override:\nright edge explicitly suppressed.", x: 390, y: 545, width: 290, size: 16)
        try caption("Public controls only; native evidence is on pages 1-2. Custom resolved styles, opaque solid borders, unmerged LTR grids with constant color and width per grid line. No universal table parity claim.", y: 640, size: 14, height: 70)
        var checks = try partialTableStylesChecks(deck, reference: reference)
        checks.append(.init("Public partial-style controls applied", try partialTableStyleControlsMatch(deck, alternative: options.alternative), "Public style definitions, noFill and clear/set border calls change both effective reads and actual edge paint."))
        let bytes = try deck.serializedData(), svgs = try (0..<3).map { try deck.renderSVG(slideAt: $0) }
        checks.append(.init("Partial-style rendering leaves source unchanged", try deck.serializedData() == bytes, "Resolved border reads and rendering do not materialize authored source edges."))
        return LibraryLabDraft(deck: deck, before: before, checks: checks, extraFiles: ["native-partial-table-styles-reference.json": referenceData], verify: { reopened in
            reopened.registerEmbeddedFonts()
            var result = try partialTableStylesChecks(reopened, reference: reference, prefix: "Saved ")
            let nodes = try reference.cases.map { try tableDefaultsSpecimen(reopened, sample: $0).serialized() }
            let styles = try partialTableStyleDefinitions(reopened)
            let currentMasters = try (0..<2).map { try reopened.slides[$0].master?.part.uri }
            result.append(.init("Partial-style specimens and inheritance survive", nodes == originalNodes && masters == currentMasters && originalStyles.count == 12 && originalStyles.allSatisfy { styles[$0.key] == $0.value }, "Entire native table nodes, frames, referenced definitions, inline styles and master bindings survive; only outside captions use the bundled font."))
            result.append(.init("Partial-style embedded face survives", reopened.fonts.data(for: .init(family: "DejaVu Sans")) == font, "The exact licensed regular face reopens unchanged."))
            result.append(.init("Partial-style previews are deterministic", try (0..<3).map { try reopened.renderSVG(slideAt: $0) } == svgs, "All three saved pages reproduce identical SVG."))
            result.append(.init("Public partial-style controls survive", try partialTableStyleControlsMatch(reopened, alternative: options.alternative), "Authored/default/empty/noFill distinctions and the actual selected edge paint survive saving."))
            return result
        })
    }
    static func partialTableStyleControlsMatch(_ deck: Presentation, alternative: Bool) throws -> Bool {
        let svg = try XML.parse(Data(deck.renderSVG(slideAt: 2).utf8))
        let lines = DrawingLabFixtures.nodes(svg, "line"), fills = DrawingLabFixtures.nodes(svg, "rect")
        for index in 0..<4 {
            let table = try require((deck.slides[2].shapes.first { $0.name == "Public partial-style control \(index)" } as? TableFrame)?.table, "Saved partial-style control missing")
            let cell = try table.cell(0, 0), resolver = TableStyleResolver(table: table, theme: deck.theme)
            let left = try resolver.border(.left, row: 0, column: 0)
            let x = index % 2 == 0 ? 30.0 : 390.0, y = index < 2 ? 190.0 : 410.0
            func point(_ node: XML.Element, _ key: String) -> Double { (node[attribute: key].flatMap(Double.init) ?? .nan) / Double(EMU.perPoint) }
            let fill = fills.filter { abs(point($0, "x") - x) < 0.001 && abs(point($0, "y") - y) < 0.001 }
            guard fill.count == 1, point(fill[0], "width") == 290, point(fill[0], "height") == 120,
                  fill[0][attribute: "fill"]?.uppercased() == "#CC44AA" else { return false }
            let selected = lines.filter { point($0, "x1") >= x - 3 && point($0, "x1") <= x + 293 && point($0, "y1") >= y - 3 && point($0, "y1") <= y + 123 }
            guard selected.count == (index == 0 ? 4 : 3) else { return false }
            let leftPaint = selected.filter { abs(point($0, "x1") - x) < 0.001 && abs(point($0, "x2") - x) < 0.001 }
            switch index {
            case 0:
                guard cell.border(.left) == nil, left?.color == Color("000000"), left?.width == .points(1), leftPaint.count == 1, point(leftPaint[0], "stroke-width") == 1, leftPaint[0][attribute: "stroke"]?.uppercased() == "#000000" else { return false }
            case 1:
                guard cell.border(.left) == nil, left != nil, left?.color == nil, left?.width == nil, left?.isNone == false, leftPaint.isEmpty else { return false }
            case 2:
                guard cell.border(.left) == nil, left?.isNone == true, leftPaint.isEmpty else { return false }
            default:
                guard cell.border(.right)?.isNone == true, leftPaint.count == 1,
                      (cell.border(.left) == nil) == alternative,
                      left?.width == .points(alternative ? 1 : 4), left?.color == Color(alternative ? "000000" : "0044CC"),
                      point(leftPaint[0], "stroke-width") == (alternative ? 1 : 4),
                      leftPaint[0][attribute: "stroke"]?.uppercased() == (alternative ? "#000000" : "#0044CC") else { return false }
            }
            for line in selected where !leftPaint.contains(where: { $0 === line }) {
                guard point(line, "stroke-width") == 1, line[attribute: "stroke"]?.uppercased() == "#000000" else { return false }
            }
        }
        return true
    }
}
