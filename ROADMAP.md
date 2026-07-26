# Rostrum roadmap

Goal: full python-pptx feature parity in pure Swift, then Swift-native
additions beyond its current scope. Architecture:
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md). Every phase ships something a
user can run; the byte-identity corpus gate and the python-pptx oracle run
from phase 0 onward.

> **Truth pass (2026-07-22).** This file is the parity scoreboard newcomers
> trust, so it was audited line-by-line against the code. Three earlier
> claims were overstated and are corrected below rather than silently
> edited: bubble/radar/stock/combo charts **did not ship** in the v0.1 P3
> phase; the animations/transitions round-trip **has no dedicated test**;
> and the SVG renderer **did not** use "the TTF metrics we already parse" —
> no metrics parsing existed until the v0.4 program below built it.

## Phase 0 — Foundations ✅ (broke ground 2026-07-18)

- [x] Zero-dependency SwiftPM package (macOS/iOS/Linux)
- [x] Zip writer (STORED, deterministic, CRC-32) — validated by `unzip -t`
- [x] Pure-Swift inflate (RFC 1951) + zip reader (STORED + DEFLATE)
- [x] XML DOM: prefix-preserving parse (XMLParser bridge) + deterministic serializer
- [x] OPC layer: PackURI, content types, relationships, package read/write
- [x] Minimal 16:9 deck from XML constants; `Presentation` new/open/save
- [x] Oracle: python-pptx opens Rostrum output

## Phase 1 — The object model skeleton (✅ core, 2026-07-18)

- [x] Pristine-blob dirty-flag machinery on `Part` (byte-identity test live)
- [x] Slides collection: iterate, `add()`, **plus three long-requested
  operations on python-pptx's wishlist: `remove`, `move`, `duplicate`**
- [x] ShapeGeometry enum (178 presets) extracted from python-pptx tables
- [x] `rostrum-gen` v0: declarative schema tables (child ordering, attribute
  defaults) generated from python-pptx's, consumed by generic DOM helpers.
  *Still open:* per-element typed accessors on top of the tables.
- [ ] Layouts/masters collections — *partial:* `layouts`/`layout(type:)` and
  placeholder-inheriting frames shipped, but only the **first** master's
  layouts are visible; multi-master decks (which `DeckMerge` can already
  import!) need a real `slideMasters` collection
- [x] Byte-identity corpus gate in CI — Rostrum-generated corpus (2026-07-19);
  **real-deck fixtures** enroll automatically via
  `Tests/RostrumTests/Fixtures/RealDecks/` (scaffold 2026-07-22, decks landing)

## Phase 2 — Shapes and text (✅ core, 2026-07-18)

- [x] Autoshapes with preset geometry, transforms (position/size/rotation)
- [x] Fills: solid, solid+alpha, linear gradient; explicit line format;
  soft shadows; per-slide backgrounds
- [x] Text: paragraphs, runs, fonts, sizes, bold/italic, colors, alignment,
  line/paragraph spacing, letter tracking, anchors, margins
- [x] Proof-of-capability: `Examples/ClimateDeck` — 15-slide designed deck,
  rendered and visually verified via LibreOffice
- [x] Pictures: PNG/JPEG/GIF sniffers, content-dedup image parts, natural
  sizing by dpi (2026-07-18)
- [x] Tables: grid, cell text/fills/anchors, merge, style flags (2026-07-18)
- [x] Bullets, numbered lists, hyperlinks (2026-07-18)
- [x] **Autofit with real font metrics** — shipped 2026-07-22 by the v0.4
  program below (`FontMetrics` + `TextMeasurer` + computed `a:normAutofit`)
- [ ] Group shapes, connectors, freeform

## Phase 3 — Parity completion

- [x] Charts: clustered/stacked bar, line, pie, area, doughnut, scatter via
  extracted chart templates, with titles, data labels, axis control and
  embedded Edit-Data xlsx workbooks written by our own zip engine
- [x] Speaker notes: notesMaster/notesSlide, `slide.setNotes` (2026-07-18)
- [x] Write-side DEFLATE (fixed-Huffman + LZ77, deterministic) — file-size
  parity (2026-07-19)
- [x] Linux CI (Swift 6.0/6.1 containers, oracle tools installed)
- [ ] More chart types: radar, bubble, stock, combo — **not shipped**
  (correcting the earlier ✅; nothing beyond the six kinds above exists)
- [ ] Core/extended/custom document properties API, media parts (video/audio)
- [ ] Performance pass on large decks (no benchmarks exist yet)

## Phase 4 — Beyond parity (the reason Rostrum exists)

Ranked by demand evidence from python-pptx's issue tracker:

1. ~~Deck merge / slide import~~ ✅ **Shipped 2026-07-19**: copy slides with
   images, charts, layouts and rels intact (`slides.importAll(from:)`).
2. ~~Theme & brand kit editing~~ ✅ **Shipped 2026-07-19**: `Theme` object,
   palette + fonts, `schemeClr` → RGB resolution through the clrMap chain.
3. ~~SmartArt~~ ✅ **Shipped 2026-07-18/19**: Basic Block List, process and
   cycle layouts; `slide.smartArtTexts` extraction. Next: hierarchy layout,
   multi-level data, PowerPoint-QA across the layout set (Lectern still
   ships SmartArt behind an opt-in toggle — production trust is the gap).
4. ~~Modern threaded comments~~ ✅ **Shipped 2026-07-18**; native sections
   and font embedding followed (2026-07-19).
5. **Animations & transitions** — the `p:timing` tree, entrance/exit/emphasis
   presets, slide transitions. (Existing decks' animations survive via
   pristine parts, but there is **no dedicated round-trip test** — the v0.1
   P3 bullet claiming one was wrong.)
6. **ChartEx** (`cx:`) — waterfall, sunburst, treemap, histogram, funnel.
7. **Reading chart data back out** and robust `replaceData` (python-pptx
   corrupts on structure mismatch).

## Phase 5 — Moonshots

- Rendering: slide → image/PDF without LibreOffice (SwiftUI/CoreGraphics
  renderer on Darwin; cross-platform raster backend later). The v0.4 metrics
  engine is the foundation: faithful text is most of a faithful slide.
- Streaming/partial loading for production-scale decks
- OMML math, connector routing to attachment sites, placeholders in groups

## Program: v0.1 release — hardening & design layer ✅ (2026-07-18 → 19)

Shipped as PRs #1–#5, adversarially reviewed, CI-green on macOS + Linux,
tagged `v0.1.0`. P0 foundations (color math, Grid DSL, TypeScale), P1 design-
authoring layer (slide builders, cards/chips, auto-contrast), P2 fidelity
(table styling, footers, sections, backgrounds), P3 robustness (round-trip
property tests, reader fuzzing, deeper `validate()`, DocC + cookbook), P4
headless slide → SVG.

**Corrections (2026-07-22):** the P3 bullet listed "bubble/radar/stock/combo
charts" and "verify animations/transitions survive round-trip" — neither
shipped; both are re-opened above (Phase 3 / Phase 4 item 5). P4's "using
the TTF metrics we already parse" was wrong: nothing parsed TTF metrics
until v0.4 M1 below; the SVG renderer's text is still approximate until M2.

## Program: v0.4 — Measure & trust (2026-07-22 →)

The theme: convert the library's two biggest asserted qualities into
*measured* ones. Text layout stops guessing (the #1 pain in Lectern, the
in-repo consumer: six overflow-workaround commits in one weekend, an entire
`DeckNormalizer` layer, prompt-level content caps). And the sacred lossless
round-trip stops being unproven against foreign files. python-pptx's
`fit_text` is notoriously broken — no pptx library guarantees text fits its
box; this program makes Rostrum the first.

- **M0 — Trust riders (this branch).** Truth pass on this file. Untrusted-
  input hardening: `Slides` subscript/iterator no longer abort the process on
  malformed decks; `Inflate` caps its attacker-declared allocation. The
  python-pptx oracle runs in CI on macOS + Linux (`PythonPptxOracleTests`).
  Real-deck corpus scaffold: PowerPoint-authored fixtures auto-enroll in
  byte-identity, determinism and no-trap gates (`RealDeckCorpusTests`).
- **M1 — FontMetrics engine (this branch).** Pure-Swift sfnt parser — no
  platform text stack, same posture as our zip/XML layers: `head`/`hhea`/
  `maxp`/`hmtx`/`cmap` (formats 4 + 12), `OS/2` typo metrics, `.ttc`
  collections; every read bounds-checked and throwing (fonts are untrusted
  input). `TextMeasurer`: greedy word wrap with mid-word fallback, block
  height. Computed `a:normAutofit`: PowerPoint's fontScale/lnSpcReduction
  ladder, applied via `textFrame.fitText(in:using:)` / `shape.fitText(using:)`.
  Deterministic synthetic-font tests plus a real-font oracle (DejaVu/Arial).
- **M2 — Retire the heuristics (core shipped 2026-07-22, this branch).**
  `FontLibrary` (explicit, deterministic registration; family names parsed
  from the sfnt `name` table); builders measure with real metrics when the
  style's fonts are registered and keep the calibrated character-count ladder
  as the byte-identical fallback; `SVGRenderer` renders measured word wrap
  and baselines for registered typefaces. Builder capacity is documented
  rather than silent (`SlideCapacity`), and `registerEmbeddedFonts()` feeds
  a deck's own embedded typefaces to the measurer.
- **M3 — Read-side object model (core shipped 2026-07-26, this branch).**
  Polymorphic shape enumeration: `p:pic`, `p:graphicFrame` (table/chart/
  diagram/unmodeled), `p:grpSp` and `p:cxnSp` are visible on opened decks as
  typed `Shape` subclasses, with image/table/chart/diagram/connector/group
  read-back and group child-space mapping. Reads are provably non-mutating
  (this pass fixed a getter that corrupted graphic frames). *Still open:*
  fill/line read-back, core/extended/custom document properties, multi-master
  `slideMasters`, placeholder resolution for non-`p:sp` placeholders.
- **M4 — Chart read-back + `replaceData` that never corrupts.** Requires M3.

Hardening backlog (schedule opportunistically): pristine round-trip for
`.rels` parts and `[Content_Types].xml` (today both are parsed and
deterministically re-serialized on save, so foreign byte layout normalizes —
the one documented exception to the byte-identity rule); Zip64 (today >4 GB
archives and >65k entries are `precondition` traps on the write path);
`PackURI` precondition on malformed rel targets; quadratic hot spots on very
large decks; `prune()`/orphan audit promised in ARCHITECTURE.md.

## Standing quality gates

- `swift test` green on macOS + Linux
- Corpus decks round-trip byte-identical on untouched content parts —
  including the real-deck fixtures in `Tests/RostrumTests/Fixtures/RealDecks/`
  (`.rels`/`[Content_Types].xml` are deterministically re-serialized; making
  them pristine too is on the hardening backlog)
- Every Rostrum-written deck opens in python-pptx without exception — now
  automated in CI (`PythonPptxOracleTests`) — and in PowerPoint without
  repair prompt
- Malformed input throws; it never traps the host process
- Zero SwiftPM dependencies, forever
