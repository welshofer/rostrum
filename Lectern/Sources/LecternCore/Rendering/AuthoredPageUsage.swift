import Rostrum

enum AuthoredPageUsage {
    /// Compare the occupied fraction of body text frames after actual fitting.
    /// Titles, column headings and citations cannot make a sparse body look full.
    static func fraction(on slide: Slide, input: IRSlide, in deck: Presentation) throws -> Double {
        let labels = Set([input.title, input.body?.source, input.body?.kicker, input.body?.lead,
            input.body?.left?.heading, input.body?.right?.heading].compactMap { $0 })
        var fraction = 0.0
        // These probes use our flat authored builders before layout publication:
        // body styles are explicit on the slide. This score never approves fit;
        // AuthoredLayoutEngine already checked the full inheritance and host font.
        let nodes = try slide.part.dom().firstChild(named: "p:cSld")?
            .firstChild(named: "p:spTree")?.children(named: "p:sp") ?? []
        var bodies: [Int: XML.Element] = [:]
        for node in nodes {
            if let id = node.firstChild(named: "p:nvSpPr")?.firstChild(named: "p:cNvPr")?[attribute: "id"].flatMap(Int.init),
               let body = node.firstChild(named: "p:txBody") { bodies[id] = body }
        }
        for shape in slide.shapes.all {
            guard let text = shape.textFrame?.text, !text.isEmpty, !labels.contains(text),
                  let id = shape.shapeID, let body = bodies[id],
                  let frame = slide.effectiveFrame(of: shape), frame.height > .zero else { continue }
            let layout = RichTextLayout(textBody: body, width: frame.width.points, height: frame.height.points,
                fonts: deck.fonts, theme: slide.master?.theme ?? deck.theme)
            fraction = max(fraction, layout.contentHeight / frame.height.points)
        }
        return fraction
    }
}
