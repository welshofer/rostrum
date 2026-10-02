import Foundation

/// The supported DrawingML double-line subset. Keep this predicate shared by
/// rendering and diagnostics so unsupported combinations remain visible.
enum TableDoubleBorder {
    static func supports(_ line: XML.Element) -> Bool {
        line[attribute: "cmpd"] == "dbl"
            && line.firstChild(named: "a:solidFill") != nil
            && line.firstChild(named: "a:noFill") == nil
            && (line[attribute: "cap"] ?? "flat") == "flat"
            && (line[attribute: "algn"] ?? "ctr") == "ctr"
            && (line.firstChild(named: "a:prstDash")?[attribute: "val"] ?? "solid") == "solid"
            && ["a:custDash", "a:headEnd", "a:tailEnd", "a:round", "a:bevel"].allSatisfy {
                line.firstChild(named: $0) == nil
            }
    }

    static func svg(color: String, width: Int, endpoints: (Int, Int, Int, Int),
                    startExtension: Double = 0, endExtension: Double = 0) -> String {
        let vertical = endpoints.0 == endpoints.2
        let x1 = Double(endpoints.0) - (vertical ? 0 : startExtension)
        let y1 = Double(endpoints.1) - (vertical ? startExtension : 0)
        let x2 = Double(endpoints.2) + (vertical ? 0 : endExtension)
        let y2 = Double(endpoints.3) + (vertical ? endExtension : 0)
        let dx = x2 - x1, dy = y2 - y1
        let length = hypot(dx, dy)
        guard length > 0, width > 0 else { return "" }
        // The pinned PowerPoint PDF uses equal stroke/gap/stroke thirds.
        // Translate along the normal, including diagonals; never paint the gap
        // with a background color, which would destroy underlying cell fills.
        let component = Double(width) / 3
        let offsetX = -dy / length * component, offsetY = dx / length * component
        return [-1.0, 1.0].map { side in
            let coordinates = "x1=\"\(SVGNumber.decimal(x1 + side * offsetX))\" y1=\"\(SVGNumber.decimal(y1 + side * offsetY))\" x2=\"\(SVGNumber.decimal(x2 + side * offsetX))\" y2=\"\(SVGNumber.decimal(y2 + side * offsetY))\""
            return "<line \(coordinates) stroke=\"\(color)\" stroke-width=\"\(SVGNumber.decimal(component))\"/>"
        }.joined()
    }
}
