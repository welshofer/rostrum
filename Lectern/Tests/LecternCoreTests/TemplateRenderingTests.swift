import Foundation
import Testing
import Rostrum
@testable import LecternCore

@Suite struct TemplateRenderingTests {
    private func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func templateSurvivesEndToEndAndDoesNotReceiveThemeOverrides() async throws {
        let source = try Presentation()
        source.theme.majorFont = "Georgia"
        source.theme.setAccent(1, Color("006699"))
        source.documentKind = .template
        let template = try PowerPointTemplate(data: source.serializedData(), name: "Corporate")
        let dir = try directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let input = DeckIR(meta: Meta(title: "Template acceptance"), slides: [
            IRSlide(id: "title", layout: "title", title: "Template acceptance", body: Body(subtitle: "Native inheritance")),
            IRSlide(id: "body", layout: "bullets", title: "Preserved design", body: Body(bullets: [Bullet(text: "A concise point")]))
        ])
        let result = try await DeckRenderer().render(input, designURL: URL(fileURLWithPath: "/does-not-exist.md"), notesEnabled: false, into: dir, template: template)
        let deck = try Presentation(contentsOf: result.url)
        #expect(deck.documentKind == .presentation)
        #expect(deck.slides.count == 2)
        #expect(deck.theme.majorFont == "Georgia")
        #expect(deck.theme.accent(1) == Color("006699"))
        #expect(deck.allLayouts.count == source.allLayouts.count)
        #expect(try deck.slides[1].title?.explicitFrame == nil)
        #expect(try deck.slides[1].shapes.all.count == 2)
        try deck.validateTemplateBindings()
        #expect(result.schemaIssues.isEmpty)
    }

    @Test func themedDeckPublishesLayoutsAndNativeObjects() async throws {
        let dir = try directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let input = DeckIR(meta: Meta(title: "Own theme"), slides: [
            IRSlide(id: "title", layout: "title", title: "Own theme"),
            IRSlide(id: "body", layout: "bullets", title: "Useful content", body: Body(bullets: [Bullet(text: "One point")]))
        ])
        let result = try await DeckRenderer().render(input, designURL: nil, notesEnabled: false, into: dir)
        let deck = try Presentation(contentsOf: result.url)
        for slide in deck.slides {
            #expect(slide.layout?.name.hasPrefix("Lectern —") == true)
            #expect(slide.title?.explicitFrame == nil)
            #expect(slide.master?.name == "Lectern Theme")
        }
        try deck.validateTemplateBindings()
        #expect(result.schemaIssues.isEmpty)
    }
}
