import Foundation

// Public color math on `Color`, plus the single internal `RGB` working-space
// struct that all of Rostrum's color arithmetic shares — Theme resolution,
// Design heuristics, and these utilities — so luminance and the DrawingML
// transforms are never forked. Pure computation: no OOXML, no round-trip surface.

public extension Color {
    /// The red channel, 0…255.
    var red: Int { channel(0) }
    /// The green channel, 0…255.
    var green: Int { channel(2) }
    /// The blue channel, 0…255.
    var blue: Int { channel(4) }

    private func channel(_ offset: Int) -> Int {
        let start = hex.index(hex.startIndex, offsetBy: offset)
        let end = hex.index(start, offsetBy: 2)
        return Int(hex[start..<end], radix: 16) ?? 0
    }

    /// WCAG 2.x relative luminance — gamma-correct, 0 (black) … 1 (white).
    ///
    /// Public because anything building slides on top of Rostrum has to make
    /// the same light-text-or-dark-text decision `DeckStyle` makes internally,
    /// and the alternative is every caller hand-rolling its own luminance —
    /// which is how two parts of one deck end up disagreeing about whether a
    /// background is dark.
    public var relativeLuminance: Double {
        func linear(_ c: Int) -> Double {
            let s = Double(c) / 255
            return s <= 0.03928 ? s / 12.92 : pow((s + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    /// WCAG contrast ratio with `other`, 1 (identical) … 21 (black↔white).
    /// Symmetric.
    public func contrastRatio(with other: Color) -> Double {
        let hi = Swift.max(relativeLuminance, other.relativeLuminance)
        let lo = Swift.min(relativeLuminance, other.relativeLuminance)
        return (hi + 0.05) / (lo + 0.05)
    }

    /// The more legible of `dark`/`light` to sit ON this color as a background.
    /// Ties favor `dark`.
    public func onColor(dark: Color = .black, light: Color = .white) -> Color {
        contrastRatio(with: dark) >= contrastRatio(with: light) ? dark : light
    }

    /// The `option` with the highest contrast against `background` (auto-contrast
    /// text). Deterministic — the first of equally-good options wins; empty
    /// `options` yields `.black`.
    public static func bestTextColor(on background: Color,
                                     options: [Color] = [.black, .white]) -> Color {
        var best = Color.black
        var bestRatio = -1.0
        for option in options {
            let ratio = background.contrastRatio(with: option)
            if ratio > bestRatio { bestRatio = ratio; best = option }
        }
        return best
    }

    /// Linear sRGB blend. `amount` (clamped 0…1) is the weight of `b`:
    /// 0 → `a`, 1 → `b`, 0.5 → the midpoint.
    static func mix(_ a: Color, _ b: Color, amount: Double = 0.5) -> Color {
        RGB(a).mixed(with: RGB(b), amount: amount).color
    }

    /// This color blended toward `other` by `amount` (0…1). See `mix`.
    func mixed(with other: Color, amount: Double = 0.5) -> Color {
        Color.mix(self, other, amount: amount)
    }

    /// Toward white by `amount` (0 = unchanged, 1 = white). Note this is the
    /// inverse convention of the DrawingML `tint` *transform value*.
    func lighten(_ amount: Double) -> Color { mixed(with: .white, amount: amount) }
    /// Toward black by `amount` (0 = unchanged, 1 = black).
    func darken(_ amount: Double) -> Color { mixed(with: .black, amount: amount) }
    /// Alias of `lighten`, for design vocabulary.
    func tint(_ amount: Double) -> Color { lighten(amount) }
    /// Alias of `darken`.
    func shade(_ amount: Double) -> Color { darken(amount) }
}

/// Minimal RGB working space with the DrawingML transforms that matter for
/// resolution. Shared across Theme resolution, Design heuristics, and Color
/// math — one implementation, never forked. (Relocated from Theme.)
struct RGB {
    var r, g, b: Double   // 0…255

    init(_ color: Color) {
        r = Double(color.red); g = Double(color.green); b = Double(color.blue)
    }
    init(r: Double, g: Double, b: Double) { self.r = r; self.g = g; self.b = b }

    var color: Color {
        func c(_ x: Double) -> Int { Swift.max(0, Swift.min(255, Int(x.rounded()))) }
        return Color(red: c(r), green: c(g), blue: c(b))
    }

    /// Linear blend toward `other` by `amount` (clamped 0…1).
    func mixed(with other: RGB, amount: Double) -> RGB {
        let t = Swift.max(0, Swift.min(1, amount))
        return RGB(r: r + (other.r - r) * t, g: g + (other.g - g) * t, b: b + (other.b - b) * t)
    }

    func applying(_ t: ColorTransform) -> RGB {
        let f = t.fraction
        switch t {
        case .tint:   return map { $0 * f + 255 * (1 - f) }      // mix toward white
        case .shade:  return map { $0 * f }                       // mix toward black
        case .lumMod: return adjustingHSL { ($0, $1, $2 * f) }
        case .lumOff: return adjustingHSL { ($0, $1, $2 + f) }
        case .satMod: return scalingSaturation(by: f)            // HSL saturation × f
        case .alpha:  return self                                // opacity: no RGB effect
        }
    }

    func map(_ fn: (Double) -> Double) -> RGB {
        RGB(r: fn(r), g: fn(g), b: fn(b))
    }

    private func scalingSaturation(by factor: Double) -> RGB {
        adjustingHSL { ($0, $1 * factor, $2) }
    }

    /// HSL operations preserve the other two components, unlike per-channel
    /// multiplication. Keep floating point precision until final serialization.
    func adjustingHSL(_ operation: (Double, Double, Double) -> (Double, Double, Double)) -> RGB {
        let rn = min(1, max(0, r / 255)), gn = min(1, max(0, g / 255)), bn = min(1, max(0, b / 255))
        let high = max(rn, gn, bn), low = min(rn, gn, bn)
        let lightness = (high + low) / 2, delta = high - low
        var hue = 0.0, saturation = 0.0
        if delta > 0 {
            saturation = delta / (1 - abs(2 * lightness - 1))
            if high == rn { hue = ((gn - bn) / delta).truncatingRemainder(dividingBy: 6) }
            else if high == gn { hue = (bn - rn) / delta + 2 }
            else { hue = (rn - gn) / delta + 4 }
            hue /= 6
            if hue < 0 { hue += 1 }
        }
        let result = operation(hue, saturation, lightness)
        return Self(hue: result.0, saturation: result.1, lightness: result.2)
    }

    init(hue: Double, saturation: Double, lightness: Double) {
        var h = hue.truncatingRemainder(dividingBy: 1)
        if h < 0 { h += 1 }
        let s = min(1, max(0, saturation)), l = min(1, max(0, lightness))
        let chroma = (1 - abs(2 * l - 1)) * s
        let x = chroma * (1 - abs((h * 6).truncatingRemainder(dividingBy: 2) - 1))
        let m = l - chroma / 2
        let channels: (Double, Double, Double)
        switch h * 6 {
        case ..<1: channels = (chroma, x, 0)
        case ..<2: channels = (x, chroma, 0)
        case ..<3: channels = (0, chroma, x)
        case ..<4: channels = (0, x, chroma)
        case ..<5: channels = (x, 0, chroma)
        default: channels = (chroma, 0, x)
        }
        self.init(r: (channels.0 + m) * 255, g: (channels.1 + m) * 255, b: (channels.2 + m) * 255)
    }
}
