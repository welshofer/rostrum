import Foundation

/// The shapes on one slide — a live view over `p:spTree`. Holds the slide's
/// `Part` strongly (never a back-reference to the transient `Slide` facade).
public final class ShapeCollection: Sequence {
    let part: Part
    /// Present when the collection can create package-level resources
    /// (image parts for pictures); nil for detached usage.
    let package: OPCPackage?

    init(part: Part, package: OPCPackage? = nil) {
        self.part = part
        self.package = package
    }

    /// Existing `p:sp` shapes, in z-order (document order).
    public var all: [Shape] {
        ((try? Slide.spTree(of: part))?.children(named: "p:sp") ?? [])
            .map { Shape(element: $0, part: part) }
    }

    public var count: Int { all.count }

    public subscript(index: Int) -> Shape { all[index] }

    public func makeIterator() -> IndexingIterator<[Shape]> {
        all.makeIterator()
    }

    // MARK: - Adding

    /// Add a text box: no fill, no outline, text does not wrap-shrink.
    @discardableResult
    public func addTextBox(_ frame: Rect) throws -> Shape {
        let sp = try makeSp(name: "TextBox", frame: frame, textBox: true)
        let spPr = sp.firstChild(named: "p:spPr")!
        spPr.appendElement(Fill.none.makeElement())
        spPr.appendElement(Line.makeElement(nil))
        try Slide.spTree(of: part).appendElement(sp)
        part.markDirty()
        return Shape(element: sp, part: part)
    }

    /// Add an autoshape with a preset geometry.
    @discardableResult
    public func addShape(
        _ geometry: ShapeGeometry, frame: Rect,
        fill: Fill, line: Line? = nil
    ) throws -> Shape {
        let sp = try makeSp(name: geometry.rawValue, frame: frame, textBox: false, geometry: geometry)
        let spPr = sp.firstChild(named: "p:spPr")!
        spPr.appendElement(fill.makeElement())
        spPr.appendElement(Line.makeElement(line))
        try Slide.spTree(of: part).appendElement(sp)
        part.markDirty()
        return Shape(element: sp, part: part)
    }

    /// Add a rounded rectangle with an explicit corner radius (the DrawingML
    /// `roundRect` adjust value). A radius ≥ half the short side yields a full
    /// pill; the value is clamped to that maximum.
    @discardableResult
    public func addRoundedRectangle(
        _ frame: Rect, cornerRadius: EMU, fill: Fill, line: Line? = nil
    ) throws -> Shape {
        let sp = try makeSp(name: "roundRect", frame: frame, textBox: false, geometry: .roundedRectangle)
        let spPr = sp.firstChild(named: "p:spPr")!
        let minSide = Swift.min(frame.width.rawValue, frame.height.rawValue)
        if minSide > 0, let avLst = spPr.firstChild(named: "a:prstGeom")?.firstChild(named: "a:avLst") {
            // roundRect adj is the corner radius as a fraction (×100000) of the
            // shorter side, capped at 50% (a pill).
            let adj = Swift.max(0, Swift.min(50_000,
                Int((Double(cornerRadius.rawValue) / Double(minSide) * 100_000).rounded())))
            avLst.appendElement(XML.Element("a:gd", attributes: [("name", "adj"), ("fmla", "val \(adj)")]))
        }
        spPr.appendElement(fill.makeElement())
        spPr.appendElement(Line.makeElement(line))
        try Slide.spTree(of: part).appendElement(sp)
        part.markDirty()
        return Shape(element: sp, part: part)
    }

    /// The shared `p:sp` skeleton: non-visual properties, transform, geometry,
    /// and an empty text body (PowerPoint expects one on every sp).
    private func makeSp(
        name: String, frame: Rect, textBox: Bool,
        geometry: ShapeGeometry = .rectangle
    ) throws -> XML.Element {
        let id = try Slide.nextShapeID(of: part)
        let sp = XML.Element("p:sp")

        let nvSpPr = XML.Element("p:nvSpPr")
        nvSpPr.appendElement(XML.Element("p:cNvPr", attributes: [
            ("id", String(id)), ("name", "\(name) \(id)"),
        ]))
        nvSpPr.appendElement(XML.Element(
            "p:cNvSpPr", attributes: textBox ? [("txBox", "1")] : []))
        nvSpPr.appendElement(XML.Element("p:nvPr"))
        sp.appendElement(nvSpPr)

        let spPr = XML.Element("p:spPr")
        let xfrm = XML.Element("a:xfrm")
        xfrm.appendElement(XML.Element("a:off", attributes: [
            ("x", String(frame.x.rawValue)), ("y", String(frame.y.rawValue)),
        ]))
        xfrm.appendElement(XML.Element("a:ext", attributes: [
            ("cx", String(frame.width.rawValue)), ("cy", String(frame.height.rawValue)),
        ]))
        spPr.appendElement(xfrm)
        let prstGeom = XML.Element("a:prstGeom", attributes: [("prst", geometry.rawValue)])
        prstGeom.appendElement(XML.Element("a:avLst"))
        spPr.appendElement(prstGeom)
        sp.appendElement(spPr)

        let txBody = XML.Element("p:txBody")
        // txBody's children live in the DRAWINGML namespace: a:bodyPr, not
        // p:bodyPr — renderers silently drop the whole shape otherwise.
        let bodyPr = XML.Element("a:bodyPr")
        if textBox {
            bodyPr[attribute: "wrap"] = "square"
        }
        bodyPr[attribute: "rtlCol"] = "0"
        txBody.appendElement(bodyPr)
        txBody.appendElement(XML.Element("a:lstStyle"))
        txBody.appendElement(XML.Element("a:p"))
        sp.appendElement(txBody)

        return sp
    }
}

/// One shape (`p:sp`) — autoshape or text box.
public final class Shape {
    let element: XML.Element
    let part: Part

    init(element: XML.Element, part: Part) {
        self.element = element
        self.part = part
    }

    private var spPr: XML.Element {
        element.getOrAddChild("p:spPr", beforeAnyOf: ["p:style", "p:txBody"])
    }

    public var name: String {
        get {
            element.firstChild(named: "p:nvSpPr")?
                .firstChild(named: "p:cNvPr")?[attribute: "name"] ?? ""
        }
        set {
            element.firstChild(named: "p:nvSpPr")?
                .firstChild(named: "p:cNvPr")?[attribute: "name"] = newValue
            part.markDirty()
        }
    }

    public var frame: Rect {
        get {
            guard let xfrm = spPr.firstChild(named: "a:xfrm"),
                  let off = xfrm.firstChild(named: "a:off"),
                  let ext = xfrm.firstChild(named: "a:ext") else {
                return Rect(x: .zero, y: .zero, width: .zero, height: .zero)
            }
            return Rect(
                x: EMU(off[attribute: "x"].flatMap { Int($0) } ?? 0),
                y: EMU(off[attribute: "y"].flatMap { Int($0) } ?? 0),
                width: EMU(ext[attribute: "cx"].flatMap { Int($0) } ?? 0),
                height: EMU(ext[attribute: "cy"].flatMap { Int($0) } ?? 0))
        }
        set {
            let xfrm = spPr.getOrAddChild("a:xfrm", beforeAnyOf: ["a:custGeom", "a:prstGeom"])
            let off = xfrm.getOrAddChild("a:off", beforeAnyOf: ["a:ext"])
            off[attribute: "x"] = String(newValue.x.rawValue)
            off[attribute: "y"] = String(newValue.y.rawValue)
            let ext = xfrm.getOrAddChild("a:ext")
            ext[attribute: "cx"] = String(newValue.width.rawValue)
            ext[attribute: "cy"] = String(newValue.height.rawValue)
            part.markDirty()
        }
    }

    /// Rotation in degrees, clockwise.
    public var rotation: Double {
        get {
            let raw = spPr.firstChild(named: "a:xfrm")?[attribute: "rot"].flatMap { Int($0) } ?? 0
            return Double(raw) / 60_000
        }
        set {
            let xfrm = spPr.getOrAddChild("a:xfrm", beforeAnyOf: ["a:custGeom", "a:prstGeom"])
            xfrm[attribute: "rot"] = newValue == 0 ? nil : String(Int((newValue * 60_000).rounded()))
            part.markDirty()
        }
    }

    public func setFill(_ fill: Fill) {
        for name in Fill.choiceNames { spPr.removeChildren(named: name) }
        spPr.insertChild(fill.makeElement(), beforeAnyOf: ["a:ln", "a:effectLst", "a:sp3d", "a:extLst"])
        part.markDirty()
    }

    public func setLine(_ line: Line?) {
        spPr.removeChildren(named: "a:ln")
        spPr.insertChild(Line.makeElement(line), beforeAnyOf: ["a:effectLst", "a:sp3d", "a:extLst"])
        part.markDirty()
    }

    /// A standard soft drop shadow (blur 40pt-ish, 45° down-right, 35% black).
    public func enableSoftShadow() {
        spPr.removeChildren(named: "a:effectLst")
        let effectLst = XML.Element("a:effectLst")
        let shadow = XML.Element("a:outerShdw", attributes: [
            ("blurRad", "254000"), ("dist", "50800"), ("dir", "2700000"),
            ("rotWithShape", "0"),
        ])
        shadow.appendElement(Color.black.srgbElement(alpha: 0.35))
        effectLst.appendElement(shadow)
        spPr.insertChild(effectLst, beforeAnyOf: ["a:sp3d", "a:extLst"])
        part.markDirty()
    }

    /// The shape's text body. Every Rostrum-created shape has one.
    public var textFrame: TextFrame? {
        element.firstChild(named: "p:txBody").map { TextFrame(txBody: $0, part: part) }
    }
}
