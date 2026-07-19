import Foundation

public enum StyleTheme: String, Sendable, Equatable {
    case light, dark, unknown
}

/// A bundled, read-only design style: a `design.md` (Rostrum's opaque styling
/// input) plus a rendered hero thumbnail. Metadata is parsed from the `design.md`
/// header — name, vibe/category/theme, palette swatches, and display font — so the
/// picker can render a real, on-brand card (§6.2).
public struct Style: Sendable, Identifiable, Equatable {
    public var id: String { slug }
    public var slug: String
    public var name: String
    public var vibe: String?            // Corporate / Editorial / Technical … (shown in the pill)
    public var category: String?        // enterprise / developer / finance … (a filter tag)
    public var theme: StyleTheme
    public var tags: [String]
    public var swatches: [String]       // palette hex strings, in order
    public var displayFont: String?     // first family, quotes/stack stripped
    public var thumbnailURL: URL?
    public var designURL: URL

    public init(slug: String, name: String, vibe: String? = nil, category: String? = nil,
                theme: StyleTheme = .unknown, tags: [String] = [], swatches: [String] = [],
                displayFont: String? = nil, thumbnailURL: URL? = nil, designURL: URL) {
        self.slug = slug; self.name = name; self.vibe = vibe; self.category = category
        self.theme = theme; self.tags = tags; self.swatches = swatches
        self.displayFont = displayFont; self.thumbnailURL = thumbnailURL; self.designURL = designURL
    }

    /// The pill text, e.g. "Corporate · Dark".
    public var badge: String {
        [vibe, theme == .unknown ? nil : theme.rawValue.capitalized]
            .compactMap { $0 }.joined(separator: " · ")
    }
}

/// Loads a style catalog off-main. Supports `<root>/<slug>.md` (+ `<slug>.jpg`
/// thumbnail — Lectern's bundled layout) and `<root>/<slug>/design.md`.
public struct StyleCatalog: Sendable {
    public init() {}

    public func load(from root: URL) throws -> [Style] {
        let fm = FileManager.default
        var styles: [Style] = []
        let entries = (try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey])) ?? []
        for entry in entries.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let isDir = (try? entry.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            if isDir {
                let design = entry.appendingPathComponent("design.md")
                guard fm.fileExists(atPath: design.path) else { continue }
                styles.append(parse(slug: entry.lastPathComponent, designURL: design,
                                    thumbnail: thumbnail(in: entry, named: "thumbnail")))
            } else if entry.pathExtension.lowercased() == "md",
                      entry.lastPathComponent.lowercased() != "readme.md" {
                let slug = entry.deletingPathExtension().lastPathComponent
                styles.append(parse(slug: slug, designURL: entry,
                                    thumbnail: thumbnail(in: root, named: slug)))
            }
        }
        return styles
    }

    private func thumbnail(in dir: URL, named base: String) -> URL? {
        let fm = FileManager.default
        for ext in ["jpg", "jpeg", "png", "webp"] {
            let url = dir.appendingPathComponent("\(base).\(ext)")
            if fm.fileExists(atPath: url.path) { return url }
        }
        return nil
    }

    // MARK: - design.md header parsing

    private func parse(slug: String, designURL: URL, thumbnail: URL?) -> Style {
        let text = (try? String(contentsOf: designURL, encoding: .utf8)) ?? ""
        // YAML frontmatter takes precedence when present.
        if let front = frontmatter(text) {
            return Style(slug: slug, name: front.name ?? titleCase(slug), tags: front.tags,
                         thumbnailURL: thumbnail, designURL: designURL)
        }
        let name = firstHeading(text) ?? titleCase(slug)
        let vibe = field("Vibe", in: text)
        let category = field("Category", in: text)
        let theme = StyleTheme(rawValue: (field("Theme", in: text) ?? "").lowercased()) ?? .unknown
        let tags = [category, vibe].compactMap { $0?.lowercased() }
        return Style(slug: slug, name: name, vibe: vibe, category: category, theme: theme,
                     tags: tags, swatches: palette(text), displayFont: displayFont(text),
                     thumbnailURL: thumbnail, designURL: designURL)
    }

    /// First `# Heading`.
    private func firstHeading(_ text: String) -> String? {
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("# ") { return String(t.dropFirst(2)).trimmingCharacters(in: .whitespaces) }
        }
        return nil
    }

    /// A `**Key:** value` header field.
    private func field(_ key: String, in text: String) -> String? {
        let needle = "**\(key):**"
        for line in text.split(separator: "\n") {
            let t = line.trimmingCharacters(in: .whitespaces)
            if let r = t.range(of: needle, options: .caseInsensitive) {
                let value = t[r.upperBound...].trimmingCharacters(in: CharacterSet(charactersIn: " *`\t"))
                return value.isEmpty ? nil : value
            }
        }
        return nil
    }

    /// Hex colors under `## Color palette` (capped so a card stays legible).
    private func palette(_ text: String) -> [String] {
        guard let start = text.range(of: "## Color palette", options: .caseInsensitive) else { return [] }
        let after = text[start.upperBound...]
        let section = after.range(of: "\n## ").map { String(after[..<$0.lowerBound]) } ?? String(after)
        var hexes: [String] = []
        var scan = Substring(section)
        while let hash = scan.firstIndex(of: "#") {
            let rest = scan[scan.index(after: hash)...]
            let hex = rest.prefix { $0.isHexDigit }
            if hex.count == 6 || hex.count == 3 || hex.count == 8 {
                let value = "#" + hex.lowercased()
                if !hexes.contains(value) { hexes.append(value) }
            }
            scan = rest
        }
        return Array(hexes.prefix(6))
    }

    /// The first font family, unwrapping quoted CSS stacks like
    /// `"'CursorGothic', sans-serif"` → `CursorGothic`.
    private func displayFont(_ text: String) -> String? {
        guard let r = text.range(of: "Families:", options: .caseInsensitive) else { return nil }
        var body = Substring(text[r.upperBound...])
        if let dot = body.range(of: ". Weights", options: .caseInsensitive) { body = body[..<dot.lowerBound] }
        var s = body.trimmingCharacters(in: .whitespaces)
        // Peel any wrapping quote characters, then take the first family token.
        while let q = s.first, q == "\"" || q == "'" { s = String(s.dropFirst()) }
        if let i = s.firstIndex(where: { $0 == "," || $0 == "\"" || $0 == "'" || $0 == "." }) {
            s = String(s[..<i])
        }
        let name = s.trimmingCharacters(in: CharacterSet(charactersIn: " \"'"))
        return name.isEmpty ? nil : name
    }

    private func frontmatter(_ text: String) -> (name: String?, tags: [String])? {
        guard text.hasPrefix("---") else { return nil }
        var name: String?; var tags: [String] = []; var inFront = false
        for line in text.components(separatedBy: "\n") {
            if line.trimmingCharacters(in: .whitespaces) == "---" {
                if inFront { break }; inFront = true; continue
            }
            guard inFront, let colon = line.firstIndex(of: ":") else { continue }
            let key = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            if key == "name" { name = value.trimmingCharacters(in: CharacterSet(charactersIn: "\"'")) }
            if key == "tags" {
                tags = value.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
                    .split(separator: ",").map { $0.trimmingCharacters(in: CharacterSet(charactersIn: " \"'")) }
                    .filter { !$0.isEmpty }
            }
        }
        return (name, tags)
    }

    private func titleCase(_ slug: String) -> String {
        slug.split(whereSeparator: { $0 == "-" || $0 == "_" })
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }
}
