import Foundation

/// Where each shape-tree child stores its transform. The paths are **not**
/// uniform, and that non-uniformity is the whole reason a polymorphic `frame`
/// needs one dispatch point instead of an assumption:
///
///     p:sp / p:pic / p:cxnSp   →  p:spPr/a:xfrm
///     p:graphicFrame           →  p:xfrm          (a direct child!)
///     p:grpSp                  →  p:grpSpPr/a:xfrm
///
/// `p:graphicFrame` and `p:grpSp` have no `p:spPr` in their content models at
/// all, so code that reaches for one on those elements invents invalid XML.
enum ShapeTransform {
    /// The transform element, or nil when the shape carries none.
    ///
    /// A pure read: never `getOrAddChild`, never `markDirty()`. Reading a
    /// shape's geometry must not modify the document — that is what makes an
    /// untouched part re-emit its pristine bytes.
    static func element(of e: XML.Element) -> XML.Element? {
        switch e.name {
        case "p:graphicFrame":
            return e.firstChild(named: "p:xfrm")
        case "p:grpSp":
            return e.firstChild(named: "p:grpSpPr")?.firstChild(named: "a:xfrm")
        case "p:sp", "p:pic", "p:cxnSp":
            return e.firstChild(named: "p:spPr")?.firstChild(named: "a:xfrm")
        default:
            return nil
        }
    }

    /// Get-or-create the transform in schema position, for setters.
    ///
    /// Returns nil for element kinds with no legal home for one: we refuse to
    /// invent XML rather than emit a document PowerPoint offers to repair.
    /// The caller marks the part dirty.
    static func mutableElement(of e: XML.Element) -> XML.Element? {
        switch e.name {
        case "p:graphicFrame":
            return e.getOrAddChild("p:xfrm", beforeAnyOf: ["a:graphic"])
        case "p:grpSp":
            return e.getOrAddChild(
                "p:grpSpPr",
                beforeAnyOf: ["p:sp", "p:grpSp", "p:graphicFrame", "p:cxnSp", "p:pic", "p:extLst"]
            ).getOrAddChild("a:xfrm")
        case "p:sp", "p:pic", "p:cxnSp":
            return e.getOrAddChild("p:spPr", beforeAnyOf: ["p:style", "p:txBody"])
                .getOrAddChild("a:xfrm", beforeAnyOf: ["a:custGeom", "a:prstGeom"])
        default:
            return nil
        }
    }

    /// The `p:spPr` this element kind can legally carry — nil for
    /// `p:graphicFrame` and `p:grpSp`. Creates it when the kind allows one.
    static func mutableShapeProperties(of e: XML.Element) -> XML.Element? {
        switch e.name {
        case "p:sp", "p:pic", "p:cxnSp":
            return e.getOrAddChild("p:spPr", beforeAnyOf: ["p:style", "p:txBody"])
        default:
            return nil
        }
    }

    /// The rectangle described by an `a:off`/`a:ext` pair, or nil when either
    /// is absent (a placeholder inheriting its geometry writes neither).
    static func rect(_ xfrm: XML.Element?,
                     offset: String = "a:off", extent: String = "a:ext") -> Rect? {
        guard let xfrm,
              let off = xfrm.firstChild(named: offset),
              let ext = xfrm.firstChild(named: extent) else { return nil }
        return Rect(x: EMU(int(off, "x")), y: EMU(int(off, "y")),
                    width: EMU(int(ext, "cx")), height: EMU(int(ext, "cy")))
    }

    /// A group's child coordinate space (`a:chOff`/`a:chExt`): the rectangle
    /// its children's coordinates are expressed in, which the group's own
    /// `a:off`/`a:ext` then maps onto the slide.
    static func childSpace(_ xfrm: XML.Element?) -> Rect? {
        rect(xfrm, offset: "a:chOff", extent: "a:chExt")
    }

    /// Clockwise rotation in degrees (`@rot`, in 60,000ths of a degree).
    static func rotation(of e: XML.Element) -> Double {
        Double(element(of: e)?[attribute: "rot"].flatMap { Int($0) } ?? 0) / 60_000
    }

    private static func int(_ e: XML.Element, _ attribute: String) -> Int {
        e[attribute: attribute].flatMap { Int($0) } ?? 0
    }
}
