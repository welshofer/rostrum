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
            for message in record.warnings {
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
}
