import Foundation

// Brand table styling via EXPLICIT per-cell fills + a:tcPr padding + the Phase-1
// text path — no tableStyles.xml part, so it stays lossless, byte-deterministic,
// and repair-free. Colors/spacing resolve from DeckStyle, matching the deck's
// brand. Trade-off (intended for a brand-locked authoring tool): explicit fills
// don't auto-recolor when a user later edits the theme in PowerPoint.

public extension Table {
    /// Style row 0 as a brand header: primary fill with auto-contrast text.
    @discardableResult
    func header(style: DeckStyle, fill: Color? = nil, textColor: Color? = nil,
                role: TypeRole = .heading, align: TextAlignment = .left,
                anchor: VerticalAnchor = .middle) -> Table {
        clearBuiltInStyle()
        guard rowCount > 0, columnCount > 0 else { return self }
        let bg = fill ?? style.primary
        var ts = style.type(role)
        ts.color = textColor ?? style.textColor(on: bg)
        // Bulk styling is tolerant of a ragged foreign row: a cell the grid
        // declares but the row does not have is skipped, not an error.
        for c in 0..<columnCount {
            guard let cell = try? cell(0, c) else { continue }
            cell.setFill(bg).verticalAnchorAndStyle(ts, align: align, anchor: anchor)
        }
        return self
    }

    /// Alternate body-row fills (banded), auto-contrasting text per row, with an
    /// optional brand header row.
    @discardableResult
    func styleBanded(style: DeckStyle, header: Bool = true, band1: Color? = nil, band2: Color? = nil,
                     role: TypeRole = .body, align: TextAlignment = .left,
                     anchor: VerticalAnchor = .middle) -> Table {
        clearBuiltInStyle()
        if header { self.header(style: style, align: align, anchor: anchor) }
        let b1 = band1 ?? style.surface
        let b2 = band2 ?? style.primary.mixed(with: style.surface, amount: 0.90)
        let start = header ? 1 : 0
        var band = 0
        for r in start..<rowCount {
            let rowFill = band % 2 == 0 ? b1 : b2
            var ts = style.type(role)
            ts.color = style.textColor(on: rowFill)
            for c in 0..<columnCount {
                guard let cell = try? cell(r, c) else { continue }
                cell.setFill(rowFill).verticalAnchorAndStyle(ts, align: align, anchor: anchor)
            }
            band += 1
        }
        return self
    }

    /// Uniform cell padding on every cell.
    @discardableResult
    func cellPadding(_ inset: EMU) -> Table {
        cellPadding(left: inset, top: inset, right: inset, bottom: inset)
    }

    /// Per-edge cell padding on every cell.
    @discardableResult
    func cellPadding(left: EMU, top: EMU, right: EMU, bottom: EMU) -> Table {
        for r in 0..<rowCount {
            for c in 0..<columnCount {
                guard let cell = try? cell(r, c) else { continue }
                cell.setPadding(left: left, top: top, right: right, bottom: bottom)
            }
        }
        return self
    }
}

public extension TableCell {
    /// A solid-color fill (non-throwing convenience alongside `setFill(_:Fill)`),
    /// inserted in schema order (before a:headers/a:extLst).
    @discardableResult
    func setFill(_ color: Color) -> TableCell {
        for name in Fill.choiceNames { tcPr.removeChildren(named: name) }
        let fill = XML.Element("a:solidFill")
        fill.appendElement(color.srgbElement())
        tcPr.insertChild(fill, beforeAnyOf: ["a:headers", "a:extLst"])
        part.markDirty()
        return self
    }

    /// Cell padding as `a:tcPr` margin attributes.
    @discardableResult
    func setPadding(left: EMU, top: EMU, right: EMU, bottom: EMU) -> TableCell {
        tcPr[attribute: "marL"] = String(left.rawValue)
        tcPr[attribute: "marT"] = String(top.rawValue)
        tcPr[attribute: "marR"] = String(right.rawValue)
        tcPr[attribute: "marB"] = String(bottom.rawValue)
        part.markDirty()
        return self
    }

    /// Set the cell's text and apply a `TextStyle` to it.
    @discardableResult
    func setText(_ text: String, style: TextStyle, align: TextAlignment? = nil) -> TableCell {
        self.text = style.uppercase ? text.uppercased() : text
        return applyTextStyle(style, align: align)
    }

    /// Apply a `TextStyle` (font/size/bold/color/tracking/line-height) to every
    /// paragraph/run already in the cell.
    @discardableResult
    func applyTextStyle(_ style: TextStyle, align: TextAlignment? = nil) -> TableCell {
        for p in textFrame.paragraphs {
            if let align { p.alignment = align }
            p.apply(style)
        }
        part.markDirty()
        return self
    }

    /// Internal helper: set anchor + text style in one chainable call.
    @discardableResult
    func verticalAnchorAndStyle(_ style: TextStyle, align: TextAlignment,
                                anchor: VerticalAnchor) -> TableCell {
        verticalAnchor = anchor
        return applyTextStyle(style, align: align)
    }
}
