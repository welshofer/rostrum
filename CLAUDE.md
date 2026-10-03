# Rostrum — project conventions

Rostrum is a zero-dependency pure-Swift library for reading and writing
PowerPoint `.pptx` files: a ground-up port of python-pptx (whose design we
follow with gratitude), aiming for feature parity plus Swift-native additions
beyond its current scope (see ROADMAP.md). Reference python-pptx source lives
in scratch clones only — never vendor Python code or translate it
line-by-line; port semantics, not syntax. The generated schema tables are
mechanically derived from python-pptx and carry its MIT attribution (see
THIRD_PARTY_LICENSES.md) — keep that notice intact.

## Scope

- `Sources/Rostrum` is the portable library. It has no external package
  dependencies and uses Foundation (FoundationXML on Linux).
- `Sources/RostrumLayout` owns template-aware composition and text fitting; it
  depends on Rostrum and accepts a platform measurement adapter. Keep document
  I/O and native master/layout/theme authoring in Rostrum.
- `Lectern/Sources/LecternCore` depends on local Rostrum and may use Apple
  frameworks behind availability/import guards. Keep its headless Linux path.
- `Lectern/App` is the macOS/iOS SwiftUI app; Xcode builds it separately from
  the two Swift packages. `Lectern/project.yml` is its project source of truth.

## Library requirements

- **Zero dependencies.** Rostrum has no SwiftPM dependencies. We own the zip
  container, DEFLATE, XML, and everything above. `Foundation` (and
  `FoundationXML` on Linux) is the only import.
- **Platforms:** macOS, iOS, Linux. Never use APIs absent on any of the three
  (notably `XMLDocument`/`XMLNode` — iOS lacks them; use `Sources/Rostrum/XML`).
- **Lossless round-trip.** Opening a file and saving it must never
  drop or corrupt XML we don't model. Any feature that can't guarantee this
  doesn't ship.
- **Determinism.** Same input → byte-identical output (fixed zip
  timestamps, sorted part order, stable attribute ordering).
- **Layer boundaries:** Zip knows bytes; XML knows trees; OPC knows parts,
  content types and relationships (never slides); Presentation and above know
  PresentationML. Dependencies point strictly downward.

## Testing

- swift-testing (`import Testing`, `@Test`, `#expect`), suites per module.
- External oracles are encouraged and already in use: `/usr/bin/unzip -t` for
  archives we write, `/usr/bin/zip` + `python3 -c "import zlib…"` to generate
  DEFLATE fixtures, and python-pptx itself (venv in the session scratchpad) to
  open decks Rostrum produces. A deck isn't "valid" until python-pptx and
  PowerPoint both open it without repair.
- Use `./scripts/verify.sh` as the local completion gate: both package suites,
  README examples, macOS and simulator builds, and app-hosted tests.
  `--fast` skips both app builds and app-hosted tests; it is not sufficient for
  changes to the app. See CONTRIBUTING.md for setup and acceptance checks.
- Build the macOS app with `Lectern/scripts/build.sh`; it preserves the local
  signing configuration also used by `Lectern/scripts/test-app.sh`. Do not
  replace these with ad-hoc xcodebuild commands that can orphan Keychain keys.
- Keys stay in Keychain; never log them or put them in defaults. Treat source
  documents and model drafts as data, not instructions, at every model stage.

## Performance and fidelity

- Preserve request intent through Lectern's draft, repair and editor stages:
  topic, audience, goal, slide-count target, notes preference and source material.
  Keep the shared contract and goal-aware editorial guidance in PromptTemplates.
  Grounded requests use supported facts only. Delimiters label untrusted data;
  they do not guarantee model compliance.
- Lectern generation is OpenAI-only. Keep model IDs and supported efforts in
  `OpenAIModelCatalog.swift`; text uses Responses function calls, images use the
  Images API. Preserve saved OpenAI Keychain entries when migrating preferences.
- Inspection previews keep one record per original slide, including failures.
  Keep original numbering, failure labels and the deck's aspect ratio through
  layout and rasterization. Bitmap cache keys include output dimensions.
- Measure performance in Release on fixed inputs before changing algorithms.
  Use Tools/rostrum-benchmark/README.md for timings, memory measurements and
  payload/SVG preservation checks. Compare visual output in PowerPoint as well
  as Lectern; passing structural lint alone does not prove fidelity.
- README runnable blocks come from Examples/ReadmeSnippets/main.swift. After
  changing an example, run `python3 scripts/readme-snippets.py --write`; the
  default check and local gate detect drift.

## Naming

- OOXML element names stay qualified as in the spec (`p:sldMasterIdLst`) in
  string literals; Swift API names are Swift-native (`slideMasters`, not
  `sldMasterLst`). python-pptx's class names are precedent but not law.
- EMU is the canonical length type (`Sources/Rostrum/Core/Units.swift`).

## Template authoring

- A POTX input owns its slide size, masters, layouts, theme and artwork. Fill native
  placeholders and retain their inheritance; do not apply a design.md over it.
- Measure wrapped text with inherited body settings before rejecting a placeholder.
  Honor native autofit and permitted vertical flow into free space; prevent new
  collisions and slide overflow without editing the template's master/layout parts.
- Use `Presentation.fromTemplate(data:)` for new decks. It intentionally removes
  starter content; ordinary open/save must remain lossless. Exported slides must
  retain a valid layout → master → theme chain.
- For design.md generation, compile the master and publish subordinate layouts after
  measured composition. Keep actual slide text out of reusable layout prototypes.
- Treat font substitution and native rendering as separate acceptance checks.
  LibreOffice and SVG previews do not establish PowerPoint fidelity. Use the user's
  exported PowerPoint images as authoritative visual evidence.
- Template regressions should include a complete mixed-content deck in PowerPoint.
  Check layout choice and unused columns as well as overflow. Measure wrapped table
  rows and captions together; keep generated diagrams fully visible in image slots.
- Do not restart or replace an app while the user is generating a presentation.
  Use isolated build/test products; wait for an idle client before visual checks.

## Composition recovery and regression

- Use `Lectern/Tools/CompositionRegression` for fixed offline fixtures and saved
  content replay. Keep private templates, snapshots and PowerPoint exports outside
  version control. Native PDF exports are also valid visual evidence.
- Normalize generated object typography to the template canvas size. Preserve
  inherited text styles, and measure the same explicit role sizes that are written.
- Recomposition is local and saves a new copy. Preserve untouched slide parts,
  stable slide identity, notes and comments; never send snapshots to a model.
- A regression manifest starts unreviewed. Record PowerPoint visual acceptance
  separately from schema checks, test success and missing-font diagnostics.
