import Foundation

// Footer text, slide numbers, and dates — dropped as small text boxes in the
// bottom band of each slide. Numbers/dates use a live `a:fld` run so PowerPoint
// keeps them dynamic; field GUIDs are derived deterministically (byte-stable).
// Slide-XML-only: no master/layout placeholder wiring, no new parts.

public extension Presentation {
    /// Add a live slide-number field to the bottom-right of every slide.
    @discardableResult
    func showSlideNumbers(style: DeckStyle? = nil) throws -> Presentation {
        let s = style ?? self.style
        let b = bounds
        let frame = Rect(x: b.maxX - .inches(1.3), y: b.maxY - .inches(0.55),
                         width: .inches(1.0), height: .inches(0.35))
        try forEachSlide { try $0.shapes.addFieldBox(type: "slidenum", text: "1", frame: frame, style: s, align: .right) }
        return self
    }

    /// Add a live date field to the bottom-left of every slide.
    @discardableResult
    func showDate(style: DeckStyle? = nil) throws -> Presentation {
        let s = style ?? self.style
        let b = bounds
        let frame = Rect(x: b.minX, y: b.maxY - .inches(0.55), width: .inches(2.4), height: .inches(0.35))
        try forEachSlide { try $0.shapes.addFieldBox(type: "datetime", text: "2020-01-01", frame: frame, style: s, align: .left) }
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
            try $0.addText(text, in: frame, role: .caption, style: s, color: s.mutedInk, align: .center, anchor: .middle)
        }
        return self
    }

    private func forEachSlide(_ body: (Slide) throws -> Void) throws {
        for i in 0..<slides.count { try body(slides[i]) }
    }
}

extension ShapeCollection {
    /// A small text box carrying a live field (`a:fld`) — slide number or date.
    @discardableResult
    func addFieldBox(type: String, text: String, frame: Rect, style: DeckStyle,
                     align: TextAlignment) throws -> Shape {
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
        fill.appendElement(style.mutedInk.srgbElement())
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
