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
    /// Where the app's own diagnostics go — the rejected drafts a failed
    /// generation leaves behind.
    ///
    /// Application Support, not the decks folder. That file is the model's
    /// rendering of the user's prompt plus up to 40,000 characters lifted from
    /// whatever PDF they attached, and on iOS the decks folder is published to
    /// the Files app. App-owned data belongs in the app's own directory; only
    /// the decks were ever in the wrong place.
    public static func diagnosticsDirectory(appSupport: URL) -> URL {
        appSupport.appendingPathComponent("Lectern/Diagnostics", isDirectory: true)
    }

    /// How long a rejected draft is kept before it is deleted unread.
    public static let diagnosticsRetention: TimeInterval = 7 * 24 * 60 * 60

    /// Delete diagnostics older than `olderThan`.
    ///
    /// These files are the model's rendering of the user's prompt plus up to
    /// 40,000 characters lifted from whatever PDF they attached. Keeping one
    /// while a failure is being investigated is the point; keeping every one
    /// forever is a liability nobody asked for, and until now nothing ever
    /// deleted them.
    ///
    /// - Returns: how many were removed.
    @discardableResult
    public static func pruneDiagnostics(in directory: URL,
                                        olderThan: TimeInterval = diagnosticsRetention,
                                        now: Date = Date(),
                                        fileManager: FileManager = .default) -> Int {
        guard let entries = try? fileManager.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsSubdirectoryDescendants]) else { return 0 }

        var removed = 0
        for url in entries {
            // Only our own drafts. Anything else in there was not put there by
            // us and is not ours to delete.
            guard url.lastPathComponent.hasPrefix("rejected-draft"),
                  url.pathExtension.lowercased() == "json" else { continue }
            let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? now
            guard now.timeIntervalSince(modified) > olderThan else { continue }
            if (try? fileManager.removeItem(at: url)) != nil { removed += 1 }
        }
        return removed
    }

    /// A filename-safe, sortable UTC stamp: `20260731T221500Z`.
    ///
    /// Built from components rather than a shared `ISO8601DateFormatter`, which
    /// is not `Sendable` and cannot be a static under strict concurrency. No
    /// colons: legal on APFS, a nuisance everywhere a path gets shell-quoted.
    public static func timestamp(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        let c = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        return String(format: "%04d%02d%02dT%02d%02d%02dZ",
                      c.year ?? 0, c.month ?? 0, c.day ?? 0,
                      c.hour ?? 0, c.minute ?? 0, c.second ?? 0)
    }

    /// Move the user's decks out of a previous location into the current one.
    ///
    /// Changing where decks are written is not, on its own, a kindness: the
    /// user's existing decks are still in the old place, and from the app they
    /// have simply vanished. This moves them once.
    ///
    /// **Decks only.** Whatever else is in that folder is the app's own —
    /// `rejected-draft.json` is a diagnostic, `~$deck.pptx` is a lock file
    /// PowerPoint left behind — and none of it belongs in someone's Documents
    /// folder. Application Support was never the wrong home for those; it was
    /// only ever the wrong home for documents. What counts as a deck is
    /// `DeckLibrary.isDeck`, deliberately the same rule that decides what gets
    /// listed, so the two cannot drift apart.
    ///
    /// Deliberately conservative. A name already present in `destination` is
    /// left alone rather than overwritten — a collision means that deck is
    /// already here, and the copy in use is the one that stays. The old
    /// directory is removed only if it ends up completely empty, because
    /// leaving a stray file behind is a much better failure than deleting one.
    ///
    /// - Returns: how many decks were moved.
    @discardableResult
    public static func migrateDecks(from legacy: URL, to destination: URL,
                                    fileManager: FileManager = .default) -> Int {
        guard legacy.standardizedFileURL != destination.standardizedFileURL else { return 0 }
        guard let contents = try? fileManager.contentsOfDirectory(
            at: legacy, includingPropertiesForKeys: nil) else { return 0 }
        let decks = contents.filter(DeckLibrary.isDeck)
        guard !decks.isEmpty else { return 0 }

        guard (try? fileManager.createDirectory(
            at: destination, withIntermediateDirectories: true)) != nil else { return 0 }

        var moved = 0
        for deck in decks {
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

