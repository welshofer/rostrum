import Foundation

/// A design specification parsed from a `design.md` file: fonts, a named color
/// palette, and free-form direction. Apply it to a deck's theme with
/// `Presentation.applyDesign(_:)`.
///
/// The expected Markdown is deliberately simple and human/LLM-writable —
/// `##` sections with `- Key: Value` lists:
///
/// ```md
/// # Design
///
/// ## Fonts
/// - Heading: Avenir Next
/// - Body: Inter
///
/// ## Palette
/// - Background: #F7F4EE
/// - Text: #22303F
/// - Accent 1: #18A999
/// - Accent 2: #FF6B5B
/// - Link: #1155CC
///
/// ## Direction
/// Clean and editorial. Generous whitespace, bold oversized headlines,
/// one accent color used sparingly.
/// ```
///
/// Section headings are matched case-insensitively: `Fonts`; `Palette` or
/// `Colors`; `Direction` or `Notes`. Unrecognized sections are ignored,
/// unrecognized keys are preserved in `colors`, and malformed color values are
/// skipped — parsing never throws on content.
public struct Design: Sendable, Equatable {
    /// Heading / display typeface → the theme's major (heading) font.
    public var headingFont: String?
    /// Body / paragraph typeface → the theme's minor (body) font.
    public var bodyFont: String?
    /// Every named palette color, keyed by its lowercased role name
    /// ("background", "text", "accent 1", "primary", …). Recognized roles are
    /// pushed onto the theme by `applyDesign`; the rest stay here for your own
    /// layout code.
    public var colors: [String: Color]
    /// Free-form design direction / notes. Not machine-applied — guidance for
    /// human authors or content generators.
    public var direction: String?

    public init(headingFont: String? = nil, bodyFont: String? = nil,
                colors: [String: Color] = [:], direction: String? = nil) {
        self.headingFont = headingFont
        self.bodyFont = bodyFont
        self.colors = colors
        self.direction = direction
    }

    /// Load and parse a `design.md` from disk.
    public init(contentsOf url: URL) throws {
        self = Design.parse(try String(contentsOf: url, encoding: .utf8))
    }

    /// Parse a `design.md` document. See the type doc for the format.
    public static func parse(_ markdown: String) -> Design {
        var design = Design()
        var section = ""
        var directionLines: [String] = []

        for rawLine in markdown.components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("#") {
                section = normalizeHeading(line)
                continue
            }
            switch section {
            case "fonts":
                guard let (key, value) = keyValue(line) else { continue }
                if ["heading", "headings", "title", "display", "major"].contains(key) {
                    design.headingFont = value
                } else if ["body", "text", "paragraph", "minor"].contains(key) {
                    design.bodyFont = value
                }
            case "palette", "colors", "colours":
                guard let (key, value) = keyValue(line), let color = parseColor(value) else { continue }
                design.colors[key] = color
            case "direction", "notes":
                if !line.isEmpty { directionLines.append(line) }
            default:
                continue
            }
        }
        let joined = directionLines.joined(separator: " ").trimmingCharacters(in: .whitespaces)
        design.direction = joined.isEmpty ? nil : joined
        return design
    }

    // MARK: - Role → theme slot

    /// The theme slot a palette role name maps onto, or nil if the role is not
    /// one Rostrum applies to the theme. Note the DrawingML `bg1`/`tx1` swap:
    /// a background color is stored on `lt1` and text on `dk1`.
    static func themeSlot(forRole role: String) -> ThemeSlot? {
        switch role {
        case "background", "bg", "page", "surface": return .lt1
        case "text", "ink", "foreground", "fg", "body": return .dk1
        case "dark", "dark 2": return .dk2
        case "light", "light 2": return .lt2
        case "accent 1", "accent1", "primary": return .accent1
        case "accent 2", "accent2", "secondary": return .accent2
        case "accent 3", "accent3", "tertiary": return .accent3
        case "accent 4", "accent4": return .accent4
        case "accent 5", "accent5": return .accent5
        case "accent 6", "accent6": return .accent6
        case "link", "hyperlink": return .hlink
        case "visited", "followed", "visited link": return .folHlink
        default: return nil
        }
    }

    // MARK: - Parsing helpers

    private static func normalizeHeading(_ line: String) -> String {
        String(line.drop { $0 == "#" })
            .trimmingCharacters(in: CharacterSet(charactersIn: " *`#")).lowercased()
    }

    /// Split a `- Key: Value` (or `Key: Value`) line, stripping list markers and
    /// Markdown emphasis. Returns lowercased key and trimmed value.
    private static func keyValue(_ line: String) -> (key: String, value: String)? {
        var body = Substring(line)
        while let first = body.first, "-*+".contains(first) { body = body.dropFirst() }
        guard let colon = body.firstIndex(of: ":") else { return nil }
        let trim = CharacterSet(charactersIn: " *`")
        let key = String(body[..<colon]).trimmingCharacters(in: trim).lowercased()
        let value = String(body[body.index(after: colon)...]).trimmingCharacters(in: trim)
        guard !key.isEmpty, !value.isEmpty else { return nil }
        return (key, value)
    }

    /// A 6-digit hex color, with or without a leading `#`; nil if not valid hex
    /// (so a non-color value never traps `Color.init`).
    static func parseColor(_ text: String) -> Color? {
        let hex = text.hasPrefix("#") ? String(text.dropFirst()) : text
        guard hex.count == 6, hex.allSatisfy(\.isHexDigit) else { return nil }
        return Color(hex)
    }
}

extension Presentation {
    /// Apply a parsed `Design` to this deck's theme: set the major/minor fonts
    /// and map recognized palette roles (background, text, accent 1…6, link, …)
    /// onto the theme's scheme colors. Colors with an unrecognized role are left
    /// on the `Design` value for your own use. Existing slides that reference
    /// theme colors/fonts update to match.
    public func applyDesign(_ design: Design) {
        if let heading = design.headingFont { theme.majorFont = heading }
        if let body = design.bodyFont { theme.minorFont = body }
        for (role, color) in design.colors {
            if let slot = Design.themeSlot(forRole: role) {
                theme.setColor(slot, color)
            }
        }
    }

    /// Convenience: parse a `design.md` from disk and apply it in one call,
    /// returning the parsed `Design` (e.g. for its `direction` or extra colors).
    @discardableResult
    public func applyDesign(contentsOf url: URL) throws -> Design {
        let design = try Design(contentsOf: url)
        applyDesign(design)
        return design
    }
}
