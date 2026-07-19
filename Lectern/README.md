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

## What remains (needs Xcode — M3–M5)

These are macOS-app / network concerns that can't be built or verified headlessly:

- **The SwiftUI app** (Liquid Glass, §5): `NavigationSplitView` with a
  History sidebar and a Compose → Generating → Result state machine; Settings
  scene. Drives `DeckGenerator` (default `MockProvider`; Debug menu switches
  failure modes).
- **Live providers** (§7.2): Anthropic / OpenAI / Gemini / Custom, hand-rolled on
  `URLSession` (no vendor SDKs), each conforming to `LLMProvider` — build the
  request with the IR JSON Schema (generated from `DeckIR`), stream Stage-B
  progress, and return `RawDraft`. The two-stage outline→deck pipeline and the
  PDF grounding ladder (§7.4) live here.
- **Keychain** (invariant I1), **History** (SwiftData, §11), **Settings**
  (§10), and the **PriceTable** cost estimate (§10.3).

The `LLMProvider` protocol, `GenerationEvent` stream, and `LecternError` taxonomy
(§12) are already defined, so a live provider is a drop-in conformance.

## Open items

- **Style catalog source.** The vzestup repo ships ~150 style **thumbnails**
  (`style-samples/`, `public/style-thumbs/`) but the `design.md` **source files**
  weren't in the tree — they need locating (or generating) for `StyleCatalog` to
  load real styles. The `sunflower.md` format is confirmed working, so the
  binding is sound.
- OQ-3 (final app name), OQ-5 (bundle id/signing) — owner decisions.
