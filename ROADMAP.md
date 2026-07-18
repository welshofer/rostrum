# Rostrum roadmap

Goal: full python-pptx parity in pure Swift, then past it. Architecture:
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md). Every phase ships something a
user can run; the byte-identity corpus gate and the python-pptx oracle run
from phase 0 onward.

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
- [x] Slides collection: iterate, `add()`, **and the three things python-pptx
  never shipped: `remove`, `move`, `duplicate`**
- [x] ShapeGeometry enum (178 presets) extracted from python-pptx tables
- [ ] `rostrum-gen` v0 proper (declarative tables → generated accessors)
- [ ] Layouts/masters collections; placeholder resolution
- [ ] Byte-identity corpus gate in CI (test exists; corpus + CI pending)

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
- [ ] Group shapes, connectors, freeform
- [ ] Bullets/hyperlinks/autofit with real font metrics

## Phase 3 — Parity completion

- [x] Charts: clustered bar, line, pie via extracted chart templates, with
  embedded Edit-Data xlsx workbooks written by our own zip engine (2026-07-18)
- [x] Speaker notes: notesMaster/notesSlide, `slide.setNotes` (2026-07-18)
- [ ] More chart types (scatter/area/radar/doughnut), chart titles/data labels
- [ ] Core/extended/custom document properties API, media parts
- [ ] Write-side DEFLATE (fixed-Huffman first) — file-size parity
- [ ] Linux CI; performance pass on large decks

## Phase 4 — Beyond parity (the reason Rostrum exists)

Ranked by demand evidence from python-pptx's issue tracker:

1. **Deck merge / slide import across presentations** — copy a slide with its
   images, charts, layout and rels intact. The #1 unsolved workflow.
2. **Theme & brand kit editing** — a real `Theme` object: palette
   (accent1–6, dk/lt), major/minor fonts, apply-a-brand-to-a-deck; resolve
   `schemeClr` → RGB through the clrMap chain.
3. ~~SmartArt~~ ✅ **Shipped 2026-07-18**: `addSmartArt(items:frame:)` creates
   Basic Block List diagrams (verified in PowerPoint + LibreOffice);
   `slide.smartArtTexts` extracts text from any diagram. Next: more layouts
   (process, cycle, hierarchy), multi-level data.
4. ~~Modern threaded comments~~ ✅ **Shipped 2026-07-18**: `addComment`/
   `addReply`/`resolve` with authors part and slide anchoring. Next:
   **sections** (`p14:sectionLst`), embedded fonts.
5. **Animations & transitions** — the `p:timing` tree, entrance/exit/emphasis
   presets, slide transitions.
6. **ChartEx** (`cx:`) — waterfall, sunburst, treemap, histogram, funnel.
7. **Reading chart data back out** and robust `replaceData` (python-pptx
   corrupts on structure mismatch).

## Phase 5 — Moonshots

- Rendering: slide → image/PDF without LibreOffice (SwiftUI/CoreGraphics
  renderer on Darwin; cross-platform raster backend later)
- Streaming/partial loading for production-scale decks
- OMML math, connector routing to attachment sites, placeholders in groups

## Standing quality gates

- `swift test` green on macOS + Linux
- Corpus decks round-trip byte-identical on untouched parts
- Every Rostrum-written deck opens in python-pptx without exception and in
  PowerPoint without repair prompt
- Zero SwiftPM dependencies, forever
