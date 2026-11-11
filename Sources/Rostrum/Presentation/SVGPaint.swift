import Foundation

/// Per-render IDs avoid scanning an ever-growing string (including embedded
/// image data). No shared state or cache can outlive a render or hide edits.
struct SVGDefinitions: CustomStringConvertible {
    private var serial = 0
    private var xml = ""
    var description: String { xml }

    mutating func nextID(_ prefix: String) -> String {
        defer { serial += 1 }
        return "\(prefix)\(serial)"
    }

    static func += (lhs: inout Self, rhs: String) { lhs.xml += rhs }
}

/// Resolves DrawingML paint across all 6 color models and 26 color transforms.
struct SVGPaint {
    static let colorElements = DrawingColor.colorElements
    let color: Color
    let opacity: Double
    var hex: String { "#" + color.hex }
    var css: String {
        opacity == 1 ? hex : "rgba(\(color.red),\(color.green),\(color.blue),\(opacity))"
    }

    static func resolve(in container: XML.Element?, theme: Theme) -> Self? {
        guard let container, let resolved = DrawingColor.resolve(in: container, theme: theme) else { return nil }
        return Self(color: resolved.color, opacity: resolved.alpha)
    }

    /// DrawingML's clockwise vector, scaled by the fill bounds when requested.
    /// Project all corners onto the vector so endpoint stops span the rectangle.
    static func gradientVector(_ line: XML.Element?, frame: (Int, Int, Int, Int)) -> (Double, Double, Double, Double) {
        let angle = Double(line?.boundedInt("ang", in: 0...21_599_999) ?? 0) / 60_000 * .pi / 180
        let w = Double(max(0, frame.2)), h = Double(max(0, frame.3))
        let scaled = ["1", "true"].contains(line?[attribute: "scaled"] ?? "0")
        var dx = cos(angle) * (scaled ? w : 1), dy = sin(angle) * (scaled ? h : 1)
        let magnitude = hypot(dx, dy)
        if magnitude > 0 { dx /= magnitude; dy /= magnitude }
        if abs(dx) < 1e-12 { dx = 0 }
        if abs(dy) < 1e-12 { dy = 0 }
        let half = (abs(w * dx) + abs(h * dy)) / 2
        let cx = Double(frame.0) + w / 2, cy = Double(frame.1) + h / 2
        return (cx - half * dx, cy - half * dy, cx + half * dx, cy + half * dy)
    }

    /// Computes `<radialGradient>` attributes (`cx`, `cy`, `fx`, `fy`, `r`) from `<a:path>` / `<a:fillToRect>`.
    static func radialGradientAttributes(_ path: XML.Element?) -> String {
        guard let fillToRect = path?.firstChild(named: "a:fillToRect")
            ?? path?.firstChild(named: "a:path")?.firstChild(named: "a:fillToRect") else { return "" }
        let l = Double(fillToRect.boundedInt("l", in: -100_000...200_000) ?? 50_000) / 100_000
        let t = Double(fillToRect.boundedInt("t", in: -100_000...200_000) ?? 50_000) / 100_000
        let r = Double(fillToRect.boundedInt("r", in: -100_000...200_000) ?? 50_000) / 100_000
        let b = Double(fillToRect.boundedInt("b", in: -100_000...200_000) ?? 50_000) / 100_000
        let fx = (l + (1 - r)) / 2
        let fy = (t + (1 - b)) / 2
        if abs(fx - 0.5) < 1e-6 && abs(fy - 0.5) < 1e-6 { return "" }
        let radius = max(0.5, hypot(max(fx, 1 - fx), max(fy, 1 - fy)))
        return " cx=\"\(SVGNumber.decimal(fx))\" cy=\"\(SVGNumber.decimal(fy))\" fx=\"\(SVGNumber.decimal(fx))\" fy=\"\(SVGNumber.decimal(fy))\" r=\"\(SVGNumber.decimal(radius))\""
    }

    static func isRenderableColorContainer(_ container: XML.Element?) -> Bool {
        guard let container,
              let color = container.childElements.first(where: { colorElements.contains($0.name) }) else {
            return false
        }
        if color.childElements.contains(where: { $0.name != "a:extLst" && !DrawingColor.supportedTransforms.contains($0.name) }) {
            return false
        }
        switch color.name {
        case "a:srgbClr":
            return color[attribute: "val"].flatMap(Color.init(validating:)) != nil
        case "a:schemeClr":
            return color[attribute: "val"] != nil
        case "a:prstClr":
            return DrawingColor.isSupportedPreset(color[attribute: "val"])
        case "a:sysClr":
            return DrawingColor.isSupportedSystemColor(color)
        case "a:hslClr":
            return DrawingColor.isValidHSL(color)
        case "a:scrgbClr":
            return DrawingColor.isValidScRGB(color)
        default:
            return false
        }
    }

    static func isRenderablePatternFill(_ element: XML.Element) -> Bool {
        guard let prst = element[attribute: "prst"],
              PatternFillPreset(rawValue: prst) != nil,
              isRenderableColorContainer(element.firstChild(named: "a:fgClr")),
              isRenderableColorContainer(element.firstChild(named: "a:bgClr")) else {
            return false
        }
        return true
    }

    static func patternSVG(id: String, element: XML.Element, theme: Theme) -> String? {
        guard let prst = element[attribute: "prst"],
              let preset = PatternFillPreset(rawValue: prst),
              let fg = resolve(in: element.firstChild(named: "a:fgClr"), theme: theme)?.css,
              let bg = resolve(in: element.firstChild(named: "a:bgClr"), theme: theme)?.css else {
            return nil
        }
        // 8x8 grid scaled into EMU (1 pt = 12700 EMU -> 8 pt = 101600 EMU tile).
        let u = 12700
        let size = 8 * u
        var fgShapes = ""
        func rect(_ x: Int, _ y: Int, _ w: Int, _ h: Int) {
            fgShapes += "<rect x=\"\(x * u)\" y=\"\(y * u)\" width=\"\(w * u)\" height=\"\(h * u)\" fill=\"\(fg)\"/>"
        }
        func line(_ x1: Int, _ y1: Int, _ x2: Int, _ y2: Int, width: Int = 1) {
            fgShapes += "<line x1=\"\(x1 * u)\" y1=\"\(y1 * u)\" x2=\"\(x2 * u)\" y2=\"\(y2 * u)\" stroke=\"\(fg)\" stroke-width=\"\(width * u)\"/>"
        }
        switch preset {
        case .pct5:
            rect(0, 0, 1, 1); rect(4, 4, 1, 1)
        case .pct10:
            rect(0, 0, 1, 1); rect(4, 2, 1, 1); rect(2, 4, 1, 1); rect(6, 6, 1, 1)
        case .pct20:
            for y in stride(from: 0, to: 8, by: 2) {
                for x in stride(from: (y / 2) % 2 == 0 ? 0 : 2, to: 8, by: 4) { rect(x, y, 1, 1) }
            }
        case .pct25:
            for y in stride(from: 0, to: 8, by: 2) {
                for x in stride(from: (y / 2) % 2, to: 8, by: 2) { rect(x, y, 1, 1) }
            }
        case .pct30:
            for y in stride(from: 0, to: 8, by: 2) {
                for x in stride(from: 0, to: 8, by: 2) { rect(x, y, 1, 1) }
            }
            rect(1, 1, 1, 1); rect(5, 5, 1, 1)
        case .pct40:
            for y in 0..<8 {
                for x in stride(from: y % 2, to: 8, by: 2) where (x + y) % 3 != 0 { rect(x, y, 1, 1) }
            }
        case .pct50, .smCheck:
            for y in 0..<8 {
                for x in stride(from: y % 2, to: 8, by: 2) { rect(x, y, 1, 1) }
            }
        case .pct60:
            for y in 0..<8 {
                for x in 0..<8 where (x + y) % 2 == 0 || (x % 4 == 1 && y % 4 == 1) { rect(x, y, 1, 1) }
            }
        case .pct70:
            for y in 0..<8 {
                for x in 0..<8 where !((x + y) % 2 == 1 && (x % 2 == 1)) { rect(x, y, 1, 1) }
            }
        case .pct75:
            for y in 0..<8 {
                for x in 0..<8 where !(x % 2 == 1 && y % 2 == 1) { rect(x, y, 1, 1) }
            }
        case .pct80:
            for y in 0..<8 {
                for x in 0..<8 where !(x % 4 == 0 && y % 2 == 0) { rect(x, y, 1, 1) }
            }
        case .pct90:
            for y in 0..<8 {
                for x in 0..<8 where !(x % 4 == 0 && y % 4 == 0) { rect(x, y, 1, 1) }
            }
        case .horz, .ltHorz:
            rect(0, 0, 8, 1); rect(0, 4, 8, 1)
        case .narHorz:
            for y in stride(from: 0, to: 8, by: 2) { rect(0, y, 8, 1) }
        case .dkHorz:
            rect(0, 0, 8, 2); rect(0, 4, 8, 2)
        case .dashHorz:
            rect(0, 0, 4, 1); rect(4, 4, 4, 1)
        case .vert, .ltVert:
            rect(0, 0, 1, 8); rect(4, 0, 1, 8)
        case .narVert:
            for x in stride(from: 0, to: 8, by: 2) { rect(x, 0, 1, 8) }
        case .dkVert:
            rect(0, 0, 2, 8); rect(4, 0, 2, 8)
        case .dashVert:
            rect(0, 0, 1, 4); rect(4, 4, 1, 4)
        case .cross, .lgGrid:
            rect(0, 0, 8, 1); rect(0, 0, 1, 8)
        case .smGrid:
            for i in stride(from: 0, to: 8, by: 2) { rect(0, i, 8, 1); rect(i, 0, 1, 8) }
        case .dotGrid:
            for i in stride(from: 0, to: 8, by: 2) { rect(i, 0, 1, 1); rect(0, i, 1, 1) }
        case .dnDiag, .ltDnDiag:
            line(0, 0, 8, 8); line(-4, 4, 4, 12); line(4, -4, 12, 4)
        case .upDiag, .ltUpDiag:
            line(0, 8, 8, 0); line(-4, 4, 4, -4); line(4, 12, 12, 4)
        case .dkDnDiag, .wdDnDiag:
            line(0, 0, 8, 8, width: 2); line(-4, 4, 4, 12, width: 2); line(4, -4, 12, 4, width: 2)
        case .dkUpDiag, .wdUpDiag:
            line(0, 8, 8, 0, width: 2); line(-4, 4, 4, -4, width: 2); line(4, 12, 12, 4, width: 2)
        case .dashDnDiag:
            line(0, 0, 4, 4); line(4, 4, 8, 8)
        case .dashUpDiag:
            line(0, 8, 4, 4); line(4, 4, 8, 0)
        case .diagCross, .trellis:
            line(0, 0, 8, 8); line(0, 8, 8, 0)
        case .lgCheck:
            rect(0, 0, 4, 4); rect(4, 4, 4, 4)
        case .smConfetti, .lgConfetti, .sphere, .divot:
            rect(1, 1, 2, 2); rect(5, 4, 2, 2); rect(2, 6, 1, 1); rect(6, 1, 1, 1)
        case .horzBrick, .shingle:
            rect(0, 0, 8, 1); rect(0, 4, 8, 1); rect(0, 0, 1, 4); rect(4, 4, 1, 4)
        case .diagBrick, .weave, .plaid:
            line(0, 0, 8, 8); line(0, 4, 4, 0); line(4, 8, 8, 4)
        case .solidDmnd:
            fgShapes += "<polygon points=\"\(4 * u),0 \(8 * u),\(4 * u) \(4 * u),\(8 * u) 0,\(4 * u)\" fill=\"\(fg)\"/>"
        case .openDmnd, .dotDmnd:
            fgShapes += "<polygon points=\"\(4 * u),0 \(8 * u),\(4 * u) \(4 * u),\(8 * u) 0,\(4 * u)\" fill=\"none\" stroke=\"\(fg)\" stroke-width=\"\(u)\"/>"
        case .wave, .zigZag:
            fgShapes += "<polyline points=\"0,\(4 * u) \(2 * u),\(2 * u) \(4 * u),\(4 * u) \(6 * u),\(6 * u) \(8 * u),\(4 * u)\" fill=\"none\" stroke=\"\(fg)\" stroke-width=\"\(u)\"/>"
        }
        return "<pattern id=\"\(id)\" patternUnits=\"userSpaceOnUse\" width=\"\(size)\" height=\"\(size)\">"
            + "<rect width=\"\(size)\" height=\"\(size)\" fill=\"\(bg)\"/>"
            + fgShapes
            + "</pattern>"
    }

    static let supportedBlipEffects: Set<String> = [
        "a:extLst", "a:alphaModFix", "a:grayscl", "a:biLevel", "a:lum", "a:duotone",
    ]

    static func hasUnsupportedBlipEffects(_ blip: XML.Element) -> Bool {
        for child in blip.childElements {
            if !supportedBlipEffects.contains(child.name) { return true }
            if child.name == "a:duotone" {
                let colors = child.childElements.filter { colorElements.contains($0.name) }
                if colors.count < 2 { return true }
            }
        }
        return false
    }

    static func blipFilterSVG(id: String, blip: XML.Element, theme: Theme) -> (filterDef: String?, opacity: Double?) {
        var opacity: Double?
        var primitives = ""
        for child in blip.childElements {
            switch child.name {
            case "a:alphaModFix":
                let amt = Double(child.boundedInt("amt", in: 0...100_000) ?? 100_000) / 100_000
                opacity = (opacity ?? 1.0) * amt
            case "a:grayscl":
                primitives += "<feColorMatrix type=\"saturate\" values=\"0\"/>"
            case "a:biLevel":
                let thresh = Double(child.boundedInt("thresh", in: 0...100_000) ?? 50_000) / 100_000
                let steps = max(2, min(20, Int((1.0 / max(0.05, min(thresh, 1 - thresh))).rounded())))
                let zeros = max(1, min(steps - 1, Int((thresh * Double(steps)).rounded())))
                let table = (Array(repeating: "0", count: zeros) + Array(repeating: "1", count: steps - zeros)).joined(separator: " ")
                primitives += "<feColorMatrix type=\"saturate\" values=\"0\"/>"
                    + "<feComponentTransfer><feFuncR type=\"discrete\" tableValues=\"\(table)\"/>"
                    + "<feFuncG type=\"discrete\" tableValues=\"\(table)\"/>"
                    + "<feFuncB type=\"discrete\" tableValues=\"\(table)\"/></feComponentTransfer>"
            case "a:lum":
                let bright = Double(child.boundedInt("bright", in: -100_000...100_000) ?? 0) / 100_000
                let contrast = Double(child.boundedInt("contrast", in: -100_000...100_000) ?? 0) / 100_000
                let slope = max(0, 1 + contrast)
                let intercept = bright + (1 - slope) * 0.5
                let s = SVGNumber.decimal(slope), ic = SVGNumber.decimal(intercept)
                primitives += "<feComponentTransfer>"
                    + "<feFuncR type=\"linear\" slope=\"\(s)\" intercept=\"\(ic)\"/>"
                    + "<feFuncG type=\"linear\" slope=\"\(s)\" intercept=\"\(ic)\"/>"
                    + "<feFuncB type=\"linear\" slope=\"\(s)\" intercept=\"\(ic)\"/>"
                    + "</feComponentTransfer>"
            case "a:duotone":
                let colorNodes = child.childElements.filter { colorElements.contains($0.name) }
                guard colorNodes.count >= 2,
                      let c0 = DrawingColor.resolve(in: XML.Element("c", children: [.element(colorNodes[0])]), theme: theme)?.color,
                      let c1 = DrawingColor.resolve(in: XML.Element("c", children: [.element(colorNodes[1])]), theme: theme)?.color else {
                    break
                }
                let r0 = SVGNumber.decimal(Double(c0.red) / 255), r1 = SVGNumber.decimal(Double(c1.red) / 255)
                let g0 = SVGNumber.decimal(Double(c0.green) / 255), g1 = SVGNumber.decimal(Double(c1.green) / 255)
                let b0 = SVGNumber.decimal(Double(c0.blue) / 255), b1 = SVGNumber.decimal(Double(c1.blue) / 255)
                primitives += "<feColorMatrix type=\"saturate\" values=\"0\"/>"
                    + "<feComponentTransfer>"
                    + "<feFuncR type=\"table\" tableValues=\"\(r0) \(r1)\"/>"
                    + "<feFuncG type=\"table\" tableValues=\"\(g0) \(g1)\"/>"
                    + "<feFuncB type=\"table\" tableValues=\"\(b0) \(b1)\"/>"
                    + "</feComponentTransfer>"
            default:
                break
            }
        }
        let filterDef = primitives.isEmpty ? nil : "<filter id=\"\(id)\" color-interpolation-filters=\"sRGB\">\(primitives)</filter>"
        return (filterDef, opacity)
    }
}
