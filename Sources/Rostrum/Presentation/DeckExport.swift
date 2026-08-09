import Foundation

/// Write a deck out as a folder a person can read and a script can parse.
///
/// The shape on disk:
///
/// ```text
/// Quarterly Review/
/// ├── Quarterly Review.md      every slide's words, in order
/// ├── slide-01/
/// │   └── image1.png
/// └── slide-04/
///     ├── chart-1.csv
///     └── media1.mp4
/// ```
///
/// A slide gets a folder only when it has something to put in one; a deck of
/// pure text exports as a single Markdown file, which is the answer most of
/// the time.
///
/// This is a one-way projection and makes no claim otherwise. It is for
/// getting the content *out* — into a diff, a translation pass, a search
/// index, a script that wants the numbers behind a chart. Nothing here can
/// rebuild the `.pptx`, and the round-trip guarantee that governs opening and
/// saving a deck does not apply: the original file is only ever read.
public enum DeckExport {
    /// What a completed export produced.
    public struct Summary: Sendable {
        public let directory: URL
        public let markdownFile: URL
        public let slideFolders: Int
        public let assetsWritten: Int
        public let chartsWritten: Int
        /// Anything the export could not do, including whatever
        /// `DeckOutline.warnings` already knew about. Empty means complete.
        public let warnings: [String]
    }

    /// Extract `deck` into `directory`.
    ///
    /// The directory is created if it does not exist. Nothing is ever deleted:
    /// files this export writes are overwritten, and anything else already in
    /// there is left exactly where it is. Re-exporting the same deck to the
    /// same place is therefore safe, and — because neither the clock nor the
    /// source path is written into any output — produces identical bytes.
    ///
    /// - Parameters:
    ///   - deck: an opened presentation; it is only read.
    ///   - directory: where the export goes.
    ///   - name: the Markdown file's name, without extension. Defaults to the
    ///     directory's own name.
    @discardableResult
    public static func write(_ deck: Presentation,
                             to directory: URL,
                             named name: String? = nil,
                             fileManager: FileManager = .default) throws -> Summary {
        let outline = deck.outline()
        var warnings = outline.warnings

        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        var parts: [String: Part] = [:]
        for (uri, part) in deck.package.parts { parts[uri.value] = part }

        let stem = SlideOutline.sanitized(name ?? directory.lastPathComponent, fallback: "deck")
        let documentName = stem.lowercased().hasSuffix(".md") ? stem : stem + ".md"
        let markdownFile = directory.appendingPathComponent(documentName)
        let markdown = outline.markdown(title: name ?? directory.lastPathComponent)
        try Data(markdown.utf8).write(to: markdownFile, options: .atomic)

        var folders = 0
        var assetsWritten = 0
        var chartsWritten = 0

        for slide in outline.slides where slide.hasAttachments {
            let folder = directory.appendingPathComponent(slide.folderName, isDirectory: true)
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
            folders += 1

            for asset in slide.assets {
                guard let part = parts[asset.partName] else {
                    warnings.append("slide \(slide.number): \(asset.partName) is referenced but not in the package")
                    continue
                }
                try part.blob.write(to: folder.appendingPathComponent(asset.filename), options: .atomic)
                assetsWritten += 1
            }

            for chart in slide.charts {
                let csv = DeckExport.csv(chart.grid)
                try Data(csv.utf8).write(to: folder.appendingPathComponent(chart.filename), options: .atomic)
                chartsWritten += 1
            }
        }

        return Summary(directory: directory,
                       markdownFile: markdownFile,
                       slideFolders: folders,
                       assetsWritten: assetsWritten,
                       chartsWritten: chartsWritten,
                       warnings: warnings)
    }

    // MARK: - CSV

    /// RFC 4180: CRLF line endings, quotes doubled inside quoted fields.
    static func csv(_ rows: [[String]]) -> String {
        var out = ""
        for row in rows {
            out += row.map(field).joined(separator: ",")
            out += "\r\n"
        }
        return out
    }

    static func field(_ value: String) -> String {
        let guarded = needsFormulaGuard(value) ? "'" + value : value
        let mustQuote = guarded.contains(",") || guarded.contains("\"")
            || guarded.contains("\n") || guarded.contains("\r")
        guard mustQuote else { return guarded }
        return "\"" + guarded.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    /// Whether a cell would be executed rather than displayed.
    ///
    /// A category label lifted from someone else's deck lands in a file whose
    /// whole purpose is to be double-clicked into a spreadsheet, and a cell
    /// beginning `=` is a formula there, not a string. Prefixing an apostrophe
    /// is the standard defence and the only one that survives being opened by
    /// software we do not control.
    ///
    /// A leading `-` is the awkward case: it starts both a negative number and
    /// an expression. Numbers are left alone — mangling `-5` into `'-5` would
    /// corrupt real chart data to defend against nothing — and only a leading
    /// `-` that is *not* part of a number is guarded.
    static func needsFormulaGuard(_ value: String) -> Bool {
        guard let first = value.first else { return false }
        switch first {
        case "=", "+", "@", "\t", "\r":
            return true
        case "-":
            return Double(value) == nil
        default:
            return false
        }
    }
}
