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
        // Keep the section title/subtitle in the left half so a right-hand image
        // panel (added by the renderer) never overlaps the text; fit the title to
        // its length so a long one stays ≤2 lines and clears the subtitle below.
        let fitted = title.count > 40 ? 30.0 : (title.count > 24 ? 34.0 : s.type(.title).sizePt)
        let titleStyle = s.with(.title) { $0.sizePt = fitted }
        try slide.addText(title, in: grid.cell(column: 0, row: 4, columnSpan: 6, rowSpan: 3),
                          role: .title, style: titleStyle, color: onBg, anchor: .bottom)
        if let subtitle {
            // Start higher (row 8) and run wider (9 cols) so a long closing CTA
            // wraps to a few lines well clear of the bottom edge, not off it. A
            // section header's subtitle is short, so the extra width is harmless.
            try slide.addText(subtitle, in: grid.cell(column: 0, row: 8, columnSpan: 9, rowSpan: 4),
                              role: .subhead, style: s, color: onBg)
        }
        return slide
    }

    /// A closing slide: a near-full-width punchline title, an optional call to
    /// action, and an optional contact line pinned to its own bottom band. Unlike
    /// reusing `sectionSlide` (whose title is narrowed to leave room for a side
    /// image, and whose single subtitle box overflows when a CTA and a contact
    /// line share it), each element here owns a separate band, so a cramped title
    /// or a CTA/contact collision is structurally impossible.
    @discardableResult
    func closingSlide(_ title: String, callToAction: String? = nil,
                      contact: String? = nil, style: DeckStyle? = nil) throws -> Slide {
        let s = style ?? self.style
        let slide = try blankCanvas()
        let bg = s.accent(1)
        try slide.setBackground(.solid(bg))
        let onBg = s.textColor(on: bg)
        let grid = deckGrid(s)

        // Title uses (nearly) the full width so a real closing line — "Ship one
        // narrow agent this quarter" — never cramps to half-width and breaks badly.
        let fitted = title.count > 48 ? 34.0 : (title.count > 30 ? 40.0 : 46.0)
        let titleStyle = s.with(.title) { $0.sizePt = fitted }
        try slide.addText(title, in: grid.cell(column: 0, row: 3, columnSpan: 11, rowSpan: 3),
                          role: .title, style: titleStyle, color: onBg, anchor: .bottom)
        if let callToAction, !callToAction.isEmpty {
            try slide.addText(callToAction, in: grid.cell(column: 0, row: 7, columnSpan: 10, rowSpan: 3),
                              role: .subhead, style: s, color: onBg, anchor: .top)
        }
        if let contact, !contact.isEmpty {
            // A distinct bottom band (row 11), a clear row below the CTA — the
            // overlap the shared-with-section layout produced can't happen here.
            try slide.addText(contact, in: grid.cell(column: 0, row: 11, columnSpan: 12, rowSpan: 1),
                              role: .caption, style: s, color: onBg, anchor: .bottom)
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
        try slide.addBulletList(bullets, in: content, style: s, anchor: .top)   // start just below the title
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
        _ = try header(on: slide, kicker: nil, title: title, style: s)   // draws the title
        // Comparison cards run a row taller than the shared content rect (start at
        // row 2, not 3) so their bullets get real headroom — a bullet that wraps
        // (wider fonts in PowerPoint than in preview) then never runs off the card.
        let content = deckGrid(s).cell(column: 0, row: 2, columnSpan: 12, rowSpan: 10)
        let cols = content.split(.horizontal, count: 2, gutter: s.gutter)
        // Header gets its own top band (room for two lines) and the bullets fill
        // the rest, top-anchored — so a two-line header never overlaps them.
        let headStyle = s.with(.heading) { $0.sizePt = 24 }
        for (col, headerText, items) in [(cols[0], leftHeader, left), (cols[1], rightHeader, right)] {
            let card = try slide.addCard(in: col, style: s)
            let (head, body) = card.content.split(.vertical, ratio: 0.16, gutter: s.spacing.sm)
            try slide.addText(headerText, in: head, role: .heading, style: headStyle, anchor: .top)
            // Cards are narrower than a full slide; a smaller body and tighter gaps
            // keep four bullets inside the card (auto-fit shrinks any that don't).
            try slide.addBulletList(items, in: body, style: s, size: items.count >= 4 ? 20 : 24,
                                    gapPt: s.spacing.sm.points)
        }
        return slide
    }

    /// A horizontal numbered process: 2–5 steps, each a colored number badge and a
    /// caption, joined by arrows. For sequences, stages, and step-by-step plans.
    @discardableResult
    func processSlide(_ title: String, steps: [String], kicker: String? = nil, style: DeckStyle? = nil) throws -> Slide {
        let s = style ?? self.style
        let slide = try startContentSlide(s)
        let content = try header(on: slide, kicker: kicker, title: title, style: s)
        let items = Array(steps.prefix(5))
        guard !items.isEmpty else { return slide }
        let cols = content.split(.horizontal, count: items.count, gutter: s.gutter)
        let badge = EMU.inches(1.1)
        let numberStyle = s.with(.stat) { $0.sizePt = 44 }
        for (i, step) in items.enumerated() {
            let col = cols[i]
            let accent = s.legibleAccent(i + 1, on: s.background)
            let badgeRect = Rect(x: col.midX - badge / 2.0, y: col.minY, width: badge, height: badge)
            try slide.shapes.addShape(.ellipse, frame: badgeRect, fill: .solid(accent))
            try slide.addText("\(i + 1)", in: badgeRect, role: .stat, style: numberStyle,
                              color: s.textColor(on: accent), align: .center, anchor: .middle)
            let top = badgeRect.maxY + EMU.points(16)
            try slide.addText(step, in: Rect(x: col.minX, y: top, width: col.width, height: content.maxY - top),
                              role: .body, style: s, align: .center, anchor: .top)
            if i < items.count - 1 {                       // arrow into the gutter
                let a = badge / 3.5
                try slide.shapes.addShape(.rightArrow,
                                          frame: Rect(x: col.maxX, y: badgeRect.y + a, width: s.gutter, height: a),
                                          fill: .solid(s.mutedInk))
            }
        }
        return slide
    }

    /// A stacked pyramid: 2–5 graduated levels, widest at the base. For
    /// hierarchies, maturity ladders, and foundations that build to a peak.
    @discardableResult
    func pyramidSlide(_ title: String, levels: [String], kicker: String? = nil, style: DeckStyle? = nil) throws -> Slide {
        let s = style ?? self.style
        let slide = try startContentSlide(s)
        let content = try header(on: slide, kicker: kicker, title: title, style: s)
        let items = Array(levels.prefix(5))
        guard !items.isEmpty else { return slide }
        let n = items.count
        let gap = s.spacing.sm.rawValue
        let bandH = (content.height.rawValue - gap * (n - 1)) / n
        let levelStyle = s.with(.heading) { $0.sizePt = n >= 5 ? 20 : 24 }
        for (i, text) in items.enumerated() {
            let accent = s.legibleAccent(i + 1, on: s.background)
            let frac = 0.5 + 0.5 * (Double(i) / Double(max(1, n - 1)))   // narrow top → wide base
            let w = content.width * frac
            let rect = Rect(x: content.midX - w / 2.0,
                            y: EMU(content.minY.rawValue + i * (bandH + gap)),
                            width: w, height: EMU(bandH))
            try slide.shapes.addShape(.trapezoid, frame: rect, fill: .solid(accent))
            try slide.addText(text, in: rect, role: .heading, style: levelStyle,
                              color: s.textColor(on: accent), align: .center, anchor: .middle)
        }
        return slide
    }

    /// A title over a native SmartArt diagram — a real, editable PowerPoint
    /// SmartArt object (not drawn shapes), which python-pptx cannot produce.
    /// `kind` selects the layout family (e.g. `.process` for a chevron sequence);
    /// nodes are brand-colored by cycling the deck accents.
    @discardableResult
    func smartArtSlide(_ title: String, kind: SmartArt.Layout, items: [String],
                       kicker: String? = nil, style: DeckStyle? = nil) throws -> Slide {
        let s = style ?? self.style
        let slide = try startContentSlide(s)
        let content = try header(on: slide, kicker: kicker, title: title, style: s)
        let nodes = Array(items.prefix(6))
        guard !nodes.isEmpty else { return slide }
        let colors = (0..<nodes.count).map { s.accent($0 + 1) }
        try slide.shapes.addSmartArt(items: nodes, frame: content, colors: colors, layout: kind)
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
            // Label goes in the band rect itself (always positive height). Using
            // the card's padded content would go negative on a thin band — a
            // negative extent PowerPoint rejects with a repair.
            _ = try slide.addCard(in: rect, style: s, fill: .solid(fill), radiusToken: "sm", shadow: false)
            try slide.addText(text, in: rect, role: .heading, style: bandStyle,
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
        // Title at the top of a two-row band; the body starts a row below it, so
        // there's a consistent breathing gap between title and content (never
        // jammed against it, never floating far below).
        try slide.addText(title, in: grid.cell(column: 0, row: titleRow, columnSpan: 11, rowSpan: 2),
                          role: .title, style: style, anchor: .top)
        let top = titleRow + 3
        return grid.cell(column: 0, row: top, columnSpan: 12, rowSpan: 12 - top)
    }
}
