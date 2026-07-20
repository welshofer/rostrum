# Changelog

Rostrum is **pre-1.0**: minor versions may change API. Format follows
[Keep a Changelog](https://keepachangelog.com/); versions follow
[SemVer](https://semver.org/) with the 0.x caveat above.

## [0.1.0] — 2026-07-19

First public release.

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
