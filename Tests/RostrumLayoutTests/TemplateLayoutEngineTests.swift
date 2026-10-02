import Foundation
import Testing
@testable import Rostrum
@testable import RostrumLayout

@Suite struct TemplateLayoutEngineTests {
    @Test func choosesRealLayoutAndPreservesInheritance() throws {
        let source = try Presentation()
        source.documentKind = .template
        let deck = try Presentation.fromTemplate(data: source.serializedData())
        let engine = TemplateLayoutEngine(presentation: deck)
        let body = [[LayoutParagraph("A short point")]]
        let plan = try engine.plan(title: "A title", columns: body, preferredTypes: ["obj"])
        let slide = try engine.compose(plan, title: "A title", columns: body)
        #expect(slide.title?.explicitFrame == nil)
        #expect(slide.layout?.part.uri == plan.layout.part.uri)
        #expect(slide.placeholder(idx: plan.textSlots[0].index)?.textFrame?.text == "A short point")
        try deck.validateTemplateBindings()
        #expect(try Presentation(data: deck.serializedData()).documentKind == .presentation)
    }

    @Test func rejectsOverflowInsteadOfOverpaintingTemplate() throws {
        let deck = try Presentation()
        let engine = TemplateLayoutEngine(presentation: deck)
        #expect(throws: LayoutError.self) {
            _ = try engine.plan(title: "Short", columns: [[LayoutParagraph(String(repeating: "Too much text ", count: 2000))]], preferredTypes: ["obj"])
        }
        #expect(deck.slides.count == 1)
    }

    @Test func explicitMasterSelectionSurvivesSaveAndReopen() throws {
        let source = try Presentation()
        let second = try Presentation()
        second.theme.majorFont = "Georgia"
        second.theme.setAccent(1, Color("AA3300"))
        _ = try second.bulletSlide("Starter", ["Content"])
        try source.slides.importAll(from: second)
        source.documentKind = .template
        let deck = try Presentation.fromTemplate(data: source.serializedData())
        let master = try #require(deck.slideMasters.last)
        let engine = TemplateLayoutEngine(presentation: deck)
        let columns = [[LayoutParagraph("Content")]]
        let plan = try engine.plan(title: "Second master", columns: columns, preferredTypes: ["obj"], masterURI: master.part.uri.value)
        _ = try engine.compose(plan, title: "Second master", columns: columns)
        let reopened = try Presentation(data: deck.serializedData())
        #expect(try reopened.slides[0].master?.theme?.majorFont == "Georgia")
        #expect(try reopened.slides[0].master?.theme?.accent(1) == Color("AA3300"))
        #expect(reopened.slideMasters.count == 2)
        try reopened.validateTemplateBindings()
    }
    @Test func customCoverUsesBodyLevelsWithoutRewritingTheLayout() throws {
        let deck = try Presentation()
        let layout = try #require(deck.layout(type: "title"))
        let tree = try #require(layout.part.dom().firstChild(named: "p:cSld")?.firstChild(named: "p:spTree"))
        for shape in tree.children(named: "p:sp") {
            let ph = shape.firstChild(named: "p:nvSpPr")?.firstChild(named: "p:nvPr")?.firstChild(named: "p:ph")
            if ph?[attribute: "type"] == "subTitle" { tree.removeChild(shape); continue }
            guard ph?[attribute: "type"] == "ctrTitle" else { continue }
            ph?[attribute: "type"] = "body"
            ph?[attribute: "idx"] = "16"
            let text = try #require(shape.firstChild(named: "p:txBody"))
            text.removeChildren(named: "a:lstStyle")
            let styles = XML.Element("a:lstStyle")
            text.appendElement(styles)
            for (level, size) in [(1, 6000), (2, 4000)] {
                let p = XML.Element("a:lvl\(level)pPr")
                styles.appendElement(p)
                p.appendElement(XML.Element("a:defRPr", attributes: [("sz", String(size))]))
            }
        }
        let before = try layout.part.dom().serialized()
        let engine = TemplateLayoutEngine(presentation: deck, measure: { _ in 10 })
        let content = [[LayoutParagraph("Subtitle")]]
        let plan = try engine.plan(title: "Title", columns: content, preferredTypes: ["title"])
        #expect(plan.combinesTitleAndBody)
        let slide = try engine.compose(plan, title: "Title", columns: content)
        let paragraphs = try #require(slide.placeholder(idx: 16)?.textFrame?.paragraphs)
        #expect(paragraphs.map { $0.runs.map(\.text).joined() } == ["Title", "Subtitle"])
        #expect(paragraphs.map(\.indentLevel) == [0, 1])
        #expect(slide.placeholder(idx: 16)?.explicitFrame == nil)
        #expect(try layout.part.dom().serialized() == before)
    }

    @Test func subtitleDoesNotStealTheBodyRegion() throws {
        let deck = try Presentation()
        let layout = try #require(deck.layout(type: "obj"))
        let tree = try #require(layout.part.dom().firstChild(named: "p:cSld")?.firstChild(named: "p:spTree"))
        let body = try #require(tree.children(named: "p:sp").first {
            $0.firstChild(named: "p:nvSpPr")?.firstChild(named: "p:nvPr")?.firstChild(named: "p:ph")?[attribute: "idx"] == "1"
        })
        let subtitle = body.deepCopy()
        let ph = try #require(subtitle.firstChild(named: "p:nvSpPr")?.firstChild(named: "p:nvPr")?.firstChild(named: "p:ph"))
        ph[attribute: "type"] = "subTitle"; ph[attribute: "idx"] = "13"
        tree.appendElement(subtitle)
        let engine = TemplateLayoutEngine(presentation: deck, measure: { _ in 10 })
        let plan = try engine.plan(title: "Title", columns: [[LayoutParagraph("Body")]], preferredTypes: ["obj"])
        #expect(plan.layout.part.uri == layout.part.uri)
        #expect(plan.textSlots.map(\.index) == [1])
    }

}
