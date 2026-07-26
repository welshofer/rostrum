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

    /// Every shape on the slide, in z-order (document order): autoshapes,
    /// pictures, tables, charts, SmartArt, groups and connectors alike, each
    /// as the most specific `Shape` subclass Rostrum models. Narrow with
    /// `as?` (`shape as? Picture`) or filter on the cheaper `shape.kind`.
    ///
    /// Shape types Rostrum does not model still appear — as plain `Shape`
    /// values with `kind == .other` — so nothing on a foreign deck is
    /// invisible to enumeration.
    ///
    /// A pure read: nothing here creates or dirties XML.
    public var all: [Shape] {
        guard let spTree = Slide.existingSpTree(of: part) else { return [] }
        return Self.children(of: spTree, part: part, package: package)
    }

    /// Only the `p:sp` autoshapes and text boxes — what `all` returned before
    /// pictures, tables, charts, groups and connectors joined it.
    public var autoShapes: [Shape] {
        all.filter { $0.kind == .autoShape }
    }

    /// The shape-tree children of `container` (a `p:spTree` or a `p:grpSp`),
    /// skipping the container's own non-shape properties.
    static func children(of container: XML.Element, part: Part,
                         package: OPCPackage?) -> [Shape] {
        container.childElements.compactMap { element in
            // A shape tree's first children are its own properties, not
            // shapes: p:nvGrpSpPr and p:grpSpPr (plus a trailing p:extLst).
            // Enumerating those as shapes is the classic bug here.
            switch element.name {
            case "p:nvGrpSpPr", "p:grpSpPr", "p:extLst": return nil
            default: return make(element, part: part, package: package)
            }
        }
    }

    /// The most specific facade for a shape-tree child.
    private static func make(_ element: XML.Element, part: Part,
                             package: OPCPackage?) -> Shape {
        switch ShapeKind(element: element) {
        case .picture: return Picture(element: element, part: part, package: package)
        case .connector: return Connector(element: element, part: part, package: package)
        case .group: return GroupShape(element: element, part: part, package: package)
        case .table: return TableFrame(element: element, part: part, package: package)
        case .chart: return ChartFrame(element: element, part: part, package: package)
        case .diagram: return DiagramFrame(element: element, part: part, package: package)
        case .graphicFrame: return GraphicFrame(element: element, part: part, package: package)
        case .autoShape, .other: return Shape(element: element, part: part, package: package)
        }
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
        return Shape(element: sp, part: part, package: package)
    }

    /// Add an autoshape with a preset geometry.
    @discardableResult
    public func addShape(
        _ geometry: ShapeGeometry, frame: Rect,
        fill: Fill, line: Line? = nil
    ) throws -> Shape {
        let sp = try makeSp(name: geometry.rawValue, frame: frame, textBox: false, geometry: geometry)
        let spPr = sp.firstChild(named: "p:spPr")!
        spPr.appendElement(try fill.fillElement(embeddingInto: part, package: package))
        spPr.appendElement(Line.makeElement(line))
        try Slide.spTree(of: part).appendElement(sp)
        part.markDirty()
        return Shape(element: sp, part: part, package: package)
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
        spPr.appendElement(try fill.fillElement(embeddingInto: part, package: package))
        spPr.appendElement(Line.makeElement(line))
        try Slide.spTree(of: part).appendElement(sp)
        part.markDirty()
        return Shape(element: sp, part: part, package: package)
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
        // a:ext is ST_PositiveCoordinate — a negative extent from an over-inset
        // layout is schema-invalid and makes PowerPoint offer to "repair". Clamp
        // it away at the one point every shape's size is written.
        xfrm.appendElement(XML.Element("a:ext", attributes: [
            ("cx", String(Swift.max(0, frame.width.rawValue))), ("cy", String(Swift.max(0, frame.height.rawValue))),
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
        // Shrink text to fit its box rather than spill past the edges. This is the
        // single guard against overflow across every builder (long bullets, step
        // captions, headers); PowerPoint and LibreOffice both honor it.
        bodyPr.appendElement(XML.Element("a:normAutofit"))
        txBody.appendElement(bodyPr)
        txBody.appendElement(XML.Element("a:lstStyle"))
        txBody.appendElement(XML.Element("a:p"))
        sp.appendElement(txBody)

        return sp
    }
}

/// One child of a shape tree: an autoshape or text box (`p:sp`), or — via a
/// subclass — a `Picture`, `TableFrame`, `ChartFrame`, `DiagramFrame`,
/// `GroupShape` or `Connector`.
///
/// Public but not `open`: Rostrum owns every subclass, so `as?` narrowing is
/// exhaustive in practice while the taxonomy stays free to grow in a minor
/// version. `kind` is the cheap discriminator when you only need to filter.
public class Shape {
    let element: XML.Element
    let part: Part
    /// The owning package, when known — required to embed image fills. `nil` for
    /// shapes built without package context (chart/SmartArt graphic frames).
    let package: OPCPackage?

    init(element: XML.Element, part: Part, package: OPCPackage? = nil) {
        self.element = element
        self.part = part
        self.package = package
    }

    /// What this shape is — the cheap discriminator, derived from the element
    /// name (plus the payload URI for graphic frames) without building a
    /// facade. Narrow to a typed subclass with `as?` when you need its API.
    public var kind: ShapeKind { ShapeKind(element: element) }

    /// The shape id (`p:cNvPr@id`), unique within the slide.
    public var shapeID: Int? {
        element.childElements.first?.firstChild(named: "p:cNvPr")?[attribute: "id"]
            .flatMap { Int($0) }
    }

    /// The `p:spPr` this shape can legally carry, created on demand — nil for
    /// graphic frames and groups, whose content models have none. Setters
    /// only: a *read* must never create XML (see `ShapeTransform`).
    private var mutableSpPr: XML.Element? {
        ShapeTransform.mutableShapeProperties(of: element)
    }

    /// The shape's name (`p:cNvPr@name`), read through whichever non-visual
    /// container this element kind uses — `p:nvSpPr` for an autoshape,
    /// `p:nvPicPr` for a picture, and so on. It is always the first child.
    public var name: String {
        get { element.childElements.first?.firstChild(named: "p:cNvPr")?[attribute: "name"] ?? "" }
        set {
            element.childElements.first?.firstChild(named: "p:cNvPr")?[attribute: "name"] = newValue
            part.markDirty()
        }
    }

    /// The transform written on this shape, or nil when it carries none — a
    /// placeholder inheriting its geometry from the layout, or a graphic frame
    /// that has not been positioned. Use this to tell "no transform" apart
    /// from a genuine zero rectangle; `Slide.effectiveFrame(of:)` resolves
    /// placeholder inheritance.
    public var explicitFrame: Rect? {
        ShapeTransform.rect(ShapeTransform.element(of: element))
    }

    /// Position and size, zero when the shape carries no transform.
    ///
    /// Reads the transform from wherever this element kind keeps it — a
    /// graphic frame's lives in `p:xfrm`, not `p:spPr/a:xfrm` — and writing to
    /// a kind with no legal home for one is a no-op rather than invalid XML.
    public var frame: Rect {
        get { explicitFrame ?? Rect(x: .zero, y: .zero, width: .zero, height: .zero) }
        set {
            guard let xfrm = ShapeTransform.mutableElement(of: element) else { return }
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
        get { ShapeTransform.rotation(of: element) }
        set {
            guard let xfrm = ShapeTransform.mutableElement(of: element) else { return }
            xfrm[attribute: "rot"] = newValue == 0 ? nil : String(Int((newValue * 60_000).rounded()))
            part.markDirty()
        }
    }

    /// - Throws: `RostrumError.packageInvalid` when this shape has no
    ///   `p:spPr` to put a fill in — graphic frames (charts, tables, SmartArt)
    ///   and groups. Style those through their own content instead.
    public func setFill(_ fill: Fill) throws {
        guard let spPr = mutableSpPr else {
            throw RostrumError.packageInvalid("\(element.name) has no p:spPr to fill")
        }
        for name in Fill.choiceNames { spPr.removeChildren(named: name) }
        spPr.insertChild(try fill.fillElement(embeddingInto: part, package: package),
                         beforeAnyOf: ["a:ln", "a:effectLst", "a:sp3d", "a:extLst"])
        part.markDirty()
    }

    /// A no-op on graphic frames and groups, which have no `p:spPr`.
    public func setLine(_ line: Line?) {
        guard let spPr = mutableSpPr else { return }
        spPr.removeChildren(named: "a:ln")
        spPr.insertChild(Line.makeElement(line), beforeAnyOf: ["a:effectLst", "a:sp3d", "a:extLst"])
        part.markDirty()
    }

    /// A standard soft drop shadow (blur 40pt-ish, 45° down-right, 35% black).
    /// A no-op on graphic frames and groups, which have no `p:spPr`.
    public func enableSoftShadow() {
        guard let spPr = mutableSpPr else { return }
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
