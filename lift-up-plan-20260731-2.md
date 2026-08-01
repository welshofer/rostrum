# Lift-Up Plan: Lectern

> Platform: mixed Apple — a SwiftUI app targeting macOS 26 and iOS/iPadOS 26 (`Lectern/project.yml`), on `LecternCore`, a SwiftPM package floored at macOS 13 / iOS 16 and built on Linux in CI
> Surveyed: 2026-07-31
> Coverage: full — every file under `Lectern/App` (12 files) and `Lectern/Sources/LecternCore` (17 files), 5,610 lines, plus `project.yml` and the 2,057-line test target. Nothing in this target was left unread. `Sources/Rostrum` is **out of scope** by request; findings that resolve into the library are noted and excluded.
> Attractiveness anchor: inferred — **Raycast** (a single-window Mac utility: keyboard-first, instant, calm density, a first run that teaches itself)

Second audit of this target today. Nine fixes landed on `main` in between, so every candidate here was re-verified against the current files rather than carried over — six previously-reported items are now genuinely fixed and appear only in *Dropped during verification*, not as findings. Two of the findings below are defects in code I wrote this afternoon.

---

## Performance

### 1. The style gallery re-filters 150 styles four times per keystroke

- **Location:** `Lectern/App/StylePickerSheet.swift:27-37`
- **Proof:**
  ```swift
    private func matches(_ s: Style) -> Bool {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let tagOK = activeTag == nil || s.tags.contains(activeTag!)
        let qOK = q.isEmpty || s.name.lowercased().contains(q)
            || s.tags.contains { $0.contains(q) } || (s.vibe?.lowercased().contains(q) ?? false)
        return tagOK && qOK
    }

    private var filtered: [Style] { app.styles.filter(matches) }
    private var favorites: [Style] { filtered.filter { app.isFavorite($0.slug) } }
    private var recents: [Style] { app.recents.compactMap { slug in filtered.first { $0.slug == slug } } }
  ```
- **Verified:** `grep -n 'filtered\|@State private var query\|debounce\|searchable' App/StylePickerSheet.swift` →
  ```
  9:    @State private var query = ""
  35:    private var filtered: [Style] { app.styles.filter(matches) }
  36:    private var favorites: [Style] { filtered.filter { app.isFavorite($0.slug) } }
  37:    private var recents: [Style] { app.recents.compactMap { slug in filtered.first { $0.slug == slug } } }
  48:                        if !favorites.isEmpty { section("Favorites", favorites) }
  49:                        if !recents.isEmpty { section("Recents", recents) }
  50:                        section(activeTag == nil && query.isEmpty ? "All \(app.styles.count)" : "\(filtered.count) results", filtered)
  ```
- **Do:** `filtered` is computed, and `body` evaluates it at lines 48, 49 and twice on 50 — four full passes over 150 styles per keystroke. Worse, `matches` recomputes `query.trimmingCharacters(...).lowercased()` *inside* the loop, so a single character typed allocates ~600 throwaway Strings. Hoist the normalized query into a computed property outside `matches`, and materialize `filtered` once into a `let` at the top of `body` (or `@State` updated in `.onChange(of: query)`), deriving `favorites`/`recents` from that one array.
- **Why:** Search across 150 styles is this sheet's primary interaction and it does ~600 allocations and four array copies per keypress, all on the main actor.
- **Effort:** S · **Impact:** M

### 2. The contact sheet spawns one WKWebView — and one web content process — per slide

- **Location:** `Lectern/App/SlidePreview.swift:48-56`, used from `SlideContactSheet` at `:92-101`
- **Proof:**
  ```swift
    @MainActor fileprivate func makeWebView() -> WKWebView {
        let view = WKWebView()
        #if os(iOS)
        view.scrollView.isScrollEnabled = false
        view.isOpaque = false
        view.backgroundColor = .clear
        #endif
        return view
    }
  ```
- **Verified:** `grep -rn 'WKProcessPool\|WKWebViewConfiguration\|takeSnapshot\|ImageRenderer' App/SlidePreview.swift` → `# (no matches)`
- **Do:** `slideCount` ranges to 40 (`ContentView.swift:206`), so a long deck instantiates up to 40 `WKWebView`s, each with its own WebKit content and networking process. `LazyVGrid` defers creation but never tears them down once scrolled past. Rasterize each SVG once via `WKWebView.takeSnapshot(with:)` and show plain `Image` views in the grid, keeping a live web view only for a full-size inspector. Failing that, share one `WKProcessPool` through a `WKWebViewConfiguration` and cap how many live views exist at once.
- **Why:** Forty web content processes for forty static pictures is hundreds of megabytes and visible scroll stutter, on the screen the user lands on after every single generation.
- **Effort:** M · **Impact:** L

### 3. Launch reads 150 full `design.md` files to parse six header fields

- **Location:** `Lectern/Sources/LecternCore/StyleCatalog/StyleCatalog.swift:77`
- **Proof:**
  ```swift
    private func parse(slug: String, designURL: URL, thumbnail: URL?) -> Style {
        let text = (try? String(contentsOf: designURL, encoding: .utf8)) ?? ""
        // YAML frontmatter takes precedence when present.
        if let front = frontmatter(text) {
  ```
- **Verified:** `cat App/Resources/Styles/*.md | wc -c` → `1449192`; `ls App/Resources/Styles/*.md | wc -l` → `150`; `grep -rn 'cache\|manifest\|index.json' Sources/LecternCore/StyleCatalog/StyleCatalog.swift` → `# (no matches)`
- **Do:** 1.45 MB of markdown is read and UTF-8 decoded at every launch to extract name, vibe, category, theme, palette and font — all of which sit in the first ~40 lines of each file. It is correctly off-main (`AppState.loadStyles` wraps it in `Task.detached`), so this is latency-to-first-gallery rather than a hang. Generate a `styles-index.json` at build time from a script in `Lectern/scripts/` (matching the existing `build.sh`/`build-ios.sh` convention) and have `StyleCatalog` prefer it, falling back to the directory scan when absent.
- **Why:** The style picker is the app's most differentiated surface; it should be populated before the user can reach it, not after a 1.45 MB parse.
- **Effort:** M · **Impact:** S

### 4. Slide previews render strictly serially, after the deck is already saved

- **Location:** `Lectern/Sources/LecternCore/Rendering/DeckRenderer.swift:72-76`
- **Proof:**
  ```swift
    private static func previews(of presentation: Presentation) -> [String] {
        (0..<presentation.slides.count).compactMap { index in
            try? presentation.renderSVG(slideAt: index, pixelWidth: 640)
        }
    }
  ```
- **Verified:** `grep -n 'withTaskGroup\|concurrentPerform\|DispatchQueue' Sources/LecternCore/Rendering/DeckRenderer.swift` → `# (no matches)`
- **Do:** This runs after `save(to:)` has already succeeded, so every second it takes is pure added latency on the last step before the user sees anything — and the file's own comment at `:420-422` calls previews "the tail cost and pure convenience". `Presentation` is deliberately non-`Sendable` and must not leave the actor, so parallelism has to come from below: extract a value-typed per-slide input (slide XML + resolved theme + media blobs) and fan out with `DispatchQueue.concurrentPerform` over those values.
- **Why:** On a 40-slide illustrated deck this is the difference between the result screen appearing instantly and appearing after several seconds of finished-but-frozen UI.
- **Effort:** M · **Impact:** M

### 5. The library re-lists the decks folder synchronously on the main actor

- **Location:** `Lectern/App/AppState.swift:95-97`
- **Proof:**
  ```swift
    func refreshLibrary() {
        library = DeckLibrary.decks(in: Self.decksDirectory())
    }
  ```
- **Verified:** `grep -rn 'refreshLibrary' App/` →
  ```
  App/AppState.swift:95:    func refreshLibrary() {
  App/AppState.swift:100:        refreshLibrary()
  App/AppState.swift:92:        refreshLibrary()
  App/ContentView.swift:245:        .task { app.refreshLibrary() }
  App/DeckLibrarySheet.swift:56:        .task { app.refreshLibrary() }
  ```
  `AppState` is `@MainActor` (`:14`), and `DeckLibrary.decks` is a plain synchronous function — `grep -n 'nonisolated\|async' Sources/LecternCore/Storage/DeckLibrary.swift` → `# (no matches)`.
- **Do:** Mine, from this afternoon. Each call is `contentsOfDirectory` plus a `resourceValues` stat per deck, on the main actor — and it fires on every Compose appearance and every time the library sheet opens. Twenty-one decks is imperceptible; a folder someone has pointed at a network volume or filled with hundreds of decks is not. Make `refreshLibrary` `async`, do the listing in a `Task.detached`, and assign the result back on the main actor — the same shape `loadStyles` already uses at `AppState.swift:131-136`.
- **Why:** It is main-thread filesystem I/O on the two most-visited screens, and the cost scales with a directory the user controls.
- **Effort:** S · **Impact:** S

---

## Functionality

### 1. Three of the four advertised LLM providers are not implemented

- **Location:** `Lectern/Sources/LecternCore/Providers/ProviderFactory.swift:17-25`
- **Proof:**
  ```swift
        case .anthropic:
            return AnthropicProvider(apiKey: key, model: model)
        case .openAI, .gemini, .custom:
            throw LecternError.providerError(status: 0, message: "\(id.rawValue) isn't wired up yet — use Anthropic.")
        }
    }

    /// Whether `id` currently has a live implementation (independent of any key).
    public static func isWired(_ id: ProviderID) -> Bool { id == .anthropic }
  ```
- **Verified:** `grep -rn 'struct OpenAIProvider\|struct GeminiProvider\|struct CustomProvider' Sources/` → `# (no matches)`. The only OpenAI/Gemini types are `OpenAIImageProvider` and `GeminiImageProvider`, which conform to `ImageProvider`, not `LLMProvider`.
- **Do:** `ProviderID` has four cases, Settings renders all four with a "(soon)" suffix, and `Theme.swift:29-35` gives each a polished display label — the whole surface is built for a capability that does not exist. `AnthropicProvider` is only 241 lines and `LLMProvider` is already the right seam, so port it to OpenAI's chat-completions + `tools` and Gemini's `generateContent` + `functionDeclarations`. Both now inherit the shared `HTTPRetry` policy for free. If they are not going to ship, cut the dead cases from `ProviderID` instead.
- **Why:** Anyone holding an OpenAI key sees it offered, selects it, pastes the key, and hits a dead end — the app advertises four doors and opens one.
- **Effort:** L · **Impact:** L

### 2. The model list is a compile-time constant, and the live one is fetched then discarded

- **Location:** `Lectern/App/AppState.swift:44-50` and `:226-235`
- **Proof:**
  ```swift
    static func defaultModels(for id: ProviderID) -> [String] {
        switch id {
        case .anthropic: return ["claude-opus-4-8", "claude-sonnet-5", "claude-fable-5", "claude-haiku-4-5-20251001"]
        default: return []
        }
    }
    var modelOptions: [String] { Self.defaultModels(for: providerID) }
  ```
  and the fetch that throws its result away:
  ```swift
    func validateKey() async {
        guard let key = KeychainStore.read(for: providerID) else { keyStatus = .invalid("No key stored."); return }
        keyStatus = .validating
        do {
            let models = try await AnthropicModels.list(apiKey: key)
            keyStatus = .valid(models.count)
        } catch {
  ```
- **Verified:** `grep -n 'AnthropicModels.list\|modelOptions\|defaultModels' App/AppState.swift` →
  ```
  44:    static func defaultModels(for id: ProviderID) -> [String] {
  50:    var modelOptions: [String] { Self.defaultModels(for: providerID) }
  230:            let models = try await AnthropicModels.list(apiKey: key)
  ```
  `models` is consumed only as `.count`; `modelOptions` never reads it.
- **Do:** The curation rationale at `:40-43` is sound — the raw `/v1/models` dump is full of point releases and EAP builds. But the consequence is that a new model needs an app rebuild, and the hardcoded list rots silently. Intersect the fetched list against a curated *prefix* allowlist rather than exact strings, so new point releases appear automatically while noise stays hidden, and mark any selected model the account can no longer reach.
- **Why:** A deck generator whose model menu is a compile-time constant is one provider release away from offering only models the user cannot call.
- **Effort:** S · **Impact:** M

### 3. PDF grounding reads one document, silently stops at 40k characters, and cannot read scans

- **Location:** `Lectern/App/PDFGrounding.swift:24-32`
- **Proof:**
  ```swift
            for i in 0..<doc.pageCount {
                if let page = doc.page(at: i), let s = page.string { text += s + "\n" }
                if text.count > maxChars { break }
            }
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            let truncated = trimmed.count > maxChars
            return Source(name: url.lastPathComponent,
                          text: String(trimmed.prefix(maxChars)),
  ```
- **Verified:** `grep -rn 'VNRecognizeText\|import Vision\|allowsMultipleSelection' App/` → `# (no matches)`; `grep -n 'grounding' App/AppState.swift` shows `private(set) var grounding: PDFGrounding.Source?` — a single optional, not a collection.
- **Do:** Three gaps in order of value. (a) The loop `break`s positionally, so a 300-page report contributes only its opening pages while the UI still reports the full `doc.pageCount` — rank or summarize chunks by relevance to the prompt instead of truncating at the front. (b) Accept several PDFs by making `grounding` an array; `fileImporter` needs only `allowsMultipleSelection: true`. (c) Route the "no selectable text" case through `VNRecognizeTextRequest` rather than telling the user scans need OCR and stopping.
- **Why:** "Ground the deck on real facts" is what separates this from a chat prompt, and today it reads the first dozen pages of one text-layer PDF.
- **Effort:** M · **Impact:** M

### 4. A finished deck can only be regenerated from scratch, though the revise path already exists

- **Location:** the `.result` phase — `Lectern/App/ContentView.swift:41-48`
- **Proof:**
  ```swift
    @ViewBuilder private var phaseView: some View {
        switch app.phase {
        case .compose: ComposeView()
        case .generating: GeneratingView()
        case .result(let r): ResultView(result: r)
        case .failed(let m): FailedView(message: m)
        }
    }
  ```
- **Verified:** `grep -rn 'revise' App/ Sources/LecternCore/` →
  ```
  Sources/LecternCore/Providers/AnthropicProvider.swift:56:    public func revise(_ request: DeckRequest, deckJSON: String,
  Sources/LecternCore/Providers/DeckGenerator.swift:82:            if let revised = try? await provider.revise(request, deckJSON: draftJSON, emit: emit),
  Sources/LecternCore/Providers/Providers.swift:79:    func revise(_ request: DeckRequest, deckJSON: String,
  Sources/LecternCore/Providers/Providers.swift:85:    func revise(_ request: DeckRequest, deckJSON: String,
  ```
  Every call site is internal to the QA pass; nothing in `App/` reaches it.
- **Do:** `.result` is terminal — the only exit is "New", which discards everything and starts a fresh paid generation. `provider.revise(_:deckJSON:emit:)` is implemented and already round-trips a whole deck through the forced schema. Expose it: persist the validated `DeckIR` beside the `.pptx`, let the user tap a slide in the contact sheet, type an instruction, and re-render. The deck library from this afternoon gives that persisted IR somewhere to live.
- **Why:** One bad slide in twenty currently costs a full regeneration at full price, with no guarantee the other nineteen survive.
- **Effort:** L · **Impact:** L

### 5. The library can open and delete a deck but not rename it, and the app generates colliding names

- **Location:** `Lectern/App/DeckLibrarySheet.swift:120-152` (the row's actions), against `Lectern/Sources/LecternCore/Rendering/DeckRenderer.swift:885-895`
- **Proof:** the name is derived from the title, with a numeric suffix on collision:
  ```swift
    private func outputURL(title: String, in directory: URL) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let base = slugify(title.isEmpty ? "deck" : title)
        var candidate = directory.appendingPathComponent("\(base).pptx")
        var n = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(base)-\(n).pptx")
            n += 1
        }
        return candidate
    }
  ```
- **Verified:** `grep -rn 'rename\|moveItem' App/DeckLibrarySheet.swift Sources/LecternCore/Storage/DeckLibrary.swift` →
  ```
  Sources/LecternCore/Storage/DeckLibrary.swift:85:        try fileManager.removeItem(at: deck.url)
  ```
  No rename anywhere. And the real Decks folder shows the collision behaviour in the wild: `train-the-skill-not-the-weights.pptx`, `-2.pptx`, `-3.pptx`, plus `training-the-skill-not-the-weights.pptx` and `-2.pptx` — five near-identical names from re-runs of one idea.
- **Do:** Add rename to `DeckLibrary` (a `moveItem` with the same never-overwrite guard `DeckStorage.migrateDecks` uses) and an inline-editable name in the row. This is what makes the numeric-suffix pile-up survivable: the date and size in the row tell decks apart, but nothing lets the user fix the names.
- **Why:** Re-running a prompt is the normal workflow, and it produces indistinguishable files the user cannot correct from inside the app that made them.
- **Effort:** M · **Impact:** M

---

## Stability

**4 items, not 5.** A fifth candidate — the `outputURL` existence-then-write race — was investigated and dropped as unreachable, because generation is serialized behind `phase != .generating` (see *Dropped during verification*). Rather than pad, this dimension ships four. That is a fair count for a target with no force-unwraps, no `try!`, and no TODOs across 5,610 lines.

### 1. A cancelled generation's completion clobbers the run that replaced it

- **Location:** `Lectern/App/AppState.swift:310-323`
- **Proof:**
  ```swift
                self.phase = .result(result)
            } catch is CancellationError {
                self.phase = .compose
            } catch {
                self.phase = .failed(Self.describe(error))
            }
        }
    }

    func cancel() { task?.cancel(); task = nil; phase = .compose }
  ```
- **Verified:** `grep -c 'generationID\|epoch' App/AppState.swift` → `0`. The identity-guard pattern *is* known in this file — `grep -n 'guard imageProviderID == id' App/AppState.swift` →
  ```
  205:            guard imageProviderID == id else { return }
  208:            guard imageProviderID == id else { return }
  ```
  — it is simply absent from the terminal `phase` writes.
- **Do:** Cancellation is cooperative, so the old task's `catch` runs some time *after* `cancel()` returns. Cancel then immediately regenerate, and the stale task resolves and writes `.compose` (or `.failed`) over the live `.generating` run — dropping the UI back to the form while a paid generation continues invisibly, its result unreachable. Add a monotonically increasing `generationID`, capture it in the task, and guard every terminal write with `guard self.generationID == captured else { return }`, exactly as line 205 already does for the image provider.
- **Why:** The user watches their in-flight generation vanish for no reason, and has no route back to the deck it eventually produces.
- **Effort:** S · **Impact:** M

### 2. `validateKey()` is missing the provider guard its image-side twin has

- **Location:** `Lectern/App/AppState.swift:226-235`
- **Proof:**
  ```swift
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
  ```
- **Verified:** the image equivalent, `sed -n '198,210p' App/AppState.swift` →
  ```
        imageKeyStatus = .validating
        do {
            try await ImageProviderFactory.validate(id: id, apiKey: key)
            guard imageProviderID == id else { return }
            imageKeyStatus = .valid
        } catch {
            guard imageProviderID == id else { return }
            imageKeyStatus = .invalid(Self.describe(error))
        }
  ```
  `validateImageKey` captures `let id = imageProviderID` up front and guards both branches. `validateKey` captures nothing and guards nothing.
- **Do:** Capture `let id = providerID` before the `await` and guard both writes with `guard providerID == id else { return }`. Note `selectProvider` (`:158`) already resets `keyStatus = .unknown`, so a late write actively overwrites a correct reset with a stale verdict.
- **Why:** Switching provider in Settings mid-validation paints a green "Valid · 4 models" — or a red rejection — against the wrong provider's key, in the one place in the app whose entire job is telling you whether your key works.
- **Effort:** S · **Impact:** S

### 3. A missing Styles resource degrades to zero styles with nothing said anywhere

- **Location:** `Lectern/App/AppState.swift:131-136`, with `Lectern/Sources/LecternCore/StyleCatalog/StyleCatalog.swift:47`
- **Proof:**
  ```swift
    func loadStyles() async {
        guard styles.isEmpty, let dir = Bundle.main.resourceURL?.appendingPathComponent("Styles") else { return }
        let loaded = await Task.detached { (try? StyleCatalog().load(from: dir)) ?? [] }.value
        styles = loaded
        if selectedStyleSlug == nil { selectedStyleSlug = recents.first ?? loaded.first?.slug }
    }
  ```
  and one layer down:
  ```swift
        let entries = (try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey])) ?? []
  ```
- **Verified:** `grep -rn 'styleLoadError\|stylesError\|ContentUnavailableView' App/AppState.swift App/ContentView.swift` → `# (no matches)`. The app's only `ContentUnavailableView`s are `StylePickerSheet.swift:46` (empty *search result*) and `DeckLibrarySheet.swift:27` (empty *library*) — neither is a load failure.
- **Do:** Three `try?`-to-default conversions stack: a missing bundle folder, an unreadable directory, an unreadable file. The result is `styles == []`, `selectedStyleSlug == nil`, and `generate()` proceeding with `styleSlug: "default"` and `designURL: nil` — an unstyled deck, with the picker still cheerfully offering to "Search 150 styles". Add a `styleLoadError: String?` to `AppState`, set it when the load throws or returns empty, and surface it on the STYLE card.
- **Why:** A resource-bundling regression would ship an app that quietly produces unstyled decks and passes every headless test, because `LecternCoreTests` uses its own fixtures rather than the app bundle.
- **Effort:** S · **Impact:** M

### 4. Launch does two synchronous Keychain reads on the main actor, each materializing the whole secret

- **Location:** `Lectern/App/AppState.swift:117-127`, calling `Lectern/App/KeychainStore.swift:40-56`
- **Proof:**
  ```swift
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
  ```
- **Verified:** `grep -n 'kSecReturnData\|static func hasKey' App/KeychainStore.swift` →
  ```
  47:            kSecReturnData as String: true,
  81:    static func hasKey(for provider: ProviderID) -> Bool { read(for: provider) != nil }
  90:    static func hasKey(forImage provider: ImageProviderID) -> Bool { read(forImage: provider) != nil }
  ```
  `hasKey` is `read(...) != nil`, and `read` sets `kSecReturnData: true` — so an existence test decrypts and copies the API key. `grep -c 'KeychainStore.hasKey\|KeychainStore.read' App/AppState.swift` → `10`.
- **Do:** `AppState.init()` runs during `LecternApp`'s `@State` initialization, so two blocking `SecItemCopyMatching` calls sit ahead of the first frame; on a locked login keychain that is an indefinite main-thread stall behind a system unlock prompt. Add a `hasKey`-only query using `kSecReturnData: false` + `kSecReturnAttributes: true` so existence never materializes the secret, then move the probes into the existing `start()` (`:83-93`). The one wrinkle to handle deliberately: `hasKey` gates the Generate button, so make it a three-state `Bool?` and render nothing until known, rather than flashing "add an API key" on every launch.
- **Why:** A locked keychain turns launch into an indefinite hang, and the app decrypts its most sensitive value ten times over to answer a boolean.
- **Effort:** M · **Impact:** M

---

## Reliability

**4 items, not 5.** This dimension was largely emptied earlier today — the retry policy, `max_tokens` truncation, image fan-out and atomic writes all landed on `main` and are listed under *Dropped during verification*. What remains is genuinely four; padding to five would mean inventing a fifth.

### 1. The Validate button is the one network call with no retry at all

- **Location:** `Lectern/Sources/LecternCore/Providers/AnthropicModels.swift:28-40`
- **Proof:**
  ```swift
        case 200:
            let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let models = (obj?["data"] as? [[String: Any]])?.compactMap { $0["id"] as? String } ?? []
            return models
        case 401, 403:
            throw LecternError.authFailed(provider: "Anthropic")
        case 429:
            let retry = Int(http.value(forHTTPHeaderField: "Retry-After") ?? "") ?? 2
            throw LecternError.rateLimited(afterSeconds: retry)
        default:
            throw LecternError.providerError(status: http.statusCode, message: "couldn't list models")
        }
  ```
- **Verified:** `for f in Sources/LecternCore/Providers/*.swift; do grep -q 'HTTPRetry' "$f" || echo "$f"; done` →
  ```
  Sources/LecternCore/Providers/AnthropicModels.swift
  Sources/LecternCore/Providers/DeckGenerator.swift
  Sources/LecternCore/Providers/DeckSchema.swift
  Sources/LecternCore/Providers/ImageGeneration.swift
  Sources/LecternCore/Providers/PriceTable.swift
  Sources/LecternCore/Providers/PromptTemplates.swift
  Sources/LecternCore/Providers/ProviderFactory.swift
  Sources/LecternCore/Providers/Providers.swift
  ```
  Of those, only `AnthropicModels` makes network calls — the rest are prompts, schema, pricing and factories. So it is the single network caller the shared policy does not reach.
- **Do:** Mine, from this afternoon: I unified `AnthropicProvider`, `GeminiImageProvider` and `OpenAIImageProvider` onto `HTTPRetry` and did not notice this file. It still hand-rolls the 429 path, does not translate a `URLError`, and never retries — so a transient blip makes a perfectly good key report as broken. Route it through `HTTPRetry` and give it the same `send:` test seam the three providers have.
- **Why:** This backs the Validate button, whose entire purpose is to tell the user whether their key works. A dropped connection currently answers "no".
- **Effort:** S · **Impact:** M

### 2. A validated, fully paid-for deck is discarded when rendering fails

- **Location:** `Lectern/Sources/LecternCore/Providers/DeckGenerator.swift:56-76` and `:250-256`
- **Proof:** the draft is preserved on the schema-failure path only —
  ```swift
    private static func keepRejectedDraft(_ json: String, in directory: URL) -> URL? {
        let url = directory.appendingPathComponent("rejected-draft.json")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try json.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }
  ```
- **Verified:** `grep -n 'keepRejectedDraft\|RenderError.renderFailed' Sources/LecternCore/Providers/DeckGenerator.swift` →
  ```
  57:                if let kept = Self.keepRejectedDraft(repaired.json, in: diagnostics ?? directory) {
  66:    private static func keepRejectedDraft(_ json: String, in directory: URL) -> URL?
  253:        } catch let RenderError.renderFailed(underlying) {
  ```
  Line 57 is the schema-invalid branch; line 253 rethrows a render failure and keeps nothing.
- **Do:** The instinct is right and already documented — "Without it the only record of what the model actually sent is an error string." But it is applied to the failure where the deck was *invalid*, not the one where the deck was **valid and our renderer broke**. Persist the validated `DeckIR` before calling `renderer.render`, and on `RenderError` keep it and offer a retry that skips straight back to rendering.
- **Why:** A bug in our own renderer costs the user the entire generation fee with nothing recoverable.
- **Effort:** S · **Impact:** M

### 3. A 120-second timeout now hides behind three retries with no overall deadline

- **Location:** `Lectern/Sources/LecternCore/Providers/AnthropicProvider.swift:158-166`
- **Proof:**
  ```swift
        while true {
            var req = URLRequest(url: endpoint, timeoutInterval: 120)
            req.httpMethod = "POST"
            req.setValue(apiKey, forHTTPHeaderField: "x-api-key")           // never logged (I1)
            req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            req.setValue("application/json", forHTTPHeaderField: "content-type")
            req.httpBody = try JSONSerialization.data(withJSONObject: payload)
  ```
- **Verified:** `grep -n 'timeoutInterval\|maxAttempts\|deadline\|Date()' Sources/LecternCore/Providers/AnthropicProvider.swift` →
  ```
  159:            var req = URLRequest(url: endpoint, timeoutInterval: 120)
  183:                guard attempt + 1 < HTTPRetry.maxAttempts else {
  200:                    if attempt + 1 < HTTPRetry.maxAttempts else {
  ```
  No wall-clock deadline anywhere; `HTTPRetry.maxAttempts` is 3.
- **Do:** Also mine, from this afternoon — adding retries without a ceiling changed the worst case. A deck request that times out now does so three times with 2s and 4s backoff between: up to ~366 seconds during which `GeneratingView` shows a spinner and a stage label that never advances. Track a deadline at the top of `send` and stop retrying once it passes, and emit a progress event on each retry so the UI can say "connection dropped — retrying" instead of appearing hung.
- **Why:** The fix for one dropped socket should not turn a stalled network into six minutes of a UI that looks frozen and says nothing.
- **Effort:** S · **Impact:** M

### 4. The migration notice is lost if the user quits before seeing it

- **Location:** `Lectern/App/AppState.swift:83-93`
- **Proof:**
  ```swift
    func start() async {
        #if os(macOS)
        let moved = await Task.detached { Self.migrateLegacyDecks() }.value
        if moved > 0 {
            migrationNotice = "Moved \(moved) deck\(moved == 1 ? "" : "s") to Documents › Lectern."
        }
        #endif
        refreshLibrary()
    }
  ```
- **Verified:** `grep -n 'migrationNotice' App/AppState.swift App/ContentView.swift` →
  ```
  App/AppState.swift:79:    private(set) var migrationNotice: String?
  App/AppState.swift:82:    func dismissMigrationNotice() { migrationNotice = nil }
  App/AppState.swift:88:            migrationNotice = "Moved \(moved) deck\(moved == 1 ? "" : "s") to Documents › Lectern."
  ```
  In-memory only — no `UserDefaults`, no persistence.
- **Do:** Also mine. The migration is once-only and irreversible from the app's side: after it runs, `moved` is 0 forever. If the user quits before reading the notice — or never opens Compose that session — they are never told their 21 decks moved, and the old folder is gone. Persist a "migration announced" flag in `UserDefaults` and keep showing the notice until it is actually dismissed.
- **Why:** A one-shot message about relocating someone's documents should not depend on them looking at the right screen during the right launch.
- **Effort:** S · **Impact:** S

---

## Security

### 1. The macOS app ships with neither App Sandbox nor Hardened Runtime

- **Location:** `Lectern/project.yml:26-45` (the macOS target's `settings.base`)
- **Proof:**
  ```yaml
      settings:
        base:
          PRODUCT_BUNDLE_IDENTIFIER: com.lectern.app
          MARKETING_VERSION: "1.0"
          CURRENT_PROJECT_VERSION: "1"
          GENERATE_INFOPLIST_FILE: "YES"
          ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
          SWIFT_VERSION: "6.0"
          SWIFT_STRICT_CONCURRENCY: complete
  ```
- **Verified:** `grep -rn 'ENABLE_APP_SANDBOX\|ENABLE_HARDENED_RUNTIME\|com.apple.security' project.yml` → `# (no matches)`; `find . -name '*.entitlements' -not -path '*/.build*'` → `./App/Lectern-iOS-Sim.entitlements` — iOS simulator only. The macOS target has no entitlements file at all.
- **Do:** The app reads user-selected PDFs, holds API keys in the login keychain, calls three vendors, and renders generated markup in a WebKit process — unsandboxed, without hardened runtime. `AppState.attachPDF` already calls `startAccessingSecurityScopedResource()`, so the code is written *as if* sandboxed. Add an entitlements file with `com.apple.security.app-sandbox`, `files.user-selected.read-write` and `network.client`, and set `ENABLE_HARDENED_RUNTIME: "YES"`. **Sequence this after a decision on deck storage:** inside a sandbox `.documentDirectory` resolves to the container, which would put decks straight back into a hidden per-app folder and undo `AppState.swift:370-390`. Reaching the real `~/Documents` needs a user-chosen folder plus a security-scoped bookmark.
- **Why:** Without hardened runtime the app cannot be notarized and cannot ship; without the sandbox, a WebKit or PDFKit parsing bug is an unconfined foothold.
- **Effort:** M · **Impact:** L

### 2. Rejected drafts are written in the clear, under one fixed name, and never expire

- **Location:** `Lectern/Sources/LecternCore/Providers/DeckGenerator.swift:66-76`
- **Proof:**
  ```swift
    private static func keepRejectedDraft(_ json: String, in directory: URL) -> URL? {
        let url = directory.appendingPathComponent("rejected-draft.json")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try json.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }
  ```
- **Verified:** `grep -rn 'prune\|expire\|olderThan\|completeFileProtection\|FileProtection' Sources/LecternCore/ App/` → `# (no matches)`. The only `removeItem` calls are `DeckLibrary.swift:85` (user-initiated delete) and `DeckStorage.swift:68` (legacy folder cleanup) — neither touches diagnostics.
- **Do:** Half-fixed today: it now lands in `Lectern/Diagnostics` rather than among the user's documents, which was the urgent part. What remains is retention. The file is the model's rendering of the prompt plus up to 40,000 characters lifted from whatever PDF was attached, it keeps one fixed name so the newest silently replaces the last, and nothing ever deletes it — a failed generation from months ago is still sitting there in plaintext. Give it a per-run name, set `.completeFileProtection` on iOS, and prune anything older than a few days on launch.
- **Why:** Confidential source material persists indefinitely with no retention policy and no way for the user to know it exists.
- **Effort:** S · **Impact:** M

### 3. Slide previews render generated markup in WebKit with JavaScript enabled

- **Location:** `Lectern/App/SlidePreview.swift:48-56`
- **Proof:**
  ```swift
    @MainActor fileprivate func makeWebView() -> WKWebView {
        let view = WKWebView()
        #if os(iOS)
        view.scrollView.isScrollEnabled = false
        view.isOpaque = false
        view.backgroundColor = .clear
        #endif
        return view
    }
  ```
- **Verified:** `grep -rn 'allowsContentJavaScript\|WKWebViewConfiguration\|WKPreferences\|navigationDelegate' App/` → `# (no matches)`. Escaping on the producing side is correct (`Sources/Rostrum/Presentation/SVGRenderer.swift:746-757` escapes `&`, `<`, `>` in text content), so this is defense in depth, not a live exploit.
- **Do:** `WKWebView()` takes a default configuration in which `defaultWebpagePreferences.allowsContentJavaScript` is `true`. The markup is assembled from LLM output that may itself be grounded in an attacker-supplied PDF, and it loads into the app's own WebKit context. Construct with a `WKWebViewConfiguration` setting `allowsContentJavaScript = false`, and add a `WKNavigationDelegate` that cancels every navigation except the initial `loadHTMLString`. The comment at `:19-22` already argues the nil `baseURL` removes network and file access — closing off script execution completes that argument.
- **Why:** One missed escape anywhere in a 780-line renderer becomes script execution inside the app rather than a broken thumbnail, and the mitigation is three lines.
- **Effort:** S · **Impact:** M

### 4. Testing whether a key exists decrypts and copies the key

- **Location:** `Lectern/App/KeychainStore.swift:40-56` and `:81`
- **Proof:**
  ```swift
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
  ```
  with the existence test defined as a full read:
  ```swift
    static func hasKey(for provider: ProviderID) -> Bool { read(for: provider) != nil }
  ```
- **Verified:** `grep -n 'kSecReturnAttributes\|kSecReturnRef' App/KeychainStore.swift` → `# (no matches)`; `grep -c 'KeychainStore.hasKey' App/AppState.swift` → `6`
- **Do:** Every `hasKey` call materializes the plaintext API key into a Swift `String` — a heap allocation with no zeroing, retained until ARC gets round to it — purely to answer whether a key is present. Six call sites in `AppState` alone, two of them on the launch path. Add a dedicated existence query with `kSecReturnData: false` and `kSecReturnAttributes: true`, so the secret only leaves the keychain when it is genuinely about to be sent.
- **Why:** The app's most sensitive value is decrypted and copied into unmanaged memory dozens of times per session for no reason beyond a boolean, widening the window for a memory disclosure to matter.
- **Effort:** S · **Impact:** M

### 5. Generated decks on iOS are published to the Files app by default

- **Location:** `Lectern/project.yml:86-90`
- **Proof:**
  ```yaml
        # Generated decks land in Documents/Decks; these two make them visible
        # in the Files app (and to Finder file sharing) rather than trapped in
        # the sandbox.
        INFOPLIST_KEY_UIFileSharingEnabled: "YES"
        INFOPLIST_KEY_LSSupportsOpeningDocumentsInPlace: "YES"
  ```
- **Verified:** `grep -rn 'UIFileSharingEnabled\|LSSupportsOpeningDocumentsInPlace\|FileProtection' project.yml App/` →
  ```
  project.yml:89:        INFOPLIST_KEY_UIFileSharingEnabled: "YES"
  project.yml:90:        INFOPLIST_KEY_LSSupportsOpeningDocumentsInPlace: "YES"
  ```
  No file-protection class is set anywhere.
- **Do:** This is a deliberate, well-reasoned trade — it is how decks are reachable at all on iOS, and it should stay. What is missing is the other half: `UIFileSharingEnabled` exposes the whole Documents directory over USB file sharing to anything that can talk to the device, and the decks themselves carry no data-protection class, so they are readable whenever the device is unlocked and by a backup. Set `.completeFileProtectionUntilFirstUserAuthentication` on written decks, and keep anything that is not a user document (diagnostics especially) out of Documents — which the Diagnostics split already starts.
- **Why:** Decks are generated from the user's prompts and their private PDFs; publishing them over USB file sharing with no protection class is a broader grant than "let them see their files".
- **Effort:** S · **Impact:** M

---

## Usability

### 1. The compose screen's icon-only buttons are unlabelled for VoiceOver

- **Location:** `Lectern/App/ContentView.swift:197-199`
- **Proof:**
  ```swift
                    Button { app.clearPDF() } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).foregroundStyle(.secondary)
                }
  ```
- **Verified:** `grep -n 'accessibility' App/ContentView.swift` →
  ```
  117:                        .accessibilityLabel("Dismiss")
  121:                    .accessibilityElement(children: .combine)
  ```
  Both are on the migration notice I added today. The 401-line file's other controls — including this one — have none. The pattern exists elsewhere: `grep -rn 'accessibilityLabel' App/` also shows `SlidePreview.swift:108,139`, `StyleThumbnail.swift:84`, and `DeckLibrarySheet.swift:141,147,150`.
- **Do:** VoiceOver reads this as "xmark circle fill". Add `.accessibilityLabel("Remove PDF")`. `StylePickerSheet.swift:86` has the same unlabelled search-clear button. Then set `.accessibilityElement(children: .combine)` on each `Card` so a card reads as one unit rather than four fragments.
- **Why:** The PDF-grounding card is a primary flow and its only destructive control is unreachable by name — in an app that ships four dedicated accessibility *styles* (`contrastink`, `largeprint`, `nightreader`).
- **Effort:** S · **Impact:** M

### 2. The Mac app has no menu bar of its own

- **Location:** `Lectern/App/LecternApp.swift:88-110`
- **Proof:**
  ```swift
    var body: some Scene {
        WindowGroup("Lectern") {
            ContentView()
                .environment(app)
                #if os(macOS)
                .background(LaunchFrame())
                .onAppear { delegate.app = app }
                #endif
        }
        #if os(macOS)
        .defaultSize(width: 780, height: 1060)
        #endif
  ```
- **Verified:** `grep -rn '\.commands\|CommandGroup\|CommandMenu' App/` → `# (no matches)`. The whole keyboard surface is three shortcuts: `grep -rn 'keyboardShortcut' App/` →
  ```
  App/StylePickerSheet.swift:76:                .keyboardShortcut(.defaultAction)
  App/ContentView.swift:238:            .keyboardShortcut("l", modifiers: .command)
  App/ContentView.swift:246:            .keyboardShortcut(.return, modifiers: .command)
  App/DeckLibrarySheet.swift:80:                .keyboardShortcut(.defaultAction)
  ```
- **Do:** The app inherits SwiftUI's default File/Edit/View menus, full of items that do nothing here (New Window, Print, Undo). Add a `.commands { }` block: replace `CommandGroup(.newItem)` with "New Deck ⌘N" wired to `app.reset()`, add "Your Decks ⇧⌘L" and "Choose Style… ⇧⌘S", a "Open Decks Folder" item, and `CommandGroup(replacing: .help)` pointing at the README. Remove the inapplicable defaults.
- **Why:** Measured against the Raycast anchor, a keyboard-first Mac utility whose File menu is full of no-ops reads as a prototype rather than a Mac app.
- **Effort:** S · **Impact:** M

### 3. The failure screen is a dead end that throws away its own diagnosis

- **Location:** `Lectern/App/ContentView.swift:388-401`
- **Proof:**
  ```swift
    @Environment(AppState.self) private var app
    let message: String
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 44)).foregroundStyle(.orange)
            Text(message).font(.title3).multilineTextAlignment(.center).frame(maxWidth: 420)
            Button("Back to Compose") { app.reset() }.buttonStyle(.glassProminent).controlSize(.large)
        }
        .padding(48)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  ```
- **Verified:** `grep -rn 'Retry\|Try again\|Open Settings' App/` → `# (no matches)`
- **Do:** Every failure — rate limit, rejected key, dropped connection, truncated response, unparseable draft — funnels into one button that returns to the form. `AppState.describe` (`:352-378`) already knows exactly which `LecternError` occurred, then flattens it to a `String` and discards the type. Pass the `LecternError` itself into `FailedView` and branch: `.rateLimited` gets "Try again" with a countdown, `.authFailed`/`.noKey` get "Open Settings", `.networkOffline` a plain retry, `.responseTruncated` a "generate fewer slides" button that adjusts the stepper, and `.schemaInvalid` a "Show the rejected draft" that reveals the file whose path is currently sitting in the message as unclickable prose.
- **Why:** The most common failure is a rate limit, and it currently costs the user their place in the flow with no action available but starting over.
- **Effort:** S · **Impact:** M

### 4. The style gallery's search is hand-rolled, so none of the platform behaviour works

- **Location:** `Lectern/App/StylePickerSheet.swift:81-90`
- **Proof:**
  ```swift
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search 150 styles by name or vibe", text: $query)
                    .textFieldStyle(.plain)
                if !query.isEmpty {
                    Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary) }
                        .buttonStyle(.plain)
                }
            }
  ```
- **Verified:** `grep -rn 'searchable\|FocusState\|submitLabel' App/` → `# (no matches)`
- **Do:** Because it is a raw `TextField` rather than `.searchable`, the sheet opens with focus nowhere (you must click before typing), ⌘F does nothing, Esc does not clear, there is no scope bar for the tag chips, and iOS gets no search key on the keyboard. Replace with `.searchable(text: $query, placement: .toolbar, prompt: "Search 150 styles")`, add a `@FocusState` so the field is focused on presentation, and move `pillTags` into `.searchScopes` where it belongs.
- **Why:** Choosing among 150 styles is the app's most differentiated interaction, and reaching its search currently requires taking your hands off the keyboard.
- **Effort:** S · **Impact:** M

### 5. The longest screen in the app announces nothing and estimates nothing

- **Location:** `Lectern/App/ContentView.swift:268-284`
- **Proof:**
  ```swift
    @Environment(AppState.self) private var app
    var body: some View {
        VStack(spacing: 18) {
            ProgressView().controlSize(.large)
            Text(app.stage).font(.title3.weight(.semibold)).contentTransition(.opacity)
            if app.total > 0 {
                ProgressView(value: Double(app.drafted), total: Double(app.total))
                    .frame(maxWidth: 280)
                Text("\(app.drafted) of \(app.total) \(app.progressNoun)").font(.callout).foregroundStyle(.secondary)
            }
            Button("Cancel", role: .cancel) { app.cancel() }.buttonStyle(.glass)
        }
        .padding(48)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  ```
- **Verified:** `grep -n 'accessibilityValue\|AccessibilityNotification\|announce\|elapsed\|ETA' App/ContentView.swift` → `# (no matches)`
- **Do:** Nothing here is announced when it changes, so a VoiceOver user hears silence for a multi-minute generation and cannot distinguish progress from a hang. Add `.accessibilityElement(children: .combine)` with an `.accessibilityValue` built from `stage` and `drafted/total`, and post an `AccessibilityNotification.Announcement` from `AppState.apply(_:)` on each stage change. Separately: `stage` moves through ten named phases with no elapsed time and no estimate, and `PriceTable.estimate` already models deck size well enough to produce a rough one.
- **Why:** The screen users spend the most time on is the least communicative, and for a VoiceOver user it is entirely opaque.
- **Effort:** S · **Impact:** M

---

## Attractiveness / Sexiness

Anchor: **Raycast** — a single-window Mac utility that feels instant, teaches itself on first launch, and treats motion as feedback rather than decoration.

### 1. A Liquid Glass app with a flat, pre-26 app icon

- **Location:** `Lectern/App/Assets.xcassets/AppIcon.appiconset/Contents.json`
- **Proof:**
  ```json
  {
    "images" : [
      { "idiom" : "mac", "scale" : "1x", "size" : "16x16", "filename" : "icon_16.png" },
      { "idiom" : "mac", "scale" : "2x", "size" : "16x16", "filename" : "icon_32.png" },
  ```
  …through to:
  ```json
      { "idiom" : "universal", "platform" : "ios", "size" : "1024x1024", "filename" : "icon_1024.png" }
    ],
    "info" : { "author" : "xcode", "version" : 1 }
  }
  ```
- **Verified:** `find . -name '*.icon' -not -path '*/.build*'` → `# (no matches)`; `ls App/Assets.xcassets/AppIcon.appiconset/` → `Contents.json  icon_1024.png  icon_128.png  icon_16.png  icon_256.png  icon_32.png  icon_512.png  icon_64.png` — seven flat PNGs, no layered source.
- **Do:** Both targets deploy at 26.0 and the UI commits to Liquid Glass throughout (`.buttonStyle(.glass)`, `.glassProminent`, `.regularMaterial` cards). The icon is the one surface that did not come along: a flat pre-26 `.appiconset` gets none of the specular, depth, or tinted/clear/dark treatments the system now applies. Rebuild it in Icon Composer as a layered `.icon` and point `ASSETCATALOG_COMPILER_APPICON_NAME` at it.
- **Why:** The icon is the first and most-repeated impression — Dock, Spotlight, App Switcher — and it is currently the only part of the product that looks older than the OS it targets.
- **Effort:** M · **Impact:** M

### 2. The four principal states cut hard, with no transition

- **Location:** `Lectern/App/ContentView.swift:41-48`
- **Proof:**
  ```swift
    @ViewBuilder private var phaseView: some View {
        switch app.phase {
        case .compose: ComposeView()
        case .generating: GeneratingView()
        case .result(let r): ResultView(result: r)
        case .failed(let m): FailedView(message: m)
        }
    }
  ```
- **Verified:** `grep -n 'animation\|transition\|withAnimation\|matchedGeometry' App/ContentView.swift` → `# (no matches)`. The app animates in exactly one place: `grep -rn 'withAnimation\|\.animation(' App/` → `App/Theme.swift:88:        withAnimation(.easeOut(duration: 0.2)) { image = loaded }`
- **Do:** The entire user journey swaps instantaneously — pressing Generate replaces a full form with a spinner in a single frame, and the finished deck arrives with the same abruptness. Wrap the switch in `.animation(.smooth, value: app.phase)` and give each branch an asymmetric transition (compose pushes out, generating fades up, result scales in from the progress indicator). A `matchedGeometryEffect` from the Generate button to the progress ring would make the causal link explicit.
- **Why:** State changes are where a native app earns its feeling of quality; four hard cuts make a carefully built product feel like four screens bolted together.
- **Effort:** S · **Impact:** M

### 3. First launch is a form you cannot submit

- **Location:** `Lectern/App/ContentView.swift:225-232`, gated by `Lectern/App/AppState.swift:262-264`
- **Proof:**
  ```swift
    var canGenerate: Bool {
        phase != .generating && hasKey && !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
  ```
  and the only guidance offered:
  ```swift
                if !app.hasKey {
                    Label("Add an API key in \(AppState.settingsHint) to generate", systemImage: "key")
                        .font(.callout).foregroundStyle(.secondary)
  ```
- **Verified:** `grep -rn 'onboard\|firstRun\|hasLaunched\|AppStorage\|welcome' App/*.swift` → `# (no matches)`
- **Do:** A new user opens a 780×1060 window showing five cards, a dimmed Generate button, and a line of grey text naming a menu item they must find themselves — and that label is not even a button. Build a first-run state: one welcoming panel explaining what Lectern does, a control that opens Settings directly at the key field (making that `Label` a `Button` is the minimum), and two or three of the best style thumbnails as a preview of what they are buying. Gate it on `@AppStorage("hasCompletedOnboarding")`.
- **Why:** First run is the only moment every user is guaranteed to reach, and it currently presents a locked door with the key described in small grey text.
- **Effort:** M · **Impact:** L

### 4. The longest wait is a bare spinner, and the outline it could show is discarded

- **Location:** `Lectern/App/ContentView.swift:271-279`, against `Lectern/App/AppState.swift:326-338`
- **Proof:**
  ```swift
        VStack(spacing: 18) {
            ProgressView().controlSize(.large)
            Text(app.stage).font(.title3.weight(.semibold)).contentTransition(.opacity)
            if app.total > 0 {
                ProgressView(value: Double(app.drafted), total: Double(app.total))
                    .frame(maxWidth: 280)
                Text("\(app.drafted) of \(app.total) \(app.progressNoun)").font(.callout).foregroundStyle(.secondary)
            }
  ```
- **Verified:** `grep -n 'case .outlineReady' App/AppState.swift` →
  ```
  330:        case .outlineReady: stage = "Outline ready"
  ```
  The associated `DeckOutline` — title, sections, slide stubs — is not bound and not stored; `grep -c 'DeckOutline' App/AppState.swift` → `0`.
- **Do:** The pipeline emits a genuinely interesting narrative — outlining, drafting, validating, repairing, polishing, illustrating, rendering — and the UI flattens all ten stages into one line of text over a generic spinner. Show them as a checklist that fills in. The real prize is line 330: `outlineReady` carries the actual `DeckOutline` and the handler ignores its payload entirely. Bind it, and reveal the deck's title and section names the moment they land, then let slide thumbnails populate as they render.
- **Why:** A multi-minute wait is the app's biggest engagement risk and its biggest opportunity, and the data for a compelling progressive reveal is already arriving and being dropped one line short of the screen.
- **Effort:** M · **Impact:** L

### 5. The payoff screen is buried under four collapsible caveat drawers

- **Location:** `Lectern/App/ContentView.swift:322-380`
- **Proof:**
  ```swift
            if !result.warnings.isEmpty {
                DisclosureGroup("\(result.warnings.count) validation warning(s)") {
  ```
  followed in sequence by:
  ```swift
            if !result.droppedContent.isEmpty {
                DisclosureGroup("\(result.droppedContent.count) slide(s) lost content to layout limits") {
  ```
  ```swift
            if !result.schemaIssues.isEmpty {
                DisclosureGroup("\(result.schemaIssues.count) schema issue(s) in the written deck") {
  ```
  ```swift
            if !result.unmeasuredFonts.isEmpty {
                DisclosureGroup("\(result.unmeasuredFonts.count) font(s) not installed") {
  ```
- **Verified:** `grep -c 'DisclosureGroup' App/ContentView.swift` → `4`
- **Do:** The taxonomy behind these four buckets is genuinely excellent, and the comments justifying the separation are the best writing in the file — but the user's moment of delight is "my deck is ready", and it arrives stacked beneath up to four grey accordions of caveats. Collapse them behind a single quiet "Details" affordance with an inline badge, give the contact sheet the full height, and make Open/Share the visual anchor. Keep all four categories intact *inside* the panel, where their precision is a feature rather than an apology.
- **Why:** This is the screen the entire product exists to reach; against the Raycast anchor it should feel like an arrival, not a lint report.
- **Effort:** S · **Impact:** M

---

## First move

**A cancelled generation's completion clobbers the run that replaced it** (from Stability)

Ship this first because it is the only item here that can silently destroy work the user has already paid for, and because the fix is an afternoon. Cancel a generation, start another, and the first task's `catch` — running some indeterminate time later, since cancellation is cooperative — writes `.compose` or `.failed` over the live `.generating` state. The user watches their in-flight run vanish from the screen for no visible reason; the generation itself keeps going, keeps spending, and lands its result into a phase nobody is showing. There is no route back to that deck: the library only lists what reached disk, and this one may never get there. It ranks above the sandbox work (larger, and genuinely blocked on the deck-storage decision it would undo), above the provider gaps (multi-day), and above the retry and diagnostics items (real but lower stakes) because it is small, self-contained, and the pattern is already in this exact file — `validateImageKey` guards its late writes at lines 205 and 208, so the fix is to apply a known local idiom to the three terminal writes at 314-318. Doing it also unblocks Stability #2, which is the same bug in a second function, and makes the Reliability #3 retry work safe: adding retries lengthens the window during which a stale task can resolve over a live one.

## Dropped during verification

- **Anthropic retries once with a flat delay** — already fixed. `grep -n 'HTTPRetry' Sources/LecternCore/Providers/AnthropicProvider.swift` shows the shared policy in use; `HTTPRetry.swift:15-32` provides three attempts with exponential backoff. Landed today in `0f595d3`.
- **`max_tokens` is a flat 8,192 and truncation is silent** — already fixed. `grep -n 'stop_reason\|outputTokenBudget' Sources/LecternCore/Providers/AnthropicProvider.swift` → `48:"max_tokens": Self.outputTokenBudget(for: request)`, `104:obj["stop_reason"] as? String == "max_tokens"`.
- **Image generation fans out with no ceiling** — already fixed. `grep -n 'inFlightLimit' Sources/LecternCore/Providers/DeckGenerator.swift` → `126: let inFlightLimit = max(1, imageProvider.id.maximumConcurrentRequests)`.
- **Decks accumulate with no way to see them** — already fixed. `Sources/LecternCore/Storage/DeckLibrary.swift` and `App/DeckLibrarySheet.swift` now exist, reachable at ⌘L.
- **Decks are written to Application Support** — already fixed. `AppState.swift:370-390` writes to `~/Documents/Lectern` with a one-time migration.
- **`rejected-draft.json` is written among the user's decks** — partially fixed, so the *location* half is dropped and only retention survives, as Security #2. `grep -n 'diagnostics' Sources/LecternCore/Providers/DeckGenerator.swift` → `:34 diagnostics: URL? = nil` and `:57 in: diagnostics ?? directory`.
- **`outputURL` has a check-then-write race** — unreachable. `AppState.generate()` opens with `guard phase != .generating else { return }` (`:268`), so two generations cannot overlap, and nothing else in the target calls `render`. Would be real if concurrent generation were ever added; not real today.
- **`DeckNormalizer` could mangle prose into stat tiles** — cited code does something else. `promoteNumericBullets` requires `stats.count == bullets.count` (`DeckNormalizer.swift:170`), so it fires only when *every* bullet parses as a figure, and `leadingStat` rejects a lone number with no caption.
- **`StyleCatalog.palette` could loop forever on malformed markdown** — provably terminates. The scan reassigns `scan = rest` after each `#`, where `rest` is strictly shorter, so the loop advances even when no hex digits follow.

## Deferred

- **`DeckRenderer.swift` is 911 lines** — nearly twice the next-largest file in the target, and the single place where IR, layout, furniture, fonts, charts, scrims and previews all meet. Not a defect; the obvious split is previews and font resolution, both self-contained.
- **`LecternCoreTests.swift` is 1,495 lines in one suite** — 73% of the test target in a single file, now spanning rendering, validation, providers, retry and fonts. The three newer files (`DeckStorageTests`, `DeckLibraryTests`, `DeckNormalizerTests`) show the better shape.
- **No UI tests at all** — every test targets `LecternCore`; `App/` has none, which is why the Linux break and both Apple-platform regressions this week were caught by compilation rather than by a test.
- **`PDFGrounding.extract` calls `text.count` per page** — an O(n) grapheme walk inside the page loop. Bounded by `maxChars` so it is not pathological, but `text.utf8.count` would be O(1)-ish and exact for the purpose.
- **`Lectern/README.md:127` still describes decks as living in `Documents/Decks`** — true for iOS, stale for macOS since this afternoon's move to `~/Documents/Lectern`.
