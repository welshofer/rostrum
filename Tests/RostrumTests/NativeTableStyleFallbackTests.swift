import Foundation
import Testing
@testable import Rostrum

@Suite struct NativeTableStyleFallbackTests {
    private var root: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/NativeTableStyleFallback")
    }
    private struct Line: Decodable {
        let points: [Double], color: [Double], opacity: Double, width: Double
    }
    private struct Glyph: Decodable {
        let text: String, origin: [Double], size: Double
    }
    private struct Fill: Decodable {
        let bounds: [Double], color: [Double], opacity: Double
    }
    private struct Reference: Decodable {
        let id: String, page: Int, x: Double, y: Double, width: Double, height: Double
        let lines: [Line], glyphs: [Glyph]
        let fills: [Fill]
    }
    private func read() throws -> (Presentation, [Reference]) {
        let deck = try Presentation(contentsOf: root.appendingPathComponent("native-table-style-fallback19-v1.pptx"))
        #expect(deck.registerEmbeddedFonts() == ["DejaVu Sans"])
        let references = try JSONDecoder().decode([Reference].self, from: Data(contentsOf: root.appendingPathComponent("paint-reference.json")))
        return (deck, references)
    }
    private func nodes(_ node: XML.Element, _ name: String) -> [XML.Element] {
        (node.name == name ? [node] : []) + node.childElements.flatMap { nodes($0, name) }
    }
    private func close(_ a: [Double], _ b: [Double], tolerance: Double) -> Bool {
        a.count == b.count && zip(a, b).allSatisfy { abs($0 - $1) < tolerance }
    }
    private func rgb(_ value: String?) throws -> [Double] {
        let string = try #require(value)
        let bits = try #require(UInt32(string.dropFirst(), radix: 16))
        return [Double(bits >> 16), Double((bits >> 8) & 255), Double(bits & 255)].map { $0 / 255 }
    }
    private func point(_ node: XML.Element, _ key: String) throws -> Double {
        try #require(node[attribute: key].flatMap(Double.init)) / Double(EMU.perPoint)
    }
    private func inside(_ x: Double, _ y: Double, _ reference: Reference) -> Bool {
        x >= reference.x - 6 && x <= reference.x + reference.width + 6
            && y >= reference.y - 6 && y <= reference.y + reference.height + 6
    }
    private func lines(_ svg: XML.Element, _ reference: Reference) throws -> [Line] {
        try nodes(svg, "line").compactMap { node in
            let points = try ["x1", "y1", "x2", "y2"].map { try point(node, $0) }
            guard inside(points[0], points[1], reference) else { return nil }
            return Line(points: points, color: try rgb(node[attribute: "stroke"]),
                        opacity: node[attribute: "stroke-opacity"].flatMap(Double.init) ?? 1,
                        width: try point(node, "stroke-width"))
        }
    }
    // Coalesce only adjacent identical paint. Native PDF coalesces some outer
    // strokes; preserve every distinct color, width, opacity and interval.
    private func intervals(_ lines: [Line]) -> [[Double]] {
        let values = lines.map { line -> [Double] in
            let p = line.points, vertical = p[0] == p[2]
            return [vertical ? 1 : 0, vertical ? p[0] : p[1], line.width, line.opacity]
                + line.color.map { ($0 * 255).rounded() }
                + [vertical ? p[1] : p[0], vertical ? p[3] : p[2]]
        }.sorted { $0.lexicographicallyPrecedes($1) }
        var result: [[Double]] = []
        for value in values {
            if let last = result.last, close(Array(last.prefix(7)), Array(value.prefix(7)), tolerance: 0.001),
               abs(last[8] - value[7]) < 0.001 {
                result[result.count - 1][8] = value[8]
            } else { result.append(value) }
        }
        return result
    }
    private func bounds(_ line: Line) -> [Double] {
        let p = line.points, half = line.width / 2
        return p[0] == p[2] ? [p[0] - half, p[1], p[2] + half, p[3]]
            : [p[0], p[1] - half, p[2], p[3] + half]
    }
    private func paintedColor(_ lines: [Line], x: Double, y: Double) -> [Double]? {
        lines.last { line in
            let b = bounds(line)
            return x >= b[0] && y >= b[1] && x <= b[2] && y <= b[3]
        }?.color
    }
    private func check(_ svg: XML.Element, _ reference: Reference) throws {
        #expect(nodes(svg, "g").allSatisfy { $0[attribute: "transform"] == nil })
        let actual = try lines(svg, reference)
        // Validate raw colors before byte-channel grouping, independently of
        // the finite PDF channel quantization used by the interval projection.
        for line in actual {
            #expect(reference.lines.contains { $0.width == line.width && $0.opacity == line.opacity
                && close($0.color, line.color, tolerance: 0.0001) })
        }
        let a = intervals(actual), b = intervals(reference.lines)
        #expect(a.count == b.count, "\(reference.id): complete painted intervals")
        for (first, second) in zip(a, b) {
            #expect(close(first, second, tolerance: 0.001), "\(reference.id): native interval \(first) versus \(second)")
        }
        let fills: [Fill] = try nodes(svg, "rect").compactMap { rect in
            let x = try point(rect, "x"), y = try point(rect, "y")
            let w = try point(rect, "width"), h = try point(rect, "height")
            guard inside(x, y, reference), w <= reference.width, h <= reference.height else { return nil }
            return Fill(bounds: [x, y, x + w, y + h], color: try rgb(rect[attribute: "fill"]),
                        opacity: rect[attribute: "fill-opacity"].flatMap(Double.init) ?? 1)
        }
        #expect(fills.count == reference.fills.count)
        for (observed, native) in zip(fills, reference.fills) {
            #expect(close(observed.bounds, native.bounds, tolerance: 0.001))
            #expect(close(observed.color, native.color, tolerance: 0.0001))
            #expect(observed.opacity == native.opacity)
        }
        // Compare final opaque paint on the complete rectangular subdivision,
        // retaining fill/stroke order. Every open region has constant paint.
        let actualPaint = fills + actual.map { Fill(bounds: bounds($0), color: $0.color, opacity: $0.opacity) }
        let nativePaint = reference.fills + reference.lines.map { Fill(bounds: bounds($0), color: $0.color, opacity: $0.opacity) }
        #expect((actualPaint + nativePaint).allSatisfy { $0.opacity == 1 })
        let xs = Set((actualPaint + nativePaint).flatMap { [$0.bounds[0], $0.bounds[2]] }).sorted()
        let ys = Set((actualPaint + nativePaint).flatMap { [$0.bounds[1], $0.bounds[3]] }).sorted()
        func color(_ paint: [Fill], _ x: Double, _ y: Double) -> [Double]? {
            paint.last { x > $0.bounds[0] && x < $0.bounds[2] && y > $0.bounds[1] && y < $0.bounds[3] }?.color
        }
        var completePaintMatches = true
        for (left, right) in zip(xs, xs.dropFirst()) {
            for (top, bottom) in zip(ys, ys.dropFirst()) {
                let x = (left + right) / 2, y = (top + bottom) / 2
                let observed = color(actualPaint, x, y), native = color(nativePaint, x, y)
                if let observed, let native {
                    if !close(observed, native, tolerance: 0.0001) { completePaintMatches = false }
                } else if (observed == nil) != (native == nil) { completePaintMatches = false }
            }
        }
        #expect(completePaintMatches, "\(reference.id): complete ordered opaque paint")
        var glyphs: [Glyph] = []
        for text in nodes(svg, "text") {
            guard let transform = text[attribute: "transform"] else { continue }
            let values = transform.components(separatedBy: CharacterSet(charactersIn: "(), ")).compactMap(Double.init)
            guard values.count == 3, inside(values[0] / Double(EMU.perPoint), values[1] / Double(EMU.perPoint), reference) else { continue }
            #expect(values[2] == Double(EMU.perPoint))
            for span in text.childElements {
                let xs = try #require(span[attribute: "x"]).split(separator: " ").compactMap { Double($0) }
                let scalars = Array(span.textContent.unicodeScalars)
                #expect(xs.count == scalars.count && span[attribute: "textLength"] == nil)
                let size = try #require(span[attribute: "font-size"].flatMap(Double.init))
                for (scalar, x) in zip(scalars, xs) {
                    glyphs.append(Glyph(text: String(scalar), origin: [values[0] / Double(EMU.perPoint) + x, values[1] / Double(EMU.perPoint)], size: size))
                }
            }
        }
        #expect(glyphs.count == reference.glyphs.count)
        for (actual, native) in zip(glyphs, reference.glyphs) {
            #expect(actual.text == native.text)
            #expect(abs(actual.origin[0] - native.origin[0]) < 0.025)
            // New frame positions expose the already calibrated native print
            // placement residual, up to 0.119995 pt here. No text formula changes.
            #expect(abs(actual.origin[1] - native.origin[1]) < 0.121)
            #expect(abs(actual.size - native.size) < 0.002)
        }
    }
    @Test func nativeMissingEdgesPreserveEveryFillIntervalAndGlyph() throws {
        let (deck, references) = try read()
        #expect(references.count == 12 && Set(references.map(\.id)).count == 12)
        #expect(references.reduce(0) { $0 + $1.glyphs.count } == 72)
        let before = try deck.serializedData()
        let baseline = try JSONDecoder().decode([String: [String]].self,
            from: Data(contentsOf: root.appendingPathComponent("baseline-text.json")))
        let font = root.deletingLastPathComponent().appendingPathComponent("NativeListMarkers/fonts/DejaVuSans.ttf")
        #expect(deck.fonts.data(for: FontFaceKey(family: "DejaVu Sans")) == (try Data(contentsOf: font)))
        #expect(Set(baseline.keys) == Set(references.map(\.id)))
        for page in 0..<2 {
            let result = try deck.renderSVGReportingProblems(slideAt: page)
            #expect(result.problems.fidelityIssues.isEmpty && result.problems.unsupportedContent.isEmpty)
            let svg = result.svg
            let parsed = try XML.parse(Data(svg.utf8))
            for reference in references where reference.page == page {
                try check(parsed, reference)
                let body = nodes(parsed, "text").filter { text in
                    guard let transform = text[attribute: "transform"] else { return false }
                    let values = transform.components(separatedBy: CharacterSet(charactersIn: "(), ")).compactMap(Double.init)
                    return values.count == 3 && inside(values[0] / Double(EMU.perPoint), values[1] / Double(EMU.perPoint), reference)
                }
                let expected = try #require(baseline[reference.id]).map { try XML.parse(Data($0.utf8)).serialized() }
                // Exact frozen pre-fix output: complete text attributes, scalar
                // x lists, paint sizes, face selection and optional features.
                let unchanged = body.map { $0.serialized() } == expected
                #expect(unchanged, "\(reference.id): all original glyph output unchanged")
            }
            #expect(try deck.renderSVG(slideAt: page) == svg)
        }
        #expect(try deck.serializedData() == before)
        let reopened = try Presentation(data: before)
        reopened.registerEmbeddedFonts()
        for page in 0..<2 { #expect(try reopened.renderSVG(slideAt: page) == deck.renderSVG(slideAt: page)) }
        #expect(try reopened.serializedData() == before)
    }
    private func table(_ deck: Presentation, name: String = "referenced-fill-only", page: Int = 0) throws -> Table {
        let frame = try #require(deck.slides[page].shapes.first { $0.name == name } as? TableFrame)
        return try #require(frame.table)
    }
    private func style(_ body: String, id: String = "{19000000-0000-4000-8000-000000000099}") throws -> XML.Element {
        try XML.parse(Data("<a:tblStyle xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" xmlns:custom=\"urn:owned-future\" styleId=\"\(id)\" styleName=\"Owned guard\">\(body)</a:tblStyle>".utf8))
    }
    @Test func resolvedDefaultsDoNotMaterializeAuthoredEdges() throws {
        let (deck, _) = try read()
        let before = try deck.serializedData()
        for name in ["absent-cell-style", "empty-cell-style", "empty-cell-borders", "referenced-fill-only"] {
            let value = try table(deck, name: name)
            let resolver = TableStyleResolver(table: value, theme: deck.theme)
            let cell = try value.cell(0, 0)
            for edge in [TableCellBorder.left, .right, .top, .bottom] {
                let resolved = try #require(try resolver.border(edge, row: 0, column: 0))
                #expect(resolved.color == Color("000000") && resolved.width == .points(1) && !resolved.isNone)
                #expect(cell.border(edge) == nil)
            }
        }
        let empty = try table(deck, name: "style-empty-left-line")
        let emptyLine = try #require(try TableStyleResolver(table: empty, theme: deck.theme).border(.left, row: 0, column: 0))
        #expect(emptyLine.color == nil && emptyLine.width == nil && !emptyLine.isNone)
        let none = try table(deck, name: "style-left-noFill", page: 1)
        #expect(try TableStyleResolver(table: none, theme: deck.theme).border(.left, row: 0, column: 0)?.isNone == true)
        let direct = try table(deck, name: "fill-direct-left", page: 1)
        #expect(try direct.cell(0, 0).border(.left)?.width == .points(4))
        #expect(try TableStyleResolver(table: direct, theme: deck.theme).border(.left, row: 0, column: 0)?.color == Color("0044CC"))
        #expect(try deck.serializedData() == before)
    }

    @Test func unresolvedWrappersAndReferencesDoNotAcquireDefaultPaint() throws {
        let (deck, _) = try read()
        let value = try table(deck)
        for wrapper in ["<a:left/>",
                        "<a:left><a:lnRef idx=\"999\"><a:srgbClr val=\"FF0000\"/></a:lnRef></a:left>",
                        "<a:left><a:lnRef idx=\"invalid\"/></a:left>",
                        "<a:left><custom:future/></a:left>"] {
            try value.setStyleDefinition(style("<a:wholeTbl><a:tcStyle><a:tcBdr>\(wrapper)</a:tcBdr></a:tcStyle></a:wholeTbl>"))
            let before = try deck.serializedData()
            let resolver = TableStyleResolver(table: value, theme: deck.theme)
            #expect(try resolver.border(.left, row: 0, column: 0) == nil)
            #expect(try resolver.border(.right, row: 0, column: 0)?.color == Color("000000"))
            _ = try deck.renderSVGReportingProblems(slideAt: 0)
            #expect(try deck.serializedData() == before)
        }
        // A resolvable reference still owns its paint, including theme width.
        try value.setStyleDefinition(style("<a:wholeTbl><a:tcStyle><a:tcBdr><a:left><a:lnRef idx=\"1\"><a:srgbClr val=\"FF0000\"/></a:lnRef></a:left></a:tcBdr></a:tcStyle></a:wholeTbl>"))
        #expect(try TableStyleResolver(table: value, theme: deck.theme).border(.left, row: 0, column: 0)?.color == Color("FF0000"))
        // A higher-ranked neighbor's unresolved boundary also remains absent.
        let grid = try table(deck, name: "partial-grid-first-row-fill", page: 1)
        let unresolved = "<a:firstRow><a:tcStyle><a:tcBdr><a:bottom><a:lnRef idx=\"999\"/></a:bottom></a:tcBdr></a:tcStyle></a:firstRow>"
        try grid.setStyleDefinition(style("<a:wholeTbl/>" + unresolved))
        var resolver = TableStyleResolver(table: grid, theme: deck.theme)
        #expect(try resolver.border(.bottom, row: 0, column: 0) == nil)
        #expect(try resolver.border(.top, row: 1, column: 0) == nil)
        // Existing lower-ranked explicit paint still survives the unresolved
        // wrapper, matching prior resolution rather than inventing precedence.
        let inside = "<a:wholeTbl><a:tcStyle><a:tcBdr><a:insideH><a:ln w=\"25400\"><a:solidFill><a:srgbClr val=\"008800\"/></a:solidFill></a:ln></a:insideH></a:tcBdr></a:tcStyle></a:wholeTbl>"
        try grid.setStyleDefinition(style(inside + unresolved))
        resolver = TableStyleResolver(table: grid, theme: deck.theme)
        #expect(try resolver.border(.bottom, row: 0, column: 0)?.color == Color("008800"))
        #expect(try resolver.border(.top, row: 1, column: 0)?.width == .points(2))
    }

    @Test func aliasesLiveDefinitionsAndUnknownIDsStayDistinct() throws {
        let (deck, _) = try read()
        let value = try table(deck), alias = try table(deck)
        let replacement = try style("<a:wholeTbl><a:tcStyle><a:fill><a:solidFill><a:srgbClr val=\"55AA77\"/></a:solidFill></a:fill></a:tcStyle></a:wholeTbl><a:extLst><a:ext uri=\"owned\"><custom:payload>keep</custom:payload></a:ext></a:extLst>")
        // Namespace aliases are normalized for reading, never rewritten in source.
        let xml = replacement.serialized().replacingOccurrences(of: "a:", with: "d:")
            .replacingOccurrences(of: "xmlns:a", with: "xmlns:d")
        try alias.setStyleDefinition(XML.parse(Data(xml.utf8)))
        let before = try deck.serializedData()
        #expect(try TableStyleResolver(table: value, theme: deck.theme).border(.left, row: 0, column: 0)?.width == .points(1))
        #expect(try TableStyleResolver(table: value, theme: deck.theme).fill(row: 0, column: 0) == .solid(Color("55AA77"), alpha: 1))
        _ = try deck.renderSVG(slideAt: 0)
        #expect(try deck.serializedData() == before)
        let cell = try alias.cell(0, 0)
        cell.setBorder(.left, line: nil)
        #expect(try TableStyleResolver(table: value, theme: deck.theme).border(.left, row: 0, column: 0)?.isNone == true)
        cell.clearBorder(.left)
        #expect(try TableStyleResolver(table: value, theme: deck.theme).border(.left, row: 0, column: 0)?.width == .points(1))
        let part = try #require(TableStyleResolver(table: value, theme: deck.theme).stylePart)
        let styles = try part.dom()
        let live = try #require(styles.childElements.first { $0[attribute: "styleId"] == value.styleID })
        let cellStyle = try #require(live.childElements.first { $0.name.hasSuffix(":wholeTbl") }?.childElements.first { $0.name.hasSuffix(":tcStyle") })
        cellStyle.appendElement(try XML.parse(Data("<a:tcBdr xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\"><a:left><a:ln w=\"38100\"><a:solidFill><a:srgbClr val=\"FF0000\"/></a:solidFill></a:ln></a:left></a:tcBdr>".utf8)))
        part.markDirty()
        #expect(try TableStyleResolver(table: alias, theme: deck.theme).border(.left, row: 0, column: 0)?.width == .points(3))
        styles[attribute: "def"] = BuiltInTableStyle.noStyleNoGrid.rawValue
        part.markDirty()
        #expect(try TableStyleResolver(table: alias, theme: deck.theme).border(.right, row: 0, column: 0)?.width == .points(1))
        #expect(live.serialized().contains("custom:payload>keep</custom:payload>"))
        value.styleID = "{FFFFFFFF-0000-4000-8000-000000000019}"
        #expect(try TableStyleResolver(table: alias, theme: deck.theme).border(.left, row: 0, column: 0) == nil)
        #expect(!(try deck.renderSVGReportingProblems(slideAt: 0)).problems.fidelityIssues.isEmpty)
        value.styleID = BuiltInTableStyle.noStyleNoGrid.rawValue
        #expect(try TableStyleResolver(table: alias, theme: deck.theme).border(.left, row: 0, column: 0)?.isNone == true)
        let saved = try deck.serializedData()
        let reopened = try Presentation(data: saved)
        reopened.registerEmbeddedFonts()
        #expect(try reopened.serializedData() == saved)
        #expect(try reopened.renderSVG(slideAt: 0) == deck.renderSVG(slideAt: 0))
    }

    @Test func collinearWidthOrColorChangesRetainUncalibratedEndpoints() throws {
        for mode in ["width", "color", "rtl", "merged"] {
            let (deck, _) = try read()
            let grid = try table(deck, name: "partial-grid-whole", page: 1)
            if mode == "width" || mode == "color" {
                try grid.cell(1, 0).setBorder(.left, line: Rostrum.Line(color: Color(mode == "color" ? "FF0000" : "008800"), width: .points(mode == "width" ? 4 : 2)))
            } else if mode == "rtl" { grid.rightToLeft = true }
            else { try grid.merge(row: 0, column: 0, rowSpan: 1, columnSpan: 2) }
            let svg = try XML.parse(Data(deck.renderSVG(slideAt: 1).utf8))
            let physicalLeft = mode == "rtl" ? 270.0 : 30.0
            let raw = try nodes(svg, "line").contains { node in
                try point(node, "x1") == physicalLeft && point(node, "x2") == physicalLeft && point(node, "y1") == 495
            }
            #expect(raw, "\(mode): preserve raw fallback outside constant per-grid-line paint")
        }
    }

    @Test func importCollisionRetainsResolvedPaintAndSourcePurity() throws {
        let (source, references) = try read()
        let before = try source.serializedData()
        let destination = try Presentation()
        destination.slideSize = source.slideSize
        let control = try destination.slides[0].shapes.addTable(rows: 1, columns: 1,
            frame: Rect(x: .zero, y: .zero, width: .points(100), height: .points(100)))
        let incomingID = try #require(table(source, name: "absent-cell-style").styleID)
        try control.setStyleDefinition(style("<a:wholeTbl><a:tcStyle><a:fill><a:solidFill><a:srgbClr val=\"00FF00\"/></a:solidFill></a:fill></a:tcStyle></a:wholeTbl>", id: incomingID))
        let first = destination.slides.count
        try destination.slides.importAll(from: source)
        // Import is slide-scoped. Register the exact source face for this
        // controlled preview comparison; do not claim font-package transfer.
        let font = root.deletingLastPathComponent().appendingPathComponent("NativeListMarkers/fonts/DejaVuSans.ttf")
        try destination.fonts.register(contentsOf: font)
        for page in 0..<2 {
            let svg = try destination.renderSVG(slideAt: first + page)
            #expect(try svg == source.renderSVG(slideAt: page))
            let parsed = try XML.parse(Data(svg.utf8))
            for reference in references where reference.page == page { try check(parsed, reference) }
        }
        let imported = try table(destination, name: "absent-cell-style", page: first)
        #expect(imported.styleID != incomingID)
        #expect(try TableStyleResolver(table: imported, theme: destination.theme).border(.left, row: 0, column: 0)?.width == .points(1))
        #expect(try source.serializedData() == before)
        let saved = try destination.serializedData()
        let reopened = try Presentation(data: saved)
        try reopened.fonts.register(contentsOf: font)
        for page in 0..<2 { #expect(try reopened.renderSVG(slideAt: first + page) == destination.renderSVG(slideAt: first + page)) }
    }

}
