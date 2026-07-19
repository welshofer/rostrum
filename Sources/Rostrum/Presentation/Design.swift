import Foundation

/// A design specification parsed from a `design.md` file: fonts, a color
/// palette, and free-form direction. Apply it to a deck's theme with
/// `Presentation.applyDesign(_:)`.
///
/// Two Markdown shapes are understood, and they may be mixed:
///
/// 1. A simple hand-written spec — `##` sections with `- Role: Value` lists:
///    ```md
///    ## Fonts
///    - Heading: Avenir Next
///    - Body: Inter
///    ## Palette
///    - Background: #F7F4EE
///    - Accent 1: #18A999
///    ## Direction
///    Clean and editorial.
///    ```
/// 2. A compiled design-system export — front-matter (`**Theme:** light`), a
///    bare-hex `## Color palette`, `## Typography`, and a fenced style prompt
///    carrying `Color tokens:` / `Typography tokens:` groups. Semantic token
///    names ("primary", "brand-yellow", …) land in `colors`; the ordered
///    swatch list lands in `palette`.
///
/// Recognized roles (background, text, accent 1–6, link, …) are mapped straight
/// onto theme slots by `applyDesign`; a token-named palette with no explicit
/// roles is mapped heuristically (lightest→background, darkest→text for a light
/// theme, the curated palette → accents). Parsing never throws on content —
/// bad hex and unknown groups are skipped.
public struct Design: Sendable, Equatable {
    /// Design-system name (the H1, or `**ID:**` / `Design system name:`).
    public var name: String?
    /// `light` or `dark`, from `**Theme:**`. Drives background/text mapping.
    public var themeMode: String?
    /// Heading / display typeface → the theme's major (heading) font.
    public var headingFont: String?
    /// Body / paragraph typeface → the theme's minor (body) font.
    public var bodyFont: String?
    /// The ordered swatch list from a bare-hex `## Color palette`.
    public var palette: [Color]
    /// Named colors, keyed by lowercased role/token name ("primary",
    /// "brand-yellow", "accent 1", …).
    public var colors: [String: Color]
    /// Free-form direction / vibe / personality notes (not machine-applied).
    public var direction: String?
    /// Any `**Key:** value` front-matter (id, category, theme, vibe, …).
    public var metadata: [String: String]

    public init(name: String? = nil, themeMode: String? = nil,
                headingFont: String? = nil, bodyFont: String? = nil,
                palette: [Color] = [], colors: [String: Color] = [:],
                direction: String? = nil, metadata: [String: String] = [:]) {
        self.name = name
        self.themeMode = themeMode
        self.headingFont = headingFont
        self.bodyFont = bodyFont
        self.palette = palette
        self.colors = colors
        self.direction = direction
        self.metadata = metadata
    }

    /// Load and parse a `design.md` from disk.
    public init(contentsOf url: URL) throws {
        self = Design.parse(try String(contentsOf: url, encoding: .utf8))
    }

    // MARK: - Parsing

    private enum Mode { case none, fonts, colors, direction, ignore }

    /// Parse a `design.md` document. See the type doc for the accepted shapes.
    public static func parse(_ markdown: String) -> Design {
        var design = Design()
        var mode = Mode.none
        var directionParts: [String] = []
        var headingFamily: String?, bodyFamily: String?, anyFamily: String?

        func note(_ s: String) {
            let t = s.trimmingCharacters(in: .whitespaces)
            if !t.isEmpty { directionParts.append(t) }
        }
        func ingestFont(label: String, spec: String) {
            let family = extractFamily(spec)
            guard !family.isEmpty else { return }
            let isHeading = ["hero", "display", "heading", "title", "major", "h1", "h2", "h3"]
                .contains { label.contains($0) }
            let isBody = ["body", "paragraph", "subtitle", "caption", "minor", "text", "label", "overline"]
                .contains { label.contains($0) }
            if isHeading { headingFamily = headingFamily ?? family }
            if isBody { bodyFamily = bodyFamily ?? family }
            if !isHeading && !isBody { anyFamily = anyFamily ?? family }
        }

        for raw in markdown.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("```") { continue }

            if line.hasPrefix("#") {
                let heading = normalizeHeading(line)
                if line.hasPrefix("# ") && design.name == nil {
                    design.name = String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                }
                mode = sectionMode(heading)
                continue
            }

            guard let (label, value) = splitLabel(line) else {
                // A bare line: swatches while in a color section, else prose.
                switch mode {
                case .colors: design.palette.append(contentsOf: colorTokens(line))
                case .direction: note(line)
                default: break
                }
                continue
            }

            // Group / metadata labels take precedence over data lines.
            switch label {
            case "color tokens", "colors", "colours", "color palette", "palette", "swatches":
                mode = .colors; continue
            case "typography tokens", "typography", "fonts":
                mode = .fonts; continue
            case "families", "family":
                mode = .fonts; anyFamily = anyFamily ?? emptyToNil(extractFamily(value)); continue
            case "direction", "notes", "design token description", "overall visual personality":
                mode = .direction; note(value); continue
            case "spacing tokens", "radius and shape tokens", "component tokens", "color rationale",
                 "typography rationale", "layout system", "depth and hierarchy", "shape language",
                 "component language", "style source", "style-content firewall",
                 "detected source-domain vocabulary":
                mode = .ignore; continue
            case "theme":
                design.metadata["theme"] = value; design.themeMode = value.lowercased(); continue
            case "vibe":
                design.metadata["vibe"] = value; note(value); continue
            case "design system name":
                design.name = design.name ?? emptyToNil(value); design.metadata[label] = value; continue
            case "id", "category":
                design.metadata[label] = value; continue
            default:
                break
            }

            // A data line within the active section.
            switch mode {
            case .colors:
                if let color = parseColor(value) { design.colors[label] = color }
            case .fonts:
                ingestFont(label: label, spec: value)
            case .direction:
                note(line)
            default:
                break
            }
        }

        design.headingFont = headingFamily ?? anyFamily
        design.bodyFont = bodyFamily ?? anyFamily
        let joined = directionParts.joined(separator: " ").trimmingCharacters(in: .whitespaces)
        design.direction = joined.isEmpty ? nil : joined
        return design
    }

    // MARK: - Role → theme slot

    /// The theme slot an explicit palette role maps onto, or nil for token names
    /// that need heuristic handling. Note the DrawingML `bg1`/`tx1` swap: a
    /// background lives on `lt1`, text on `dk1`.
    static func themeSlot(forRole role: String) -> ThemeSlot? {
        switch role {
        case "background", "bg", "page", "surface": return .lt1
        case "text", "ink", "foreground", "fg": return .dk1
        case "dark", "dark 2": return .dk2
        case "light", "light 2": return .lt2
        case "accent 1", "accent1": return .accent1
        case "accent 2", "accent2": return .accent2
        case "accent 3", "accent3": return .accent3
        case "accent 4", "accent4": return .accent4
        case "accent 5", "accent5": return .accent5
        case "accent 6", "accent6": return .accent6
        case "link", "hyperlink": return .hlink
        case "visited", "followed", "visited link": return .folHlink
        default: return nil
        }
    }

    /// The hyperlink color to use, preferring an explicit link/blue token.
    static func linkColor(_ design: Design) -> Color? {
        let keys = design.colors.keys.sorted()
        if let k = keys.first(where: { $0.contains("link") }) { return design.colors[k] }
        if let k = keys.first(where: { $0 == "brand-blue" }) { return design.colors[k] }
        if let k = keys.first(where: { $0.contains("blue") }) { return design.colors[k] }
        return nil
    }

    // MARK: - Parsing helpers

    private static func emptyToNil(_ s: String) -> String? { s.isEmpty ? nil : s }

    private static func normalizeHeading(_ line: String) -> String {
        String(line.drop { $0 == "#" })
            .trimmingCharacters(in: CharacterSet(charactersIn: " *`#")).lowercased()
    }

    private static func sectionMode(_ heading: String) -> Mode {
        switch heading {
        case "fonts", "typography": return .fonts
        case "palette", "colors", "colours", "color palette", "colour palette", "swatches": return .colors
        case "direction", "notes", "vibe": return .direction
        default: return .none
        }
    }

    /// Split a `Key: Value` line (with or without a `-`/`*` list marker and
    /// `**`/`` ` `` emphasis). Value may be empty (for group headers).
    private static func splitLabel(_ line: String) -> (label: String, value: String)? {
        var body = Substring(line)
        while let first = body.first, "-*+ ".contains(first) { body = body.dropFirst() }
        guard let colon = body.firstIndex(of: ":") else { return nil }
        let trim = CharacterSet(charactersIn: " *`")
        let label = String(body[..<colon]).trimmingCharacters(in: trim).lowercased()
        let value = String(body[body.index(after: colon)...]).trimmingCharacters(in: trim)
        guard !label.isEmpty else { return nil }
        return (label, value)
    }

    /// The font family named in a typography spec: `family Roobert PRO, size…`
    /// or `Roobert PRO. Weights…` or a bare `Avenir Next`.
    private static func extractFamily(_ spec: String) -> String {
        var s = Substring(spec)
        if let r = s.range(of: "family ", options: .caseInsensitive) { s = s[r.upperBound...] }
        if let i = s.firstIndex(where: { $0 == "," || $0 == "." || $0 == ";" }) { s = s[..<i] }
        if let r = s.range(of: "Weight", options: .caseInsensitive) { s = s[..<r.lowerBound] }
        return String(s).trimmingCharacters(in: .whitespaces)
    }

    /// Every 6-digit hex color token on a line (bare swatch lists).
    static func colorTokens(_ line: String) -> [Color] {
        line.split { !($0.isHexDigit || $0 == "#") }.compactMap { parseColor(String($0)) }
    }

    /// A 6-digit hex color, with or without `#`; nil if not valid hex.
    static func parseColor(_ text: String) -> Color? {
        let hex = text.hasPrefix("#") ? String(text.dropFirst()) : text
        guard hex.count == 6, hex.allSatisfy(\.isHexDigit) else { return nil }
        return Color(hex)
    }

    static func luminance(_ color: Color) -> Double {
        let v = Int(color.hex, radix: 16) ?? 0
        let r = Double((v >> 16) & 0xFF), g = Double((v >> 8) & 0xFF), b = Double(v & 0xFF)
        return (0.299 * r + 0.587 * g + 0.114 * b) / 255
    }
}

extension Presentation {
    /// Apply a parsed `Design` to this deck's theme: set the major/minor fonts
    /// and map colors onto theme scheme colors. Explicit roles (background,
    /// text, accent 1–6, link, …) map directly; a token-named palette with no
    /// explicit roles is mapped heuristically — lightest color → background and
    /// darkest → text for a light theme (inverted for dark), the curated
    /// `palette` → accents, and a blue/link token → the hyperlink color.
    /// Unmapped colors stay on the `Design` value for your own layout code.
    public func applyDesign(_ design: Design) {
        if let heading = design.headingFont { theme.majorFont = heading }
        if let body = design.bodyFont { theme.minorFont = body }

        var set = Set<ThemeSlot>()
        for key in design.colors.keys.sorted() {
            if let slot = Design.themeSlot(forRole: key) {
                theme.setColor(slot, design.colors[key]!)
                set.insert(slot)
            }
        }

        // Background & text by luminance, unless explicit roles set them.
        let named = design.colors.keys.sorted().compactMap { design.colors[$0] }
        let pool = design.palette + named
        var background: Color?, text: Color?
        if !pool.isEmpty {
            let ordered = pool.sorted {
                let (a, b) = (Design.luminance($0), Design.luminance($1))
                return a != b ? a < b : $0.hex < $1.hex
            }
            let light = (design.themeMode ?? "light").lowercased() != "dark"
            background = light ? ordered.last : ordered.first
            text = light ? ordered.first : ordered.last
        }
        if !set.contains(.lt1), let background { theme.setColor(.lt1, background); set.insert(.lt1) }
        if !set.contains(.dk1), let text { theme.setColor(.dk1, text); set.insert(.dk1) }

        // Accents from the curated palette order, skipping near-neutrals and
        // the chosen background/text — only if no explicit accents were given.
        let accentSlots: [ThemeSlot] = [.accent1, .accent2, .accent3, .accent4, .accent5, .accent6]
        if accentSlots.allSatisfy({ !set.contains($0) }) {
            let source = design.palette.isEmpty ? named : design.palette
            var used = Set([background?.hex, text?.hex].compactMap { $0 })
            var accents: [Color] = []
            for color in source {
                let lum = Design.luminance(color)
                if lum > 0.92 || lum < 0.06 || used.contains(color.hex) { continue }
                used.insert(color.hex)
                accents.append(color)
                if accents.count == accentSlots.count { break }
            }
            for (slot, color) in zip(accentSlots, accents) { theme.setColor(slot, color) }
        }

        if !set.contains(.hlink), let link = Design.linkColor(design) {
            theme.setColor(.hlink, link)
        }
    }

    /// Convenience: parse a `design.md` from disk and apply it, returning the
    /// parsed `Design` (for its `direction`, `palette`, or extra `colors`).
    @discardableResult
    public func applyDesign(contentsOf url: URL) throws -> Design {
        let design = try Design(contentsOf: url)
        applyDesign(design)
        return design
    }
}
