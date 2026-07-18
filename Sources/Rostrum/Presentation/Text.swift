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
        if let beforePoints {
            let spcBef = pPr.getOrAddChild("a:spcBef", beforeAnyOf: ["a:spcAft", "a:buNone", "a:buChar"])
            spcBef.removeChildren(named: "a:spcPts")
            spcBef.appendElement(XML.Element(
                "a:spcPts", attributes: [("val", String(Int((beforePoints * 100).rounded())))]))
        }
        if let afterPoints {
            let spcAft = pPr.getOrAddChild("a:spcAft", beforeAnyOf: ["a:buNone", "a:buChar"])
            spcAft.removeChildren(named: "a:spcPts")
            spcAft.appendElement(XML.Element(
                "a:spcPts", attributes: [("val", String(Int((afterPoints * 100).rounded())))]))
        }
        part.markDirty()
    }

    /// Line spacing as a multiple of single spacing (1.0 = single).
    public func setLineSpacing(_ multiple: Double) {
        let lnSpc = pPr.getOrAddChild("a:lnSpc", beforeAnyOf: ["a:spcBef", "a:spcAft"])
        lnSpc.removeChildren(named: "a:spcPct")
        lnSpc.appendElement(XML.Element(
            "a:spcPct", attributes: [("val", String(Int((multiple * 100_000).rounded())))]))
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
                rPr.appendElement(XML.Element("a:latin", attributes: [("typeface", newValue)]))
            }
            part.markDirty()
        }
    }

    public var color: Color? {
        get {
            rPr.firstChild(named: "a:solidFill")?
                .firstChild(named: "a:srgbClr")?[attribute: "val"].map(Color.init)
        }
        set {
            rPr.removeChildren(named: "a:solidFill")
            if let newValue {
                let fill = XML.Element("a:solidFill")
                fill.appendElement(newValue.srgbElement())
                // a:solidFill must precede a:latin in rPr's schema order.
                rPr.insertChild(fill, beforeAnyOf: ["a:latin", "a:ea", "a:cs"])
            }
            part.markDirty()
        }
    }
}
