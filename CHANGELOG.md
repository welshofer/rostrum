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
  byte-identity (zip-entry level, content parts; `.rels` and
  `[Content_Types].xml` are deterministically re-serialized and exempt —
  see ARCHITECTURE.md), determinism, and no-trap tests
  (`RealDeckCorpusTests`).
- The python-pptx oracle now runs in CI on macOS and Linux
  (`PythonPptxOracleTests`): representative Rostrum-written decks must open
  in python-pptx on every push.
- `RostrumError.fontCorrupt` for unparseable font files.
- **FontLibrary** — `deck.fonts.register(_:aliases:)` registers fonts under
  their `name`-table family names (parsed from the sfnt, IDs 1/16) for text
  measurement. Explicit registration only: platform font lookup would break
  cross-machine determinism.
- **Measured slide builders** — with the style's fonts registered, every
  builder that fitted text by character count (title, section, closing,
  process, quote, metrics, header wrap detection) now measures with real
  advance widths. With no fonts registered, output is byte-identical to the
  previous character-count behavior.
- **Measured SVG rendering** — paragraphs whose typeface is registered render
  with real word wrap and baseline placement in `renderSVG`; unregistered
  text keeps the one-line approximation, byte-identical to before.

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
