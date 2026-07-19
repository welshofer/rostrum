import Foundation
import Observation
import LecternCore

// The app's single source of truth (@Observable, no ViewModel types — views
// observe this directly). Wired to the tested LecternCore pipeline; the default
// provider is MockProvider so the app runs end-to-end with no key (M2). Swap in
// AnthropicProvider (+ Keychain) for live runs.
//
// NOTE: this App/ tree is the Xcode app target — it is NOT built by `swift test`
// (which builds LecternCore only). Liquid Glass styling (§3), Settings/Keychain,
// History (SwiftData), and the PDF ladder are the remaining M3–M5 work.

@MainActor
@Observable
final class AppState {
    enum Phase: Equatable {
        case compose
        case generating
        case result(DeckResult)
        case failed(String)
    }

    var phase: Phase = .compose

    // Compose form.
    var prompt = ""
    var audience = "General"
    var goal = "inform"
    var slideCount = 12
    var includeNotes = true

    // Style catalog (bundled design.md files).
    var styles: [Style] = []
    var selectedStyleSlug: String?
    var selectedStyle: Style? { styles.first { $0.slug == selectedStyleSlug } }

    /// Load the bundled style catalog off the main thread (invariant I6).
    func loadStyles() async {
        guard styles.isEmpty, let dir = Bundle.main.resourceURL?.appendingPathComponent("Styles") else { return }
        let loaded = await Task.detached { (try? StyleCatalog().load(from: dir)) ?? [] }.value
        styles = loaded
        if selectedStyleSlug == nil { selectedStyleSlug = loaded.first?.slug }
    }

    // Generating progress.
    var stage = ""
    var drafted = 0
    var total = 0

    private var task: Task<Void, Never>?

    var canGenerate: Bool {
        phase != .generating && !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func generate() {
        guard canGenerate else { return }
        phase = .generating; stage = "Starting"; drafted = 0; total = slideCount

        let request = DeckRequest(prompt: prompt, audience: audience, goal: goal,
                                  slideCount: slideCount, notes: includeNotes,
                                  styleSlug: selectedStyleSlug ?? "default")
        // Mock-first: a valid deck the requested size, no network. Replace with a
        // live provider once a key is validated in Settings.
        let provider = MockProvider(validJSON: Self.sampleDeckJSON(title: prompt, count: slideCount))
        let directory = Self.decksDirectory()
        let designURL = selectedStyle?.designURL           // renders with the chosen brand

        task = Task {
            do {
                let result = try await DeckGenerator(provider: provider)
                    .generate(request, designURL: designURL, into: directory) { [weak self] event in
                        Task { @MainActor in self?.apply(event) }
                    }
                self.phase = .result(result)
            } catch is CancellationError {
                self.phase = .compose
            } catch {
                self.phase = .failed(Self.describe(error))
            }
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        phase = .compose
    }

    func reset() {
        prompt = ""; stage = ""; drafted = 0; total = 0; phase = .compose
    }

    private func apply(_ event: GenerationEvent) {
        switch event {
        case .preparingSource: stage = "Reading source"
        case .outlining: stage = "Outlining"
        case .outlineReady: stage = "Outline ready"
        case .drafting(let completed, let total): stage = "Writing slides"; drafted = completed; self.total = total
        case .validating: stage = "Validating"
        case .repairing: stage = "Repairing"
        case .rendering: stage = "Rendering .pptx"
        case .finished: stage = "Done"
        }
    }

    private static func describe(_ error: Error) -> String {
        guard let lectern = error as? LecternError else { return "\(error)" }
        switch lectern {
        case .noKey: return "Add an API key to begin."
        case .authFailed(let provider): return "That key was rejected by \(provider)."
        case .rateLimited(let s): return "Rate-limited. Try again in \(s)s."
        case .requestTooLarge: return "That PDF is too large for this model."
        case .networkOffline: return "No connection."
        case .schemaInvalid: return "The model returned a deck Lectern couldn't parse."
        case .providerError(_, let message): return message
        case .renderFailed(let message): return "Couldn't write the deck: \(message)"
        case .cancelled: return "Cancelled."
        }
    }

    static func decksDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("Lectern/Decks", isDirectory: true)
    }

    /// A valid `lectern.deck/1` of `count` slides — the Mock's fixture.
    static func sampleDeckJSON(title: String, count: Int) -> String {
        let cleanTitle = title.isEmpty ? "Untitled Deck" : String(title.prefix(80))
        var slides: [IRSlide] = [
            IRSlide(id: "sl1", layout: "title", title: cleanTitle,
                    body: Body(subtitle: "Generated by Lectern"), notes: "Open with the framing."),
        ]
        let contentCount = max(1, count - 2)
        for i in 0..<contentCount {
            slides.append(IRSlide(id: "sl\(i + 2)", layout: "bullets", title: "Point \(i + 1)",
                                  body: Body(bullets: [Bullet(text: "First idea"), Bullet(text: "Second idea")]),
                                  notes: "Talk to point \(i + 1)."))
        }
        slides.append(IRSlide(id: "sl\(count)", layout: "closing", title: "Thank you",
                              body: Body(callToAction: "Questions?"), notes: "Invite discussion."))
        let deck = DeckIR(meta: Meta(title: cleanTitle), slides: slides)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(deck)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
    }
}
