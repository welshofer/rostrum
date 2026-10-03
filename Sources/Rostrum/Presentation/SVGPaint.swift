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

/// Bounded preview subset; not a complete DrawingML color interpreter.
struct SVGPaint {
    static let colorElements = ["a:srgbClr", "a:schemeClr", "a:sysClr"]
    let color: Color
    let opacity: Double
    var hex: String { "#" + color.hex }
    var css: String {
        opacity == 1 ? hex : "rgba(\(color.red),\(color.green),\(color.blue),\(opacity))"
    }

    static func resolve(in container: XML.Element?, theme: Theme) -> Self? {
        guard let element = container?.childElements.first(where: { colorElements.contains($0.name) }) else { return nil }
        let base: Color?
        switch element.name {
        case "a:schemeClr":
            base = element[attribute: "val"].flatMap(SchemeColor.init(rawValue:)).flatMap { theme.resolve($0) }
        case "a:sysClr": base = element[attribute: "lastClr"].flatMap(Color.init(validating:))
        default: base = element[attribute: "val"].flatMap(Color.init(validating:))
        }
        guard let base else { return nil }
        var rgb = RGB(base), alpha = 1.0
        for transform in element.childElements {
            // DrawingML percentages use integer thousandths of one percent.
            // Reject malformed/unbounded input before arithmetic or SVG output.
            guard let raw = transform.boundedInt("val", in: -2_147_483_648...2_147_483_647) else { continue }
            let value = Double(raw) / 100_000
            switch transform.name {
            case "a:tint" where (0...1).contains(value): rgb = rgb.applying(.tint(value))
            case "a:shade" where (0...1).contains(value): rgb = rgb.applying(.shade(value))
            case "a:satMod" where value >= 0: rgb = rgb.applying(.satMod(value))
            case "a:alpha" where (0...1).contains(value): alpha = value
            case "a:alphaMod" where value >= 0: alpha = min(1, alpha * value)
            case "a:alphaOff": alpha = min(1, max(0, alpha + value))
            default: continue
            }
        }
        return Self(color: rgb.color, opacity: alpha)
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
}
