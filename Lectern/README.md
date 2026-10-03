# Lectern

The demo application for **Rostrum** — prove the full loop in one window: a
prompt, optional PDF grounding, a few intent parameters, and one of many bundled
`design.md` styles or a PowerPoint template go in; a native `.pptx` written entirely by Rostrum comes out.
Everything runs on-device except the LLM call. (Section references like §8.3
below cite the internal Lectern spec, which is not part of this repository.)

## Layout

```
Lectern/
├── Package.swift            # LecternCore SPM package (depends on Rostrum via ../)
├── Sources/LecternCore/     # UI-free, fully testable
│   ├── DeckIR/              # lectern.deck/1 IR + validation + repair prompt
│   ├── Export/              # deck → folder: Markdown + media + chart CSVs
│   ├── Inspection/          # deck → counts, findings, digests, previews
│   ├── LibraryLab/          # offline executable catalog + saved-file verification
│   ├── Providers/           # LLMProvider protocol, DeckGenerator, image providers, errors
│   ├── Rendering/           # DeckRenderer actor → Rostrum builders
│   └── StyleCatalog/        # design.md catalog loader
└── Tests/LecternCoreTests/  # the acceptance core, fixture-backed
```

Rostrum is a **local path dependency** (`../`), resolving OQ-4.

## Library Lab

Choose **Library Lab** in the sidebar to exercise the library offline. Its 25
configurable demonstrations cover drawing, text/fonts, paragraph justification, standard tab stops, tables, charts, SmartArt,
notes, comments, sections, imports, layouts/themes/templates, design builders,
media, packages and extraction. **Run All** saves and reopens every example,
checks its content, renders previews and extracts its files. Use **Inspect Result**,
**Inspect Before** and **All Files** to examine the real artifacts on macOS or iOS.
No provider key is required. File checks and preview limitations are reported
separately; passing a demo is not a claim of perfect PowerPoint rendering.

The tab-stop demo shows left, center, right and period-decimal fields against
visible guides, plus tab-aware Latin justification in text boxes and a table cell.
Its bounded controls change the title, guide color, numeric row count and stop
positions. The bundled regular DejaVu Sans face keeps measurements reproducible;
RTL and locale-specific decimal behavior remain outside the demonstrated profile.

See the [coverage and verification record](../docs/LIBRARY-LAB-20261002.md).

## Choose a PowerPoint template

In **New Deck**, choose **Choose Template…** and select a `.potx` or `.pptx`.
Lectern validates a local snapshot and shows its filename, canvas size and layout
count. The snapshot is kept for the current app session; the source file stays
unchanged. Replace or remove the choice at any time before generation. A failed
replacement keeps the previous selection, and generation waits for import to finish.

The template takes precedence over the style catalog. New decks retain its theme,
fonts, slide size, masters and layouts, while replacing its example slides and
sections with generated content. The output is an editable `.pptx`. Template
bytes are used locally and are not sent to the text or image provider.

Generated content uses Lectern's compositions and the first slide master's theme
and layouts. Arbitrary placeholder positions are not reproduced, and generated
background fills can cover template background imagery. These limits are shown in
the form and output warnings. Remove the template to return to the selected catalog
style. For an offline sample, run **Library Lab → Templates and document properties**
and choose its `template.potx` from **All Files**.

See the [template selection verification record](../docs/TEMPLATE-SELECTION-20261002.md)
for file limits, regression coverage and native PowerPoint checks.

## Feature integration and regression checks

The inspector exposes table cells, speaker notes, section membership, modern
comment threads and replies, resolved status, and legacy comments. Wide tables
page through six columns with lazy rows. Export includes table text, notes,
sections and complete comment text alongside the original media bytes.

Preview geometry follows each slide's aspect ratio. macOS snapshots have bounded
dimensions, queue depth and completion time; cache identity includes the full SVG
and output size. Installed font lookup validates actual families and styles,
preserves embedded faces, and reports unavailable metrics. Rendering limitations
remain visible separately from schema findings.

The deterministic [feature pipeline fixture](Tests/LecternCoreTests/Fixtures/FeaturePipeline/README.md)
combines native/custom tables, rich text, image crops, notes, comments, sections,
duplication and import. Run the core and app checks from the repository root:

```sh
swift test --package-path Lectern --jobs 2
python3 Lectern/scripts/test-inspection-headless.py --all-app-tests
Lectern/scripts/test-app.sh -parallel-testing-enabled NO
```

The Xcode Test action isolates defaults, library folders and diagnostics and skips
keychain reads while exercising the production startup tasks. It also enables
real WebKit portrait/4:3 snapshot tests. The headless harness exercises app state
and view compilation; it does not replace native UI or WebKit checks. Normal app
launches retain their usual storage and keychain behavior. See the
[October 2 integration record](../docs/LECTERN-INTEGRATION-20261002.md) for exact
results, live inspection/export evidence and remaining limits.

## How a deck gets made

```mermaid
flowchart LR
    subgraph Shell["App shell (SwiftUI, per-platform seams behind #if os)"]
        UI["Compose<br/>prompt · audience · goal<br/>length · style · PDF"]
        SET["Settings<br/>provider · model · keys"]
        KC["KeychainStore<br/>keys live only here"]
    end
    subgraph Core["LecternCore (UI-free, tested headless)"]
        GEN["DeckGenerator<br/>draft → decode → validate<br/>→ one repair → render"]
        IR["DeckIR lectern.deck/1<br/>structural + soft validation<br/>unknown layouts downgrade"]
        REN["DeckRenderer (actor)<br/>IR layout → Rostrum builder"]
        CAT["StyleCatalog<br/>150 bundled design.md"]
        PROV["LLMProvider<br/>Anthropic · image providers"]
    end
    R["Rostrum<br/>design-authoring builders<br/>→ native .pptx"]
    OUT[("deck.pptx<br/>opens clean in PowerPoint,<br/>Keynote, python-pptx")]

    UI --> GEN
    SET --> KC
    KC --> PROV
    GEN --> PROV
    PROV --> GEN
    GEN --> IR
    IR --> REN
    CAT --> REN
    REN --> R
    R --> OUT
```

Two invariants anchor the pipeline: **I1** — API keys exist only in the
Keychain (never UserDefaults, never logs, write-only UI); **I3** — nothing
reaches the renderer unvalidated (the IR is checked, repaired at most once,
and unknown layouts downgrade to bullets rather than crash).

## What's built and proven (headless)

`LecternCore` is complete and tested end-to-end against a fixture provider —
the spec's fixture-first M1–M2: *the whole pipeline is proven before a single
real network call*.

- **DeckIR** (`lectern.deck/1`): `Codable` models, structural + soft validation
  (§8.3–8.4), unknown-layout downgrade (§8.5), and the one-shot repair prompt
  (§8.7). Nothing reaches the renderer unvalidated (invariant I3).
- **DeckGenerator**: `draft → decode+validate → one repair → render`.
- **DeckInspector / DeckExporter**: the other direction. The app opens on a
  fork — **Create** or **Inspect** — and Inspect (⌘I) takes any `.pptx`, one
  Lectern made or one that arrived by email, and shows what it is made of:
  counts, geometry, sections, schema findings, a contact sheet of every slide,
  and every word in it. **Export Everything…** then writes a folder holding a
  Markdown file of the deck's words beside a folder per slide with its images,
  movies, sounds and one CSV per chart.

  Every step of that is off the main actor and reports progress — slide
  rendering drives a real `n of N` bar — because opening a large deck and
  drawing every slide is seconds of work, not milliseconds. The extraction
  itself is Rostrum's `DeckOutline`/`DeckExport`; what lives here is the part
  with a user in front of it, and it speaks in `String` and `Int` so the app
  target never needs to link Rostrum.
- **DeckRenderer** (an `actor`, invariant I2): maps each IR layout onto Rostrum's
  design-authoring builders and applies the chosen `design.md`:

  | IR layout | Rostrum builder |
  |---|---|
  | `title` | `titleSlide` |
  | `sectionHeader` | `sectionSlide` |
  | `agenda` / `bullets` | `bulletSlide` |
  | `twoColumn` / `comparison` | `comparisonSlide` |
  | `bigNumber` | `calloutSlide` |
  | `quote` | `quoteSlide` |
  | `closing` | `closingSlide` |
  | `chart` (well-formed data) | `chartSlide` — else bullets fallback |
  | `metrics` | `metricsSlide` |
  | `bands` | `bandsSlide`, or native SmartArt when opted in |
  | `diagram` (process / cycle / pyramid) | `processSlide` / `pyramidSlide`, or SmartArt |
  | `unknown` | downgraded to bullets by validation |

  Styling is `Presentation.applyDesign(contentsOf: design.md)` — **this resolves
  OQ-1**. Sections and speaker notes flow through.
- **FixtureProvider** (tests only): replays a fixture with injectable
  failures, so the whole pipeline is exercised headlessly. The shipping app
  has **no mock path** — generation requires a real key.
- **StyleCatalog**: scans a `design.md` directory into `[Style]`.

**Verified:** the fixture-driven pipeline renders a deck that opens in PowerPoint without
repair (AT-10), with the exact slide count (AT-11), the notes toggle honored
(AT-12), the repair loop recovering once then failing (AT-14), and unknown
layouts downgrading (AT-15). Run it:

```sh
cd Lectern && swift test
```

## The macOS app

The SwiftUI shell (`App/`) is a real macOS app. Its Xcode project is **generated
from `project.yml`** with [xcodegen] — `project.yml` is the checked-in source of
truth; the `.xcodeproj` is a build artifact (gitignored, like `.build/`). No
manual project bookkeeping, no merge conflicts in a pbxproj.

```sh
cd Lectern
xcodegen generate                                              # project.yml → Lectern.xcodeproj
xcodebuild -project Lectern.xcodeproj -scheme Lectern build     # or just open it in Xcode
```

## The iOS/iPadOS app

The same SwiftUI shell builds as a second target, **`Lectern-iOS`** (iPhone +
iPad, iOS/iPadOS 26+, Liquid Glass system components throughout — the same
`.glass`/`.glassProminent` styling as the Mac app). One source tree; the
platform seams live behind `#if os(...)`:

- **Settings** is a sheet behind a toolbar gear (no Settings scene on iOS);
  the macOS quit-guard and window-frame plumbing compile out.
- **Result actions**: Quick Look **Preview** and a **Share** sheet replace
  Open/Reveal-in-Finder. Decks are written to `Documents/Decks` and, via
  `UIFileSharingEnabled` + `LSSupportsOpeningDocumentsInPlace`, appear in the
  **Files** app.
- **Keys** live in the iOS data-protection keychain (same `KeychainStore`,
  no code change needed).
- PDF grounding works via the document picker *and* drag-and-drop from Files
  (iPad); compact widths stack the Compose cards; the style-card favorite
  heart is always visible (no hover on touch).

```sh
cd Lectern
xcodegen generate
scripts/build-ios.sh        # simulator build — ad-hoc signed, no team needed
```

Simulator builds are **ad hoc signed with a minimal entitlements file**
(`App/Lectern-iOS-Sim.entitlements`), not unsigned: a fully unsigned app has
no `application-identifier`, and every Keychain call then fails with
`errSecMissingEntitlement (-34018)` — keys silently refuse to save. To run on
hardware, open the project in Xcode and pick your team under Signing &
Capabilities for `Lectern-iOS`, or from the CLI:

```sh
xcodebuild -scheme Lectern-iOS -destination 'platform=iOS,id=<device-udid>' \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
  DEVELOPMENT_TEAM=<your-team-id> CODE_SIGN_STYLE=Automatic build
xcrun devicectl device install app --device <device-udid> <path>/Lectern.app
```

**Verified:** the app compiles under **Swift 6 complete strict-concurrency**,
bundles all 150 `design.md` styles as an app resource, and launches clean on
macOS, iPadOS, and iOS (simulator and hardware). The Compose → Generating →
Result → Failed state machine (`ContentView`), the `@Observable` `AppState`
driving `DeckGenerator`, the bundled **Style picker** (curated Light/Dark +
vibe filter chips), and Settings are all live — the full prompt-to-PowerPoint
round-trip has been exercised on Mac and iPad with a real key.

[xcodegen]: https://github.com/yonaskolb/XcodeGen

## The local gate

From the repo root, `./scripts/verify.sh` is the full local gate: it runs the
Rostrum and LecternCore suites, the README snippets, both app builds (macOS and
the iOS simulator), and — the part nothing else covers — the **app-hosted
tests** (`Lectern/AppTests`), which exercise `AppState` and the SwiftUI target
that `swift test` never compiles.

CI deliberately does less. Linux runs on every push (Swift 6.0 and 6.1); a
single macOS job runs on pull requests only, because a hosted macOS runner
bills about ten times the Linux rate. Even that job stops at building the app —
nothing in CI ever runs the app-hosted tests. This local gate is where the
Apple side actually gets verified, which is why the pre-push hook matters.

Install the pre-push hook once so every `git push` runs it for you:

```sh
./scripts/install-hooks.sh   # points core.hooksPath at scripts/hooks
```

After that, `git push` runs `./scripts/verify.sh` first and refuses the push if
it fails (`--fast` skips the app builds; `git push --no-verify` bypasses once).

## Settings, keys, and provider selection — done

Keys and provider choice are wired end-to-end (§10 / invariant I1):

- **`KeychainStore`** — API keys live *only* in the login keychain (a
  generic-password item per provider). Never UserDefaults, never logged; the
  `SecureField` is write-only, so a stored key never round-trips through the UI.
- **`SettingsView`** — provider picker + model + key entry, plus optional
  image-provider keys (OpenAI Images / Gemini) for on-brand slide art. The
  field is write-only; a saved key shows a masked "saved" prompt and a green
  Keychain badge instead of ever echoing the secret.
- **`ProviderFactory`** (LecternCore, unit-tested) — the one UI-free place the
  "which provider" decision lives: a stored key for a wired provider → live;
  no key → generation is blocked with a clear message. There is **no mock
  fallback** — Lectern never fabricates a deck. `AppState` persists only the
  non-secret choice (provider/model) and reads key *presence* from the
  Keychain.

## What remains (M3–M5)

- **Live providers** (§7.2): `AnthropicProvider` is written (URLSession, no vendor
  SDK) and selected automatically once a key is stored; OpenAI / Gemini / Custom
  follow the same `LLMProvider` shape. The two-stage outline→deck pipeline and the
  PDF grounding ladder (§7.4) live here. *(The live round-trip needs a real key to
  smoke-test — not exercisable in headless CI.)*
- **History** (SwiftData, §11): persist past decks in the sidebar (currently a
  stub).
- **PriceTable** cost estimate (§10.3) and **Liquid Glass** polish (§3).

The `LLMProvider` protocol, `GenerationEvent` stream, and `LecternError` taxonomy
(§12) are defined, so a new live provider is a drop-in conformance.

## Open items

- **Style catalog source — resolved.** All 150 real `design.md` files ship in
  `App/Resources/Styles/` and are bundled into the app. Every one loads, parses,
  and renders to a PowerPoint-clean deck; the picker selects among them.
  *Provenance:* each style is an original distillation of design *principles*
  (palette, type scale, spacing, mood) observed across real-world sites — no
  copied assets, markup, or imagery. Styles may *name* commercial typefaces;
  no font files are bundled, and PowerPoint substitutes normally when a named
  face isn't installed.
- OQ-3 (final app name), OQ-5 (bundle id/signing) — owner decisions. The
  macOS target builds with a stable Development signing identity (which is
  what lets login-keychain API keys survive rebuilds — see the note in
  `project.yml`); the iOS simulator target signs ad hoc; device builds use
  Xcode automatic signing. Bundle id `com.lectern.app` on both platforms.
