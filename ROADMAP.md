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

## Phase 1 — The object model skeleton

- Pristine-blob dirty-flag machinery on `Part` (the hybrid's core mechanism)
- `rostrum-gen` v0: extract descriptor tables from python-pptx source
  (`xmlchemy` declarations, `spec.py`, enum tables); emit typed wrappers for
  the presentation/slide/master/layout element families
- Slides collection: iterate, `addSlide(layout:)`, **and the three things
  python-pptx never shipped: `remove`, `move`, `duplicate`** (top-3 requested
  feature, 15 years open)
- Layouts/masters collections; placeholder resolution (slide → layout → master)
- Byte-identity corpus gate wired into CI at the OPC layer

## Phase 2 — Shapes and text

- Shape tree: autoshapes (184 preset geometries from the extracted tables),
  pictures, group shapes, connectors, freeform builder
- Transforms (position/size/rotation/flip), fills (solid/gradient/picture/
  pattern), line format, shadow — full effect properties, not python-pptx's
  inherit-flag-only `ShadowFormat`
- Text frames: paragraphs, runs, fonts, colors, alignment, bullets,
  hyperlinks, autofit **with real font-metric computation** (python-pptx
  writes the attribute but can't compute `fontScale` — we can)
- Images: dedup by SHA-1 (as python-pptx does), PNG/JPEG dimension sniffing
- Tables: full parity (merge, banding, styles)

## Phase 3 — Parity completion

- Charts: the classic `c:` namespace set (bar/line/pie/scatter/area/radar…)
  via extracted chart-template XML; embedded xlsx workbook part (needs our
  zip writer — already done)
- Notes slides, core/extended/custom document properties, media parts
- Write-side DEFLATE (fixed-Huffman first) — file-size parity with python-pptx
- Linux CI; performance pass on large decks (python-pptx: 1.7 GB RAM for a
  323-slide deck — pristine blobs mean we only pay for parts actually touched)

## Phase 4 — Beyond parity (the reason Rostrum exists)

Ranked by demand evidence from python-pptx's issue tracker:

1. **Deck merge / slide import across presentations** — copy a slide with its
   images, charts, layout and rels intact. The #1 unsolved workflow.
2. **Theme & brand kit editing** — a real `Theme` object: palette
   (accent1–6, dk/lt), major/minor fonts, apply-a-brand-to-a-deck; resolve
   `schemeClr` → RGB through the clrMap chain.
3. **SmartArt** — read text out of existing diagrams first (data1.xml), then
   authoring via layout templates. python-pptx returns literally nothing.
4. **Sections** (`p14:sectionLst`), **modern threaded comments**, embedded
   fonts.
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
