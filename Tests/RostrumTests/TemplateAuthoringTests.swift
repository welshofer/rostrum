import Foundation
import Testing
@testable import Rostrum

@Suite struct TemplateAuthoringTests {
    @Test func instantiationKeepsMasterLayoutAndThemeBytes() throws {
        let template = try Presentation()
        template.documentKind = .template
        _ = try template.bulletSlide("Starter content to remove", ["Private example"])
        let bytes = try template.serializedData()
        let deck = try Presentation.fromTemplate(data: bytes)
        #expect(deck.slides.count == 0)
        #expect(deck.documentKind == .presentation)
        let before = try ZipReader(data: bytes)
        let after = try ZipReader(data: deck.serializedData())
        for name in before.entryNames where name.hasPrefix("ppt/slideMasters/") || name.hasPrefix("ppt/slideLayouts/") || name.hasPrefix("ppt/theme/") {
            #expect(try before.data(forEntry: name) == after.data(forEntry: name), "Changed \(name)")
        }
        #expect(try Presentation(data: bytes).slides.count == 2)
    }

    @Test func publishedLayoutHasNoSlideTextAndGeometryReallyInherits() throws {
        let deck = try Presentation()
        try deck.compileThemeMaster()
        let slide = try deck.bulletSlide("Specific confidential title", ["Specific confidential content"])
        let titleFrame = try #require(slide.title?.frame)
        let layout = try deck.publishLayout(of: slide, named: "Content")
        #expect(!(try layout.part.dom()).serialized().contains("confidential"))
        #expect(slide.title?.explicitFrame == nil)
        #expect(slide.effectiveFrame(of: try #require(slide.title)) == titleFrame)
        let newSlide = try deck.slides.add(clonedFrom: layout)
        #expect(newSlide.placeholders.count == 2)
        try newSlide.fillPlaceholder(index: 0, paragraphs: [("New title", 0)])
        let reopened = try Presentation(data: deck.serializedData())
        try reopened.validateTemplateBindings()
        #expect(try reopened.slides[2].title?.textFrame?.text == "New title")
        #expect(try reopened.validate().isEmpty)
        let ids = try layout.part.dom().firstChild(named: "p:cSld")?.firstChild(named: "p:spTree")?.childElements.compactMap {
            $0.childElements.first?.firstChild(named: "p:cNvPr")?[attribute: "id"]
        } ?? []
        #expect(ids.count == Set(ids).count)
    }

    @Test func placeholderOnChartRetainsBinding() throws {
        let deck = try Presentation()
        let layout = try #require(deck.layout(type: "obj"))
        let slide = try deck.slides.add(clonedFrom: layout)
        let slot = try #require(slide.placeholder(idx: 1))
        let chart = try slide.shapes.addChart(.barClustered, data: ChartData(categories: ["A"], series: [.init(name: "Values", values: [2])]), frame: try #require(slide.effectiveFrame(of: slot)))
        try slide.replacePlaceholder(index: 1, with: chart)
        #expect(slide.placeholder(idx: 1)?.kind == .chart)
        #expect(slide.placeholders.count == 2)
    }

    @Test func instantiationRejectsPresentationMasqueradingAsTemplate() throws {
        #expect(throws: RostrumError.self) { _ = try Presentation.fromTemplate(data: Presentation().serializedData()) }
    }
}
