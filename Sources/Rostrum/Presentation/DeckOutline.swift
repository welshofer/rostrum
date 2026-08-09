import Foundation

// A deck, reduced to the things a person wants back out of it: the words, and
// an inventory of what those words were sitting next to.
//
// This is deliberately a *projection*, not a parse. A `.pptx` is a design
// document and most of it — geometry, theme, animation, the careful kerning
// somebody argued about — has no text representation and is not attempted
// here. What survives is what survives being read aloud: titles, subtitles,
// bullets at their outline level, table cells, SmartArt labels, speaker notes,
// and a manifest of the media and chart data the slide carries.
//
// The outline holds no bytes. An asset records the package part it came from
// and how big it is; whoever writes the export resolves that back to the part.
// That keeps this type a value — cheap to build, safe to hand across an actor
// boundary, and testable without a filesystem.

/// One paragraph of slide text, at its outline level.
public struct OutlineParagraph: Sendable, Equatable {
    /// 0 for a top-level bullet, 1 for its first sub-bullet, and so on (`a:pPr@lvl`).
    public let level: Int
    /// The paragraph's text. May contain newlines, which were manual line breaks.
    public let text: String

    public init(level: Int, text: String) {
        self.level = level
        self.text = text
    }
}

/// A run of paragraphs that shared one text box.
public struct OutlineTextBlock: Sendable, Equatable {
    /// The raw OOXML placeholder type (`body`, `obj`, `ftr`, …), or `nil` for a
    /// free-standing text box that inherits nothing.
    public let placeholder: String?
    public let paragraphs: [OutlineParagraph]

    public init(placeholder: String?, paragraphs: [OutlineParagraph]) {
        self.placeholder = placeholder
        self.paragraphs = paragraphs
    }
}

/// A table's cell text, row by row.
public struct OutlineTable: Sendable, Equatable {
    public let rows: [[String]]

    public init(rows: [[String]]) {
        self.rows = rows
    }
}

/// A chart, flattened to the grid a spreadsheet would show.
///
/// Every chart kind lands in the same shape — categorical charts as
/// `Category | Series…`, scatter and bubble as one row per point — because the
/// point of the export is a file somebody can open, not a faithful model of
/// PowerPoint's plot structure.
public struct OutlineChart: Sendable, Equatable {
    public let title: String?
    /// The plot element name, e.g. `barChart`. `nil` when the chart XML has none.
    public let kind: String?
    /// Header row first. Cells are already rendered as text.
    public let grid: [[String]]
    /// The name this chart's CSV gets inside the slide's folder.
    public let filename: String

    public init(title: String?, kind: String?, grid: [[String]], filename: String) {
        self.title = title
        self.kind = kind
        self.grid = grid
        self.filename = filename
    }
}

/// A picture, movie or sound the slide carries.
public struct OutlineAsset: Sendable, Equatable {
    public enum Kind: String, Sendable {
        case image, video, audio
    }

    public let kind: Kind
    /// The name this asset gets inside the slide's folder — sanitized, and
    /// unique within that folder.
    public let filename: String
    /// The package part it came from, e.g. `/ppt/media/image1.png`.
    public let partName: String
    public let byteCount: Int
    /// The picture's alt text (`p:cNvPr@descr`), if the author wrote one.
    public let altText: String?

    public init(kind: Kind, filename: String, partName: String, byteCount: Int, altText: String?) {
        self.kind = kind
        self.filename = filename
        self.partName = partName
        self.byteCount = byteCount
        self.altText = altText
    }
}

/// One slide's worth of extracted content.
public struct SlideOutline: Sendable, Equatable {
    /// 1-based, and always the slide's real position — a slide that failed to
    /// read is recorded as a warning rather than shifting everything after it.
    public let number: Int
    /// The folder this slide's assets go in, e.g. `slide-03`.
    public let folderName: String
    public let title: String?
    public let subtitle: String?
    public let body: [OutlineTextBlock]
    public let tables: [OutlineTable]
    /// SmartArt node text, one array per diagram.
    public let diagrams: [[String]]
    public let charts: [OutlineChart]
    public let assets: [OutlineAsset]
    /// Speaker notes, one entry per paragraph.
    public let notes: [String]

    /// Whether this slide needs a folder of its own — the "if needed" in
    /// "a folder per slide, if needed".
    public var hasAttachments: Bool { !assets.isEmpty || !charts.isEmpty }
}

/// A whole deck's outline.
public struct DeckOutline: Sendable, Equatable {
    public let slides: [SlideOutline]
    /// Slides that could not be read, and content that could not be reached.
    /// Empty is the normal case; a non-empty list is the export telling you it
    /// is not complete rather than pretending it is.
    public let warnings: [String]

    public var assetCount: Int { slides.reduce(0) { $0 + $1.assets.count } }
    public var chartCount: Int { slides.reduce(0) { $0 + $1.charts.count } }
}

// MARK: - Extraction

extension Presentation {
    /// Read the deck's text and take an inventory of what it carries.
    ///
    /// Never throws. A deck somebody else made is exactly the deck most likely
    /// to have one unreadable slide in it, and losing the other forty because
    /// of it would be a poor trade; a slide that cannot be read becomes a line
    /// in `warnings` and the rest of the deck still comes out.
    public func outline() -> DeckOutline {
        let count = slides.count
        let width = max(2, String(count).count)
        var out: [SlideOutline] = []
        var warnings: [String] = []
        for index in 0..<count {
            let number = index + 1
            do {
                let slide = try slides.slide(at: index)
                out.append(SlideOutline(extracting: slide, number: number, folderWidth: width))
            } catch {
                warnings.append("slide \(number) could not be read: \(error)")
            }
        }
        return DeckOutline(slides: out, warnings: warnings)
    }
}

extension SlideOutline {
    init(extracting slide: Slide, number: Int, folderWidth: Int) {
        let flat = SlideOutline.flattened(slide.shapes.all)

        // Filenames are handed out once per slide folder, case-insensitively,
        // because the folder may well land on a case-insensitive filesystem
        // and two files differing only in case would silently become one.
        var taken: Set<String> = []
        func unique(_ candidate: String) -> String {
            var name = candidate
            var suffix = 2
            while taken.contains(name.lowercased()) {
                name = SlideOutline.appending(suffix: suffix, to: candidate)
                suffix += 1
            }
            taken.insert(name.lowercased())
            return name
        }

        var title: String?
        var subtitle: String?
        var body: [OutlineTextBlock] = []
        var tables: [OutlineTable] = []
        var assets: [OutlineAsset] = []
        var seenParts: Set<String> = []

        for shape in flat {
            if let table = (shape as? TableFrame)?.table {
                let rows = SlideOutline.rows(of: table)
                if !rows.isEmpty { tables.append(OutlineTable(rows: rows)) }
                continue
            }

            if let picture = shape as? Picture,
               let asset = SlideOutline.asset(from: picture, seen: &seenParts, name: unique) {
                assets.append(asset)
                continue
            }

            guard let frame = shape.textFrame else { continue }
            let paragraphs = frame.paragraphs.compactMap { paragraph -> OutlineParagraph? in
                let text = paragraph.plainText.trimmingCharacters(in: .whitespaces)
                guard !text.isEmpty else { return nil }
                return OutlineParagraph(level: max(0, paragraph.indentLevel), text: text)
            }
            guard !paragraphs.isEmpty else { continue }

            // `Slide.title` matches on placeholder index alone, which any
            // placeholder that omits `idx` also satisfies. The type is the
            // thing that actually says "title", so that is what is matched
            // here, and only the first one wins.
            let type = shape.placeholder?.type
            let joined = paragraphs.map(\.text).joined(separator: " ")
            if title == nil, type == "title" || type == "ctrTitle" {
                title = joined
                continue
            }
            if subtitle == nil, type == "subTitle" {
                subtitle = joined
                continue
            }
            body.append(OutlineTextBlock(placeholder: type, paragraphs: paragraphs))
        }

        // `slide.charts` does its own group recursion, so it is asked directly
        // rather than filtered out of the flattened list.
        var charts: [OutlineChart] = []
        for (index, chart) in slide.charts.enumerated() {
            charts.append(OutlineChart(title: chart.title,
                                       kind: chart.plotType,
                                       grid: SlideOutline.grid(of: chart),
                                       filename: unique("chart-\(index + 1).csv")))
        }

        let diagrams = slide.smartArtTexts.filter { !$0.isEmpty }
        let notes = slide.hasNotes
            ? slide.notesParagraphs.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            : []

        var padded = String(number)
        while padded.count < folderWidth { padded = "0" + padded }

        self.init(number: number,
                  folderName: "slide-" + padded,
                  title: title,
                  subtitle: subtitle,
                  body: body,
                  tables: tables,
                  diagrams: diagrams,
                  charts: charts,
                  assets: assets,
                  notes: notes)
    }

    /// Groups carry no text of their own, so they are unwrapped rather than
    /// listed. Without this, every picture and bullet inside a grouped shape
    /// is invisible to the export — and grouping is how real decks are built.
    static func flattened(_ shapes: [Shape]) -> [Shape] {
        var out: [Shape] = []
        for shape in shapes {
            if let group = shape as? GroupShape {
                out.append(contentsOf: flattened(group.shapes))
            } else {
                out.append(shape)
            }
        }
        return out
    }

    private static func asset(from picture: Picture,
                              seen: inout Set<String>,
                              name unique: (String) -> String) -> OutlineAsset? {
        let part: Part
        let kind: OutlineAsset.Kind
        if picture.isMedia, let media = picture.mediaPart {
            part = media
            kind = picture.isAudio ? .audio : .video
        } else if let image = picture.imagePart {
            part = image
            kind = .image
        } else {
            return nil
        }

        // One part used twice on one slide is one file in that slide's folder.
        let partName = part.uri.value
        guard !seen.contains(partName) else { return nil }
        seen.insert(partName)

        return OutlineAsset(kind: kind,
                            filename: unique(sanitized(part.uri.filename, fallback: "\(kind.rawValue).bin")),
                            partName: partName,
                            byteCount: part.blob.count,
                            altText: picture.altText.flatMap { $0.isEmpty ? nil : $0 })
    }

    private static func rows(of table: Table) -> [[String]] {
        guard table.rowCount > 0, table.columnCount > 0 else { return [] }
        return (0..<table.rowCount).map { row in
            (0..<table.columnCount).map { column in
                // A foreign table can declare more grid columns than a row has
                // cells, so a missing cell is a blank, not a failure.
                guard let cell = try? table.cell(row, column) else { return "" }
                guard let frame = cell.existingTextFrame else { return "" }
                return frame.paragraphs
                    .map(\.plainText)
                    .joined(separator: "\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
    }

    /// Flatten a chart to the grid its CSV will hold.
    ///
    /// `Chart.data` is deliberately not used: it returns `nil` unless every
    /// series lines up exactly with the categories, which is the right rule
    /// for *rewriting* a chart and the wrong one for reading somebody else's.
    /// The tolerant reads are used instead and ragged data comes out ragged.
    static func grid(of chart: Chart) -> [[String]] {
        if chart.isXY {
            let series = chart.xySeries
            let hasSize = series.contains { $0.points.contains { $0.size != nil } }
            let hasLabels = series.contains { !$0.xLabels.isEmpty }
            var header = ["Series"]
            if hasLabels { header.append("Label") }
            header += ["X", "Y"]
            if hasSize { header.append("Size") }

            var rows = [header]
            for entry in series {
                for (index, point) in entry.points.enumerated() {
                    var row = [entry.name]
                    if hasLabels { row.append(index < entry.xLabels.count ? entry.xLabels[index] : "") }
                    row.append(number(point.x))
                    row.append(number(point.y))
                    if hasSize { row.append(number(point.size)) }
                    rows.append(row)
                }
            }
            return rows
        }

        let categories = chart.categories
        let series = chart.series
        var rows = [["Category"] + series.map(\.name)]
        let depth = max(categories.count, series.map(\.values.count).max() ?? 0)
        for index in 0..<depth {
            var row = [index < categories.count ? categories[index] : ""]
            for entry in series {
                row.append(index < entry.values.count ? number(entry.values[index]) : "")
            }
            rows.append(row)
        }
        return rows
    }

    /// A number as a spreadsheet would want it, and stable across runs.
    ///
    /// Whole values lose the `.0` that `String(Double)` insists on, because a
    /// count of 12 written as "12.0" is a small lie about what the deck says.
    /// A gap point (`nil`) and a non-finite value are both an empty cell:
    /// neither has a truthful spelling in CSV.
    static func number(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "" }
        if value == value.rounded(), abs(value) < 1e15 { return String(Int64(value)) }
        return String(value)
    }

    /// Turn a package part's filename into one that is safe to create.
    ///
    /// A part name in a file somebody sent you is untrusted input that is
    /// about to become a path. Only the last component is kept, the character
    /// set is narrowed to things every filesystem accepts, and the reserved
    /// DOS device names are pushed out of the way — `NUL.png` is a legal part
    /// name and an unopenable file on Windows.
    ///
    /// A space is not one of the dangerous characters, and this also names the
    /// Markdown file from a title the user chose: turning `Q3 Review` into
    /// `Q3-Review` would be the export inventing a name nobody asked for.
    static func sanitized(_ raw: String, fallback: String) -> String {
        let base = raw.split(separator: "/").last.map(String.init) ?? ""
        var cleaned = ""
        var lastWasDash = false
        for scalar in base.unicodeScalars {
            let allowed = CharacterSet.alphanumerics.contains(scalar)
                || scalar == "." || scalar == "-" || scalar == "_" || scalar == " "
            if allowed {
                cleaned.unicodeScalars.append(scalar)
                lastWasDash = false
            } else if !lastWasDash {
                cleaned.append("-")
                lastWasDash = true
            }
        }
        let strip: (Character) -> Bool = { $0 == "." || $0 == "-" || $0 == " " }
        while let first = cleaned.first, strip(first) { cleaned.removeFirst() }
        while let last = cleaned.last, strip(last) { cleaned.removeLast() }
        guard !cleaned.isEmpty else { return fallback }

        let stem = cleaned.split(separator: ".").first.map(String.init) ?? cleaned
        if Self.reservedNames.contains(stem.uppercased()) { cleaned = "_" + cleaned }

        // Long enough for any real name, short enough to survive a deep
        // destination path on every platform.
        if cleaned.count > 80 {
            let ext = cleaned.split(separator: ".").count > 1 ? "." + (cleaned.split(separator: ".").last.map(String.init) ?? "") : ""
            let keep = max(1, 80 - ext.count)
            cleaned = String(cleaned.prefix(keep)) + ext
        }
        return cleaned
    }

    private static let reservedNames: Set<String> = {
        var names: Set<String> = ["CON", "PRN", "AUX", "NUL"]
        for index in 1...9 {
            names.insert("COM\(index)")
            names.insert("LPT\(index)")
        }
        return names
    }()

    static func appending(suffix: Int, to filename: String) -> String {
        let parts = filename.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count > 1, let ext = parts.last else { return "\(filename)-\(suffix)" }
        let stem = parts.dropLast().joined(separator: ".")
        return "\(stem)-\(suffix).\(ext)"
    }
}

// MARK: - Markdown

extension DeckOutline {
    /// Render the outline as one Markdown document.
    ///
    /// Deterministic: the same deck renders the same bytes, with nothing
    /// stamped in from the clock or the filesystem.
    public func markdown(title: String? = nil) -> String {
        var out: [String] = []
        out.append("# \(DeckOutline.heading(title ?? "Deck outline"))")
        out.append("")
        out.append("\(slides.count) slide\(slides.count == 1 ? "" : "s") · extracted by Rostrum")

        if !warnings.isEmpty {
            out.append("")
            out.append("> **This outline is incomplete.**")
            for warning in warnings {
                out.append("> - \(DeckOutline.inline(warning))")
            }
        }

        for slide in slides {
            out.append("")
            out.append("---")
            out.append("")
            if let title = slide.title {
                out.append("## \(slide.number). \(DeckOutline.heading(title))")
            } else {
                out.append("## \(slide.number). *(untitled)*")
            }

            if let subtitle = slide.subtitle {
                out.append("")
                out.append("**\(DeckOutline.heading(subtitle))**")
            }

            for block in slide.body {
                out.append("")
                out.append(contentsOf: DeckOutline.bullets(block.paragraphs))
            }

            for table in slide.tables where !table.rows.isEmpty {
                out.append("")
                out.append(contentsOf: DeckOutline.table(table.rows))
            }

            for diagram in slide.diagrams {
                out.append("")
                out.append("**Diagram**")
                out.append("")
                for label in diagram {
                    out.append("- \(DeckOutline.inline(label.replacingOccurrences(of: "\n", with: " ")))")
                }
            }

            for chart in slide.charts {
                out.append("")
                let name = chart.title.map { DeckOutline.inline($0) } ?? "Untitled chart"
                out.append("**Chart — \(name)**")
                out.append("")
                let kind = chart.kind.map { DeckOutline.inline($0) } ?? "chart"
                out.append("\(kind) · data in `\(slide.folderName)/\(chart.filename)`")
            }

            if !slide.assets.isEmpty {
                out.append("")
                out.append("**Media**")
                out.append("")
                for asset in slide.assets {
                    var line = "- `\(slide.folderName)/\(asset.filename)` — \(asset.kind.rawValue)"
                    line += ", \(DeckOutline.size(asset.byteCount))"
                    if let alt = asset.altText {
                        line += " — alt: \(DeckOutline.inline(alt.replacingOccurrences(of: "\n", with: " ")))"
                    }
                    out.append(line)
                }
            }

            if !slide.notes.isEmpty {
                out.append("")
                out.append("**Notes**")
                for note in slide.notes {
                    out.append("")
                    out.append(DeckOutline.blockText(note))
                }
            }
        }

        out.append("")
        return out.joined(separator: "\n")
    }

    /// Bullets, nested to the paragraph's outline level.
    static func bullets(_ paragraphs: [OutlineParagraph]) -> [String] {
        paragraphs.map { paragraph in
            let indent = String(repeating: "  ", count: min(paragraph.level, 8))
            // A manual line break inside a bullet becomes a CommonMark hard
            // break: trailing backslash, then a continuation line indented
            // past the marker so it stays inside the same item.
            let continuation = indent + "  "
            let lines = paragraph.text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            let escaped = lines.map { inline($0) }
            guard escaped.count > 1 else { return "\(indent)- \(escaped.first ?? "")" }
            let head = "\(indent)- \(escaped[0])\\"
            let tail = escaped.dropFirst().enumerated().map { offset, line -> String in
                offset == escaped.count - 2 ? "\(continuation)\(line)" : "\(continuation)\(line)\\"
            }
            return ([head] + tail).joined(separator: "\n")
        }
    }

    /// A GitHub-flavoured table. Cells lose their line breaks — a newline ends
    /// the row, and a mangled table helps nobody.
    static func table(_ rows: [[String]]) -> [String] {
        guard let first = rows.first else { return [] }
        let width = rows.map(\.count).max() ?? first.count
        func render(_ row: [String]) -> String {
            let cells = (0..<width).map { index -> String in
                let raw = index < row.count ? row[index] : ""
                return inline(raw.replacingOccurrences(of: "\n", with: " "))
            }
            return "| " + cells.joined(separator: " | ") + " |"
        }
        var out = [render(first)]
        out.append("| " + Array(repeating: "---", count: width).joined(separator: " | ") + " |")
        for row in rows.dropFirst() { out.append(render(row)) }
        return out
    }

    /// Escape the characters that would otherwise be read as markup.
    ///
    /// Deliberately eager. Slide text is somebody else's prose and it is full
    /// of asterisks, underscores and pipes that mean nothing; a reader who
    /// sees the file rendered should see the words that were on the slide.
    static func inline(_ text: String) -> String {
        var out = ""
        out.reserveCapacity(text.count)
        for character in text {
            switch character {
            case "\\", "`", "*", "_", "[", "]", "<", ">", "|", "#", "~":
                out.append("\\")
                out.append(character)
            default:
                out.append(character)
            }
        }
        return out
    }

    /// A heading or a bold line: escaped, and flattened to one line.
    static func heading(_ text: String) -> String {
        inline(text.replacingOccurrences(of: "\n", with: " "))
    }

    /// A standalone paragraph, where a leading `-` or `1.` would start a list
    /// that was never in the deck.
    static func blockText(_ text: String) -> String {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        return lines.map { line -> String in
            var escaped = inline(line)
            if let first = escaped.first, first == "-" || first == "+" || first == "=" {
                escaped = "\\" + escaped
            } else if let match = line.firstIndex(where: { !$0.isNumber }),
                      match != line.startIndex,
                      line[match] == "." || line[match] == ")" {
                let offset = line.distance(from: line.startIndex, to: match)
                escaped = String(line.prefix(offset)) + "\\" + inline(String(line.dropFirst(offset)))
            }
            return escaped
        }.joined(separator: "\n")
    }

    /// A size a person can read, computed the same way every time.
    static func size(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        let units = ["KB", "MB", "GB"]
        var value = Double(bytes) / 1024
        var unit = 0
        while value >= 1024, unit < units.count - 1 {
            value /= 1024
            unit += 1
        }
        // No "%@": on Linux's Foundation a Swift String is not a safe CVarArg.
        return String(format: "%.1f", value) + " " + units[unit]
    }
}
