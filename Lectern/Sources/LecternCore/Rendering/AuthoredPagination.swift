import Foundation
import RostrumLayout

/// Reflow accepted content without asking a model to summarize or rewrite it.
/// The fit callback uses the production builder and its actual font measurement.
enum AuthoredPagination {
    struct Result {
        var deck: DeckIR
        var images: [String: Data]
        var warnings: [String]
    }

    static func prepare(_ input: DeckIR, images: [String: Data],
                        isolation: isolated (any Actor)? = #isolation,
                        usage: ((IRSlide, Bool) throws -> Double?)? = nil,
                        fits: (IRSlide, Bool) throws -> Bool) throws -> Result {
        var result = Result(deck: input, images: images, warnings: [])
        result.deck.slides = []
        var usedIDs = Set(input.slides.map(\.id)), additions: [String: [String]] = [:]
        for original in input.slides {
            try Task.checkCancellation()
            let supported = [.bullets, .imageLeft, .imageRight, .agenda, .twoColumn, .comparison].contains(original.kind)
            let hasImage = images[original.id] != nil
            guard supported, try !fits(original, hasImage) else {
                result.deck.slides.append(original); continue
            }
            var base = original
            // A tall standfirst becomes ordinary visible content on overflow.
            // Its words remain intact and can flow with the other paragraphs.
            var lines = [base.body?.lead].compactMap { $0 }.filter { !$0.isEmpty }
            base.body?.lead = nil
            var pages: [IRSlide] = []
            if original.kind == .comparison || original.kind == .twoColumn {
                let left = original.body?.left ?? Column(heading: "", bullets: [])
                let right = original.body?.right ?? Column(heading: "", bullets: [])
                // Keep each column's heading attached to its content; the IR
                // does not assert a row-by-row correspondence between columns.
                struct Pair { var left: String?; var right: String? }
                func candidate(_ pairs: [Pair], continuation: Bool = false) -> IRSlide {
                    var page = base
                    let lhs = pairs.compactMap(\.left), rhs = pairs.compactMap(\.right)
                    if continuation, lhs.isEmpty != rhs.isEmpty {
                        // The other column has finished. Keep the active heading
                        // with its words and release the unused half of the slide.
                        page.layout = "bullets"
                        page.body?.lead = lhs.isEmpty ? right.heading : left.heading
                        page.body?.bullets = (lhs.isEmpty ? rhs : lhs).map { Bullet(text: $0) }
                        page.body?.left = nil; page.body?.right = nil
                    } else {
                        page.body?.left = Column(heading: left.heading, bullets: lhs)
                        page.body?.right = Column(heading: right.heading, bullets: rhs)
                    }
                    return page
                }
                let lhs = lines + left.bullets
                let rhs = right.bullets
                let leftPieces = try lhs.flatMap { value in
                    try MeasuredPaginator.text(value) { try fits(candidate([Pair(left: $0)]), false) }
                }
                let rightPieces = try rhs.flatMap { value in
                    try MeasuredPaginator.text(value) { try fits(candidate([Pair(right: $0)]), false) }
                }
                let pairs = (0..<max(leftPieces.count, rightPieces.count)).map {
                    Pair(left: $0 < leftPieces.count ? leftPieces[$0] : nil,
                         right: $0 < rightPieces.count ? rightPieces[$0] : nil)
                }
                var partitions = try MeasuredPaginator.pages(pairs) { try fits(candidate($0), false) }
                if let tail = partitions.indices.dropFirst().first(where: { index in
                    partitions[index].allSatisfy { $0.left == nil } || partitions[index].allSatisfy { $0.right == nil }
                }) {
                    let remaining = partitions[tail...].flatMap { $0 }
                    let reflowed = try MeasuredPaginator.pages(remaining) {
                        try fits(candidate($0, continuation: true), false)
                    }
                    partitions.replaceSubrange(tail..., with: reflowed)
                }
                try balanceTail(&partitions, usage: usage.map { measure in
                    { values, index in try measure(candidate(values, continuation: index > 0), false) }
                })
                pages = partitions.enumerated().map { candidate($0.element, continuation: $0.offset > 0) }
            } else {
                if original.kind == .agenda { lines += original.body?.items ?? [] }
                else {
                    lines += (original.body?.bullets ?? []).flatMap { [$0.text] + ($0.subBullets ?? []).map { "– \($0)" } }
                }
                func candidate(_ values: [String]) -> IRSlide {
                    var page = base
                    if original.kind == .agenda { page.body?.items = values }
                    else { page.body?.bullets = values.map { Bullet(text: $0) } }
                    return page
                }
                let pieces = try lines.flatMap { value in
                    try MeasuredPaginator.text(value) { try fits(candidate([$0]), hasImage) }
                }
                var partitions = try MeasuredPaginator.pages(pieces) { try fits(candidate($0), hasImage) }
                try balanceTail(&partitions, usage: usage.map { measure in
                    { values, _ in try measure(candidate(values), hasImage) }
                })
                pages = partitions.map(candidate)
            }
            guard !pages.isEmpty else { throw LayoutError.cannotFit("The slide header or source needs a roomier layout.") }
            for index in pages.indices {
                if index > 0 {
                    var id = original.id + "-continued-\(index + 1)"
                    while usedIDs.contains(id) { id += "-next" }
                    usedIDs.insert(id); pages[index].id = id
                    additions[original.id, default: []].append(id)
                    if let image = images[original.id] { result.images[id] = image }
                }
                // Keep the exact measured headline: appending text to it could
                // consume another line and invalidate the successful fit.
                result.deck.slides.append(pages[index])
            }
            result.warnings.append("\(original.title ?? "Slide"): content flows across \(pages.count) slides to keep it readable.")
        }
        result.deck.sections = input.sections?.map { section in
            var section = section
            section.slideIds = section.slideIds.flatMap { [$0] + (additions[$0] ?? []) }
            return section
        }
        return result
    }

    /// Adjust only the last boundary, only for a sparse final page, and only
    /// after measuring both resulting pages. No global search or retained cache.
    private static func balanceTail<Item>(_ pages: inout [[Item]],
                                          usage: (([Item], Int) throws -> Double?)?) throws {
        guard pages.count > 1, let usage else { return }
        func measured(_ values: [Item], _ index: Int) throws -> Double? {
            try Task.checkCancellation()
            let result = try usage(values, index)
            try Task.checkCancellation()
            return result
        }
        let last = pages.count - 1, previous = last - 1
        guard let tail = try measured(pages[last], last), tail < 0.4,
              let head = try measured(pages[previous], previous), head - tail > 0.2,
              pages[previous].count > 1 else { return }
        let all = pages[previous] + pages[last]
        let boundary = pages[previous].count
        var best = boundary, difference = head - tail
        // At most eight candidate boundaries regardless of paragraph count.
        // Include the one-item move and spread the rest across the prior page.
        let shifts = Set((1...min(8, boundary - 1)).map {
            1 + ($0 - 1) * max(0, boundary - 2) / max(1, min(8, boundary - 1) - 1)
        }).sorted()
        for shift in shifts {
            let split = boundary - shift
            guard let lhs = try measured(Array(all[..<split]), previous),
                  let rhs = try measured(Array(all[split...]), last) else { continue }
            let delta = abs(lhs - rhs)
            if delta + 0.05 < difference {
                difference = delta; best = split
            }
        }
        if best != boundary {
            pages[previous] = Array(all[..<best]); pages[last] = Array(all[best...])
        }
    }
}
