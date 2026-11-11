import Foundation

/// A deliberately small, self-contained SVG image subset. Keep the original
/// package bytes; reject active/external content instead of executing or stripping it.
enum SVGEmbeddedImage {
    static func svgReference(in blip: XML.Element) -> String? {
        blip.firstChild(named: "a:extLst")?
            .children(named: "a:ext").compactMap {
                $0.firstChild(named: "asvg:svgBlip")?[attribute: "r:embed"]
            }.first
    }

    static func reference(in blip: XML.Element) -> String? {
        svgReference(in: blip) ?? blip[attribute: "r:embed"]
    }

    static func resolve(
        in blip: XML.Element,
        owner: Part,
        package: OPCPackage,
        resources: RenderImageResources
    ) -> RenderImageResources.Resource? {
        if let svgID = svgReference(in: blip),
           let res = resources.resolve(svgID, owner: owner, package: package),
           res.supported {
            return res
        }
        if let embedID = blip[attribute: "r:embed"],
           let res = resources.resolve(embedID, owner: owner, package: package),
           res.supported {
            return res
        }
        if let id = reference(in: blip) {
            return resources.resolve(id, owner: owner, package: package)
        }
        return nil
    }

    static func size(_ data: Data) -> (width: Double, height: Double)? {
        guard data.count <= 4 * 1024 * 1024,
              let source = String(data: data, encoding: .utf8),
              !source.contains("<!"), !source.contains("<?"),
              let root = try? XML.parse(data), root.name == "svg",
              root[attribute: "xmlns"] == "http://www.w3.org/2000/svg" else { return nil }
        let elements: Set<String> = [
            "svg", "g", "path", "rect", "circle", "ellipse", "line", "polyline", "polygon",
            "style", "title", "desc", "defs", "linearGradient", "radialGradient", "stop",
            "clipPath", "mask", "symbol", "use", "text", "tspan"
        ]
        let attributes: Set<String> = [
            "xmlns", "xmlns:xlink", "width", "height", "viewBox", "preserveAspectRatio",
            "fill", "fill-opacity", "fill-rule", "stroke", "stroke-width", "stroke-opacity",
            "stroke-linecap", "stroke-linejoin", "stroke-miterlimit", "stroke-dasharray",
            "stroke-dashoffset", "opacity", "overflow", "transform", "d", "x", "y",
            "x1", "x2", "y1", "y2", "cx", "cy", "r", "rx", "ry", "fx", "fy", "points",
            "class", "id", "gradientUnits", "gradientTransform", "spreadMethod",
            "offset", "stop-color", "stop-opacity", "clip-path", "clip-rule", "clipPathUnits",
            "mask", "maskUnits", "href", "xlink:href", "font-family", "font-size",
            "font-weight", "font-style", "text-anchor", "dominant-baseline", "letter-spacing",
            "visibility", "display", "vector-effect", "paint-order", "color"
        ]
        let fragmentURLPattern = #"^url\(#[A-Za-z_][A-Za-z0-9_.:-]*\)$"#
        let fragmentHrefPattern = #"^#[A-Za-z_][A-Za-z0-9_.:-]*$"#
        var count = 0
        func valid(_ node: XML.Element, depth: Int) -> Bool {
            count += 1
            guard depth < 64, count <= 65536, elements.contains(node.name) else { return false }
            for attribute in node.attributes {
                guard attributes.contains(attribute.name) else { return false }
                if attribute.name.hasPrefix("xmlns") { continue }
                let rawValue = attribute.value.trimmingCharacters(in: .whitespacesAndNewlines)
                let value = rawValue.lowercased()
                guard !value.contains("\\"), !value.contains("&") else { return false }
                if attribute.name == "href" || attribute.name == "xlink:href" {
                    guard rawValue.range(of: fragmentHrefPattern, options: .regularExpression) != nil else {
                        return false
                    }
                    continue
                }
                if value.contains("url") {
                    guard rawValue.range(of: fragmentURLPattern, options: .regularExpression) != nil else {
                        return false
                    }
                }
            }
            if node.name == "style" {
                // Office's solid-color/stroke/fragment-URL class rules; no imports, external URLs or general CSS.
                let pattern = #"^\s*(\.[A-Za-z_][A-Za-z_0-9-]*\s*\{\s*([A-Za-z-]+\s*:\s*([#A-Za-z0-9.,%\s-]+|url\(#[A-Za-z_][A-Za-z0-9_.:-]*\))\s*;?\s*)+\}\s*)*$"#
                let css = node.textContent
                let stripped = css.replacingOccurrences(of: #"url\(#[A-Za-z_][A-Za-z0-9_.:-]*\)"#, with: "", options: .regularExpression)
                guard !stripped.lowercased().contains("url"),
                      !css.contains("@"),
                      !css.contains("\\"),
                      css.range(of: pattern, options: .regularExpression) != nil else { return false }
            }
            return node.childElements.allSatisfy { valid($0, depth: depth + 1) }
        }
        guard valid(root, depth: 0) else { return nil }

        func parseDimension(_ raw: String?) -> Double? {
            guard var s = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
            var scale = 1.0
            if s.hasSuffix("px") {
                s.removeLast(2)
            } else if s.hasSuffix("pt") {
                s.removeLast(2)
                scale = 96.0 / 72.0
            }
            guard let v = Double(s.trimmingCharacters(in: .whitespacesAndNewlines)) else { return nil }
            return v * scale
        }

        var w = parseDimension(root[attribute: "width"])
        var h = parseDimension(root[attribute: "height"])
        if w == nil || h == nil,
           let vb = root[attribute: "viewBox"] {
            let parts = vb.split { $0 == " " || $0 == "," || $0 == "\t" || $0 == "\n" }.compactMap { Double($0) }
            if parts.count == 4 {
                if w == nil { w = parts[2] }
                if h == nil { h = parts[3] }
            }
        }
        guard let width = w, let height = h,
              width.isFinite, height.isFinite, width > 0, height > 0, width <= 1e7, height <= 1e7 else {
            return nil
        }
        return (width * 9525, height * 9525) // SVG CSS pixels are 96 dpi.
    }
}
