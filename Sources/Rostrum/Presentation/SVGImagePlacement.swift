import Foundation

/// Map the retained source rectangle into the saved destination rectangle.
/// Source percentages can be negative (outset); never replace an authored crop
/// with an aspect-ratio heuristic. A viewport clips only the image's frame.
enum SVGImagePlacement {
    static func render(_ fill: XML.Element, data: String, width: Double, height: Double) -> String? {
        guard width > 0, height > 0 else { return nil }
        func fraction(_ element: XML.Element?, _ key: String) -> Double {
            Double(element?.boundedInt(key, in: -1_000_000...1_000_000) ?? 0) / 100_000
        }
        let source = fill.firstChild(named: "a:srcRect")
        let l = fraction(source, "l"), t = fraction(source, "t")
        let retainedW = 1 - l - fraction(source, "r"), retainedH = 1 - t - fraction(source, "b")
        guard retainedW >= 0.00001, retainedH >= 0.00001 else { return nil }
        let destination = fill.firstChild(named: "a:stretch")?.firstChild(named: "a:fillRect")
        let dl = fraction(destination, "l"), dt = fraction(destination, "t")
        let dw = width * (1 - dl - fraction(destination, "r")), dh = height * (1 - dt - fraction(destination, "b"))
        guard dw > 0, dh > 0 else { return nil }
        let iw = dw / retainedW, ih = dh / retainedH
        let x = width * dl - l * iw, y = height * dt - t * ih
        return "<svg width=\"\(width)\" height=\"\(height)\" viewBox=\"0 0 \(width) \(height)\" overflow=\"hidden\"><image x=\"\(x)\" y=\"\(y)\" width=\"\(iw)\" height=\"\(ih)\" preserveAspectRatio=\"none\" href=\"\(data)\"/></svg>"
    }
}
