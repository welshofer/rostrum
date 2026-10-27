import Foundation

/// Shared DrawingML colour resolution. RGB and opacity stay separate because
/// the public Color value is an opaque sRGB colour. Previews, tables, slide
/// backgrounds and rich text all resolve through this one implementation, so
/// a colour cannot differ by where it is painted.
enum DrawingColor {
    struct Resolved { var color: Color; var alpha: Double }

    /// Every DrawingML colour source (EG_ColorChoice).
    static let colorElements: Set<String> = ["a:srgbClr", "a:schemeClr", "a:sysClr", "a:scrgbClr", "a:prstClr", "a:hslClr"]

    /// The transforms `resolve` applies; any other child is ignored.
    static let supportedTransforms: Set<String> = [
        "a:comp", "a:inv", "a:gray", "a:gamma", "a:invGamma",
        "a:tint", "a:shade", "a:satMod", "a:sat", "a:satOff", "a:lum", "a:lumMod", "a:lumOff",
        "a:hue", "a:hueOff", "a:hueMod",
        "a:red", "a:green", "a:blue", "a:redOff", "a:greenOff", "a:blueOff", "a:redMod", "a:greenMod", "a:blueMod",
        "a:alpha", "a:alphaMod", "a:alphaOff",
    ]

    static func resolve(in container: XML.Element?, theme: Theme?) -> Resolved? {
        guard let node = container?.childElements.first(where: { colorElements.contains($0.name) }),
              let base = baseColor(of: node, theme: theme) else { return nil }
        guard !node.childElements.isEmpty else { return Resolved(color: base, alpha: 1) }
        var rgb = RGB(base), alpha = 1.0
        for transform in node.childElements {
            switch transform.name {
            case "a:comp": rgb = rgb.adjustingHSL { ($0 + 0.5, $1, $2) }; continue
            case "a:inv": rgb = rgb.map { 255 - $0 }; continue
            case "a:gray":
                let gray = rgb.r * 0.2126 + rgb.g * 0.7152 + rgb.b * 0.0722
                rgb = RGB(r: gray, g: gray, b: gray); continue
            case "a:gamma":
                rgb = rgb.map { channel in
                    let c = channel / 255
                    return 255 * (c <= 0.0031308 ? 12.92 * c : 1.055 * pow(c, 1 / 2.4) - 0.055)
                }; continue
            case "a:invGamma":
                rgb = rgb.map { channel in
                    let c = channel / 255
                    return 255 * (c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4))
                }; continue
            default: break
            }
            // DrawingML percentages use integer thousandths of one percent.
            // Reject malformed/unbounded input before arithmetic or output.
            guard let raw = transform.boundedInt("val", in: -2_147_483_648...2_147_483_647) else { continue }
            let value = Double(raw) / 100_000
            switch transform.name {
            case "a:tint" where (0...1).contains(value): rgb = rgb.applying(.tint(value))
            case "a:shade" where (0...1).contains(value): rgb = rgb.applying(.shade(value))
            case "a:satMod" where value >= 0: rgb = rgb.applying(.satMod(value))
            case "a:sat" where (0...1).contains(value): rgb = rgb.adjustingHSL { ($0, value, $2) }
            case "a:satOff": rgb = rgb.adjustingHSL { ($0, $1 + value, $2) }
            case "a:lum" where (0...1).contains(value): rgb = rgb.adjustingHSL { h, s, _ in (h, s, value) }
            case "a:lumMod" where value >= 0: rgb = rgb.applying(.lumMod(value))
            case "a:lumOff": rgb = rgb.applying(.lumOff(value))
            case "a:hue" where (0..<21_600_000).contains(raw): rgb = rgb.adjustingHSL { (_, s, l) in (Double(raw) / 21_600_000, s, l) }
            case "a:hueOff": rgb = rgb.adjustingHSL { ($0 + Double(raw) / 21_600_000, $1, $2) }
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

    private static func baseColor(of node: XML.Element, theme: Theme?) -> Color? {
        switch node.name {
        case "a:srgbClr":
            return node[attribute: "val"].flatMap(Color.init(validating:))
        case "a:schemeClr":
            return node[attribute: "val"].flatMap(SchemeColor.init(rawValue:)).flatMap { theme?.resolve($0) }
        case "a:sysClr":
            // lastClr is the producer's resolved value; the two universal
            // window colours stand in when it is absent.
            if let last = node[attribute: "lastClr"].flatMap(Color.init(validating:)) { return last }
            switch node[attribute: "val"] {
            case "windowText": return Color(red: 0, green: 0, blue: 0)
            case "window": return Color(red: 255, green: 255, blue: 255)
            default: return nil
            }
        case "a:prstClr":
            return node[attribute: "val"].flatMap(presetHex).flatMap(Color.init(validating:))
        case "a:scrgbClr":
            func channel(_ name: String) -> Int {
                let x = max(0, min(1, Double(node.boundedInt(name, in: -2_147_483_648...2_147_483_647) ?? 0) / 100_000))
                let s = x <= 0.0031308 ? x * 12.92 : 1.055 * pow(x, 1 / 2.4) - 0.055
                return Int((s * 255).rounded())
            }
            return Color(red: channel("r"), green: channel("g"), blue: channel("b"))
        case "a:hslClr":
            guard let hue = node.boundedInt("hue", in: 0...21_599_999),
                  let saturation = node.boundedInt("sat", in: -2_147_483_648...2_147_483_647),
                  let luminance = node.boundedInt("lum", in: -2_147_483_648...2_147_483_647) else { return nil }
            return RGB(hue: Double(hue) / 21_600_000, saturation: Double(saturation) / 100_000,
                       lightness: Double(luminance) / 100_000).color
        default:
            return nil
        }
    }

    /// ST_PresetColorVal: the CSS/X11 names, plus Office's dk/lt/med
    /// abbreviations for the dark/light/medium variants.
    static func presetHex(_ name: String) -> String? {
        var key = name.lowercased()
        if key.hasPrefix("dk") { key = "dark" + key.dropFirst(2) }
        else if key.hasPrefix("lt") { key = "light" + key.dropFirst(2) }
        else if key.hasPrefix("med") && !key.hasPrefix("medium") { key = "medium" + key.dropFirst(3) }
        return presetColors[key]
    }

    private static let presetColors: [String: String] = [
        "aliceblue": "F0F8FF", "antiquewhite": "FAEBD7", "aqua": "00FFFF", "aquamarine": "7FFFD4",
        "azure": "F0FFFF", "beige": "F5F5DC", "bisque": "FFE4C4", "black": "000000",
        "blanchedalmond": "FFEBCD", "blue": "0000FF", "blueviolet": "8A2BE2", "brown": "A52A2A",
        "burlywood": "DEB887", "cadetblue": "5F9EA0", "chartreuse": "7FFF00", "chocolate": "D2691E",
        "coral": "FF7F50", "cornflowerblue": "6495ED", "cornsilk": "FFF8DC", "crimson": "DC143C",
        "cyan": "00FFFF", "darkblue": "00008B", "darkcyan": "008B8B", "darkgoldenrod": "B8860B",
        "darkgray": "A9A9A9", "darkgrey": "A9A9A9", "darkgreen": "006400", "darkkhaki": "BDB76B",
        "darkmagenta": "8B008B", "darkolivegreen": "556B2F", "darkorange": "FF8C00", "darkorchid": "9932CC",
        "darkred": "8B0000", "darksalmon": "E9967A", "darkseagreen": "8FBC8F", "darkslateblue": "483D8B",
        "darkslategray": "2F4F4F", "darkslategrey": "2F4F4F", "darkturquoise": "00CED1", "darkviolet": "9400D3",
        "deeppink": "FF1493", "deepskyblue": "00BFFF", "dimgray": "696969", "dimgrey": "696969",
        "dodgerblue": "1E90FF", "firebrick": "B22222", "floralwhite": "FFFAF0", "forestgreen": "228B22",
        "fuchsia": "FF00FF", "gainsboro": "DCDCDC", "ghostwhite": "F8F8FF", "gold": "FFD700",
        "goldenrod": "DAA520", "gray": "808080", "grey": "808080", "green": "008000",
        "greenyellow": "ADFF2F", "honeydew": "F0FFF0", "hotpink": "FF69B4", "indianred": "CD5C5C",
        "indigo": "4B0082", "ivory": "FFFFF0", "khaki": "F0E68C", "lavender": "E6E6FA",
        "lavenderblush": "FFF0F5", "lawngreen": "7CFC00", "lemonchiffon": "FFFACD", "lightblue": "ADD8E6",
        "lightcoral": "F08080", "lightcyan": "E0FFFF", "lightgoldenrodyellow": "FAFAD2", "lightgray": "D3D3D3",
        "lightgrey": "D3D3D3", "lightgreen": "90EE90", "lightpink": "FFB6C1", "lightsalmon": "FFA07A",
        "lightseagreen": "20B2AA", "lightskyblue": "87CEFA", "lightslategray": "778899", "lightslategrey": "778899",
        "lightsteelblue": "B0C4DE", "lightyellow": "FFFFE0", "lime": "00FF00", "limegreen": "32CD32",
        "linen": "FAF0E6", "magenta": "FF00FF", "maroon": "800000", "mediumaquamarine": "66CDAA",
        "mediumblue": "0000CD", "mediumorchid": "BA55D3", "mediumpurple": "9370DB", "mediumseagreen": "3CB371",
        "mediumslateblue": "7B68EE", "mediumspringgreen": "00FA9A", "mediumturquoise": "48D1CC", "mediumvioletred": "C71585",
        "midnightblue": "191970", "mintcream": "F5FFFA", "mistyrose": "FFE4E1", "moccasin": "FFE4B5",
        "navajowhite": "FFDEAD", "navy": "000080", "oldlace": "FDF5E6", "olive": "808000",
        "olivedrab": "6B8E23", "orange": "FFA500", "orangered": "FF4500", "orchid": "DA70D6",
        "palegoldenrod": "EEE8AA", "palegreen": "98FB98", "paleturquoise": "AFEEEE", "palevioletred": "DB7093",
        "papayawhip": "FFEFD5", "peachpuff": "FFDAB9", "peru": "CD853F", "pink": "FFC0CB",
        "plum": "DDA0DD", "powderblue": "B0E0E6", "purple": "800080", "red": "FF0000",
        "rosybrown": "BC8F8F", "royalblue": "4169E1", "saddlebrown": "8B4513", "salmon": "FA8072",
        "sandybrown": "F4A460", "seagreen": "2E8B57", "seashell": "FFF5EE", "sienna": "A0522D",
        "silver": "C0C0C0", "skyblue": "87CEEB", "slateblue": "6A5ACD", "slategray": "708090",
        "slategrey": "708090", "snow": "FFFAFA", "springgreen": "00FF7F", "steelblue": "4682B4",
        "tan": "D2B48C", "teal": "008080", "thistle": "D8BFD8", "tomato": "FF6347",
        "turquoise": "40E0D0", "violet": "EE82EE", "wheat": "F5DEB3", "white": "FFFFFF",
        "whitesmoke": "F5F5F5", "yellow": "FFFF00", "yellowgreen": "9ACD32",
        // Not in ST_PresetColorVal; kept from the earlier resolver for decks that use it.
        "transparent": "000000",
    ]
}
