import Foundation
import Testing
import Rostrum
@testable import LecternCore

/// End to end: a deck rendered the way the app renders one must have titles
/// PowerPoint can see.
///
/// Every Lectern-made deck in a real library came back `titled=0/N`, every
/// slide on the Blank layout — the deck looked right and had no titles at all
/// in the outline view, the slide navigator, or to a screen reader, because the
/// builders drew the title as a plain text box.
@Suite struct RenderedDeckTitlesTests {
    @Test func aRenderedDeckHasRealTitlesOnEverySlide() async throws {
        let deck = DeckIR(meta: Meta(title: "Quarterly Review"), slides: [
            IRSlide(id: "s1", layout: "title", title: "Quarterly Review",
                    body: Body(subtitle: "Northwind")),
            IRSlide(id: "s2", layout: "bullets", title: "Highlights",
                    body: Body(bullets: [Bullet(text: "ARR up"), Bullet(text: "NPS up")])),
            IRSlide(id: "s3", layout: "bullets", title: "What to do now",
                    body: Body(bullets: [Bullet(text: "Ship one narrow agent")])),
        ])
        let validated = try DeckValidator().validate(deck, notesRequired: false)
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("titles-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let result = try await DeckRenderer().render(validated.deck, designURL: nil,
                                                     notesEnabled: false, into: dir)
        let written = try Presentation(contentsOf: result.url)

        // What the outline — and so PowerPoint, and our own inspector — sees.
        let titles: [String?] = written.outline().slides.map { $0.title }
        #expect(!titles.contains { $0 == nil || $0!.isEmpty },
                "untitled slides: \(titles.map { $0 ?? "nil" })")

        // Real placeholders, not text boxes that merely look like titles.
        for index in 0..<written.slides.count {
            let slide = try written.slides.slide(at: index)
            #expect(slide.title != nil, "slide \(index + 1) has no title placeholder")
            #expect(slide.layout?.name != "Blank", "slide \(index + 1) is still on Blank")
        }
    }
}
