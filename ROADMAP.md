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
  `Tests/RostrumTests/Fixtures/RealDecks/` (scaffold 2026-07-22; populated
  2026-07-28 with decks from PowerPoint, Keynote and Google Slides — modern
  comments, embedded video, photographic media). One test case per deck; an
  empty corpus now fails rather than passing vacuously, and
  `ROSTRUM_REAL_DECKS` points the gate at decks that can't be published.
  **Still wanted: SmartArt (`ppt/diagrams/`) and a real `.potx`** — the two
  decks covering those were removed the same day for being built on a
  vendor's brand template rather than the owner's own work, which is a
  provenance rule the corpus README now states explicitly.

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
  plus a `p:timing` node per clip and read-back (`picture.mediaData`,
  `isMedia`, `isAudio`); 2026-07-27.

  **What that timing actually is, measured 2026-07-28** against
  `Fixtures/RealDecks/MovieAndComments.pptx` — a PowerPoint-authored deck with
  a real video, which is the first ground truth we have had. Rostrum writes
  `p:video > p:cMediaNode` under the `tmRoot`, which gives the clip transport
  controls. PowerPoint writes that *and* two sequences Rostrum does not:

  - a `p:seq nodeType="mainSeq"` whose innermost `p:cTn` is
    `presetID="1" presetClass="mediacall" nodeType="clickEffect"` carrying
    `<p:cmd type="call" cmd="playFrom(0.0)">` at the clip's `spid`, with the
    behaviour's `p:cTn@dur` set to the clip length in ms (`31600` there);
  - a `p:seq nodeType="interactiveSeq"` started by `evt="onClick"` on the
    clip, whose `clickEffect` issues `cmd="togglePause"`.

  It also does *not* put a `p:endCondLst` on the media node, where Rostrum
  writes `evt="onStopped"`. `MediaTimingGroundTruthTests` pins both sides of
  this so the gap cannot close by accident or be claimed shut.

  *Open:* emitting those two sequences (the shape is now known, but the result
  has to be opened in PowerPoint before it ships — a malformed `p:timing` is a
  repair prompt, which is the one outcome this project will not risk on an
  unverified guess); **auto-play on slide entry**, which in the observed tree
  is the `mainSeq` effect's start condition — click-to-play spells it
  `<p:cond delay="indefinite"/>`, and the auto-play spelling is exactly what a
  second sample, of a clip set to *Start: Automatically*, would settle; and
  PowerPoint's speaker icon for poster-less audio.
- [ ] Performance pass on large decks (no benchmarks exist yet)

## Phase 4 — Beyond parity (the reason Rostrum exists)

Ranked by demand evidence from python-pptx's issue tracker:

0. ~~Deck extraction / unpack~~ ✅ **Shipped 2026-08-09**: `deck.outline()`
   projects a deck onto a value model of its words and its cargo, and
   `DeckExport.write` unpacks it to a folder — one Markdown file of every
   slide's text, a folder per slide for its media, one CSV per chart
   (`pptx-tool extract`, and Lectern's File ▸ Export Deck to Folder…).
   python-pptx has no equivalent; getting content *out* of a deck is one of
   the most common reasons people reach for it in the first place.
   Next: an `--include-poster` for video thumbnails, and reading the
   embedded chart workbook for the values the chart XML cache omits.
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

## Program: v0.4 — Measure & trust ✅ (2026-07-22 → 2026-08-17, shipped as v0.4.0)

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
  `Presentation.init`. It first defaulted to `.unlimited` so decks that are
  merely large kept opening; the default is now `.default` — 4 GiB of
  declared uncompressed bytes, far past any real deck — so untrusted input is
  bounded out of the box, with `.unlimited` passed explicitly for archives
  the caller already trusts.

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
  distinct name once and the sum covers exactly that set. The same review closed
  a second route to the same end: `PackURI` identity is the raw string while
  `baseURI`/`filename` split on `/` discarding empties, so `ppt//slides/s.xml`
  and `ppt/slides/s.xml` were distinct parts sharing one `.rels` — decoded once
  per alias. Part names with empty segments are rejected (OPC M1.1), on the
  write path as well, so Rostrum cannot produce an archive it then refuses.

  A **third** adversarial round then falsified the repaired claim too, and it is
  worth recording why, because the same mistake was made twice in a row. Both
  times the claim was "the unit of accounting equals the unit of work"; both
  times the accounting unit was `uncompressedSize`. But decoding costs
  `compressedSize` — the payload slice is copied, the decoder copies it again,
  and the DEFLATE scan walks all of it — and nothing made two central-directory
  records describe *different* payload regions. So N records with N **distinct**
  names, immune to the dedup, could all point at one large payload while each
  declared it produces nothing (a run of empty stored blocks decodes to zero
  bytes with CRC 0). Unbounded work, charged nothing, under any budget.

  The answer is not another knob. A well-formed archive's payloads are disjoint
  and inside the file, so their compressed sizes sum to less than the file
  itself; `ZipReader.init` now requires that. It is a structural check on the
  archive rather than caller policy, so it holds under `.unlimited` too, and it
  bounds a full read's work at O(archive size) — which is what a budget on
  declared output was twice assumed to give and never did.

  A **fourth** round then confirmed the structural check is sound — including
  that it cannot refuse a legitimate deck, since a file is always
  `Σ compressedSize + Σ(76 + 2·nameLength) + 22` and extra fields, data
  descriptors and comments only widen that gap — but found the *guarantee*
  overstated again, in a quieter way. Precisely: the budget bounds bytes
  **produced**; the structural check bounds **work**, at one decode per
  resolvable name; neither covers a caller who fetches the same name twice; and
  neither bounds **peak memory**, which is where the gap is largest. DEFLATE
  expands at most 1032:1 against this decoder, and `OPCPackage.read` retains
  every decoded part, so an archive that passes every check can still occupy
  ~1032× its own size. Those numbers are now in `ZipReader.Limits`' documentation
  instead of the phrase "a small constant multiple of the budget", which said
  nothing at all under the default of `.unlimited`.

  The same round closed the trailing-slash alias the empty-segment rule missed
  (`ppt/x.xml/` derives the same `relsURI` as `ppt/x.xml`; the rule is now "any
  empty component" rather than a list of shapes), extended the write guard to
  the three name classes `read` disposes of by skipping rather than throwing,
  and rejected byte-distinct member names that decode to an equal Swift
  `String` — Swift compares by canonical equivalence, so NFC and NFD spellings
  of one name silently dropped a part and served another's bytes under it.

  Also from that round: ~~directory-placeholder entries are dropped on read and
  never re-emitted~~ ✅ 2026-07-27 — `OPCPackage` carries them verbatim, and a
  fifth round immediately found the twin: `.rels` entries that parse to zero
  children, or that no part claims, were read and never written back either.
  Both are carried now. Note what the corpus gate did NOT do here: it is
  written to catch exactly this (every `before` name must appear in `after`),
  but through 2026-07-27 `Fixtures/RealDecks/` held only a README, so it
  iterated zero decks and passed vacuously. It guarded nothing for five days
  while being cited as the thing that would catch precisely these bugs.

  ✅ 2026-07-28 — six decks landed and the suite was rebuilt so that cannot
  recur: one test case per deck, `corpusIsPopulated` fails outright on an
  empty corpus, and a packaging check anchored on the checked-in README tells
  "resources were never copied" apart from "the directory is empty" — the
  ambiguity that hid the vacuity, since the listing failed open to `[]`.
  It earned its keep on the first run: the `.potx` failed byte-identity
  because opening a template retyped its main part to a presentation, so a
  template could not survive a round trip at all. Fixed in the library, not
  the test — see `DocumentKind`.

  `PackURI` percent-decoding — **investigated, implemented, reverted, and left
  open deliberately.** (Not struck through: the underlying gap is still there.) Decoding was implemented, reviewed, and reverted the same day. A part
  name is `pchar` segments and the zip item name is the part name minus its
  leading slash, so a conformant package is internally consistent in *encoded*
  space: item name, `Override/@PartName` and `Target` all carry the same
  escapes. Decoding only the `Target` moves one end of the comparison into a
  namespace no other layer shares — a regression in exactly the case it was
  meant to fix — and decoding is many-to-one besides (`slide%31.xml` collapses
  onto `slide1.xml`; every invalid UTF-8 escape funnels to U+FFFD), which is
  the aliasing class `hasEmptySegment` exists to prevent. **Genuinely open:** a
  producer that writes the item name RAW but the `Target` ENCODED is internally
  inconsistent, and neither spelling alone resolves it. That wants a
  try-verbatim-then-decoded fallback at every `resolve` call site with the
  package in hand — an API change to design, not a one-line decode.
- Zip64 — **entry count done, sizes/offsets deliberately not.** Past 65535
  entries `ZipWriter` emits a zip64 EOCD record and locator with the classic
  count sentinel, and `ZipReader` follows the locator to read the real count;
  the structures appear only when needed, so every archive that fit before is
  byte-identical. Proved in CI both ways plus `/usr/bin/unzip -t`, and at the
  65535 boundary, where a literal 0xFFFF count must NOT be read as a sentinel
  (APPNOTE 4.4.1.4).

  The 64-bit **size and offset** fields are a different feature: they need the
  per-entry zip64 extra field, and nothing here can exercise them without
  writing four gigabytes. They stay *reported* — `ZipWriter.finalize()` throws
  and `ZipReader` returns `zipUnsupported` — because a half-implemented format
  claimed as done is the overstatement this codebase keeps having to walk back.
  The entry count is the ceiling a real `.pptx` can plausibly reach; the size
  fields are not.
- Quadratic hot spots on very large decks; `prune()`/orphan audit promised in
  ARCHITECTURE.md.

### Known gap: entry encoding is not preserved

The real-deck gate compares each entry's **decompressed** bytes. An untouched
part's *encoding* is not carried: Rostrum picks STORE or DEFLATE from the file
extension alone (`OPCPackage.storedExtensions`), so it re-emits six JPEGs in
`FromKeynote.pptx` and four in `FromGoogleSlides.pptx` STORED that their
authors had DEFLATEd, and it does not reproduce the data descriptors Google
Slides sets on all 86 of its entries. Those files are byte-different from what
their authors wrote.

Nothing is lost — identical payloads under identical names, which is what
Rostrum promises — but "open and save changes nothing" would be a stronger and
better promise. Carrying a pristine entry's original method and descriptor
through the writer is the fix; it needs `ZipReader` to surface per-entry
encoding and `OPCPackage.serialize` to honour it for parts that never went
dirty. Found 2026-07-28 by an adversarial review of the corpus gate, which
had been claiming full byte identity in its own doc comment.

## Deferred — real, deliberately not scheduled

Findings from the 2026-08-11 audits that were confirmed against the code and
then *not* acted on, recorded here so they are not rediscovered from scratch.
Each is a judgement about leverage, not a doubt about the finding.

**Rostrum**

- **Effective-frame inheritance matches layout → master by reduced type**
  (`Slide.swift`) — a real asymmetry, but no observed deck reaches it and the
  fix needs the full placeholder-matching table.
- **`OPCPackage` multi-pass serialisation** — measured in milliseconds against
  a whole-deck save; below the noise floor.
- **`RostrumError` carries prose, not structured cases** — a genuine API
  ergonomics gap, low leverage while the consumer set is this small.
- **Text measurement ignores kerning, ligatures and shaping**
  (`FontMetrics.swift`) — documented behaviour; fixing it means a shaping
  engine, which is out of scope for a zero-dependency library.
- **No snapshot or golden-file tests for `SVGRenderer`** —
  `SVGRendererTests.swift` asserts structure, so a *visual* regression in the
  preview path would pass silently.
- `DeckRenderer`, `KeychainStore` and `SlideRasterizer` have **no tests at
  all** — distinct from tests that existed but never ran, which is closed.
- **`Examples/` and `Tools/` have never been audited** — four executable
  targets plus `extract-schema.py` sit outside every surveyed set so far.

**Lectern**

- Only one image failure is reported when several fail — the collapse is in a
  warning path the user rarely sees.
- No cancel affordance *during* a long generation — needs a cancellation
  token threaded through `DeckGenerator` and the provider.
- **The decks already written remain headless.** The title-placeholder fix
  applies to newly written decks only; repairing the existing library is a
  migration, not a lift-up item.
- iOS keeps live `WKWebView` slide previews while macOS rasterizes —
  `takeSnapshot` needs a window, and the iOS path is not currently slow.
- **`DeckRenderer.swift` is 923 lines** — the single place where IR, layout,
  furniture, fonts, charts and previews all meet. Not a defect, but previews
  and font resolution are both self-contained and the obvious next split.

## Standing quality gates

- `swift test` green on Linux on every push; on macOS in the pull-request
  gate (hosted macOS bills ~10× Linux, so Apple platforms are verified
  per-PR rather than per-push)
- Corpus decks round-trip byte-identical on **every zip entry** — including
  the real-deck fixtures in `Tests/RostrumTests/Fixtures/RealDecks/`. M5
  closed the last exception: `.rels` and `[Content_Types].xml` keep their
  parsed bytes until something in them actually changes.
- Every Rostrum-written deck opens in python-pptx without exception — now
  automated in CI (`PythonPptxOracleTests`) — and in PowerPoint without
  repair prompt
- Malformed input throws; it never traps the host process
- Zero SwiftPM dependencies, forever
