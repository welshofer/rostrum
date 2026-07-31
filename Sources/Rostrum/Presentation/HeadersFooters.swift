import Foundation

// Footer text, slide numbers, and dates — dropped as small text boxes in the
// bottom band of each slide. Numbers/dates use a live `a:fld` run so PowerPoint
// keeps them dynamic; field GUIDs are derived deterministically (byte-stable).
// Slide-XML-only: no master/layout placeholder wiring, no new parts.

extension Slide {
    /// What this slide is actually painted with, as far as text drawn on top
    /// of it is concerned.
    ///
    /// Furniture is added after the builders have set backgrounds, so asking
    /// the slide is the difference between "legible on the deck's canvas" and
    /// "legible on this slide".
    enum Backdrop {
        case canvas                 // no explicit background; the deck's own
        case solid(Color)           // a section field, a coloured panel
        case picture                // a photograph: texture, not a flat tone
    }

    var backdrop: Backdrop {
        guard let bgPr = (try? part.dom())?.firstChild(named: "p:cSld")?
            .firstChild(named: "p:bg")?.firstChild(named: "p:bgPr") else { return .canvas }
        if bgPr.firstChild(named: "a:blipFill") != nil { return .picture }
        if let hex = bgPr.firstChild(named: "a:solidFill")?
            .firstChild(named: "a:srgbClr")?[attribute: "val"],
           let color = Color(validating: hex) { return .solid(color) }
        return .canvas
    }
}

public extension Presentation {
    /// Add a live slide-number field to the bottom-right of every slide.
    @discardableResult
    func showSlideNumbers(style: DeckStyle? = nil) throws -> Presentation {
        let s = style ?? self.style
        let b = bounds
        let frame = Rect(x: b.maxX - .inches(1.3), y: b.maxY - .inches(0.55),
                         width: .inches(1.0), height: .inches(0.35))
        try forEachSlide {
            try $0.shapes.addFieldBox(type: "slidenum", text: "1", frame: frame,
                                      style: s, align: .right,
                                      color: furnitureColor(on: $0, style: s))
        }
        return self
    }

    /// Add a live date field to the bottom-left of every slide.
    @discardableResult
    func showDate(style: DeckStyle? = nil) throws -> Presentation {
        let s = style ?? self.style
        let b = bounds
        let frame = Rect(x: b.minX, y: b.maxY - .inches(0.55), width: .inches(2.4), height: .inches(0.35))
        try forEachSlide {
            try $0.shapes.addFieldBox(type: "datetime", text: "2020-01-01", frame: frame,
                                      style: s, align: .left,
                                      color: furnitureColor(on: $0, style: s))
        }
        return self
    }

    /// Add footer text to the bottom-center of every slide.
    @discardableResult
    func footer(_ text: String, style: DeckStyle? = nil) throws -> Presentation {
        let s = style ?? self.style
        let b = bounds
        let frame = Rect(x: b.midX - .inches(2.5), y: b.maxY - .inches(0.55),
                         width: .inches(5.0), height: .inches(0.35))
        try forEachSlide {
            try $0.addText(text, in: frame, role: .caption, style: s,
                           color: furnitureColor(on: $0, style: s), align: .center, anchor: .middle)
        }
        return self
    }

    /// The colour furniture should take on `slide`.
    ///
    /// Muted ink is right on a flat canvas — it is what makes a footer read as
    /// furniture rather than content. Over a photograph it is just washed out,
    /// whatever its contrast ratio says, because the eye is fighting texture
    /// rather than a tone; there, full-strength ink is the legible choice. A
    /// section slide painted with an accent field is a third case again: the
    /// deck's muted ink was picked against the canvas, not against that field.
    internal func furnitureColor(on slide: Slide, style s: DeckStyle) -> Color {
        switch slide.backdrop {
        case .canvas:
            return s.mutedInk
        case .picture:
            return s.textColor(on: s.background)
        case .solid(let fill):
            let ink = s.textColor(on: fill)
            // Keep the quieter tone when it still carries on this field.
            return s.mutedInk.contrastRatio(with: fill) >= 4.5 ? s.mutedInk : ink
        }
    }

    private func forEachSlide(_ body: (Slide) throws -> Void) throws {
        for i in 0..<slides.count { try body(slides[i]) }
    }
}

extension ShapeCollection {
    /// A small text box carrying a live field (`a:fld`) — slide number or date.
    @discardableResult
    func addFieldBox(type: String, text: String, frame: Rect, style: DeckStyle,
                     align: TextAlignment, color: Color? = nil) throws -> Shape {
        let box = try addTextBox(frame)
        let tf = box.textFrame!
        tf.setMargins(left: .zero, top: .zero, right: .zero, bottom: .zero)
        tf.verticalAnchor = .middle
        tf.clear()
        let paragraph = tf.addParagraph()
        paragraph.alignment = align

        let caption = style.type(.caption)
        let fld = XML.Element("a:fld", attributes: [
            ("id", SectionGUID.make(name: "\(type):\(part.uri.value)", index: 0, avoiding: [])),
            ("type", type),
        ])
        let rPr = XML.Element("a:rPr", attributes: [("lang", "en-US"), ("sz", String(Int(caption.sizePt * 100)))])
        let fill = XML.Element("a:solidFill")
        fill.appendElement((color ?? style.mutedInk).srgbElement())
        rPr.appendElement(fill)                                   // a:solidFill before a:latin (schema order)
        rPr.appendElement(XML.Element("a:latin", attributes: [("typeface", caption.font)]))
        fld.appendElement(rPr)
        let t = XML.Element("a:t")
        t.children = [.text(text)]
        fld.appendElement(t)
        paragraph.p.appendElement(fld)                           // a:pPr (from alignment) then a:fld
        part.markDirty()
        return box
    }
}
