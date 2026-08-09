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
        let presentation = try Presentation(contentsOf: deck)
        let name = folderName(for: deck)
        let directory = parent.appendingPathComponent(name, isDirectory: true)
        let summary = try DeckExport.write(presentation, to: directory, named: name)
        return Outcome(directory: summary.directory,
                       markdownFile: summary.markdownFile,
                       slideCount: presentation.slides.count,
                       assetsWritten: summary.assetsWritten,
                       chartsWritten: summary.chartsWritten,
                       warnings: summary.warnings)
    }
}
