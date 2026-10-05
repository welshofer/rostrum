# Horseshoe Curve: The long way over the mountain

A complete, reproducible Swift example: a 28-slide history of Horseshoe Curve near Altoona, Pennsylvania, authored with **Rostrum** and **RostrumLayout**. The included [PowerPoint deck](Horseshoe-Curve.pptx) is ready to open and inspect; its content, builder and illustrated assets are all here.

![Overview of the 28-slide Horseshoe Curve presentation](overview.jpg)

## What the example demonstrates

| Feature | Included |
|---|---|
| Slide composition | 28 slides using 13 composition patterns |
| Images | 10 generated illustrations in 11 cropped placements |
| Charts | 2 editable native charts, each with an embedded workbook |
| Tables | 2 editable tables with vertically centered cell text |
| Speaker notes | Notes on all 28 slides, including source URLs |
| Comments | 2 native comments identifying the library authoring |
| Sections | 5 named sections |

The composition patterns include covers, large dates, image-led slides, comparisons, timelines, tables, charts, a statement, a closing image and sources. Georgia headings, Arial body text, warm paper, forest green and rust give the deck a consistent visual identity while leaving room for varied slide structures.

All PowerPoint content is created and saved in Swift through Rostrum and RostrumLayout. The raster illustrations were generated separately and are embedded as pictures. Rebuilding uses the committed images; it does not call an image-generation service or require API credentials.

## Build the deck

The example requires **macOS 13 or later and Swift 6.0 or later**. Run this command from the repository root:

```sh
swift run --package-path Examples/HorseshoeCurve/Builder HorseshoeDeck
```

The builder locates this example directory from its own `#filePath`. You can also pass an absolute path explicitly:

```sh
swift run --package-path Examples/HorseshoeCurve/Builder HorseshoeDeck \
  "$PWD/Examples/HorseshoeCurve"
```

**Rebuilding intentionally overwrites `Horseshoe-Curve.pptx` in the example directory.** It also produces `previews/slide-01.svg` through `slide-28.svg` and `validation.json`; those generated diagnostics are ignored by Git. The checked-in overview image is a visual index, not an output of the builder.

This example uses Apple CoreText and CoreGraphics to measure text with the system Georgia and Arial fonts. That measurement choice makes this particular builder macOS-specific. The Rostrum and RostrumLayout libraries remain portable; another host can provide its own text-measurement implementation.

## Follow the implementation

| File | Purpose |
|---|---|
| [Builder/Package.swift](Builder/Package.swift) | Local Swift package depending on the repository's `Rostrum` and `RostrumLayout` products |
| [Builder/Sources/HorseshoeDeck/main.swift](Builder/Sources/HorseshoeDeck/main.swift) | Design tokens, text measurement, composition, native content authoring, saving and validation |
| [content.json](content.json) | Slide text, layout choices, chart values, table cells, notes, comments and sections |
| [sources.json](sources.json) | Historical sources, supported claims and research access dates |
| [images/provenance.json](images/provenance.json) | Image prompts, provenance, file hashes and historical limitations |
| [images/](images/) | Generated illustrations used by the builder |
| [Horseshoe-Curve.pptx](Horseshoe-Curve.pptx) | Finished editable presentation |

Start with `content.json` to change the story. In `main.swift`, `Builder` creates the presentation and design, supplies a `TextHeightMeasurer`, and uses `AuthoredLayoutEngine` to compose and fit the slides. The composition branches demonstrate native text, cropped pictures, tables and charts. `addNotes` writes the presentation narrative and citations; `build` assigns sections, saves, reopens and checks the result.

The example keeps the historical content separate from the Swift composition code, so it is also a starting point for a different subject. If you change the slide count or feature mix, update the builder's explicit demo-contract checks along with the content.

## Validation and inspection

The builder reopens the saved deck and checks template bindings, slide and note counts, note text and source URLs, comment text, image bytes and crops, table dimensions and cell content, vertical cell alignment, chart values and embedded workbooks. It writes a machine-readable receipt and SVG previews for inspection.

The included deck was opened in Microsoft PowerPoint without a repair prompt. Its speaker notes, comments and sections were also inspected in PowerPoint. This is a separate manual check: a rebuild's `validation.json` deliberately leaves `nativePowerPointVerified` set to `false`, because the Swift builder does not launch or verify PowerPoint.

SVG rendering is an approximation, not a pixel-perfect PowerPoint reference. The current deck reports **41 text-shaping approximation diagnostics** involving Unicode/native advance rounding and **2 chart-approximation diagnostics**. Review those records when changing typography or charts, and use PowerPoint to inspect the final native presentation.

## Historical and image interpretation

The narrative distinguishes the 1854 locomotive-hauled mountain crossing from the earlier Portage system, separates the 1942 sabotage plan from an attack, and dates track configurations rather than applying today's arrangement to every era. Figures and dates are supported by citations in the notes and source registry.

Every generated scene is labeled as an illustration. These images interpret the setting and period; they are not archival photographs, portraits of identified people, surveyed views or engineering specifications. The modern aerial includes features that did not exist when the line opened. Image prompts and specific limitations are recorded in `images/provenance.json`.
