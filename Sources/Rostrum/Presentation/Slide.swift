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

    /// Set the slide's background fill (`p:bg`, always the first child of
    /// `p:cSld`).
    public func setBackground(_ fill: Fill) throws {
        let cSld = try cSld()
        cSld.removeChildren(named: "p:bg")
        let bg = XML.Element("p:bg")
        let bgPr = XML.Element("p:bgPr")
        bgPr.appendElement(fill.makeElement())
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
            if element.name == "p:cNvPr", let id = element[attribute: "id"].flatMap({ Int($0) }) {
                maxID = Swift.max(maxID, id)
            }
            stack.append(contentsOf: element.childElements)
        }
        return maxID + 1
    }
}
