import Foundation

public enum TextAlignment: String, Sendable {
    case left = "l"
    case center = "ctr"
    case right = "r"
    case justified = "just"
}

public enum VerticalAnchor: String, Sendable {
    case top = "t"
    case middle = "ctr"
    case bottom = "b"
}

/// A shape's text body (`p:txBody`).
public final class TextFrame {
    let txBody: XML.Element
    let part: Part

    init(txBody: XML.Element, part: Part) {
        self.txBody = txBody
        self.part = part
    }

    private var bodyPr: XML.Element {
        txBody.getOrAddChild("a:bodyPr", beforeAnyOf: ["a:lstStyle", "a:p"])
    }

    public var wordWrap: Bool {
        get { bodyPr[attribute: "wrap"] != "none" }
        set {
            bodyPr[attribute: "wrap"] = newValue ? "square" : "none"
            part.markDirty()
        }
    }

    public var verticalAnchor: VerticalAnchor {
        get { bodyPr[attribute: "anchor"].flatMap(VerticalAnchor.init(rawValue:)) ?? .top }
        set {
            bodyPr[attribute: "anchor"] = newValue.rawValue
            part.markDirty()
        }
    }

    /// Inner margins (left, top, right, bottom). PowerPoint defaults are
    /// 0.1"/0.05" — set `.zero` for edge-to-edge design text.
    public func setMargins(left: EMU, top: EMU, right: EMU, bottom: EMU) {
        bodyPr[attribute: "lIns"] = String(left.rawValue)
        bodyPr[attribute: "tIns"] = String(top.rawValue)
        bodyPr[attribute: "rIns"] = String(right.rawValue)
        bodyPr[attribute: "bIns"] = String(bottom.rawValue)
        part.markDirty()
    }

    public var paragraphs: [Paragraph] {
        txBody.children(named: "a:p").map { Paragraph(p: $0, part: part) }
    }

    /// Plain-text view: concatenated on read; replaces all content with a
    /// single paragraph/run on write.
    public var text: String {
        get {
            paragraphs.map { paragraph in
                paragraph.runs.map(\.text).joined()
            }.joined(separator: "\n")
        }
        set {
            clear()
            let paragraph = addParagraph()
            paragraph.addRun(newValue)
        }
    }

    /// Remove all paragraphs. (`p:txBody` requires at least one `a:p`, so a
    /// subsequent save without `addParagraph()` gets one back implicitly.)
    public func clear() {
        txBody.removeChildren(named: "a:p")
        part.markDirty()
    }

    @discardableResult
    public func addParagraph() -> Paragraph {
        let p = XML.Element("a:p")
        txBody.appendElement(p)
        part.markDirty()
        return Paragraph(p: p, part: part)
    }

    /// Ensure the body is schema-valid (at least one `a:p`).
    func ensureNonEmpty() {
        if txBody.firstChild(named: "a:p") == nil {
            txBody.appendElement(XML.Element("a:p"))
        }
    }
}

/// One paragraph (`a:p`).
public final class Paragraph {
    let p: XML.Element
    let part: Part

    init(p: XML.Element, part: Part) {
        self.p = p
        self.part = part
    }

    /// `a:pPr` must be the first child of `a:p`.
    private var pPr: XML.Element {
        if let existing = p.firstChild(named: "a:pPr") { return existing }
        let pPr = XML.Element("a:pPr")
        p.children.insert(.element(pPr), at: 0)
        return pPr
    }

    public var alignment: TextAlignment? {
        get { p.firstChild(named: "a:pPr")?[attribute: "algn"].flatMap(TextAlignment.init(rawValue:)) }
        set {
            pPr[attribute: "algn"] = newValue?.rawValue
            part.markDirty()
        }
    }

    /// Space before/after the paragraph, in points.
    public func setSpacing(beforePoints: Double? = nil, afterPoints: Double? = nil) {
        // No explicit beforeAnyOf: the generated schema places a:spcBef/a:spcAft
        // ahead of ALL the bullet elements (buFont/buAutoNum/buChar/…). A
        // hand-written list omitting those mis-orders spacing after a bullet.
        if let beforePoints {
            let spcBef = pPr.getOrAddChild("a:spcBef")
            spcBef.removeChildren(named: "a:spcPts")
            spcBef.appendElement(XML.Element(
                "a:spcPts", attributes: [("val", String(Int((beforePoints * 100).rounded())))]))
        }
        if let afterPoints {
            let spcAft = pPr.getOrAddChild("a:spcAft")
            spcAft.removeChildren(named: "a:spcPts")
            spcAft.appendElement(XML.Element(
                "a:spcPts", attributes: [("val", String(Int((afterPoints * 100).rounded())))]))
        }
        part.markDirty()
    }

    /// Line spacing as a multiple of single spacing (1.0 = single).
    public func setLineSpacing(_ multiple: Double) {
        // a:lnSpc is the first child of a:pPr; the generated schema's full
        // successor list keeps it ahead of spacing AND bullet elements even
        // when those were added first (an explicit [spcBef, spcAft] would not).
        let lnSpc = pPr.getOrAddChild("a:lnSpc")
        lnSpc.removeChildren(named: "a:spcPct")
        lnSpc.appendElement(XML.Element(
            "a:spcPct", attributes: [("val", String(Int((multiple * 100_000).rounded())))]))
        part.markDirty()
    }

    // MARK: - Bullets & indentation

    /// Outline/indent level, 0…8 (`a:pPr@lvl`).
    public var indentLevel: Int {
        get { p.firstChild(named: "a:pPr")?[attribute: "lvl"].flatMap { Int($0) } ?? 0 }
        set {
            pPr[attribute: "lvl"] = newValue == 0 ? nil : String(newValue)
            part.markDirty()
        }
    }

    /// The bullet/numbering choice group and everything that follows it.
    private static let bulletSuccessors = ["a:tabLst", "a:defRPr", "a:extLst"]

    private func clearBulletChildren() {
        for name in ["a:buNone", "a:buAutoNum", "a:buChar", "a:buFont"] {
            pPr.removeChildren(named: name)
        }
    }

    /// A character bullet (default a round bullet in Arial).
    public func setBullet(_ char: String = "\u{2022}", font: String = "Arial") {
        clearBulletChildren()
        pPr.insertChild(XML.Element("a:buFont", attributes: [("typeface", font)]),
                        beforeAnyOf: ["a:buNone", "a:buAutoNum", "a:buChar"] + Self.bulletSuccessors)
        pPr.insertChild(XML.Element("a:buChar", attributes: [("char", char)]),
                        beforeAnyOf: Self.bulletSuccessors)
        part.markDirty()
    }

    /// An auto-numbered bullet, e.g. "arabicPeriod" (1.), "alphaLcParenR" (a)).
    public func setNumbered(_ type: String = "arabicPeriod") {
        clearBulletChildren()
        pPr.insertChild(XML.Element("a:buAutoNum", attributes: [("type", type)]),
                        beforeAnyOf: Self.bulletSuccessors)
        part.markDirty()
    }

    /// Explicitly suppress a bullet (overrides an inherited list style).
    public func setNoBullet() {
        clearBulletChildren()
        pPr.insertChild(XML.Element("a:buNone"), beforeAnyOf: Self.bulletSuccessors)
        part.markDirty()
    }

    public var runs: [Run] {
        p.children(named: "a:r").map { Run(r: $0, part: part) }
    }

    @discardableResult
    public func addRun(_ text: String) -> Run {
        let r = XML.Element("a:r")
        let t = XML.Element("a:t")
        t.children = [.text(text)]
        r.appendElement(t)
        p.appendElement(r)
        part.markDirty()
        return Run(r: r, part: part)
    }
}

/// One text run (`a:r`) and its character properties (`a:rPr`).
public final class Run {
    let r: XML.Element
    let part: Part

    init(r: XML.Element, part: Part) {
        self.r = r
        self.part = part
    }

    /// `a:rPr` must precede `a:t`.
    private var rPr: XML.Element {
        if let existing = r.firstChild(named: "a:rPr") { return existing }
        let rPr = XML.Element("a:rPr", attributes: [("lang", "en-US"), ("dirty", "0")])
        r.children.insert(.element(rPr), at: 0)
        return rPr
    }

    public var text: String {
        get { r.firstChild(named: "a:t")?.textContent ?? "" }
        set {
            let t = r.getOrAddChild("a:t")
            t.children = [.text(newValue)]
            part.markDirty()
        }
    }

    /// Font size in points.
    public var fontSize: Double? {
        get { rPr[attribute: "sz"].flatMap { Int($0) }.map { Double($0) / 100 } }
        set {
            rPr[attribute: "sz"] = newValue.map { String(Int(($0 * 100).rounded())) }
            part.markDirty()
        }
    }

    public var bold: Bool {
        get { rPr[attribute: "b"] == "1" }
        set {
            rPr[attribute: "b"] = newValue ? "1" : nil
            part.markDirty()
        }
    }

    public var italic: Bool {
        get { rPr[attribute: "i"] == "1" }
        set {
            rPr[attribute: "i"] = newValue ? "1" : nil
            part.markDirty()
        }
    }

    /// Letter spacing (tracking) in points; positive spreads, negative tightens.
    public var letterSpacing: Double? {
        get { rPr[attribute: "spc"].flatMap { Int($0) }.map { Double($0) / 100 } }
        set {
            rPr[attribute: "spc"] = newValue.map { String(Int(($0 * 100).rounded())) }
            part.markDirty()
        }
    }

    /// Typeface name (e.g. "Avenir Next"). Sets latin script fonts.
    public var fontName: String? {
        get { rPr.firstChild(named: "a:latin")?[attribute: "typeface"] }
        set {
            rPr.removeChildren(named: "a:latin")
            if let newValue {
                // insertChild (no explicit successors) consults the generated
                // schema, so a:latin lands before a:ea/a:cs/a:sym/a:hlinkClick…
                // even when the hyperlink or color was set first. Appending
                // here would emit a:latin after a:hlinkClick — invalid order.
                rPr.insertChild(XML.Element("a:latin", attributes: [("typeface", newValue)]))
            }
            part.markDirty()
        }
    }

    public var color: Color? {
        get {
            rPr.firstChild(named: "a:solidFill")?
                .firstChild(named: "a:srgbClr")?[attribute: "val"]
                .flatMap { Color(validating: $0) }
        }
        set {
            rPr.removeChildren(named: "a:solidFill")
            if let newValue {
                let fill = XML.Element("a:solidFill")
                fill.appendElement(newValue.srgbElement())
                // The generated schema places a:solidFill ahead of a:latin AND
                // a:hlinkClick; a hand-written list omitting hlinkClick would
                // mis-order a color set after a hyperlink.
                rPr.insertChild(fill)
            }
            part.markDirty()
        }
    }

    /// Underline (`a:rPr@u`; sng/dbl/none/…).
    public var underline: Bool {
        get { let u = rPr[attribute: "u"]; return u != nil && u != "none" }
        set {
            rPr[attribute: "u"] = newValue ? "sng" : nil
            part.markDirty()
        }
    }

    /// Strikethrough (`a:rPr@strike`).
    public var strikethrough: Bool {
        get { let s = rPr[attribute: "strike"]; return s != nil && s != "noStrike" }
        set {
            rPr[attribute: "strike"] = newValue ? "sngStrike" : nil
            part.markDirty()
        }
    }

    /// Baseline shift as a percent of font size (`a:rPr@baseline`): positive
    /// raises (superscript), negative lowers (subscript), nil is normal.
    public var baselinePercent: Double? {
        get { rPr[attribute: "baseline"].flatMap { Int($0) }.map { Double($0) / 1000 } }
        set {
            rPr[attribute: "baseline"] = newValue.map { String(Int(($0 * 1000).rounded())) }
            part.markDirty()
        }
    }

    public func setSuperscript() { baselinePercent = 30 }
    public func setSubscript() { baselinePercent = -25 }

    /// Turn this run into a hyperlink to `url` (an external target). Adds the
    /// relationship on the owning part and an `a:hlinkClick` to the run.
    public func setHyperlink(_ url: String) {
        let rId = part.rels.add(type: RelType.hyperlink, target: url, isExternal: true)
        rPr.removeChildren(named: "a:hlinkClick")
        rPr.insertChild(XML.Element("a:hlinkClick", attributes: [("r:id", rId)]),
                        beforeAnyOf: ["a:hlinkMouseOver", "a:rtl", "a:extLst"])
        part.markDirty()
    }

    /// The hyperlink target if this run is a link, resolved through the part's
    /// relationships.
    public var hyperlink: String? {
        guard let rId = rPr.firstChild(named: "a:hlinkClick")?[attribute: "r:id"] else { return nil }
        return part.rels.relationship(withId: rId)?.target
    }
}
