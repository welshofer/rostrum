import Foundation

// Brand components — shapes + text laid out from a DeckStyle, built ONLY on the
// existing schema-safe writers (addRoundedRectangle/addShape/addTextBox +
// TextFrame/Paragraph/Run). Because each component uses its own box/shape and
// never a master body placeholder, it never inherits a template bullet — which
// is exactly why the authoring layer needs no placeholders.

/// A card: its rounded-rect background shape, the full frame, and the padded
/// `content` region for inner content.
public struct Card {
    public let shape: Shape
    public let bounds: Rect
    public let content: Rect
}

public extension ShapeCollection {
    /// One styled line (or wrapped block) of text in its own box.
    @discardableResult
    func addText(_ text: String, in rect: Rect, role: TypeRole, style: DeckStyle,
                 color: Color? = nil, align: TextAlignment = .left,
                 anchor: VerticalAnchor = .top) throws -> Shape {
        let box = try styledBox(rect, anchor: anchor)
        var ts = style.type(role)
        if let color { ts.color = color }
        let p = box.textFrame!.addParagraph()
        p.alignment = align
        p.addRun(ts.uppercase ? text.uppercased() : text)
        p.apply(ts)
        return box
    }

    /// Several lines as separate paragraphs in one box.
    @discardableResult
    func addParagraphs(_ lines: [String], in rect: Rect, role: TypeRole, style: DeckStyle,
                       color: Color? = nil, align: TextAlignment = .left,
                       anchor: VerticalAnchor = .top, spacingPt: Double = 0) throws -> Shape {
        let box = try styledBox(rect, anchor: anchor)
        var ts = style.type(role)
        if let color { ts.color = color }
        let tf = box.textFrame!
        for (i, line) in lines.enumerated() {
            let p = tf.addParagraph()
            p.alignment = align
            if i > 0 && spacingPt > 0 { p.setSpacing(beforePoints: spacingPt) }
            p.addRun(ts.uppercase ? line.uppercased() : line)
            p.apply(ts)
        }
        if lines.isEmpty { tf.addParagraph() }   // a txBody must have >= 1 a:p
        return box
    }

    /// A bulleted list; the body size auto-shrinks as the item count grows.
    @discardableResult
    func addBulletList(_ items: [String], in rect: Rect, style: DeckStyle,
                       size: Double? = nil, color: Color? = nil, gapPt: Double? = nil) throws -> Shape {
        let box = try styledBox(rect, anchor: .middle)      // center the list block in its cell
        var ts = style.type(.body)
        ts.sizePt = size ?? bulletSize(count: items.count, base: ts.sizePt)
        if let color { ts.color = color }
        let gap = gapPt ?? style.spacing.md.points          // breathing room between items
        let tf = box.textFrame!
        for (i, item) in items.enumerated() {
            let p = tf.addParagraph()
            p.indentLevel = 0
            p.setBullet()
            if i > 0 { p.setSpacing(beforePoints: gap) }
            p.addRun(item)
            p.apply(ts)
        }
        if items.isEmpty { tf.addParagraph() }   // a txBody must have >= 1 a:p
        return box
    }

    /// A small tracked, uppercase eyebrow label.
    @discardableResult
    func addKicker(_ text: String, in rect: Rect, style: DeckStyle,
                   color: Color? = nil, alignment: TextAlignment = .left,
                   anchor: VerticalAnchor = .top) throws -> Shape {
        try addText(text, in: rect, role: .kicker, style: style, color: color, align: alignment, anchor: anchor)
    }

    /// An oversized number with a caption beneath it.
    @discardableResult
    func addStatTile(_ value: String, caption: String, in rect: Rect, style: DeckStyle,
                     valueColor: Color? = nil, captionColor: Color? = nil,
                     align: TextAlignment = .left, anchor: VerticalAnchor = .top) throws -> Shape {
        let box = try styledBox(rect, anchor: anchor)
        let tf = box.textFrame!
        var vs = style.type(.stat); if let valueColor { vs.color = valueColor }
        var cs = style.type(.caption); if let captionColor { cs.color = captionColor }
        let v = tf.addParagraph(); v.alignment = align; v.addRun(value); v.apply(vs)
        let c = tf.addParagraph(); c.alignment = align
        c.setSpacing(beforePoints: style.spacing.sm.points)
        c.addRun(caption); c.apply(cs)
        return box
    }

    /// A rectangular accent rule / band.
    @discardableResult
    func addAccentRule(in rect: Rect, style: DeckStyle, color: Color? = nil) throws -> Shape {
        try addShape(.rectangle, frame: rect, fill: .solid(color ?? style.primary))
    }

    /// A rounded-rect card (background only). Place inner content in `content`.
    @discardableResult
    func addCard(in rect: Rect, style: DeckStyle, fill: Fill? = nil,
                 radiusToken: String = "lg", radius: EMU? = nil,
                 shadow: Bool = true, line: Line? = nil, padding: EMU? = nil) throws -> Card {
        let shape = try addRoundedRectangle(
            rect, cornerRadius: radius ?? style.radius(radiusToken),
            fill: fill ?? .solid(style.surface), line: line)
        if shadow { shape.enableSoftShadow() }
        return Card(shape: shape, bounds: rect, content: rect.inset(by: padding ?? style.spacing.lg))
    }

    /// A filled pill button with a centered, auto-contrast label.
    @discardableResult
    func addButton(_ label: String, in rect: Rect, style: DeckStyle, fill: Fill? = nil,
                   radiusToken: String = "full", radius: EMU? = nil,
                   textColor: Color? = nil, fontSize: Double? = nil,
                   bold: Bool = true, uppercase: Bool = false) throws -> Shape {
        let f = fill ?? .solid(style.primary)
        let shape = try addRoundedRectangle(
            rect, cornerRadius: radius ?? style.radius(radiusToken), fill: f)
        writeLabel(into: shape, uppercase ? label.uppercased() : label,
                   color: textColor ?? style.textColor(on: f.solidColor ?? style.primary),
                   font: style.bodyFont, size: fontSize ?? style.type(.body).sizePt, bold: bold)
        return shape
    }

    /// A small pill chip / tag (a light tint of the primary by default).
    @discardableResult
    func addChip(_ label: String, in rect: Rect, style: DeckStyle, fill: Fill? = nil,
                 radiusToken: String = "full", radius: EMU? = nil,
                 textColor: Color? = nil, fontSize: Double? = nil,
                 line: Line? = nil, uppercase: Bool = false) throws -> Shape {
        let f = fill ?? .solidAlpha(style.primary, 0.12)
        let shape = try addRoundedRectangle(
            rect, cornerRadius: radius ?? style.radius(radiusToken), fill: f, line: line)
        writeLabel(into: shape, uppercase ? label.uppercased() : label,
                   color: textColor ?? style.ink,
                   font: style.bodyFont, size: fontSize ?? style.type(.caption).sizePt, bold: false)
        return shape
    }

    // MARK: - Private

    private func styledBox(_ rect: Rect, anchor: VerticalAnchor) throws -> Shape {
        let box = try addTextBox(rect)
        let tf = box.textFrame!
        tf.setMargins(left: .zero, top: .zero, right: .zero, bottom: .zero)
        tf.wordWrap = true
        tf.verticalAnchor = anchor
        tf.clear()
        return box
    }

    /// Write a centered label into a shape's OWN text body (button/chip) — never
    /// a second shape, never a second a:bodyPr.
    private func writeLabel(into shape: Shape, _ text: String, color: Color,
                            font: String, size: Double, bold: Bool) {
        guard let tf = shape.textFrame else { return }
        tf.setMargins(left: .zero, top: .zero, right: .zero, bottom: .zero)
        tf.verticalAnchor = .middle
        tf.clear()
        let p = tf.addParagraph()
        p.alignment = .center
        let run = p.addRun(text)
        run.fontName = font; run.fontSize = size; run.bold = bold; run.color = color
    }

    /// Deterministic body-size ladder for a bullet list by item count.
    private func bulletSize(count: Int, base: Double) -> Double {
        if count <= 4 { return base }
        if count <= 6 { return base - 2 }
        if count <= 8 { return base - 4 }
        return Swift.max(20, base - 6)   // never below a legible projection floor
    }
}

/// One-line `Slide` forwarders to `slide.shapes.add*`.
public extension Slide {
    @discardableResult
    func addText(_ text: String, in rect: Rect, role: TypeRole, style: DeckStyle,
                 color: Color? = nil, align: TextAlignment = .left,
                 anchor: VerticalAnchor = .top) throws -> Shape {
        try shapes.addText(text, in: rect, role: role, style: style, color: color, align: align, anchor: anchor)
    }
    @discardableResult
    func addBulletList(_ items: [String], in rect: Rect, style: DeckStyle,
                       size: Double? = nil, color: Color? = nil, gapPt: Double? = nil) throws -> Shape {
        try shapes.addBulletList(items, in: rect, style: style, size: size, color: color, gapPt: gapPt)
    }
    @discardableResult
    func addKicker(_ text: String, in rect: Rect, style: DeckStyle, color: Color? = nil,
                   alignment: TextAlignment = .left, anchor: VerticalAnchor = .top) throws -> Shape {
        try shapes.addKicker(text, in: rect, style: style, color: color, alignment: alignment, anchor: anchor)
    }
    @discardableResult
    func addStatTile(_ value: String, caption: String, in rect: Rect, style: DeckStyle,
                     valueColor: Color? = nil, captionColor: Color? = nil,
                     align: TextAlignment = .left, anchor: VerticalAnchor = .top) throws -> Shape {
        try shapes.addStatTile(value, caption: caption, in: rect, style: style,
                               valueColor: valueColor, captionColor: captionColor, align: align, anchor: anchor)
    }
    @discardableResult
    func addAccentRule(in rect: Rect, style: DeckStyle, color: Color? = nil) throws -> Shape {
        try shapes.addAccentRule(in: rect, style: style, color: color)
    }
    @discardableResult
    func addCard(in rect: Rect, style: DeckStyle, fill: Fill? = nil, radiusToken: String = "lg",
                 radius: EMU? = nil, shadow: Bool = true, line: Line? = nil, padding: EMU? = nil) throws -> Card {
        try shapes.addCard(in: rect, style: style, fill: fill, radiusToken: radiusToken,
                           radius: radius, shadow: shadow, line: line, padding: padding)
    }
    @discardableResult
    func addButton(_ label: String, in rect: Rect, style: DeckStyle, fill: Fill? = nil,
                   radiusToken: String = "full", radius: EMU? = nil, textColor: Color? = nil,
                   fontSize: Double? = nil, bold: Bool = true, uppercase: Bool = false) throws -> Shape {
        try shapes.addButton(label, in: rect, style: style, fill: fill, radiusToken: radiusToken,
                             radius: radius, textColor: textColor, fontSize: fontSize, bold: bold, uppercase: uppercase)
    }
    @discardableResult
    func addChip(_ label: String, in rect: Rect, style: DeckStyle, fill: Fill? = nil,
                 radiusToken: String = "full", radius: EMU? = nil, textColor: Color? = nil,
                 fontSize: Double? = nil, line: Line? = nil, uppercase: Bool = false) throws -> Shape {
        try shapes.addChip(label, in: rect, style: style, fill: fill, radiusToken: radiusToken,
                           radius: radius, textColor: textColor, fontSize: fontSize, line: line, uppercase: uppercase)
    }
}

extension Fill {
    /// The base color for auto-contrast (solid / solidAlpha), else nil.
    var solidColor: Color? {
        switch self {
        case .solid(let c), .solidAlpha(let c, _): return c
        default: return nil
        }
    }
}
