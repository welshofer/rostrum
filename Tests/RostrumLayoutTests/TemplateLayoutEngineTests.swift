import Foundation
import Testing
@testable import Rostrum
@testable import RostrumLayout

@Suite struct TemplateLayoutEngineTests {
    @Test func prefersFullContentAreaOverFirstNarrowVariant() throws {
        let deck = try Presentation()
        let narrow = try #require(deck.layout(type: "obj"))
        let narrowBody = try #require(ShapeCollection(part: narrow.part, package: deck.package).all.first { $0.placeholder?.idx == 1 })
        narrowBody.frame = Rect(x: .points(40), y: .points(180), width: .points(250), height: .points(180))
        let second = try Presentation()
        _ = try second.bulletSlide("Seed", ["Text"])
        try deck.slides.importAll(from: second)
        let plan = try TemplateLayoutEngine(presentation: deck).plan(title: "Evidence", columns: [], preferredTypes: ["obj"], object: "chart")
        #expect(plan.objectFrame!.width.points > 250)
        #expect(plan.layout.part.uri != narrow.part.uri)
    }

    @Test func rejectsInvertedHeadlineHierarchyWhenChoosingCover() throws {
        let deck = try Presentation()
        let layout = try #require(deck.layout(type: "title"))
        let subtitle = try #require(ShapeCollection(part: layout.part, package: deck.package).all.first { $0.placeholder?.type == "subTitle" })
        let tx = try #require(subtitle.element.firstChild(named: "p:txBody"))
        tx.getOrAddChild("a:lstStyle", beforeAnyOf: ["a:p"]).getOrAddChild("a:lvl1pPr")
            .getOrAddChild("a:defRPr")[attribute: "sz"] = "8800"
        let alternative = try Presentation()
        _ = try alternative.bulletSlide("Seed", ["Body"])
        try deck.slides.importAll(from: alternative)
        let engine = TemplateLayoutEngine(presentation: deck, measure: { _ in 10 })
        let plan = try engine.plan(title: "Headline", columns: [[LayoutParagraph("Supporting line")]], preferredTypes: ["title", "obj"])
        #expect(plan.layout.part.uri != layout.part.uri)
    }

    @Test func sectionHeadingRespectsLargerInheritedBodySize() throws {
        let deck = try Presentation()
        let layout = try #require(deck.layout(type: "obj"))
        let body = try #require(ShapeCollection(part: layout.part, package: deck.package).all.first { $0.placeholder?.idx == 1 })
        let tx = try #require(body.element.firstChild(named: "p:txBody"))
        tx.getOrAddChild("a:lstStyle", beforeAnyOf: ["a:p"]).getOrAddChild("a:lvl1pPr")
            .getOrAddChild("a:defRPr")[attribute: "sz"] = "3200"
        let engine = TemplateLayoutEngine(presentation: deck, measure: { _ in 10 })
        let content = [[LayoutParagraph("Section", role: .heading), LayoutParagraph("Supporting point")]]
        let plan = try engine.plan(title: "Headline", columns: content, preferredTypes: ["obj"], layoutURI: layout.part.uri.value)
        let slide = try engine.compose(plan, title: "Headline", columns: content)
        let paragraphs = try #require(slide.placeholder(idx: 1)?.textFrame?.paragraphs)
        #expect((paragraphs[0].runs.first?.fontSize ?? 0) > 32)
        #expect(paragraphs[1].runs.first?.fontSize == nil)
    }

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

    private func flowFixture(autofit: Bool = false, clipped: Bool = false) throws -> (Presentation, SlideLayout) {
        let deck = try Presentation()
        let layout = try #require(deck.layout(type: "obj"))
        let shapes = ShapeCollection(part: layout.part, package: deck.package)
        let title = try #require(shapes.all.first { $0.placeholder?.type == "title" })
        title.frame = Rect(x: .points(40), y: .points(30), width: .points(300), height: .points(autofit ? 50 : 30))
        title.textFrame?.setMargins(left: .zero, top: .zero, right: .zero, bottom: .zero)
        let tx = try #require(title.element.firstChild(named: "p:txBody"))
        let body = try #require(tx.firstChild(named: "a:bodyPr"))
        for name in ["a:noAutofit", "a:normAutofit", "a:spAutoFit"] { body.removeChildren(named: name) }
        body.appendElement(XML.Element(autofit ? "a:normAutofit" : "a:noAutofit"))
        if clipped { body[attribute: "vertOverflow"] = "clip" }
        let list = tx.getOrAddChild("a:lstStyle", beforeAnyOf: ["a:p"])
        let defaults = list.getOrAddChild("a:lvl1pPr").getOrAddChild("a:defRPr")
        defaults[attribute: "sz"] = "2400"
        let content = try #require(shapes.all.first { $0.placeholder?.idx == 1 })
        content.frame = Rect(x: .points(40), y: .points(180), width: .points(640), height: .points(280))
        return (deck, layout)
    }

    @Test func wrappedTitleFlowsIntoSafeSpaceAndPreservesTemplate() throws {
        let (deck, layout) = try flowFixture()
        let before = try layout.part.dom().serialized()
        let engine = TemplateLayoutEngine(presentation: deck, measure: { $0.text == "Body" ? 20 : 72 })
        let title = "Human-caused warming is clear; future harm is not fixed"
        let columns = [[LayoutParagraph("Body")]]
        let plan = try engine.plan(title: title, columns: columns, preferredTypes: ["obj"])
        #expect(plan.layout.part.uri == layout.part.uri)
        let slide = try engine.compose(plan, title: title, columns: columns)
        #expect(slide.title?.frame.height == .points(72))
        #expect(slide.title?.textFrame?.text == title)
        #expect(try layout.part.dom().serialized() == before)
        let reopened = try Presentation(data: deck.serializedData())
        let saved = try reopened.slides[reopened.slides.count - 1]
        #expect(saved.title?.frame.height == .points(72))
        #expect(saved.title?.textFrame?.paragraphs.first?.runs.first?.fontSize == nil)
        #expect(try reopened.validate().isEmpty)
    }

    @Test func nativeAutoFitShrinksWithoutFlatteningInheritedFonts() throws {
        let (deck, layout) = try flowFixture(autofit: true)
        let engine = TemplateLayoutEngine(presentation: deck, measure: { $0.text == "Body" ? 10 : $0.size * 2.5 })
        let columns = [[LayoutParagraph("Body")]]
        let plan = try engine.plan(title: "Wrapped title", columns: columns, preferredTypes: ["obj"], layoutURI: layout.part.uri.value)
        let fit = try #require(plan.textFits[0])
        #expect(fit.fontScale < 1 && fit.fontScale >= 0.75)
        let slide = try engine.compose(plan, title: "Wrapped title", columns: columns)
        #expect(slide.title?.explicitFrame == nil)
        let scale = slide.title?.element.firstChild(named: "p:txBody")?.firstChild(named: "a:bodyPr")?.firstChild(named: "a:normAutofit")?[attribute: "fontScale"]
        #expect(scale != nil)
        #expect(slide.title?.textFrame?.paragraphs.first?.runs.first?.fontSize == nil)
        #expect(plan.layout.part.uri == layout.part.uri)
        #expect(try Presentation(data: deck.serializedData()).validate().isEmpty)
    }

    @Test func narrowTitleCanUseFullWidthContentSpanWithoutEditingLayout() throws {
        let (deck, layout) = try flowFixture()
        let content = try #require(ShapeCollection(part: layout.part, package: deck.package).all.first { $0.placeholder?.idx == 1 })
        content.frame = Rect(x: .points(40), y: .points(70), width: .points(640), height: .points(280))
        let before = try layout.part.dom().serialized()
        let engine = TemplateLayoutEngine(presentation: deck, measure: {
            $0.text == "Body" ? 20 : ($0.width < 500 ? 72 : 24)
        })
        let columns = [[LayoutParagraph("Body")]]
        let plan = try engine.plan(title: "A long title", columns: columns, preferredTypes: ["obj"])
        #expect(plan.layout.part.uri == layout.part.uri)
        let slide = try engine.compose(plan, title: "A long title", columns: columns)
        #expect(slide.title?.frame.width == .points(640))
        #expect(slide.title!.frame.maxY < content.frame.y)
        #expect(try layout.part.dom().serialized() == before)
    }

    @Test func textFlowCannotCrossContentOrExplicitClipping() throws {
        let (deck, layout) = try flowFixture()
        let slot = try #require(layout.placeholders.first { $0.isTitle })
        let blocked = TemplateLayoutEngine(presentation: deck, measure: { _ in 200 })
        #expect(!blocked.fits([LayoutParagraph("Too tall")], in: try #require(slot.frame), layout: layout, slot: slot.index))
        let (clippedDeck, clippedLayout) = try flowFixture(clipped: true)
        let clipped = TemplateLayoutEngine(presentation: clippedDeck, measure: { _ in 72 })
        #expect(!clipped.fits([LayoutParagraph("Clipped")], in: try #require(slot.frame), layout: clippedLayout, slot: slot.index))
    }

}

@Suite struct CompositionSelectionTests {
    @Test func measurementCacheIsBoundedToAnEngineAndDoesNotChangeChoice() throws {
        let deck = try Presentation()
        var calls = 0
        let engine = TemplateLayoutEngine(presentation: deck, measure: { _ in calls += 1; return 20 })
        let columns = [[LayoutParagraph("An evidence statement")]]
        let first = try engine.plan(title: "A title", columns: columns, preferredTypes: ["obj"])
        let initial = calls
        let second = try engine.plan(title: "A title", columns: columns, preferredTypes: ["obj"])
        #expect(first.layout.part.uri == second.layout.part.uri)
        #expect(calls == initial)
        #expect(engine.measurementCacheHits > 0)
        #expect(!second.score.reasons.isEmpty)
    }
    @Test func structuredFramesAreBoundedAndKeepAllItems() throws {
        let region = Rect(x: .points(40), y: .points(100), width: .points(640), height: .points(300))
        for kind in [StructuredKind.metrics, .timeline, .quadrant, .pyramid, .cycle, .bands] {
            let frames = try StructuredLayout.frames(kind: kind, count: 4, in: region)
            #expect(frames.count == 4)
            #expect(frames.allSatisfy { $0.x >= region.x && $0.y >= region.y && $0.maxX <= region.maxX && $0.maxY <= region.maxY })
        }
    }
}
