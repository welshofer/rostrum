import Foundation

/// A deliberately small, self-contained SVG image subset. Keep the original
/// package bytes; reject active/external content instead of executing or stripping it.
enum SVGEmbeddedImage {
    static func reference(in blip: XML.Element) -> String? {
        blip[attribute: "r:embed"] ?? blip.firstChild(named: "a:extLst")?
            .children(named: "a:ext").compactMap {
                $0.firstChild(named: "asvg:svgBlip")?[attribute: "r:embed"]
            }.first
    }

    static func size(_ data: Data) -> (width: Double, height: Double)? {
        guard data.count <= 4 * 1024 * 1024,
              let source = String(data: data, encoding: .utf8),
              !source.contains("<!"), !source.contains("<?"),
              let root = try? XML.parse(data), root.name == "svg",
              root[attribute: "xmlns"] == "http://www.w3.org/2000/svg" else { return nil }
        let elements: Set<String> = ["svg", "g", "path", "rect", "circle", "ellipse", "line", "polyline", "polygon", "style", "title", "desc"]
        let attributes: Set<String> = ["xmlns", "xmlns:xlink", "width", "height", "viewBox", "preserveAspectRatio", "fill", "fill-opacity", "fill-rule", "stroke", "stroke-width", "stroke-opacity", "stroke-linecap", "stroke-linejoin", "stroke-miterlimit", "stroke-dasharray", "stroke-dashoffset", "opacity", "overflow", "transform", "d", "x", "y", "x1", "x2", "y1", "y2", "cx", "cy", "r", "rx", "ry", "points", "class", "id"]
        var count = 0
        func valid(_ node: XML.Element, depth: Int) -> Bool {
            count += 1
            guard depth < 64, count <= 65536, elements.contains(node.name) else { return false }
            for attribute in node.attributes {
                guard attributes.contains(attribute.name) else { return false }
                if attribute.name.hasPrefix("xmlns") { continue }
                let value = attribute.value.lowercased()
                guard !value.contains("url"), !value.contains("\\"), !value.contains("&") else { return false }
            }
            if node.name == "style" {
                // Office's solid-color class rules; no imports, URLs or general CSS.
                let pattern = #"^\s*(\.[A-Za-z_][A-Za-z_0-9-]*\s*\{\s*(fill|stroke)\s*:\s*#[A-Fa-f0-9]{6}\s*;?\s*\}\s*)*$"#
                guard node.textContent.range(of: pattern, options: .regularExpression) != nil else { return false }
            }
            return node.childElements.allSatisfy { valid($0, depth: depth + 1) }
        }
        guard valid(root, depth: 0), let w = root[attribute: "width"].flatMap(Double.init),
              let h = root[attribute: "height"].flatMap(Double.init),
              w.isFinite, h.isFinite, w > 0, h > 0, w <= 1e7, h <= 1e7 else { return nil }
        return (w * 9525, h * 9525) // SVG CSS pixels are 96 dpi.
    }
}
