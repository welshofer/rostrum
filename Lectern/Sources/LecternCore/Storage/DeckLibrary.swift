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
    public static func delete(_ deck: DeckFile, fileManager: FileManager = .default) throws {
        #if os(macOS)
        try fileManager.trashItem(at: deck.url, resultingItemURL: nil)
        #else
        try fileManager.removeItem(at: deck.url)
        #endif
    }
}
