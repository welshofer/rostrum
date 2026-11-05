import Foundation
import Rostrum
import RostrumLayout

/// A computed-fit demonstration, separate from the native reference specimens.
enum AuthoredFittingRecipe {
    static func append(to draft: LibraryLabDraft, alternative: Bool) throws -> LibraryLabDraft {
        var result = draft
        let deck = draft.deck
        let page = deck.slides.count
        let slide = try deck.slides.add()
        let height = alternative ? 48.0 : 45.0
        let title = try PlatformLabRecipes.text("Mixed-size authored text: before and after", on: slide,
            in: LibraryLabSupport.frame(0.6, 0.3, 12, 0.8))
        title.textFrame?.paragraphs.first?.runs.first?.fontSize = 25
        var boxes: [Shape] = []
        for x in [50.0, 480.0] {
            let box = try slide.shapes.addTextBox(Rect(x: .points(x), y: .points(170), width: .points(350), height: .points(height)))
            box.name = boxes.isEmpty ? "Before authored fitting" : "After authored fitting"
            box.setLine(Line(color: Color("94A3B8"), width: .points(1)))
            let text = try PlatformLabRecipes.require(box.textFrame, "Missing authored text body")
            text.setMargins(left: .zero, top: .zero, right: .zero, bottom: .zero)
            text.clear()
            let paragraph = text.addParagraph()
            let small = paragraph.addRun("Small ")
            small.fontName = "DejaVu Sans"; small.fontSize = 24
            let large = paragraph.addRun("LARGE")
            large.fontName = "DejaVu Sans"; large.fontSize = 48
            large.color = Color("276D89")
            boxes.append(box)
        }
        // A quarter-turn label: authored fitting cannot verify vertical text,
        // so it reports the shape as skipped and leaves its XML untouched.
        let vertical = try PlatformLabRecipes.text("Vertical label", on: slide,
            in: Rect(x: .points(860), y: .points(110), width: .points(50), height: .points(170)))
        vertical.name = "Vertical label (left unfitted)"
        let verticalID = try PlatformLabRecipes.require(vertical.shapeID, "Missing vertical shape ID")
        let verticalBody = try PlatformLabRecipes.require(node(slide, id: verticalID)?.firstChild(named: "p:txBody")?
            .firstChild(named: "a:bodyPr"), "Missing vertical body properties")
        verticalBody[attribute: "vert"] = "vert270"
        slide.part.markDirty()
        let verticalXML = try node(slide, id: verticalID).map(XML.document)
        // Saving normalizes attribute order, so compare the reopened label with
        // its saved pre-fit form rather than the in-memory element.
        let savedBeforeFit = try Presentation(data: deck.serializedData())
        let savedVerticalXML = try node(savedBeforeFit.slides[page], id: verticalID).map(XML.document)
        let fittedID = try PlatformLabRecipes.require(boxes[1].shapeID, "Missing fitted shape ID")
        let before = try layout(slide, id: fittedID, deck: deck)
        let report = try AuthoredLayoutEngine(presentation: deck).fitText(in: slide, only: [fittedID, verticalID])
        let after = try layout(slide, id: fittedID, deck: deck)
        let savedRuns = boxes[1].textFrame?.paragraphs.first?.runs.map { ($0.text, $0.fontSize) }
        _ = try PlatformLabRecipes.text("Left: original 24/48 pt runs exceed the frame. Right: the authored fitter saves a computed scale while preserving both runs. The vertical label at right is reported as skipped and left unchanged.\nThe preview and fitter share rich-text geometry. This is not a PowerPoint-selected autofit or native pixel-equivalence claim.",
            on: slide, in: LibraryLabSupport.frame(0.7, 4, 11.8, 1.6))
        result.checks.append(.init("Authored mixed-size fit", !before.fits && after.fits,
            "Complete mixed-size geometry changes from overflow to a fitting body in a \(height) pt frame."))
        let verticalAfter = try node(slide, id: verticalID).map(XML.document)
        result.checks.append(.init("Vertical text reported as skipped", report.fitted == [fittedID]
            && report.skipped.map(\.shapeID) == [verticalID] && verticalXML != nil && verticalAfter == verticalXML,
            "The fit report lists the ordinary body as fitted and the vert270 label as skipped; the label's XML is unchanged and the other body still fits."))
        let originalVerify = draft.verify
        result.verify = { reopened in
            var checks = try originalVerify(reopened)
            _ = reopened.registerEmbeddedFonts()
            let reopenedSlide = try reopened.slides[page]
            let actual = try layout(reopenedSlide, id: fittedID, deck: reopened)
            let fitted = try PlatformLabRecipes.require(reopenedSlide.shapes.all.first { $0.shapeID == fittedID }, "Saved fitted shape missing")
            let runs = fitted.textFrame?.paragraphs.first?.runs
            checks.append(.init("Authored fit survives reopening", actual.fits && actual.lines == after.lines,
                "Saved autofit reproduces the accepted lines, run sizes, positions and colors with the embedded face."))
            checks.append(.init("Authored run formatting preserved", runs?.map(\.text) == savedRuns?.map(\.0)
                && runs?.map(\.fontSize) == [24, 48], "Original run text and authored sizes remain editable; normal autofit carries the computed scale."))
            let savedVertical = try node(reopenedSlide, id: verticalID).map(XML.document)
            checks.append(.init("Skipped vertical text preserved", savedVertical != nil && savedVertical == savedVerticalXML,
                "The unfitted vert270 label reopens byte-identical to its saved pre-fit XML."))
            return checks
        }
        return result
    }

    private static func node(_ slide: Slide, id: Int) throws -> XML.Element? {
        try slide.part.dom().firstChild(named: "p:cSld")?.firstChild(named: "p:spTree")?.childElements.first {
            $0.firstChild(named: "p:nvSpPr")?.firstChild(named: "p:cNvPr")?[attribute: "id"] == String(id)
        }
    }

    private static func layout(_ slide: Slide, id: Int, deck: Presentation) throws -> RichTextLayout {
        let shape = try PlatformLabRecipes.require(slide.shapes.all.first { $0.shapeID == id }, "Authored shape missing")
        let body = try PlatformLabRecipes.require(node(slide, id: id)?.firstChild(named: "p:txBody"), "Authored body missing")
        return RichTextLayout(textBody: body, width: shape.frame.width.points, height: shape.frame.height.points,
            fonts: deck.fonts, theme: deck.theme, maxLines: 64)
    }
}
