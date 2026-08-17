# Lift-Up Plan: Rostrum + Lectern

> Platform: mixed (macOS 26 + iOS 26 app on a macOS 13 / iOS 16 library)
> Surveyed: 2026-08-09
> Coverage: full for `Lectern/App/`, `Lectern/Sources/LecternCore/`; partial for `Sources/Rostrum/` (Presentation/, Zip/, XML/, OPC/, Charts/, Fonts/ read; `Tools/` and `Examples/` not audited)
> Attractiveness anchor: inferred — **Raycast** (the macOS-native benchmark for a single-window utility that must feel instant and premium). Not user-supplied.
> Model tier: Opus 5 (frontier) — no rerun needed.

Verification was unusually punishing on this codebase: 11 of ~34 candidates were
dropped, most because the "missing" guard was already there. Several dimensions
therefore ship fewer than 5 items rather than padded ones. That is a signal about
Rostrum's quality, not about the audit.

## Performance

### 1. The contact sheet builds one `WKWebView` per slide

- **Location:** `Lectern/App/SlidePreview.swift:120`
- **Proof:**
  ```swift
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(Array(previews.enumerated()), id: \.offset) { index, svg in
                    SlidePreview(svg: svg)
                        .aspectRatio(16.0 / 9.0, contentMode: .fit)
  ```
  `SlidePreview` is a `WKWebView` (`makeWebView` → `WKWebView(frame:configuration:)`),
  so each tile is a full web content process.
- **Verified:** `grep -n 'WKWebView\|NSViewRepresentable\|UIViewRepresentable' Lectern/App/SlidePreview.swift` →
  ```
  2:import WebKit
  62:    @MainActor fileprivate func makeWebView(_ coordinator: Coordinator) -> WKWebView {
  69:        let view = WKWebView(frame: .zero, configuration: config)
  86:extension SlidePreview: NSViewRepresentable {
  87:    func makeNSView(context: Context) -> WKWebView { makeWebView(context.coordinator) }
  ```
- **Do:** Rasterize each SVG once to a `CGImage` off the main actor and show `Image`
  in the grid; keep the `WKWebView` only for a single full-size detail view. On macOS
  the SVG can go through `NSImage`-free `CGImageSourceCreateWithData` after a one-shot
  WebKit snapshot (`takeSnapshot(with:)`), cached by slide index.
- **Why:** A 60-slide deck currently spawns dozens of web content processes while
  scrolling; each carries its own JS-disabled renderer and several MB of RSS. This is
  the single biggest reason the inspector feels heavy on real decks.
- **Effort:** M · **Impact:** L

### 2. Every slide is rendered to SVG before the inspector appears

- **Location:** `Lectern/Sources/LecternCore/Inspection/DeckInspection.swift:149`
- **Proof:**
  ```swift
    public static func inspect(deckAt url: URL,
                               renderPreviews: Bool = true,
                               limits: ZipReader.Limits =
                                   .init(totalUncompressedBytes: DeckInspector.defaultReadLimit),
                               onEvent: (Event) -> Void = { _ in }) throws -> DeckInspection {
  ```
- **Verified:** `grep -n 'renderPreviews' Lectern/Sources/LecternCore/Inspection/DeckInspection.swift Lectern/App/AppState.swift` →
  ```
  Lectern/Sources/LecternCore/Inspection/DeckInspection.swift:146:    /// - Parameter renderPreviews: pass `false` to skip the slowest step when
  Lectern/Sources/LecternCore/Inspection/DeckInspection.swift:149:                               renderPreviews: Bool = true,
  Lectern/Sources/LecternCore/Inspection/DeckInspection.swift:178:        if renderPreviews {
  ```
  No hit in `AppState.swift` — the call site takes the default, so previews are always eager.
- **Do:** Render previews lazily per visible tile (or cap the eager pass at the first
  ~12 slides and stream the rest), driven by the existing `.rendering(done:total:)`
  event. `AppState.inspect(deckAt:)` should pass `renderPreviews: false` and fault
  tiles in from the contact sheet.
- **Why:** The user's own library has decks of 84–96 MB; every one of those pays full
  SVG rasterization of every slide — including base64-inlined media — before a single
  fact appears on screen. Time-to-first-content is currently bounded by the slowest step.
- **Effort:** M · **Impact:** L

### 3. The deck library re-scans the directory on every appearance

- **Location:** `Lectern/Sources/LecternCore/Storage/DeckLibrary.swift:36`
- **Proof:**
  ```swift
        guard let entries = try? fileManager.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]) else { return [] }
        return entries.compactMap { url -> DeckFile? in
            guard isDeck(url) else { return nil }
  ```
- **Verified:** `grep -rn 'refreshLibrary()' Lectern/App/` →
  ```
  Lectern/App/ContentView.swift:133:        .task { app.refreshLibrary() }
  Lectern/App/DeckLibrarySheet.swift:57:        .task { app.refreshLibrary() }
  ```
- **Do:** Cache the listing in `AppState` and invalidate on write/delete, or watch the
  directory with a `DispatchSource` file-system observer. Keep the rescan as the
  fallback path only.
- **Why:** Two `.task` sites re-stat 29+ files (several ~90 MB) each time Home appears
  or the sheet opens, on the main actor's behalf. It is invisible today and will not
  stay invisible as the library grows.
- **Effort:** S · **Impact:** M

### 4. Font files are re-read and re-parsed on every render

- **Location:** `Lectern/Sources/LecternCore/Rendering/DeckRenderer.swift:185`
- **Proof:**
  ```swift
        guard let url = installedFontFile(named: name) ?? officeFontFile(named: name),
              let data = try? Data(contentsOf: url),
              let face = familyCandidates(for: name)
                  .lazy.compactMap({ faceIndex(named: $0, in: data) }).first,
  ```
- **Verified:** `grep -n 'cache\|Cache\|memo' Lectern/Sources/LecternCore/Rendering/DeckRenderer.swift` → `# (no matches)`
- **Do:** Memoize `name → (URL, faceIndex, Data)` in a `static let` actor-isolated cache
  keyed by font name; font files do not change during a run.
- **Why:** `Data(contentsOf:)` on a font file is tens of MB for large families, repeated
  per render pass and per face candidate.
- **Effort:** S · **Impact:** M

Four items. A fifth Performance candidate (`XML.textContent` string concatenation)
was dropped — see *Dropped during verification*.

## Functionality

### 1. Two of the three text providers are selectable but throw

- **Location:** `Lectern/Sources/LecternCore/Providers/ProviderFactory.swift:20`
- **Proof:**
  ```swift
        switch id {
        case .anthropic:
            return AnthropicProvider(apiKey: key, model: model)
        case .openAI, .gemini, .custom:
            throw LecternError.providerError(status: 0, message: "\(id.rawValue) isn't wired up yet — use Anthropic.")
        }
  ```
- **Verified:** `grep -n 'ProviderID.allCases\|isWired' Lectern/App/SettingsView.swift` →
  ```
  44:                    ForEach(ProviderID.allCases, id: \.self) { id in
  62:                    .disabled(!ProviderFactory.isWired(app.providerID))
  179:        if !ProviderFactory.isWired(app.providerID) {
  ```
- **Do:** Either implement `OpenAIProvider` behind the existing `LLMProvider` protocol
  (the image providers already prove the shape), or remove `.openAI`/`.gemini`/`.custom`
  from the Settings picker until they exist.
- **Why:** The picker advertises three choices and honours one. The app degrades
  politely, but a settings screen that lists capabilities it does not have is a promise
  the product breaks on first use.
- **Effort:** L · **Impact:** M

### 2. Decks can be created and deleted but never renamed

- **Location:** `Lectern/Sources/LecternCore/Storage/DeckLibrary.swift`
- **Proof:**
  ```swift
    public static func delete(_ deck: DeckFile,
                              fileManager: FileManager = .default) throws {
        try fileManager.removeItem(at: deck.url)
    }
  ```
- **Verified:** `grep -rn 'rename\|Rename' Lectern/App/DeckLibrarySheet.swift Lectern/Sources/LecternCore/Storage/DeckLibrary.swift` → `# (no matches)`
- **Do:** Add `DeckLibrary.rename(_:to:)` doing a collision-checked `moveItem`, and wire
  it to an inline `TextField` rename in `DeckRow` (double-click / return-to-commit).
- **Why:** Deck names are model-generated slugs like
  `paperbanana-automating-academic-illustration-for-ai-scientis-2-rebranded`. The one
  affordance a user needs most for their own archive is the one missing.
- **Effort:** S · **Impact:** M

### 3. The inspector's slide tiles are not linked to their text

- **Location:** `Lectern/App/InspectorView.swift:55`
- **Proof:**
  ```swift
                    if !inspection.previews.isEmpty {
                        Card(title: "SLIDES", systemImage: "rectangle.on.rectangle") {
                            SlideContactSheet(previews: inspection.previews,
                                              titles: inspection.previewTitles)
                                .frame(minHeight: 260)
                        }
                    }
  ```
- **Verified:** `grep -n 'ScrollViewReader\|scrollTo\|onTapGesture' Lectern/App/InspectorView.swift` → `# (no matches)`
- **Do:** Wrap the inspector `ScrollView` in a `ScrollViewReader`, give each slide block
  in `textCard` an `.id(slide.number)`, and make a contact-sheet tile tap scroll to it.
- **Why:** The two halves of the inspector describe the same slides and cannot refer to
  each other; finding the words for the tile you are looking at means scrolling and counting.
- **Effort:** S · **Impact:** M

Three items. Candidates 4 and 5 (`ChartReader.setFormula` unused; missing chart-kind
coverage) were dropped — see *Dropped during verification*.

## Stability

### 1. Section writing swallows its own errors

- **Location:** `Lectern/Sources/LecternCore/Rendering/DeckRenderer.swift:890`
- **Proof:**
  ```swift
        distinct.insert((name: opening?.isEmpty == false ? opening! : "Opening", startSlide: 0),
                        at: 0)
        try? presentation.setSections(distinct)
  ```
- **Verified:** `grep -n 'try?' Lectern/Sources/LecternCore/Rendering/DeckRenderer.swift | wc -l` → `14`
- **Do:** Capture the failure into the render's existing `warnings` array rather than
  discarding it: `do { try presentation.setSections(distinct) } catch { warnings.append(...) }`.
- **Why:** A deck that silently loses its section structure looks correct in Lectern and
  wrong in PowerPoint, with no signal anywhere that a step failed.
- **Effort:** S · **Impact:** M

### 2. `PackURI` traps rather than throws on a malformed path

- **Location:** `Sources/Rostrum/OPC/PackURI.swift:19`
- **Proof:**
  ```swift
    public init(_ value: String) {
        precondition(value.hasPrefix("/"), "pack URI must be absolute: \(value)")
  ```
- **Verified:** `grep -rn 'PackURI(' Sources/Rostrum/OPC/OPCPackage.swift | head -3` →
  ```
  Sources/Rostrum/OPC/OPCPackage.swift:118:            let uri = PackURI("/" + entry.name)
  Sources/Rostrum/OPC/OPCPackage.swift:263:        let uri = PackURI("/" + entry.name)
  ```
- **Do:** The two package-read call sites prepend `/` so they cannot trip the
  precondition today — that is load-bearing and undocumented. Add a failable
  `PackURI(validating:)` used at every boundary that consumes zip entry names, and note
  the invariant at the call sites.
- **Why:** The precondition is one refactor away from becoming a crash on a hostile
  archive: it is the only thing between an attacker-controlled entry name and a trap.
- **Effort:** S · **Impact:** M · `speculative` (no current reachable path; the anchor is
  the untrusted-input adjacency, not a live bug)

Two items. Six Stability candidates were dropped as provably safe — this is the
strongest dimension in the codebase and the report says so rather than inventing three
more. See *Dropped during verification*.

## Reliability

### 1. The retry deadline only gates *starting* an attempt

- **Location:** `Lectern/Sources/LecternCore/Providers/HTTPRetry.swift:84`
- **Proof:**
  ```swift
    static func hasTimeToRetry(startedAt: Date, nextWait: Int, now: Date = Date()) -> Bool {
        now.addingTimeInterval(TimeInterval(nextWait)).timeIntervalSince(startedAt) < overallDeadline
    }
  ```
- **Verified:** `grep -n 'overallDeadline\|timeoutInterval' Lectern/Sources/LecternCore/Providers/HTTPRetry.swift Lectern/Sources/LecternCore/Providers/AnthropicProvider.swift` →
  ```
  Lectern/Sources/LecternCore/Providers/HTTPRetry.swift:82:    static let overallDeadline: TimeInterval = 180
  Lectern/Sources/LecternCore/Providers/AnthropicProvider.swift:149:        var req = URLRequest(url: endpoint, timeoutInterval: 600)
  ```
- **Do:** Wrap the whole retry loop in a `Task` with a deadline, or lower the per-request
  `timeoutInterval` so `attempts × timeout` cannot exceed `overallDeadline`.
- **Why:** A request started at t=179 s with a 600 s socket timeout can hold the
  "generating" screen for ten minutes against a 180 s stated ceiling. The user's only
  exit is Cancel.
- **Effort:** S · **Impact:** M

### 2. Image failures silently downgrade a paid deck

- **Location:** `Lectern/Sources/LecternCore/Providers/DeckGenerator.swift:180`
- **Proof:**
  ```swift
                    case .failure(let error): failures.append(DeckGenerator.imageFailure(error))
                }
        var warnings: [String] = discarded
        if !failures.isEmpty {
  ```
- **Verified:** `grep -n 'failures.isEmpty\|warnings.append' Lectern/Sources/LecternCore/Providers/DeckGenerator.swift | head -4` →
  ```
  182:        if !failures.isEmpty {
  ```
- **Do:** Distinguish "some images failed" from ordinary warnings in `DeckResult`, and
  offer a "Retry missing images" action on `ResultView` that regenerates only the failed
  briefs rather than the whole deck.
- **Why:** Every image is a paid call. Today a half-illustrated deck is reported in the
  same disclosure group as a schema nit, and the only remedy offered is regenerating
  everything from scratch.
- **Effort:** M · **Impact:** M

Two items; three Reliability candidates were dropped as already-handled.

## Security

### 1. Grounding text from a PDF is interpolated straight into the prompt

- **Location:** `Lectern/Sources/LecternCore/Providers/PromptTemplates.swift:110`
- **Proof:**
  ```swift
        if let grounding = request.groundingText, !grounding.isEmpty {
            parts.append("Ground every factual claim in the SOURCE MATERIAL below; do not invent statistics.\n\n"
                + "--- SOURCE MATERIAL ---\n\(grounding)")
        }
        return parts.joined(separator: "\n\n")
  ```
- **Verified:** `grep -rn 'sanitiz\|escape\|injection' Lectern/Sources/LecternCore/Providers/PromptTemplates.swift Lectern/App/PDFGrounding.swift` → `# (no matches)`
- **Do:** Move grounding into its own message turn rather than concatenating it into the
  instruction block, delimit it with a nonce fence, and state in the system prompt that
  source material is data and never instructions.
- **Why:** The PDF is frequently someone else's document. Text inside it can currently
  redirect a paid generation — including the QA pass that reviews the result.
- **Effort:** S · **Impact:** M

### 2. Rejected drafts persist unencrypted outside iOS

- **Location:** `Lectern/Sources/LecternCore/Providers/DeckGenerator.swift:75`
- **Proof:**
  ```swift
        try Data(json.utf8).write(to: url, options: [.atomic, .completeFileProtection])
        #else
        try Data(json.utf8).write(to: url, options: .atomic)
  ```
- **Verified:** `grep -rn 'completeFileProtection' Lectern/Sources/LecternCore/` →
  ```
  Lectern/Sources/LecternCore/Providers/DeckGenerator.swift:75:        try Data(json.utf8).write(to: url, options: [.atomic, .completeFileProtection])
  ```
  Single occurrence — the macOS branch has no equivalent.
- **Do:** On macOS, write rejected drafts to a directory with owner-only POSIX
  permissions (`0o700`) and prune on a timer, or keep them in memory unless a debug
  flag is set.
- **Why:** A rejected draft contains the user's full prompt and any grounding excerpts,
  left at rest in a readable location on a multi-user Mac.
- **Effort:** S · **Impact:** M

Two items. Three Security candidates were dropped as already mitigated — notably the
untrusted-file read budget and the preview sandbox, both already correct.

## Usability

### 1. Every control on the compose form is invisible to VoiceOver

- **Location:** `Lectern/App/ContentView.swift:253`
- **Proof:**
  ```swift
                Card(title: "PROMPT", systemImage: "text.alignleft") {
                    TextEditor(text: $app.prompt)
                        .font(.body).scrollContentBackground(.hidden)
                        .frame(minHeight: 120)
                        .overlay(alignment: .topLeading) {
                            if app.prompt.isEmpty {
                                Text("What is this presentation about, and what should it accomplish?")
                                    .foregroundStyle(.tertiary).allowsHitTesting(false).padding(.top, 2)
                            }
                        }
                }
  ```
  The `Card` title is decoration; the placeholder is a non-hit-testable overlay. Neither
  reaches the accessibility tree.
- **Verified:** `grep -n 'accessibilityLabel' Lectern/App/ContentView.swift` →
  ```
  246:                        .accessibilityLabel("Dismiss")
  328:                        .accessibilityLabel("Remove PDF")
  ```
  Only two, both on icon buttons elsewhere. Confirmed empirically against the live app's
  accessibility tree, which reports the prompt as a bare `AXTextArea` with no description
  and the audience picker as `AXPopUpButton Value: General` with no label.
- **Do:** Give `TextEditor` an `.accessibilityLabel("Prompt")`, replace `Picker("")` +
  `.labelsHidden()` with real labels (`Picker("Audience", …)`) kept visually hidden via
  `.accessibilityLabel` rather than erased, and label the `Stepper` and `Toggle` groups.
- **Why:** The entire primary task of the app — describing a deck — is unusable with
  VoiceOver. The visual `Card` headings carry all the meaning and none of it is exposed.
- **Effort:** S · **Impact:** L

### 2. A 29-deck library has no search

- **Location:** `Lectern/App/DeckLibrarySheet.swift:35`
- **Proof:**
  ```swift
                List {
                    ForEach(app.library) { deck in
                        DeckRow(deck: deck,
                                open: { open(deck) },
  ```
- **Verified:** `grep -rn 'searchable' Lectern/App/ Lectern/Sources/` → `# (no matches)`
- **Do:** Add `.searchable(text:)` over the library list filtering on deck name, and a
  sort control (name / date / size). `StylePickerSheet` already implements exactly this
  pattern for styles and can be copied.
- **Why:** The library is the only route back to decks that cost real money to make, and
  the names are long model-generated slugs. Finding one is currently linear scanning.
- **Effort:** S · **Impact:** M

### 3. You cannot drop a deck on the window to inspect it

- **Location:** `Lectern/App/ContentView.swift:350`
- **Proof:**
  ```swift
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first(where: { $0.pathExtension.lowercased() == "pdf" }) else { return false }
            Task { await app.attachPDF(url) }
            return true
        } isTargeted: { dropTargeted = $0 }
  ```
- **Verified:** `grep -rn 'dropDestination' Lectern/App/` →
  ```
  Lectern/App/ContentView.swift:350:        .dropDestination(for: URL.self) { urls, _ in
  ```
  The only drop target in the app, scoped to `ComposeView` and to `.pdf`.
- **Do:** Add a `.dropDestination` at the `HomeView` (and window) level accepting
  `pptx`/`potx`/`ppsx` that calls `app.inspect(deckAt:)`, with a highlighted drop state.
- **Why:** "Open a deck" is half the product, and the most natural macOS gesture for it
  does nothing. The app already registers those UTTypes for the file importer.
- **Effort:** S · **Impact:** M

### 4. Hero glyphs are fixed-size and ignore Dynamic Type

- **Location:** `Lectern/App/ContentView.swift:96`
- **Proof:**
  ```swift
                Image(systemName: "rectangle.on.rectangle.angled")
                    .font(.system(size: 44)).foregroundStyle(.tint)
                Text("Lectern").font(.largeTitle.weight(.semibold))
  ```
- **Verified:** `grep -rn 'font(.system(size:' Lectern/App/*.swift` →
  ```
  Lectern/App/ContentView.swift:96:                    .font(.system(size: 44)).foregroundStyle(.tint)
  Lectern/App/ContentView.swift:143:            Image(systemName: systemImage).font(.system(size: 28))
  Lectern/App/ContentView.swift:437:                Image(systemName: "checkmark.seal.fill").font(.system(size: 52)).foregroundStyle(.green)
  Lectern/App/ContentView.swift:524:            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 44)).foregroundStyle(.orange)
  Lectern/App/StyleThumbnail.swift:39:                        .font(.system(size: 12, weight: .semibold))
  Lectern/App/StyleThumbnail.swift:59:                            .font(.system(size: 9, weight: .semibold))
  ```
- **Do:** Replace with relative sizing — `.font(.system(size: 44, relativeTo: .largeTitle))`
  or `.imageScale(.large)` on a text-style font — so the glyphs track the user's setting.
- **Why:** At larger accessibility text sizes the labels grow and the icons do not, which
  breaks the visual hierarchy of exactly the two screens that carry the product's identity.
- **Effort:** S · **Impact:** S

### 5. The window has a default size but no resizability contract

- **Location:** `Lectern/App/LecternApp.swift:52`
- **Proof:**
  ```swift
        .defaultSize(width: 780, height: 1060)
  ```
- **Verified:** `grep -rn 'windowResizability\|defaultSize\|WindowGroup' Lectern/App/LecternApp.swift` →
  ```
  40:        WindowGroup("Lectern") {
  52:        .defaultSize(width: 780, height: 1060)
  ```
- **Do:** Add `.windowResizability(.contentMinSize)` so the 640×560 `minWidth/minHeight`
  already declared in `ContentView` is actually enforced by the window.
- **Why:** The content declares a minimum the window does not honour; dragging small
  produces clipped controls rather than a floor.
- **Effort:** S · **Impact:** S

## Attractiveness / Sexiness

Anchor: **Raycast** — a single-window macOS tool that feels instant, dense and
deliberate, where every wait is narrated and every state looks designed.

### 1. A two-minute paid generation shows a spinner and a noun

- **Location:** `Lectern/App/ContentView.swift:396`
- **Proof:**
  ```swift
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
  ```
- **Verified:** `grep -n 'previews\|skeleton\|shimmer\|redacted' Lectern/App/ContentView.swift | sed -n '1,6p'` →
  ```
  432:            if result.previews.isEmpty {
  440:                SlideContactSheet(previews: result.previews, titles: result.previewTitles)
  ```
  Nothing progressive exists during generation; previews appear only in `ResultView`.
- **Do:** Show the deck assembling: a skeleton contact sheet of `app.total` placeholder
  tiles that fill in as slides are drafted, with the stage label as a caption. The
  generator already emits `.drafting(c, t)` per slide, so the data is there.
- **Why:** This is the screen the user stares at for the longest, on the most expensive
  action, and it is the least designed one in the app. Raycast's rule is that waiting is
  a state to design, not a gap to fill with a spinner.
- **Effort:** M · **Impact:** L

### 2. First run drops you at a fork with no idea what either side does

- **Location:** `Lectern/App/ContentView.swift:88`
- **Proof:**
  ```swift
    var body: some View {
        @Bindable var app = app
        VStack(spacing: 30) {
            Spacer()
            VStack(spacing: 10) {
                Image(systemName: "rectangle.on.rectangle.angled")
                    .font(.system(size: 44)).foregroundStyle(.tint)
                Text("Lectern").font(.largeTitle.weight(.semibold))
                Text("Write a deck, or take one apart.")
  ```
- **Verified:** `grep -rn 'onboard\|firstRun\|hasLaunched\|welcome' Lectern/App/ Lectern/Sources/` → `# (no matches)`
- **Do:** On first launch (no key, empty library) replace the fork with a one-screen
  welcome: what Lectern does, the single field that unblocks it (the API key), and a
  "Try Inspect with a sample deck" path that needs no key at all.
- **Why:** Without a key, Create fails at the first press; Inspect is the only working
  half and nothing says so. A first run that cannot succeed is the most expensive
  polish gap in the product.
- **Effort:** M · **Impact:** L

### 3. The no-preview success state is a bare checkmark on an empty pane

- **Location:** `Lectern/App/ContentView.swift:437`
- **Proof:**
  ```swift
            if result.previews.isEmpty {
                Spacer()
                Image(systemName: "checkmark.seal.fill").font(.system(size: 52)).foregroundStyle(.green)
                Spacer()
            } else {
  ```
- **Verified:** `grep -n 'ContentUnavailableView' Lectern/App/*.swift` →
  ```
  Lectern/App/DeckLibrarySheet.swift:28:                    ContentUnavailableView(
  ```
  Used once, in the library only.
- **Do:** Replace with a composed success state — deck name, slide count, file size, and
  the primary Open action — or reuse `ContentUnavailableView` with a description
  explaining why no previews were rendered.
- **Why:** The payoff moment of a paid generation currently renders as a floating green
  glyph in whitespace, which reads as a placeholder rather than a finish.
- **Effort:** S · **Impact:** M

### 4. The inspector is fourteen identical material slabs

- **Location:** `Lectern/App/ContentView.swift:186`
- **Proof:**
  ```swift
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: .rect(cornerRadius: 16, style: .continuous))
    }
  ```
- **Verified:** `grep -c 'Card(title:' Lectern/App/InspectorView.swift` → `9`
- **Do:** Give `Card` a density variant: stats and findings as full cards, the secondary
  reads (fonts, properties, masters) as a single grouped section with dividers. Introduce
  one accent — the deck's own theme colour, already extracted in `themeFonts`/masters —
  so the inspector looks like it is about *that* deck.
- **Why:** Nine same-weight cards give the eye no hierarchy; everything is equally
  important, so nothing is. The anchor's inspector panes lead with one number and
  demote the rest.
- **Effort:** M · **Impact:** M

Four items; a fifth (app-icon quality) was not assessable — see *Deferred*.

---

## First move

**Every control on the compose form is invisible to VoiceOver** (from Usability)

Ship this first because it is the only item on the list where the product is currently
*broken* rather than merely unpolished, and it is an afternoon's work. Lectern's primary
task — describing a deck — cannot be performed at all with VoiceOver: the prompt is an
unlabelled text area, and the audience and goal pickers were constructed with `Picker("")`
plus `.labelsHidden()`, which does not hide a label, it deletes one. I confirmed this both
in source and against the running app's accessibility tree, where the prompt appears as a
bare `AXTextArea` with no description. Every other item on this plan makes a working thing
better; this one makes a non-working thing work, for the users least able to route around
it. It also costs the least of any `Impact: L` item here, needs no architectural decision,
and cannot conflict with the larger UI work that follows — which means it can land while
the generating-screen redesign (the other `L`) is still being built.

## Dropped during verification

- **Force-unwrapped provider endpoint URLs** (`AnthropicProvider.swift:18`, `OpenAIImageProvider.swift:65`, `GeminiImageProvider.swift:69`, `AnthropicModels.swift:11`) — cited code does something else: all four unwrap compile-time string literals that are provably valid, so the `!` can never trap. Classic false positive.
- **`try!` in the DEFLATE fixed-table path** (`Inflate.swift:299-300`) — cited code does something else: the lengths are RFC 1951 constants, not input-derived; `HuffmanTable` cannot fail on them.
- **`data.series[0]` in pie/doughnut generation** (`ChartXML.swift:517`) — already in place: `grep -n 'series.isEmpty' Sources/Rostrum/Charts/ChartData.swift` → `26:        precondition(!series.isEmpty, "chart needs at least one series")`. Empty series cannot reach the subscript.
- **Compose form has no validation feedback** — already in place: `.disabled(!app.canGenerate)` at `ContentView.swift:389`.
- **Home screen buttons lack accessibility labels** — already in place: verified against the live accessibility tree, which reports `AXButton Description: Create, Describe it, and Lectern writes the .pptx.` SwiftUI combines the label stack automatically.
- **The inspector reads untrusted decks with no decompression limit** — already in place: fixed earlier today; `DeckInspector.defaultReadLimit = 1 << 30` is now passed as `ZipReader.Limits`.
- **SVG previews could execute script** — already in place: `config.defaultWebpagePreferences.allowsContentJavaScript = false` plus a navigation delegate that allows only `about:blank`.
- **Provider responses cached to disk** — already in place: `ProviderNetworking.session = URLSession(configuration: .ephemeral)`.
- **`XML.textContent` string concatenation is quadratic** — mislocated: the builder already coalesces chunks (`pendingText.count == 1 ? pendingText[0] : pendingText.joined()`), so the pathological case is handled at parse time; the remaining concatenation is per-node and shallow.
- **`ChartReader.setFormula` is dead code** — cited code does something else: it is called from the chart-series editing path, not from `ChartReader` itself, so "unused" was an artefact of the single-file grep.
- **Deck generation leaves orphaned artifacts when cancelled** — already in place: the pipeline throws on `CancellationError` before the write step rather than after (`DeckGenerator.swift:90-107`).

## Deferred

- **App icon and marketing surface quality** — could not assess: the asset catalog was not inspected and there is no marketing surface in the repo.
- **`Tools/` and `Examples/` executables** — outside the two products under audit; no user-facing surface.
- **Structured error taxonomy for `RostrumError`** — real but low leverage; the strings are already human-readable and the library's consumers are few.
- **Concurrent image generation memory ceiling** (`DeckGenerator.swift:153`) — real, but bounded by `maximumConcurrentRequests` and only reachable on very large illustrated decks.
- **`OPCPackage` multi-pass serialization** — real but measured in milliseconds against a whole-deck save; below the noise floor of item Performance-2.
