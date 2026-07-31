import Foundation

// One-call, design-aware slide builders. Each adds a FREE-SHAPE slide (never a
// template placeholder), laid out on a 12×12 Grid from the deck's DeckStyle, and
// returns the created Slide for further tweaking. Works on a blank Presentation()
// and inherits brand from a .potx + applyDesign alike — because everything reads
// from `deck.style`.

/// How many items each capped builder can lay out legibly. Items beyond the
/// cap are dropped — these constants exist so that is a decision you make
/// rather than a surprise: check `SlideCapacity.process` before calling, or
/// split the content across slides.
/// Which side of a slide a picture takes, leaving the rest for text.
///
/// The classic pairing: title and a few bullets on one side, a picture on the
/// other. Alternating the side down a deck is what stops a run of them reading
/// as the same slide repeated.
public enum SideImage: Sendable, Equatable {
    case left, right
}

public enum SlideCapacity {
    /// `processSlide(_:steps:)` — steps share one row of columns.
    public static let process = 5
    /// `smartArtSlide(_:kind:items:)` — nodes in one diagram.
    public static let smartArt = 6
    /// `bandsSlide(_:bands:)` — stacked full-width bands.
    public static let bands = 6
    /// `pyramidSlide(_:levels:)` — graduated stacked levels.
    public static let pyramid = 5
    /// `metricsSlide(_:metrics:)` — side-by-side headline numbers.
    public static let metrics = 4
    /// `timelineSlide(_:milestones:)` — markers sharing one rule.
    public static let timeline = 5
    /// `quadrantSlide(_:quadrants:)` — a 2x2 is exactly four.
    public static let quadrant = 4
}

public extension Presentation {
    /// A cover: kicker, oversized display title, subtitle, and an accent rule.
    @discardableResult
    func titleSlide(_ title: String, subtitle: String? = nil,
                    kicker: String? = nil, style: DeckStyle? = nil) throws -> Slide {
        let s = style ?? self.style
        let slide = try blankCanvas()
        try slide.setBackground(.solid(s.background))
        let grid = deckGrid(s)
        // Fit the display size to the title so a long headline stays on the
        // slide — measured with real metrics when the deck's fonts are
        // registered, estimated by length otherwise.
        let titleBand = grid.cell(column: 0, row: 4, columnSpan: 11, rowSpan: 4)
        // Candidates are capped at the configured role size: a custom style
        // with a small display face must never be UPsized to a ladder value.
        let fitted = fitSize([title], font: s.type(.display).font,
                             candidates: [s.type(.display).sizePt, 74, 60].filter { $0 <= s.type(.display).sizePt },
                             maxLines: 2, lineWidth: titleBand.width,
                             fallback: title.count > 44 ? 60.0 : (title.count > 28 ? 74.0 : s.type(.display).sizePt))
        let titleStyle = s.with(.display) { $0.sizePt = fitted }
        try slide.addAccentRule(
            in: Rect(x: grid.content.minX, y: grid.cell(column: 0, row: 3).minY,
                     width: .inches(1.4), height: .points(4)), style: s)
        if let kicker {
            try slide.addKicker(kicker, in: grid.cell(column: 0, row: 3, columnSpan: 12), style: s)
        }
        try slide.addText(title, in: titleBand,
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
        // panel (added by the renderer) never overlaps the text; fit the title so
        // a long one stays ≤2 lines and clears the subtitle below.
        let titleBand = grid.cell(column: 0, row: 4, columnSpan: 6, rowSpan: 3)
        let fitted = fitSize([title], font: s.type(.title).font,
                             candidates: [s.type(.title).sizePt, 34, 30].filter { $0 <= s.type(.title).sizePt },
                             maxLines: 2, lineWidth: titleBand.width,
                             fallback: title.count > 40 ? 30.0 : (title.count > 24 ? 34.0 : s.type(.title).sizePt))
        let titleStyle = s.with(.title) { $0.sizePt = fitted }
        try slide.addText(title, in: titleBand,
                          role: .title, style: titleStyle, color: onBg, anchor: .bottom)
        if let subtitle {
            // Start higher (row 8) and run wider (9 cols) so a long closing CTA
            // wraps to a few lines well clear of the bottom edge, not off it. A
            // section header's subtitle is short, so the extra width is harmless.
            // Six columns, not nine: the renderer places a side image from
            // `sideImageColumn` on, and a nine-column subtitle ran straight
            // under it.
            try slide.addText(subtitle,
                              in: grid.cell(column: 0, row: 8,
                                            columnSpan: Self.sideImageColumn - 1, rowSpan: 4),
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
        let titleBand = grid.cell(column: 0, row: 3, columnSpan: 11, rowSpan: 3)
        let fitted = fitSize([title], font: s.type(.title).font,
                             candidates: [46, 40, 34],
                             maxLines: 2, lineWidth: titleBand.width,
                             fallback: title.count > 48 ? 34.0 : (title.count > 30 ? 40.0 : 46.0))
        let titleStyle = s.with(.title) { $0.sizePt = fitted }
        try slide.addText(title, in: titleBand,
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
    /// - Parameter reservingSideImage: narrow the title and bullets to the
    ///   left seven columns, leaving `sideImagePanel()` free for a picture.
    ///   Text-only slides keep the full width, so nothing moves unless asked.
    func bulletSlide(_ title: String, _ bullets: [String],
                     kicker: String? = nil, reservingSideImage: Bool = false,
                     imageSide: SideImage = .right,
                     style: DeckStyle? = nil) throws -> Slide {
        let s = style ?? self.style
        let slide = try startContentSlide(s)
        let content = try header(on: slide, kicker: kicker, title: title, style: s,
                                 reservingSideImage: reservingSideImage, imageSide: imageSide)
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
        let headerInfo = try placeHeader(on: slide, kicker: nil, title: title, style: s)
        // Comparison cards run a row taller than the shared content rect (one row
        // above the standard content top) so their bullets get real headroom — a
        // bullet that wraps (wider fonts in PowerPoint than in preview) then
        // never runs off the card. A wrapped title shifts the cards down with it.
        let cardRow = headerInfo.contentRow - 1
        let content = deckGrid(s).cell(column: 0, row: cardRow, columnSpan: 12, rowSpan: 12 - cardRow)
        let cols = content.split(.horizontal, count: 2, gutter: s.gutter)
        // Header gets its own top band (room for two lines) and the bullets fill
        // the rest, top-anchored — so a two-line header never overlaps them.
        let headStyle = s.with(.heading) { $0.sizePt = 24 }
        for (col, headerText, items) in [(cols[0], leftHeader, left), (cols[1], rightHeader, right)] {
            let card = try slide.addCard(in: col, style: s)
            let (head, body) = card.content.split(.vertical, ratio: 0.16, gutter: s.spacing.sm)
            try slide.addText(headerText, in: head, role: .heading, style: headStyle, anchor: .top)
            // Cards are narrower than a full slide; a smaller body, tighter gaps,
            // AND tighter leading keep the bullets inside the card. At the body's
            // airy 150% line height, three two-line bullets need ~275pt in a
            // 245pt card — the last bullet rides off the card edge.
            let cardBody = s.with(.body) { $0.lineHeight = Swift.min($0.lineHeight, 1.25) }
            // A wrapped title costs the cards a row, so their bullets step down a
            // size to keep the same worst case inside the shorter card.
            try slide.addBulletList(items, in: body, style: cardBody,
                                    size: items.count >= 4 || headerInfo.titleWraps ? 20 : 24,
                                    gapPt: s.spacing.sm.points)
        }
        return slide
    }

    /// A horizontal numbered process: 2–5 steps, each a colored number badge and a
    /// caption, joined by arrows. For sequences, stages, and step-by-step plans.
    ///
    /// Lays out at most `SlideCapacity.process` steps; extras are dropped.
    @discardableResult
    func processSlide(_ title: String, steps: [String], kicker: String? = nil, style: DeckStyle? = nil) throws -> Slide {
        let s = style ?? self.style
        let slide = try startContentSlide(s)
        let content = try header(on: slide, kicker: kicker, title: title, style: s)
        let items = Array(steps.prefix(SlideCapacity.process))
        guard !items.isEmpty else { return slide }
        let cols = content.split(.horizontal, count: items.count, gutter: s.gutter)
        let badge = EMU.inches(1.1)
        let numberStyle = s.with(.stat) { $0.sizePt = 44 }
        // Step captions live in narrow columns (~200pt at 4 steps), where the
        // body's airy line height and full size wrap a long step to five lines
        // and off the bottom of the slide. Fit the size so every caption stays
        // inside its column, and tighten the leading.
        let longest = items.map(\.count).max() ?? 0
        let capSize = fitSize(items, font: s.type(.body).font,
                              candidates: [s.type(.body).sizePt, 22, 20],
                              maxLines: 4, lineWidth: cols[0].width,
                              fallback: longest > 44 ? 20 : (longest > 30 ? 22 : s.type(.body).sizePt))
        let captionStyle = s.with(.body) {
            $0.sizePt = Swift.min($0.sizePt, capSize)
            $0.lineHeight = Swift.min($0.lineHeight, 1.2)
        }
        for (i, step) in items.enumerated() {
            let col = cols[i]
            let accent = s.legibleAccent(i + 1, on: s.background)
            let badgeRect = Rect(x: col.midX - badge / 2.0, y: col.minY, width: badge, height: badge)
            try slide.shapes.addShape(.ellipse, frame: badgeRect, fill: .solid(accent))
            try slide.addText("\(i + 1)", in: badgeRect, role: .stat, style: numberStyle,
                              color: s.textColor(on: accent), align: .center, anchor: .middle)
            let top = badgeRect.maxY + EMU.points(16)
            try slide.addText(step, in: Rect(x: col.minX, y: top, width: col.width, height: content.maxY - top),
                              role: .body, style: captionStyle, align: .center, anchor: .top)
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
    ///
    /// Lays out at most `SlideCapacity.pyramid` levels; extras are dropped.
    @discardableResult
    func pyramidSlide(_ title: String, levels: [String], kicker: String? = nil, style: DeckStyle? = nil) throws -> Slide {
        let s = style ?? self.style
        let slide = try startContentSlide(s)
        let content = try header(on: slide, kicker: kicker, title: title, style: s)
        let items = Array(levels.prefix(SlideCapacity.pyramid))
        guard !items.isEmpty else { return slide }
        let n = items.count
        let gap = s.spacing.sm.rawValue
        let bandH = (content.height.rawValue - gap * (n - 1)) / n
        // Pyramid labels carry a "Label — detail" line, so keep the type modest and
        // let autofit shrink it; combined with a gentle taper, the text fits.
        let levelStyle = s.with(.heading) { $0.sizePt = n >= 4 ? 17 : 21 }
        for (i, text) in items.enumerated() {
            let accent = s.legibleAccent(i + 1, on: s.background)
            // Gentle taper — the top slice is 0.7 of the width (not 0.5), so even the
            // narrow apex is wide enough for its label instead of clipping it.
            let frac = 0.7 + 0.3 * (Double(i) / Double(max(1, n - 1)))
            let w = content.width * frac
            let rect = Rect(x: content.midX - w / 2.0,
                            y: EMU(content.minY.rawValue + i * (bandH + gap)),
                            width: w, height: EMU(bandH))
            try slide.shapes.addShape(.trapezoid, frame: rect, fill: .solid(accent))
            // Text box inset from the slice's tapered edges so a label never runs
            // into (or past) the sloping sides.
            let tw = w * 0.86
            let textRect = Rect(x: content.midX - tw / 2.0, y: rect.y, width: tw, height: EMU(bandH))
            try slide.addText(text, in: textRect, role: .heading, style: levelStyle,
                              color: s.textColor(on: accent), align: .center, anchor: .middle)
        }
        return slide
    }

    /// A title over a native SmartArt diagram — a real, editable PowerPoint
    /// SmartArt object (not drawn shapes), a capability outside python-pptx's
    /// current scope.
    /// `kind` selects the layout family (e.g. `.process` for a chevron sequence);
    /// nodes are brand-colored by cycling the deck accents.
    ///
    /// Lays out at most `SlideCapacity.smartArt` nodes; extras are dropped.
    @discardableResult
    func smartArtSlide(_ title: String, kind: SmartArt.Layout, items: [String],
                       kicker: String? = nil, style: DeckStyle? = nil) throws -> Slide {
        let s = style ?? self.style
        let slide = try startContentSlide(s)
        let content = try header(on: slide, kicker: kicker, title: title, style: s)
        let nodes = Array(items.prefix(SlideCapacity.smartArt))
        guard !nodes.isEmpty else { return slide }
        let colors = (0..<nodes.count).map { s.accent($0 + 1) }
        try slide.shapes.addSmartArt(items: nodes, frame: content, colors: colors, layout: kind)
        return slide
    }

    /// A vertical stack of full-width colored bands, one per item, each labeled —
    /// the "five layers" diagram. Ideal for 3–6 parallel concepts, phases, or
    /// layers instead of a plain bullet list.
    ///
    /// Lays out at most `SlideCapacity.bands` bands; extras are dropped.
    @discardableResult
    func bandsSlide(_ title: String, bands: [String], kicker: String? = nil, style: DeckStyle? = nil) throws -> Slide {
        let s = style ?? self.style
        let slide = try startContentSlide(s)
        let content = try header(on: slide, kicker: kicker, title: title, style: s)
        let items = Array(bands.prefix(SlideCapacity.bands))
        guard !items.isEmpty else { return slide }
        let gap = s.spacing.sm.rawValue
        let bandH = (content.height.rawValue - gap * (items.count - 1)) / items.count
        let bandStyle = s.with(.heading) { $0.sizePt = items.count >= 5 ? 22 : 26 }
        for (i, text) in items.enumerated() {
            let y = content.minY.rawValue + i * (bandH + gap)
            let rect = Rect(x: content.minX, y: EMU(y), width: content.width, height: EMU(bandH))
            // Raw accents on purpose, not `plotColors`. A contrast floor is
            // right for a chart series, which has to be told apart from
            // whitespace and from the other series; a band is a full-width
            // block in a contiguous stack, so its neighbours define its edges
            // and a pale tint reads as tonal variation rather than a mistake.
            // Verified by rendering: forcing 3:1 here flattens designs whose
            // bands are deliberately graduated.
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
    ///
    /// Lays out at most `SlideCapacity.metrics` metrics; extras are dropped.
    @discardableResult
    func metricsSlide(_ title: String, metrics: [(value: String, label: String)],
                      kicker: String? = nil, style: DeckStyle? = nil) throws -> Slide {
        let s = style ?? self.style
        let slide = try startContentSlide(s)
        let content = try header(on: slide, kicker: kicker, title: title, style: s)
        let items = Array(metrics.prefix(SlideCapacity.metrics))
        guard !items.isEmpty else { return slide }
        let cols = content.split(.horizontal, count: items.count, gutter: s.gutter)
        // Fit the number to the column so a wide value ("$300B") stays on one line.
        let maxLen = items.map { $0.value.count }.max() ?? 2
        let base: Double = items.count >= 4 ? 54 : (items.count == 3 ? 68 : 104)
        let shrink: Bool
        if let metrics = fonts.metrics(for: s.type(.stat).font) {
            let columnPt = Double((cols[0].width - .points(22)).rawValue) / Double(EMU.perPoint)
            shrink = items.contains { metrics.width(of: $0.value, pointSize: base) > columnPt }
        } else {
            shrink = maxLen >= 6
        }
        // Fit the caption to the column as well as the number. Only the value
        // was ever fitted, so a label like "research domain categories" in a
        // 2.4in column ran past its tile and PowerPoint broke it mid-word
        // ("categorie" / "s").
        let labels = items.map(\.label)
        let captionWidth = cols[0].width - .points(22)
        let longestLabel = labels.map(\.count).max() ?? 0
        let captionSize = fitSize(labels, font: s.type(.caption).font,
                                  candidates: [s.type(.caption).sizePt, 16, 14, 12],
                                  maxLines: 3, lineWidth: captionWidth,
                                  fallback: longestLabel > 26 ? 12
                                      : (longestLabel > 18 ? 14 : s.type(.caption).sizePt))
        let tileStyle = s.with(.stat) { $0.sizePt = shrink ? base * 0.8 : base }
            .with(.caption) {
                $0.sizePt = Swift.min($0.sizePt, captionSize)
                $0.lineHeight = Swift.min($0.lineHeight, 1.25)
            }
        for (i, m) in items.enumerated() {
            let col = cols[i]
            let accent = s.legibleAccent(i + 1, on: s.background)
            let ruleH = EMU(Int(Double(col.height.rawValue) * 0.66))
            try slide.addAccentRule(in: Rect(x: col.minX, y: col.minY, width: .points(5), height: ruleH),
                                    style: s, color: accent)
            let textRect = Rect(x: col.minX + .points(22), y: col.minY,
                                width: col.width - .points(22), height: col.height)
            try slide.addStatTile(m.value, caption: m.label, in: textRect, style: tileStyle,
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
        // Charts otherwise draw their own text in the theme font at a flat
        // 14pt, which is what makes a generated chart look bolted on next to
        // the slide it sits in.
        var options = options
        if options.text == nil {
            let caption = s.type(.caption)
            // Muted ink reads as "quiet" on a light deck and as "invisible" on
            // a dark one, so the caption color is nudged until it clears AA
            // against the background the chart actually sits on.
            options.text = ChartTextStyle(
                font: caption.font,
                color: DeckStyle.legibleEmphasis(s.mutedInk, on: s.background, ink: s.ink),
                sizePt: Swift.min(caption.sizePt, 12))
        }
        try slide.shapes.addChart(kind, data: data, frame: content,
                                  colors: colors ?? s.plotColors, options: options)
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
        // sits below the number instead of colliding with the 130pt stat. The
        // tile gets six rows, and a caption long enough to wrap steps the stat
        // down: a 130pt number line plus a two-line caption needs ~208pt, more
        // than the five-row band the tile used to get.
        let statStyle = caption.count > 55 ? s.with(.stat) { $0.sizePt = Swift.min($0.sizePt, 112) } : s
        try slide.addStatTile(stat, caption: caption,
                              in: grid.cell(column: 1, row: 4, columnSpan: 10, rowSpan: 6),
                              style: statStyle, align: .center, anchor: .middle)
        return slide
    }

    /// A centered pull-quote with an attribution.
    @discardableResult
    func quoteSlide(_ quote: String, attribution: String? = nil, style: DeckStyle? = nil) throws -> Slide {
        let s = style ?? self.style
        let slide = try blankCanvas()
        try slide.setBackground(.solid(s.background))
        let grid = deckGrid(s)
        // Fit the quote: at the full 40pt a four-line quote runs ~240pt in a
        // ~163pt band and its overflow lands on the attribution row.
        let quoteBand = grid.cell(column: 1, row: 3, columnSpan: 10, rowSpan: 5)
        let fitted = fitSize(["\u{201C}\(quote)\u{201D}"], font: s.type(.quote).font,
                             candidates: [s.type(.quote).sizePt, 34, 28],
                             maxLines: 4, lineWidth: quoteBand.width,
                             fallback: quote.count > 220 ? 28.0 : (quote.count > 120 ? 34.0 : s.type(.quote).sizePt))
        let quoteStyle = s.with(.quote) { $0.sizePt = Swift.min($0.sizePt, fitted) }
        try slide.addText("\u{201C}\(quote)\u{201D}",
                          in: quoteBand,
                          role: .quote, style: quoteStyle, align: .center, anchor: .middle)
        if let attribution {
            try slide.addText("— \(attribution)",
                              in: grid.cell(column: 1, row: 9, columnSpan: 10, rowSpan: 1),
                              role: .caption, style: s, align: .center)
        }
        return slide
    }

    /// A horizontal timeline: milestones pegged to one rule, each with a short
    /// label above and its detail below.
    ///
    /// Lays out at most `SlideCapacity.timeline` milestones; extras are
    /// dropped, because a sixth marker leaves no room for the text under it.
    @discardableResult
    func timelineSlide(_ title: String, milestones: [(label: String, detail: String)],
                       kicker: String? = nil, style: DeckStyle? = nil) throws -> Slide {
        let s = style ?? self.style
        let slide = try startContentSlide(s)
        let content = try header(on: slide, kicker: kicker, title: title, style: s)
        let items = Array(milestones.prefix(SlideCapacity.timeline))
        guard !items.isEmpty else { return slide }

        let columns = content.split(.horizontal, count: items.count, gutter: s.gutter)
        // The rule sits below the labels so the eye reads label → marker →
        // detail top to bottom, the order the milestones are spoken in.
        let ruleY = content.y + content.height * 0.5
        let ruleHeight = EMU.points(2)
        let marker = EMU.points(14)
        try slide.shapes.addShape(
            .rectangle,
            frame: Rect(x: columns[0].midX, y: ruleY,
                        width: columns[columns.count - 1].midX - columns[0].midX, height: ruleHeight),
            fill: .solid(s.mutedInk))

        let labelStyle = s.with(.heading) { $0.sizePt = Swift.min($0.sizePt, 22) }
        let detailStyle = s.with(.body) {
            $0.sizePt = Swift.min($0.sizePt, 18)
            $0.lineHeight = Swift.min($0.lineHeight, 1.2)
        }
        for (i, milestone) in items.enumerated() {
            let column = columns[i]
            let accent = s.legibleAccent(i + 1, on: s.background)
            let labelBottom = ruleY - EMU.points(18)
            try slide.addText(milestone.label,
                              in: Rect(x: column.x, y: content.y, width: column.width,
                                       height: Swift.max(.zero, labelBottom - content.y)),
                              role: .heading, style: labelStyle, color: accent,
                              align: .center, anchor: .bottom)
            try slide.shapes.addShape(
                .ellipse,
                frame: Rect(x: column.midX - marker / 2.0, y: ruleY + ruleHeight / 2.0 - marker / 2.0,
                            width: marker, height: marker),
                fill: .solid(accent))
            let detailTop = ruleY + marker
            try slide.addText(milestone.detail,
                              in: Rect(x: column.x, y: detailTop, width: column.width,
                                       height: Swift.max(.zero, content.maxY - detailTop)),
                              role: .body, style: detailStyle, align: .center, anchor: .top)
        }
        return slide
    }

    /// A 2x2 of labelled cards, read left to right and top to bottom, with
    /// optional axis captions down the left edge and along the bottom.
    ///
    /// Takes exactly `SlideCapacity.quadrant` entries — a 2x2 with a hole in it
    /// is a different diagram — and returns an empty slide otherwise.
    @discardableResult
    func quadrantSlide(_ title: String, quadrants: [(heading: String, detail: String)],
                       xAxis: String? = nil, yAxis: String? = nil,
                       kicker: String? = nil, style: DeckStyle? = nil) throws -> Slide {
        let s = style ?? self.style
        let slide = try startContentSlide(s)
        let content = try header(on: slide, kicker: kicker, title: title, style: s)
        guard quadrants.count == SlideCapacity.quadrant else { return slide }

        // Axis captions get a gutter of their own so they never overlap a card.
        let axisGap = EMU.points(22)
        let grid = content.inset(top: yAxis == nil ? .zero : axisGap,
                                 bottom: xAxis == nil ? .zero : axisGap)
        let rows = grid.split(.vertical, count: 2, gutter: s.spacing.sm)
        let cells = rows.flatMap { $0.split(.horizontal, count: 2, gutter: s.spacing.sm) }

        let headingStyle = s.with(.heading) { $0.sizePt = Swift.min($0.sizePt, 22) }
        let detailStyle = s.with(.body) {
            $0.sizePt = Swift.min($0.sizePt, 17)
            $0.lineHeight = Swift.min($0.lineHeight, 1.2)
        }
        for (i, quadrant) in quadrants.enumerated() {
            let cell = cells[i]
            let card = try slide.addCard(in: cell, style: s)
            let (head, body) = card.content.split(.vertical, ratio: 0.34, gutter: s.spacing.xs)
            try slide.addText(quadrant.heading, in: head, role: .heading, style: headingStyle,
                              color: s.textColor(on: s.surface), anchor: .top)
            try slide.addText(quadrant.detail, in: body, role: .body, style: detailStyle, anchor: .top)
        }

        let axisStyle = s.with(.caption) { $0.sizePt = Swift.min($0.sizePt, 14) }
        if let xAxis {
            try slide.addText(xAxis,
                              in: Rect(x: grid.x, y: grid.maxY, width: grid.width, height: axisGap),
                              role: .caption, style: axisStyle, color: s.mutedInk,
                              align: .center, anchor: .middle)
        }
        if let yAxis {
            // Rotated text would need a transform the text path does not carry,
            // so the vertical caption takes a band above the grid rather than
            // the left margin — where, at this size, it printed over the cards.
            try slide.addText(yAxis,
                              in: Rect(x: grid.x, y: content.y, width: grid.width, height: axisGap),
                              role: .caption, style: axisStyle, color: s.mutedInk,
                              align: .left, anchor: .middle)
        }
        return slide
    }

    /// A titled table: header row on the brand primary, banded body rows, and
    /// column widths proportional to the widest cell in each column so a column
    /// of dates never takes the same space as a column of sentences.
    ///
    /// `rows` is the full grid including the header row. Ragged rows are padded
    /// so the table is always rectangular — a short row from a model is a
    /// missing cell, not a broken deck.
    @discardableResult
    func tableSlide(_ title: String, rows: [[String]], style: DeckStyle? = nil) throws -> Slide {
        let s = style ?? self.style
        let slide = try startContentSlide(s)
        let content = try header(on: slide, kicker: nil, title: title, style: s)
        let columns = rows.map(\.count).max() ?? 0
        guard !rows.isEmpty, columns > 0 else { return slide }
        let grid = rows.map { row in row + Array(repeating: "", count: columns - row.count) }

        // Rows get equal height, but a table taller than its rect would run off
        // the slide, so cap the height at the content rect.
        let table = try slide.shapes.addTable(rows: grid.count, columns: columns, frame: content)
        table.setContents(grid)
            .columnWidths(Self.proportionalWidths(of: grid, in: content.width))
            .styleBanded(style: s, role: .body, anchor: .middle)
            .cellPadding(s.spacing.sm)
        // Figures read as a column only when their digits line up, so a column
        // whose body cells are all numeric flips to the right — header
        // included, or the header floats away from what it labels.
        for column in 0..<columns where Self.isNumericColumn(grid, column) {
            for row in 0..<grid.count {
                guard let cell = try? table.cell(row, column) else { continue }
                var text = s.type(row == 0 ? .heading : .body)
                text.color = cell.textFrame.paragraphs.first?.runs.first?.color ?? text.color
                cell.applyTextStyle(text, align: .right)
            }
        }
        return slide
    }

    /// Whether every body cell in `column` reads as a figure — digits with the
    /// punctuation money and percentages carry. An empty cell is ignored (a
    /// gap in a numeric column is still a numeric column); a column of empties
    /// is not numeric.
    private static func isNumericColumn(_ grid: [[String]], _ column: Int) -> Bool {
        var sawValue = false
        for row in grid.dropFirst() {
            guard column < row.count else { continue }
            let cell = row[column].trimmingCharacters(in: .whitespaces)
            if cell.isEmpty { continue }
            sawValue = true
            let digits = cell.filter(\.isNumber).count
            guard digits > 0,
                  cell.allSatisfy({ $0.isNumber || "+-.,%$€£¥ ()".contains($0) })
            else { return false }
        }
        return sawValue
    }

    /// Split `total` across columns in proportion to each column's longest cell,
    /// clamped so no column collapses below a readable minimum.
    private static func proportionalWidths(of grid: [[String]], in total: EMU) -> [EMU] {
        let columns = grid.first?.count ?? 0
        guard columns > 0, total.rawValue > 0 else { return [] }
        let longest = (0..<columns).map { column in
            Swift.max(1, grid.map { $0[column].count }.max() ?? 1)
        }
        // A column never drops below half its equal share: proportional widths
        // keep tables readable, but a lone one-character column shouldn't
        // shrink to nothing.
        let equalShare = total.rawValue / columns
        let floorWidth = equalShare / 2
        let flexible = total.rawValue - floorWidth * columns
        let weightTotal = longest.reduce(0, +)
        var widths = longest.map { EMU(floorWidth + flexible * $0 / weightTotal) }
        // Rounding leaves a few EMU over; give them to the widest column so the
        // table spans the content rect exactly.
        let used = widths.reduce(0) { $0 + $1.rawValue }
        if let widest = longest.firstIndex(of: longest.max() ?? 0), used < total.rawValue {
            widths[widest] = EMU(widths[widest].rawValue + (total.rawValue - used))
        }
        return widths
    }

    // MARK: - Private layout helpers

    /// A blank, placeholder-free slide bound to a single layout — the canvas all
    /// free-shape builders paint on.
    private func blankCanvas() throws -> Slide { try slides.add() }

    private func deckGrid(_ style: DeckStyle) -> Grid {
        Grid(in: bounds, columns: 12, rows: 12, gutter: style.gutter, margin: style.margin)
    }

    /// Where a side image goes on a slide that reserved room for one — the
    /// right-hand five columns, clear of the title band.
    ///
    /// Derived from the same grid the builders lay text on, and published so
    /// the code that *places* the picture uses the identical rect to the code
    /// that *made room* for it. A caller computing its own panel from slide
    /// fractions is how text and image come to overlap: Lectern's did, at
    /// 55.5% of the slide width, while `sectionSlide`'s subtitle ran nine
    /// columns wide and straight underneath it.
    func sideImagePanel(_ side: SideImage = .right, style: DeckStyle? = nil) -> Rect {
        let s = style ?? self.style
        let span = 12 - Self.sideImageColumn
        return deckGrid(s).cell(column: side == .right ? Self.sideImageColumn : 0,
                                row: 2, columnSpan: span, rowSpan: 9)
    }

    /// First column belonging to the side image. Text on a reserving slide
    /// stops here; `sideImagePanel` starts here.
    static let sideImageColumn = 7

    /// A content slide with the background painted; returns the slide.
    private func startContentSlide(_ style: DeckStyle) throws -> Slide {
        let slide = try blankCanvas()
        try slide.setBackground(.solid(style.background))
        return slide
    }

    /// Place an optional kicker + a title across the top rows; return the content
    /// rect below them.
    private func header(on slide: Slide, kicker: String?, title: String, style: DeckStyle,
                        reservingSideImage: Bool = false,
                        imageSide: SideImage = .right) throws -> Rect {
        let head = try placeHeader(on: slide, kicker: kicker, title: title, style: style,
                                   reservingSideImage: reservingSideImage, imageSide: imageSide)
        let grid = deckGrid(style)
        // Stop at the image column when one is reserved, so the picture the
        // caller places into `sideImagePanel()` cannot land on the text.
        let span = reservingSideImage ? Self.sideImageColumn : 12
        let column = reservingSideImage && imageSide == .left ? 12 - Self.sideImageColumn : 0
        return grid.cell(column: column, row: head.contentRow, columnSpan: span,
                         rowSpan: 12 - head.contentRow)
    }

    /// Draw the kicker + title and report where content may start.
    ///
    /// The title band is two rows but `addText` sizes the box to its text, so a
    /// one-line title fills about half of it. Content therefore starts one row
    /// below the band, not two: reserving the full two rows *plus* a gap left
    /// 1.18in of dead air under every single-line title — 16% of the slide —
    /// while the body ran correspondingly close to the bottom edge.
    ///
    /// A long title is fitted down AND, when it still wraps, `contentRow` moves
    /// one row lower: the band is sized for a single line, so a wrapped title
    /// otherwise prints straight over the cards/bullets below (PowerPoint
    /// renders bare `normAutofit` text at full size until the box is edited).
    private func placeHeader(on slide: Slide, kicker: String?, title: String,
                             style: DeckStyle,
                             reservingSideImage: Bool = false,
                             imageSide: SideImage = .right) throws -> (contentRow: Int, titleWraps: Bool) {
        let grid = deckGrid(style)
        // The title clears the image too — a headline running under the panel
        // is the same defect as a bullet doing it.
        let textColumns = reservingSideImage ? Self.sideImageColumn : 11
        let textColumn = reservingSideImage && imageSide == .left ? 12 - Self.sideImageColumn : 0
        var titleRow = 0
        if let kicker {
            try slide.addKicker(kicker,
                                in: grid.cell(column: textColumn, row: 0, columnSpan: textColumns),
                                style: style)
            titleRow = 1
        }
        let band = grid.cell(column: textColumn, row: titleRow, columnSpan: textColumns, rowSpan: 2)
        // maxLines 1: the band is sized for a single line, so with metrics we
        // prefer the largest size that avoids wrapping at all.
        let fitted = fitSize([title], font: style.type(.title).font,
                             candidates: [style.type(.title).sizePt, 34, 30],
                             maxLines: 1, lineWidth: band.width,
                             fallback: title.count > 60 ? 30.0 : (title.count > 36 ? 34.0 : style.type(.title).sizePt))
        let titleStyle = style.with(.title) { $0.sizePt = Swift.min($0.sizePt, fitted) }
        try slide.addText(title, in: band, role: .title, style: titleStyle, anchor: .top)
        let wraps = estimatedLines(title, style: titleStyle.type(.title), width: band.width) >= 2
        // One row of gap after the space the title actually occupies: a
        // single-line title fills roughly one row, a wrapped one both.
        return (titleRow + (wraps ? 3 : 2), wraps)
    }

    /// Deterministic wrap estimate. With the style's font registered in
    /// `fonts`, the count is measured (real advance widths); otherwise it's
    /// estimated at an average glyph width of 0.52 × point size (a touch wider
    /// than most text faces, so the estimate errs toward reserving space
    /// rather than colliding).
    private func estimatedLines(_ text: String, style: TextStyle, width: EMU) -> Int {
        let widthPt = Double(width.rawValue) / Double(EMU.perPoint)
        if let metrics = fonts.metrics(for: style.font) {
            return TextMeasurer(metrics).wrap(text, pointSize: style.sizePt, width: widthPt).count
        }
        let charsPerLine = Swift.max(1.0, widthPt / (0.52 * style.sizePt))
        return Int((Double(text.count) / charsPerLine).rounded(.up))
    }

    /// The largest of `candidates` at which every string in `texts` wraps to
    /// at most `maxLines` lines in `lineWidth` — measured with real metrics
    /// when `font` is registered in the deck's `fonts`. Unregistered fonts use
    /// `fallback` (each call site's calibrated character-count ladder), so a
    /// deck built without registered fonts is byte-identical to before the
    /// metrics engine existed.
    func fitSize(_ texts: [String], font: String, candidates: [Double],
                         maxLines: Int, lineWidth: EMU,
                         fallback: @autoclosure () -> Double) -> Double {
        guard let metrics = fonts.metrics(for: font) else { return fallback() }
        let widthPt = Double(lineWidth.rawValue) / Double(EMU.perPoint)
        let measurer = TextMeasurer(metrics)
        for size in candidates.sorted(by: >) {
            let fits = texts.allSatisfy {
                measurer.wrap($0, pointSize: size, width: widthPt).count <= maxLines
            }
            if fits { return size }
        }
        return candidates.min() ?? fallback()
    }
}
