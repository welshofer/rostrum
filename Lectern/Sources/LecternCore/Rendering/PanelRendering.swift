import Rostrum
import RostrumLayout

enum PanelRendering {
    static func content(_ slide: IRSlide) -> (PanelKind, [StructuredItem])? {
        guard let kind = PanelKind(rawValue: slide.layout) else { return nil }
        return (kind, (slide.body?.panels ?? []).map { StructuredItem($0.heading, detail: $0.detail) })
    }

    static func build(_ input: IRSlide, in deck: Presentation) throws -> Slide {
        guard let content = content(input) else { throw LayoutError.cannotFit("Unknown panel layout") }
        // The ordinary header builder owns title/eyebrow/lead geometry. Its empty
        // body supplies the same content region used by existing authored slides.
        let slide = try deck.bulletSlide(input.title ?? "", [], kicker: input.body?.kicker, lead: input.body?.lead)
        guard let body = slide.shapes.all.last, let frame = slide.effectiveFrame(of: body) else {
            throw LayoutError.cannotFit("The panel slide has no content region")
        }
        let bottom = min(frame.maxY, deck.bounds.maxY - .inches(0.65))
        let region = Rect(x: frame.x, y: frame.y, width: frame.width, height: bottom - frame.y)
        _ = try PanelLayout.compose(kind: content.0, items: content.1, in: region, on: slide,
            style: deck.style, engine: TemplateLayoutEngine(presentation: deck, measure: TemplateRendering.measurer))
        return slide
    }
}
