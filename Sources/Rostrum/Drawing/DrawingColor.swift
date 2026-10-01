import Foundation

/// Shared DrawingML colour resolution. RGB and opacity stay separate because
/// the public Color value is an opaque sRGB colour.
enum DrawingColor {
    struct Resolved { var color: Color; var alpha: Double }

    static func resolve(in container: XML.Element, theme: Theme?) -> Resolved? {
        let names: Set<String> = ["a:srgbClr", "a:schemeClr", "a:sysClr", "a:scrgbClr", "a:prstClr"]
        guard let node = container.childElements.first(where: { names.contains($0.name) }) else { return nil }
        let base: Color?
        switch node.name {
        case "a:srgbClr": base = node[attribute: "val"].flatMap(Color.init(validating:))
        case "a:sysClr": base = node[attribute: "lastClr"].flatMap(Color.init(validating:))
        case "a:schemeClr": base = node[attribute: "val"].flatMap(SchemeColor.init(rawValue:)).flatMap { theme?.resolve($0) }
        case "a:prstClr":
            let values = ["black":"000000", "white":"FFFFFF", "red":"FF0000", "green":"008000", "blue":"0000FF", "yellow":"FFFF00", "gray":"808080", "cyan":"00FFFF", "magenta":"FF00FF", "transparent":"000000"]
            base = node[attribute: "val"].flatMap { values[$0] }.flatMap(Color.init(validating:))
        case "a:scrgbClr":
            func channel(_ name: String) -> Int {
                let x = max(0, min(1, (Double(node[attribute: name] ?? "") ?? 0) / 100_000))
                let s = x <= 0.0031308 ? x * 12.92 : 1.055 * pow(x, 1 / 2.4) - 0.055
                return Int((s * 255).rounded())
            }
            base = Color(red: channel("r"), green: channel("g"), blue: channel("b"))
        default: base = nil
        }
        guard let base else { return nil }
        guard !node.childElements.isEmpty else { return Resolved(color: base, alpha: 1) }
        var rgb = RGB(base), alpha = 1.0
        for child in node.childElements {
            guard let raw = child[attribute: "val"].flatMap(Double.init), raw.isFinite, abs(raw) <= 2_147_483_647 else { continue }
            let f = raw / 100_000
            switch child.name {
            case "a:tint": rgb = rgb.applying(.tint(f))
            case "a:shade": rgb = rgb.applying(.shade(f))
            case "a:lumMod": rgb = rgb.applying(.lumMod(f))
            case "a:lumOff": rgb = rgb.applying(.lumOff(f))
            case "a:satMod": rgb = rgb.applying(.satMod(f))
            case "a:alpha": alpha = f
            case "a:alphaMod": alpha *= f
            case "a:alphaOff": alpha += f
            default: break
            }
            alpha = max(0, min(1, alpha))
        }
        return Resolved(color: rgb.color, alpha: alpha)
    }
}
