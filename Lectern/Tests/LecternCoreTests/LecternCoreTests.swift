import Foundation
import Testing
import Rostrum
@testable import LecternCore

@Suite struct LecternCoreTests {
    private func fixtureJSON() throws -> String {
        let url = try #require(Bundle.module.url(forResource: "deck-mock", withExtension: "json", subdirectory: "Fixtures"))
        return try String(contentsOf: url, encoding: .utf8)
    }
    private func fixtureDeck() throws -> DeckIR {
        try JSONDecoder().decode(DeckIR.self, from: Data(fixtureJSON().utf8))
    }
    private func tempDir() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("lectern-test-\(ProcessInfo.processInfo.globallyUniqueString)")
    }

    // MARK: - IR + validation

    @Test func decodesTheExampleIR() throws {
        let deck = try fixtureDeck()
        #expect(deck.irVersion == DeckIR.currentVersion)
        #expect(deck.slides.count == 5)
        #expect(deck.slides.first?.kind == .title)
        #expect(deck.slides.last?.kind == .closing)
        #expect(deck.slides[3].body?.value == "0")
    }

    @Test func validatesACleanDeck() throws {
        let result = try DeckValidator().validate(fixtureDeck(), requestedSlideCount: 5, notesRequired: true)
        #expect(result.warnings.isEmpty)
    }

    @Test func rejectsStructuralViolations() throws {
        var deck = try fixtureDeck()
        deck.slides[1].id = "sl1"                 // duplicate id
        #expect(throws: ValidationError.self) {
            _ = try DeckValidator().validate(deck)
        }
    }

    @Test func downgradesUnknownLayoutWithBulletsBody() throws {
        var deck = try fixtureDeck()
        deck.slides[1].layout = "timeline"        // unknown, but has a bullets body
        let result = try DeckValidator().validate(deck)
        #expect(result.deck.slides[1].layout == "bullets")
        #expect(result.warnings.contains { $0.contains("downgraded to bullets") })
    }

    @Test func failsUnknownLayoutWithoutBulletsBody() throws {
        var deck = try fixtureDeck()
        deck.slides[3].layout = "hologram"        // unknown, bigNumber body (no bullets)
        #expect(throws: ValidationError.self) { _ = try DeckValidator().validate(deck) }
    }

    // MARK: - Rendering (the Rostrum loop)

    @Test func rendersAValidPptxFromIR() async throws {
        let result = try DeckValidator().validate(fixtureDeck(), notesRequired: true)
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let deckResult = try await DeckRenderer().render(result.deck, designURL: nil, notesEnabled: true,
                                                         into: dir, warnings: result.warnings)
        #expect(deckResult.slideCount == 5)                       // AT-11 (exact against fixture)
        // Opens as a real presentation with the expected structure (AT-10 core).
        let reopened = try Presentation(contentsOf: deckResult.url)
        #expect(reopened.slides.count == 5)
        #expect(try reopened.validate().isEmpty)
        #expect(reopened.sections.count == 2)                    // sections flow through
    }

    @Test func notesToggleControlsNotesParts() async throws {
        let result = try DeckValidator().validate(fixtureDeck())
        let onDir = tempDir(), offDir = tempDir()
        defer { try? FileManager.default.removeItem(at: onDir); try? FileManager.default.removeItem(at: offDir) }
        let on = try await DeckRenderer().render(result.deck, designURL: nil, notesEnabled: true, into: onDir)
        let off = try await DeckRenderer().render(result.deck, designURL: nil, notesEnabled: false, into: offDir)
        func notesParts(_ url: URL) throws -> Int {
            try Presentation(contentsOf: url).package.parts.keys.filter { $0.value.hasPrefix("/ppt/notesSlides/") }.count
        }
        #expect(try notesParts(on.url) > 0)                       // AT-12
        #expect(try notesParts(off.url) == 0)
    }

    // MARK: - Pipeline (Mock provider end-to-end)

    @Test func mockPipelineHappyPath() async throws {
        let provider = MockProvider(validJSON: try fixtureJSON())
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let events = EventBox()
        let request = DeckRequest(prompt: "why native rendering", slideCount: 5, notes: true)
        let result = try await DeckGenerator(provider: provider).generate(request, designURL: nil, into: dir) { events.record($0) }
        #expect(result.slideCount == 5)
        let stages = events.stages
        #expect(stages.contains("outlining") && stages.contains("rendering") && stages.contains("finished"))  // AT-09
        #expect(FileManager.default.fileExists(atPath: result.url.path))
    }

    @Test func repairLoopRecoversOnceThenFails() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        // invalidJSONOnce → exactly one repair → success (AT-14).
        let once = MockProvider(validJSON: try fixtureJSON(), failure: .invalidJSONOnce)
        let events = EventBox()
        let result = try await DeckGenerator(provider: once).generate(DeckRequest(prompt: "x", slideCount: 5), designURL: nil, into: dir) { events.record($0) }
        #expect(result.slideCount == 5)
        #expect(events.stages.contains("repairing"))

        // invalidJSONAlways → .schemaInvalid.
        let always = MockProvider(validJSON: try fixtureJSON(), failure: .invalidJSONAlways)
        await #expect(throws: LecternError.self) {
            _ = try await DeckGenerator(provider: always).generate(DeckRequest(prompt: "x"), designURL: nil, into: dir) { _ in }
        }
    }

    // MARK: - Style catalog

    @Test func loadsStylesFromADirectory() throws {
        let root = tempDir(); defer { try? FileManager.default.removeItem(at: root) }
        let fm = FileManager.default
        for slug in ["sunflower", "midnight"] {
            let dir = root.appendingPathComponent(slug)
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            try "## Palette\n- Accent 1: #18A999".write(to: dir.appendingPathComponent("design.md"), atomically: true, encoding: .utf8)
        }
        let styles = try StyleCatalog().load(from: root)
        #expect(styles.count == 2)
        #expect(styles.map(\.slug).sorted() == ["midnight", "sunflower"])
        #expect(styles.first(where: { $0.slug == "sunflower" })?.name == "Sunflower")   // title-cased slug
    }

    @Test func promptTemplatesReflectGoalNotesAndLength() {
        let persuade = PromptTemplates.system(for: DeckRequest(prompt: "x", goal: "persuade"))
        #expect(persuade.contains("call to action"))
        #expect(persuade.contains(DeckIR.currentVersion))
        let noNotes = PromptTemplates.deck(for: DeckRequest(prompt: "x", slideCount: 8, notes: false))
        #expect(noNotes.contains("exactly 8 slides"))
        #expect(noNotes.contains("Omit the"))
        let grounded = PromptTemplates.deck(for: DeckRequest(prompt: "x", groundingText: "FACTS HERE"))
        #expect(grounded.contains("SOURCE MATERIAL") && grounded.contains("FACTS HERE"))
    }

    @Test func anthropicProviderWithoutKeyThrowsNoKey() async throws {
        let provider = AnthropicProvider(apiKey: "")
        await #expect(throws: LecternError.self) {
            _ = try await provider.draft(DeckRequest(prompt: "x"), repairing: nil) { _ in }
        }
    }

    // MARK: - Provider selection (no keychain, no network)

    @Test func factoryFallsBackToMockWithoutAKey() throws {
        let mockJSON = try fixtureJSON()
        for key in [nil, "", "   ", "\n"] as [String?] {
            let provider = ProviderFactory.make(id: .anthropic, apiKey: key, model: "claude-sonnet-5", mockJSON: mockJSON)
            #expect(provider.id == .custom)                       // MockProvider.id
            #expect(provider.displayName == "Mock")
            #expect(!ProviderFactory.isLive(id: .anthropic, apiKey: key))
        }
    }

    @Test func factoryPicksAnthropicWithAKey() throws {
        let provider = ProviderFactory.make(id: .anthropic, apiKey: "sk-ant-xyz", model: "claude-opus-4-8", mockJSON: try fixtureJSON())
        #expect(provider.id == .anthropic)
        #expect(provider.displayName == "Anthropic")
        #expect(ProviderFactory.isLive(id: .anthropic, apiKey: "sk-ant-xyz"))
    }

    @Test func factoryStaysOnMockForUnwiredProvidersEvenWithAKey() throws {
        // OpenAI/Gemini/Custom aren't wired live yet — don't pretend they are.
        for id in [ProviderID.openAI, .gemini, .custom] {
            let provider = ProviderFactory.make(id: id, apiKey: "some-key", model: "m", mockJSON: try fixtureJSON())
            #expect(provider.displayName == "Mock")
            #expect(!ProviderFactory.isLive(id: id, apiKey: "some-key"))
        }
    }

}

/// Thread-safe event recorder for the async pipeline.
private final class EventBox: @unchecked Sendable {
    private let lock = NSLock()
    private var events: [String] = []
    func record(_ e: GenerationEvent) {
        lock.lock(); defer { lock.unlock() }
        switch e {
        case .preparingSource: events.append("preparingSource")
        case .outlining: events.append("outlining")
        case .outlineReady: events.append("outlineReady")
        case .drafting: events.append("drafting")
        case .validating: events.append("validating")
        case .repairing: events.append("repairing")
        case .rendering: events.append("rendering")
        case .finished: events.append("finished")
        }
    }
    var stages: Set<String> { lock.lock(); defer { lock.unlock() }; return Set(events) }
}
