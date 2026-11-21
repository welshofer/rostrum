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
        let maxNodes = 65536
        var count = 0
        var elementsById: [String: XML.Element] = [:]
        func valid(_ node: XML.Element, depth: Int) -> Bool {
            count += 1
            guard depth < 64, count <= maxNodes, elements.contains(node.name) else { return false }
            var seenHref: String?
            var seenXlinkHref: String?
            for attribute in node.attributes {
                guard attributes.contains(attribute.name) else { return false }
                if attribute.name.hasPrefix("xmlns") { continue }
                let rawValue = Self.trimASCIIWhitespace(attribute.value)
                guard !rawValue.utf8.contains(0x5C), !rawValue.utf8.contains(0x26) else { return false }
                if attribute.name == "id" {
                    guard !rawValue.isEmpty, elementsById[rawValue] == nil else { return false }
                    elementsById[rawValue] = node
                }
                if attribute.name == "href" || attribute.name == "xlink:href" {
                    guard Self.isValidFragmentIdentifier(rawValue) else {
                        return false
                    }
                    if attribute.name == "href" { seenHref = rawValue }
                    else { seenXlinkHref = rawValue }
                    continue
                }
                if Self.containsASCIIURLSubstring(rawValue) {
                    guard Self.isValidFragmentURL(rawValue) else {
                        return false
                    }
                }
            }
            if let seenHref, let seenXlinkHref, seenHref != seenXlinkHref {
                return false
            }
            if node.name == "style" {
                // Office's solid-color/stroke/fragment-URL class rules; no imports, external URLs or general CSS.
                guard Self.isValidStyleSheet(node.textContent) else { return false }
            }
            return node.childElements.allSatisfy { valid($0, depth: depth + 1) }
        }
        guard valid(root, depth: 0),
              Self.withinExpandedNodeBudget(root, elementsById: elementsById, limit: maxNodes) else {
            return nil
        }

        func parseDimension(_ raw: String?) -> Double? {
            guard let raw else { return nil }
            var s = Self.trimASCIIWhitespace(raw)
            guard !s.isEmpty else { return nil }
            var scale = 1.0
            if s.hasSuffix("px") {
                s.removeLast(2)
            } else if s.hasSuffix("pt") {
                s.removeLast(2)
                scale = 96.0 / 72.0
            }
            guard let v = Double(Self.trimASCIIWhitespace(s)) else { return nil }
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

    private static func trimASCIIWhitespace(_ raw: String) -> String {
        let bytes = Array(raw.utf8)
        var start = 0
        var end = bytes.count
        while start < end && isASCIIWhitespace(bytes[start]) { start += 1 }
        while end > start && isASCIIWhitespace(bytes[end - 1]) { end -= 1 }
        if start == 0 && end == bytes.count { return raw }
        return String(decoding: bytes[start..<end], as: UTF8.self)
    }

    private static func containsASCIIURLSubstring(_ raw: String) -> Bool {
        let bytes = Array(raw.utf8)
        guard bytes.count >= 3 else { return false }
        for i in 0...(bytes.count - 3) {
            if (bytes[i] | 0x20) == 0x75 && (bytes[i + 1] | 0x20) == 0x72 && (bytes[i + 2] | 0x20) == 0x6C {
                return true
            }
        }
        return false
    }

    private static func isIdentStart(_ b: UInt8) -> Bool {
        (b >= 0x41 && b <= 0x5A) || (b >= 0x61 && b <= 0x7A) || b == 0x5F
    }

    private static func isIdentContinue(_ b: UInt8) -> Bool {
        isIdentStart(b) || (b >= 0x30 && b <= 0x39) || b == 0x2D || b == 0x2E || b == 0x3A
    }

    private static func isCSSIdentContinue(_ b: UInt8) -> Bool {
        isIdentStart(b) || (b >= 0x30 && b <= 0x39) || b == 0x2D
    }

    private static func isASCIIWhitespace(_ b: UInt8) -> Bool {
        b == 0x20 || b == 0x09 || b == 0x0A || b == 0x0D || b == 0x0C
    }

    static func isValidFragmentIdentifier(_ raw: String) -> Bool {
        let bytes = Array(raw.utf8)
        guard bytes.count >= 2, bytes[0] == 0x23, isIdentStart(bytes[1]) else { return false }
        for i in 2..<bytes.count where !isIdentContinue(bytes[i]) {
            return false
        }
        return true
    }

    static func isValidFragmentURL(_ raw: String) -> Bool {
        guard raw.hasPrefix("url(#"), raw.hasSuffix(")") else { return false }
        let inner = "#" + raw.dropFirst(5).dropLast()
        return isValidFragmentIdentifier(String(inner))
    }

    /// Linear-time validator for Office's `.class { prop: value; }` SVG style blocks.
    static func isValidStyleSheet(_ css: String) -> Bool {
        guard !css.utf8.contains(0x40), !css.utf8.contains(0x5C) else { return false }
        let bytes = Array(css.utf8)
        let n = bytes.count
        var i = 0
        while i < n && isASCIIWhitespace(bytes[i]) { i += 1 }
        while i < n {
            guard bytes[i] == 0x2E else { return false } // '.'
            i += 1
            guard i < n, isIdentStart(bytes[i]) else { return false }
            i += 1
            while i < n && isCSSIdentContinue(bytes[i]) { i += 1 }
            while i < n && isASCIIWhitespace(bytes[i]) { i += 1 }
            guard i < n, bytes[i] == 0x7B else { return false } // '{'
            i += 1
            let blockStart = i
            while i < n && bytes[i] != 0x7D {
                if bytes[i] == 0x7B { return false }
                i += 1
            }
            guard i < n, bytes[i] == 0x7D else { return false } // '}'
            let block = String(decoding: bytes[blockStart..<i], as: UTF8.self)
            i += 1
            while i < n && isASCIIWhitespace(bytes[i]) { i += 1 }

            let parts = block.split(separator: ";", omittingEmptySubsequences: false)
            var sawDeclaration = false
            for (idx, rawDecl) in parts.enumerated() {
                let decl = trimASCIIWhitespace(String(rawDecl))
                if decl.isEmpty {
                    // Only a trailing empty segment after ';' is permitted.
                    if idx != parts.count - 1 { return false }
                    continue
                }
                guard let colon = decl.firstIndex(of: ":") else { return false }
                let prop = trimASCIIWhitespace(String(decl[..<colon]))
                let val = trimASCIIWhitespace(String(decl[decl.index(after: colon)...]))
                guard !prop.isEmpty, !val.isEmpty else { return false }
                guard prop.utf8.allSatisfy({
                    ($0 >= 0x41 && $0 <= 0x5A) || ($0 >= 0x61 && $0 <= 0x7A) || $0 == 0x2D
                }) else { return false }
                if isValidFragmentURL(val) {
                    sawDeclaration = true
                    continue
                }
                guard !containsASCIIURLSubstring(val) else { return false }
                guard val.utf8.allSatisfy({ b in
                    (b >= 0x41 && b <= 0x5A) || (b >= 0x61 && b <= 0x7A)
                        || (b >= 0x30 && b <= 0x39)
                        || b == 0x23 || b == 0x2E || b == 0x2C || b == 0x25 || b == 0x2D
                        || isASCIIWhitespace(b)
                }) else { return false }
                sawDeclaration = true
            }
            guard sawDeclaration else { return false }
        }
        return true
    }

    private enum ExpansionState {
        case visiting
        case count(Int)
    }

    private static func withinExpandedNodeBudget(
        _ root: XML.Element,
        elementsById: [String: XML.Element],
        limit: Int
    ) -> Bool {
        var memo: [ObjectIdentifier: ExpansionState] = [:]
        func expanded(_ node: XML.Element, useDepth: Int) -> Int? {
            guard useDepth < 64 else { return nil }
            let key = ObjectIdentifier(node)
            if let existing = memo[key] {
                switch existing {
                case .visiting: return nil
                case .count(let c): return c
                }
            }
            memo[key] = .visiting
            var total = 1
            if node.name == "use" {
                var targetIds: [String] = []
                for attrName in ["href", "xlink:href"] {
                    if let raw = node[attribute: attrName] {
                        let trimmed = trimASCIIWhitespace(raw)
                        if trimmed.hasPrefix("#") {
                            let id = String(trimmed.dropFirst())
                            if !targetIds.contains(id) { targetIds.append(id) }
                        }
                    }
                }
                for targetId in targetIds {
                    if let target = elementsById[targetId] {
                        guard let refWeight = expanded(target, useDepth: useDepth + 1) else { return nil }
                        total += refWeight
                        if total > limit { return nil }
                    }
                }
            }
            for child in node.childElements {
                guard let childWeight = expanded(child, useDepth: useDepth) else { return nil }
                total += childWeight
                if total > limit { return nil }
            }
            memo[key] = .count(total)
            return total
        }
        guard let total = expanded(root, useDepth: 0), total <= limit else { return false }
        return true
    }
}
