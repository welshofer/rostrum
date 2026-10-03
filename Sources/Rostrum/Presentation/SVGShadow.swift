import Foundation

enum SVGShadow {
    /// Simple outer shadows: source alpha -> blur -> offset -> color -> merge.
    /// User-space bounds include the blur and offset instead of SVG's default
    /// ten-percent crop. All coordinates are bounded before filter allocation.
    static func wrap(_ content: String, shadow: XML.Element, frame: (Int, Int, Int, Int),
                     theme: Theme, rotation: Double, flipH: Bool, flipV: Bool,
                     defs: inout SVGDefinitions) -> String {
        guard !content.isEmpty, let paint = SVGPaint.resolve(in: shadow, theme: theme), paint.opacity > 0 else { return content }
        let limit = Double(max(1, max(frame.2, frame.3)))
        let blur = min(limit, Double(max(0, shadow.coordinate("blurRad") ?? 0))) / 2
        let distance = min(limit * 2, Double(max(0, shadow.coordinate("dist") ?? 0)))
        var angle = Double(shadow.boundedInt("dir", in: 0...21_599_999) ?? 0) / 60_000
        let rotates = ["1", "true"].contains(shadow[attribute: "rotWithShape"] ?? "1")
        if !rotates { angle -= rotation }
        var dx = distance * cos(angle * .pi / 180), dy = distance * sin(angle * .pi / 180)
        if !rotates {
            if flipH { dx = -dx }
            if flipV { dy = -dy }
        }
        if abs(dx) < 1e-8 { dx = 0 }
        if abs(dy) < 1e-8 { dy = 0 }
        let pad = blur * 3 + max(abs(dx), abs(dy)) + 12_700
        let id = defs.nextID("shadow")
        defs += """
        <filter id="\(id)" filterUnits="userSpaceOnUse" x="\(Double(frame.0) - pad)" y="\(Double(frame.1) - pad)" width="\(Double(max(1, frame.2)) + 2 * pad)" height="\(Double(max(1, frame.3)) + 2 * pad)" color-interpolation-filters="sRGB">
        <feGaussianBlur in="SourceAlpha" stdDeviation="\(blur)" result="blur"/>
        <feOffset in="blur" dx="\(dx)" dy="\(dy)" result="offset"/>
        <feFlood flood-color="\(paint.hex)" flood-opacity="\(paint.opacity)" result="color"/>
        <feComposite in="color" in2="offset" operator="in" result="shadow"/>
        <feComposite in="shadow" in2="SourceAlpha" operator="out" result="outer"/>
        </filter>
        """
        // Only the shadow is clipped to the filter region. Text can legitimately
        // flow outside the shape, so paint the original source separately.
        return "<g filter=\"url(#\(id))\">\(content)</g>\(content)"
    }
}
