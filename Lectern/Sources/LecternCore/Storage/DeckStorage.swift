import Foundation

/// Where a generated deck lives, and how it gets there when that answer
/// changes.
///
/// A deck is the user's document. It has to be somewhere they can find without
/// being told where to look, it has to survive the app being deleted and
/// reinstalled, and it has to be picked up by their backups. That rules out
/// the app bundle absolutely — it is code-signed and usually on a read-only
/// volume, so writing there is not even possible — and it rules out
/// Application Support, which is for data the app owns and sits inside a
/// Library folder Finder hides by default.
public enum DeckStorage {
    /// Move every deck out of a previous location into the current one.
    ///
    /// Changing where decks are written is not, on its own, a kindness: the
    /// user's existing decks are still in the old place, and from the app they
    /// have simply vanished. This moves them once.
    ///
    /// Deliberately conservative. A name already present in `destination` is
    /// left alone rather than overwritten — a collision means that deck is
    /// already here, and the copy in use is the one that stays. The old
    /// directory is removed only if it ends up empty, because leaving a stray
    /// file behind is a much better failure than deleting one.
    ///
    /// - Returns: how many decks were moved.
    @discardableResult
    public static func migrate(from legacy: URL, to destination: URL,
                               fileManager: FileManager = .default) -> Int {
        guard legacy.standardizedFileURL != destination.standardizedFileURL else { return 0 }
        guard let contents = try? fileManager.contentsOfDirectory(
            at: legacy, includingPropertiesForKeys: nil), !contents.isEmpty else { return 0 }

        guard (try? fileManager.createDirectory(
            at: destination, withIntermediateDirectories: true)) != nil else { return 0 }

        var moved = 0
        for deck in contents {
            let target = destination.appendingPathComponent(deck.lastPathComponent)
            guard !fileManager.fileExists(atPath: target.path) else { continue }
            if (try? fileManager.moveItem(at: deck, to: target)) != nil { moved += 1 }
        }

        if let left = try? fileManager.contentsOfDirectory(at: legacy, includingPropertiesForKeys: nil),
           left.isEmpty {
            try? fileManager.removeItem(at: legacy)
        }
        return moved
    }
}
