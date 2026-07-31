# Lift-Up Plan: Rostrum + Lectern

> Platform: mixed — `Rostrum`, a zero-dependency Swift library (macOS 13 / iOS 16 / Linux), plus `Lectern`, a SwiftUI app (macOS 26 / iOS 26) that consumes it
> Surveyed: 2026-07-31
> Coverage: partial — full read of `Lectern/App`, `Lectern/Sources/LecternCore`, `Sources/Rostrum/{XML,Zip,OPC,Core}`, `Presentation/{Presentation,SVGRenderer}.swift`, CI, and `project.yml`. Not read end-to-end: `Sources/Rostrum/Presentation/SlideBuilders.swift` (975 lines), `Charts/*` (2,436 lines), `Schema/GeneratedSchema.swift` (mechanically generated), `Tools/*`, and the 12,858-line test corpus beyond structural greps.
> Attractiveness anchor: inferred — **Raycast** (single-window Mac utility: keyboard-first, instant, calm density, a first run that teaches itself)

A note on tone before the list: this is an unusually disciplined codebase. Sixteen thousand lines of library with **two** `try!` (both provably safe by construction), **zero** force-unwraps, zero TODOs, zip-bomb limits, coordinate-overflow bounding, and an XXE guard already in place. Seven candidates were dropped during verification because the fix was already there. The findings below are therefore mostly about the seams — the app layer, the async lifecycle, and one genuine hole in the library's untrusted-input defenses.

---

## Performance

### 1. Every keystroke in the style picker re-filters 150 styles three times

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
- **Verified:** `grep -n 'filtered\|@State private var query\|debounce\|searchable' Lectern/App/StylePickerSheet.swift` →
  ```
  9:    @State private var query = ""
  35:    private var filtered: [Style] { app.styles.filter(matches) }
  36:    private var favorites: [Style] { filtered.filter { app.isFavorite($0.slug) } }
  37:    private var recents: [Style] { app.recents.compactMap { slug in filtered.first { $0.slug == slug } } }
  48:                        if !favorites.isEmpty { section("Favorites", favorites) }
  49:                        if !recents.isEmpty { section("Recents", recents) }
  50:                        section(activeTag == nil && query.isEmpty ? "All \(app.styles.count)" : "\(filtered.count) results", filtered)
  ```
  No debounce, no memoization, no `searchable`.
- **Do:** `filtered` is a computed property, so `body` evaluates it at lines 48, 49, 50 (twice) — four full passes over 150 styles per keystroke, and `matches` re-runs `query.trimmingCharacters(...).lowercased()` inside the loop, allocating a fresh String 600 times per character typed. Hoist the normalized query out of `matches` into a computed `normalizedQuery`, and compute `filtered` once into a `let` at the top of `body` (or an `@State` updated in `.onChange(of: query)`), then derive `favorites`/`recents` from that single array.
- **Why:** Search in a 150-item gallery is the picker's primary interaction, and it currently does ~600 string allocations and 4 array copies per keypress on the main actor.
- **Effort:** S · **Impact:** M

### 2. The contact sheet spawns one WKWebView — and one web content process — per slide

- **Location:** `Lectern/App/SlidePreview.swift:48-56`, used from `SlideContactSheet` at `Lectern/App/SlidePreview.swift:92-101`
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
- **Verified:** `grep -n 'WKProcessPool\|WKWebViewConfiguration\|ImageRenderer\|snapshot\|takeSnapshot' Lectern/App/SlidePreview.swift` → `# (no matches)`
- **Do:** A 40-slide deck (the `slideCount` ceiling is `3...40`, `ContentView.swift:206`) instantiates up to 40 `WKWebView`s, each backed by its own WebKit content and networking process. `LazyVGrid` defers creation but never tears them down once scrolled. Render each SVG once to a bitmap via `WKWebView.takeSnapshot(with:)` (or rasterize off-main and cache a `CGImage`), then show plain `Image` views in the grid; keep a live web view only for a full-size single-slide inspector. Failing that, share one `WKProcessPool` via `WKWebViewConfiguration` and cap concurrent live views.
- **Why:** Forty web content processes for forty static pictures is hundreds of megabytes and a visible scroll stutter on the deck-review screen users land on after every generation.
- **Effort:** M · **Impact:** L

### 3. Full-resolution generated images are base64-embedded into every 640px preview

- **Location:** `Sources/Rostrum/Presentation/SVGRenderer.swift:297`
- **Proof:**
  ```swift
        guard let media = package.parts[target] else { return "" }
        let ext = target.ext.lowercased()
        let mime = ext == "jpg" || ext == "jpeg" ? "image/jpeg" : ext == "gif" ? "image/gif" : "image/png"
        let data = media.blob.base64EncodedString()
        return "<image x=\"\(x)\" y=\"\(y)\" width=\"\(w)\" height=\"\(h)\" "
            + "preserveAspectRatio=\"xMidYMid slice\" href=\"data:\(mime);base64,\(data)\"/>"
    }
  ```
- **Verified:** `grep -rn 'base64EncodedString\|downsample\|thumbnail\|CGImageSourceCreateThumbnail' Sources/Rostrum/` →
  ```
  Sources/Rostrum/Presentation/SVGRenderer.swift:297:        let data = media.blob.base64EncodedString()
  ```
  Only one call site; no downsampling anywhere in the library.
- **Do:** `DeckRenderer` calls `renderSVG(slideAt:pixelWidth: 640)` (`DeckRenderer.swift:74`) while `GeminiImageProvider` requests `"image_size": "2K"` (`GeminiImageProvider.swift:66`). Each preview string therefore carries a whole 2K JPEG inflated 1.33× by base64 — for a 640px thumbnail. Add a `maxImagePixels` parameter to `renderSVG` that downsamples the blob (ImageIO on Apple platforms, a nearest-neighbour box filter on Linux to keep the zero-dependency rule) before encoding, defaulting to the render width.
- **Why:** `DeckResult.previews` is `[String]` held in memory and pushed into N web views; at 2K source images a 20-slide illustrated deck is tens of megabytes of base64 text for pictures displayed at 640px.
- **Effort:** M · **Impact:** L

### 4. Slide previews render strictly serially

- **Location:** `Lectern/Sources/LecternCore/Rendering/DeckRenderer.swift:72-76`
- **Proof:**
  ```swift
    private static func previews(of presentation: Presentation) -> [String] {
        (0..<presentation.slides.count).compactMap { index in
            try? presentation.renderSVG(slideAt: index, pixelWidth: 640)
        }
    }
  ```
- **Verified:** `grep -n 'withTaskGroup\|concurrentPerform\|DispatchQueue' Lectern/Sources/LecternCore/Rendering/DeckRenderer.swift` → `# (no matches)`
- **Do:** This runs after the `.pptx` is already saved, so it is pure added latency on the last step before the user sees anything — and it includes the base64 work from item 3. `Presentation` is deliberately non-`Sendable` and must not leave the actor, so the parallelism has to come from below: extract the per-slide SVG render into a value-typed input (slide XML + resolved theme + media blobs), then fan out with `DispatchQueue.concurrentPerform` or a `TaskGroup` over those values.
- **Why:** On a 40-slide illustrated deck this is the difference between the result screen appearing instantly and appearing after several seconds of apparently-finished-but-frozen UI.
- **Effort:** M · **Impact:** M

### 5. Launch reads all 150 design.md files in full to parse six header fields

- **Location:** `Lectern/Sources/LecternCore/StyleCatalog/StyleCatalog.swift:77`
- **Proof:**
  ```swift
    private func parse(slug: String, designURL: URL, thumbnail: URL?) -> Style {
        let text = (try? String(contentsOf: designURL, encoding: .utf8)) ?? ""
        // YAML frontmatter takes precedence when present.
        if let front = frontmatter(text) {
  ```
- **Verified:** `cat Lectern/App/Resources/Styles/*.md | wc -c` → `1449192`; `ls Lectern/App/Resources/Styles/*.md | wc -l` → `150`; `grep -rn 'cache\|Cache\|manifest\|index.json' Lectern/Sources/LecternCore/StyleCatalog/StyleCatalog.swift` → `# (no matches)`
- **Do:** 1.45 MB of markdown is read and fully decoded to UTF-8 at every launch to extract name, vibe, category, theme, palette and font — all of which live in the first ~40 lines. It is correctly off-main (`AppState.loadStyles` wraps it in `Task.detached`), so this is latency-to-first-gallery, not a hang. Generate a `styles-index.json` manifest at build time (a script in `Lectern/scripts/`, consistent with the existing `build-ios.sh` convention) and have `StyleCatalog` load that, falling back to the current directory scan when the manifest is absent.
- **Why:** The style picker is the app's signature surface; it should be populated before the user can reach it, not after a 1.45 MB parse.
- **Effort:** M · **Impact:** S

---

## Functionality

### 1. Three of the four advertised providers are not implemented

- **Location:** `Lectern/Sources/LecternCore/Providers/ProviderFactory.swift:19-25`
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
- **Verified:** `grep -rn 'struct OpenAIProvider\|struct GeminiProvider\|struct CustomProvider' Lectern/Sources/` → `# (no matches)` (only `OpenAIImageProvider` and `GeminiImageProvider`, which are image-only and conform to `ImageProvider`, not `LLMProvider`).
- **Do:** `ProviderID` has four cases, Settings renders all four in the picker with a "(soon)" suffix, and `Theme.swift:29-35` gives each a polished display label — the whole surface is built for a capability that does not exist. `AnthropicProvider` is only 143 lines and the `LLMProvider` protocol is already the right seam, so port it to OpenAI's chat-completions + `tools` and Gemini's `generateContent` + `functionDeclarations`. Alternatively, cut the dead cases from `ProviderID` until they ship.
- **Why:** Every user who owns an OpenAI key sees it offered, selects it, pastes a key, and hits a dead end — the app advertises four doors and opens one.
- **Effort:** L · **Impact:** L

### 2. Generated decks accumulate on disk with no way to see them again

- **Location:** `Lectern/App/AppState.swift:332-345`
- **Proof:**
  ```swift
    static func decksDirectory() -> URL {
        #if os(iOS)
        // Documents, not Application Support: with UIFileSharingEnabled +
        // LSSupportsOpeningDocumentsInPlace the decks show up in the Files app,
        // which is the iOS equivalent of "Reveal in Finder".
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("Decks", isDirectory: true)
  ```
- **Verified:** `grep -rn 'contentsOfDirectory' Lectern/App/ Lectern/Sources/` →
  ```
  Lectern/Sources/LecternCore/Rendering/DeckRenderer.swift:251:            guard let files = try? FileManager.default.contentsOfDirectory(
  Lectern/Sources/LecternCore/StyleCatalog/StyleCatalog.swift:47:        let entries = (try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey])) ?? []
  ```
  Line 251 enumerates Office **font** directories; line 47 enumerates **styles**. Nothing ever lists `decksDirectory()`.
- **Do:** `ContentView.swift:34` comments "No sidebar — there's no deck History to show, so a single pane is honest." The honesty is admirable but the decks are right there. Add a `DeckLibrary` that lists `decksDirectory()` sorted by creation date, with the stored `DeckIR` JSON beside each `.pptx` so a deck can be reopened, re-rendered in a different style, or re-generated. On macOS, restore the sidebar; on iOS, add a second tab.
- **Why:** Once you hit "New" the previous deck is unreachable inside the app, and each one cost a real API call — the product forgets everything the user paid for.
- **Effort:** L · **Impact:** L

### 3. The key-validation call fetches the live model list and throws it away

- **Location:** `Lectern/App/AppState.swift:44-47` and `Lectern/App/AppState.swift:190-196`
- **Proof:**
  ```swift
    static func defaultModels(for id: ProviderID) -> [String] {
        switch id {
        case .anthropic: return ["claude-opus-4-8", "claude-sonnet-5", "claude-fable-5", "claude-haiku-4-5-20251001"]
        default: return []
        }
    }
  ```
  and:
  ```swift
    func validateKey() async {
        guard let key = KeychainStore.read(for: providerID) else { keyStatus = .invalid("No key stored."); return }
        keyStatus = .validating
        do {
            let models = try await AnthropicModels.list(apiKey: key)
            keyStatus = .valid(models.count)
        } catch {
  ```
- **Verified:** `grep -n 'AnthropicModels.list\|modelOptions\|defaultModels' Lectern/App/AppState.swift` →
  ```
  44:    static func defaultModels(for id: ProviderID) -> [String] {
  53:    var modelOptions: [String] { Self.defaultModels(for: providerID) }
  194:            let models = try await AnthropicModels.list(apiKey: key)
  ```
  `models` is consumed only as `.count`; `modelOptions` never reads it.
- **Do:** The curation rationale at lines 40-43 is sound — the raw `/v1/models` dump is noisy. But the consequence is that a new model requires an app rebuild, and the hardcoded list will silently rot (`claude-fable-5` and `claude-opus-4-8` are already unverifiable against the live account). Intersect the fetched list with a curated *prefix* allowlist rather than an exact-match list, so new point releases appear automatically while EAP builds stay hidden, and surface anything in the list that the account can no longer access.
- **Why:** A deck generator whose model menu is a compile-time constant is one provider release away from offering only models the user cannot call.
- **Effort:** S · **Impact:** M

### 4. PDF grounding takes one document, silently caps at 40k characters, and cannot read scans

- **Location:** `Lectern/App/PDFGrounding.swift:24-37`
- **Proof:**
  ```swift
    static func extract(from url: URL) async -> Source? {
        await Task.detached(priority: .userInitiated) { () -> Source? in
            guard let doc = PDFDocument(url: url) else { return nil }
            var text = ""
            for i in 0..<doc.pageCount {
                if let page = doc.page(at: i), let s = page.string { text += s + "\n" }
                if text.count > maxChars { break }
            }
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            let truncated = trimmed.count > maxChars
            return Source(name: url.lastPathComponent,
                          text: String(trimmed.prefix(maxChars)),
                          pageCount: doc.pageCount,
                          truncated: truncated)
        }.value
    }
  ```
- **Verified:** `grep -rn 'VNRecognizeText\|Vision\|OCR\|\[URL\]\|grounding\b' Lectern/App/AppState.swift Lectern/App/PDFGrounding.swift` →
  ```
  Lectern/App/AppState.swift:57:    private(set) var grounding: PDFGrounding.Source?
  Lectern/App/AppState.swift:216:    func attachPDF(_ url: URL) async {
  Lectern/App/AppState.swift:229:    func clearPDF() { grounding = nil; groundingError = nil }
  ```
  `grounding` is a single optional, not a collection; no Vision import anywhere.
- **Do:** Three gaps, ordered by value. (a) The loop breaks at 40k chars so a 300-page report contributes only its opening pages, while the UI still reports the full `doc.pageCount` — front-load a cheap extractive summary or chunk-and-rank by query relevance instead of truncating positionally. (b) Accept multiple PDFs by making `grounding` an array — `fileImporter` needs only `allowsMultipleSelection: true`. (c) Route the "no selectable text" case through `VNRecognizeTextRequest` rather than telling the user "scans need OCR" and stopping.
- **Why:** "Ground the deck on real facts" is the feature that separates this from a chat prompt, and today it reads the first 12 pages of one text-layer PDF.
- **Effort:** M · **Impact:** M

### 5. A finished deck cannot be adjusted — only regenerated from scratch

- **Location:** the compose → result flow, `Lectern/App/ContentView.swift:41-47` and `Lectern/App/AppState.swift:286`
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
  and the only exit from `.result`:
  ```swift
    func reset() { stage = ""; drafted = 0; total = 0; phase = .compose }
  ```
- **Verified:** `grep -rn 'regenerate\|reroll\|editSlide\|func revise' Lectern/App/ Lectern/Sources/LecternCore/` →
  ```
  Lectern/Sources/LecternCore/Providers/AnthropicProvider.swift:56:    public func revise(_ request: DeckRequest, deckJSON: String,
  Lectern/Sources/LecternCore/Providers/Providers.swift:79:    func revise(_ request: DeckRequest, deckJSON: String,
  Lectern/Sources/LecternCore/Providers/Providers.swift:85:    func revise(_ request: DeckRequest, deckJSON: String,
  ```
  `revise` exists but is called only internally by the QA pass (`DeckGenerator.swift:82`); no user-facing entry point.
- **Do:** The four-state phase machine is terminal at `.result` — the only affordance is "New", which discards the deck and starts a fresh paid generation. `provider.revise(_:deckJSON:emit:)` is already implemented and already round-trips a whole deck through the schema. Expose it: let the user tap a slide in the contact sheet, type an instruction, and re-render. Persist the validated `DeckIR` JSON next to the `.pptx` so this survives relaunch.
- **Why:** One bad slide in twenty currently costs a full regeneration at full price, with no guarantee the other nineteen survive intact.
- **Effort:** L · **Impact:** L

---

## Stability

**4 items, not 5.** A fifth candidate — "a cancel during the QA pass is swallowed and the deck renders anyway" — was investigated and dropped during verification once the renderer's own cancellation handling was read in full (see *Dropped during verification*). Rather than pad, this dimension ships four. That is the honest count for a library with two `try!` (both provably safe), zero force-unwraps, and zero TODOs across 16,179 lines.

### 1. A cancelled generation's completion handler clobbers the state of the run that replaced it

- **Location:** `Lectern/App/AppState.swift:246-286`
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
- **Verified:** `grep -n 'guard self.providerID == \|guard imageProviderID == id\|generation ==\|epoch\|token' Lectern/App/AppState.swift` →
  ```
  169:            guard imageProviderID == id else { return }
  172:            guard imageProviderID == id else { return }
  254:                        if self.imageProviderID == imageID { self.imageKeyStatus = .valid }
  256:                        if self.imageProviderID == imageID {
  ```
  Identity guards exist in `validateImageKey` (169, 172) and for `imageKeyStatus` inside `generate` (254, 256) — but none guards the terminal `phase` writes at 276-281.
- **Do:** Cancellation is cooperative, so the old task's `catch` block runs some time *after* `cancel()` returns. If the user cancels and immediately regenerates, the stale task resolves and writes `phase = .compose` (or `.failed`) over the live `.generating` run, dropping the UI back to the compose form while a paid generation continues invisibly. Add a monotonically increasing `generationID`, capture it in the task, and guard every terminal write with `guard self.generationID == captured else { return }` — the same pattern already used correctly at line 169.
- **Why:** The user sees their in-flight generation vanish from the screen for no reason, and has no way to reach the deck it eventually produces.
- **Effort:** S · **Impact:** M

### 2. `validateKey()` is missing the provider guard its image-side twin has

- **Location:** `Lectern/App/AppState.swift:190-201`
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
- **Verified:** `sed -n '160,176p' Lectern/App/AppState.swift` (the image equivalent) →
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
  `validateImageKey` captures `let id = imageProviderID` up front and guards both branches; `validateKey` captures nothing and guards nothing.
- **Do:** Capture `let id = providerID` before the `await`, then guard both the success and failure writes with `guard providerID == id else { return }`. Note `selectProvider` (line 121) already resets `keyStatus = .unknown`, so a late write actively overwrites a correct reset with a stale verdict.
- **Why:** Switching provider in Settings while a validation is in flight paints a green "Valid · 4 models" (or a red rejection) against the wrong provider's key — the one state in Settings a user has to trust.
- **Effort:** S · **Impact:** S

### 3. A missing Styles resource folder degrades to zero styles with no error anywhere

- **Location:** `Lectern/App/AppState.swift:88-93`, with `Lectern/Sources/LecternCore/StyleCatalog/StyleCatalog.swift:47`
- **Proof:**
  ```swift
    func loadStyles() async {
        guard styles.isEmpty, let dir = Bundle.main.resourceURL?.appendingPathComponent("Styles") else { return }
        let loaded = await Task.detached { (try? StyleCatalog().load(from: dir)) ?? [] }.value
        styles = loaded
        if selectedStyleSlug == nil { selectedStyleSlug = recents.first ?? loaded.first?.slug }
    }
  ```
  and, one layer down:
  ```swift
        let entries = (try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey])) ?? []
  ```
- **Verified:** `grep -n 'stylesError\|styleLoadFailed\|ContentUnavailableView' Lectern/App/AppState.swift Lectern/App/ContentView.swift` → `# (no matches)`
  (the only `ContentUnavailableView` in the app is `StylePickerSheet.swift:46`, for an empty *search result*, not a load failure.)
- **Do:** Three `try?`-to-default conversions stack up: a missing bundle folder, an unreadable directory, and an unreadable file each degrade silently. The result is `styles == []`, `selectedStyleSlug == nil`, and `generate()` proceeding with `styleSlug: "default"` and `designURL: nil` — an unstyled deck with no indication anything went wrong, while the picker cheerfully says "Search 150 styles". Add a `styleLoadError: String?` to `AppState`, set it when `load` throws or returns empty, and surface it on the STYLE card in `ComposeView`.
- **Why:** A resource-bundling regression in the Xcode project would ship an app that quietly produces unstyled decks and passes every headless test, because `LecternCoreTests` uses its own fixtures rather than the app bundle.
- **Effort:** S · **Impact:** M

### 4. Synchronous Keychain reads run on the main actor, including at launch

- **Location:** `Lectern/App/AppState.swift:74-81`, calling `Lectern/App/KeychainStore.swift:40-56`
- **Proof:**
  ```swift
        favorites = Set(d.stringArray(forKey: Keys.favorites) ?? [])
        recents = d.stringArray(forKey: Keys.recents) ?? []
        useSmartArt = d.bool(forKey: Keys.useSmartArt)
        hasKey = KeychainStore.hasKey(for: providerID)
        hasImageKey = KeychainStore.hasKey(forImage: imageProviderID)
    }
  ```
  and `hasKey` resolves to a blocking `SecItemCopyMatching`:
  ```swift
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
  ```
- **Verified:** `grep -n 'KeychainStore.read\|KeychainStore.hasKey' Lectern/App/AppState.swift` →
  ```
  79:        hasKey = KeychainStore.hasKey(for: providerID)
  80:        hasImageKey = KeychainStore.hasKey(forImage: imageProviderID)
  124:        hasKey = KeychainStore.hasKey(for: id)
  131:        hasKey = KeychainStore.hasKey(for: providerID)
  147:        hasImageKey = KeychainStore.hasKey(forImage: imageProviderID)
  191:        hasImageKey = KeychainStore.hasKey(forImage: imageProviderID)
  243:        hasKey = KeychainStore.hasKey(for: providerID)
  244:        hasImageKey = KeychainStore.hasKey(forImage: imageProviderID)
  ```
  `AppState` is `@MainActor` (line 9), so all eight are main-thread; `KeychainStore` exposes no async variant.
- **Do:** `AppState.init()` runs during `LecternApp`'s `@State` initialization, so two blocking `SecItemCopyMatching` calls sit on the launch path. If the login keychain is locked — a normal state after a cold boot on macOS — the call blocks the main thread behind a system unlock prompt before the first frame draws. Worse, `hasKey` reads the *entire secret* just to test existence. Add `kSecReturnData: false` + `kSecReturnAttributes: true` for the existence check, and move the launch-time probes into an `async` step after first paint.
- **Why:** A locked keychain currently turns app launch into an indefinite main-thread stall, and the app reads its most sensitive value eight times over just to answer a boolean.
- **Effort:** S · **Impact:** M

---

## Reliability

### 1. The text provider retries once, with a flat delay — while the image provider does it properly

- **Location:** `Lectern/Sources/LecternCore/Providers/AnthropicProvider.swift:78-106`
- **Proof:**
  ```swift
            let data: Data, response: URLResponse
            do { (data, response) = try await session.data(for: req) }
            catch let error as URLError where error.code == .notConnectedToInternet { throw LecternError.networkOffline }
  ```
  and the retry arm:
  ```swift
            case 429, 500...599:
                let retryAfter = Int(http.value(forHTTPHeaderField: "Retry-After") ?? "") ?? 2
                if attempt == 0 { try? await Task.sleep(nanoseconds: UInt64(retryAfter) * 1_000_000_000); continue }
  ```
- **Verified:** `grep -n 'for attempt in' Lectern/Sources/LecternCore/Providers/*.swift` →
  ```
  Lectern/Sources/LecternCore/Providers/AnthropicProvider.swift:80:        for attempt in 0...1
  Lectern/Sources/LecternCore/Providers/GeminiImageProvider.swift:73:        for attempt in 0..<3
  ```
  Gemini's arm, for contrast (`GeminiImageProvider.swift:96-98`): `let fallback = min(60, 2 * (1 << attempt))` — genuine exponential backoff.
- **Do:** Two defects in one function. (a) Only `.notConnectedToInternet` is translated; a `.timedOut` (against a 120-second ceiling), `.networkConnectionLost`, or `.cannotFindHost` propagates raw, is never retried, and reaches the user as a Foundation string via `describe`'s `localizedDescription` fallback. (b) The single retry uses a flat 2-second default with no exponentiation and no jitter. Lift `GeminiImageProvider`'s loop shape — 3 attempts, `min(60, 2 * (1 << attempt))`, `Retry-After` honored — into a shared `HTTPRetry` helper and use it from both, adding the transient `URLError` codes to the retryable set.
- **Why:** The single most expensive, longest-running call in the product has the weakest retry policy in the codebase, and a transient TCP reset discards a paid multi-thousand-token generation.
- **Effort:** M · **Impact:** L

### 2. `max_tokens` is fixed at 8192 and truncation is never detected

- **Location:** `Lectern/Sources/LecternCore/Providers/AnthropicProvider.swift:43` and `:69`
- **Proof:**
  ```swift
        let payload: [String: Any] = [
            "model": model,
            "max_tokens": 8192,
            "system": system,
            "messages": [["role": "user", "content": user]],
            "tools": [tool],
            "tool_choice": ["type": "tool", "name": "emit_deck"],
        ]
  ```
- **Verified:** `grep -rn 'stop_reason\|max_tokens\|slideCount' Lectern/Sources/LecternCore/Providers/AnthropicProvider.swift` →
  ```
  43:            "max_tokens": 8192,
  69:            "max_tokens": 8192,
  50:        emit(.drafting(completed: 0, total: request.slideCount))
  53:        emit(.drafting(completed: request.slideCount, total: request.slideCount))
  ```
  `stop_reason` is never read anywhere in the target.
- **Do:** `slideCount` ranges to 40 and `includeNotes` adds a speaker-notes paragraph per slide, so a large deck can exceed 8192 output tokens. When it does, the API returns `stop_reason: "max_tokens"` with a partial `tool_use` input — which is still a *valid JSON object*, so `extractDeckJSON` accepts it and the validator sees a short-but-well-formed deck. Scale `max_tokens` from `request.slideCount` and `request.notes`, and read `stop_reason` in `send`, throwing a dedicated `.responseTruncated` so the pipeline's existing repair path can retry with a higher ceiling.
- **Why:** Asking for 40 slides can silently yield 22 with no warning anywhere in the UI — the validator's `requestedSlideCount` check is the only thing standing between this and a silently short deck.
- **Effort:** S · **Impact:** L

### 3. Image generation fans out with no concurrency ceiling

- **Location:** `Lectern/Sources/LecternCore/Providers/DeckGenerator.swift:120-131`
- **Proof:**
  ```swift
        await withTaskGroup(of: (String, Result<Data, Error>).self) { group in
            for (id, brief, aspect, role) in briefed {
                group.addTask {
                    do {
                        let data = try await imageProvider.image(prompt: brief.prompt, style: style,
                                                                 aspect: aspect, role: role)
                        return (id, .success(data))
                    } catch {
                        return (id, .failure(error))
                    }
                }
            }
  ```
- **Verified:** `grep -n 'maxConcurrent\|Semaphore\|prefix(\|chunked\|withThrowingTaskGroup' Lectern/Sources/LecternCore/Providers/DeckGenerator.swift` → `# (no matches)`
- **Do:** Every briefed slide gets a task immediately, so a 40-slide deck can fire 40 simultaneous 2K image requests at a provider whose per-minute limits are far below that. The result is self-inflicted 429s: `GeminiImageProvider` burns its three attempts on congestion this code created, and the failures surface as "N of M image(s) couldn't be generated". Use the standard bounded-group idiom — seed `min(4, briefed.count)` tasks, then add one more each time `next()` yields.
- **Why:** The illustration feature degrades exactly when it matters most (long decks), and it does so for a reason entirely within our control.
- **Effort:** S · **Impact:** L

### 4. Decks are written non-atomically, so an interrupted save corrupts the file

- **Location:** `Sources/Rostrum/Presentation/Presentation.swift:191-193`
- **Proof:**
  ```swift
    public func save(to url: URL) throws {
        try serializedData().write(to: url)
    }
  }
  ```
- **Verified:** `grep -rn 'write(to:.*options\|\.atomic\|atomically' Sources/Rostrum/Presentation/Presentation.swift Lectern/Sources/LecternCore/Rendering/DeckRenderer.swift` →
  ```
  Lectern/Sources/LecternCore/Rendering/DeckRenderer.swift:416:            try presentation.save(to: url)
  ```
  Only `DeckGenerator.keepRejectedDraft` uses `atomically: true` (`DeckGenerator.swift:65`) — the deck-save path does not.
- **Do:** `Data.write(to:)` without `.atomic` truncates the destination and streams into it. A crash, a full disk, or an iOS suspension mid-write leaves a truncated `.pptx` that PowerPoint will refuse to open, and if the path already held a deck the original is gone. Change to `try serializedData().write(to: url, options: .atomic)`. This is a one-line fix in the library that protects every consumer, and `keepRejectedDraft` already demonstrates the convention.
- **Why:** The `.pptx` on disk is described throughout the codebase as "the deliverable"; the last step of producing it should not be able to destroy a previous one.
- **Effort:** S · **Impact:** M

### 5. A render failure discards a validated, fully paid-for deck

- **Location:** `Lectern/Sources/LecternCore/Providers/DeckGenerator.swift:58-71` and `:213-224`
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
- **Verified:** `grep -n 'keepRejectedDraft\|RenderError.renderFailed' Lectern/Sources/LecternCore/Providers/DeckGenerator.swift` →
  ```
  57:                if let kept = Self.keepRejectedDraft(repaired.json, in: directory) {
  62:        let url = directory.appendingPathComponent("rejected-draft.json")
  223:        } catch let RenderError.renderFailed(underlying) {
  ```
  The draft is preserved only on the *schema-invalid* path (line 57); the render-failure path at 223 rethrows and keeps nothing.
- **Do:** The instinct is already right and already documented — "Without it the only record of what the model actually sent is an error string." But it is applied to the one failure mode where the deck was *invalid*, not to the one where the deck was **valid and the render broke**. Persist the validated `DeckIR` JSON before calling `renderer.render`, and on `RenderError` keep it and offer a retry that skips straight to rendering.
- **Why:** A rendering bug — ours, not the model's — currently costs the user the entire generation fee with nothing recoverable.
- **Effort:** S · **Impact:** M

---

## Security

### 1. A 1,446-byte `.pptx` crashes the host process, defeating the zip limits entirely

- **Location:** `Sources/Rostrum/XML/XML.swift:45` (the `Element` class) and `:137` (recursive `serialize`), reached from `Sources/Rostrum/Presentation/Presentation.swift:92`
- **Proof:** the library documents a throw:
  ```swift
  /// - Parse errors throw `RostrumError.xmlMalformed` with the parser's message
  ///   and line number.
  public enum XML {
  ```
  and the tree it builds is a chain of reference types with a recursive serializer and no depth bound anywhere:
  ```swift
        private func serialize(into out: inout String) {
            out += "<"
            out += name
  ```
- **Verified:** `grep -rn 'depth\|maxDepth\|nesting\|recursion' Sources/Rostrum/ --include='*.swift'` →
  ```
  Sources/Rostrum/Presentation/Design.swift:188:                 "typography rationale", "layout system", "depth and hierarchy", "shape language",
  ```
  The single match is a string literal in an unrelated design vocabulary list. No depth guard exists.

  Confirmed empirically end-to-end, through the public API, with the zip budget explicitly engaged:
  ```
  $ ls -l bomb.pptx
  -rw-r--r--  1446 bomb.pptx          # 40,000 nested <a> elements, deflated

  $ ./xmldepth                        # Presentation(contentsOf:limits: .init(totalUncompressedBytes: 1_000_000))
  opening bomb.pptx with a 1 MB zip budget…
  opened: 0 slides
  Segmentation fault: 11
  exit=139
  ```
  Bisected to isolate the stage — parsing *succeeds*; the crash is the recursive ARC release of the element chain when the tree deallocates:
  ```
  --- depth 5000 parseonly ---    PARSE OK / DONE (tree about to deallocate) / EXITED CLEANLY / exit=0
  --- depth 20000 parseonly ---   PARSE OK / DONE (tree about to deallocate) / Segmentation fault: 11 / exit=139
  ```
- **Do:** Two unbounded recursions share one root cause: `Element` is a `final class` holding `children`, so both the compiler-synthesized deinit chain and `serialize(into:)` recurse once per level. Add a depth counter to `TreeBuilder.parser(_:didStartElement:...)` and throw `RostrumError.xmlMalformed` past a ceiling (Word and PowerPoint themselves cap around 100; a limit of 1,000 is generous and well under the ~20,000 crash threshold measured above). Then make teardown iterative — give `Element` an explicit `deinit` that walks the tree onto a worklist and releases breadth-first — and convert `serialize` to an explicit stack. Add the 40,000-deep fixture to `Tests/RostrumTests/FuzzTests.swift`, which today has no nesting-depth case.
- **Why:** This is a remotely triggerable, unrecoverable process kill on the library's central promise — safely reading a file someone else made — and it is entirely immune to the `ZipReader.Limits` hardening built specifically to stop hostile archives, because the payload is 1.4 KB.
- **Effort:** M · **Impact:** L

### 2. The macOS app ships with neither App Sandbox nor Hardened Runtime

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
          INFOPLIST_KEY_LSApplicationCategoryType: public.app-category.productivity
          INFOPLIST_KEY_NSHumanReadableCopyright: ""
  ```
- **Verified:** `grep -rn 'ENABLE_APP_SANDBOX\|ENABLE_HARDENED_RUNTIME\|com.apple.security' Lectern/ --include='*.yml' --include='*.entitlements' --include='*.plist'` →
  ```
  Lectern/.build-xcode/Build/Intermediates.noindex/Lectern.build/Debug/Lectern.build/DerivedSources/Entitlements.plist:5:	<key>com.apple.security.get-task-allow</key>
  ```
  The only hit is a generated Debug artifact (`get-task-allow` is the debugger entitlement). `find Lectern -name '*.entitlements' -not -path '*/.build*'` → `Lectern/App/Lectern-iOS-Sim.entitlements` — iOS simulator only; the macOS target has no entitlements file at all.
- **Do:** The app reads user-selected PDFs, holds API keys in the login keychain, makes network calls to three vendors, and renders generated markup in a WebKit process — with no sandbox and no hardened runtime. `AppState.attachPDF` already calls `startAccessingSecurityScopedResource()` (`AppState.swift:218`), so the code is written *as if* sandboxed. Add an entitlements file with `com.apple.security.app-sandbox`, `files.user-selected.read-only`, and `network.client`, set `ENABLE_HARDENED_RUNTIME: "YES"`, and regenerate. Note this changes the keychain access story documented in `KeychainStore.swift:12-18` — a sandboxed app gets its own keychain partition, which actually *solves* the rebuild-instability problem described there.
- **Why:** Without hardened runtime the app cannot be notarized and cannot ship; without the sandbox, a WebKit or PDFKit parsing bug is an unconfined foothold on the user's Mac.
- **Effort:** M · **Impact:** L

### 3. Untrusted-archive limits are opt-in rather than opt-out

- **Location:** `Sources/Rostrum/Presentation/Presentation.swift:92` and `:102`
- **Proof:**
  ```swift
    public init(data: Data, limits: ZipReader.Limits = .unlimited) throws {
        package = try OPCPackage.read(data: data, limits: limits)
        let main = try package.mainDocumentPart()
  ```
  and:
  ```swift
    public convenience init(contentsOf url: URL, limits: ZipReader.Limits = .unlimited) throws {
        try self.init(data: Data(contentsOf: url), limits: limits)
    }
  ```
- **Verified:** `grep -rn 'limits:' Sources/ Lectern/ Tools/ Examples/ --include='*.swift' | grep -v 'Zip/ZipReader.swift'` →
  ```
  Sources/Rostrum/OPC/OPCPackage.swift:106:    public static func read(data: Data, limits: ZipReader.Limits = .unlimited) throws -> OPCPackage {
  Sources/Rostrum/Presentation/Presentation.swift:92:    public init(data: Data, limits: ZipReader.Limits = .unlimited) throws {
  Sources/Rostrum/Presentation/Presentation.swift:102:    public convenience init(contentsOf url: URL, limits: ZipReader.Limits = .unlimited) throws {
  Tools/pptx-tool/main.swift:47:    deck = try Presentation(data: data, limits: .init(totalUncompressedBytes: budget))
  ```
  Exactly one of four call sites passes a budget. `.unlimited` is the default at all three API layers.
- **Do:** The `Limits` machinery is thoughtfully built and its documentation is candid about what it does and does not cover. The problem is purely the default: every caller who does not know the parameter exists is unprotected, and only `pptx-tool` knows. Flip the default to a generous concrete ceiling (say 2 GB declared uncompressed, which no legitimate deck approaches) and let callers opt *into* `.unlimited`. Separately, `Data(contentsOf: url)` at line 103 reads the whole file into memory before any limit applies — add `.mappedIfSafe` so a huge file does not become a huge allocation.
- **Why:** Security controls that must be discovered to be effective protect only the readers of the docs, and this library's whole premise is parsing files from elsewhere.
- **Effort:** S · **Impact:** M

### 4. Failed drafts — including text derived from the user's private PDF — are written to disk in the clear and never cleaned up

- **Location:** `Lectern/Sources/LecternCore/Providers/DeckGenerator.swift:61-70`
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
- **Verified:** `grep -rn 'rejected-draft\|removeItem\|FileProtection\|completeFileProtection' Lectern/Sources/ Lectern/App/` →
  ```
  Lectern/Sources/LecternCore/Providers/DeckGenerator.swift:61:        let url = directory.appendingPathComponent("rejected-draft.json")
  ```
  No deletion, no expiry, no file-protection attribute anywhere in the app.
- **Do:** The draft is the model's rendering of the user's prompt plus up to 40,000 characters lifted from a PDF they attached — which may be confidential. It lands at a fixed, predictable filename inside `decksDirectory()`, which on iOS is `Documents/Decks` with `UIFileSharingEnabled: YES` (`project.yml:88-90`), making it visible to the Files app and to Finder file sharing. Move it to a `Diagnostics` subdirectory excluded from file sharing, set `.completeFileProtection` on iOS, name it per-run rather than reusing one path, and delete drafts older than a few days on launch. Also surface a "Reveal diagnostic" affordance so the user knows it exists.
- **Why:** Confidential source material silently persists in a user-visible, file-shared folder with no retention policy and no way to know it is there.
- **Effort:** S · **Impact:** M

### 5. Slide previews run in a WebKit view with JavaScript enabled by default

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
- **Verified:** `grep -rn 'allowsContentJavaScript\|WKWebViewConfiguration\|WKPreferences\|defaultWebpagePreferences' Lectern/App/` → `# (no matches)`
  Escaping on the producing side *is* present and correct (`Sources/Rostrum/Presentation/SVGRenderer.swift:746-757` escapes `&`, `<`, `>` in text content, which is sufficient to prevent tag injection), so this is defense in depth rather than a live exploit.
- **Do:** `WKWebView()` uses a default configuration in which `defaultWebpagePreferences.allowsContentJavaScript` is `true`. The markup being loaded is assembled from LLM output that may itself be grounded in an attacker-supplied PDF, and it is loaded into the app's own WebKit context. Construct the view with a `WKWebViewConfiguration` that sets `allowsContentJavaScript = false`, and add a `WKNavigationDelegate` that cancels every navigation except the initial `loadHTMLString`. The comment at lines 19-22 correctly notes the nil `baseURL` removes network and file access — closing off script execution completes the argument.
- **Why:** One missed escape anywhere in a 780-line renderer becomes script execution inside the app rather than a broken thumbnail; the mitigation is three lines and costs nothing.
- **Effort:** S · **Impact:** M

---

## Usability

### 1. Icon-only buttons in the compose screen are unlabelled for VoiceOver

- **Location:** `Lectern/App/ContentView.swift:178-179`
- **Proof:**
  ```swift
                    Spacer()
                    Button { app.clearPDF() } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).foregroundStyle(.secondary)
                }
  ```
- **Verified:** `grep -n 'accessibility' Lectern/App/ContentView.swift` → `# (no matches)`
  For contrast, the same author labelled the analogous controls elsewhere — `grep -rn 'accessibilityLabel' Lectern/App/` →
  ```
  Lectern/App/SlidePreview.swift:108:                        .accessibilityLabel("Slide \(index + 1) of \(previews.count)")
  Lectern/App/SlidePreview.swift:139:                        .accessibilityLabel("Slide \(index + 1) of \(previews.count)")
  Lectern/App/StyleThumbnail.swift:84:        .accessibilityLabel("\(style.name), \(style.badge)")
  ```
  `ContentView.swift` — the app's largest and most-used view, 369 lines — has zero accessibility modifiers.
- **Do:** VoiceOver reads this button as "xmark circle fill". Add `.accessibilityLabel("Remove PDF")`. The same file has a second unlabelled icon control at `StylePickerSheet.swift:86` (the search-clear "xmark.circle.fill"). Sweep both files and add labels, then set `.accessibilityElement(children: .combine)` on each `Card` so the grouping reads as one unit rather than four fragments.
- **Why:** The PDF-grounding card is a primary flow, and its only destructive control is unreachable by name for VoiceOver users — in an app that ships four dedicated accessibility *styles* (`contrastink`, `largeprint`, `nightreader`).
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

        #if os(macOS)
        Settings {
            SettingsView()
                .environment(app)
        }
        #endif
    }
  ```
- **Verified:** `grep -rn '\.commands\|CommandGroup\|CommandMenu' Lectern/App/` → `# (no matches)`
  The app's entire keyboard surface is two shortcuts: `grep -rn 'keyboardShortcut' Lectern/App/` →
  ```
  Lectern/App/StylePickerSheet.swift:76:                .keyboardShortcut(.defaultAction)
  Lectern/App/ContentView.swift:226:            .keyboardShortcut(.return, modifiers: .command)
  ```
- **Do:** The app inherits SwiftUI's default File/Edit/View menus, which are full of items that do nothing here (New Window, Print, Undo). Add a `.commands { }` block: replace `CommandGroup(.newItem)` with "New Deck ⌘N" wired to `app.reset()`, add "Choose Style… ⇧⌘S", "Open Decks Folder ⇧⌘O" (which also makes the Functionality item 2 gap survivable in the interim), and a `CommandGroup(replacing: .help)` pointing at the README. Delete the menu items that are inapplicable.
- **Why:** Against the Raycast anchor — a keyboard-first Mac utility — an app whose only shortcut is ⌘Return, with a File menu full of no-ops, reads as a prototype rather than a Mac app.
- **Effort:** S · **Impact:** M

### 3. The failure screen is a dead end that discards the diagnosis

- **Location:** `Lectern/App/ContentView.swift:357-369`
- **Proof:**
  ```swift
  struct FailedView: View {
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
  }
  ```
- **Verified:** `grep -rn 'Retry\|Try again\|Open Settings\|retry' Lectern/App/` → `# (no matches)`
- **Do:** Every failure — a rate limit, a rejected key, a dropped connection, an unparseable draft — funnels into one button that goes back to the form. `AppState.describe` (lines 300-323) already knows exactly which error occurred, so the recovery can be specific: `.rateLimited` deserves a "Try again" with a countdown, `.authFailed` and `.noKey` deserve an "Open Settings" button, `.networkOffline` deserves a plain retry, and `.schemaInvalid` should offer "Show the rejected draft" (the file `keepRejectedDraft` already wrote, whose path is in the message text as unclickable prose). Pass the `LecternError` itself into `FailedView` rather than a flattened `String`.
- **Why:** The most common failure — a rate limit — currently costs the user their place in the flow and gives them no action beyond starting over.
- **Effort:** S · **Impact:** M

### 4. The style gallery's search is a hand-rolled field with no platform behaviour

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
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(.regularMaterial, in: .capsule)
  ```
- **Verified:** `grep -rn 'searchable\|FocusState\|focused\|submitLabel' Lectern/App/` → `# (no matches)`
- **Do:** Because it is a raw `TextField` rather than `.searchable`, the sheet opens with focus nowhere (the user must click before typing), ⌘F does nothing, Esc does not clear, there is no scope bar for the tag chips, and on iOS the keyboard has no search affordance. Replace with `.searchable(text: $query, placement: .toolbar, prompt: "Search 150 styles")` and add a `@FocusState` so the field is focused on presentation. Move the `pillTags` row into `.searchScopes` where it belongs.
- **Why:** Picking from 150 styles is the app's most differentiated interaction, and reaching its search currently requires taking your hands off the keyboard.
- **Effort:** S · **Impact:** M

### 5. The generating screen announces nothing to VoiceOver and estimates nothing

- **Location:** `Lectern/App/ContentView.swift:236-252`
- **Proof:**
  ```swift
  struct GeneratingView: View {
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
  }
  ```
- **Verified:** `grep -n 'accessibilityValue\|announce\|AccessibilityNotification\|ETA\|estimated' Lectern/App/ContentView.swift` → `# (no matches)`
- **Do:** Nothing here is announced when it changes, so a VoiceOver user hears silence for the entire multi-minute generation and cannot tell progress from a hang. Add `.accessibilityElement(children: .combine)` with an `.accessibilityValue` derived from `stage` and `drafted/total`, and post an `AccessibilityNotification.Announcement` from `AppState.apply(_:)` on each stage change. Separately, `stage` transitions through eight named phases but shows no elapsed time and no estimate — `PriceTable` already models the deck's size, so a rough ETA is available.
- **Why:** The longest-running screen in the app is also its least communicative, and for a VoiceOver user it is entirely opaque.
- **Effort:** S · **Impact:** M

---

## Attractiveness / Sexiness

Anchor: **Raycast** — a single-window Mac utility that feels instant, teaches itself on first launch, and treats motion as feedback rather than decoration.

### 1. A Liquid Glass app with a flat, legacy app icon

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
- **Verified:** `find Lectern -name '*.icon' -not -path '*/.build*'` → `# (no matches)`
  `ls Lectern/App/Assets.xcassets/AppIcon.appiconset/` → `Contents.json  icon_1024.png  icon_128.png  icon_16.png  icon_256.png  icon_32.png  icon_512.png  icon_64.png` — seven flat PNGs, no layered source.
- **Do:** The targets deploy at macOS 26 / iOS 26 and the UI commits to Liquid Glass throughout (`.buttonStyle(.glass)`, `.glassProminent`, `.regularMaterial` cards). The icon is the one surface that did not come along: a flat pre-26 `.appiconset` gets none of the specular, depth, or tinted/clear/dark treatments the system now applies. Rebuild it in Icon Composer as a layered `.icon`, and set `ASSETCATALOG_COMPILER_APPICON_NAME` against it.
- **Why:** The icon is the first and most-repeated impression — in the Dock, in Spotlight, in the App Switcher — and it is currently the only part of the product that looks like it predates the OS it targets.
- **Effort:** M · **Impact:** M

### 2. Phase changes cut hard, with no transition

- **Location:** `Lectern/App/ContentView.swift:41-47`
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
- **Verified:** `grep -n 'animation\|transition\|withAnimation\|matchedGeometry' Lectern/App/ContentView.swift` → `# (no matches)`
  The app does animate elsewhere — `grep -rn 'withAnimation\|\.animation(' Lectern/App/` →
  ```
  Lectern/App/Theme.swift:88:        withAnimation(.easeOut(duration: 0.2)) { image = loaded }
  ```
  One animation, on thumbnail fade-in.
- **Do:** The four principal states of the app — the entire user journey — swap instantaneously, so pressing Generate replaces a full form with a spinner in a single frame, and the finished deck appears with the same abruptness. Wrap the switch in a `.animation(.smooth, value: app.phase)` and give each branch an asymmetric transition (compose pushes out, generating fades up, result scales in from the progress indicator). A `matchedGeometryEffect` from the Generate button to the progress ring would make the causal link explicit.
- **Why:** Against the Raycast anchor, state changes are where a native app earns its feeling of quality; four hard cuts make a carefully-built product feel like four screens bolted together.
- **Effort:** S · **Impact:** M

### 3. First launch is a form you cannot submit

- **Location:** the compose flow — `Lectern/App/ContentView.swift:213-232`, gated by `Lectern/App/AppState.swift:232-234`
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
- **Verified:** `grep -rn 'onboard\|firstRun\|welcome\|hasLaunched\|AppStorage' Lectern/App/` → `# (no matches)`
- **Do:** A new user opens a 780×1060 window showing five cards, a dimmed Generate button, and a grey line of text naming a menu item they must find themselves — and the label is not even a button. Build a first-run state: a single welcoming panel that explains what Lectern does, links straight to the key field (make that label a `Button` that opens Settings at minimum), and shows two or three of the best style thumbnails as a preview of what they are buying. Gate it on an `@AppStorage("hasCompletedOnboarding")` flag.
- **Why:** The first run is the only moment where every user is guaranteed to be present, and it currently presents a locked door with the key described in small grey text.
- **Effort:** M · **Impact:** L

### 4. The longest screen in the app is an indeterminate spinner

- **Location:** `Lectern/App/ContentView.swift:239-248`
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
              Button("Cancel", role: .cancel) { app.cancel() }.buttonStyle(.glass)
          }
  ```
- **Verified:** `grep -n 'GenerationEvent\|case .outlining\|case .auditing' Lectern/App/AppState.swift` →
  ```
  289:    private func apply(_ event: GenerationEvent) {
  291:        case .preparingSource: stage = "Reading source"
  292:        case .outlining: stage = "Outlining"
  293:        case .outlineReady: stage = "Outline ready"
  294:        case .drafting(let c, let t): stage = "Writing slides"; drafted = c; total = t; progressNoun = "slides"
  295:        case .validating: stage = "Validating"
  296:        case .repairing: stage = "Repairing"
  297:        case .auditing: stage = "Polishing (QA pass)"
  298:        case .illustrating(let c, let t): stage = "Generating images"; drafted = c; total = t; progressNoun = "images"
  299:        case .rendering: stage = "Rendering .pptx"
  300:        case .finished: stage = "Done"
  ```
  Ten richly-named stages arrive at the UI and are rendered as one line of text above a generic spinner.
- **Do:** The pipeline emits a genuinely interesting narrative — outlining, drafting, validating, repairing, polishing, illustrating, rendering — and the UI flattens it into a `ProgressView()`. Show the stages as a vertical checklist that fills in as each completes, and — the real prize — `outlineReady` already carries the actual `DeckOutline` with its title and section names, which is currently *discarded* (line 293 sets only a string). Reveal the outline as it lands, then let slide thumbnails populate as they render.
- **Why:** A multi-minute wait is the app's biggest engagement risk and its biggest opportunity; the data for a compelling progressive reveal is already flowing and being thrown away one line short of the screen.
- **Effort:** M · **Impact:** L

### 5. The result screen buries its payoff under four collapsible warning drawers

- **Location:** `Lectern/App/ContentView.swift:290-348`
- **Proof:**
  ```swift
              if !result.warnings.isEmpty {
                  DisclosureGroup("\(result.warnings.count) validation warning(s)") {
  ```
  …followed in sequence by:
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
- **Verified:** `grep -c 'DisclosureGroup' Lectern/App/ContentView.swift` → `4`
  All four sit inside the same `VStack` beneath the action row, each `.frame(maxWidth: 420)`.
- **Do:** The taxonomy behind these four buckets is genuinely excellent and the comments justifying the separation are the best in the file — but the user's moment of delight is "my deck is ready", and it arrives stacked under up to four grey accordions of caveats. Collapse them into a single "Details" affordance with a quiet inline badge, let the contact sheet take the full height, and promote Open/Share to the visual anchor. Keep the four categories intact *inside* the details panel, where their precision is a feature rather than an apology.
- **Why:** This is the screen the entire product exists to reach; measured against the Raycast anchor it should feel like an arrival, not a lint report.
- **Effort:** S · **Impact:** M

---

## First move

**A 1,446-byte `.pptx` crashes the host process, defeating the zip limits entirely** (from Security)

Ship this first because it is the only finding in the report that is *proven*, not argued — a 1,446-byte file, opened through the documented public API with the security budget explicitly engaged, terminates the process with SIGSEGV, and the bisection shows exactly why (recursive ARC teardown of the `XML.Element` chain, crossing the stack limit somewhere between depth 5,000 and 20,000). Everything else here is a judgement call about priorities; this is a reproducible crash. It also matters disproportionately because of what Rostrum is: a library whose entire value proposition is safely reading files that someone else made, which documents that malformed input *throws* `RostrumError.xmlMalformed`, and which has invested real care in exactly this threat model — the `ZipReader.Limits` struct, the zip64 count bounding, the coordinate-overflow clamp at `intAttr`, the explicit `shouldResolveExternalEntities = false`. This bug walks straight past all of it, because the payload is 1.4 KB and the limits only bound *declared uncompressed bytes*. Every downstream consumer inherits the hole, including Lectern, which today is unsandboxed (Security item 2) and so hands an attacker an unconfined crash. The fix is well-bounded and testable in a single sitting: a depth counter in `TreeBuilder`, an iterative `deinit` and an iterative `serialize`, and a nesting-depth case added to `FuzzTests.swift`, which currently has none. Do that, then take Reliability item 3 (bound the image fan-out) as the fast follow, since it is an afternoon's work and removes a failure mode the product inflicts on itself.

## Dropped during verification

- **A cancel during the QA pass is swallowed and the deck renders anyway** — cited code does something else. `try? await provider.revise(...)` (`DeckGenerator.swift:81`) *does* convert `CancellationError` into `nil`, and `DeckGenerator.swift` itself has no cancellation checks. But re-reading the renderer showed the stage below it is thoroughly guarded: `grep -rn 'Task.isCancelled\|checkCancellation' Lectern/Sources/LecternCore/` →
  ```
  Lectern/Sources/LecternCore/Rendering/DeckRenderer.swift:331:            try Task.checkCancellation()
  Lectern/Sources/LecternCore/Rendering/DeckRenderer.swift:341:                try Task.checkCancellation()
  Lectern/Sources/LecternCore/Rendering/DeckRenderer.swift:414:            try Task.checkCancellation()
  Lectern/Sources/LecternCore/Rendering/DeckRenderer.swift:423:                              previews: Task.isCancelled ? [] : Self.previews(of: presentation),
  ```
  with a comment at 326-330 describing precisely the symptom I was going to claim — "Without these the user is returned to Compose and then, a few seconds later, thrown into a Result screen for the deck they just cancelled, with the file already written." No file is written after a cancel; the checks at 331 and 414 see to that, and `illustrate`'s task-group children inherit cancellation. The residue is cosmetic (cancelled image requests are reported as image *failures* rather than as a cancellation), which does not belong in a top-5.
- **XXE / external entity resolution in the XML parser** — already in place: `grep -n 'shouldResolveExternalEntities' Sources/Rostrum/XML/XML.swift` → `193:        parser.shouldResolveExternalEntities = false`. Explicitly disabled.
- **Integer overflow trap on coordinates parsed from a hostile deck** — already in place. `SVGRenderer.intAttr` routes every file-derived coordinate through a bounded `coordinate(_:)`, with a comment naming this exact risk: "Swift's `+` traps on overflow. Bounding at the single point where file bytes become numbers is what makes all of that arithmetic safe."
- **`try!` in `Inflate.fixedTables` is a latent crash** — cited code is provably safe: the two calls at `Inflate.swift:286-287` construct RFC 1951 §3.2.6 fixed tables from compile-time-constant lengths. These are the only two `try!` in 16,179 lines and the accompanying comment ("well-formed by construction; failure is impossible") is correct.
- **Unescaped model text reaching the SVG preview enables XSS** — already in place: `SVGRenderer.swift:746-757` escapes `&`, `<`, `>` on every text run, and `colorHex` is validated rather than interpolated raw (comment at line 705). Reduced to the defense-in-depth JavaScript finding (Security item 5) rather than an active vulnerability.
- **Force-unwraps and crash operators across the app layer** — no occurrences: `grep -rn 'try!\|as! \|fatalError\|\.first!\|\.last!' Lectern/App Lectern/Sources` → `# (no matches)`.
- **Unhandled TODO/FIXME debt** — effectively none: the only repo-wide match is `ZipWriter.swift:160`, a doc comment describing an *unimplemented case in the OOXML spec*, not deferred work.
- **`Presentation.save` leaks partial state on failure / no `documentKind` guard** — mislocated. The guard exists at `Presentation.swift:95-98` (`throw RostrumError.notAPresentation`), and it fired correctly during my own exploit development, forcing me to set a valid PresentationML content type before the crash was reachable.

## Deferred

- **CI runs three jobs on macOS hosted runners** (`.github/workflows/ci.yml:27` `runs-on: macos-15`, `:51` `runs-on: macos-26`) — outside the seven lenses, but worth acting on: hosted macOS minutes bill at 10× Linux, and this workflow triggers on **every push to every branch** (`on: push` with no branch filter). The Linux job already covers `swift build` + `swift test` on 6.0/6.1. Consider making the macOS and `xcodebuild` jobs manual or `main`-only and verifying Apple-platform builds locally.
- **`AppState.task` is never cleared after a successful run** (`AppState.swift:286`) — `task = nil` happens only in `cancel()`. Harmless today (a completed `Task` releases its closure), but it makes the lifecycle harder to reason about; fold into the `generationID` work in Stability item 1.
- **`DeckRenderer.swift` is 907 lines** — nearly twice the next-largest Lectern file and the single place where IR, layout, furniture, fonts, charts and previews all meet. Not a defect, but the obvious next split (previews and font resolution are both self-contained).
- **No snapshot or golden-file tests for `SVGRenderer`** — `Tests/RostrumTests/SVGRendererTests.swift` is 281 lines of structural assertions; visual regressions in the preview path would pass silently.
- **`Examples/` and `Tools/` were not audited** — four executable targets plus `extract-schema.py` sit outside the surveyed set.
