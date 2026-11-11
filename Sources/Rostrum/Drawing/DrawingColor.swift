import Foundation

/// Shared DrawingML colour resolution across all 6 ECMA-376 color models and
/// 26 color transforms. RGB and opacity stay separate because the public Color
/// value is an opaque sRGB colour.
enum DrawingColor {
    struct Resolved { var color: Color; var alpha: Double }

    static let colorElements = ["a:srgbClr", "a:schemeClr", "a:sysClr", "a:scrgbClr", "a:prstClr", "a:hslClr"]
    static let colorElementSet = Set(colorElements)

    static let supportedTransforms: Set<String> = [
        "a:comp", "a:inv", "a:gray", "a:gamma", "a:invGamma",
        "a:tint", "a:shade",
        "a:sat", "a:satOff", "a:satMod",
        "a:lum", "a:lumOff", "a:lumMod",
        "a:hue", "a:hueOff", "a:hueMod",
        "a:red", "a:redOff", "a:redMod",
        "a:green", "a:greenOff", "a:greenMod",
        "a:blue", "a:blueOff", "a:blueMod",
        "a:alpha", "a:alphaOff", "a:alphaMod",
    ]

    static func percentage(_ raw: String?) -> Double? {
        guard let raw, !raw.isEmpty else { return nil }
        if raw.hasSuffix("%") {
            guard let value = Double(raw.dropLast()), value.isFinite, abs(value) <= 2_147_483.647 else { return nil }
            return value / 100
        }
        guard let value = Int64(raw), (-2_147_483_648...2_147_483_647).contains(value) else { return nil }
        return Double(value) / 100_000
    }

    static func isSupportedPreset(_ name: String?) -> Bool {
        guard let name else { return false }
        return name == "transparent" || DrawingColorTables.presets[name] != nil
    }

    static func isSupportedSystemColor(_ element: XML.Element) -> Bool {
        if let lastClr = element[attribute: "lastClr"] {
            return Color(validating: lastClr) != nil
        }
        guard let val = element[attribute: "val"] else { return false }
        return DrawingColorTables.systemColors[val] != nil
    }

    static func isValidHSL(_ element: XML.Element) -> Bool {
        guard element.boundedInt("hue", in: 0...21_600_000) != nil,
              let sat = percentage(element[attribute: "sat"]), (0...1).contains(sat),
              let lum = percentage(element[attribute: "lum"]), (0...1).contains(lum) else { return false }
        return true
    }

    static func isValidScRGB(_ element: XML.Element) -> Bool {
        percentage(element[attribute: "r"]) != nil
            && percentage(element[attribute: "g"]) != nil
            && percentage(element[attribute: "b"]) != nil
    }

    static func resolve(in container: XML.Element, theme: Theme?) -> Resolved? {
        guard let node = container.childElements.first(where: { colorElementSet.contains($0.name) }) else { return nil }
        var rgb: RGB
        var alpha = 1.0

        switch node.name {
        case "a:srgbClr":
            guard let color = node[attribute: "val"].flatMap(Color.init(validating:)) else { return nil }
            rgb = RGB(color)
        case "a:sysClr":
            if let rawLast = node[attribute: "lastClr"] {
                guard let color = Color(validating: rawLast) else { return nil }
                rgb = RGB(color)
            } else if let val = node[attribute: "val"],
                      let hex = DrawingColorTables.systemColors[val],
                      let color = Color(validating: hex) {
                rgb = RGB(color)
            } else {
                return nil
            }
        case "a:schemeClr":
            guard let scheme = node[attribute: "val"].flatMap(SchemeColor.init(rawValue:)),
                  let color = theme?.resolve(scheme) else { return nil }
            rgb = RGB(color)
        case "a:prstClr":
            guard let val = node[attribute: "val"] else { return nil }
            if val == "transparent" {
                rgb = RGB(r: 0, g: 0, b: 0)
                alpha = 0
            } else if let hex = DrawingColorTables.presets[val], let color = Color(validating: hex) {
                rgb = RGB(color)
            } else {
                return nil
            }
        case "a:scrgbClr":
            guard let rawR = percentage(node[attribute: "r"]),
                  let rawG = percentage(node[attribute: "g"]),
                  let rawB = percentage(node[attribute: "b"]) else { return nil }
            func toSRGB(_ linear: Double) -> Double {
                let x = max(0, min(1, linear))
                let s = x <= 0.0031308 ? x * 12.92 : 1.055 * pow(x, 1 / 2.4) - 0.055
                return s * 255
            }
            rgb = RGB(r: toSRGB(rawR), g: toSRGB(rawG), b: toSRGB(rawB))
        case "a:hslClr":
            guard let hue = node.boundedInt("hue", in: 0...21_600_000),
                  let sat = percentage(node[attribute: "sat"]), (0...1).contains(sat),
                  let lum = percentage(node[attribute: "lum"]), (0...1).contains(lum) else { return nil }
            rgb = RGB(hue: Double(hue) / 21_600_000, saturation: sat, lightness: lum)
        default:
            return nil
        }

        guard !node.childElements.isEmpty else { return Resolved(color: rgb.color, alpha: alpha) }

        for transform in node.childElements {
            switch transform.name {
            case "a:comp": rgb = rgb.adjustingHSL { ($0 + 0.5, $1, $2) }; continue
            case "a:inv": rgb = rgb.map { 255 - $0 }; continue
            case "a:gray":
                let gray = rgb.r * 0.2126 + rgb.g * 0.7152 + rgb.b * 0.0722
                rgb = RGB(r: gray, g: gray, b: gray); continue
            case "a:gamma":
                rgb = rgb.map { channel in
                    let c = min(1, max(0, channel / 255))
                    return 255 * (c <= 0.0031308 ? 12.92 * c : 1.055 * pow(c, 1 / 2.4) - 0.055)
                }; continue
            case "a:invGamma":
                rgb = rgb.map { channel in
                    let c = min(1, max(0, channel / 255))
                    return 255 * (c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4))
                }; continue
            default: break
            }
            // DrawingML percentages use integer thousandths of one percent (or % suffix).
            // Reject malformed/unbounded input before arithmetic or SVG output.
            if ["a:hue", "a:hueOff"].contains(transform.name) {
                guard let raw = transform.boundedInt("val", in: -2_147_483_648...2_147_483_647) else { continue }
                switch transform.name {
                case "a:hue" where (0..<21_600_000).contains(raw):
                    rgb = rgb.adjustingHSL { (_, s, l) in (Double(raw) / 21_600_000, s, l) }
                case "a:hueOff":
                    rgb = rgb.adjustingHSL { ($0 + Double(raw) / 21_600_000, $1, $2) }
                default: break
                }
                continue
            }
            guard let value = percentage(transform[attribute: "val"]) else { continue }
            switch transform.name {
            case "a:tint" where (0...1).contains(value): rgb = rgb.applying(.tint(value))
            case "a:shade" where (0...1).contains(value): rgb = rgb.applying(.shade(value))
            case "a:satMod" where value >= 0: rgb = rgb.applying(.satMod(value))
            case "a:sat" where (0...1).contains(value): rgb = rgb.adjustingHSL { ($0, value, $2) }
            case "a:satOff": rgb = rgb.adjustingHSL { ($0, $1 + value, $2) }
            case "a:lum" where (0...1).contains(value): rgb = rgb.adjustingHSL { h, s, _ in (h, s, value) }
            case "a:lumMod" where value >= 0: rgb = rgb.applying(.lumMod(value))
            case "a:lumOff": rgb = rgb.applying(.lumOff(value))
            case "a:hueMod" where value >= 0: rgb = rgb.adjustingHSL { ($0 * value, $1, $2) }
            case "a:red", "a:green", "a:blue", "a:redOff", "a:greenOff", "a:blueOff", "a:redMod", "a:greenMod", "a:blueMod":
                let name = transform.name
                func channel(_ original: Double) -> Double {
                    let result = name.hasSuffix("Off") ? original + value * 255
                        : name.hasSuffix("Mod") ? original * value : value * 255
                    return min(255, max(0, result))
                }
                if name.hasPrefix("a:red") { rgb.r = channel(rgb.r) }
                if name.hasPrefix("a:green") { rgb.g = channel(rgb.g) }
                if name.hasPrefix("a:blue") { rgb.b = channel(rgb.b) }
            case "a:alpha" where (0...1).contains(value): alpha = value
            case "a:alphaMod" where value >= 0: alpha = min(1, alpha * value)
            case "a:alphaOff": alpha = min(1, max(0, alpha + value))
            default: continue
            }
        }
        return Resolved(color: rgb.color, alpha: alpha)
    }
}
