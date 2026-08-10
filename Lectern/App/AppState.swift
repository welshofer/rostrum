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
    /// The typed error behind `.failed`, so the failure screen can offer the
    /// recovery that fits instead of one button back to the form. `describe`
    /// already knows which error occurred and then flattens it to a String;
    /// this keeps the original alongside it.
    private(set) var lastFailure: LecternError?

    /// The app has two errands, and the first screen is where you say which.
    ///
    /// `inspected` carries no payload: the inspection is held beside it rather
    /// than inside, because `Phase` is `Equatable` and drives a SwiftUI
    /// `.animation(value:)` that compares it on every pass. A deck's whole
    /// outline — every paragraph of every slide — is not something to compare
    /// on the render path.
    enum Phase: Equatable {
        case home
        case compose, generating
        case result(DeckResult)
        case failed(String)
        case inspecting, inspected
    }
    var phase: Phase = .home

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

    enum ImageKeyStatus: Equatable { case unknown, validating, valid, invalid(String) }
    private(set) var imageKeyStatus: ImageKeyStatus = .unknown

    /// A curated, clean model list — NOT the provider's raw /v1/models dump
    /// (which is full of point-releases and internal EAP builds). Validate only
    /// confirms the key; it never rewrites this list.
    static func defaultModels(for id: ProviderID) -> [String] {
        switch id {
        case .anthropic: return ["claude-opus-5", "claude-sonnet-5", "claude-fable-5", "claude-haiku-4-5-20251001"]
        case .openAI: return ["gpt-5.2", "gpt-5.2-mini", "gpt-5.1"]
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

    // MARK: Library — the decks already on disk
    private(set) var library: [DeckFile] = []
    /// Whether the library sheet is up. On `AppState` rather than local view
    /// state so the menu bar can open it from anywhere, which is the whole
    /// point of having a menu item for it.
    var isShowingLibrary = false
    /// Set once, when decks were actually relocated, so the move is not
    /// something the user has to discover. Cleared when they dismiss it.
    private(set) var migrationNotice: String?

    func dismissMigrationNotice() { migrationNotice = nil }

    /// Launch work that has no business on the launch path.
    ///
    /// Called from the first `.task`, not `init`. The migration is a directory
    /// listing and up to a few dozen renames; on the main actor during `init`
    /// that is filesystem I/O between the user and their first frame, for a
    /// job that is a no-op on every launch after the first.
    func start() async {
        #if os(macOS)
        let moved = await Task.detached { Self.migrateLegacyDecks() }.value
        if moved > 0 {
            migrationNotice = "Moved \(moved) deck\(moved == 1 ? "" : "s") to Documents › Lectern."
        }
        #endif
        // Rejected drafts carry the prompt and whatever was lifted from an
        // attached PDF. Useful while a failure is being looked at; a liability
        // once it is not.
        let diagnostics = Self.diagnosticsDirectory()
        await Task.detached { DeckStorage.pruneDiagnostics(in: diagnostics) }.value
        refreshLibrary()
    }

    /// Re-read the decks folder. Cheap (one directory listing, no deck is
    /// opened), so it runs whenever the library is shown rather than being
    /// cached and going stale when a deck is added or removed in Finder.
    func refreshLibrary() {
        library = DeckLibrary.decks(in: Self.decksDirectory())
    }

    /// Slide counts, keyed by deck. The list view shows them in a column, which
    /// needs every value up front rather than one per row as it scrolls — and
    /// reading one is now a single zip entry, so filling the whole library is
    /// cheap enough to do on a refresh.
    private(set) var slideCounts: [URL: Int] = [:]

    func loadSlideCounts() async {
        for deck in library where slideCounts[deck.url] == nil {
            if let card = await DeckCardIndex.shared.card(for: deck) {
                slideCounts[deck.url] = card.slideCount
            }
        }
    }

    func deleteFromLibrary(_ deck: DeckFile) {
        try? DeckLibrary.delete(deck)
        refreshLibrary()
    }

    /// The last rename that failed, for the view to show and then clear. A
    /// rename that silently does nothing is worse than one that explains why.
    var renameProblem: String?

    func renameInLibrary(_ deck: DeckFile, to name: String) {
        do {
            try DeckLibrary.rename(deck, to: name)
            renameProblem = nil
        } catch {
            renameProblem = String(describing: error)
        }
        refreshLibrary()
    }

    // MARK: Generating progress
    var stage = ""
    var drafted = 0
    var total = 0
    var progressNoun = "slides"          // "slides" while drafting, "images" while illustrating
    private var task: Task<Void, Never>?
    /// Which generation the UI is currently showing. A cancelled task's
    /// continuation runs after `cancel()` returns, so every write it makes is
    /// checked against this first — see `RunGate`.
    private var runs = RunGate()

    private enum Keys {
        static let provider = "providerID", model = "model", favorites = "favoriteStyles"
        static let recents = "recentStyles", imageProvider = "imageProviderID"
        static let useSmartArt = "useSmartArt"
    }

    /// - Parameter skipKeychain: pass `true` from tests. Reading the login
    ///   keychain from a test process is slow at best and a modal prompt at
    ///   worst, and no test here is about whether a key is stored.
    init(skipKeychain: Bool = false) {
        let d = UserDefaults.standard
        if let raw = d.string(forKey: Keys.provider), let id = ProviderID(rawValue: raw) { providerID = id }
        if let m = d.string(forKey: Keys.model), Self.defaultModels(for: providerID).contains(m) { model = m }
        if let raw = d.string(forKey: Keys.imageProvider), let id = ImageProviderID(rawValue: raw) { imageProviderID = id }
        favorites = Set(d.stringArray(forKey: Keys.favorites) ?? [])
        recents = d.stringArray(forKey: Keys.recents) ?? []
        useSmartArt = d.bool(forKey: Keys.useSmartArt)
        guard !skipKeychain else { return }
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
        imageKeyStatus = .unknown
        UserDefaults.standard.set(id.rawValue, forKey: Keys.imageProvider)
        hasImageKey = KeychainStore.hasKey(forImage: id)
    }

    func saveImageKey(_ key: String) {
        let ok = KeychainStore.save(key, forImage: imageProviderID)
        hasImageKey = KeychainStore.hasKey(forImage: imageProviderID)
        imageKeyStatus = ok && hasImageKey ? .unknown : .invalid("Couldn't write to the Keychain.")
    }

    func clearImageKey() {
        KeychainStore.delete(forImage: imageProviderID)
        hasImageKey = false
        imageKeyStatus = .unknown
    }

    /// Validate authentication and access to the exact image model Lectern uses.
    func validateImageKey() async {
        let id = imageProviderID
        guard let key = KeychainStore.read(forImage: id) else {
            imageKeyStatus = .invalid("No image key stored.")
            return
        }
        imageKeyStatus = .validating
        do {
            try await ImageProviderFactory.validate(id: id, apiKey: key)
            guard imageProviderID == id else { return }
            imageKeyStatus = .valid
        } catch {
            guard imageProviderID == id else { return }
            imageKeyStatus = .invalid(Self.describe(error))
        }
    }

    /// Validate the stored key by pinging the provider's models endpoint (§294).
    /// This ONLY confirms the key works — it never touches the curated model list
    /// or the current selection.
    func validateKey() async {
        // Capture and re-check the provider, exactly as validateImageKey does:
        // switching provider mid-flight would otherwise paint this verdict
        // against the wrong key — and selectProvider has already reset the
        // status to .unknown by then, so the stale write undoes a correct one.
        let id = providerID
        guard let key = KeychainStore.read(for: id) else { keyStatus = .invalid("No key stored."); return }
        keyStatus = .validating
        do {
            let models = try await AnthropicModels.list(apiKey: key)
            guard providerID == id else { return }
            keyStatus = .valid(models.count)
        } catch {
            guard providerID == id else { return }
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
        guard hasKey else {
            lastFailure = .noKey
            phase = .failed("Add your \(providerID.label) API key in \(Self.settingsHint) to generate.")
            return
        }

        phase = .generating; stage = "Starting"; drafted = 0; total = slideCount
        let run = runs.begin()
        let request = DeckRequest(prompt: prompt, audience: audience, goal: goal,
                                  slideCount: slideCount, notes: includeNotes,
                                  groundingText: grounding?.text,
                                  styleSlug: selectedStyleSlug ?? "default")
        let designURL = selectedStyle?.designURL
        let directory = Self.decksDirectory()
        let diagnostics = Self.diagnosticsDirectory()
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
                var imageSkipNote: String?
                if let imageKey {
                    if self.runs.isCurrent(run) { self.stage = "Checking image provider" }
                    do {
                        try await ImageProviderFactory.validate(id: imageID, apiKey: imageKey)
                        if self.imageProviderID == imageID { self.imageKeyStatus = .valid }
                        imageProvider = try ImageProviderFactory.make(id: imageID, apiKey: imageKey)
                        if let style {
                            imageStyle = ImageStyleDirective.from(style: style)
                        }
                    } catch {
                        // Images are an enhancement — "a deck is fully valid
                        // without one" — and the text run hasn't even started.
                        // An image key failing its check used to abort the
                        // whole generation; now it costs the pictures, not the
                        // deck, and says so on the result.
                        if self.imageProviderID == imageID {
                            self.imageKeyStatus = .invalid(Self.describe(error))
                        }
                        imageSkipNote = "Images were skipped — the image key failed its check: "
                            + Self.describe(error)
                    }
                }
                var result = try await DeckGenerator(provider: provider, imageProvider: imageProvider, imageStyle: imageStyle, useSmartArt: smartArt)
                    .generate(request, designURL: designURL, into: directory,
                              diagnostics: diagnostics) { [weak self] event in
                        Task { @MainActor in self?.apply(event, run: run) }
                    }
                if let imageSkipNote { result.warnings.append(imageSkipNote) }
                // Cancellation is cooperative, so all three of these can run
                // after the user has already started a replacement. Writing
                // them unconditionally is what dropped a live generation off
                // the screen.
                guard self.runs.isCurrent(run) else { return }
                self.phase = .result(result)
            } catch is CancellationError {
                guard self.runs.isCurrent(run) else { return }
                self.phase = .compose
            } catch {
                guard self.runs.isCurrent(run) else { return }
                self.lastFailure = error as? LecternError
                self.phase = .failed(Self.describe(error))
            }
        }
    }

    func cancel() {
        // Abandon the run before cancelling, so anything already past its last
        // cancellation check still cannot write over what replaces it.
        runs.abandon()
        task?.cancel(); task = nil; phase = .compose
    }

    /// Back to the first screen — the fork between the app's two errands.
    func goHome() {
        stage = ""; drafted = 0; total = 0; lastFailure = nil
        inspection = nil
        clearExportReport()
        phase = .home
    }

    /// Into the compose form, keeping whatever is already typed in it.
    func startCreate() {
        stage = ""; drafted = 0; total = 0; lastFailure = nil
        phase = .compose
    }

    func reset() { goHome() }

    // MARK: - Inspect

    /// The deck currently torn down. Held beside `.inspected` rather than
    /// inside it — see `Phase`.
    private(set) var inspection: DeckInspection?

    /// Whether the "choose a deck" importer is up. On `AppState` so the menu
    /// bar can start the flow from anywhere.
    var isChoosingDeckToInspect = false
    /// Whether the "choose a destination folder" importer is up.
    var isChoosingExportDestination = false

    private(set) var inspectStage = ""
    private(set) var inspectDone = 0
    private(set) var inspectTotal = 0
    private var inspectTask: Task<Void, Never>?

    private(set) var isExporting = false
    private(set) var exportedDirectory: URL?
    private(set) var exportSummary: String?
    private(set) var exportProblem: String?

    func chooseDeckToInspect() { isChoosingDeckToInspect = true }

    func clearExportReport() {
        exportedDirectory = nil; exportSummary = nil; exportProblem = nil
    }

    /// Open a deck and take it apart.
    ///
    /// All of it runs off the main actor: opening a large package, walking
    /// every shape and rendering a picture of every slide is exactly the work
    /// that freezes a window if it is done where the window is drawn (I6).
    func inspect(deckAt url: URL) {
        inspectTask?.cancel()
        inspection = nil
        clearExportReport()
        inspectStage = "Opening the deck"
        inspectDone = 0
        inspectTotal = 0
        phase = .inspecting

        // Detached *is* the task we keep, rather than a detached task inside a
        // structured one: unstructured work does not inherit cancellation, so
        // wrapping it would have left Cancel dismissing the screen while the
        // deck kept being parsed behind it.
        inspectTask = Task.detached(priority: .userInitiated) { [self] in
            do {
                // A file the user picked arrives security-scoped; without this
                // the read fails outside the sandbox for no visible reason.
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                let result = try DeckInspector.inspect(deckAt: url) { event in
                    Task { @MainActor in self.applyInspect(event) }
                }
                await MainActor.run {
                    self.inspection = result
                    self.phase = .inspected
                }
            } catch is CancellationError {
                // `cancelInspection` already moved the screen; don't move it back.
                return
            } catch {
                // Rendered here, where the error still exists: `describe` is
                // main-actor isolated and an `Error` is not `Sendable`, so what
                // crosses back is the `String`.
                let message = String(describing: error)
                await MainActor.run {
                    self.phase = .failed("Couldn't open that deck: \(message)")
                }
            }
        }
    }

    func cancelInspection() {
        inspectTask?.cancel()
        inspectTask = nil
        phase = .home
    }

    private func applyInspect(_ event: DeckInspector.Event) {
        switch event {
        case .opening: inspectStage = "Opening the deck"
        case .validating: inspectStage = "Checking it against the schema"
        case .extracting: inspectStage = "Reading every slide"
        case .rendering(let done, let total):
            inspectStage = "Rendering slide previews"
            inspectDone = done
            inspectTotal = total
        case .finished: inspectStage = "Done"
        }
    }

    /// Write the full teardown into a folder the user chose.
    ///
    /// Copying media out of a deck is I/O measured in megabytes, so it gets
    /// the same treatment as everything else here: off the main actor, with
    /// something on screen saying so.
    func exportInspected(into parent: URL) {
        guard let deck = inspection?.fileURL, !isExporting else { return }
        isExporting = true
        clearExportReport()

        Task.detached(priority: .userInitiated) { [self] in
            do {
                let scopedDeck = deck.startAccessingSecurityScopedResource()
                defer { if scopedDeck { deck.stopAccessingSecurityScopedResource() } }
                let scopedParent = parent.startAccessingSecurityScopedResource()
                defer { if scopedParent { parent.stopAccessingSecurityScopedResource() } }
                let outcome = try DeckExporter.export(deckAt: deck, into: parent)
                let summary = "\(outcome.slideCount) slide\(outcome.slideCount == 1 ? "" : "s")"
                    + " · \(outcome.assetsWritten) media file\(outcome.assetsWritten == 1 ? "" : "s")"
                    + " · \(outcome.chartsWritten) chart CSV\(outcome.chartsWritten == 1 ? "" : "s")"
                // A partial export that reports success is worse than a slow one.
                let problem = outcome.warnings.isEmpty
                    ? nil : outcome.warnings.joined(separator: "\n")
                await MainActor.run {
                    self.exportedDirectory = outcome.directory
                    self.exportSummary = summary
                    self.exportProblem = problem
                    self.isExporting = false
                }
            } catch {
                let message = String(describing: error)
                await MainActor.run {
                    self.exportProblem = message
                    self.isExporting = false
                }
            }
        }
    }

    private func apply(_ event: GenerationEvent, run: Int) {
        // Progress from a run the user already cancelled would otherwise drive
        // the stage label and the bar of the one that replaced it.
        guard runs.isCurrent(run) else { return }
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
                                            groundingChars: grounding?.text.count ?? 0,
                                            promptChars: prompt.count) else { return nil }
        return PriceTable.formatted(est)
    }

    static func describe(_ error: Error) -> String {
        guard let lectern = error as? LecternError else { return "\(error.localizedDescription)" }
        switch lectern {
        case .noKey: return "Add an API key in Settings to begin."
        case .authFailed(let p): return "That key was rejected by \(p)."
        case .rateLimited(let s): return "Rate-limited — try again in \(s)s."
        case .requestTooLarge: return "That PDF is too large for this model."
        case .responseTruncated(let slideCount):
            return "The model ran out of room before it finished all \(slideCount) slides. "
                + "Ask for fewer slides, or turn speaker notes off, and try again."
        case .networkOffline: return "No connection."
        case .schemaInvalid(let errors):
            // The reasons were always there and were thrown away, which left
            // the one failure mode a user can actually act on looking like a
            // dead end.
            let detail = errors.prefix(3).joined(separator: "\n")
            return detail.isEmpty
                ? "The model returned a deck Lectern couldn't parse."
                : "The model returned a deck Lectern couldn't parse:\n\n\(detail)"
        case .providerError(_, let m): return m
        case .renderFailed(let m): return "Couldn't write the deck: \(m)"
        case .cancelled: return "Cancelled."
        }
    }

    /// Where generated decks are written.
    ///
    /// `~/Documents/Lectern` on macOS; `Documents/Decks` on iOS, where the
    /// container's Documents is exactly what the Files app shows.
    ///
    /// A deck is the user's document, so it goes where documents go. Not the
    /// app bundle — that is code-signed and read-only, and a user's work has no
    /// business inside the program that made it. And no longer Application
    /// Support, which is for data the app owns: it sits in a Library folder
    /// Finder hides by default, so every deck saved there was one the user had
    /// to be told how to reach, and it is not where anyone looks for their own
    /// files.
    nonisolated static func decksDirectory() -> URL {
        #if os(iOS)
        // Documents, not Application Support: with UIFileSharingEnabled +
        // LSSupportsOpeningDocumentsInPlace the decks show up in the Files app,
        // which is the iOS equivalent of "Reveal in Finder".
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("Decks", isDirectory: true)
        #else
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("Lectern", isDirectory: true)
        #endif
    }

    /// Where the app's own diagnostics go — the rejected draft a failed
    /// generation leaves behind. Application Support, not the decks folder:
    /// that file is app-owned, and on iOS the decks folder is published to the
    /// Files app.
    nonisolated static func diagnosticsDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return DeckStorage.diagnosticsDirectory(appSupport: base)
    }

    #if os(macOS)
    /// Decks used to be written to `~/Library/Application Support/Lectern/Decks`.
    /// Moving where they are written does not move the ones already there, so
    /// without this a user's existing decks would simply be gone from the app's
    /// point of view.
    ///
    /// `nonisolated` and returning the count: it runs off the main actor from
    /// `start()`, and the count is what tells the user their decks moved.
    nonisolated static func migrateLegacyDecks() -> Int {
        guard let support = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask).first else { return 0 }
        return DeckStorage.migrateDecks(
            from: support.appendingPathComponent("Lectern/Decks", isDirectory: true),
            to: decksDirectory())
    }
    #endif
}
