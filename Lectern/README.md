# Lectern

The demo application for **Rostrum** — prove the full loop in one window: a
prompt, optional PDF grounding, a few intent parameters, and one of many bundled
`design.md` styles go in; a native `.pptx` written entirely by Rostrum comes out.
Everything runs on-device except the LLM call. (Spec: `lectern-spec-v1.0.md`.)

## Layout

```
Lectern/
├── Package.swift            # LecternCore SPM package (depends on Rostrum via ../)
├── Sources/LecternCore/     # UI-free, fully testable
│   ├── DeckIR/              # lectern.deck/1 IR + validation + repair prompt
│   ├── Providers/           # LLMProvider protocol, MockProvider, DeckGenerator, errors
│   ├── Rendering/           # DeckRenderer actor → Rostrum builders
│   └── StyleCatalog/        # design.md catalog loader
└── Tests/LecternCoreTests/  # the acceptance core, Mock-backed
```

Rostrum is a **local path dependency** (`../`), resolving OQ-4.

## What's built and proven (headless)

`LecternCore` is complete and tested end-to-end against `MockProvider` — the
spec's Mock-first M1–M2: *the whole app works before a single real network call*.

- **DeckIR** (`lectern.deck/1`): `Codable` models, structural + soft validation
  (§8.3–8.4), unknown-layout downgrade (§8.5), and the one-shot repair prompt
  (§8.7). Nothing reaches the renderer unvalidated (invariant I3).
- **DeckGenerator**: `draft → decode+validate → one repair → render`.
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
  | `closing` | `sectionSlide` |

  Styling is `Presentation.applyDesign(contentsOf: design.md)` — **this resolves
  OQ-1**. Sections and speaker notes flow through.
- **MockProvider**: replays a fixture with injectable failures
  (`invalidJSONOnce/Always`, `rateLimited`, `slowDrafting`).
- **StyleCatalog**: scans a `design.md` directory into `[Style]`.

**Verified:** the Mock pipeline renders a deck that opens in PowerPoint without
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

**Verified:** the app compiles under **Swift 6 complete strict-concurrency**,
bundles all 150 `design.md` styles as an app resource, and launches clean. The
Compose → Generating → Result → Failed state machine (`ContentView`), the
`@Observable` `AppState` driving `DeckGenerator` (default `MockProvider`), the
bundled **Style picker**, and the Settings scene are all in and building — so a
generated deck can be written, revealed in Finder, and opened, entirely from the
UI, with no API key.

[xcodegen]: https://github.com/yonaskolb/XcodeGen

## Settings, keys, and provider selection — done

Keys and provider choice are wired end-to-end (§10 / invariant I1):

- **`KeychainStore`** — API keys live *only* in the login keychain (a
  generic-password item per provider). Never UserDefaults, never logged; the
  `SecureField` is write-only, so a stored key never round-trips through the UI.
- **`SettingsView`** — provider picker + model + key entry. Un-wired providers
  are labeled "(soon)" and stay on the Mock.
- **`ProviderFactory`** (LecternCore, unit-tested) — the one UI-free place the
  "which provider" decision lives: a stored key for a wired provider → live;
  otherwise `MockProvider`, so the app **always runs offline**. `AppState`
  persists only the non-secret choice (provider/model) and reads key *presence*
  from the Keychain.

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
- OQ-3 (final app name), OQ-5 (bundle id/signing) — owner decisions. The project
  currently builds unsigned (`CODE_SIGNING_ALLOWED=NO`) under bundle id
  `com.lectern.app`.
