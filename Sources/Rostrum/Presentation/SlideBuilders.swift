import Foundation

// One-call, design-aware slide builders. Each adds a FREE-SHAPE slide (never a
// template placeholder), laid out on a 12×12 Grid from the deck's DeckStyle, and
// returns the created Slide for further tweaking. Works on a blank Presentation()
// and inherits brand from a .potx + applyDesign alike — because everything reads
// from `deck.style`.

public extension Presentation {
    /// A cover: kicker, oversized display title, subtitle, and an accent rule.
    @discardableResult
    func titleSlide(_ title: String, subtitle: String? = nil,
                    kicker: String? = nil, style: DeckStyle? = nil) throws -> Slide {
        let s = style ?? self.style
        let slide = try blankCanvas()
        try slide.setBackground(.solid(s.background))
        let grid = deckGrid(s)
        try slide.addAccentRule(
            in: Rect(x: grid.content.minX, y: grid.cell(column: 0, row: 4).minY,
                     width: .inches(1.4), height: .points(4)), style: s)
        if let kicker {
            try slide.addKicker(kicker, in: grid.cell(column: 0, row: 4, columnSpan: 12), style: s)
        }
        try slide.addText(title, in: grid.cell(column: 0, row: 5, columnSpan: 11, rowSpan: 3),
                          role: .display, style: s, anchor: .bottom)
        if let subtitle {
            try slide.addText(subtitle, in: grid.cell(column: 0, row: 8, columnSpan: 9, rowSpan: 2),
                              role: .subhead, style: s)
        }
        return slide
    }

    /// A section divider on an accent field with auto-contrast text.
    @discardableResult
    func sectionSlide(_ title: String, subtitle: String? = nil,
                      number: Int? = nil, style: DeckStyle? = nil) throws -> Slide {
        let s = style ?? self.style
        let slide = try blankCanvas()
        let bg = s.accent(1)
        try slide.setBackground(.solid(bg))
        let onBg = s.textColor(on: bg)
        let grid = deckGrid(s)
        if let number {
            try slide.addText(String(format: "%02d", number),
                              in: grid.cell(column: 0, row: 3, columnSpan: 4, rowSpan: 2),
                              role: .display, style: s, color: onBg)
        }
        try slide.addText(title, in: grid.cell(column: 0, row: 5, columnSpan: 11, rowSpan: 3),
                          role: .title, style: s, color: onBg)
        if let subtitle {
            try slide.addText(subtitle, in: grid.cell(column: 0, row: 8, columnSpan: 10, rowSpan: 2),
                              role: .subhead, style: s, color: onBg)
        }
        return slide
    }

    /// A title + bulleted body.
    @discardableResult
    func bulletSlide(_ title: String, _ bullets: [String],
                     kicker: String? = nil, style: DeckStyle? = nil) throws -> Slide {
        let s = style ?? self.style
        let slide = try startContentSlide(s)
        let content = try header(on: slide, kicker: kicker, title: title, style: s)
        try slide.addBulletList(bullets, in: content, style: s)
        return slide
    }

    /// A title + two bulleted columns.
    @discardableResult
    func twoColumnSlide(_ title: String, left: [String], right: [String],
                        kicker: String? = nil, style: DeckStyle? = nil) throws -> Slide {
        let s = style ?? self.style
        let slide = try startContentSlide(s)
        let content = try header(on: slide, kicker: kicker, title: title, style: s)
        let cols = content.split(.horizontal, count: 2, gutter: s.gutter)
        try slide.addBulletList(left, in: cols[0], style: s)
        try slide.addBulletList(right, in: cols[1], style: s)
        return slide
    }

    /// A title + two headed cards (comparison).
    @discardableResult
    func comparisonSlide(_ title: String, leftHeader: String, left: [String],
                         rightHeader: String, right: [String], style: DeckStyle? = nil) throws -> Slide {
        let s = style ?? self.style
        let slide = try startContentSlide(s)
        let content = try header(on: slide, kicker: nil, title: title, style: s)
        let cols = content.split(.horizontal, count: 2, gutter: s.gutter)
        for (col, headerText, items) in [(cols[0], leftHeader, left), (cols[1], rightHeader, right)] {
            let card = try slide.addCard(in: col, style: s)
            let (head, body) = card.content.split(.vertical, ratio: 0.16, gutter: s.spacing.sm)
            try slide.addText(headerText, in: head, role: .heading, style: s)
            try slide.addBulletList(items, in: body, style: s)
        }
        return slide
    }

    /// A title + a full-width chart, colored from the brand accents by default.
    @discardableResult
    func chartSlide(_ title: String, _ kind: ChartKind, _ data: ChartData,
                    kicker: String? = nil, colors: [Color]? = nil,
                    options: ChartOptions = ChartOptions(), style: DeckStyle? = nil) throws -> Slide {
        let s = style ?? self.style
        let slide = try startContentSlide(s)
        let content = try header(on: slide, kicker: kicker, title: title, style: s)
        try slide.shapes.addChart(kind, data: data, frame: content,
                                  colors: colors ?? s.accents, options: options)
        return slide
    }

    /// A big centered stat with a caption — an impact slide.
    @discardableResult
    func calloutSlide(stat: String, caption: String,
                      kicker: String? = nil, style: DeckStyle? = nil) throws -> Slide {
        let s = style ?? self.style
        let slide = try blankCanvas()
        try slide.setBackground(.solid(s.background))
        let grid = deckGrid(s)
        if let kicker {
            try slide.addKicker(kicker, in: grid.cell(column: 0, row: 3, columnSpan: 12),
                                style: s, alignment: .center)
        }
        try slide.addText(stat, in: grid.cell(column: 0, row: 4, columnSpan: 12, rowSpan: 3),
                          role: .stat, style: s, align: .center)
        try slide.addText(caption, in: grid.cell(column: 2, row: 7, columnSpan: 8, rowSpan: 2),
                          role: .subhead, style: s, align: .center)
        return slide
    }

    /// A centered pull-quote with an attribution.
    @discardableResult
    func quoteSlide(_ quote: String, attribution: String? = nil, style: DeckStyle? = nil) throws -> Slide {
        let s = style ?? self.style
        let slide = try blankCanvas()
        try slide.setBackground(.solid(s.background))
        let grid = deckGrid(s)
        try slide.addText("\u{201C}\(quote)\u{201D}",
                          in: grid.cell(column: 1, row: 3, columnSpan: 10, rowSpan: 5),
                          role: .quote, style: s, align: .center, anchor: .middle)
        if let attribution {
            try slide.addText("— \(attribution)",
                              in: grid.cell(column: 1, row: 9, columnSpan: 10, rowSpan: 1),
                              role: .caption, style: s, align: .center)
        }
        return slide
    }

    // MARK: - Private layout helpers

    /// A blank, placeholder-free slide bound to a single layout — the canvas all
    /// free-shape builders paint on.
    private func blankCanvas() throws -> Slide { try slides.add() }

    private func deckGrid(_ style: DeckStyle) -> Grid {
        Grid(in: bounds, columns: 12, rows: 12, gutter: style.gutter, margin: style.margin)
    }

    /// A content slide with the background painted; returns the slide.
    private func startContentSlide(_ style: DeckStyle) throws -> Slide {
        let slide = try blankCanvas()
        try slide.setBackground(.solid(style.background))
        return slide
    }

    /// Place an optional kicker + a title across the top rows; return the content
    /// rect below them.
    private func header(on slide: Slide, kicker: String?, title: String, style: DeckStyle) throws -> Rect {
        let grid = deckGrid(style)
        var titleRow = 0
        if let kicker {
            try slide.addKicker(kicker, in: grid.cell(column: 0, row: 0, columnSpan: 12), style: style)
            titleRow = 1
        }
        try slide.addText(title, in: grid.cell(column: 0, row: titleRow, columnSpan: 12, rowSpan: 2),
                          role: .title, style: style)
        let top = titleRow + 2
        return grid.cell(column: 0, row: top, columnSpan: 12, rowSpan: 12 - top)
    }
}
