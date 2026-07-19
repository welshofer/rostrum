# Rostrum

[![CI](https://github.com/welshofer/rostrum/actions/workflows/ci.yml/badge.svg)](https://github.com/welshofer/rostrum/actions/workflows/ci.yml)
[![Swift 6](https://img.shields.io/badge/Swift-6-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/platforms-macOS%20%7C%20iOS%20%7C%20Linux-blue.svg)](#)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A **pure-Swift, zero-dependency** library for creating and editing PowerPoint
(`.pptx`) files. Rostrum owns its entire stack — from the zip container and a
hand-written DEFLATE codec, up through OPC packaging and the PresentationML
object model. It runs anywhere Swift runs: **macOS, iOS, Linux**.

It began as a ground-up port of
[python-pptx](https://github.com/scanny/python-pptx) and now does things
python-pptx never could: slide **remove / move / duplicate**, **modern
threaded comments**, **SmartArt** creation and text extraction, **deck merge**,
**theme / brand-kit editing**, and lossless byte-identical round-trips of the
parts you don't touch.

```swift
import Rostrum

let deck = try Presentation()                       // one blank 16:9 slide
let slide = try deck.slides.add(layout: deck.layout(type: "title")!)
slide.title?.textFrame?.text = "Hello, Rostrum"
try deck.save(to: URL(filePath: "hello.pptx"))
```

### …or the design-authoring layer

Open a brand template, apply a `design.md`, and build a whole deck from one-call,
auto-laid-out builders — on-brand, no placeholder plumbing:

```swift
let deck = try Presentation(contentsOf: URL(filePath: "brand.potx"))   // native .potx support
deck.applyDesign(try Design(contentsOf: URL(filePath: "sunflower.md")))

try deck.titleSlide("Q3 Business Review", subtitle: "Northwind", kicker: "FY26")
try deck.bulletSlide("Highlights", ["ARR $18.4M", "Retention 91%", "NPS 47"], kicker: "Results")
try deck.chartSlide("Revenue", .line, arr, options: ChartOptions(legend: .bottom))
try deck.setSections([("Cover", 0), ("The Quarter", 1)])
try deck.footer("Confidential").showSlideNumbers()
try deck.save(to: URL(filePath: "review.pptx"))
```

More recipes in the [cookbook](docs/COOKBOOK.md).

## Install

Swift Package Manager:

```swift
.package(url: "https://github.com/welshofer/rostrum", from: "0.1.0")
```

then add `"Rostrum"` to your target's dependencies.

## What it can do

| Area | Highlights |
|---|---|
| **Slides** | add, remove, **move, duplicate**, layouts & placeholder inheritance |
| **Shapes** | 178 preset geometries, rounded rects (pill corners), transforms, rotation |
| **Fills & lines** | solid, alpha, multi-stop gradients, outlines, soft shadows |
| **Text** | paragraphs, runs, fonts, sizes, colours, alignment, spacing, tracking, **bullets, numbered lists, hyperlinks** |
| **Pictures** | PNG/JPEG/GIF sniffing, content dedup, natural sizing, **cover-crop (`fit: .fill`)**, alt text |
| **Tables** | grid, cell fills & anchors, merge, banded rows |
| **Charts** | bar / line / pie / area / doughnut / scatter, stacked & multi-series, titles, **data labels**, axis control, embedded Edit-Data workbook |
| **SmartArt** | Basic Block List creation; **text extraction from any diagram** |
| **Comments** | modern threaded comments, replies, resolve |
| **Notes** | per-slide speaker notes |
| **Fonts** | **embed TTF/OTF** so a deck renders identically everywhere |
| **Theme** | read/edit palette & fonts; resolve `schemeClr` → RGB |
| **Merge** | import a slide from another deck with its images, charts and layout intact |
| **Design layer** | `DeckStyle` (type scale, WCAG auto-contrast, tokens); one-call slide builders; cards/buttons/kickers/stat tiles; a Grid DSL |
| **Templates** | open a `.potx`/`.ppsx` directly; drive styling from a `design.md` (fonts, palette, spacing/radius/type tokens) |
| **Sections** | native PowerPoint sections; footers, slide numbers, dates via live fields |
| **Tooling** | `pptx-tool inspect`/`validate` — machine-checkable "PowerPoint will accept this" gate |

## Design

Rostrum is a **pristine-DOM hybrid**: a mutable XML DOM is the storage layer,
and parts keep their **original bytes until first mutation**, which makes
lossless round-trips a structural guarantee rather than an aspiration. Typed
Swift facades read and write through to the DOM, with schema-ordering tables
mechanically extracted from python-pptx's own declarations
(`Tools/rostrum-gen`). Full rationale in
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md); roadmap in
[`ROADMAP.md`](ROADMAP.md).

Layers, bottom to top:

| Layer | Location | Counterpart |
|---|---|---|
| Zip container (read/write, own inflate + deflate) | `Sources/Rostrum/Zip` | Python's `zipfile` |
| XML DOM (parse/serialize, prefix-preserving) | `Sources/Rostrum/XML` | `lxml` |
| OPC packaging (parts, content types, relationships) | `Sources/Rostrum/OPC` | `pptx.opc` |
| Generated schema tables | `Sources/Rostrum/Schema` | `pptx.oxml` descriptors |
| PresentationML object model | `Sources/Rostrum/Presentation`, `Charts` | `pptx.parts` + API |

## Examples

Runnable sample decks live in `Examples/` — a 15-slide climate briefing, a
30-slide illustrated field guide, and a self-referential showcase — each
emitted entirely in Swift:

```sh
swift run ClimateDeck out.pptx
```

## Verification

Rostrum is checked three ways: unit tests against external oracles
(`unzip -t`, `zlib`), reopening its own output, and — the strictest — a
scripted **PowerPoint double-click open** (`Tools/ppt-check.sh`) that catches
integrity errors other tools tolerate.

## License

[MIT](LICENSE). Contributions welcome — see [`CONTRIBUTING.md`](CONTRIBUTING.md).
