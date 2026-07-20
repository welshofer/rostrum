import Foundation
import Observation
import LecternCore

// The app's single source of truth (@Observable — views observe it directly, no
// ViewModels). Wired to the tested LecternCore pipeline. There is NO mock
// provider: generation requires a real key (invariant I1: key lives only in the
// Keychain). Runs off-main for catalog, PDF, network, and rendering (I6).
@MainActor
@Observable
final class AppState {
    enum Phase: Equatable {
        case compose, generating
        case result(DeckResult)
        case failed(String)
    }
    var phase: Phase = .compose

    // MARK: Compose form
    var prompt = ""
    var audience = "General"
    var goal = "inform"
    var slideCount = 12
    var includeNotes = true

    /// Render diagrams (process/cycle/layers) as native PowerPoint SmartArt when
    /// on; as styled shapes when off. Default off — SmartArt is opt-in.
    private(set) var useSmartArt = false

    // MARK: Provider + model (non-secret prefs persisted; key stays in Keychain)
    private(set) var providerID: ProviderID = .anthropic
    var model = "claude-sonnet-5"
    private(set) var hasKey = false

    enum KeyStatus: Equatable { case unknown, validating, valid(Int), invalid(String) }
    private(set) var keyStatus: KeyStatus = .unknown

    /// A curated, clean model list — NOT the provider's raw /v1/models dump
    /// (which is full of point-releases and internal EAP builds). Validate only
    /// confirms the key; it never rewrites this list.
    static func defaultModels(for id: ProviderID) -> [String] {
        switch id {
        case .anthropic: return ["claude-opus-4-8", "claude-sonnet-5", "claude-fable-5", "claude-haiku-4-5-20251001"]
        default: return []
        }
    }
    var modelOptions: [String] { Self.defaultModels(for: providerID) }

    // MARK: Optional image provider (§image grounding)
    private(set) var imageProviderID: ImageProviderID = .gemini
    private(set) var hasImageKey = false

    // MARK: Style catalog
    var styles: [Style] = []
    var selectedStyleSlug: String?
    var favorites: Set<String> = []
    private(set) var recents: [String] = []
    var selectedStyle: Style? { styles.first { $0.slug == selectedStyleSlug } }

    // MARK: PDF grounding (§7.4)
    private(set) var grounding: PDFGrounding.Source?
    private(set) var groundingLoading = false
    private(set) var groundingError: String?

    // MARK: Generating progress
    var stage = ""
    var drafted = 0
    var total = 0
    var progressNoun = "slides"          // "slides" while drafting, "images" while illustrating
    private var task: Task<Void, Never>?

    private enum Keys {
        static let provider = "providerID", model = "model", favorites = "favoriteStyles"
        static let recents = "recentStyles", imageProvider = "imageProviderID"
        static let useSmartArt = "useSmartArt"
    }

    init() {
        let d = UserDefaults.standard
        if let raw = d.string(forKey: Keys.provider), let id = ProviderID(rawValue: raw) { providerID = id }
        if let m = d.string(forKey: Keys.model), Self.defaultModels(for: providerID).contains(m) { model = m }
        if let raw = d.string(forKey: Keys.imageProvider), let id = ImageProviderID(rawValue: raw) { imageProviderID = id }
        favorites = Set(d.stringArray(forKey: Keys.favorites) ?? [])
        recents = d.stringArray(forKey: Keys.recents) ?? []
        useSmartArt = d.bool(forKey: Keys.useSmartArt)
        hasKey = KeychainStore.hasKey(for: providerID)
        hasImageKey = KeychainStore.hasKey(forImage: imageProviderID)
    }

    // MARK: - Styles

    func loadStyles() async {
        guard styles.isEmpty, let dir = Bundle.main.resourceURL?.appendingPathComponent("Styles") else { return }
        let loaded = await Task.detached { (try? StyleCatalog().load(from: dir)) ?? [] }.value
        styles = loaded
        if selectedStyleSlug == nil { selectedStyleSlug = recents.first ?? loaded.first?.slug }
    }

    func selectStyle(_ slug: String) {
        selectedStyleSlug = slug
        recents.removeAll { $0 == slug }
        recents.insert(slug, at: 0)
        recents = Array(recents.prefix(8))
        UserDefaults.standard.set(recents, forKey: Keys.recents)
    }

    func isFavorite(_ slug: String) -> Bool { favorites.contains(slug) }

    func toggleFavorite(_ slug: String) {
        if favorites.contains(slug) { favorites.remove(slug) } else { favorites.insert(slug) }
        UserDefaults.standard.set(Array(favorites), forKey: Keys.favorites)
    }

    // MARK: - Provider / key

    func selectProvider(_ id: ProviderID) {
        providerID = id
        keyStatus = .unknown
        if !Self.defaultModels(for: id).contains(model) { model = Self.defaultModels(for: id).first ?? model }
        UserDefaults.standard.set(id.rawValue, forKey: Keys.provider)
        hasKey = KeychainStore.hasKey(for: id)
    }

    func setModel(_ value: String) {
        model = value
        UserDefaults.standard.set(value, forKey: Keys.model)
    }

    func setUseSmartArt(_ value: Bool) {
        useSmartArt = value
        UserDefaults.standard.set(value, forKey: Keys.useSmartArt)
    }

    func saveKey(_ key: String) {
        let ok = KeychainStore.save(key, for: providerID)
        hasKey = KeychainStore.hasKey(for: providerID)
        keyStatus = ok && hasKey ? .unknown : .invalid("Couldn't write to the Keychain.")
    }

    func clearKey() {
        KeychainStore.delete(for: providerID)
        hasKey = false; keyStatus = .unknown
    }

    // MARK: - Image provider (optional)

    func selectImageProvider(_ id: ImageProviderID) {
        imageProviderID = id
        UserDefaults.standard.set(id.rawValue, forKey: Keys.imageProvider)
        hasImageKey = KeychainStore.hasKey(forImage: id)
    }

    func saveImageKey(_ key: String) {
        KeychainStore.save(key, forImage: imageProviderID)
        hasImageKey = KeychainStore.hasKey(forImage: imageProviderID)
    }

    func clearImageKey() {
        KeychainStore.delete(forImage: imageProviderID)
        hasImageKey = false
    }

    /// Validate the stored key by pinging the provider's models endpoint (§294).
    /// This ONLY confirms the key works — it never touches the curated model list
    /// or the current selection.
    func validateKey() async {
        guard let key = KeychainStore.read(for: providerID) else { keyStatus = .invalid("No key stored."); return }
        keyStatus = .validating
        do {
            let models = try await AnthropicModels.list(apiKey: key)
            keyStatus = .valid(models.count)
        } catch {
            keyStatus = .invalid(Self.describe(error))
        }
    }

    // MARK: - PDF grounding

    func attachPDF(_ url: URL) async {
        groundingLoading = true; groundingError = nil
        let needsScope = url.startAccessingSecurityScopedResource()
        defer { if needsScope { url.stopAccessingSecurityScopedResource() } }
        if let source = await PDFGrounding.extract(from: url) {
            grounding = source
        } else {
            groundingError = "No selectable text in that PDF (scans need OCR)."
        }
        groundingLoading = false
    }

    func clearPDF() { grounding = nil; groundingError = nil }

    // MARK: - Generate

    var canGenerate: Bool {
        phase != .generating && hasKey && !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Where Settings lives on this platform, for user-facing hints.
    #if os(macOS)
    static let settingsHint = "Settings (⌘,)"
    #else
    static let settingsHint = "Settings"
    #endif

    func generate() {
        guard phase != .generating else { return }
        guard hasKey else { phase = .failed("Add your \(providerID.label) API key in \(Self.settingsHint) to generate."); return }

        phase = .generating; stage = "Starting"; drafted = 0; total = slideCount
        let request = DeckRequest(prompt: prompt, audience: audience, goal: goal,
                                  slideCount: slideCount, notes: includeNotes,
                                  groundingText: grounding?.text,
                                  styleSlug: selectedStyleSlug ?? "default")
        let designURL = selectedStyle?.designURL
        let directory = Self.decksDirectory()
        let key = KeychainStore.read(for: providerID)
        let id = providerID, chosenModel = model
        let style = selectedStyle
        let smartArt = useSmartArt
        let imageID = imageProviderID
        let imageKey = KeychainStore.read(forImage: imageProviderID)

        task = Task {
            do {
                let provider = try ProviderFactory.make(id: id, apiKey: key, model: chosenModel)
                // Optional imagery: only when an image key exists. Art direction
                // comes from the chosen style's design.md so images stay on-brand.
                var imageProvider: (any ImageProvider)?
                var imageStyle: String?
                if let imageKey, let provider = try? ImageProviderFactory.make(id: imageID, apiKey: imageKey) {
                    imageProvider = provider
                    if let style {
                        let text = try? String(contentsOf: style.designURL, encoding: .utf8)
                        imageStyle = ImageStyleDirective.from(style: style, designText: text)
                    }
                }
                let result = try await DeckGenerator(provider: provider, imageProvider: imageProvider, imageStyle: imageStyle, useSmartArt: smartArt)
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

    func cancel() { task?.cancel(); task = nil; phase = .compose }
    func reset() { stage = ""; drafted = 0; total = 0; phase = .compose }

    private func apply(_ event: GenerationEvent) {
        switch event {
        case .preparingSource: stage = "Reading source"
        case .outlining: stage = "Outlining"
        case .outlineReady: stage = "Outline ready"
        case .drafting(let c, let t): stage = "Writing slides"; drafted = c; total = t; progressNoun = "slides"
        case .validating: stage = "Validating"
        case .repairing: stage = "Repairing"
        case .auditing: stage = "Polishing (QA pass)"
        case .illustrating(let c, let t): stage = "Generating images"; drafted = c; total = t; progressNoun = "images"
        case .rendering: stage = "Rendering .pptx"
        case .finished: stage = "Done"
        }
    }

    /// Pre-flight cost ballpark for the current model (nil if unpriced).
    var costEstimate: String? {
        guard let est = PriceTable.estimate(model: model, slideCount: slideCount,
                                            groundingChars: grounding?.text.count ?? 0) else { return nil }
        return PriceTable.formatted(est)
    }

    static func describe(_ error: Error) -> String {
        guard let lectern = error as? LecternError else { return "\(error.localizedDescription)" }
        switch lectern {
        case .noKey: return "Add an API key in Settings to begin."
        case .authFailed(let p): return "That key was rejected by \(p)."
        case .rateLimited(let s): return "Rate-limited — try again in \(s)s."
        case .requestTooLarge: return "That PDF is too large for this model."
        case .networkOffline: return "No connection."
        case .schemaInvalid: return "The model returned a deck Lectern couldn't parse."
        case .providerError(_, let m): return m
        case .renderFailed(let m): return "Couldn't write the deck: \(m)"
        case .cancelled: return "Cancelled."
        }
    }

    static func decksDirectory() -> URL {
        #if os(iOS)
        // Documents, not Application Support: with UIFileSharingEnabled +
        // LSSupportsOpeningDocumentsInPlace the decks show up in the Files app,
        // which is the iOS equivalent of "Reveal in Finder".
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("Decks", isDirectory: true)
        #else
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("Lectern/Decks", isDirectory: true)
        #endif
    }
}
