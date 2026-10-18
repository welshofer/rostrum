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
}
