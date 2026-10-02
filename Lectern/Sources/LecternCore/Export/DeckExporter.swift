import Foundation
import Rostrum

/// Take a deck apart into a folder of readable pieces.
///
/// Lectern's other direction. Everything else here turns a prompt into a
/// `.pptx`; this opens a `.pptx` — one Lectern made or one that arrived by
/// email — and writes out what it says: a Markdown file of every slide's
/// words, and a folder per slide holding its pictures, movies, sounds and the
/// data behind its charts.
///
/// The work is Rostrum's (`DeckExport`). What lives here is the part with a
/// user in front of it: choosing the folder's name, and reporting what came
/// out in terms the UI can show without re-deriving anything.
public enum DeckExporter {
    /// What one export produced.
    public struct Outcome: Sendable {
        public let directory: URL
        public let markdownFile: URL
        public let slideCount: Int
        public let assetsWritten: Int
        public let chartsWritten: Int
        /// Non-empty when the deck only partly came out. The UI shows these
        /// rather than reporting a clean success it cannot vouch for.
        public let warnings: [String]
    }

    /// The folder a deck should export into: the deck's own name, minus
    /// `.pptx`.
    ///
    /// A deck called `Q3 Review.pptx` becomes `Q3 Review/`, which is the name
    /// the person already has in their head. Path separators cannot survive
    /// `lastPathComponent`, so what comes back is always a single component.
    public static func folderName(for deck: URL) -> String {
        let stem = deck.deletingPathExtension().lastPathComponent
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return stem.isEmpty ? "Deck" : stem
    }

    /// Open the deck at `deck` and export it into a new folder inside `parent`.
    ///
    /// Re-exporting the same deck to the same place overwrites the files this
    /// wrote and leaves everything else in the folder alone, so running it
    /// twice is a refresh rather than a mess.
    public static func export(deckAt deck: URL, into parent: URL) throws -> Outcome {
        try Task.checkCancellation()
        let presentation = try Presentation(contentsOf: deck,
            limits: .init(totalUncompressedBytes: DeckInspector.defaultReadLimit))
        let name = folderName(for: deck)
        let directory = parent.appendingPathComponent(name, isDirectory: true)
        try Task.checkCancellation()
        try TableTextExtractor.preflight(presentation)
        let summary = try DeckExport.write(presentation, to: directory, named: name)
        // DeckExport owns the base outline/assets. Refresh that file first, then
        // append the metadata Lectern inspects, so repeated exports never duplicate it.
        let metadata = metadataMarkdown(from: presentation)
        if !metadata.text.isEmpty {
            let base = try String(contentsOf: summary.markdownFile, encoding: .utf8)
            try (base + metadata.text).write(to: summary.markdownFile, atomically: true, encoding: .utf8)
        }
        return Outcome(directory: summary.directory,
                       markdownFile: summary.markdownFile,
                       slideCount: presentation.slides.count,
                       assetsWritten: summary.assetsWritten,
                       chartsWritten: summary.chartsWritten,
                       warnings: summary.warnings + metadata.warnings)
    }
    private static func metadataMarkdown(from deck: Presentation) -> (text: String, warnings: [String]) {
        var lines: [String] = []
        var warnings: [String] = []
        var remainingTableCells = TableTextExtractor.maximumTotalCells
        // Compare against the exact projection used for the base Markdown.
        // Count equal matrices, so repeated identical tables are not duplicated.
        let outlineTables = Dictionary(uniqueKeysWithValues: deck.outline().slides.map { ($0.number - 1, $0.tables) })
        let sections = Array(deck.sections)
        if !sections.isEmpty {
            lines += ["", "## Sections", ""]
            for section in sections {
                let slides = section.slideIndices.map { String($0 + 1) }.joined(separator: ", ")
                lines.append("- \(inline(section.name)) — slides \(slides)")
            }
        }
        for index in 0..<deck.slides.count {
            guard let slide = try? deck.slides.slide(at: index) else { continue }
            if let root = try? slide.part.dom() {
                let extraction = TableTextExtractor.extract(in: root, remainingCells: &remainingTableCells)
                warnings += extraction.warnings.map { "slide \(index + 1): " + $0 }
                var represented: [[[String]]: Int] = [:]
                for table in outlineTables[index] ?? [] { represented[table.rows, default: 0] += 1 }
                for table in extraction.tables where !table.rows.isEmpty {
                    if let count = represented[table.rows], count > 0 {
                        represented[table.rows] = count - 1
                    } else {
                        lines += ["", "## Slide \(index + 1) table \(table.index + 1) text", ""]
                        lines += tableMarkdown(table.rows)
                    }
                }
                if represented.values.contains(where: { $0 > 0 }) {
                    warnings.append("slide \(index + 1): ordinary table outline differs from namespace-aware table text; the base table projection may be incomplete or inaccurate")
                }
            }
            let comments = DeckDetailExtractor.comments(in: slide)
            guard !comments.isEmpty else { continue }
            lines += ["", "## Slide \(index + 1) comments", ""]
            for comment in comments {
                let status = comment.kind == "legacy" ? "legacy" : (comment.resolved ? "resolved" : "open")
                lines.append("### \(inline(comment.author)) (\(status))")
                lines += quoted(comment.text)
                for reply in comment.replies {
                    lines += ["", "Reply — \(inline(reply.author))"]
                    lines += quoted(reply.text)
                }
                lines.append("")
            }
        }
        return (lines.isEmpty ? "" : lines.joined(separator: "\n") + "\n", warnings)
    }

    private static func tableMarkdown(_ rows: [[String]]) -> [String] {
        guard let first = rows.first else { return [] }
        func row(_ cells: [String]) -> String { "| " + cells.map(inline).joined(separator: " | ") + " |" }
        return [row(first), "| " + Array(repeating: "---", count: first.count).joined(separator: " | ") + " |"]
            + rows.dropFirst().map(row)
    }

    private static func inline(_ text: String) -> String {
        var result = text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n").replacingOccurrences(of: "\n", with: " ")
        for character in ["\\", "`", "*", "_", "[", "]", "<", ">", "#", "|"] {
            result = result.replacingOccurrences(of: character, with: "\\" + character)
        }
        return result
    }

    private static func quoted(_ text: String) -> [String] {
        text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n").map { "> " + inline($0) }
    }

}
