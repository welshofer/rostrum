import Foundation
import PDFKit

/// Extracts text from a dropped PDF to ground generation (§7.4). The first rung of
/// the ladder: raw text, capped so a huge document can't blow the context window.
/// Runs off-main (I6); the extracted text becomes `DeckRequest.groundingText`.
enum PDFGrounding {
    /// ~40k chars ≈ 10k tokens of source — plenty to ground a deck without
    /// dominating the request.
    static let maxChars = 40_000

    struct Source: Sendable, Equatable {
        var name: String
        var text: String
        var pageCount: Int
        var truncated: Bool
    }

    /// Returns `nil` for an image-only / unreadable PDF (no extractable text).
    static func extract(from url: URL) async -> Source? {
        await Task.detached(priority: .userInitiated) { () -> Source? in
            guard let doc = PDFDocument(url: url) else { return nil }
            var text = ""
            for i in 0..<doc.pageCount {
                if let page = doc.page(at: i), let s = page.string { text += s + "\n" }
                if text.count > maxChars { break }
            }
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            let truncated = trimmed.count > maxChars
            return Source(name: url.lastPathComponent,
                          text: String(trimmed.prefix(maxChars)),
                          pageCount: doc.pageCount,
                          truncated: truncated)
        }.value
    }
}
