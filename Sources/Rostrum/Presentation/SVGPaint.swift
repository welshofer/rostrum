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

/// A resolved preview paint. Resolution is shared with tables, backgrounds and
/// rich text through `DrawingColor`; this adds only the SVG serialization.
struct SVGPaint {
    static let colorElements = DrawingColor.colorElements
    let color: Color
    let opacity: Double
    var hex: String { "#" + color.hex }
    var css: String {
        opacity == 1 ? hex : "rgba(\(color.red),\(color.green),\(color.blue),\(opacity))"
    }

    static func resolve(in container: XML.Element?, theme: Theme) -> Self? {
        DrawingColor.resolve(in: container, theme: theme).map { Self(color: $0.color, opacity: $0.alpha) }
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
