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
- [x] Layouts/masters collections — `layouts`/`layout(type:)`, placeholder-
  inheriting frames, and (2026-07-26) `slideMasters` with per-master
  `layouts`/`theme`, `allLayouts`, and `layout.master`/`slide.layout`/
  `slide.master`
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
- [x] Radar (`.radar`, `.radarFilled`) and bubble (`addBubbleChart`) —
  shipped 2026-07-27, closing two of the four types the earlier ✅ overclaimed
- [x] **Combo charts** — `addComboChart(_:frame:options:)` writes several plot
  groups into one plot area, with an optional secondary value axis; series are
  numbered globally so the workbook columns, the read side and `replaceData`
  all agree (2026-07-27)
- [ ] **Stock charts** — designed but deliberately not shipped. `CT_StockChart`
  itself is straightforward (`ser{3,4}`, `c:hiLowLines`, `c:upDownBars` for the
  open-high-low-close variant), and Rostrum already refuses series edits that
  would break the 3–4 bound. The blocker is the category axis: every
  Office-generated stock part we could find pairs `c:stockChart` with a
  `c:dateAx` over numeric serial dates, while `ChartData.categories` is
  `[String]` and so forces `c:catAx`. That is schema-legal and no source says
  PowerPoint rejects it, but nobody has a sample proving it doesn't — and this
  project's bar is "PowerPoint opens it without a repair prompt", which cannot
  be checked from CI (python-pptx can't help: its `PlotFactory` raises on
  `c:stockChart`). Shipping it would be a guess. **To unblock:** author one
  stock deck, open it in PowerPoint; if it opens clean, implement as designed.
  If it repairs, the fix is a date-typed category model plus a workbook
  variant — a separate feature, not a patch. Do *not* write string categories
  under a `c:dateAx`; that is exactly the corruption `replaceData` already
  refuses as `.categoryAxisIsNotText`.
- [x] Core/extended/custom document properties API (`deck.documentProperties`,
  2026-07-26)
- [x] Media parts — `shapes.addMedia(_:format:frame:poster:)` embeds video and
  audio with both the legacy link and the modern `p14:media` relationship,
  plus a `p:timing` node per clip (play controls, start on click) and
  read-back (`picture.mediaData`, `isMedia`, `isAudio`); 2026-07-27.
  *Open:* auto-play on slide entry, and PowerPoint's speaker icon for
  poster-less audio.
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
7. ~~Reading chart data back out and robust `replaceData`~~ ✅ **Shipped
   2026-07-26** (v0.4 M4): `deck.charts`, and a `replaceData` that validates
   the replacement against the chart's own structure and refuses rather than
   corrupting — the failure mode python-pptx is known for. Completed
   2026-07-27 with XY (scatter/bubble) read-back via `chart.xySeries` and
   `addSeries`/`removeSeries`, which renumber indices, formulas and legend
   entries and rewrite the embedded workbook — or refuse before writing.

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
  (this pass fixed a getter that corrupted graphic frames). Placeholder
  binding and `effectiveFrame` now cover every shape kind, and document
  properties shipped alongside, then fill/line/background/cell appearance
  read-back and a multi-master `slideMasters` collection with
  `layout.master` / `slide.layout` / `slide.master`. **M3 complete.**
- **M4 — Chart read-back + `replaceData` that never corrupts (shipped
  2026-07-26).** `deck.charts`/`chartFrame.chart` expose kind, title,
  categories and series from the chart XML caches; `replaceData(_:)` edits
  values, series names and categories in place (formulas, colors, axes and
  unmodeled elements untouched) and rewrites the embedded workbook, refusing
  any structural change before writing a byte. Completed 2026-07-27:
  `chart.xySeries` reads scatter and bubble points (x, y, size, gaps, and
  text-encoded x values reported as labels rather than silent nils), and
  `addSeries`/`removeSeries` edit the series list — cloning a sibling's
  per-kind children but not its identity, renumbering `c:idx`/`c:order`,
  workbook formulas and `c:legendEntry` indices, and rewriting the embedded
  workbook. Structural edits refuse (before writing) what they cannot keep
  coherent: combo and XY charts, literal caches, foreign workbook layouts, a
  second series on a pie, and removing a chart's last series. **M4 complete.**

- **M5 — No exceptions to the round-trip rule (shipped 2026-07-27).**
  `.rels` parts and `[Content_Types].xml` keep their parsed bytes and rebuild
  only when a relationship or content type actually changes, so the
  byte-identity gate now covers every zip entry. This was the last documented
  exception to the sacred invariant.

Hardening backlog (schedule opportunistically):

- ~~`PackURI` precondition on a file-supplied part name~~ ✅ 2026-07-27, along
  with a wider audit of the same class: file-supplied colors, chart point
  indices, shape ids, group child-space coordinates and SVG font sizes all
  reached a `precondition` or an overflow on the read path. A trap is a crash
  the caller cannot catch, and a `.pptx` is untrusted input.
- A second adversarial pass over those fixes returned **19 confirmed findings
  against 4 refutations** — almost all of one shape: a defect fixed at one
  site and left at its twins (`nextSlideID` beside `nextShapeID`, a second
  inset parser beside the bounded one). Fixed 2026-07-27 by moving the bound
  to the parse boundary — `XML.Element.boundedInt(_:in:)` and `OOXMLBounds` —
  so a missed call site is no longer possible. `deck.addSection` on a foreign
  deck with duplicate section starts, and the 0xFFFF zip entry-name field
  (now reported by `OPCPackage.serialize` rather than trapping in
  `ZipWriter.addFile`), went with it.
- `Table.cell(_:_:)` now **throws** (2026-07-27) rather than preconditioning on
  the index, so the natural reading idiom (`for c in 0..<table.columnCount`)
  reports instead of aborting on a **ragged** foreign table — one whose
  `a:tblGrid` declares more columns than a row has `a:tc`. Same rule as
  `Slides.subscript`. `merge` throws with it; `setContents` and the bulk
  styling helpers stay tolerant by contract and skip cells a row does not have.
- ~~`Inflate` bounds each entry by that entry's own declared size, so a zip
  bomb amplifies across many entries~~ ✅ 2026-07-27. Resource exhaustion
  rather than a trap, so the fix had to be an API decision, not a patch: a
  caller-supplied `ZipReader.Limits` threaded through `OPCPackage.read` and
  `Presentation.init`, defaulting to `.unlimited` so decks that are merely
  large keep opening.

  The budget is enforced **up front, from the central directory**, not
  accumulated as entries decode. Since each entry is bounded by its own declared
  size, the sum over the entries a name *resolves to* is the ceiling on what a
  full read can produce — and the archive states all of them before a byte is
  inflated. So an over-budget archive costs no decompression at all, and the
  verdict cannot depend on which entries a caller reads or in what order.

  "Resolves to" is load-bearing, and the first cut got it wrong: an adversarial
  review found that the sum counted central-directory *records* while the work
  is driven by entry *names*, which are last-wins. 65535 records sharing one
  name — shadows need no local header and no payload, so they cost a 46-byte
  record each and declare zero — bought 65534 full inflations of the surviving
  entry inside a budget that had charged for one. `entryNames` now yields each
  distinct name once and the sum covers exactly that set, so the unit of
  accounting and the unit of work are the same. The same review closed a second
  route to the same end: `PackURI` identity is the raw string while
  `baseURI`/`filename` split on `/` discarding empties, so `ppt//slides/s.xml`
  and `ppt/slides/s.xml` were distinct parts sharing one `.rels` — decoded once
  per alias. Part names with empty segments are rejected (OPC M1.1).

  It bounds *decoded output*, not peak memory (a read holds the archive bytes,
  the compressed slice, and briefly two copies of the current entry), and it
  bounds *declared* size, which is the conservative direction: the alternative
  is doing the work to find out.
- Zip64 **write** support. Archives over 4 GB, over 65535 entries, or with a
  central directory over 4 GB are now *reported* — `ZipWriter.finalize()`
  throws `RostrumError.packageInvalid` and `OPCPackage.serialize` propagates it
  — so this is a missing feature rather than a crash risk. Reading such an
  archive is likewise unimplemented.
- Quadratic hot spots on very large decks; `prune()`/orphan audit promised in
  ARCHITECTURE.md.

## Standing quality gates

- `swift test` green on macOS + Linux
- Corpus decks round-trip byte-identical on **every zip entry** — including
  the real-deck fixtures in `Tests/RostrumTests/Fixtures/RealDecks/`. M5
  closed the last exception: `.rels` and `[Content_Types].xml` keep their
  parsed bytes until something in them actually changes.
- Every Rostrum-written deck opens in python-pptx without exception — now
  automated in CI (`PythonPptxOracleTests`) — and in PowerPoint without
  repair prompt
- Malformed input throws; it never traps the host process
- Zero SwiftPM dependencies, forever
