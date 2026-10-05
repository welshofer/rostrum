import Foundation
import Testing
@testable import Rostrum

@Suite struct NativeTableJoinProfileTests {
    private var root: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/NativeTableJoinProfiles")
    }
    private struct Line: Decodable {
        let points: [Double], color: [Double], opacity: Double, width: Double
    }
    private struct Glyph: Decodable {
        let text: String, origin: [Double], size: Double
    }
    private struct Reference: Decodable {
        let id: String, page: Int, x: Double, y: Double, width: Double, height: Double
        let lines: [Line], glyphs: [Glyph]
    }
    private func read() throws -> (Presentation, [Reference]) {
        let deck = try Presentation(contentsOf: root.appendingPathComponent("native-table-joins18-v1.pptx"))
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
        if reference.id.hasPrefix("colored-") {
            var crossings = 0
            for i in reference.lines.indices {
                for second in reference.lines.dropFirst(i + 1) where !close(reference.lines[i].color, second.color, tolerance: 0.0001) {
                    let f = bounds(reference.lines[i]), s = bounds(second)
                    let l = max(f[0], s[0]), t = max(f[1], s[1]), r = min(f[2], s[2]), bottom = min(f[3], s[3])
                    guard l < r && t < bottom else { continue }
                    crossings += 1
                    let x = (l + r) / 2, y = (t + bottom) / 2
                    let expected = try #require(paintedColor(reference.lines, x: x, y: y))
                    let observed = try #require(paintedColor(actual, x: x, y: y))
                    #expect(close(observed, expected, tolerance: 0.0001), "\(reference.id): crossing paint order at \(x),\(y)")
                }
            }
            #expect(crossings == 9)
        }
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
            #expect(close(actual.origin, native.origin, tolerance: 0.025))
            #expect(abs(actual.size - native.size) < 0.002)
        }
    }
    @Test func nativeProfilesPreserveEveryIntervalCrossingAndGlyph() throws {
        let (deck, references) = try read()
        #expect(references.count == 8 && Set(references.map(\.id)).count == 8)
        #expect(references.reduce(0) { $0 + $1.glyphs.count } == 112)
        let before = try deck.serializedData()
        for page in 0..<2 {
            let result = try deck.renderSVGReportingProblems(slideAt: page)
            #expect(result.problems.fidelityIssues.isEmpty && result.problems.unsupportedContent.isEmpty)
            let svg = result.svg
            let parsed = try XML.parse(Data(svg.utf8))
            for reference in references where reference.page == page { try check(parsed, reference) }
            #expect(try deck.renderSVG(slideAt: page) == svg)
        }
        #expect(try deck.serializedData() == before)
        let reopened = try Presentation(data: before)
        reopened.registerEmbeddedFonts()
        for page in 0..<2 { #expect(try reopened.renderSVG(slideAt: page) == deck.renderSVG(slideAt: page)) }
        #expect(try reopened.serializedData() == before)
    }
    @Test func liveRTLSelectionUsesCurrentDOMAndPreservesReopen() throws {
        let (deck, references) = try read()
        let frame = try #require(deck.slides[0].shapes.first { $0.name == "ltr-unequal-grid" } as? TableFrame)
        let table = try #require(frame.table), alias = try #require(frame.table)
        let original = try deck.renderSVG(slideAt: 0)
        alias.rightToLeft = true
        #expect(table.rightToLeft)
        let native = references[1]
        // Translation preserves the independently measured native geometry;
        // only the source frame differs between the paired LTR/RTL controls.
        let dx = references[0].x - native.x
        let shifted = Reference(id: native.id, page: native.page, x: native.x + dx,
            y: native.y, width: native.width, height: native.height,
            lines: native.lines.map { line in
                let p = line.points
                return Line(points: [p[0] + dx, p[1], p[2] + dx, p[3]], color: line.color,
                            opacity: line.opacity, width: line.width)
            }, glyphs: native.glyphs.map {
                Glyph(text: $0.text, origin: [$0.origin[0] + dx, $0.origin[1]], size: $0.size)
            })
        let changed = try deck.renderSVG(slideAt: 0)
        #expect(changed != original)
        try check(XML.parse(Data(changed.utf8)), shifted)
        let bytes = try deck.serializedData()
        let reopened = try Presentation(data: bytes)
        reopened.registerEmbeddedFonts()
        #expect(try reopened.renderSVG(slideAt: 0) == changed)
        table.rightToLeft = false
        #expect(try deck.renderSVG(slideAt: 0) == original)
    }

    @Test func combinedProfilesPreserveCalibratedAdmissionBoundaries() throws {
        for mode in ["rtl-color", "rtl-merge", "merged-color", "two-axis-merge", "mixed-merge-orientations", "axis-color-transition"] {
            let (deck, _) = try read()
            let page = mode == "rtl-merge" || mode == "merged-color" ? 1 : 0
            let name = page == 1 ? "horizontal-merge-matching" : "ltr-unequal-grid"
            let frame = try #require(deck.slides[page].shapes.first { $0.name == name } as? TableFrame)
            let table = try #require(frame.table)
            if mode == "rtl-color" || mode == "rtl-merge" { table.rightToLeft = true }
            if mode == "two-axis-merge" { try table.merge(row: 0, column: 0, rowSpan: 2, columnSpan: 2) }
            if mode == "mixed-merge-orientations" {
                try table.insertRow(at: 2, height: .points(60))
                try table.merge(row: 0, column: 0, rowSpan: 1, columnSpan: 2)
                try table.merge(row: 1, column: 0, rowSpan: 2, columnSpan: 1)
                #expect(try table.mergedRegions.count == 2)
            }
            if mode == "rtl-color" || mode == "merged-color" || mode == "axis-color-transition" {
                let cell = try table.cell(0, 0)
                let color = try #require(cell.tc.firstChild(named: "a:tcPr")?.firstChild(named: "a:lnL")?
                    .firstChild(named: "a:solidFill")?.firstChild(named: "a:srgbClr"))
                color[attribute: "val"] = "FF0000"
                table.part.markDirty()
            }
            let svg = try XML.parse(Data(deck.renderSVG(slideAt: page).utf8))
            let left = table.rightToLeft ? 270.0 : 30.0
            let raw = try nodes(svg, "line").contains { node in
                let x1 = try point(node, "x1"), x2 = try point(node, "x2"), y1 = try point(node, "y1")
                return x1 == left && x2 == left && y1 == 70
            }
            if mode == "axis-color-transition" {
                let calibrated = try nodes(svg, "line").contains { node in
                    try point(node, "x1") == left && point(node, "x2") == left && point(node, "y1") == 69.5
                }
                #expect(calibrated && !raw, "new native collinear transition admission")
            } else {
                #expect(raw, "\(mode): unchanged raw endpoint outside calibrated combinations")
            }
        }
    }

}
