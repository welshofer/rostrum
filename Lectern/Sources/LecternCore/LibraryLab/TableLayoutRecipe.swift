import Foundation
import Rostrum
import RostrumLayout

enum TableLayoutRecipe {
    static func append(to draft: LibraryLabDraft) throws -> LibraryLabDraft {
        var result = draft
        let source = try Presentation()
        source.slideSize = draft.deck.slideSize
        let layout = try PlatformLabRecipes.require(source.layout(type: "obj"), "Table layout missing")
        let shapes = try layout.part.dom().firstChild(named: "p:cSld")?.firstChild(named: "p:spTree")?.children(named: "p:sp") ?? []
        for shape in shapes {
            let placeholder = shape.firstChild(named: "p:nvSpPr")?.firstChild(named: "p:nvPr")?.firstChild(named: "p:ph")
            guard let placeholder else { continue }
            let index = Int(placeholder[attribute: "idx"] ?? "0") ?? 0
            guard index == 0 || index == 1 else { continue }
            let properties = try PlatformLabRecipes.require(shape.firstChild(named: "p:spPr"), "Table placeholder geometry missing")
            properties.children.removeAll { if case .element(let child) = $0 { return child.name == "a:xfrm" }; return false }
            properties.children.insert(.element(XML.Element("a:xfrm", children: [
                .element(XML.Element("a:off", attributes: [("x", String(EMU.points(50).rawValue)), ("y", String(EMU.points(index == 0 ? 30 : 135).rawValue))])),
                .element(XML.Element("a:ext", attributes: [("cx", String((source.bounds.width - .points(100)).rawValue)), ("cy", String(EMU.points(index == 0 ? 80 : 350).rawValue))]))
            ])), at: 0)
        }
        layout.part.markDirty()
        source.theme.majorFont = "DejaVu Sans"; source.theme.minorFont = "DejaVu Sans"
        let font = try PlatformLabRecipes.resource("DejaVuSans", "ttf")
        try source.embedFont("DejaVu Sans", faces: .init(regular: font))
        source.documentKind = .template
        let input = try source.serializedData()
        let deck = try Presentation.fromTemplate(data: input)
        _ = deck.registerEmbeddedFonts()
        let content = TemplateTableContent(rows: [
            ["Area", "What determines the row height", "State"],
            ["Fidelity", "Actual cell fonts, native style and wrapping", "Measured"],
            ["Layout", "Explicit cell padding and paragraph spacing", "Editable"],
            ["Performance", "Repeated cells reuse measurements within each plan", "Bounded"]
        ], columnWeights: [1, 2.6, 1])
        let engine = TemplateLayoutEngine(presentation: deck)
        let caption = "Unmerged horizontal cells only. No pagination or table autofit. Bundled regular DejaVu Sans; missing faces remain diagnostic. PowerPoint visual acceptance is pending."
        let plan = try engine.plan(title: "Tables use native cell geometry", columns: [], preferredTypes: ["obj"],
            object: "tbl", objectCaption: caption, table: content)
        let slide = try engine.compose(plan, title: "Tables use native cell geometry", columns: [])
        let frame = try PlatformLabRecipes.require(slide.shapes.all.compactMap { $0 as? TableFrame }.first, "Planned table missing")
        let table = try PlatformLabRecipes.require(frame.table, "Planned cells missing")
        // Exercise the public existing-table path as well as template composition.
        try table.cell(2, 1).setPadding(left: .points(18), top: .points(11), right: .points(18), bottom: .points(9))
        let measured = try TableLayoutEngine(presentation: deck).plan(table, minimumRowHeight: .points(30),
            maximumHeight: plan.objectFrame?.height)
        guard measured.fits else { throw LayoutError.cannotFit("Lab table exceeds its template slot.") }
        table.rowHeights(measured.rowHeights)
        if let captionFrame = plan.captionFrame {
            let note = try slide.addText(caption, in: captionFrame, role: .caption,
                style: engine.objectStyle(layout: plan.layout, slot: plan.objectSlot?.index))
            try AuthoredLayoutEngine(presentation: deck).fitText(in: slide, only: [note.shapeID!])
        }
        let page = draft.deck.slides.count
        let svg = try deck.renderSVG(slideAt: 0)
        try draft.deck.slides.importAll(from: deck)
        result.extraFiles["table-layout-template.potx"] = input
        result.extraFiles["planned-table-output.pptx"] = try deck.serializedData()
        result.checks.append(.init("Native table plan reserves caption space", measured.fits
            && (plan.captionFrame?.y ?? .zero) >= frame.frame.maxY + .points(8),
            "Explicit padding is measured at full text size before applying rows; the caption keeps an eight-point gap."))
        let originalVerify = draft.verify
        result.verify = { reopened in
            var checks = try originalVerify(reopened)
            _ = reopened.registerEmbeddedFonts()
            let slide = try reopened.slides[page]
            let saved = try PlatformLabRecipes.require(slide.shapes.all.compactMap { ($0 as? TableFrame)?.table }.first, "Saved planned table missing")
            let current = try TableLayoutEngine(presentation: reopened).plan(saved, minimumRowHeight: .points(30))
            var cellsFit = true, textRetained = true
            for row in content.rows.indices { for column in content.rows[row].indices {
                let cell = try saved.cell(row, column)
                textRetained = textRetained && cell.text == content.rows[row][column]
                let text = try PlatformLabRecipes.require(cell.existingTextFrame, "Saved cell text missing")
                cellsFit = cellsFit && text.fitText(in: Rect(x: .zero, y: .zero,
                    width: measured.columnWidths[column], height: measured.rowHeights[row]),
                    fonts: reopened.fonts, theme: slide.master?.theme).fits
            } }
            checks += [
                .init("Saved table rows reproduce the plan", current.fits && current.rowHeights == measured.rowHeights
                    && current.columnWidths == measured.columnWidths && cellsFit && textRetained,
                    "Every saved native cell retains its words and fits its planned width and height; the public planner reproduces the row grid."),
                .init("Saved planned table renders identically", try reopened.renderSVG(slideAt: page) == svg,
                    "Import, export and reopen preserve the actual slide SVG. This is a portable geometry check, not native PowerPoint acceptance.")
            ]
            return checks
        }
        return result
    }
}
