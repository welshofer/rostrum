import Foundation
import Testing
import Rostrum
import RostrumLayout
@testable import LecternCore

@Suite struct AuthoredFurnitureTests {
    @Test func inheritedBodySpacingCannotAbortAtTheSlideNumber() throws {
        let deck = try Presentation()
        deck.applyDesign(Design.parse("## Typography\n- body-md: family Arial, size 20pt, line 1.5\n- caption: family Arial, size 13pt, line 2\n"))
        try deck.compileThemeMaster()
        let slide = try deck.bulletSlide("Costs", ["Keep this evidence."])
        try deck.showSlideNumbers()
        let engine = AuthoredLayoutEngine(presentation: deck)
        #expect(throws: LayoutError.self) { try engine.fitText(in: slide) }
        try AuthoredFurniture.finish(slide, layoutName: "Readable furniture", engine: engine)
        let body = try #require(slide.shapes.all.first { $0.textFrame?.text == "Keep this evidence." })
        #expect(body.textFrame?.text == "Keep this evidence.")
        let field = try #require(slide.shapes.all.first { $0.textFrame?.text == "1" })
        let node = try #require(slide.part.dom().firstChild(named: "p:cSld")?.firstChild(named: "p:spTree")?.children(named: "p:sp").first {
            $0.firstChild(named: "p:nvSpPr")?.firstChild(named: "p:cNvPr")?[attribute: "id"] == field.shapeID.map(String.init)
        })
        let paragraph = try #require(node.firstChild(named: "p:txBody")?.firstChild(named: "a:p"))
        #expect(paragraph.firstChild(named: "a:fld")?[attribute: "type"] == "slidenum")
        #expect(paragraph.firstChild(named: "a:pPr")?.firstChild(named: "a:lnSpc")?.firstChild(named: "a:spcPct")?[attribute: "val"] == "100000")
        #expect(try deck.validate().isEmpty)
    }

    @Test func ordinaryOutputIsUnchangedAndContentFailuresStillThrow() throws {
        func build(repair: Bool) throws -> Data {
            let deck = try Presentation()
            let slide = try deck.bulletSlide("Evidence", ["Exact words"])
            try deck.showSlideNumbers()
            let engine = AuthoredLayoutEngine(presentation: deck)
            if repair { try AuthoredFurniture.finish(slide, layoutName: "Same", engine: engine) }
            else { try engine.finish(slide, layoutName: "Same") }
            return try deck.serializedData()
        }
        #expect(try build(repair: true) == build(repair: false))
        let deck = try Presentation()
        let slide = try deck.bulletSlide("Impossible", [String(repeating: "Unbreakable", count: 1000)])
        try deck.showSlideNumbers()
        #expect(throws: LayoutError.self) {
            try AuthoredFurniture.finish(slide, layoutName: "No lost text", engine: AuthoredLayoutEngine(presentation: deck))
        }
    }

    /// A vertical sidebar used to abort the whole slide's final fit. It is now
    /// published unchanged, the rest of the deck is fitted, and the renderer
    /// names the skipped shape instead of accepting it silently.
    @Test func verticalTextShapeShipsWithAWarningNamingIt() throws {
        let deck = try Presentation()
        while deck.slides.count > 0 { try deck.slides.remove(at: 0) } // Index-aligned with the IR below.
        _ = try deck.titleSlide("Plan", subtitle: "Quarterly review")
        let slide = try deck.bulletSlide("Costs", ["Keep this evidence."])
        let sidebar = try slide.shapes.addTextBox(Rect(x: .points(880), y: .points(120), width: .points(40), height: .points(300)))
        sidebar.textFrame?.text = "DRAFT SIDEBAR THAT WOULD NEVER FIT HORIZONTALLY"
        let id = try #require(sidebar.shapeID)
        let node = try #require(slide.part.dom().firstChild(named: "p:cSld")?.firstChild(named: "p:spTree")?.childElements.first {
            $0.firstChild(named: "p:nvSpPr")?.firstChild(named: "p:cNvPr")?[attribute: "id"] == String(id)
        })
        try #require(node.firstChild(named: "p:txBody")?.firstChild(named: "a:bodyPr"))[attribute: "vert"] = "vert270"
        slide.part.markDirty()
        try deck.showSlideNumbers(from: 1)
        let ir = DeckIR(meta: .init(title: "Plan"), slides: [
            IRSlide(id: "open", layout: "title", title: "Plan", body: Body(subtitle: "Quarterly review")),
            IRSlide(id: "costs", layout: "bullets", title: "Costs", body: Body(bullets: [Bullet(text: "Keep this evidence.")]))])

        let warnings = try DeckRenderer.finishAuthoredSlides(deck, deck: ir,
            engine: AuthoredLayoutEngine(presentation: deck, measure: TemplateRendering.measurer))

        #expect(warnings == ["Costs: shape \(id) was left unfitted because it uses vertical or multi-column text that authored fitting does not support."])
        #expect(try deck.validate().isEmpty)
        let reopened = try Presentation(data: deck.serializedData())
        try reopened.validateTemplateBindings()
        try #require(reopened.slides.count == 2)
        let saved = try reopened.slides[1]
        #expect(saved.layout?.name == "Lectern — bullets 2")
        // Publishing turns slide text into inheriting placeholders. The text is
        // intact and the vertical body still resolves, so it is still skipped.
        #expect(saved.shapes.all.first { $0.shapeID == id }?.textFrame?.text == "DRAFT SIDEBAR THAT WOULD NEVER FIT HORIZONTALLY")
        #expect(try AuthoredLayoutEngine(presentation: reopened).fitText(in: saved, only: [id]).skipped.map(\.shapeID) == [id])
        #expect(saved.shapes.all.contains { $0.textFrame?.text == "Keep this evidence." })
    }

    @Test func unfittedWarningsNameIDLessShapesAndFallBackToTheSlideID() {
        let report = AuthoredFitReport(fitted: [2], skipped: [.init(shapeID: nil, reason: "uses vertical text.")])
        #expect(DeckRenderer.unfittedWarnings(report, on: IRSlide(id: "s7", layout: "bullets", title: ""))
            == ["s7: a shape without an id was left unfitted because it uses vertical text."])
        #expect(DeckRenderer.unfittedWarnings(AuthoredFitReport(fitted: [2]), on: IRSlide(id: "s7", layout: "bullets")).isEmpty)
    }
}
