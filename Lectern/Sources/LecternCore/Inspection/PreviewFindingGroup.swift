import Foundation

/// A compact presentation of repeated messages. Detailed per-shape diagnostics
/// and the original per-slide warning strings remain available for export.
public struct PreviewFindingGroup: Sendable, Identifiable, Equatable {
    public let message: String
    public let slides: [Int]
    public let isVerificationNote: Bool
    public var id: String { (isVerificationNote ? "verification:" : "limitation:") + message }

    public var slideLabel: String {
        var ranges: [String] = []
        var start: Int?, previous: Int?
        func flush() {
            guard let start, let previous else { return }
            ranges.append(start == previous ? "\(start)" : "\(start)–\(previous)")
        }
        for number in slides {
            if let previous, number == previous + 1 { } else { flush(); start = number }
            previous = number
        }
        flush()
        return (slides.count == 1 ? "Slide " : "Slides ") + ranges.joined(separator: ", ")
    }

    static func collect(records: [SlidePreviewRecord], diagnostics: [SlidePreviewDiagnostics]) -> [Self] {
        var verification: [Int: Set<String>] = [:]
        for slide in diagnostics {
            let notes = Set(slide.issues.filter { $0.code == "unverifiedTextLayout" }.map(\.message))
            let concrete = Set(slide.issues.filter { $0.code != "unverifiedTextLayout" }.map(\.message))
            verification[slide.slideNumber] = notes.subtracting(concrete)
        }
        var order: [String] = [], groups: [String: (message: String, slides: Set<Int>, note: Bool)] = [:]
        for record in records {
            for message in combiningSymbolSubstitutions(record.warnings) {
                let note = verification[record.number]?.contains(message) == true
                let key = (note ? "verification:" : "limitation:") + message
                if groups[key] == nil { order.append(key); groups[key] = (message, [], note) }
                groups[key]?.slides.insert(record.number)
            }
        }
        return order.compactMap { key in
            groups[key].map { Self(message: $0.message, slides: $0.slides.sorted(), isVerificationNote: $0.note) }
        }
    }

    /// One sentence per substituted symbol. A fallback face that cannot be
    /// embedded is drawn from the installed font, so its separate restriction
    /// message is folded in. The detailed diagnostics keep both messages.
    static func combiningSymbolSubstitutions(_ warnings: [String]) -> [String] {
        let symbol = /^Preview symbol U\+([0-9A-F]+) uses registered (.+) because (.+) has no glyph\. The document font is unchanged\.$/
        let restricted = /^OS\/2 embedding restrictions prevent embedding (.+) in SVG\.$/
        let restrictedFaces = Set(warnings.compactMap { try? restricted.wholeMatch(in: $0).map { String($0.1) } })
        var substituted = Set<String>()
        var result: [String] = []
        for warning in warnings {
            guard let match = try? symbol.wholeMatch(in: warning),
                  let value = UInt32(match.1, radix: 16), let scalar = Unicode.Scalar(value) else {
                result.append(warning); continue
            }
            let face = String(match.2)
            substituted.insert(face)
            let source = restrictedFaces.contains(face) ? "the installed \(face)" : face
            result.append("\(Character(scalar)) (U+\(match.1)) is drawn with \(source) because \(match.3) lacks it.")
        }
        return result.filter { warning in
            guard let match = try? restricted.wholeMatch(in: warning) else { return true }
            return !substituted.contains(String(match.1))
        }
    }
}
