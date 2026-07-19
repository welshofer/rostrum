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
        // Fit the display size to the title length so a long headline stays on the
        // slide (a 96pt eight-word title would run off the top).
        let fitted = title.count > 44 ? 60.0 : (title.count > 28 ? 74.0 : s.type(.display).sizePt)
        let titleStyle = s.with(.display) { $0.sizePt = fitted }
        try slide.addAccentRule(
            in: Rect(x: grid.content.minX, y: grid.cell(column: 0, row: 3).minY,
                     width: .inches(1.4), height: .points(4)), style: s)
        if let kicker {
            try slide.addKicker(kicker, in: grid.cell(column: 0, row: 3, columnSpan: 12), style: s)
        }
        try slide.addText(title, in: grid.cell(column: 0, row: 4, columnSpan: 11, rowSpan: 4),
                          role: .display, style: titleStyle, anchor: .bottom)
        if let subtitle {
            try slide.addText(subtitle, in: grid.cell(column: 0, row: 9, columnSpan: 10, rowSpan: 2),
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

    /// A vertical stack of full-width colored bands, one per item, each labeled —
    /// the "five layers" diagram. Ideal for 3–6 parallel concepts, phases, or
    /// layers instead of a plain bullet list.
    @discardableResult
    func bandsSlide(_ title: String, bands: [String], kicker: String? = nil, style: DeckStyle? = nil) throws -> Slide {
        let s = style ?? self.style
        let slide = try startContentSlide(s)
        let content = try header(on: slide, kicker: kicker, title: title, style: s)
        let items = Array(bands.prefix(6))
        guard !items.isEmpty else { return slide }
        let gap = s.spacing.sm.rawValue
        let bandH = (content.height.rawValue - gap * (items.count - 1)) / items.count
        let bandStyle = s.with(.heading) { $0.sizePt = items.count >= 5 ? 22 : 26 }
        for (i, text) in items.enumerated() {
            let y = content.minY.rawValue + i * (bandH + gap)
            let rect = Rect(x: content.minX, y: EMU(y), width: content.width, height: EMU(bandH))
            let fill = s.accent(i + 1)
            let card = try slide.addCard(in: rect, style: s, fill: .solid(fill), radiusToken: "sm", shadow: false)
            try slide.addText(text, in: card.content, role: .heading, style: bandStyle,
                              color: s.textColor(on: fill), align: .center, anchor: .middle)
        }
        return slide
    }

    /// A row of 2–4 headline metrics — each a colored rule, a big number, and a
    /// caption (the "180 / 0 / 11" layout).
    @discardableResult
    func metricsSlide(_ title: String, metrics: [(value: String, label: String)],
                      kicker: String? = nil, style: DeckStyle? = nil) throws -> Slide {
        let s = style ?? self.style
        let slide = try startContentSlide(s)
        let content = try header(on: slide, kicker: kicker, title: title, style: s)
        let items = Array(metrics.prefix(4))
        guard !items.isEmpty else { return slide }
        let cols = content.split(.horizontal, count: items.count, gutter: s.gutter)
        // Fit the number to the column so a wide value ("$300B") stays on one line.
        let maxLen = items.map { $0.value.count }.max() ?? 2
        let base: Double = items.count >= 4 ? 54 : (items.count == 3 ? 68 : 104)
        let numberStyle = s.with(.stat) { $0.sizePt = maxLen >= 6 ? base * 0.8 : base }
        for (i, m) in items.enumerated() {
            let col = cols[i]
            let accent = s.legibleAccent(i + 1, on: s.background)
            let ruleH = EMU(Int(Double(col.height.rawValue) * 0.66))
            try slide.addAccentRule(in: Rect(x: col.minX, y: col.minY, width: .points(5), height: ruleH),
                                    style: s, color: accent)
            let textRect = Rect(x: col.minX + .points(22), y: col.minY,
                                width: col.width - .points(22), height: col.height)
            try slide.addStatTile(m.value, caption: m.label, in: textRect, style: numberStyle,
                                  valueColor: accent, anchor: .top)
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
                                style: s, alignment: .center, anchor: .bottom)
        }
        // One stacked tile (number + caption) centered — so the caption always
        // sits below the number instead of colliding with the 130pt stat.
        try slide.addStatTile(stat, caption: caption,
                              in: grid.cell(column: 1, row: 4, columnSpan: 10, rowSpan: 5),
                              style: s, align: .center, anchor: .middle)
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
        // Give the title three rows so a two-line title never collides with the
        // content below it, and bottom-anchor it so a one-line title still hugs
        // the content instead of floating.
        try slide.addText(title, in: grid.cell(column: 0, row: titleRow, columnSpan: 11, rowSpan: 3),
                          role: .title, style: style, anchor: .bottom)
        let top = titleRow + 3
        return grid.cell(column: 0, row: top, columnSpan: 12, rowSpan: 12 - top)
    }
}
