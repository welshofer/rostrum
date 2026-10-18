import Foundation

/// One preview limitation and every slide it affects. Grouping keeps a deck-wide
/// caveat from repeating once per slide; the flat per-slide warnings remain the
/// exported record.
public struct PreviewLimitation: Hashable, Sendable {
    public let message: String
    /// One-based slide numbers in ascending order; empty for deck-level warnings.
    public let slides: [Int]

    public init(message: String, slides: [Int]) {
        self.message = message; self.slides = slides
    }

    /// Groups `"Slide N: message"` warnings by message. Groups affecting the most
    /// slides come first; ties keep first-appearance order.
    public static func grouped(_ warnings: [String]) -> [PreviewLimitation] {
        var order: [String] = [], slides: [String: Set<Int>] = [:]
        for warning in warnings {
            let (slide, message) = split(warning)
            if slides[message] == nil { order.append(message); slides[message] = [] }
            if let slide { slides[message]?.insert(slide) }
        }
        let groups = order.map { PreviewLimitation(message: $0, slides: slides[$0, default: []].sorted()) }
        return groups.enumerated().sorted {
            ($0.element.slides.count, -$0.offset) > ($1.element.slides.count, -$1.offset)
        }.map(\.element)
    }

    /// "Slide 4", "Slides 2–4, 7" or "All 33 slides" when `slideCount` matches.
    public func slideSummary(slideCount: Int? = nil) -> String {
        guard !slides.isEmpty else { return "Deck" }
        if let slideCount, slideCount > 1, slides == Array(1...slideCount) { return "All \(slideCount) slides" }
        var ranges: [String] = [], start = slides[0], end = slides[0]
        func close() { ranges.append(start == end ? "\(start)" : end == start + 1 ? "\(start), \(end)" : "\(start)–\(end)") }
        for slide in slides.dropFirst() {
            if slide == end + 1 { end = slide } else { close(); start = slide; end = slide }
        }
        close()
        return (slides.count == 1 ? "Slide " : "Slides ") + ranges.joined(separator: ", ")
    }

    private static func split(_ warning: String) -> (Int?, String) {
        guard warning.hasPrefix("Slide "), let colon = warning.firstIndex(of: ":"),
              let number = Int(warning[warning.index(warning.startIndex, offsetBy: 6)..<colon])
        else { return (nil, warning) }
        return (number, warning[warning.index(after: colon)...].trimmingCharacters(in: .whitespaces))
    }
}
