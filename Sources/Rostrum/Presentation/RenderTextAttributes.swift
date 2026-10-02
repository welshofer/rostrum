/// Text styling repeats across cells and lines. Keep only serialized styling
/// within one render; positions, text, font resolution and diagnostics remain live.
final class RenderTextAttributes {
    private struct Key: Hashable {
        let family: String?
        let size: Double
        let color: String
        let bold: Bool
        let italic: Bool
        let tracking: Double
        let usesKerning: Bool

        static func == (lhs: Self, rhs: Self) -> Bool {
            // Swift String equality normalizes canonically equivalent Unicode.
            // Serialization preserves the original bytes, including font aliases.
            let sameFamily: Bool
            switch (lhs.family, rhs.family) {
            case (nil, nil): sameFamily = true
            case let (left?, right?): sameFamily = left.utf8.elementsEqual(right.utf8)
            default: sameFamily = false
            }
            return sameFamily && lhs.size == rhs.size && lhs.color.utf8.elementsEqual(rhs.color.utf8)
                && lhs.bold == rhs.bold && lhs.italic == rhs.italic && lhs.tracking == rhs.tracking
                && lhs.usesKerning == rhs.usesKerning
        }
    }
    private var entries: [Key: String] = [:]
    private(set) var retainedBytes = 0
    var count: Int { entries.count }
    private static let byteLimit = 65_536
    private static let entryLimit = 128

    func reset() { entries.removeAll(keepingCapacity: true); retainedBytes = 0 }

    func attributes(for run: ResolvedTextRun, family: String?) -> String {
        let key = Key(family: family, size: run.fontSize, color: run.color,
                      bold: run.bold, italic: run.italic, tracking: run.tracking, usesKerning: run.usesKerning)
        if let cached = entries[key] { return cached }
        var result = " font-size=\"\(SVGNumber.decimal(run.fontSize))\" fill=\"\(run.color)\""
        if let family, !family.isEmpty {
            result += " font-family=\"\(SVGMarkup.escape(family)), sans-serif\""
        }
        if run.bold { result += " font-weight=\"bold\"" }
        if run.italic { result += " font-style=\"italic\"" }
        // SVG 1.1 kerning=0 disables font pair adjustments without disabling
        // ligatures. Span-wide textLength alone would stretch kerned glyphs.
        if !run.usesKerning { result += " kerning=\"0\"" }
        if run.tracking != 0 { result += " letter-spacing=\"\(SVGNumber.decimal(run.tracking))\"" }
        // Bound keys as well as values. Unusual fonts/styles still serialize
        // normally when the cache is full or a single entry exceeds the budget.
        let cost = 256 + (family?.utf8.count ?? 0) + run.color.utf8.count + result.utf8.count
        if entries.count < Self.entryLimit, cost <= Self.byteLimit - retainedBytes {
            entries[key] = result
            retainedBytes += cost
        }
        return result
    }
}

enum SVGMarkup {
    static func escape(_ text: String) -> String {
        // Most slide text and typeface names need no escaping. Avoid building
        // an identical string character by character in that common case.
        guard text.utf8.contains(where: { $0 == 38 || $0 == 60 || $0 == 62 || $0 == 34 }) else { return text }
        var result = ""
        result.reserveCapacity(text.utf8.count)
        for character in text {
            switch character {
            case "&": result += "&amp;"
            case "<": result += "&lt;"
            case ">": result += "&gt;"
            case "\"": result += "&quot;"
            default: result.append(character)
            }
        }
        return result
    }
}
