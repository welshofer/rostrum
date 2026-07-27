import Foundation

// Read-back for the appearance a shape carries: the fill, the outline, and
// whether it has a shadow. `Fill` and `Line` were write-only — you could set
// them but never ask what a shape already had, which made "open a deck and
// restyle only the untouched shapes" impossible.

/// A shape's fill, as read from the XML. Distinguishes "no fill element at
/// all" (inherits from the theme or placeholder, reported as `nil` by the
/// accessors) from an explicit `a:noFill`.
public enum ReadFill: Equatable, Sendable {
    /// `a:solidFill` with an sRGB color, and its alpha when one is set.
    case solid(Color, alpha: Double)
    /// `a:solidFill` with a theme color reference (`a:schemeClr@val`).
    case themeScheme(String)
    /// `a:gradFill`, with the stops in document order.
    case gradient([GradientStop])
    /// `a:blipFill` — a picture fill; the relationship id of the image.
    case image(relationshipID: String?)
    /// `a:pattFill`, which Rostrum does not model further.
    case pattern
    /// An explicit `a:noFill`. Named to avoid colliding with `Optional.none`,
    /// since these accessors all return `ReadFill?` — where `nil` means
    /// "inherits", the opposite of this case.
    case noFill
    /// An explicit fill Rostrum does not model — a solid `a:sysClr`,
    /// `a:prstClr`, `a:scrgbClr` or `a:hslClr`, or a `a:grpFill`. Reported
    /// distinctly so an authored fill is never mistaken for inheritance.
    case unmodeled(elementName: String)

    init?(container: XML.Element) {
        if let solid = container.firstChild(named: "a:solidFill") {
            if let srgb = solid.firstChild(named: "a:srgbClr"),
               let hex = srgb[attribute: "val"], let color = Color(validating: hex) {
                let alpha = srgb.firstChild(named: "a:alpha")?[attribute: "val"]
                    .flatMap { Int($0) }.map { Double($0) / 100_000 } ?? 1
                self = .solid(color, alpha: alpha)
            } else if let scheme = solid.firstChild(named: "a:schemeClr"),
                      let value = scheme[attribute: "val"] {
                self = .themeScheme(value)
            } else {
                // An authored fill in a color model we do not parse: still a
                // fill, so never report it as inheritance.
                self = .unmodeled(elementName: solid.childElements.first?.name ?? "a:solidFill")
            }
        } else if let gradient = container.firstChild(named: "a:gradFill") {
            let stops = (gradient.firstChild(named: "a:gsLst")?.children(named: "a:gs") ?? [])
                .compactMap { gs -> GradientStop? in
                    guard let srgb = gs.firstChild(named: "a:srgbClr"),
                          let hex = srgb[attribute: "val"],
                          let color = Color(validating: hex) else { return nil }
                    let position = gs[attribute: "pos"].flatMap { Int($0) }
                        .map { Double($0) / 100_000 } ?? 0
                    let alpha = srgb.firstChild(named: "a:alpha")?[attribute: "val"]
                        .flatMap { Int($0) }.map { Double($0) / 100_000 } ?? 1
                    return GradientStop(position: position, color: color, alpha: alpha)
                }
            self = .gradient(stops)
        } else if let blip = container.firstChild(named: "a:blipFill") {
            self = .image(relationshipID: blip.firstChild(named: "a:blip")?[attribute: "r:embed"])
        } else if container.firstChild(named: "a:pattFill") != nil {
            self = .pattern
        } else if container.firstChild(named: "a:noFill") != nil {
            self = .noFill
        } else if container.firstChild(named: "a:grpFill") != nil {
            self = .unmodeled(elementName: "a:grpFill")
        } else {
            return nil
        }
    }
}

/// A shape's outline, as read from the XML.
public struct ReadLine: Equatable, Sendable {
    /// The stroke color, when it is a plain sRGB solid fill.
    public var color: Color?
    /// The theme color token, when the stroke is a `schemeClr` reference.
    public var themeScheme: String?
    /// Stroke width (`a:ln@w`); nil when the element leaves it inherited.
    public var width: EMU?
    /// The dash style token (`a:prstDash@val`), e.g. "dash", "sysDot".
    public var dashStyle: String?
    /// True when the outline is explicitly `a:noFill` — a suppressed border,
    /// which is different from no `a:ln` at all.
    public var isNone: Bool

    init(element: XML.Element) {
        width = element[attribute: "w"].flatMap { Int($0) }.map { EMU($0) }
        dashStyle = element.firstChild(named: "a:prstDash")?[attribute: "val"]
        isNone = element.firstChild(named: "a:noFill") != nil
        let solid = element.firstChild(named: "a:solidFill")
        color = solid?.firstChild(named: "a:srgbClr")?[attribute: "val"]
            .flatMap { Color(validating: $0) }
        themeScheme = solid?.firstChild(named: "a:schemeClr")?[attribute: "val"]
    }
}

public extension Shape {
    /// The properties element that carries this kind's fill/line/effects:
    /// `p:spPr` for shapes, pictures and connectors, `p:grpSpPr` for a group.
    /// Graphic frames have neither. A pure read — never creates anything.
    private var appearanceProperties: XML.Element? {
        switch element.name {
        case "p:grpSp": return element.firstChild(named: "p:grpSpPr")
        case "p:sp", "p:pic", "p:cxnSp": return element.firstChild(named: "p:spPr")
        default: return nil
        }
    }

    /// The fill written on this shape, or nil when it carries none and
    /// inherits (from its placeholder, the layout, or the theme). An
    /// explicitly authored fill Rostrum does not model reads as
    /// `.unmodeled`, never as nil.
    ///
    /// A pure read — unlike `setFill(_:)` it never creates a properties
    /// element, so asking a graphic frame simply yields nil.
    var fill: ReadFill? {
        appearanceProperties.flatMap(ReadFill.init(container:))
    }

    /// The outline written on this shape, or nil when it carries none.
    var line: ReadLine? {
        appearanceProperties?.firstChild(named: "a:ln").map(ReadLine.init(element:))
    }

    /// True when the shape carries an outer shadow effect.
    var hasShadow: Bool {
        appearanceProperties?
            .firstChild(named: "a:effectLst")?.firstChild(named: "a:outerShdw") != nil
    }
}

public extension Slide {
    /// The background fill written on this slide, or nil when it inherits
    /// from the layout or master.
    var background: ReadFill? {
        guard let bgPr = (try? part.dom())?.firstChild(named: "p:cSld")?
            .firstChild(named: "p:bg")?.firstChild(named: "p:bgPr") else { return nil }
        return ReadFill(container: bgPr)
    }
}

public extension TableCell {
    /// The fill written on this cell, or nil when it inherits from the table
    /// style.
    var fill: ReadFill? {
        tc.firstChild(named: "a:tcPr").flatMap(ReadFill.init(container:))
    }
}
