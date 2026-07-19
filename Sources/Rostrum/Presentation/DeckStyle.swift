import Foundation

// The design-authoring layer's single "style currency". A DeckStyle is an
// immutable value snapshot resolved from the deck's Theme (authoritative for
// colors + fonts, which survive save/reopen) plus an optionally-applied Design
// (authoritative for the type/spacing/radius TOKENS, which live only in-memory).
// Emits NO XML of its own — the only writes go through the existing schema-safe
// Run/Paragraph setters via `apply`.

/// A semantic role in the type scale. Every role always resolves to a concrete
/// `TextStyle`; `design.md` typography tokens override facets by alias.
public enum TypeRole: String, CaseIterable, Sendable {
    case kicker, display, title, heading, subhead, body, stat, quote, caption
}

/// A fully-resolved text style: concrete font, size (pt), numeric weight,
/// tracking (pt), line-height multiple, color, and case.
public struct TextStyle: Sendable, Equatable {
    public var font: String
    public var sizePt: Double
    public var weight: Int
    public var trackingPt: Double
    public var lineHeight: Double
    public var color: Color
    public var uppercase: Bool
    /// The run model has no numeric weight; 600+ collapses to bold.
    public var bold: Bool { weight >= 600 }

    public init(font: String, sizePt: Double, weight: Int, trackingPt: Double,
                lineHeight: Double, color: Color, uppercase: Bool = false) {
        self.font = font; self.sizePt = sizePt; self.weight = weight
        self.trackingPt = trackingPt; self.lineHeight = lineHeight
        self.color = color; self.uppercase = uppercase
    }
}

/// The resolved type scale — every `TypeRole` mapped to a concrete `TextStyle`.
public struct TypeScale: Sendable, Equatable {
    private var styles: [TypeRole: TextStyle]
    init(_ styles: [TypeRole: TextStyle]) { self.styles = styles }

    public subscript(_ role: TypeRole) -> TextStyle { styles[role]! }
    public func callAsFunction(_ role: TypeRole) -> TextStyle { styles[role]! }

    /// A copy with one role's `TextStyle` mutated in place.
    public func overriding(_ role: TypeRole, _ mutate: (inout TextStyle) -> Void) -> TypeScale {
        var copy = styles
        var style = copy[role]!
        mutate(&style)
        copy[role] = style
        return TypeScale(copy)
    }
}

/// A named EMU scale (spacing or corner-radius). Built-in defaults overlaid by
/// `design.md` tokens; an unknown name resolves to `md`.
public struct TokenScale: Sendable, Equatable {
    private var tokens: [String: EMU]
    init(_ tokens: [String: EMU]) { self.tokens = tokens }

    public func callAsFunction(_ name: String) -> EMU {
        tokens[name.lowercased()] ?? tokens["md"] ?? .zero
    }
    public func callAsFunction(_ name: String, default fallback: EMU) -> EMU {
        tokens[name.lowercased()] ?? fallback
    }
    /// The token if it exists, without the `md` fallback.
    public func value(_ name: String) -> EMU? { tokens[name.lowercased()] }

    public var xs: EMU { self("xs") }
    public var sm: EMU { self("sm") }
    public var md: EMU { self("md") }
    public var lg: EMU { self("lg") }
    public var xl: EMU { self("xl") }
    public var xxl: EMU { self("xxl") }
}

/// A resolved brand style the whole authoring layer reads from. Value type:
/// `Sendable`, `Equatable`, and cheaply copied/overridden.
public struct DeckStyle: Sendable, Equatable {
    public var background: Color
    public var surface: Color
    public var ink: Color
    public var mutedInk: Color
    public var link: Color
    public var accents: [Color]
    public var isDark: Bool
    public var headingFont: String
    public var bodyFont: String
    public var type: TypeScale
    public var spacing: TokenScale
    public var radius: TokenScale
    public var margin: EMU
    public var gutter: EMU

    public init(background: Color, surface: Color, ink: Color, mutedInk: Color, link: Color,
                accents: [Color], isDark: Bool, headingFont: String, bodyFont: String,
                type: TypeScale, spacing: TokenScale, radius: TokenScale,
                margin: EMU, gutter: EMU) {
        self.background = background; self.surface = surface; self.ink = ink
        self.mutedInk = mutedInk; self.link = link; self.accents = accents
        self.isDark = isDark; self.headingFont = headingFont; self.bodyFont = bodyFont
        self.type = type; self.spacing = spacing; self.radius = radius
        self.margin = margin; self.gutter = gutter
    }

    /// Resolve a style from a `Theme` (+ optional `Design` for tokens). This is
    /// the only place that reads the mutable `Theme` class; it snapshots into
    /// value fields immediately.
    public init(theme: Theme, design: Design? = nil) {
        let bg = design?.colors["background"] ?? theme.resolve(.bg1) ?? theme.color(.lt1) ?? .white
        let rawInk = design?.colors["ink"] ?? design?.colors["text"]
            ?? theme.resolve(.tx1) ?? theme.color(.dk1) ?? .black
        // Contrast guard. A token named "ink"/"text" can be dark by intent (meant
        // for light surfaces); on a dark theme it lands dark-on-dark and the deck
        // is unreadable. If the raw text color doesn't clear AA on the background,
        // swap in the most legible option (an on-brand palette light, else white).
        let inkColor: Color = rawInk.contrastRatio(with: bg) >= 4.5
            ? rawInk
            : Color.bestTextColor(on: bg, options: [rawInk, .white, .black] + (design?.palette ?? []))
        let dark = bg.relativeLuminance < 0.5
        let acc = (1...6).map { theme.accent($0) ?? design?.colors["accent \($0)"] ?? inkColor }
        self.init(
            background: bg,
            surface: design?.colors["surface"] ?? (dark ? bg.lighten(0.08) : bg),
            ink: inkColor,
            mutedInk: inkColor.mixed(with: bg, amount: 0.45),
            link: theme.color(.hlink) ?? Color("0563C1"),
            accents: acc, isDark: dark,
            headingFont: design?.headingFont ?? theme.majorFont ?? DeckStyle.fallbackHeadingFont,
            bodyFont: design?.bodyFont ?? theme.minorFont ?? DeckStyle.fallbackBodyFont,
            type: DeckStyle.makeTypeScale(
                headingFont: design?.headingFont ?? theme.majorFont ?? DeckStyle.fallbackHeadingFont,
                bodyFont: design?.bodyFont ?? theme.minorFont ?? DeckStyle.fallbackBodyFont,
                ink: inkColor, mutedInk: inkColor.mixed(with: bg, amount: 0.45),
                accent1: acc[0], design: design),
            spacing: TokenScale(DeckStyle.merge(DeckStyle.defaultSpacing, design?.spacing)),
            radius: TokenScale(DeckStyle.merge(DeckStyle.defaultRadius, design?.radius)),
            margin: .inches(0.9), gutter: .inches(0.2))
    }

    // MARK: - Accessors

    /// The nth accent, 1-based and cyclic (accent(7) == accent(1)); never traps.
    public func accent(_ n: Int) -> Color {
        guard !accents.isEmpty else { return ink }
        let i = ((n - 1) % accents.count + accents.count) % accents.count
        return accents[i]
    }

    /// The primary brand color (accent 1).
    public var primary: Color { accent(1) }

    /// The most legible text color to place on `fill`, preferring the deck's own
    /// ink/paper when equally legible.
    public func textColor(on fill: Color) -> Color {
        Color.bestTextColor(on: fill, options: [ink, background, .black, .white])
    }

    /// Accent `n` if it clears WCAG AA (4.5:1) on `bg`, else legible text.
    public func legibleAccent(_ n: Int, on bg: Color) -> Color {
        let a = accent(n)
        return a.contrastRatio(with: bg) >= 4.5 ? a : textColor(on: bg)
    }

    // MARK: - Overrides (value semantics)

    public func with(background: Color? = nil, ink: Color? = nil, accents: [Color]? = nil,
                     headingFont: String? = nil, bodyFont: String? = nil,
                     margin: EMU? = nil, gutter: EMU? = nil) -> DeckStyle {
        var c = self
        if let background { c.background = background; c.isDark = background.relativeLuminance < 0.5 }
        if let ink { c.ink = ink }
        if let accents { c.accents = accents }
        if let headingFont { c.headingFont = headingFont }
        if let bodyFont { c.bodyFont = bodyFont }
        if let margin { c.margin = margin }
        if let gutter { c.gutter = gutter }
        return c
    }

    /// A copy with one type role restyled: `style.with(.title) { $0.sizePt = 54 }`.
    public func with(_ role: TypeRole, _ mutate: (inout TextStyle) -> Void) -> DeckStyle {
        var c = self
        c.type = c.type.overriding(role, mutate)
        return c
    }

    // MARK: - Defaults

    public static let fallbackHeadingFont = "Calibri Light"
    public static let fallbackBodyFont = "Calibri"

    static let defaultSpacing: [String: EMU] = [
        "xxs": .pixels(2), "xs": .pixels(4), "sm": .pixels(8), "md": .pixels(16),
        "lg": .pixels(24), "xl": .pixels(32), "xxl": .pixels(48), "2xl": .pixels(48),
    ]
    static let defaultRadius: [String: EMU] = [
        "none": .zero, "xs": .pixels(2), "sm": .pixels(4), "md": .pixels(8), "lg": .pixels(12),
        "xl": .pixels(16), "xxl": .pixels(24), "2xl": .pixels(24), "full": .pixels(9999), "pill": .pixels(9999),
    ]

    /// A hard-neutral style with no theme (detached / preview use).
    public static let standard = DeckStyle(
        background: .white, surface: .white, ink: Color("1A1A1A"), mutedInk: Color("5A6B7A"),
        link: Color("0563C1"),
        accents: ["4472C4", "ED7D31", "A5A5A5", "FFC000", "5B9BD5", "70AD47"].map(Color.init),
        isDark: false, headingFont: fallbackHeadingFont, bodyFont: fallbackBodyFont,
        type: makeTypeScale(headingFont: fallbackHeadingFont, bodyFont: fallbackBodyFont,
                            ink: Color("1A1A1A"), mutedInk: Color("5A6B7A"), accent1: Color("4472C4"), design: nil),
        spacing: TokenScale(defaultSpacing), radius: TokenScale(defaultRadius),
        margin: .inches(0.9), gutter: .inches(0.2))

    private static func merge(_ defaults: [String: EMU], _ overrides: [String: EMU]?) -> [String: EMU] {
        var m = defaults
        for (k, v) in overrides ?? [:] { m[k.lowercased()] = v }
        return m
    }

    /// Build the type scale, overlaying `design.md` typography tokens (by alias,
    /// per-facet) onto the built-in defaults.
    static func makeTypeScale(headingFont: String, bodyFont: String, ink: Color,
                              mutedInk: Color, accent1: Color, design: Design?) -> TypeScale {
        // role, size, weight, tracking, lineHeight, usesHeadingFont, color, uppercase
        let defs: [(TypeRole, Double, Int, Double, Double, Bool, Color, Bool)] = [
            (.kicker,  14, 700,  2.0,  1.0,  false, accent1,  true),
            (.display, 84, 700, -1.0,  1.02, true,  ink,      false),
            (.title,   34, 700, -0.5,  1.05, true,  ink,      false),
            (.heading, 22, 700, -0.25, 1.1,  true,  ink,      false),
            (.subhead, 22, 400,  0,    1.2,  false, mutedInk, false),
            (.body,    18, 400,  0,    1.25, false, ink,      false),
            (.stat,    96, 700, -1.0,  1.0,  true,  accent1,  false),
            (.quote,   36, 500, -0.25, 1.2,  true,  ink,      false),
            (.caption, 14, 400,  0,    1.2,  false, mutedInk, false),
        ]
        let aliases: [TypeRole: [String]] = [
            .kicker:  ["kicker", "eyebrow", "overline", "label"],
            .display: ["display", "hero-display", "hero"],
            // Title-tier names only — display/hero tokens belong to `.display`.
            // Ranking them here made a content-slide title inherit the display
            // SIZE and overflow its grid cell.
            .title:   ["title", "h1", "headline"],
            .heading: ["heading", "h2", "section-title"],
            .subhead: ["subhead", "subtitle", "h3"],
            .body:    ["body", "body-md", "paragraph", "base", "p"],
            .caption: ["caption", "body-sm", "small", "footnote"],
            .stat:    ["stat", "statnumber", "display-xl"],
            .quote:   ["quote", "blockquote"],
        ]
        var map: [TypeRole: TextStyle] = [:]
        for (role, size, weight, tracking, lineHeight, usesHeading, color, upper) in defs {
            var ts = TextStyle(font: usesHeading ? headingFont : bodyFont, sizePt: size,
                               weight: weight, trackingPt: tracking, lineHeight: lineHeight,
                               color: color, uppercase: upper)
            if let design, let token = firstToken(aliases[role] ?? [], in: design) {
                if let f = token.family { ts.font = f }
                if let s = token.sizePt { ts.sizePt = s }
                if let w = token.weight { ts.weight = w }
                if let t = token.trackingPt { ts.trackingPt = t }
                if let l = token.lineHeight { ts.lineHeight = l }
            }
            map[role] = ts
        }
        return TypeScale(map)
    }

    private static func firstToken(_ keys: [String], in design: Design) -> Design.TypeToken? {
        for key in keys { if let t = design.typeScale[key.lowercased()] { return t } }
        return nil
    }
}

public extension Presentation {
    /// The deck's resolved `DeckStyle`, reflecting the theme and any in-session
    /// `applyDesign`. Computed each call (the theme is mutable).
    var style: DeckStyle { DeckStyle(theme: theme, design: appliedDesign) }

    /// A style from an explicit `Design` without mutating the theme (preview).
    func style(with design: Design) -> DeckStyle { DeckStyle(theme: theme, design: design) }
}

public extension Run {
    /// Apply a resolved `TextStyle` (font/size/weight→bold/color/tracking) via
    /// the existing schema-safe setters.
    @discardableResult
    func apply(_ style: TextStyle) -> Run {
        fontName = style.font
        fontSize = style.sizePt
        bold = style.bold
        color = style.color
        letterSpacing = style.trackingPt != 0 ? style.trackingPt : nil
        return self
    }
}

public extension Paragraph {
    /// Apply a `TextStyle` to the paragraph (line spacing) and all its runs.
    @discardableResult
    func apply(_ style: TextStyle) -> Paragraph {
        setLineSpacing(style.lineHeight)
        for run in runs { _ = run.apply(style) }
        return self
    }
}
