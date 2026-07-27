# Changelog

Rostrum is **pre-1.0**: minor versions may change API. Format follows
[Keep a Changelog](https://keepachangelog.com/); versions follow
[SemVer](https://semver.org/) with the 0.x caveat above.

## [Unreleased]

### Added

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
  tests (`RealDeckCorpusTests`).
- The python-pptx oracle now runs in CI on macOS and Linux
  (`PythonPptxOracleTests`): representative Rostrum-written decks must open
  in python-pptx on every push.
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
  `renderSVG` (mixed-run paragraphs keep the approximation); unregistered
  text is byte-identical to before.
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
