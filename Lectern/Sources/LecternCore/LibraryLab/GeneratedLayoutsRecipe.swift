import Foundation
import Rostrum
import RostrumLayout

public extension LibraryLab {
    /// Offline source content for generation, saved-content recovery and review.
    /// No provider calls, private templates or font policy are required.
    static func generatedLayoutExample() -> DeckIR {
        let panels: [IRPanel] = [
            .init(heading: "Fidelity", detail: "Keep native text, table structure and caller-selected fonts editable."),
            .init(heading: "Performance", detail: "Measure CPU, elapsed time and memory on fixed inputs."),
            .init(heading: "Layout", detail: "Give every word room and keep related rows together.")]
        var rows: [[String]] = [], merges: [IRTableMerge] = [
            .init(row: 0, column: 0, rowSpan: 2, columnSpan: 1),
            .init(row: 0, column: 1, rowSpan: 1, columnSpan: 2),
            .init(row: 0, column: 3, rowSpan: 2, columnSpan: 1)]
        for group in 1...8 {
            merges.append(.init(row: rows.count + 2, column: 0, rowSpan: 2, columnSpan: 1))
            rows.append(["Team \(group)", "R\(group * 2 - 1)", "Preserve every source word in record \(group * 2 - 1).", "Ready"])
            rows.append(["", "R\(group * 2)", "Keep record \(group * 2) with its connected group.", "Ready"])
        }
        let table = IRTable(headers: ["Group", "Evidence", "", "State"], rows: rows,
            additionalHeaders: [["", "Record", "Observation", ""]], merges: merges,
            textDirections: [.init(row: 0, column: 0, direction: .vertical),
                             .init(row: 0, column: 3, direction: .vertical270)])
        let slides = [
            IRSlide(id: "cover", layout: "title", title: "Make room for the idea", body: Body(subtitle: "More ways to compose editable slides")),
            IRSlide(id: "cards", layout: "cards", title: "Four checks", body: Body(panels: panels + [.init(heading: "Reliability", detail: "Save, reopen and inspect the same deck before accepting it.")])),
            IRSlide(id: "columns", layout: "threeColumn", title: "Three priorities guide the work", body: Body(panels: panels)),
            IRSlide(id: "steps", layout: "numberedSteps", title: "Turn evidence into a finished deck", body: Body(panels: [
                .init(heading: "Prepare", detail: "Choose content and typography."),
                .init(heading: "Compose", detail: "Measure text and preserve structure."),
                .init(heading: "Review", detail: "Inspect the saved deck in PowerPoint.")])),
            IRSlide(id: "table", layout: "table", title: "Keep each group together", body: Body(table: table,
                source: "Synthetic example records; every row remains editable."), notes: "Both header rows repeat; team rows stay together.")]
        return DeckIR(meta: Meta(title: "Lectern layout variety"),
            sections: [.init(id: "examples", title: "Examples", slideIds: slides.map(\.id))], slides: slides)
    }
}

enum GeneratedLayoutsRecipe {
    static func make(_ options: LibraryLabOptions) throws -> LibraryLabDraft {
        let deck = try LibraryLabSupport.deck(title: "Generated layouts")
        if options.alternative {
            let ratio = 720 / deck.slideSize.width.points
            deck.slideSize = (.points(720), .points(540))
            // These are our synthetic layouts, not an imported user template.
            for part in deck.slideMasters.map(\.part) + deck.allLayouts.map(\.part) {
                let shapes = try part.dom().firstChild(named: "p:cSld")?.firstChild(named: "p:spTree")?.children(named: "p:sp") ?? []
                for shape in shapes {
                    if let transform = shape.firstChild(named: "p:spPr")?.firstChild(named: "a:xfrm") {
                        for (name, attribute) in [("a:off", "x"), ("a:ext", "cx")] {
                            if let node = transform.firstChild(named: name), let value = node[attribute: attribute].flatMap(Double.init) {
                                node[attribute: attribute] = String(Int((value * ratio).rounded()))
                            }
                        }
                    }
                }
                part.markDirty()
            }
        }
        var input = LibraryLab.generatedLayoutExample()
        input.slides[0].title = options.text
        let engine = TemplateLayoutEngine(presentation: deck, measure: TemplateRendering.measurer)
        let prepared = try TableRendering.prepare(input, engine: engine, templateBacked: false)
        var pages: [String: Slide] = [:]
        for slide in prepared.deck.slides {
            let built: Slide
            if let group = prepared.groups[slide.id] {
                for (id, page) in zip(group.ids, try engine.composeTablePages(group.plan)) { pages[id] = page }
            }
            if let page = pages.removeValue(forKey: slide.id) { built = page }
            else if slide.kind == .title { built = try deck.titleSlide(slide.title ?? "", subtitle: slide.body?.subtitle) }
            else { built = try PanelRendering.build(slide, in: deck) }
            try built.part.dom().firstChild(named: "p:cSld")?[attribute: "name"] = "Lectern:" + slide.id
            built.part.markDirty()
            if let notes = slide.notes { try built.setNotes(notes) }
            try AuthoredLayoutEngine(presentation: deck, measure: TemplateRendering.measurer)
                .finish(built, layoutName: "Generated — " + slide.layout)
        }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return LibraryLabDraft(deck: deck, checks: [
            .init("Measured connected groups", prepared.groups["table"]?.plan.pages.count ?? 0 > 1,
                  "Native merged tables continue with both header rows.")],
            extraFiles: ["generated-layouts.json": try encoder.encode(input)], verify: { reopened in
                let text = reopened.outline().markdown()
                return [.init("Saved panel content", ["Fidelity", "Performance", "Layout", "Reliability", "Prepare", "Compose", "Review"].allSatisfy(text.contains), "All headings remain editable text."),
                    .init("Saved table structure", reopened.slides.flatMap { $0.shapes.all.compactMap { ($0 as? TableFrame)?.table } }
                        .allSatisfy { (try? $0.cell(0, 0).textDirection) == .vertical && ((try? $0.mergedRegions.count) ?? 0) >= 3 },
                        "Header merges and quarter-turn directions survive saving.")]
            })
    }
}
