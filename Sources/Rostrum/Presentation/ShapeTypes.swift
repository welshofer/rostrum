import Foundation

// Typed views over the shape-tree children that are not autoshapes. Each is a
// subclass of `Shape`, so `slide.shapes` stays a collection of `Shape` and
// existing code keeps compiling, while `as?` narrows to the typed API:
//
//     for shape in slide.shapes {
//         if let picture = shape as? Picture { … picture.imageData … }
//     }
//
// Rostrum owns every subclass (none are `open`), so switching over them is
// exhaustive in practice; `shape.kind` is the cheap, stable discriminator when
// you only need to filter or count.

/// A picture (`p:pic`) — an image placed on a slide.
public final class Picture: Shape {
    /// The relationship id of the embedded image (`a:blip@r:embed`).
    public var imageRelationshipID: String? {
        element.firstChild(named: "p:blipFill")?
            .firstChild(named: "a:blip")?[attribute: "r:embed"]
    }

    /// The package part holding this picture's bytes, resolved through the
    /// owning part's relationships.
    public var imagePart: Part? {
        guard let rId = imageRelationshipID,
              let rel = part.rels.relationship(withId: rId),
              let package else { return nil }
        let uri = PackURI.resolve(target: rel.target, relativeTo: part.uri.baseURI)
        return try? package.part(at: uri)
    }

    /// The image bytes exactly as stored in the package — the read-back half
    /// of `addPicture`.
    public var imageData: Data? { imagePart?.blob }

    /// The image's file extension in the package (`png`, `jpeg`, `gif`, …),
    /// which is how OPC records its format.
    public var imageFormat: String? { imagePart?.uri.ext }
}

/// A connector (`p:cxnSp`) — a line, optionally attached to other shapes.
public final class Connector: Shape {
    /// The shape id and connection-site index this connector starts at
    /// (`a:stCxn`), when it is attached.
    public var startConnection: (shapeID: Int, index: Int)? {
        connection(named: "a:stCxn")
    }

    /// The shape id and connection-site index this connector ends at
    /// (`a:endCxn`), when it is attached.
    public var endConnection: (shapeID: Int, index: Int)? {
        connection(named: "a:endCxn")
    }

    private func connection(named name: String) -> (shapeID: Int, index: Int)? {
        guard let cxn = element.firstChild(named: "p:nvCxnSpPr")?
            .firstChild(named: "p:cNvCxnSpPr")?.firstChild(named: name),
            let id = cxn[attribute: "id"].flatMap({ Int($0) }),
            let idx = cxn[attribute: "idx"].flatMap({ Int($0) }) else { return nil }
        return (id, idx)
    }
}

/// A graphic frame (`p:graphicFrame`) — the container PowerPoint uses for
/// tables, charts, SmartArt diagrams and OLE objects. Its transform lives in
/// `p:xfrm`, not `p:spPr`, and it has no fill or line of its own.
public class GraphicFrame: Shape {
    /// The `a:graphicData` payload element, whatever it holds.
    public var graphicData: XML.Element? {
        element.firstChild(named: "a:graphic")?.firstChild(named: "a:graphicData")
    }
}

/// A graphic frame holding a table.
public final class TableFrame: GraphicFrame {
    /// The table, reconstructed over the parsed `a:tbl` — the read-back half
    /// of `addTable`, with the same cell/row/column API.
    public var table: Table? {
        guard let tbl = graphicData?.firstChild(named: "a:tbl") else { return nil }
        return Table(tbl: tbl, part: part, graphicFrame: element)
    }
}

/// A graphic frame holding a chart.
public final class ChartFrame: GraphicFrame {
    /// The relationship id of the chart part (`c:chart@r:id`).
    public var chartRelationshipID: String? {
        graphicData?.firstChild(named: "c:chart")?[attribute: "r:id"]
    }

    /// The chart part itself. Reading its data back is M4; today this is the
    /// escape hatch to the `chartSpace` XML.
    public var chartPart: Part? {
        guard let rId = chartRelationshipID,
              let rel = part.rels.relationship(withId: rId),
              let package else { return nil }
        let uri = PackURI.resolve(target: rel.target, relativeTo: part.uri.baseURI)
        return try? package.part(at: uri)
    }
}

/// A graphic frame holding a SmartArt diagram.
public final class DiagramFrame: GraphicFrame {
    /// The diagram's data part (`dgm:relIds@r:dm`), which holds its points
    /// and the text `smartArtTexts` extracts.
    public var dataPart: Part? {
        guard let relIds = graphicData?.firstChild(named: "dgm:relIds"),
              let rId = relIds[attribute: "r:dm"],
              let rel = part.rels.relationship(withId: rId),
              let package else { return nil }
        let uri = PackURI.resolve(target: rel.target, relativeTo: part.uri.baseURI)
        return try? package.part(at: uri)
    }
}

/// A group (`p:grpSp`) — shapes positioned in the group's own child
/// coordinate space.
public final class GroupShape: Shape {
    /// The shapes inside this group, one level down. Nested groups appear as
    /// `GroupShape` values you can recurse into.
    ///
    /// Their `frame`s are expressed in this group's **child space**, not slide
    /// coordinates — map one with `convertToParentSpace(_:)`.
    public var shapes: [Shape] {
        ShapeCollection.children(of: element, part: part, package: package)
    }

    /// The group's own child coordinate space (`a:chOff`/`a:chExt`).
    public var childSpace: Rect? {
        ShapeTransform.childSpace(ShapeTransform.element(of: element))
    }

    /// Map a child's rectangle from this group's child space into the space
    /// the group itself lives in (the slide, or an enclosing group).
    ///
    /// Applies the group's `flipH`/`flipV`, which mirror children within the
    /// child extent. The group's `@rot` is **not** composed — rotation turns
    /// an axis-aligned rectangle into a quadrilateral, which `Rect` cannot
    /// express; read `rotation` and compose it yourself if you need it.
    ///
    /// Returns `rect` unchanged when the group declares no child space or a
    /// degenerate one — the transform is undefined then, and inventing a
    /// scale factor would be worse than reporting raw coordinates.
    public func convertToParentSpace(_ rect: Rect) -> Rect {
        guard let child = childSpace, let outer = explicitFrame,
              child.width.rawValue != 0, child.height.rawValue != 0 else { return rect }

        let xfrm = ShapeTransform.element(of: element)
        var localX = rect.x.rawValue
        var localY = rect.y.rawValue
        if xfrm?[attribute: "flipH"] == "1" {
            localX = 2 * child.x.rawValue + child.width.rawValue - (localX + rect.width.rawValue)
        }
        if xfrm?[attribute: "flipV"] == "1" {
            localY = 2 * child.y.rawValue + child.height.rawValue - (localY + rect.height.rawValue)
        }

        let scaleX = Double(outer.width.rawValue) / Double(child.width.rawValue)
        let scaleY = Double(outer.height.rawValue) / Double(child.height.rawValue)
        return Rect(
            x: EMU(outer.x.rawValue + Int((Double(localX - child.x.rawValue) * scaleX).rounded())),
            y: EMU(outer.y.rawValue + Int((Double(localY - child.y.rawValue) * scaleY).rounded())),
            width: EMU(Int((Double(rect.width.rawValue) * scaleX).rounded())),
            height: EMU(Int((Double(rect.height.rawValue) * scaleY).rounded())))
    }
}
