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
                func candidate(_ pairs: [Pair]) -> IRSlide {
                    var page = base
                    page.body?.left = Column(heading: left.heading, bullets: pairs.compactMap(\.left))
                    page.body?.right = Column(heading: right.heading, bullets: pairs.compactMap(\.right))
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
                pages = try MeasuredPaginator.pages(pairs) { try fits(candidate($0), false) }.map(candidate)
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
                pages = try MeasuredPaginator.pages(pieces) { try fits(candidate($0), hasImage) }.map(candidate)
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
}
