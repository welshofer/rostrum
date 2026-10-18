import RostrumLayout

/// A panel is a presentation choice, not a limit on accepted source content.
/// Called only after the original panel arrangement fails its real fit check.
enum PanelPagination {
    static func reflow(_ original: IRSlide,
                       isolation: isolated (any Actor)? = #isolation,
                       fits: (IRSlide) throws -> Bool) throws -> [IRSlide] {
        try Task.checkCancellation()
        let panels = original.body?.panels ?? []
        // Four cards can often retain their visual treatment in two taller rows
        // on separate slides. Validate both before committing to that choice.
        if original.kind == .cards, panels.count == 4 {
            var first = original, second = original
            first.body?.panels = Array(panels.prefix(2))
            second.body?.panels = Array(panels.suffix(2))
            if try fits(first), try fits(second) {
                try Task.checkCancellation()
                return [first, second]
            }
        }

        struct Block {
            var heading: String?
            var text: String
            var visibleText: String {
                guard let heading, !heading.isEmpty else { return text }
                return text.isEmpty ? heading : heading + "\n" + text
            }
        }
        var base = original
        base.layout = "bullets"
        // Release the fixed caption/header area as well. A long lead or source
        // must be allowed to flow, rather than shrinking every continuation.
        base.body = Body()
        func candidate(_ blocks: [Block]) -> IRSlide {
            var page = base
            page.body?.bullets = blocks.map { Bullet(text: $0.visibleText) }
            return page
        }
        var blocks = [original.body?.kicker, original.body?.lead]
            .compactMap { $0 }.filter { !$0.isEmpty }.map { Block(text: $0) }
        blocks += panels.enumerated().map { index, panel in
            // Text continuations retain the source step number; rebuilding a
            // shorter numberedSteps slide would silently restart its badges.
            let heading = original.kind == .numberedSteps ? "\(index + 1). \(panel.heading)" : panel.heading
            return Block(heading: heading, text: panel.detail)
        }
        if let source = original.body?.source, !source.isEmpty { blocks.append(Block(text: source)) }
        var pieces: [Block] = []
        for block in blocks {
            // Repeat a panel's heading with each piece of its detail. Never
            // orphan a heading or change the exact Unicode/whitespace payload.
            let chunks = try MeasuredPaginator.text(block.text) { text in
                try fits(candidate([Block(heading: block.heading, text: text)]))
            }
            guard !chunks.isEmpty else {
                throw LayoutError.cannotFit("The panel heading exceeds the readable page area.")
            }
            pieces += chunks.map { Block(heading: block.heading, text: $0) }
        }
        let pages = try MeasuredPaginator.pages(pieces) { try fits(candidate($0)) }.map(candidate)
        guard !pages.isEmpty else { throw LayoutError.cannotFit("The panel slide has no content to reflow.") }
        return pages
    }
}
