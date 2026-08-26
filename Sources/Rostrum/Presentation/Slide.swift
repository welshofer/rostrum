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

    /// The slide's own solid background colour, if it sets one.
    ///
    /// `setBackground` had no counterpart, so a caller could write a background
    /// but never ask what one was — which makes "build a new slide that looks
    /// like this deck" impossible to do faithfully. Plenty of real decks carry
    /// their look on the slide rather than in the theme: a Keynote export puts
    /// `<p:bg><a:solidFill><a:srgbClr val="000000"/>` on every slide while the
    /// theme's `dk1`/`lt1` stay at the Office defaults, so a reader consulting
    /// only the theme concludes the deck is light.
    ///
    /// Nil when the slide inherits its background, or sets a gradient or
    /// picture fill rather than a solid one — this answers one narrow question
    /// and says nothing when the answer is not simple.
    public var solidBackground: Color? {
        guard let bg = (try? part.dom())?
            .firstChild(named: "p:cSld")?
            .firstChild(named: "p:bg")?
            .firstChild(named: "p:bgPr")?
            .firstChild(named: "a:solidFill"),
            let srgb = bg.firstChild(named: "a:srgbClr"),
            let value = srgb[attribute: "val"] else { return nil }
        // `validating:` rather than the literal init: this value came out of a
        // file, and a malformed one should be nil rather than a trap.
        return Color(validating: value)
    }

    /// Set the slide's background fill (`p:bg`, always the first child of
    /// `p:cSld`).
    public func setBackground(_ fill: Fill) throws {
        let cSld = try cSld()
        cSld.removeChildren(named: "p:bg")
        let bg = XML.Element("p:bg")
        let bgPr = XML.Element("p:bgPr")
        bgPr.appendElement(try fill.fillElement(embeddingInto: part, package: package))
        bgPr.appendElement(XML.Element("a:effectLst"))
        bg.appendElement(bgPr)
        cSld.children.insert(.element(bg), at: 0)
        part.markDirty()
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
