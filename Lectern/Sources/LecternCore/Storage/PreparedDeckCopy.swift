import Foundation

public extension DeckStorage {
    /// A copied deck that is not listed until its owner accepts the operation.
    /// Prepare off-main, then commit only after checking the current run token.
    /// Discard abandoned work; neither operation changes the source document.
    struct PreparedDeckCopy: Sendable {
        private let staged: URL
        public let destination: URL

        fileprivate init(staged: URL, destination: URL) {
            self.staged = staged; self.destination = destination
        }

        /// FileManager's move refuses an existing destination. Prior decks are
        /// never replaced, even if another writer wins an unlikely UUID collision.
        @discardableResult
        public func commit() throws -> URL {
            try FileManager.default.moveItem(at: staged, to: destination)
            return destination
        }

        public func discard() { try? FileManager.default.removeItem(at: staged) }

        /// Remove staging files a crash or force-quit left behind. Only regular
        /// `.library-demo-*.pending` files older than `age` are touched. An
        /// in-flight copy is normally safe because this runs once, from the
        /// startup task, which completes long before a recipe can be run and
        /// saved — the age check alone would not protect it (`copyItem` keeps
        /// the source's modification date, so a fresh copy of an old deck
        /// already looks stale). Best-effort: per-file errors are swallowed.
        ///
        /// - Returns: how many files were removed.
        @discardableResult
        public static func pruneAbandoned(in directory: URL, olderThan age: TimeInterval = 86_400,
                                          now: Date = Date(), fileManager: FileManager = .default) -> Int {
            guard let entries = try? fileManager.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
                options: [.skipsSubdirectoryDescendants]) else { return 0 }
            var removed = 0
            for url in entries {
                let name = url.lastPathComponent
                guard name.hasPrefix(".library-demo-"), name.hasSuffix(".pending") else { continue }
                let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey])
                // Only our own regular files go: a directory or link that
                // happens to carry the staging name is left alone.
                guard values?.isRegularFile == true else { continue }
                let modified = values?.contentModificationDate ?? now
                guard now.timeIntervalSince(modified) > age else { continue }
                if (try? fileManager.removeItem(at: url)) != nil { removed += 1 }
            }
            return removed
        }
    }

    /// Copy original bytes to a hidden temporary file in the destination volume.
    /// A completed file becomes visible through a final non-overwriting rename.
    static func prepareDeckCopy(from source: URL, title: String, into directory: URL,
                                now: Date = Date(), identifier: UUID = UUID()) throws -> PreparedDeckCopy {
        let manager = FileManager.default
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        let sanitized = DeckLibrary.sanitizedName(title)
        var label = ""
        for character in sanitized {
            guard label.utf8.count + String(character).utf8.count <= 120 else { break }
            label.append(character)
        }
        if label.isEmpty { label = "Library Demo" }
        let suffix = timestamp(now) + "-" + identifier.uuidString
        let destination = directory.appendingPathComponent(label + "-" + suffix).appendingPathExtension("pptx")
        let staged = directory.appendingPathComponent(".library-demo-" + UUID().uuidString + ".pending")
        do {
            try manager.copyItem(at: source, to: staged)
            return PreparedDeckCopy(staged: staged, destination: destination)
        } catch {
            try? manager.removeItem(at: staged)
            throw error
        }
    }
}
