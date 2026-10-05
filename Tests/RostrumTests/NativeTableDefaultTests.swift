import Foundation
import Testing
@testable import Rostrum

@Suite struct NativeTableDefaultTests {
    private var root: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/NativeTableDefault")
    }
    private struct Paint: Decodable {
        struct Fill: Decodable { let bounds: [Double]; let color: [Double]; let opacity: Double }
        struct Line: Decodable { let points: [Double]; let color: [Double]; let opacity: Double; let width: Double }
        struct Glyph: Decodable { let text: String; let origin: [Double] }
        let id: String; let x: Double; let y: Double; let width: Double; let height: Double
        let fills: [Fill]; let lines: [Line]; let glyphs: [Glyph]
    }
    private func nodes(_ root: XML.Element, _ name: String) -> [XML.Element] {
        (root.name == name ? [root] : []) + root.childElements.flatMap { nodes($0, name) }
    }
    private func number(_ node: XML.Element, _ name: String) throws -> Double {
        try #require(node[attribute: name].flatMap(Double.init)) / Double(EMU.perPoint)
    }
    private func channels(_ hex: String?) throws -> [Double] {
        let hex = try #require(hex)
        let value = try #require(UInt32(hex.dropFirst(), radix: 16))
        return [Double(value >> 16), Double((value >> 8) & 255), Double(value & 255)].map { $0 / 255 }
    }
    private func same(_ actual: [Double], _ expected: [Double], tolerance: Double) -> Bool {
        actual.count == expected.count && zip(actual, expected).allSatisfy { abs($0 - $1) < tolerance }
    }
    private func check(svg: String, references: [Paint]) throws {
        let parsed = try XML.parse(Data(svg.utf8))
        #expect(nodes(parsed, "g").allSatisfy { $0[attribute: "transform"] == nil })
        for reference in references {
            let fills = try nodes(parsed, "rect").filter {
                let x = try number($0, "x"), y = try number($0, "y")
                return abs(x - reference.x) < 0.001 && abs(y - reference.y) < 0.001
            }
            #expect(fills.count == reference.fills.count, "\(reference.id): native fill count")
            for (fill, native) in zip(fills, reference.fills) {
                let x = try number(fill, "x"), y = try number(fill, "y")
                let w = try number(fill, "width"), h = try number(fill, "height")
                #expect(same([x, y, x + w, y + h], native.bounds, tolerance: 0.001))
                // PDF colors carry finite normalized channel quantization.
                #expect(try same(channels(fill[attribute: "fill"]), native.color, tolerance: 0.0001))
                #expect((fill[attribute: "fill-opacity"].flatMap(Double.init) ?? 1) == native.opacity)
            }
            let lines = try nodes(parsed, "line").filter {
                let x = try number($0, "x1"), y = try number($0, "y1")
                return x >= reference.x - 3 && x <= reference.x + reference.width + 3
                    && y >= reference.y - 3 && y <= reference.y + reference.height + 3
            }
            #expect(lines.count == reference.lines.count, "\(reference.id): native stroke count")
            var consumed = Set<Int>()
            for line in lines {
                let points = try ["x1", "y1", "x2", "y2"].map { try number(line, $0) }
                let index = try #require(reference.lines.indices.first { same(points, reference.lines[$0].points, tolerance: 0.001) }, "\(reference.id): native endpoints \(points)")
                #expect(consumed.insert(index).inserted)
                let native = reference.lines[index]
                #expect(try same(channels(line[attribute: "stroke"]), native.color, tolerance: 0.0001), "\(reference.id): native stroke color")
                #expect(abs(try number(line, "stroke-width") - native.width) < 0.001)
                #expect((line[attribute: "stroke-opacity"].flatMap(Double.init) ?? 1) == native.opacity)
            }
            let text = nodes(parsed, "text").filter {
                guard let transform = $0[attribute: "transform"] else { return false }
                let values = transform.components(separatedBy: CharacterSet(charactersIn: "(), ")).compactMap(Double.init)
                return values.count == 3 && values[2] == Double(EMU.perPoint)
                    && abs(values[0] / Double(EMU.perPoint) - reference.x) < 0.001
                    && values[1] / Double(EMU.perPoint) >= reference.y
                    && values[1] / Double(EMU.perPoint) < reference.y + reference.height
            }
            #expect(text.count == 1)
            let line = try #require(text.first)
            #expect(line.textContent == reference.glyphs.map(\.text).joined())
        }
    }
    @Test(arguments: ["builtin", "custom"])
    func nativeStyleChoiceAndDirectPaint(group: String) throws {
        let directory = root.appendingPathComponent(group)
        let deck = try Presentation(contentsOf: directory.appendingPathComponent("native-table-default-\(group)-v1.pptx"))
        #expect(deck.registerEmbeddedFonts() == ["DejaVu Sans"])
        let references = try JSONDecoder().decode([Paint].self, from: Data(contentsOf: directory.appendingPathComponent("paint-reference.json")))
        #expect(references.count == 4 && Set(references.map(\.id)).count == 4)
        #expect(references.reduce(0) { $0 + $1.glyphs.count } == 16)
        let before = try deck.serializedData()
        let svg = try deck.renderSVGReportingProblems(slideAt: 0)
        #expect(svg.problems.fidelityIssues.isEmpty)
        try check(svg: svg.svg, references: references)
        #expect(try deck.renderSVG(slideAt: 0) == svg.svg)
        #expect(try deck.serializedData() == before)
        let reopened = try Presentation(data: before)
        reopened.registerEmbeddedFonts()
        #expect(try reopened.renderSVG(slideAt: 0) == svg.svg)
        #expect(try reopened.serializedData() == before)
    }
    @Test func nativeOpaqueMixedWidthJoinsKeepEveryPaintedInterval() throws {
        let directory = root.deletingLastPathComponent().appendingPathComponent("NativeTableJoins")
        let deck = try Presentation(contentsOf: directory.appendingPathComponent("native-table-joins-v1.pptx"))
        deck.registerEmbeddedFonts()
        let references = try JSONDecoder().decode([Paint].self, from: Data(contentsOf: directory.appendingPathComponent("paint-reference.json")))
        #expect(references.count == 4 && references.reduce(0) { $0 + $1.glyphs.count } == 40)
        let before = try deck.serializedData()
        let svg = try deck.renderSVG(slideAt: 0)
        let parsed = try XML.parse(Data(svg.utf8))
        // Native PDF coalesces identical adjacent opaque strokes. Compare
        // their exact painted union, without removing any distinct width,
        // color, opacity or perpendicular line.
        func intervals(_ lines: [Paint.Line]) -> [[Double]] {
            let values = lines.map { line -> [Double] in
                let p = line.points, vertical = abs(p[0] - p[2]) < 0.001
                return [vertical ? 1 : 0, vertical ? p[0] : p[1], line.width,
                        vertical ? p[1] : p[0], vertical ? p[3] : p[2]]
            }.sorted { $0.lexicographicallyPrecedes($1) }
            var result: [[Double]] = []
            for value in values {
                if let last = result.last, last[0] == value[0], abs(last[1] - value[1]) < 0.001,
                   last[2] == value[2], abs(last[4] - value[3]) < 0.001 {
                    result[result.count - 1][4] = value[4]
                } else { result.append(value) }
            }
            return result
        }
        for reference in references {
            let selected = try nodes(parsed, "line").filter {
                let x = try number($0, "x1"), y = try number($0, "y1")
                return x >= reference.x - 3 && x <= reference.x + reference.width + 3
                    && y >= reference.y - 3 && y <= reference.y + reference.height + 3
            }
            let actual = try selected.map { node in
                Paint.Line(points: try ["x1", "y1", "x2", "y2"].map { try number(node, $0) },
                           color: try channels(node[attribute: "stroke"]),
                           opacity: node[attribute: "stroke-opacity"].flatMap(Double.init) ?? 1,
                           width: try number(node, "stroke-width"))
            }
            #expect((actual + reference.lines).allSatisfy { $0.color == [0, 0, 0] && $0.opacity == 1 })
            let a = intervals(actual), b = intervals(reference.lines)
            #expect(a.count == b.count, "\(reference.id): complete stroke coverage")
            for (first, second) in zip(a, b) { #expect(same(first, second, tolerance: 0.001), "\(reference.id): native interval \(first) vs \(second)") }
        }
        #expect(try deck.renderSVG(slideAt: 0) == svg)
        #expect(try deck.serializedData() == before)
    }
    @Test func signedJoinsUseActualOwnersAndLargerPerpendicularDonor() throws {
        for continuation in [Int?.none, 1, 2, 5] {
            var borders = TableBorderSegments<Int>()
            borders.append(axis: .vertical, boundary: 1, range: 1..<2, paint: 2)
            borders.append(axis: .vertical, boundary: 1, range: 0..<1, paint: continuation)
            borders.append(axis: .vertical, boundary: 1, range: 2..<3, paint: 3)
            borders.append(axis: .horizontal, boundary: 1, range: 0..<1, paint: 4)
            borders.append(axis: .horizontal, boundary: 1, range: 1..<2, paint: 6)
            borders.append(axis: .horizontal, boundary: 2, range: 0..<1, paint: 8)
            let segment = try #require(borders.resolved().first { $0.edge.axis == .vertical && $0.range == 1..<2 })
            let result = borders.mixedWidthExtensions(segment, width: { $0 })
            let expectedLower = continuation == 2 ? 0.0 : continuation == 5 ? -3.0 : 3.0
            #expect(result.lower == expectedLower && result.upper == -4)
            // A later noFill owner erases a prior collinear paint, restoring
            // the terminal extension rather than retaining a hidden donor.
            borders.append(axis: .vertical, boundary: 1, range: 0..<1, paint: nil)
            #expect(borders.mixedWidthExtensions(segment, width: { $0 }).lower == 3)
            borders.append(axis: .horizontal, boundary: 1, range: 1..<2, paint: nil)
            #expect(borders.mixedWidthExtensions(segment, width: { $0 }).lower == 2)
            borders.append(axis: .horizontal, boundary: 1, range: 0..<1, paint: nil)
            #expect(borders.mixedWidthExtensions(segment, width: { $0 }).lower == 0)
        }
    }

    @Test func mixedJoinProfilesRespectCalibratedAndRejectedEndpoints() throws {
        let directory = root.deletingLastPathComponent().appendingPathComponent("NativeTableJoins")
        for mode in ["alpha", "dash", "diagonal", "rtl-colored", "multicolor", "rtl-merged", "ragged", "wide"] {
            let deck = try Presentation(contentsOf: directory.appendingPathComponent("native-table-joins-v1.pptx"))
            deck.registerEmbeddedFonts()
            let multi = mode == "multicolor" || mode == "rtl-merged" || mode == "ragged"
            let name = multi ? "mixed-shared-grid" : "unequal-four-edges"
            let frame = try #require(deck.slides[0].shapes.first { $0.name == name } as? TableFrame)
            let table = try #require(frame.table)
            let cell = try table.cell(0, 0)
            let properties = try #require(cell.tc.firstChild(named: "a:tcPr"))
            let left = try #require(properties.firstChild(named: "a:lnL"))
            switch mode {
            case "alpha":
                let color = try #require(left.firstChild(named: "a:solidFill")?.firstChild(named: "a:srgbClr"))
                color.appendElement(XML.Element("a:alpha", attributes: [("val", "50000")]))
            case "dash": left.appendElement(XML.Element("a:prstDash", attributes: [("val", "dash")]))
            case "diagonal":
                let diagonal = left.deepCopy(); diagonal.name = "a:lnTlToBr"; properties.appendElement(diagonal)
            case "rtl-colored":
                // RTL alone is now native-calibrated; its multicolor combination is not.
                table.rightToLeft = true
                left.firstChild(named: "a:solidFill")?.firstChild(named: "a:srgbClr")?[attribute: "val"] = "FF0000"
            case "multicolor": left.firstChild(named: "a:solidFill")?.firstChild(named: "a:srgbClr")?[attribute: "val"] = "FF0000"
            case "wide": left[attribute: "w"] = String(200 * EMU.perPoint)
            case "ragged":
                let row = try #require(table.tbl.children(named: "a:tr").last)
                row.children.removeLast()
            default:
                // LTR one-axis merges are calibrated; combined RTL merges remain outside scope.
                table.rightToLeft = true
                cell.tc[attribute: "gridSpan"] = "2"
                try table.cell(0, 1).tc[attribute: "hMerge"] = "1"
            }
            table.part.markDirty()
            let svg = try XML.parse(Data(deck.renderSVG(slideAt: 0).utf8))
            let y = multi ? 350.0 : 70.0
            let matching = try nodes(svg, "line").filter {
                let x1 = try number($0, "x1"), x2 = try number($0, "x2"), y1 = try number($0, "y1")
                return abs(x1 - 30) < 0.001 && x1 == x2 && abs(y1 - y) < 0.001
            }
            if mode == "multicolor" {
                let calibrated = try nodes(svg, "line").contains {
                    try number($0, "x1") == 30 && number($0, "x2") == 30 && number($0, "y1") == 349.5
                }
                #expect(calibrated && matching.isEmpty, "unmerged LTR collinear color transition")
            } else {
                #expect(!matching.isEmpty, "\(mode): retains raw mixed-width fallback endpoint")
            }
        }
    }

    @Test func liveDefaultsExplicitChoicesAndUnknownIDsRemainDistinct() throws {
        let deck = try Presentation(contentsOf: root.appendingPathComponent("custom/native-table-default-custom-v1.pptx"))
        deck.registerEmbeddedFonts()
        let frame = try #require(deck.slides[0].shapes.first { $0.name == "custom-absent" } as? TableFrame)
        let table = try #require(frame.table)
        let main = try deck.package.mainDocumentPart()
        let stylePart = try main.related(by: RelType.tableStyles, in: deck.package)
        let styles = try stylePart.dom()
        let custom = try #require(TableStyleXML.definitions(in: styles).first)
        let customID = try #require(custom[attribute: "styleId"])
        let whole = try #require(custom.childElements.first)
        let customText = XML.Element("a:tcTxStyle", attributes: [("b", "on"), ("xmlns:a", TableStyleXML.drawing)])
        customText.appendElement(XML.Element("a:srgbClr", attributes: [("val", "FF0000")]))
        whole.children.insert(.element(customText), at: 0)
        var colors: [XML.Element] = []
        TableStyleXML.walk(custom, namespaces: TableStyleXML.bindings(styles, inheriting: TableStyleXML.defaults)) { node, scope in
            if TableStyleXML.isDrawing(node, "srgbClr", namespaces: scope) { colors.append(node) }
        }
        let color = try #require(colors.last)
        let alias = table
        func fill() throws -> ReadFill? { try TableStyleResolver(table: alias, theme: deck.theme).fill(row: 0, column: 0) }
        #expect(try fill() == .noFill)
        #expect(TableStyleResolver(table: table, theme: deck.theme).effective(row: 0, column: 0).text[attribute: "b"] == nil)
        styles[attribute: "def"] = BuiltInTableStyle.mediumStyle2Accent1.rawValue
        color[attribute: "val"] = "112233"
        #expect(try fill() == .noFill)
        table.styleID = customID
        #expect(TableStyleResolver(table: table, theme: deck.theme).effective(row: 0, column: 0).text[attribute: "b"] == "1")
        #expect(try fill() == .solid(Color("112233"), alpha: 1))
        color[attribute: "val"] = "445566"
        #expect(try fill() == .solid(Color("445566"), alpha: 1))
        table.styleID = nil
        try table.cell(0, 0).setFill(.solid(Color("ABCDEF")))
        #expect(try fill() == .solid(Color("ABCDEF"), alpha: 1))
        table.styleID = "{FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF}"
        #expect(!TableStyleResolver(table: table, theme: deck.theme).hasStyleDefinition)
        #expect(try fill() == .solid(Color("ABCDEF"), alpha: 1))
        #expect(try deck.renderSVGReportingProblems(slideAt: 0).problems.fidelityIssues.contains { $0.code == .unresolvedTableStyle })
        table.styleID = nil
        #expect(try !deck.renderSVGReportingProblems(slideAt: 0).problems.fidelityIssues.contains { $0.code == .unresolvedTableStyle })
    }
    @Test func omittedAppliedStyleStaysOmittedOnImport() throws {
        let source = try Presentation(contentsOf: root.appendingPathComponent("custom/native-table-default-custom-v1.pptx"))
        source.registerEmbeddedFonts()
        let references = try JSONDecoder().decode([Paint].self, from: Data(contentsOf: root.appendingPathComponent("custom/paint-reference.json")))
            .filter { $0.id == "custom-absent" }
        try check(svg: source.renderSVG(slideAt: 0), references: references)
        let destination = try Presentation()
        try destination.fonts.register(try #require(source.fonts.data(for: .init(family: "DejaVu Sans"))))
        let slide = try destination.slides.add()
        let table = try slide.shapes.addTable(rows: 1, columns: 1, frame: .init(x: .zero, y: .zero, width: .inches(2), height: .inches(1)))
        try table.setStyleDefinition(try XML.parse(Data("<a:tblStyle styleId=\"{11111111-1111-1111-1111-111111111111}\"><a:wholeTbl><a:tcStyle><a:fill><a:solidFill><a:srgbClr val=\"FF0000\"/></a:solidFill></a:fill></a:tcStyle></a:wholeTbl></a:tblStyle>".utf8)))
        let incoming = try destination.slides.import(from: source, at: 0)
        let importedIndex = destination.slides.count - 1
        try check(svg: destination.renderSVG(slideAt: importedIndex), references: references)
        for name in ["custom-absent", "custom-absent-direct"] {
            let shape = try #require(incoming.shapes.first { $0.name == name })
            let imported = try #require((shape as? TableFrame)?.table)
            #expect(imported.styleID == nil)
        }
        let shape = try #require(source.slides[0].shapes.first { $0.name == "custom-absent" })
        let original = try #require((shape as? TableFrame)?.table)
        original.tbl.removeChildren(named: "a:tblPr")
        original.part.markDirty()
        let noProperties = try destination.slides.import(from: source, at: 0)
        #expect(try #require((noProperties.shapes.first { $0.name == "custom-absent" } as? TableFrame)?.table).tbl.firstChild(named: "a:tblPr") == nil)
    }
}
