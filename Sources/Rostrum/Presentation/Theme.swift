import Foundation

/// A slot in `a:clrScheme` — the theme-facing color names (fixed order).
public enum ThemeSlot: String, CaseIterable, Sendable {
    case dk1, lt1, dk2, lt2
    case accent1, accent2, accent3, accent4, accent5, accent6
    case hlink, folHlink
}

/// A value legal in `<a:schemeClr val="…">`. `bg*/tx*` resolve through the
/// master's clrMap (bg1→lt1, tx1→dk1 in a standard theme — the swap); the
/// accents/hlinks also route through clrMap (usually identity); `dk*/lt*` are
/// direct theme slots; `phClr` is a style-matrix placeholder (unresolvable
/// without style context).
public enum SchemeColor: String, Hashable, Sendable {
    case bg1, tx1, bg2, tx2
    case accent1, accent2, accent3, accent4, accent5, accent6
    case hlink, folHlink
    case dk1, lt1, dk2, lt2
    case phClr
}

/// A DrawingML color transform (wire value = fraction × 100000). Applied in
/// order to a base color.
public enum ColorTransform: Hashable, Sendable {
    case tint(Double), shade(Double)
    case lumMod(Double), lumOff(Double)
    case satMod(Double)
    case alpha(Double)

    var name: String {
        switch self {
        case .tint: return "tint"; case .shade: return "shade"
        case .lumMod: return "lumMod"; case .lumOff: return "lumOff"
        case .satMod: return "satMod"; case .alpha: return "alpha"
        }
    }
    var fraction: Double {
        switch self {
        case .tint(let v), .shade(let v), .lumMod(let v), .lumOff(let v),
             .satMod(let v), .alpha(let v): return v
        }
    }
    var element: XML.Element {
        XML.Element("a:\(name)", attributes: [("val", String(Int((fraction * 100_000).rounded())))])
    }
}

/// A presentation's theme — the palette and fonts every `schemeClr` reference
/// resolves against. Editing a slot recolors every shape that references it.
public final class Theme {
    public let part: Part
    /// The slide master, needed to read its clrMap for bg*/tx* routing.
    let master: Part?

    init(part: Part, master: Part?) {
        self.part = part
        self.master = master
    }

    private var clrScheme: XML.Element? {
        try? part.dom().firstChild(named: "a:themeElements")?.firstChild(named: "a:clrScheme")
    }
    private var fontScheme: XML.Element? {
        try? part.dom().firstChild(named: "a:themeElements")?.firstChild(named: "a:fontScheme")
    }

    // MARK: - Palette

    /// The concrete RGB of a theme slot (`a:srgbClr@val`, or `a:sysClr@lastClr`).
    public func color(_ slot: ThemeSlot) -> Color? {
        guard let el = clrScheme?.firstChild(named: "a:\(slot.rawValue)") else { return nil }
        if let srgb = el.firstChild(named: "a:srgbClr")?[attribute: "val"] { return Color(srgb) }
        if let last = el.firstChild(named: "a:sysClr")?[attribute: "lastClr"] { return Color(last) }
        return nil
    }

    /// Set a slot to a concrete RGB (replaces sysClr/srgbClr with srgbClr).
    public func setColor(_ slot: ThemeSlot, _ color: Color) {
        guard let el = clrScheme?.firstChild(named: "a:\(slot.rawValue)") else { return }
        el.children = [.element(color.srgbElement())]
        part.markDirty()
    }

    /// Accent 1…6 convenience (a brand's core palette).
    public func accent(_ n: Int) -> Color? { color(accentSlot(n)) }
    public func setAccent(_ n: Int, _ color: Color) { setColor(accentSlot(n), color) }

    private func accentSlot(_ n: Int) -> ThemeSlot {
        precondition((1...6).contains(n), "accent index must be 1…6")
        return ThemeSlot(rawValue: "accent\(n)")!
    }

    // MARK: - Fonts

    public var majorFont: String? {
        get { fontScheme?.firstChild(named: "a:majorFont")?.firstChild(named: "a:latin")?[attribute: "typeface"] }
        set { setFont(major: true, newValue) }
    }
    public var minorFont: String? {
        get { fontScheme?.firstChild(named: "a:minorFont")?.firstChild(named: "a:latin")?[attribute: "typeface"] }
        set { setFont(major: false, newValue) }
    }

    private func setFont(major: Bool, _ typeface: String?) {
        guard let typeface,
              let latin = fontScheme?.firstChild(named: major ? "a:majorFont" : "a:minorFont")?
                  .firstChild(named: "a:latin") else { return }
        latin[attribute: "typeface"] = typeface
        part.markDirty()
    }

    // MARK: - Resolution

    /// Resolve a scheme color (with transforms) to a concrete RGB. Returns nil
    /// for `phClr` (needs style-matrix context) or an unmappable value.
    public func resolve(_ scheme: SchemeColor, transforms: [ColorTransform] = []) -> Color? {
        guard scheme != .phClr, let slot = slot(for: scheme), var rgb = color(slot).map(RGB.init)
        else { return nil }
        for t in transforms { rgb = rgb.applying(t) }
        return rgb.color
    }

    /// The theme slot a scheme value resolves to: bg*/tx*/accent*/hlink route
    /// through the master clrMap; dk*/lt* are direct.
    private func slot(for scheme: SchemeColor) -> ThemeSlot? {
        switch scheme {
        case .dk1: return .dk1
        case .lt1: return .lt1
        case .dk2: return .dk2
        case .lt2: return .lt2
        case .phClr: return nil
        default:
            // clrMap attribute value is a theme-slot name.
            guard let clrMap = try? master?.dom().firstChild(named: "p:clrMap"),
                  let mapped = clrMap[attribute: scheme.rawValue] else {
                // No master/clrMap: accents map to themselves.
                return ThemeSlot(rawValue: scheme.rawValue)
            }
            return ThemeSlot(rawValue: mapped)
        }
    }
}

extension Presentation {
    /// The deck's theme (via the first slide master), for brand-kit editing
    /// and color resolution.
    public var theme: Theme {
        let master = try? presentationPart.related(by: RelType.slideMaster, in: package)
        let themePart: Part? = {
            if let master, let t = try? master.related(by: RelType.theme, in: package) { return t }
            return package.parts[PackURI("/ppt/theme/theme1.xml")]
        }()
        return Theme(part: themePart ?? presentationPart, master: master)
    }
}

/// Minimal RGB with the DrawingML transforms that matter for resolution.
private struct RGB {
    var r, g, b: Double   // 0…255
    init(_ color: Color) {
        let v = Int(color.hex, radix: 16) ?? 0
        r = Double((v >> 16) & 0xFF); g = Double((v >> 8) & 0xFF); b = Double(v & 0xFF)
    }
    var color: Color {
        func c(_ x: Double) -> Int { Swift.max(0, Swift.min(255, Int(x.rounded()))) }
        return Color(red: c(r), green: c(g), blue: c(b))
    }
    func applying(_ t: ColorTransform) -> RGB {
        let f = t.fraction
        switch t {
        case .tint:   return map { $0 * f + 255 * (1 - f) }      // mix toward white
        case .shade:  return map { $0 * f }                       // mix toward black
        case .lumMod: return map { $0 * f }
        case .lumOff: return map { $0 + 255 * f }
        case .satMod: return scalingSaturation(by: f)            // HSL saturation × f
        case .alpha:  return self                                // opacity: no RGB effect
        }
    }
    private func map(_ fn: (Double) -> Double) -> RGB {
        RGB(r: fn(r), g: fn(g), b: fn(b))
    }
    init(r: Double, g: Double, b: Double) { self.r = r; self.g = g; self.b = b }

    /// Multiply HSL saturation by `factor` (DrawingML `a:satMod`), clamping the
    /// result to [0, 1]. Grayscale colors (saturation 0) are unaffected.
    private func scalingSaturation(by factor: Double) -> RGB {
        let rn = r / 255, gn = g / 255, bn = b / 255
        let maxc = Swift.max(rn, gn, bn), minc = Swift.min(rn, gn, bn)
        let lum = (maxc + minc) / 2
        let delta = maxc - minc
        guard delta != 0 else { return self }
        var hue: Double
        if maxc == rn { hue = (gn - bn) / delta + (gn < bn ? 6 : 0) }
        else if maxc == gn { hue = (bn - rn) / delta + 2 }
        else { hue = (rn - gn) / delta + 4 }
        hue /= 6
        let sat0 = lum > 0.5 ? delta / (2 - maxc - minc) : delta / (maxc + minc)
        let sat = Swift.max(0, Swift.min(1, sat0 * factor))
        let q = lum < 0.5 ? lum * (1 + sat) : lum + sat - lum * sat
        let p = 2 * lum - q
        func channel(_ offset: Double) -> Double {
            var t = hue + offset
            if t < 0 { t += 1 } else if t > 1 { t -= 1 }
            if t < 1.0 / 6 { return p + (q - p) * 6 * t }
            if t < 1.0 / 2 { return q }
            if t < 2.0 / 3 { return p + (q - p) * (2.0 / 3 - t) * 6 }
            return p
        }
        return RGB(r: channel(1.0 / 3) * 255, g: channel(0) * 255, b: channel(-1.0 / 3) * 255)
    }
}
