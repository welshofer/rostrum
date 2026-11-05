import Rostrum
import RostrumLayout

enum AuthoredFurniture {
    /// Normal decks take the unchanged final-fit path. A generated slide-number
    /// field can inherit oversized caption paragraph spacing from a design master;
    /// give just that rejected field explicit single-line furniture spacing.
    /// Returns the final pass's report so callers can surface skipped shapes.
    @discardableResult
    static func finish(_ slide: Slide, layoutName: String, engine: AuthoredLayoutEngine) throws -> AuthoredFitReport {
        do { return try engine.finish(slide, layoutName: layoutName) }
        catch let original as LayoutError {
            var repaired = false
            let nodes = try slide.part.dom().firstChild(named: "p:cSld")?
                .firstChild(named: "p:spTree")?.children(named: "p:sp") ?? []
            let fields = Set(nodes.compactMap { node -> Int? in
                guard node.firstChild(named: "p:txBody")?.children(named: "a:p").contains(where: {
                    $0.children(named: "a:fld").contains { $0[attribute: "type"] == "slidenum" }
                }) == true else { return nil }
                return node.firstChild(named: "p:nvSpPr")?.firstChild(named: "p:cNvPr")?[attribute: "id"].flatMap(Int.init)
            })
            for shape in slide.shapes.all {
                guard let id = shape.shapeID, fields.contains(id), let text = shape.textFrame else { continue }
                do { try engine.fitText(in: slide, only: [id]) }
                catch is LayoutError {
                    for paragraph in text.paragraphs {
                        paragraph.setLineSpacing(1)
                        paragraph.setSpacing(beforePoints: 0, afterPoints: 0)
                    }
                    repaired = true
                }
            }
            guard repaired else { throw original }
            // Revalidate the whole slide. Content failures and unfit fields
            // still surface; never suppress a layout error or remove a number.
            return try engine.finish(slide, layoutName: layoutName)
        }
    }
}
