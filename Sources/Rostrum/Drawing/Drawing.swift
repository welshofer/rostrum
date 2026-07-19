import Foundation

/// An sRGB color, stored as six uppercase hex digits (the DrawingML wire form).
public struct Color: Hashable, Sendable {
    public let hex: String

    public init(_ hex: String) {
        var value = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        value = value.uppercased()
        precondition(value.count == 6 && value.allSatisfy(\.isHexDigit),
                     "Color requires 6 hex digits, got \(hex)")
        self.hex = value
    }

    public init(red: Int, green: Int, blue: Int) {
        self.init(String(format: "%02X%02X%02X", red, green, blue))
    }

    public static let white = Color("FFFFFF")
    public static let black = Color("000000")

    /// `<a:srgbClr val="…">` with an optional `<a:alpha>` child
    /// (alpha in 0…1; wire unit is thousandths of a percent).
    func srgbElement(alpha: Double? = nil) -> XML.Element {
        let element = XML.Element("a:srgbClr", attributes: [("val", hex)])
        if let alpha, alpha < 1 {
            element.appendElement(XML.Element(
                "a:alpha", attributes: [("val", String(Int((alpha * 100_000).rounded())))]))
        }
        return element
    }
}

/// One stop of a gradient. `position` runs 0…1.
public struct GradientStop: Hashable, Sendable {
    public var position: Double
    public var color: Color
    public var alpha: Double

    public init(position: Double, color: Color, alpha: Double = 1) {
        self.position = position
        self.color = color
        self.alpha = alpha
    }
}

/// A gradient. Linear by default: `angleDegrees` is clockwise from "pointing
/// right" (0 = left→right, 90 = top→bottom; wire unit 1/60000 degree). Radial
/// gradients (`isRadial`) run from the center outward and ignore the angle.
public struct GradientFill: Hashable, Sendable {
    public var stops: [GradientStop]
    public var angleDegrees: Double
    /// Radial (center → edge) instead of linear. Ignores `angleDegrees`.
    public var isRadial: Bool

    public init(stops: [GradientStop], angleDegrees: Double = 90, isRadial: Bool = false) {
        precondition(stops.count >= 2, "a gradient needs at least 2 stops")
        self.stops = stops
        self.angleDegrees = angleDegrees
        self.isRadial = isRadial
    }

    /// Two-color convenience, top→bottom by default.
    public init(from: Color, to: Color, angleDegrees: Double = 90) {
        self.init(stops: [
            GradientStop(position: 0, color: from),
            GradientStop(position: 1, color: to),
        ], angleDegrees: angleDegrees)
    }

    /// A radial gradient from the center outward.
    public static func radial(stops: [GradientStop]) -> GradientFill {
        GradientFill(stops: stops, isRadial: true)
    }

    /// A two-color radial gradient, `from` at the center to `to` at the edge.
    public static func radial(from: Color, to: Color) -> GradientFill {
        GradientFill(stops: [
            GradientStop(position: 0, color: from),
            GradientStop(position: 1, color: to),
        ], isRadial: true)
    }
}

/// How an image fill maps onto the shape (or background) it fills. Distinct
/// from `PictureFit`, which is for `p:pic` picture shapes — tiling is a
/// fill-only capability.
public enum ImageFillMode: Hashable, Sendable {
    /// Scale the image to fill the region (`a:stretch`/`a:fillRect`).
    case stretch
    /// Tile the image at `scale` (1.0 = native), repeating to fill (`a:tile`).
    case tile(scale: Double = 1.0)
}

/// A shape or background fill.
public enum Fill: Hashable, Sendable {
    case solid(Color)
    /// Solid color with opacity 0…1 — overlays, scrims, subtle accents.
    case solidAlpha(Color, Double)
    case gradient(GradientFill)
    /// An image fill (`a:blipFill`). The image is embedded (deduplicated) and a
    /// relationship added when the fill is written — so this case must be
    /// realized through `fillElement(embeddingInto:package:)`, never the pure
    /// `makeElement()`.
    case image(Data, ImageFillMode)
    /// A theme color reference (with optional transforms). Shapes filled this
    /// way recolor automatically when the theme palette is edited.
    case themeScheme(SchemeColor, [ColorTransform])
    case none

    /// A theme color fill, e.g. `.themeColor(.accent1)` or with transforms.
    public static func themeColor(_ scheme: SchemeColor, _ transforms: [ColorTransform] = []) -> Fill {
        .themeScheme(scheme, transforms)
    }

    /// An image fill from raw image bytes (PNG/JPEG/GIF).
    public static func image(_ data: Data, fit: ImageFillMode = .stretch) -> Fill {
        .image(data, fit)
    }

    /// The DrawingML fill element (`a:solidFill`/`a:gradFill`/`a:noFill`).
    func makeElement() -> XML.Element {
        switch self {
        case .solid(let color):
            let fill = XML.Element("a:solidFill")
            fill.appendElement(color.srgbElement())
            return fill
        case .themeScheme(let scheme, let transforms):
            let fill = XML.Element("a:solidFill")
            let clr = XML.Element("a:schemeClr", attributes: [("val", scheme.rawValue)])
            for t in transforms { clr.appendElement(t.element) }
            fill.appendElement(clr)
            return fill
        case .solidAlpha(let color, let alpha):
            let fill = XML.Element("a:solidFill")
            fill.appendElement(color.srgbElement(alpha: alpha))
            return fill
        case .gradient(let gradient):
            let fill = XML.Element("a:gradFill", attributes: [("rotWithShape", "1")])
            let stopList = XML.Element("a:gsLst")
            for stop in gradient.stops.sorted(by: { $0.position < $1.position }) {
                let gs = XML.Element("a:gs", attributes: [
                    ("pos", String(Int((stop.position * 100_000).rounded()))),
                ])
                gs.appendElement(stop.color.srgbElement(alpha: stop.alpha))
                stopList.appendElement(gs)
            }
            fill.appendElement(stopList)
            if gradient.isRadial {
                // Radial: a:gsLst then a:path (never a:lin). fillToRect at the
                // center makes the last stop the outer edge.
                let path = XML.Element("a:path", attributes: [("path", "circle")])
                path.appendElement(XML.Element("a:fillToRect", attributes: [
                    ("l", "50000"), ("t", "50000"), ("r", "50000"), ("b", "50000"),
                ]))
                fill.appendElement(path)
            } else {
                fill.appendElement(XML.Element("a:lin", attributes: [
                    ("ang", String(Int((gradient.angleDegrees * 60_000).rounded()))),
                    ("scaled", "1"),
                ]))
            }
            return fill
        case .image:
            preconditionFailure(
                "image fills must be written via Fill.fillElement(embeddingInto:package:)")
        case .none:
            return XML.Element("a:noFill")
        }
    }

    /// The DrawingML fill choice-group members, for remove-before-replace.
    static let choiceNames = [
        "a:noFill", "a:solidFill", "a:gradFill", "a:blipFill", "a:pattFill", "a:grpFill",
    ]
}

/// A shape outline. `nil` on a Rostrum shape means an explicit `a:ln` with
/// `a:noFill` — design shapes shouldn't inherit theme outlines by surprise.
public struct Line: Hashable, Sendable {
    public var color: Color
    public var width: EMU

    public init(color: Color, width: EMU = .points(1)) {
        self.color = color
        self.width = width
    }

    static func makeElement(_ line: Line?) -> XML.Element {
        let ln = XML.Element("a:ln")
        if let line {
            ln[attribute: "w"] = String(line.width.rawValue)
            let fill = XML.Element("a:solidFill")
            fill.appendElement(line.color.srgbElement())
            ln.appendElement(fill)
        } else {
            ln.appendElement(XML.Element("a:noFill"))
        }
        return ln
    }
}

/// A position + size in EMU. Origin is the slide's top-left corner.
public struct Rect: Hashable, Sendable {
    public var x: EMU
    public var y: EMU
    public var width: EMU
    public var height: EMU

    public init(x: EMU, y: EMU, width: EMU, height: EMU) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}
