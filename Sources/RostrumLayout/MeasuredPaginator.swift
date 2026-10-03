import Foundation

/// Partitions ordered content using the caller's real layout measurement. It
/// never discards items or substitutes smaller text to satisfy a page count.
public enum MeasuredPaginator {
    /// `fits` should be deterministic and monotonic with prefix length. Each
    /// accepted prefix is checked; items are never reordered or discarded.
    public static func pages<Item>(_ items: [Item], fits: ([Item]) throws -> Bool) throws -> [[Item]] {
        guard !items.isEmpty else { return [] }
        var pages: [[Item]] = [], start = 0
        while start < items.count {
            try Task.checkCancellation()
            let remaining = Array(items[start...])
            if try fits(remaining) { pages.append(remaining); break }
            var low = 1, high = remaining.count - 1, accepted = 0
            while low <= high {
                try Task.checkCancellation()
                let count = (low + high) / 2
                if try fits(Array(remaining.prefix(count))) { accepted = count; low = count + 1 }
                else { high = count - 1 }
            }
            guard accepted > 0 else {
                throw LayoutError.cannotFit("A single content item exceeds the readable page area.")
            }
            pages.append(Array(remaining.prefix(accepted)))
            start += accepted
        }
        return pages
    }

    /// Split an oversized paragraph at word boundaries. Each returned string is
    /// an exact substring; joining the chunks reproduces the original text.
    public static func text(_ text: String, fits: (String) throws -> Bool) throws -> [String] {
        try Task.checkCancellation()
        if try fits(text) { return [text] }
        var tokens: [String] = [], start = text.startIndex, index = start
        while index < text.endIndex {
            let next = text.index(after: index)
            if text[index].isWhitespace && (next == text.endIndex || !text[next].isWhitespace) {
                tokens.append(String(text[start..<next])); start = next
            }
            index = next
        }
        if start < text.endIndex { tokens.append(String(text[start...])) }
        return try pages(tokens) { try fits($0.joined()) }.map { $0.joined() }
    }
}
