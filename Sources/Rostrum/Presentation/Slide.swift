import Foundation

/// One slide — a facade over its part's DOM.
///
/// Ownership note: facades hold strong references to the stable object graph
/// (`Part`, `OPCPackage`) and never back-reference the transient facade that
/// created them — `deck.slides[0].shapes.addTextBox(…)` must be safe even
/// though the intermediate `Slide` dies mid-expression.
public final class Slide {
    public let part: Part
    /// The owning package — needed to create related parts (notes, comments,
    /// images) on demand. Strong reference; the package never points back.
    let package: OPCPackage

    init(part: Part, package: OPCPackage) {
        self.part = part
        self.package = package
    }

    /// The shape tree: iterate existing shapes, add text boxes, autoshapes
    /// and pictures.
    public var shapes: ShapeCollection {
        ShapeCollection(part: part, package: package)
    }

    func cSld() throws -> XML.Element {
        try Slide.cSld(of: part)
    }

    func spTree() throws -> XML.Element {
        try Slide.spTree(of: part)
    }

    static func cSld(of part: Part) throws -> XML.Element {
        try part.dom().getOrAddChild("p:cSld", beforeAnyOf: ["p:clrMapOvr", "p:timing"])
    }

    static func spTree(of part: Part) throws -> XML.Element {
        try cSld(of: part).getOrAddChild("p:spTree")
    }

    /// The shape tree if the part has one. Unlike `spTree(of:)`, which is
    /// `getOrAddChild`-based and would inject `p:cSld`/`p:spTree` into the DOM
    /// on a pure read, this creates nothing — every read path uses it, so
    /// enumerating an untouched part leaves it byte-identical.
    static func existingSpTree(of part: Part) -> XML.Element? {
        (try? part.dom())?.firstChild(named: "p:cSld")?.firstChild(named: "p:spTree")
    }

    /// Set the slide's background fill (`p:bg`, always the first child of
    /// `p:cSld`).
    ///
    /// A `.image(_, .cover)` background is cropped to the slide canvas, whose
    /// aspect is read from `p:sldSz` here — the background is the one fill
    /// whose region is not a shape frame, so it has to be looked up rather
    /// than passed in.
    public func setBackground(_ fill: Fill) throws {
        let cSld = try cSld()
        cSld.removeChildren(named: "p:bg")
        let bg = XML.Element("p:bg")
        let bgPr = XML.Element("p:bgPr")
        bgPr.appendElement(try fill.fillElement(embeddingInto: part, package: package,
                                                regionAspect: canvasAspect))
        bgPr.appendElement(XML.Element("a:effectLst"))
        bg.appendElement(bgPr)
        cSld.children.insert(.element(bg), at: 0)
        part.markDirty()
    }

    /// The slide canvas aspect (width ÷ height) from the presentation part's
    /// `p:sldSz`, or nil when the deck does not say (`p:sldSz` is optional) or
    /// the size is degenerate. Read-only: unlike `Presentation.slideSize`'s
    /// setter this never creates the element, so asking leaves the part
    /// byte-identical.
    var canvasAspect: Double? {
        guard let dom = try? package.mainDocumentPart().dom(),
              let sldSz = dom.firstChild(named: "p:sldSz"),
              let cx = sldSz[attribute: "cx"].flatMap({ Int($0) }),
              let cy = sldSz[attribute: "cy"].flatMap({ Int($0) }),
              cx > 0, cy > 0 else { return nil }
        return Double(cx) / Double(cy)
    }

    /// Allocate the next free shape id on a slide (`p:cNvPr id` must be a
    /// unique nonzero uint per slide; id 1 is the root group).
    static func nextShapeID(of part: Part) throws -> Int {
        var maxID = 1
        var stack: [XML.Element] = [try part.dom()]
        while let element = stack.popLast() {
            // An id outside the format's range is IGNORED, not clamped: a
            // clamp would let one hostile id pin maxID at the ceiling and
            // permanently refuse every future shape on the slide.
            if element.name == "p:cNvPr",
               let id = element.boundedInt("id", in: OOXMLBounds.drawingElementID) {
                maxID = Swift.max(maxID, id)
            }
            stack.append(contentsOf: element.childElements)
        }
        guard maxID < Self.maxShapeID else {
            throw RostrumError.packageInvalid(
                "shape ids on this slide reach the format's maximum (\(Self.maxShapeID)); "
                    + "there is no id left to assign")
        }
        return maxID + 1
    }

    /// The largest `p:cNvPr@id` the format allows (`ST_DrawingElementId` is an
    /// `xsd:unsignedInt`).
    static let maxShapeID = OOXMLBounds.drawingElementID.upperBound
}
