import Foundation
import Rostrum

public struct KeyxPreview: Sendable {
    public let svg: String
    public let width: Double
    public let height: Double
    public let warnings: [String]
}

/// A separate, approximate interchange renderer, not a document converter.
/// FontLibrary/TextMeasurer are reused without constructing PresentationML.
public enum KeyxPreviewRenderer {
    public static func render(_ document: KeyxDocument, slideAt index: Int,
                              fonts: FontLibrary? = nil) throws -> KeyxPreview {
        let slides = try document.slides
        guard slides.indices.contains(index) else { throw KeyxError.invalid("Slide index out of bounds") }
        let size = try document.slideSize
        let slide = slides[index]
        let resolver = try document.styleResolver()
        var renderer = Renderer(document: document, resolver: resolver, fonts: fonts)
        let layout = try document.layout(for: slide)
        let background: KeyxValue?
        switch try resolver.property("background", on: slide.node) {
        case .value(let value): background = value
        case .cleared: background = nil
        case .inherited: background = layout?["background"]
        }
        let fill = try renderer.paint(background?["standard"], fallback: "#FFFFFF")
        var body = "<rect width=\"\(size.width)\" height=\"\(size.height)\" fill=\"\(fill)\"/>"
        if layout == nil { renderer.warn("External theme/layout artwork is unavailable in this preview.") }
        if layout?["slide_objects_layer_with_layout"]?.bool == true {
            renderer.warn("Interleaved layout/object stacking is approximated.")
        }
        for item in try document.displayObjects(on: slide) {
            try Task.checkCancellation()
            do { body += try renderer.draw(item.canvas, depth: 0) }
            catch { renderer.warn("Object preview unavailable: \(error)") }
        }
        renderer.warn("Interchange preview is not Keynote's renderer; native text shaping, theme defaults and effects can differ.")
        return KeyxPreview(svg: """
        <svg xmlns="http://www.w3.org/2000/svg" width="\(size.width)" height="\(size.height)" viewBox="0 0 \(size.width) \(size.height)">
        \(body)
        </svg>
        """, width: size.width, height: size.height, warnings: renderer.warnings)
    }

    private struct Renderer {
        let document: KeyxDocument
        let resolver: KeyxStyleResolver
        let fonts: FontLibrary?
        var warnings: [String] = []
        var warningSet: Set<String> = []
        var remainingCells = 100_000
        var clipIndex = 0
        mutating func warn(_ warning: String) {
            if warningSet.insert(warning).inserted { warnings.append(warning) }
        }
        mutating func draw(_ canvas: KeyxCanvasObject, depth: Int) throws -> String {
            guard depth < document.limits.jsonDepth else { throw KeyxError.limit("Preview group nesting limit exceeded") }
            let kind = try canvas.kind
            var node = try resolver.resolved(canvas.properties)
            if kind == "chart" {
                let keys = node.fields.keys.filter { !["type_identifier", "version", "preset_identifier"].contains($0) }
                guard keys.count == 1, let key = keys.first, let value = node[key] else { throw KeyxError.unsupported("Unsupported chart form") }
                let chart = try resolver.resolved(KeyxNode(value: value))
                if let geometry = chart["geometry"] { node["geometry"] = geometry }
            }
            if kind == "group" {
                var result = ""
                // Children are slide-absolute: never translate by the group's
                // position. Only a group rotation/flip transforms those points.
                for child in node["children"]?.array ?? [] {
                    result += try draw(KeyxCanvasObject(node: KeyxNode(value: child)), depth: depth + 1)
                }
                if let geometry = node["geometry"] {
                    let g = try KeyxGeometry(node: resolver.resolved(KeyxNode(value: geometry)))
                    if g.angle != 0 || g.flipped {
                        warn("Group rotations/flips are approximated; child coordinates remain slide-absolute.")
                        return "<g transform=\"translate(\(g.centerX) \(g.centerY)) rotate(\(-g.previewAngle)) scale(\(g.flipped ? -1 : 1) 1) translate(\(-g.centerX) \(-g.centerY))\">\(result)</g>"
                    }
                }
                return result
            }
            guard let value = node["geometry"] else { throw KeyxError.unsupported("\(kind) has no explicit geometry") }
            let geometry = try KeyxGeometry(node: resolver.resolved(KeyxNode(value: value)))
            let w = geometry.width, h = geometry.height
            var body = ""
            for effect in ["shadow", "reflection", "instant_alpha_path", "mask"] where node[effect] != nil && node[effect] != .null {
                warn("\(effect.replacingOccurrences(of: "_", with: " ")) is preserved but not rendered.")
            }
            switch kind {
            case "textbox", "shape":
                let fill = try paint(node["fill"], fallback: kind == "shape" ? "#D5E4E9" : "none")
                let stroke = try border(node["stroke"])
                if let path = node["path"]?["bezier"] {
                    guard let d = path["path"]?.string, let space = path["space"],
                          let x = space["position"]?["x"]?.double, let y = space["position"]?["y"]?.double,
                          let sw = space["size"]?["width"]?.double, let sh = space["size"]?["height"]?.double,
                          sw > 0, sh > 0 else {
                        throw KeyxError.unsupported("Vector paths without an explicit coordinate space are not previewed")
                    }
                    body += "<path d=\"\(escape(d))\" transform=\"scale(\(w / sw) \(h / sh)) translate(\(-x) \(-y))\" fill=\"\(fill)\" \(stroke)/>"
                } else {
                    if node["path"] != nil { warn("Unsupported vector path is approximated by its bounding box.") }
                    body += "<rect width=\"\(w)\" height=\"\(h)\" fill=\"\(fill)\" \(stroke)/>"
                }
                if let text = node["text"] {
                    body += try textSVG(KeyxNode(value: text), owner: node, width: w, height: h)
                }
            case "image":
                guard let resource = node["resource"] else { throw KeyxError.invalid("Missing image resource") }
                let data = try document.resourceData(resource)
                let mime: String
                if data.starts(with: [137, 80, 78, 71]) { mime = "image/png" }
                else if data.starts(with: [255, 216, 255]) { mime = "image/jpeg" }
                else if data.starts(with: Array("GIF8".utf8)) { mime = "image/gif" }
                else { throw KeyxError.unsupported("This image encoding is preserved but not previewed") }
                body += "<image width=\"\(w)\" height=\"\(h)\" preserveAspectRatio=\"none\" href=\"data:\(mime);base64,\(data.base64EncodedString())\"/>"
            case "table": body += try tableSVG(node, width: w, height: h)
            case "chart": body += try chartSVG(canvas.properties, width: w, height: h)
            default:
                warn("\(kind) is preserved but cannot be rendered.")
                body = "<rect width=\"\(w)\" height=\"\(h)\" fill=\"#F2F2F2\" stroke=\"#9A6700\" stroke-dasharray=\"6 4\"/><text x=\"8\" y=\"24\" font-size=\"16\">\(escape(kind)) preview unavailable</text>"
            }
            let opacity = node["opacity"]?.double ?? 1
            return "<g opacity=\"\(opacity)\" transform=\"translate(\(geometry.centerX) \(geometry.centerY)) rotate(\(-geometry.previewAngle)) scale(\(geometry.flipped ? -1 : 1) 1) translate(\(-w / 2) \(-h / 2))\">\(body)</g>"
        }

        mutating func paint(_ value: KeyxValue?, fallback: String) throws -> String {
            guard let value, value != .null else { return fallback }
            let fill = try resolver.resolved(KeyxNode(value: value))
            if let color = fill["color"] { return try colorCSS(color) }
            warn("Gradient/image fill is preserved but approximated in the preview.")
            return fallback
        }
        mutating func colorCSS(_ color: KeyxValue) throws -> String {
            let color = try resolver.resolved(KeyxNode(value: color))
            guard let value = color["rgba"] else { throw KeyxError.unsupported("Unsupported color") }
            let rgba = try resolver.resolved(KeyxNode(value: value))
            if let space = rgba["color_space"]?.string, space != "srgb" { warn("Wide-gamut color is approximated as sRGB.") }
            let r = min(1, max(0, rgba["red"]?.double ?? 0)) * 255
            let g = min(1, max(0, rgba["green"]?.double ?? 0)) * 255
            let b = min(1, max(0, rgba["blue"]?.double ?? 0)) * 255
            return "rgba(\(r),\(g),\(b),\(min(1, max(0, rgba["alpha"]?.double ?? 1))))"
        }
        mutating func border(_ value: KeyxValue?) throws -> String {
            guard let value, value != .string("empty"), value != .null else { return "stroke=\"none\"" }
            if let line = value["line"] {
                let color = try line["color"].map { try colorCSS($0) } ?? "#333333"
                if let pattern = line["pattern"]?.string, pattern != "solid" { warn("Patterned stroke is approximated as a solid stroke.") }
                return "stroke=\"\(color)\" stroke-width=\"\(line["width"]?.double ?? 1)\""
            }
            warn("Frame stroke is not previewed."); return "stroke=\"none\""
        }

        mutating func textSVG(_ text: KeyxNode, owner: KeyxNode, width: Double, height: Double) throws -> String {
            let text = try resolver.resolved(text)
            let paragraph = try owner["paragraph_properties"].map { try resolver.resolved(KeyxNode(value: $0)) } ?? KeyxNode()
            let base = try paragraph["character_properties"].map { try resolver.resolved(KeyxNode(value: $0)) } ?? KeyxNode()
            var paragraphs: [[(String, KeyxNode)]] = []
            func run(_ value: KeyxValue, base: KeyxNode) throws -> (String, KeyxNode) {
                guard let string = value["string"]?.string else { throw KeyxError.invalid("Invalid text run") }
                let style = try value["style"].map { try resolver.resolved(KeyxNode(value: $0)) } ?? KeyxNode()
                return (string, KeyxNode(base.fields.merging(style.fields) { _, local in local }))
            }
            if let string = text["string"]?.string { paragraphs = [[(string, base)]] }
            else if let values = text["text_runs"]?.array { paragraphs = [try values.map { try run($0, base: base) }] }
            else if let values = text["paragraphs"]?.array {
                for value in values {
                    let p = try resolver.resolved(KeyxNode(value: value))
                    let style = try p["style"].map { try resolver.resolved(KeyxNode(value: $0)) } ?? KeyxNode()
                    let characters = try style["character_properties"].map { try resolver.resolved(KeyxNode(value: $0)) } ?? base
                    var segments: [(String, KeyxNode)] = []
                    for item in p["contents"]?.array ?? [] {
                        if let value = item["run"] ?? item["hyperlink"]?["run"] {
                            segments.append(try run(value, base: characters))
                        } else { warn("Inline text objects are preserved but not previewed.") }
                    }
                    paragraphs.append(segments)
                    if p["list_style"] != nil || p["list_level"] != nil { warn("List markers are not rendered in the interchange preview.") }
                }
            } else { throw KeyxError.unsupported("Unknown text encoding") }
            let layout = try owner["layout_properties"].map { try resolver.resolved(KeyxNode(value: $0)) } ?? KeyxNode()
            if layout["vertical_text"]?.bool == true || layout["columns"] != nil { warn("Vertical/multicolumn text is approximated as horizontal text.") }
            if paragraph["alignment"]?.string != nil && paragraph["alignment"]?.string != "left" { warn("Paragraph alignment is approximated as left-aligned text.") }
            let padding = layout["padding"]
            let left = padding?["left"]?.double ?? 4
            let top = padding?["top"]?.double ?? 4
            let right = padding?["right"]?.double ?? 4
            var x = left, y = top, lineHeight = 0.0, lineSize = 0.0
            var spans = "", output = ""
            func finishLine() {
                let size = lineSize > 0 ? lineSize : 18
                if !spans.isEmpty {
                    output += "<text xml:space=\"preserve\" x=\"\(left)\" y=\"\(y + size)\">\(spans)</text>"
                }
                y += max(lineHeight, size * 1.3)
                x = left; lineHeight = 0; lineSize = 0; spans = ""
            }
            func advance(_ string: String, style: KeyxNode, font: String, size: Double, bold: Bool, italic: Bool) -> Double {
                if let width = fonts?.previewAdvance?(string, font, size, bold, italic), width.isFinite { return max(0, width) }
                if let metrics = fonts?.metrics(for: font, bold: bold, italic: italic) {
                    return TextMeasurer(metrics).width(of: string, pointSize: size)
                }
                return Double(string.count) * size * 0.6
            }
            for (p, segments) in paragraphs.enumerated() {
                if p > 0 { finishLine() }
                for (string, style) in segments {
                    let font = style["font_name"]?.string ?? "Arial"
                    let size = min(1000, max(1, style["font_size"]?.double ?? 18))
                    let bold = style["bold"]?.bool ?? false, italic = style["italic"]?.bool ?? false
                    let color = try paint(style["character_fill"], fallback: "#172B3A")
                    if fonts?.metrics(for: font, bold: bold, italic: italic) == nil && fonts?.previewAdvance == nil {
                        warn("Font \(font) uses estimated advances; line wrapping may differ in Keynote.")
                    }
                    // Whitespace stays in the source; runs are split only into
                    // preview paint segments. No text is rewritten on disk.
                    var tokens: [String] = [], token = ""
                    for character in string {
                        token.append(character)
                        if character.isWhitespace { tokens.append(token); token = "" }
                    }
                    if !token.isEmpty { tokens.append(token) }
                    for token in tokens {
                        let hardBreak = token.hasSuffix("\n") || token.hasSuffix("\r")
                        let painted = token.trimmingCharacters(in: .newlines)
                        let length = advance(painted, style: style, font: font, size: size, bold: bold, italic: italic)
                        if x > left, x + length > width - right { finishLine() }
                        lineHeight = max(lineHeight, size * 1.3)
                        lineSize = max(lineSize, size)
                        if y + lineHeight > height || length > width - left - right { warn("Text extends beyond its preview frame; all source text remains in the document.") }
                        spans += "<tspan fill=\"\(color)\" font-family=\"\(escape(font))\" font-size=\"\(size)\" font-weight=\"\(bold ? 700 : 400)\" font-style=\"\(italic ? "italic" : "normal")\">\(escape(painted))</tspan>"
                        x += length
                        if hardBreak { finishLine() }
                    }
                }
            }
            if !spans.isEmpty { finishLine() }
            clipIndex += 1
            return "<defs><clipPath id=\"keyx-text-\(clipIndex)\"><rect width=\"\(width)\" height=\"\(height)\"/></clipPath></defs><g clip-path=\"url(#keyx-text-\(clipIndex))\">\(output)</g>"
        }

        mutating func tableSVG(_ node: KeyxNode, width: Double, height: Double) throws -> String {
            remainingCells = min(remainingCells, document.limits.tableCells)
            let grid = try KeyxDocument.tableGrid(node, remainingCells: &remainingCells)
            let rows = node["content"]?.array ?? []
            let columns = node["column_headers"]?.array ?? []
            if node["merges"]?.array?.isEmpty == false { warn("Merged table cells are preserved but shown as an unmerged preview grid.") }
            if node["transformation"] != nil { warn("Table filtering/sorting is preserved but not applied to the preview.") }
            let columnCount = grid.first?.count ?? 1
            var output = "", y = 0.0
            var rowNodes: [Int: KeyxValue] = [:], nextRow = 0
            for row in rows {
                let r = row["row_index"]?.integer ?? nextRow; rowNodes[r] = row; nextRow = r + 1
            }
            for (r, values) in grid.enumerated() {
                let row = rowNodes[r]
                let rh = row?["row_height"]?.double ?? node["default_row_height"]?.double ?? height / Double(grid.count)
                var x = 0.0
                for (c, string) in values.enumerated() {
                    let cw = columns.indices.contains(c) ? (columns[c]["column_width"]?.double ?? width / Double(columnCount)) : width / Double(columnCount)
                    let fill = try paint(row?["cell_properties"]?["fill"], fallback: r < (node["number_of_header_rows"]?.integer ?? 0) ? "#D5E4E9" : "#FFFFFF")
                    output += "<g transform=\"translate(\(x) \(y))\"><rect width=\"\(cw)\" height=\"\(rh)\" fill=\"\(fill)\" stroke=\"#B6C2C9\" stroke-width=\"0.5\"/>"
                    var owner = KeyxNode()
                    if let style = row?["text_properties"] { owner["paragraph_properties"] = style }
                    output += try textSVG(KeyxText(string).node, owner: owner, width: cw, height: rh) + "</g>"
                    x += cw
                }
                y += rh
            }
            warn("Table preview approximates cell formatting and borders; formulas are not evaluated.")
            return output
        }

        mutating func chartSVG(_ node: KeyxNode, width: Double, height: Double) throws -> String {
            let chart = try KeyxChartSummary(node: node)
            guard ["bar", "column", "line", "pie"].contains(chart.kind) else { throw KeyxError.unsupported("This chart type has no preview adapter") }
            let palette = ["#276D89", "#D99A36", "#7A63A8", "#3B8E72", "#B85562"]
            let numbers = chart.values.flatMap { $0.compactMap { $0 } }
            guard !numbers.isEmpty else { throw KeyxError.unsupported("Chart has no numeric values to preview") }
            warn("Chart preview uses a simplified numeric plot; native chart styling and axes can differ.")
            var output = ""
            if chart.kind == "pie" {
                let values = chart.values.first ?? []
                guard values.allSatisfy({ ($0 ?? 0) >= 0 }), values.compactMap({ $0 }).reduce(0, +) > 0 else {
                    throw KeyxError.unsupported("Pie preview requires nonnegative values")
                }
                let total = values.compactMap { $0 }.reduce(0, +)
                let radius = min(width, height) * 0.4, cx = width / 2, cy = height / 2
                var angle = -Double.pi / 2
                for (i, value) in values.enumerated() {
                    let delta = (value ?? 0) / total * 2 * .pi, end = angle + delta
                    if delta >= 2 * .pi - 0.000001 {
                        output += "<circle cx=\"\(cx)\" cy=\"\(cy)\" r=\"\(radius)\" fill=\"\(palette[i % palette.count])\"/>"
                    } else if delta > 0 {
                        output += "<path d=\"M \(cx) \(cy) L \(cx + radius * cos(angle)) \(cy + radius * sin(angle)) A \(radius) \(radius) 0 \(delta > .pi ? 1 : 0) 1 \(cx + radius * cos(end)) \(cy + radius * sin(end)) Z\" fill=\"\(palette[i % palette.count])\"/>"
                    }
                    angle = end
                }
                return output
            }
            let minValue = min(0, numbers.min() ?? 0), maxValue = max(0, numbers.max() ?? 1)
            let range = max(1e-12, maxValue - minValue)
            let plotW = max(1, width - 50), plotH = max(1, height - 45)
            let baseline = 10 + maxValue / range * plotH
            let count = max(1, chart.values.map(\.count).max() ?? chart.categories.count)
            let slot = plotW / Double(count)
            for (s, values) in chart.values.enumerated() {
                var points: [String] = []
                for (c, value) in values.enumerated() {
                    guard let value else { continue }
                    let x = 35 + (Double(c) + 0.5) * slot
                    let y = 10 + (maxValue - value) / range * plotH
                    if chart.kind == "line" {
                        points.append("\(x),\(y)")
                        output += "<circle cx=\"\(x)\" cy=\"\(y)\" r=\"3\" fill=\"\(palette[s % palette.count])\"/>"
                    } else {
                        let bw = slot * 0.7 / Double(max(1, chart.values.count))
                        output += "<rect x=\"\(x - slot * 0.35 + Double(s) * bw)\" y=\"\(min(y, baseline))\" width=\"\(bw)\" height=\"\(abs(baseline - y))\" fill=\"\(palette[s % palette.count])\"/>"
                    }
                }
                if chart.kind == "line" { output += "<polyline points=\"\(points.joined(separator: " "))\" fill=\"none\" stroke=\"\(palette[s % palette.count])\" stroke-width=\"2\"/>" }
            }
            for (i, label) in chart.categories.enumerated() {
                output += "<text x=\"\(35 + (Double(i) + 0.5) * slot)\" y=\"\(height - 8)\" text-anchor=\"middle\" font-size=\"12\">\(escape(label))</text>"
            }
            if chart.kind == "bar" { warn("Horizontal bar charts are previewed as vertical columns.") }
            return output
        }
    }
}

private func escape(_ value: String) -> String {
    value.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
        .replacingOccurrences(of: "'", with: "&apos;")
}
