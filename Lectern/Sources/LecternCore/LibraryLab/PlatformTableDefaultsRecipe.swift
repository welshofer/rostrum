import Foundation
import Rostrum

struct TableDefaultsReferences: Decodable {
    struct Fill: Decodable { let bounds: [Double]; let color: [Double]; let opacity: Double }
    struct Stroke: Decodable { var points: [Double]; let color: [Double]; let opacity: Double; let width: Double }
    struct Glyph: Decodable { let text: String; let origin: [Double]; let size: Double; let color: [Double] }
    struct Sample: Decodable {
        let id: String; let slide: Int; let sourceGroup: String; let source: String
        let x: Double; let y: Double; let width: Double; let height: Double
        let fills: [Fill]; let lines: [Stroke]; let glyphs: [Glyph]
    }
    struct Source: Decodable {
        let group: String; let source: String; let sourceSHA256: String
        let nativePDFSHA256: String; let fontSHA256: String; let fixture: String
    }
    let scope: String; let sources: [Source]; let cases: [Sample]
}

/// A single parse per page, reused by all table specimens. Source glyph trace
/// origins are deliberately separate from the independent vector paint proof.
struct TableDefaultsSVGPage {
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
        // Different colors can overlap at corners. Preserve the captured paint
        // order rather than using interval sorting to erase ownership changes.
        if let first = sample.lines.first, !sample.lines.allSatisfy({ Self.same($0.color, first.color, 0.0001) }) {
            guard actual.count == sample.lines.count,
                  zip(actual, sample.lines).allSatisfy({ Self.same($0.points, $1.points, 0.001) && Self.same($0.color, $1.color, 0.0001) }) else { return false }
        }
        return true
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
        for (i, pair) in zip(glyphs, sample.glyphs).enumerated() {
            let (a, b) = pair
            // Every captured cell contains one unwrapped "Agjp". A terminal
            // p marks the next cell's first scalar, not a general line-break rule.
            let first = i == 0 || sample.glyphs[i - 1].text == "p"
            guard a.0 == b.text, b.origin.count == 2, abs(a.1 - b.origin[0]) < (first ? 0.025 : 0.06),
                  abs(a.2 - b.origin[1]) < 0.121, abs(a.3 - b.size) < 0.002, Self.same(a.4, b.color, 0.0001) else { return false }
        }
        return true
    }
}

extension PlatformLabRecipes {
    static func tableDefaultsReferences() throws -> TableDefaultsReferences {
        try JSONDecoder().decode(TableDefaultsReferences.self, from: resource("TableDefaultsReferences", "json"))
    }
    static func tableDefaultsSpecimen(_ deck: Presentation, sample: TableDefaultsReferences.Sample, slideIndex: Int? = nil) throws -> XML.Element {
        let tree = try require(deck.slides[slideIndex ?? sample.slide].part.dom().firstChild(named: "p:cSld")?.firstChild(named: "p:spTree"), "Table source tree missing")
        return try require(tree.children(named: "p:graphicFrame").first {
            $0.firstChild(named: "p:nvGraphicFramePr")?.firstChild(named: "p:cNvPr")?[attribute: "name"] == sample.id
        }, "Table specimen missing: " + sample.id)
    }
    static func tableDefaultsChecks(_ deck: Presentation, reference: TableDefaultsReferences, prefix: String = "") throws -> [LibraryLabCheck] {
        let rendered = try (0..<3).map { try deck.renderSVGReportingProblems(slideAt: $0) }
        let pages = try rendered.map { try TableDefaultsSVGPage(svg: $0.svg, fonts: deck.fonts) }
        var result: [LibraryLabCheck] = []
        for sample in reference.cases {
            result.append(.init(prefix + "Native table vectors: " + sample.id, pages[sample.slide].vectorsMatch(sample), "Native fills and opaque border intervals: geometry .001 pt, RGB .0001; only identical touching collinear strokes coalesce."))
            result.append(.init(prefix + "Native table glyphs: " + sample.id, pages[sample.slide].glyphsMatch(sample), "Exact regular face and scalar text, native trace origins/size; no trace-bounds-as-ink claim."))
        }
        result.append(.init(prefix + "Table native corpus complete", reference.cases.count == 12 && reference.cases.reduce(0) { $0 + $1.glyphs.count } == 72 && rendered.allSatisfy { $0.problems.isEmpty }, "Three source pages retain 12 native cases and 72 visible glyphs."))
        return result
    }
    static func tableDefaults(_ options: LibraryLabOptions) throws -> LibraryLabDraft {
        let referenceData = try resource("TableDefaultsReferences", "json"), reference = try tableDefaultsReferences()
        let sources = try reference.sources.map { try Presentation(data: resource(String($0.source.dropLast(5)), "pptx")) }
        let originalNodes = try reference.cases.map { try tableDefaultsSpecimen(sources[$0.slide], sample: $0, slideIndex: 0).serialized() }
        let before = try sources[0].serializedData(), deck = sources[0]
        // The incoming custom deck has a different insertion default. Import
        // must preserve omitted applied styles, not materialize either default.
        _ = try deck.slides.importAll(from: sources[1])
        _ = try deck.slides.importAll(from: sources[2])
        deck.registerEmbeddedFonts()
        let masters = try (0..<3).map { try deck.slides[$0].master?.part.uri }
        let font = try require(deck.fonts.data(for: .init(family: "DejaVu Sans")), "Table font missing")
        let names = Set(reference.cases.map(\.id))
        for slide in deck.slides { for shape in slide.shapes where !names.contains(shape.name) {
            for p in shape.textFrame?.paragraphs ?? [] { for r in p.runs { r.fontName = "DejaVu Sans" } }
        } }
        let slide = try deck.slides.add()
        func caption(_ value: String, y: Double, size: Double = 18, height: Double = 70) throws {
            let shape = try text(value, on: slide, in: .init(x: .points(30), y: .points(y), width: .points(660), height: .points(height)))
            for p in shape.textFrame?.paragraphs ?? [] { for r in p.runs { r.fontSize = size } }
        }
        try caption("Table defaults and border joins", y: 25, size: 28)
        try caption("The first three pages preserve native specimens. Import keeps a missing applied style missing, even when the destination has a different default.", y: 90)
        let frame = Rect(x: .points(30), y: .points(220), width: .points(290), height: .points(160))
        let table = try slide.shapes.addTable(rows: 1, columns: 1, frame: frame)
        let control = try require(slide.shapes.all.compactMap { $0 as? TableFrame }.last, "Authored table missing")
        control.name = "Public style control"
        let styleID = "{8F99A113-2340-4B62-9876-112233445517}"
        let definition = try XML.parse(Data("<a:tblStyle xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" styleId=\"\(styleID)\" styleName=\"Lectern explicit control\"><a:wholeTbl><a:tcStyle><a:fill><a:solidFill><a:srgbClr val=\"CC44AA\"/></a:solidFill></a:fill></a:tcStyle></a:wholeTbl></a:tblStyle>".utf8))
        try table.setStyleDefinition(definition)
        if options.alternative { table.styleID = nil }
        let cell = try table.cell(0, 0)
        cell.setText("Agjp", style: .init(font: "DejaVu Sans", sizePt: 20, weight: 400, trackingPt: 0, lineHeight: 1, color: Color("000000")), align: .left)
        cell.setPadding(left: .points(12), top: .points(12), right: .points(12), bottom: .points(12))
        let joins = try slide.shapes.addTable(rows: 1, columns: 1, frame: .init(x: .points(380), y: .points(220), width: .points(290), height: .points(160)))
        joins.styleID = nil
        let joined = try joins.cell(0, 0)
        joined.setText("Agjp", style: .init(font: "DejaVu Sans", sizePt: 20, weight: 400, trackingPt: 0, lineHeight: 1, color: Color("000000")), align: .left)
        for (edge, width) in zip([TableCellBorder.left, .right, .top, .bottom], [1.0, 2, 3, 4]) {
            joined.setBorder(edge, line: Line(color: Color("000000"), width: .points(width)))
        }
        try caption(options.alternative ? "Left: applied style cleared with styleID = nil.\nRight: public unequal opaque solid borders." : "Left: custom style explicitly applied.\nRight: public unequal opaque solid borders.", y: 405)
        try caption("A style-list default is an insertion choice. It is not an applied table style. Direct formatting remains effective when the style is absent.", y: 490)
        try caption("Native join scope: rectangular unmerged LTR tables with cell dimensions larger than the widest stroke, opaque solid borders and no diagonals. Multiple cells use one border color. Other profiles retain their existing limitations; no universal table parity claim.", y: 585, size: 15, height: 100)
        var checks = try tableDefaultsChecks(deck, reference: reference)
        checks += try tableDefaultsImportChecks(deck)
        checks.append(.init("Public style changes actual paint", try tableDefaultsControlMatches(deck, alternative: options.alternative), "The authored table actually paints the explicit custom fill, or no cell fill after clearing its applied style."))
        checks.append(.init("Public table style option applied", table.styleID == (options.alternative ? nil : styleID), "The option changes the actual applied table style through its public setter."))
        let bytes = try deck.serializedData(), svgs = try (0..<4).map { try deck.renderSVG(slideAt: $0) }
        checks.append(.init("Table rendering leaves source unchanged", try deck.serializedData() == bytes, "Inspection and native checks do not mutate the saved source."))
        return LibraryLabDraft(deck: deck, before: before, checks: checks, extraFiles: ["native-table-defaults-reference.json": referenceData], verify: { reopened in
            reopened.registerEmbeddedFonts()
            var result = try tableDefaultsChecks(reopened, reference: reference, prefix: "Saved ")
            result += try tableDefaultsImportChecks(reopened)
            let nodes = try reference.cases.map { try tableDefaultsSpecimen(reopened, sample: $0).serialized() }
            let currentMasters = try (0..<3).map { try reopened.slides[$0].master?.part.uri }
            result.append(.init("Table specimens and inheritance survive", nodes == originalNodes && masters == currentMasters, "All entire native table nodes, frames and master bindings survive; outside captions alone use the bundled font."))
            result.append(.init("Table embedded face survives", reopened.fonts.data(for: .init(family: "DejaVu Sans")) == font, "The exact licensed regular face reopens unchanged."))
            result.append(.init("Table previews are deterministic", try (0..<4).map { try reopened.renderSVG(slideAt: $0) } == svgs, "All four saved pages reproduce identical SVG."))
            let recovered = try require((reopened.slides[3].shapes.first { $0.name == "Public style control" } as? TableFrame)?.table, "Saved control missing")
            result.append(.init("Public table style survives", try recovered.styleID == (options.alternative ? nil : styleID) && tableDefaultsControlMatches(reopened, alternative: options.alternative), "The selected applied/absent style survives saving."))
            return result
        })
    }
    static func tableDefaultsControlMatches(_ deck: Presentation, alternative: Bool) throws -> Bool {
        let svg = try XML.parse(Data(deck.renderSVG(slideAt: 3).utf8))
        let fills = DrawingLabFixtures.nodes(svg, "rect").filter {
            $0[attribute: "x"].flatMap(Double.init) == 30 * Double(EMU.perPoint)
                && $0[attribute: "y"].flatMap(Double.init) == 220 * Double(EMU.perPoint)
        }
        return alternative ? fills.isEmpty : fills.count == 1 && fills[0][attribute: "fill"]?.uppercased() == "#CC44AA"
    }
    static func tableDefaultsImportChecks(_ deck: Presentation) throws -> [LibraryLabCheck] {
        let main = try deck.package.mainDocumentPart()
        let styles = try main.related(by: RelType.tableStyles, in: deck.package).dom()
        let custom = try require((deck.slides[1].shapes.first { $0.name == "custom-absent" } as? TableFrame)?.table, "Imported absent table missing")
        let direct = try require((deck.slides[1].shapes.first { $0.name == "custom-absent-direct" } as? TableFrame)?.table, "Imported direct table missing")
        return [.init("Import keeps absent style with different destination default", custom.styleID == nil && direct.styleID == nil && styles[attribute: "def"] == "{5C22544A-7EE6-4342-B048-85BDC9FD1C3A}", "The source custom default differs from the retained built-in destination default; both imported omitted style IDs remain absent and native paint checks verify their appearance.")]
    }
}
