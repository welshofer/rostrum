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
