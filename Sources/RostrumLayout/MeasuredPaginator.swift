import Foundation

/// Partitions ordered content using the caller's real layout measurement. It
/// never discards items or substitutes smaller text to satisfy a page count.
public enum MeasuredPaginator {
    /// `fits` should be deterministic and monotonic with prefix length. Each
    /// accepted prefix is checked; items are never reordered or discarded.
    public static func pages<Item>(_ items: [Item], fits: ([Item]) throws -> Bool) throws -> [[Item]] {
        guard !items.isEmpty else { return [] }
        func checkedFit(_ prefix: [Item]) throws -> Bool {
            try Task.checkCancellation()
            let result = try fits(prefix)
            try Task.checkCancellation()
            return result
        }
        // Keep the single-call path when everything fits. After this failure,
        // find the first boundary once, then seed probes with the preceding
        // page's size instead of repeatedly measuring every remaining suffix.
        if try checkedFit(items) { return [items] }
        var pages: [[Item]] = [], start = 0
        while start < items.count {
            // The first whole-input probe already failed. Later pages have no
            // known upper failure, so allow their complete remaining prefix.
            var high = items.count - start - (start == 0 ? 1 : 0)
            var accepted = 0
            if let previous = pages.last {
                var probe = min(previous.count, high)
                while probe <= high {
                    if try checkedFit(Array(items[start..<(start + probe)])) {
                        accepted = probe
                        if probe == high { break }
                        probe += min(probe, high - probe)
                    } else { high = probe - 1; break }
                }
            }
            // Only the interval between the last accepted prefix and the
            // first rejected probe needs binary refinement.
            while accepted < high {
                let low = accepted + 1
                let count = low + (high - low) / 2
                if try checkedFit(Array(items[start..<(start + count)])) { accepted = count }
                else { high = count - 1 }
            }
            guard accepted > 0 else {
                throw LayoutError.cannotFit("A single content item exceeds the readable page area.")
            }
            pages.append(Array(items[start..<(start + accepted)]))
            start += accepted
        }
        return pages
    }

    /// Split an oversized paragraph at word boundaries. Each returned string is
    /// an exact substring; joining the chunks reproduces the original text.
    public static func text(_ text: String, fits: (String) throws -> Bool) throws -> [String] {
        try Task.checkCancellation()
        let wholeFits = try fits(text)
        try Task.checkCancellation()
        if wholeFits { return [text] }
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
