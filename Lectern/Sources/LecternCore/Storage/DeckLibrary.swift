import Foundation

/// One deck already on disk.
public struct DeckFile: Identifiable, Sendable, Equatable {
    public var id: URL { url }
    public var url: URL
    /// The file's name without its extension — what the user named it, not
    /// `deck-2026-07-31.pptx`.
    public var name: String
    public var modified: Date
    public var byteCount: Int

    public init(url: URL, name: String, modified: Date, byteCount: Int) {
        self.url = url; self.name = name; self.modified = modified; self.byteCount = byteCount
    }
}

/// The decks a user has already generated.
///
/// They were always on disk and the app could not see them: once you pressed
/// New, the previous deck was unreachable from inside Lectern, and every one of
/// them had cost a real API call. This is the read side of `DeckStorage` —
/// nothing here writes a deck, it only finds the ones that are there.
public enum DeckLibrary {
    /// Every deck in `directory`, newest first.
    ///
    /// Newest first because the interesting deck is almost always the last one
    /// made. Sorted by modification date with the filename as a tiebreak, so
    /// two decks written in the same second still come back in a stable order
    /// rather than whatever the filesystem felt like.
    ///
    /// A missing directory is not an error — it is what a fresh install looks
    /// like, and an empty list says that perfectly well.
    public static func decks(in directory: URL, fileManager: FileManager = .default) -> [DeckFile] {
        let keys: [URLResourceKey] = [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey]
        guard let entries = try? fileManager.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]) else { return [] }

        return entries.compactMap { url -> DeckFile? in
            guard isDeck(url) else { return nil }
            let values = try? url.resourceValues(forKeys: Set(keys))
            // A directory named `something.pptx` is not a deck. Nothing creates
            // one, but the listing should describe what is there rather than
            // trust the extension.
            if values?.isRegularFile == false { return nil }
            return DeckFile(url: url,
                            name: url.deletingPathExtension().lastPathComponent,
                            modified: values?.contentModificationDate ?? .distantPast,
                            byteCount: values?.fileSize ?? 0)
        }
        .sorted {
            $0.modified == $1.modified
                ? $0.name.localizedStandardCompare($1.name) == .orderedAscending
                : $0.modified > $1.modified
        }
    }

    /// Whether this file is one of the user's decks, as opposed to something
    /// the app or PowerPoint left lying beside them.
    ///
    /// Shared with `DeckStorage.migrateDecks` on purpose. What gets listed and
    /// what gets moved into someone's Documents folder have to be the same
    /// answer; two copies of this rule would eventually disagree, and the way
    /// you would find out is a `rejected-draft.json` in Documents or a deck
    /// that migrated but never appeared.
    public static func isDeck(_ url: URL) -> Bool {
        guard url.pathExtension.lowercased() == "pptx" else { return false }
        // PowerPoint drops an owner file named `~$deck.pptx` beside a deck it
        // has open. It carries the .pptx extension and is not hidden, so
        // nothing else excludes it — and a real Decks folder had one, which
        // would have listed as a 165-byte deck the user never made and cannot
        // open.
        return !url.lastPathComponent.hasPrefix("~$")
    }

    /// Move a deck to the trash where that exists, so a mis-tap is recoverable,
    /// and delete it outright where it does not (Linux, and iOS, which has no
    /// trash). Deleting someone's document should be undoable wherever the
    /// platform can manage it.
    /// Move a deck to the trash where that exists, so a mis-tap is recoverable,
    /// and delete it outright where it does not (Linux, and iOS, which has no
    /// trash). Deleting someone's document should be undoable wherever the
    /// platform can manage it.
    public static func delete(_ deck: DeckFile, fileManager: FileManager = .default) throws {
        #if os(macOS)
        try fileManager.trashItem(at: deck.url, resultingItemURL: nil)
        #else
        try fileManager.removeItem(at: deck.url)
        #endif
    }

    /// Give a deck a different name, keeping it where it is.
    ///
    /// Deck names are model-generated slugs — `paperbanana-automating-academic-
    /// illustration-for-ai-scientis-2-rebranded` is a real one — and the
    /// library is now the first thing the app shows, so the name is worth being
    /// able to fix. This renames the file rather than storing a display name
    /// beside it: the deck is the document, and it should read the same in
    /// Finder as it does here.
    ///
    /// - Returns: the deck at its new URL.
    /// - Throws: `RenameProblem` for a name that cannot be used, and whatever
    ///   the file system says for anything else. Never overwrites.
    @discardableResult
    public static func rename(_ deck: DeckFile,
                              to proposed: String,
                              fileManager: FileManager = .default) throws -> DeckFile {
        let name = sanitizedName(proposed)
        guard !name.isEmpty else { throw RenameProblem.empty }
        guard name != deck.name else { return deck }

        let destination = deck.url
            .deletingLastPathComponent()
            .appendingPathComponent(name)
            .appendingPathExtension(deck.url.pathExtension)

        // A case-only change is a move onto itself on a case-insensitive
        // volume, which `fileExists` would call a collision.
        let sameFile = destination.standardizedFileURL == deck.url.standardizedFileURL
        if !sameFile, fileManager.fileExists(atPath: destination.path) {
            throw RenameProblem.nameTaken(name)
        }

        try fileManager.moveItem(at: deck.url, to: destination)
        return DeckFile(url: destination,
                        name: name,
                        modified: deck.modified,
                        byteCount: deck.byteCount)
    }

    /// Why a rename could not happen, in words a person can act on.
    public enum RenameProblem: Error, Equatable, CustomStringConvertible {
        case empty
        case nameTaken(String)

        public var description: String {
            switch self {
            case .empty: "A deck needs a name."
            case .nameTaken(let name): "There is already a deck called “\(name)”."
            }
        }
    }

    /// Strip what a filename cannot carry, rather than refusing the whole name.
    /// A user typing `Q3 / Q4 review` means one deck, not an error.
    static func sanitizedName(_ proposed: String) -> String {
        let illegal = CharacterSet(charactersIn: "/:\\")
            .union(.controlCharacters)
        return proposed
            .components(separatedBy: illegal)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            // A leading dot would hide the deck from the very list it is in.
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
    }
}
