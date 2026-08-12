# Changelog

Rostrum is **pre-1.0**: minor versions may change API. Format follows
[Keep a Changelog](https://keepachangelog.com/); versions follow
[SemVer](https://semver.org/) with the 0.x caveat above.

## [Unreleased]

### Added

- **Deck extraction** — `Presentation.outline()` projects an opened deck onto
  a `Sendable` value model: per slide, the title, subtitle, body paragraphs
  with their outline level, table cells, SmartArt labels, speaker notes, an
  inventory of the images/movies/sounds it carries, and every chart flattened
  to the grid a spreadsheet would show. Groups are traversed, so text and
  pictures inside a grouped shape are no longer invisible. A slide that cannot
  be read becomes a line in `warnings` instead of failing the whole deck.
- **`DeckExport.write(_:to:)`** — unpacks a deck into a folder: one Markdown
  file of every slide's words, plus a folder per slide (only when it has
  something to put in one) holding that slide's media and one CSV per chart.
  Deterministic — neither the clock nor the destination path reaches the
  output — and additive: it overwrites only the files it wrote and never
  deletes anything. A one-way projection; it only ever reads the deck.
- `Paragraph.plainText` — the paragraph's text as it reads on the slide.
  `runs` returns only `a:r`, so a manual line break (`a:br`) welded two runs
  into one word and a field (`a:fld` — slide number, date) vanished; this
  walks the children in document order.
- `pptx-tool extract <file.pptx> <directory>` — the extraction from the
  command line, exiting non-zero when a deck only partly came out.
- Lectern opens on a **fork — Create or Inspect** — rather than straight into
  the compose form, which had asserted that writing a deck was the only thing
  the app did and left opening one with no door at all.
  - **Inspect** (⌘I, or the button) picks a `.pptx`, opens and lints and reads
    and draws it entirely off the main actor, and shows what it turned out to
    be: counts, geometry, sections, findings, a contact sheet of every slide,
    and every word in it. **Export Everything…** writes the full teardown into
    a chosen folder.
  - Nothing slow is silent: opening, validating, extracting and rendering each
    announce themselves, slide rendering drives a determinate `n of N` bar, and
    the export raises a progress overlay while it copies media. Both are
    cancellable.
  - `DeckInspector` and `SlideDigest` in LecternCore hold the whole inspection,
    so it is tested headlessly on Linux; they expose `String`/`Int` rather than
    Rostrum's `DeckOutline` because the app target links LecternCore and
    nothing below it.
  - Because the pickers are SwiftUI's rather than AppKit panels, Inspect and
    Export work on **iOS/iPadOS** too.
- **FontMetrics engine** — pure-Swift TrueType/OpenType metrics parsing
  (`head`/`hhea`/`maxp`/`hmtx`/`cmap` formats 4 + 12, `OS/2` typographic
  metrics, `.ttc` collections) with no platform text stack. `FontMetrics`
  measures string widths and line heights; `TextMeasurer` wraps text and
  computes block heights.
- **Computed autofit** — `textFrame.fitText(in:using:)` and
  `shape.fitText(using:)` measure the frame's text with real font metrics
  and write `a:normAutofit` `fontScale`/`lnSpcReduction`, stepping the
  ladder PowerPoint uses. Text that fits is now a guarantee, not a
  character-count guess.
- Real-deck corpus gate: foreign-authored `.pptx` fixtures dropped into
  `Tests/RostrumTests/Fixtures/RealDecks/` automatically enroll in
  byte-identity (every zip entry, no exemptions), determinism, and no-trap
  tests (`RealDeckCorpusTests`). Now populated with decks from PowerPoint,
  Keynote and Google Slides, so the lossless-round-trip rule is tested
  against XML Rostrum did not write. Byte identity is of each entry's
  *decompressed* payload; entry encoding (compression method, data
  descriptors, order) is a known gap tracked in ROADMAP.
  `ROSTRUM_REAL_DECKS` points the gate at decks that can't be published.
- `Presentation.documentKind` (`.presentation` / `.template` / `.slideShow`)
  — reads and sets what PowerPoint uses to tell a `.pptx` from a `.potx` from
  a `.ppsx`, which is the main part's content type rather than the file
  extension.

### Changed

- **Opening a `.potx` or `.ppsx` no longer converts it.** A template opens as
  a template and saves as one, byte-identically; previously it was retyped to
  a presentation on open, so a template could not survive a round trip. To
  build an ordinary deck from a template, set
  `deck.documentKind = .presentation`. Found by the real-deck corpus gate.
- The python-pptx oracle runs in CI on Linux on every push, and on macOS in
  the pull-request gate (`PythonPptxOracleTests`): representative
  Rostrum-written decks must open in python-pptx before a merge.
- `RostrumError.fontCorrupt` for unparseable font files.
- **FontLibrary** — `deck.fonts.register(_:aliases:)` registers fonts under
  their `name`-table family names (parsed from the sfnt, IDs 1/16) for text
  measurement. Explicit registration only: platform font lookup would break
  cross-machine determinism.
- **Measured slide builders** — with the style's fonts registered, the
  builders that fitted text by character count (title, section, closing,
  process, quote, metrics, header wrap detection) now measure with real
  advance widths, never exceeding the configured role size. With no fonts
  registered, output is byte-identical to the previous character-count
  behavior (the ladder values are pinned by test).
- **Measured SVG rendering** — single-run paragraphs whose typeface is
  registered render with real word wrap and baseline placement in
  `renderSVG`; the rest wrap on a character-width estimate.

### Changed

- **`renderSVG` wraps long text instead of truncating it.** Paragraphs
  without registered metrics used to emit one line and drop the remainder
  behind an ellipsis, so a preview silently rewrote the deck's own words
  ("Why Native Rendering Wins" rendered as "Why Native Render…"). They now
  wrap on the same estimate, bounded at 64 lines per paragraph — the
  renderer reads files it did not write, and a one-EMU-wide shape holding a
  megabyte of text must not become a line per character. The ellipsis
  appears only when that bound actually discarded text. A paragraph that
  already fit on one line emits byte-identical markup; that is per
  *paragraph*, not per shape, since `cursorY` accumulates and a wrap moves
  every paragraph after it in the same body.
- `deck.registerEmbeddedFonts()` unwraps the deck's own EOT-Lite font parts
  back to sfnt and registers them for measurement, so a deck that carries
  its typefaces can measure its own text. Explicit call — nothing registers
  implicitly, and registration never dirties a part.
- `SlideCapacity` documents the item limits of the capped builders
  (`process` 5, `smartArt` 6, `bands` 6, `pyramid` 5, `metrics` 4), which
  previously truncated silently with no way to know the cap.

- **Video and audio** — `shapes.addMedia(_:format:frame:poster:)` embeds a
  clip in `/ppt/media/` with the two relationships PowerPoint wants pointing
  at the same part (the legacy `video`/`audio` link and the modern `media`
  relationship referenced from `p14:media`), a poster frame (with none given,
  a transparent pixel over a dark solid fill — `p:pic` requires a `blipFill`,
  and a bare transparent pixel would be an invisible, unclickable shape),
  and the content type as an extension Default the way PowerPoint writes it.
  Read-back via `picture.isMedia` / `isAudio` / `mediaData`. A `p:timing`
  node is written per clip so PowerPoint actually shows play controls and
  starts it on click — without one the clip renders as a still picture with
  no controls at all. Auto-play on slide entry is a different start
  condition and is not written. Identical clips are stored once, and media
  is stored rather than re-DEFLATEd.
- **Radar and bubble charts.** `ChartKind.radar` / `.radarFilled` plot a
  category axis wrapped into a circle; `addBubbleChart(_:frame:)` takes
  `BubbleChartData`, whose points carry x, y **and** size, with a three-column
  embedded workbook to match. These are two of the four types the v0.1
  changelog wrongly claimed had shipped; combo authoring followed later in
  this same release (below), leaving stock the only one still open.
- **Chart read-back and a `replaceData` that refuses to corrupt (v0.4 M4).**
  `deck.charts` (and `chartFrame.chart`) read a chart's kind, title,
  categories and series straight from the chart XML's caches — gaps keep
  their index — so you can open a deck and ask what it plots.
  `chart.replaceData(_:)` swaps the numbers and labels **in place**: `c:f`
  formulas, series colors, axes, data labels and every element Rostrum does
  not model survive untouched, and the embedded Edit-Data workbook is
  rewritten to match. A replacement that would change the chart's structure
  (different series or category count) is refused *before anything is
  written* — `chart.replacementProblem(for:)` reports it without throwing.
  python-pptx's `replace_data` rewrites from a fresh model and is known to
  produce decks PowerPoint offers to repair on structure mismatch; this is
  the deliberate opposite. Refusals cover more than counts: a series whose
  values would be resized, a cache the write cannot target, a numeric or
  date category axis (writing text into it corrupts the axis), a multi-level
  category axis, and — the subtle one — a chart whose surviving `c:f`
  formulas do not describe the layout Rostrum's embedded workbook uses, where
  refreshing the workbook would leave Edit Data pointing at cells that no
  longer exist. Combo charts (several plot groups in one plot area) are read
  and updated as a whole, and charts nested inside groups are found.
- **Combo charts** — `shapes.addComboChart(_:frame:options:)` takes a
  `ComboChartData` of plot groups sharing one category axis, each group with its
  own kind, colors and data labels, and each drawn against the primary or a
  secondary value axis. A secondary group gets a right-hand value axis *and* the
  deleted category axis its `c:axId` pair must name — a `c:axId` pointing at an
  axis the plot area does not contain is a repair trigger no schema check
  catches. Series are numbered globally across groups, so `c:idx`/`c:order`, the
  embedded workbook's columns, the read side and `replaceData` all describe the
  same order. Refused before anything is written, via `ChartAuthoringProblem`:
  a group kind with no shared category axis (pie, doughnut, radar), no primary
  group, or two bar groups on one axis pair — PowerPoint merges those into a
  single cluster, so it would draw something other than what was asked for.
- **Data-label positions are checked per chart type.** `c:dLblPos` carries
  per-type restrictions and an illegal one makes PowerPoint offer to repair the
  file. The one-line doughnut guard became a table: pie and of-pie accept four
  tokens, doughnut/area/radar accept none, and a stacked bar has no "outside
  end". Types where no corroborated table exists (line, scatter, bubble) are
  left unrestricted rather than having a caller's intent dropped on a guess.
  *Behavior change:* a position previously emitted on an area, radar or stacked
  bar chart is now dropped — those were latent repair prompts.
- **XY chart read-back** — `chart.xySeries` reads scatter and bubble points
  (`chart.isXY` says when to reach for it): x, y and — on bubble — size, with
  cache gaps preserved as nil and each series read independently, so series of
  different lengths survive. A `c:xVal` that is text-encoded rather than
  numeric reports its labels in `xLabels` instead of silently reading every x
  as nil.
- **Adding and removing chart series** — `chart.addSeries(name:values:)` and
  `chart.removeSeries(at:)` change a chart's series list in place. A new
  series is cloned from the last existing one, so it keeps the per-kind
  children its siblings have (`c:marker`, `c:smooth`, series-level `c:dLbls`
  settings) but not their identity: `c:spPr` — including the nested one inside
  `c:marker` and `c:dLbls`, where PowerPoint stores a line or radar series'
  marker color — `c:dPt` and per-point `c:dLbl` overrides, `c:trendline` and
  `c:errBars` (per-series analysis, not series structure), and the `c:extLst`
  carrying a series id that must stay unique. PowerPoint colors the new series
  from the theme, as it does when you add one by hand. A template with no
  `c:tx` (a chart built over a headerless range) gets one synthesized, so the
  name is never silently dropped. Removal renumbers every survivor's
  `c:idx`/`c:order` and workbook formulas, and on the chart types whose legend
  lists series it shifts `c:legendEntry` indices so formatting cannot end up
  attached to the wrong series — pie-family legends enumerate categories
  instead, and are left alone. Both operations rewrite the embedded workbook.
  The same refuse-before-writing stance as `replaceData` applies, reported by
  `addSeriesProblem(name:values:)` / `removeSeriesProblem(at:)`: combo charts,
  XY charts, charts with no embedded workbook or with literal (`c:numLit`)
  data, foreign workbook layouts, a plot hiding a filtered-out series in its
  `c:extLst` (which still owns an index and a workbook column), a pie chart
  asked for a second series it would never draw (a doughnut, which draws one
  ring per series, is allowed), a stock chart pushed outside the 3–4 series
  its schema pins it to, a value count that does not match the categories, and
  removing a chart's last series.
- **Appearance read-back** — `shape.fill`, `shape.line`, `shape.hasShadow`,
  `slide.background` and `cell.fill` report what a shape actually carries
  (`ReadFill`/`ReadLine`, covering solid + alpha, theme colors, gradients,
  picture fills, patterns and explicit `noFill`). Fills and lines were
  write-only, so "open a deck and restyle only the untouched shapes" was
  impossible. A shape that inherits its appearance reads as `nil` rather
  than a guess, and every accessor is a pure read.
- **Multi-master decks** — `deck.slideMasters` exposes every master with its
  own `layouts` and `theme`, `deck.allLayouts` spans all of them, and
  `layout.master` / `slide.layout` / `slide.master` walk the chain. Until now
  only the first master's layouts were reachable, even though
  `slides.importAll(from:)` could already bring multi-master decks in.
- **Document properties** — `deck.documentProperties` reads and writes the
  OPC core set (title, author, subject, keywords, comments, category,
  contentStatus, lastModifiedBy, revision, created, modified), the Office
  extended set (application, company, manager), and user-defined custom
  properties (`docProps/custom.xml`, typed string/int/double/bool/date,
  created on first write with its content type and relationship wired up).
  Timestamps are never stamped from the wall clock — you pass the `Date` —
  so building the same deck twice still yields identical bytes.
- **Read-side shape model (v0.4 M3).** `slide.shapes` now enumerates every
  child of the shape tree — pictures, tables, charts, SmartArt, groups and
  connectors, not just `p:sp` — so opening a deck someone else authored
  finally shows you what is on the slide. Each arrives as the most specific
  `Shape` subclass (`Picture`, `TableFrame`, `ChartFrame`, `DiagramFrame`,
  `GroupShape`, `Connector`); narrow with `as?`, or filter on the cheap
  `shape.kind` (`ShapeKind`, whose catch-all cases keep it stable as Rostrum
  models more). Shape types Rostrum does not model still appear, so nothing
  is invisible. New read-back: `picture.imageData`/`imageFormat`,
  `tableFrame.table` (the full `Table` API over a parsed `a:tbl`),
  `chartFrame.chartPart`, `diagramFrame.dataPart`, `connector.startConnection`/
  `endConnection`, `group.shapes` with `convertToParentSpace(_:)` for child
  coordinates, plus `shape.shapeID` and `shape.explicitFrame`.
  `shapes.autoShapes` keeps the old `p:sp`-only view.

### Changed

- **Read budgets are on by default.** `Presentation(data:)`,
  `OPCPackage.read` and `ZipReader` now default to `ZipReader.Limits.default`
  — 4 GiB of declared uncompressed bytes, far past any real deck — instead of
  `.unlimited`; pass `.unlimited` explicitly for archives you already trust.
  Bare `Inflate.inflate(_:)` with no declared size caps its output at 1 GiB.
  Untrusted input is bounded out of the box rather than by opt-in.
- **`Sections` throws where it used to trap.** `setSections` reports an
  empty, non-zero-start or non-increasing boundary list as a thrown error —
  section boundaries routinely arrive from dynamic data, and an abort the
  caller cannot catch turned a resortable input into a dead process. The
  section subscript is throwing (`try deck.sections[0]`) with the same
  contract as `Slides`, and `Theme.accent(7)` now answers its optional
  signature honestly with `nil` instead of a precondition failure.
- **`EMU` no longer traps on non-finite math.** `Int(Double)` aborts on
  NaN/infinity, and `width / 0.0` is ordinary layout code gone slightly
  wrong; the factories and scalar operators now clamp — NaN to zero,
  overflow to the same `OOXMLBounds.coordinate` ceiling the read side uses.
- **Charts refuse non-finite numbers at every write boundary.** A `nan` or
  `inf` serialized into `c:v` is an invalid `xsd:double` — the repair prompt
  this library exists to never cause. `addChart` and friends, `replaceData`
  and `addSeries` throw before anything is written; a refused edit leaves
  the deck byte-identical.
- **Document type declarations are rejected on parse.** An internal DTD
  subset is the entity-expansion vector `shouldResolveExternalEntities =
  false` does not cover, and libxml2's own ceilings differ across platforms.
  No OOXML part carries a DTD.
- A lossy open is now recorded: carried zip entries that cannot be decoded
  (corrupt directory placeholders, orphan `.rels` streams) are still dropped
  rather than failing the file, but the drop lands in
  `Presentation.readWarnings` instead of happening silently.
- Parse and inflate hot paths shed their quadratic corners: multi-chunk XML
  text runs coalesce through a buffer instead of repeated concatenation,
  DEFLATE match copies go through a raw buffer (one memcpy when
  non-overlapping), and `TextMeasurer.wrap` keeps a running advance sum
  instead of re-measuring the whole line per word — same results, measured
  by the same tests.
- `Slides` subscript is now throwing (`try deck.slides[0]`): a malformed
  deck — a `sldId` whose relationship or part is missing — used to abort
  the host process via `preconditionFailure`; opening untrusted files must
  never do that. `for`-`in` iteration now skips unresolvable entries
  instead of trapping.
- `Inflate` caps its up-front output reservation (1 MiB) instead of
  trusting the archive's declared size: a few-hundred-byte crafted zip can
  no longer force a multi-gigabyte allocation.
- ROADMAP.md corrected against the code (bubble/radar/stock/combo charts
  and the animations round-trip test had been marked shipped but were not;
  the SVG renderer's claimed TTF metrics did not exist until now) and
  extended with the v0.4 "Measure & trust" program.

### Fixed

- **An edited part no longer loses its XML comments and processing
  instructions.** The promise is that opening and saving never drops XML
  Rostrum does not model, and a comment is the plainest case of that XML —
  yet the parser dropped both constructs on the floor, so the first edit to a
  part silently deleted every comment in it. `XML.Node` gained `.comment` and
  `.processingInstruction` cases, which parse and serialize in their original
  position (before, among and after element children, and around text without
  disturbing the run either side). `XML.Document` — returned by the new
  `XML.parseDocument(_:)`, which parts now use — carries what sits outside the
  root element, so a leading `<?mso-application?>` or a producer's banner
  survives a save too.

- **Reading a hostile deck no longer aborts the host process.** A Swift
  `precondition` or an integer overflow is a crash a caller cannot catch, and a
  `.pptx` arrives from users, email and the web.

  The structural fix is `XML.Element.boundedInt(_:in:)` plus `OOXMLBounds`,
  applied where file bytes become numbers rather than at each arithmetic site —
  `ShapeTransform`'s coordinate parser covers `frame`, `childSpace`,
  `effectiveFrame`, group mapping and the SVG renderer from one place. Ids are
  bounded to the ranges the format defines (`ST_SlideId`,
  `ST_DrawingElementId`), so the `max + 1` allocators in `nextShapeID`,
  `nextSlideID`, `nextSldId`, `allocBigId`, media part numbering and media
  timing nodes can no longer overflow; an id outside the range is ignored
  rather than clamped, so one hostile value cannot pin an allocator at its
  ceiling and refuse every subsequent shape. Where a namespace is genuinely
  exhausted, the call throws.

  `SVGRenderer` is bounded throughout — it does Int arithmetic on every
  coordinate it reads (`x + inset`, `cx += cw`, `x + w / 2`) — and its colours
  are validated rather than interpolated raw, which also closes a markup
  injection through `a:srgbClr@val`. `Tables.syncFrameExtent` and
  `TextMeasurer.fitText` no longer sum or subtract unbounded file values.

  Also fixed: an `<Override>` `PartName` without a leading slash (`PackURI`
  gains `init?(parsing:)`); an `a:srgbClr@val` that is not six hex digits —
  three-digit shorthand, eight-digit ARGB and bare names like `red` all appear
  in third-party files — reached through `shape.fill`, `shape.line`,
  `slide.background`, `cell.fill`, `run.color` and `theme.color(_:)` (`Color`
  gains `init?(validating:)`); a `c:pt@idx` of `Int.max`, whose cache sizing
  computed `idx + 1`; and a chart with more than 255 `c:ser`, which tripped
  `ChartData`'s programmer-facing bound.

  **API change:** `Table.cell(_:_:)` and `Table.merge(row:column:rowSpan:columnSpan:)`
  now throw. `columnCount` reports what `a:tblGrid` declares, and a table
  written elsewhere can have a row with fewer `a:tc`, so the natural reading
  idiom used to abort the host — the same rule `Slides.subscript` follows.
  `setContents` and the bulk styling helpers (`header`, `styleBanded`,
  `cellPadding`) stay non-throwing and simply skip a cell a row does not have.

  One trap is recorded as open in ROADMAP.md rather than half-fixed:
  `Inflate`'s per-entry cap is resource amplification rather than a crash, and
  the fix is a caller-supplied budget worth designing.

  *How these were found, since it bears on how much to trust the list:* an
  adversarial audit sweep, then a second adversarial pass over the fixes
  themselves. The second pass returned 19 confirmed findings against 4
  refutations, almost all of one shape — a defect fixed at one site and left
  at its twins. That is why the bound now lives at the parse boundary instead
  of at the call sites, and why the fuzz tests corrupt every colour-bearing
  element rather than one.
- **`ChartKind` is `CaseIterable`**, and the tests that walk every kind now
  use `allCases` — a newly added kind can no longer silently skip the
  schema-order and read-back gates.
- **The round-trip rule has no exceptions any more.** `.rels` parts and
  `[Content_Types].xml` were parsed into models and rebuilt on every save, so
  a deck authored elsewhere had those streams normalized — different
  attribute order, indentation and (for content types) element order — even
  when nothing changed. Both now keep their original bytes and rebuild only
  when a relationship or content type actually changes, so opening and saving
  a foreign deck is byte-identical across **every** zip entry. The real-deck
  corpus gate no longer exempts them. `Shape.frame` and
  `rotation` reached for `p:spPr` through a get-or-create accessor — in a
  *getter* — so merely reading the frame of a chart, table or SmartArt shape
  appended a schema-invalid `<p:spPr/>` to its `p:graphicFrame`, which
  PowerPoint offers to repair. Transforms now dispatch per element kind
  (`p:spPr/a:xfrm` for shapes, pictures and connectors; `p:xfrm` for graphic
  frames; `p:grpSpPr/a:xfrm` for groups) through a read-only path, and
  `setFill` throws rather than corrupting a frame that has no `p:spPr`
  (`setLine`/`enableSoftShadow` are no-ops there). Slide rendering and shape
  enumeration likewise no longer inject `p:cSld`/`p:spTree` into a part they
  only read, and reading a table cell no longer creates an `a:txBody` in it
  (new `TableCell.existingTextFrame` is the pure-read accessor).
- **Placeholder and geometry resolution cover every shape kind.**
  `slide.effectiveFrame(of:)` resolved geometry through a `p:spPr`-only path,
  so it reported "no geometry" for charts, tables, SmartArt and groups — the
  exact kinds now enumerated — while `shape.explicitFrame` returned the real
  rectangle for the same shape. Placeholder binding (`shape.placeholder`,
  `slide.placeholders`, `slide.title`) read `p:ph` only under `p:nvSpPr`, so a
  picture or table sitting in a content placeholder was not recognized as one.
  Both now use the same per-kind dispatch as the rest of M3.
- `GroupShape.convertToParentSpace(_:)` applies the group's `flipH`/`flipV`
  (documented as not composing `@rot`, which a `Rect` cannot express).

### Lectern (the sample app)

- **Cancel now stops the pipeline, not just the screen.** A cancel during
  the QA pass was swallowed by a `try?`, so the run went on to generate paid
  images and write a deck the user had stopped; cancellation now propagates,
  with a checkpoint before `illustrate` starts spending.
- **A failing image key costs the pictures, not the deck.** The pre-flight
  image-provider check used to abort the whole generation before a single
  slide was drafted; it now records the failure, continues without images,
  and says so in the result's warnings.
- **The prompts' image rules are derived from the renderer.** Three prompts
  hand-copied the image-eligible layout list; the QA editor's copy named
  five layouts and told the model to move briefs off the rest — quietly
  stripping imagery from the picture-beside-bullets slides `imagePlacement`
  renders. All three now interpolate from
  `SlideLayoutKind.imageEligibleLayoutNames`, with a test pinning agreement.
- **The cost estimate counts what the run costs.** It now includes the
  user's own prompt and the QA pass (which re-sends the whole draft as
  input); the old single-call figure under-read real spend by ~2.5–3×
  exactly when the user pasted a long brief.
- Provider traffic runs on an `.ephemeral` `URLSession`: the shared
  session's disk-backed cache would put response bodies — the generated
  deck, derived from the user's own prompt and PDF — at rest on disk.
- Image-provider endpoints are percent-encoded instead of force-unwrapped
  around a raw model-id interpolation.
- Slide previews render with JavaScript off and navigation cancelled — the
  SVG is model-derived content, and a preview is a picture, not a program.
- The contact sheet speaks slide titles to VoiceOver ("Slide 3 of 12: Why
  now"), not just positions; `DeckResult` carries `previewTitles` alongside
  `previews`.
- The main window keeps the user's frame: the launch-frame enforcement that
  scrubbed saved frames and re-centred 780×1060 on every launch is gone;
  `.defaultSize` handles genuinely new windows.
- Phase changes cross-blur instead of hard-cutting, and a finished deck
  lands with a success haptic.

## [0.3.1] — 2026-07-19

- README code snippets fixed to compile and run exactly as printed (missing
  `import Foundation`, undefined chart data, stray blank starter slide) and
  added as a CI-run example target (`swift run ReadmeSnippets`), so the
  documented code is built on every push.
- `SunflowerDeck` now says so on stderr when its images directory is missing
  instead of silently rendering palette fallbacks.

## [0.3.0] — 2026-07-19

First public release. (v0.1.0 and v0.2.0 were internal phase milestones —
foundations, then the phase-3 robustness pass — tagged before the repo
opened.)

### Rostrum (the library)

- Pure-Swift, zero-dependency `.pptx` engine: own zip container (read/write,
  hand-written inflate + deflate), prefix-preserving XML DOM, OPC packaging,
  and the PresentationML object model. macOS / iOS / Linux.
- Pristine-DOM hybrid storage: untouched parts round-trip byte-identically;
  deterministic output (fixed timestamps, sorted parts, stable attributes).
- Slides: add / **remove / move / duplicate**, layouts, placeholder
  inheritance. Shapes (178 preset geometries), fills, gradients, shadows,
  transforms.
- Text: paragraphs, runs, bullets, numbered lists, hyperlinks, tracking.
  Tables, pictures (dedup, cover-crop, alt text), speaker notes.
- Charts: bar / line / pie / area / doughnut / scatter with data labels, axis
  control, and an embedded Edit-Data workbook.
- Modern threaded comments, SmartArt creation + text extraction, deck merge,
  font embedding, native sections, footers and live fields, `.potx` templates.
- Design-authoring layer: `DeckStyle` tokens with WCAG auto-contrast, a Grid
  DSL, and one-call slide builders (title, bullets, comparison, process,
  pyramid, bands, metrics, callout, quote, chart, closing) with deterministic
  overflow protection.
- Schema tables mechanically derived from python-pptx (MIT, © Steve Canny) —
  see THIRD_PARTY_LICENSES.md.

### Lectern (the sample app)

- SwiftUI app for macOS, iPadOS, and iOS: prompt + audience/goal/length +
  150-style catalog + optional PDF grounding → a native `.pptx` generated
  through a validated intermediate representation with a one-shot repair
  loop. API keys live only in the Keychain.
