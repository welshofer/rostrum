# Lectern

The demo application for **Rostrum** takes a prompt, optional PDF grounding,
intent parameters, and either a bundled `design.md` style or a PowerPoint
template, then produces an editable `.pptx`. Parsing, layout, rendering and file
creation run on-device. Configured text and optional image providers receive
the generation requests; API keys are stored in the system Keychain.

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

Rostrum is a **local path dependency** (`../`).

## Library Lab

Choose **Library Lab** in the sidebar to exercise the library offline. Its 34
configurable demonstrations cover drawing, text/fonts, paragraph justification, standard tab stops, tables, charts, SmartArt,
notes, comments, sections, imports, layouts/themes/templates, design builders,
media, packages and extraction. **Run All** saves and reopens every example,
checks its content, renders previews and extracts its files. Use **Inspect Result**,
**Inspect Before** and **All Files** to examine the real artifacts on macOS or iOS.
No provider key is required. File checks and preview limitations are reported
separately; passing a demo is not a claim of perfect PowerPoint rendering.

Every completed **Run Demo** or **Run All** result is automatically saved as a
new PowerPoint deck in your library, including results with reported findings
or failed checks. Filenames include the demo title, timestamp and a unique ID;
rerunning a demo preserves earlier decks. **Inspect Result** opens that saved
copy. If saving fails, the report shows the error and the diagnostic deck remains
available for inspection or manual saving.

The tab-stop demo shows left, center, right and period-decimal fields against
visible guides, plus tab-aware Latin justification in text boxes and a table cell.
Its bounded controls change the title, guide color, numeric row count and stop
positions. The bundled regular DejaVu Sans face keeps measurements reproducible;
RTL and locale-specific decimal behavior remain outside the demonstrated profile.

The paragraph demo also reproduces two native-measured wrapping boundaries:
a 0.02-point width change moves a character between lines, including across
mixed-size runs. Its shorter fitted copies display the scale computed through
both public fit paths; they do not claim PowerPoint chose that same scale.
A fourth slide applies the same comparison to `officeZ`, with a uniform 18-point
run and fixed-width mixed 18/12-point runs. The narrower option switches the
uniform row between independently recorded native wrap boundaries. The specimens
use separate Latin letter glyphs, matching the native references, and retain
their font sizes and fitting settings through saving and reopening.

The **Imported artwork and text** demo exercises custom curves, SVG artwork,
saved SmartArt drawings, inherited text and empty numbered paragraphs. It uses
redistributable bundled fonts and verifies saved/reopened content and source
preservation. See the [imported-fidelity acceptance record](../docs/IMPORTED-FIDELITY-20261003.md)
for native PowerPoint and separate iOS consumer results and their limits.

The catalog now includes **Native list markers**, **Text alignment**, **Mixed
faces and exact spacing**, and **Table defaults and border joins**. These preserve
native specimens while separate pages exercise public fitting and editing APIs.
They validate saved files, actual inspector previews and exports. Their support
bounds and independent PowerPoint/WebKit comparisons are documented in the
[layout guide](../docs/LAYOUT-ENGINE.md) and
[latest table checkpoint](../docs/LAYOUT-FIDELITY-20261004-17.md).

See the [coverage and verification record](../docs/LIBRARY-LAB-20261002.md).

## Choose a PowerPoint template

In **New Deck**, choose **Use PowerPoint template…** and select a `.potx` or `.pptx`.
Lectern validates a local snapshot and shows its filename and available masters. The snapshot is kept for the current app session; the source file stays
unchanged. Replace or remove the choice at any time before generation. A failed
replacement keeps the previous selection, and generation waits for import to finish.

The template takes precedence over the style catalog. New decks retain its theme,
fonts, slide size, masters and layouts, while replacing its example slides and
sections with generated content. The output is an editable `.pptx`. Template
bytes are used locally and are not sent to the text or image provider.

Generated content fills the selected master’s native placeholders and retains its
background artwork. Content is fitted or split across readable continuation slides;
a layout that cannot fit is reported instead of flattening the template. Remove the template to return to the selected catalog
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
preserves embedded faces, and reports unavailable metrics. Inspection registers
Arial as an explicit measured preview fallback so missing fonts use consistent
layout and drawing; original document font names remain unchanged. The missing
font still appears in the fidelity report. Rendering limitations
remain visible separately from schema findings.

The deterministic [feature pipeline fixture](Tests/LecternCoreTests/Fixtures/FeaturePipeline/README.md)
combines native/custom tables, rich text, image crops, notes, comments, sections,
duplication and import. Run the core and app checks from the repository root:

```sh
swift test --package-path Lectern --jobs 2
python3 Lectern/scripts/test-inspection-headless.py --all-app-tests --output /tmp/lectern-app-headless.json
Lectern/scripts/test-app.sh -parallel-testing-enabled NO
```

The **LecternTests** scheme uses a separate **LecternTestHost** app with isolated
defaults, library folders and diagnostics, disabled credential operations and
disabled live generation. It still exercises the production startup tasks and enables
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
        GEN["DeckGenerator<br/>draft → validate → optional repair<br/>→ QA → normalize → illustrate → render"]
        IR["DeckIR lectern.deck/1<br/>structural + soft validation<br/>unknown layouts downgrade"]
        REN["DeckRenderer (actor)<br/>IR layout → Rostrum builder"]
        CAT["StyleCatalog<br/>150 bundled design.md"]
        PROV["LLMProvider<br/>OpenAI Responses<br/>optional image providers"]
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

`LecternCore` has fixture-backed pipeline tests. They verify deterministic
behavior without paid calls; they do not establish live provider quality or
PowerPoint acceptance for every output. The source and tests below are the
repository's executable contract; internal spec references are historical context.

- **DeckIR** (`lectern.deck/1`): `Codable` models, structural + soft validation
  (§8.3–8.4), unknown-layout downgrade (§8.5), and the one-shot repair prompt
  (§8.7). Nothing reaches the renderer unvalidated (invariant I3).
- **DeckGenerator**: draft → decode/validate → at most one repair if needed →
  optional QA revision → normalize/revalidate → optional illustrations → render.
  A failed or structurally invalid QA revision keeps the validated draft.
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

Inspection keeps every original slide position, showing a numbered placeholder
when a preview fails. Contact sheets and filmstrips retain the deck's aspect
ratio, including 4:3 and portrait. macOS bitmap previews share one WebKit host
and a bounded cache whose keys include rendering dimensions. See the
[preview and performance checks](../Tools/rostrum-benchmark/README.md) for
reproducible snapshots and timing measurements.

The SwiftUI shell (`App/`) is a real macOS app. Its Xcode project is **generated
from `project.yml`** with [xcodegen] — `project.yml` is the checked-in source of
truth; the `.xcodeproj` is a build artifact (gitignored, like `.build/`). No
manual project bookkeeping, no merge conflicts in a pbxproj.

```sh
cd Lectern
scripts/build.sh       # generates the project as needed; honors .signing.local
scripts/test-app.sh    # app-hosted tests, with the same signing configuration
```

Hosted tests refuse to start while Lectern or LecternTestHost is running. Finish
your work and close the app yourself before running them; the script never
terminates an app. Test products use `.build-xcode-tests` or the separate
`LECTERN_TEST_DERIVED_DATA_PATH` override. Production build products retain their
usual `.build-xcode` directory and `LECTERN_DERIVED_DATA_PATH` override.

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
  Replacing a key updates the existing item without deleting it first; failed
  saves and removals remain visible, and access failures are distinct from a
  missing key.
- **`SettingsView`** — OpenAI text strength (Astra, Sol, Luna), reasoning effort,
  image model (Sunburst, Flare), and image quality dropdowns. Optional image
  generation has its own OpenAI key entry; it may use the same key as text. The
  field is write-only; a saved key shows a masked "saved" prompt and a green
  Keychain badge instead of ever echoing the secret.
- **`ProviderFactory`** (LecternCore, unit-tested) — the one UI-free place the
  "which provider" decision lives: a stored key for a wired provider → live;
  no key → generation is blocked with a clear message. There is **no mock
  fallback** — Lectern never fabricates a deck. `AppState` persists only the
  non-secret choice (provider/model) and reads key *presence* from the
  Keychain.

## Implemented behavior and remaining work

- Generation uses OpenAI only: Astra (`gpt-6-astra`), Sol (`gpt-6.1-sol`), and
  Luna (`gpt-6-luna`) through `/v1/responses`; Sunburst
  (`gpt-image-2.5-sunburst`) and Flare (`gpt-image-2.5-flare`) through the Images API.
  Defaults are Sol / medium reasoning and Flare / automatic image quality.
  Text supports low, medium, high, extra high, and maximum effort; Luna also
  supports none. Switching from Luna / none to another model selects low.
  All choices persist and apply to draft, repair, and editorial passes.
- Old provider/model preferences migrate to these defaults. Existing OpenAI
  Keychain entries are reused; other vendors' keys are never copied or deleted.
  Legacy provider enum values remain for decoding existing records.
- OpenAI requests use `store: false`, the existing untrusted-input contract,
  forced `emit_deck` function calls, validation and repair. Output budgets reserve
  additional room for reasoning. Higher effort can take longer and cost more.
- Image sizes preserve each requested aspect ratio, including exact 16:9 slide
  backgrounds. Style and background/panel art direction remain shared.
- Model capabilities were checked against the [OpenAI model catalog](https://developers.openai.com/api/docs/models)
  on October 2, 2026. Model availability still depends on the API project.
- `Storage/DeckLibrary.swift` and `App/AppState.swift` load, rename and delete
  saved deck files. This is a file-backed library, not a pending SwiftData store.
- `Providers/PriceTable.swift` supplies estimates displayed by AppState. These
  are historical estimates, not a provider billing reconciliation. The new
  reasoning models have no preflight dollar estimate: reasoning and image usage
  vary, and Lectern does not substitute a legacy model's price.
- Generation cancellation is available in ContentView and invalidates the
  active RunGate before cancelling its task. Tests cover stale run rejection.
- Live model quality and PowerPoint fidelity still need sample-based inspection;
  fixture tests cannot substitute for those checks. See ROADMAP.md for other
  deliberate deferrals rather than treating the original M3–M5 plan as current.

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

## PowerPoint templates and layout composition

In Compose, choose **Use PowerPoint template** in the Design card and select a
`.potx`. Lectern snapshots the file, lists its masters/layout counts, and lets you
select a master or use all masters. **Use theme instead** returns to the design.md
catalog. Template generation uses the template's page size, layout geometry,
typography, colors and artwork; the selected design.md does not override it.
Exports retain the template library, including every used master and layout.

The generator supplies concise content to `RostrumLayout`. Text occupies inherited
placeholders; charts and tables are native editable objects. Generated images are
inserted only when the selected layout offers a picture placeholder. Missing picture
slots and conversion of structured content to template text produce warnings. Metrics,
diagrams, timelines, quadrants and bands currently become text within native template
content regions; they are not reconstructed as native diagrams. Wrapped text uses safe
space below its placeholder when the template allows flow. Template shrink-to-fit
settings use native font scaling without replacing inherited fonts. Neither operation
changes the template's master or layout parts. Content that still cannot fit stops
export with an error instead of overflowing the slide. Missing or unmeasured
fonts remain visible in the result's diagnostics.

Chart and table explanations and sources reserve their measured wrapped height before
layout selection; they are not squeezed into a fixed caption strip. If no layout can
fit both a readable object and its explanation, the full text continues on following
template slides. Section membership and speaker notes are retained, and the result
reports the added slides. Export failures
retain the final normalized draft in the protected diagnostics folder, using the same
seven-day retention policy as rejected drafts, so it can be replayed without another
model request.

Template selection prefers layouts with the appropriate number of content regions
and enough usable area. Table rows are measured with their cell padding before
placing captions; generated diagrams fit wholly inside picture placeholders instead
of being cropped. Imported master/layout/theme parts remain unchanged.

Theme-based generation compiles design.md into the master/theme and publishes a
subordinate layout for each authored composition. Header dividers follow the measured
title band, body text gets the remaining region, and photo backgrounds use contrasting
text including footers. Dense text, image and comparison slides continue onto additional
pages at readable sizes. Long sources flow onto source-note pages. The final fit pass
can compact spacing and reduce body type to 17pt; unsupported content that still cannot
fit produces an explicit error.

Recovery previews show the revised slide count and layout adjustments. Recomposition
preserves other slides and existing review comments. **Rebuild the entire deck from
saved content** allows the page count to change freely in a new copy; later manual
edits and comments remain only in the original file.

Local acceptance evidence and the supplied-template test deck are recorded in
`audit/template-acceptance/`. Structural success is separate from PowerPoint visual
acceptance. To isolate a build from a running app, the macOS build and test wrappers
accept `LECTERN_DERIVED_DATA_PATH`; app-hosted tests also need a distinct bundle ID
when the original Lectern must stay running.
