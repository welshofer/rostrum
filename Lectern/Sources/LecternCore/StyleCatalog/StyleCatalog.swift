import Foundation

/// A bundled, read-only design style: a `design.md` (Rostrum's input, opaque to
/// Lectern) plus an optional thumbnail. `name`/`tags` come from YAML frontmatter
/// when present, else a title-cased slug.
public struct Style: Sendable, Identifiable, Equatable {
    public var id: String { slug }
    public var slug: String
    public var name: String
    public var tags: [String]
    public var thumbnailURL: URL?
    public var designURL: URL

    public init(slug: String, name: String, tags: [String], thumbnailURL: URL?, designURL: URL) {
        self.slug = slug; self.name = name; self.tags = tags
        self.thumbnailURL = thumbnailURL; self.designURL = designURL
    }
}

/// Loads a style catalog off-main from a resources directory. Supports both
/// `<root>/<slug>/design.md` (+ thumbnail.{png,jpg,webp}) and flat `<root>/<slug>.md`.
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
                let slug = entry.lastPathComponent
                styles.append(style(slug: slug, designURL: design, thumbnail: firstThumbnail(in: entry)))
            } else if entry.pathExtension.lowercased() == "md",
                      entry.lastPathComponent.lowercased() != "readme.md" {
                let slug = entry.deletingPathExtension().lastPathComponent
                let thumb = ["png", "jpg", "jpeg", "webp"]
                    .map { root.appendingPathComponent("\(slug).\($0)") }
                    .first { fm.fileExists(atPath: $0.path) }
                styles.append(style(slug: slug, designURL: entry, thumbnail: thumb))
            }
        }
        return styles
    }

    private func firstThumbnail(in dir: URL) -> URL? {
        let fm = FileManager.default
        for name in ["thumbnail.png", "thumbnail.jpg", "thumbnail.jpeg", "thumbnail.webp"] {
            let url = dir.appendingPathComponent(name)
            if fm.fileExists(atPath: url.path) { return url }
        }
        return nil
    }

    private func style(slug: String, designURL: URL, thumbnail: URL?) -> Style {
        let front = frontmatter(of: designURL)
        return Style(
            slug: slug,
            name: front.name ?? titleCase(slug),
            tags: front.tags,
            thumbnailURL: thumbnail,
            designURL: designURL)
    }

    /// Parse optional `---`-delimited YAML frontmatter for `name:` and `tags:`.
    private func frontmatter(of url: URL) -> (name: String?, tags: [String]) {
        guard let text = try? String(contentsOf: url, encoding: .utf8),
              text.hasPrefix("---") else { return (nil, []) }
        let lines = text.components(separatedBy: "\n")
        var name: String?
        var tags: [String] = []
        var inFront = false
        for line in lines {
            if line.trimmingCharacters(in: .whitespaces) == "---" {
                if inFront { break }
                inFront = true; continue
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
