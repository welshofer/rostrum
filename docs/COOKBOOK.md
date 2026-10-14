# Rostrum cookbook

Task-oriented recipes for the pure-Swift, zero-dependency libraries. Fragments
assume the surrounding document and geometry exist; see [Getting started](GETTING-STARTED.md)
for complete setup. Current `main` includes post-1.0 layout APIs. Saved-file checks
and native PowerPoint acceptance remain separate from successfully running a recipe.

## A minimal deck

```swift
import Rostrum

let deck = try Presentation()
try deck.titleSlide("Hello, Rostrum", subtitle: "A native deck engine")
try deck.slides.remove(at: 0) // remove Presentation()'s blank starter slide
try deck.save(to: URL(filePath: "hello.pptx"))
```

## One-call slide builders

Free-shape, auto-laid-out, on-brand — no template placeholders required:

```swift
try deck.titleSlide("Q3 Business Review", subtitle: "Northwind", kicker: "FY26")
try deck.sectionSlide("The Quarter", number: 1)
try deck.bulletSlide("Highlights", ["ARR $18.4M", "Retention 91%", "NPS 47"], kicker: "Results")
try deck.twoColumnSlide("Growth", left: ["New logos"], right: ["Expansion"])
try deck.comparisonSlide("Plan vs. Actual", leftHeader: "Ahead", left: [...], rightHeader: "Behind", right: [...])
try deck.chartSlide("ARR trajectory", .line, arr, kicker: "$M")
try deck.calloutSlide(stat: "26 mo", caption: "cash runway")
try deck.quoteSlide("Best quarter yet.", attribution: "The board")
```

Every builder returns the created `Slide` for further tweaking.

## Bring a brand: `.potx` templates and `design.md`

```swift
// Start a new deck with the template's masters, layouts, theme and fonts.
// Starter slides are removed; use TemplateLayoutEngine to fill placeholders.
let deck = try Presentation.fromTemplate(
    data: Data(contentsOf: URL(filePath: "brand.potx")))
let engine = TemplateLayoutEngine(presentation: deck)
let columns = [[LayoutParagraph("Content in the template's native typography")]]
let plan = try engine.plan(title: "On brand", columns: columns, preferredTypes: ["obj", "tx"])
_ = try engine.compose(plan, title: "On brand", columns: columns)
try deck.validateTemplateBindings()
try deck.save(to: URL(filePath: "out.pptx"))
```

Import `Foundation`, `Rostrum` and `RostrumLayout` for this path. Register the
template's exact font faces before planning. A separate authored-deck workflow
applies `design.md` to a fresh presentation:

```swift
let deck = try Presentation()
deck.applyDesign(try Design(contentsOf: URL(filePath: "sunflower.md")))
try deck.bulletSlide("On brand", ["everything inherits the theme"])
try deck.slides.remove(at: 0)
try deck.save(to: URL(filePath: "out.pptx"))
```

An imported template owns its typography and artwork. Applying a design is an
explicit change to that design, not part of preserving template inheritance.
For ordinary template editing, `Presentation(contentsOf:)` keeps starter content
and the original document kind; it differs from `fromTemplate(data:)`.

For editable multi-page tables, follow the complete
[measured table recipe](GETTING-STARTED.md#paginate-a-measured-table). It registers
fonts, plans widths and row heights, repeats headers/captions, saves and reopens
the result. See [horizontal spans](LAYOUT-ENGINE.md#horizontal-merged-cells) for
grouped headers, and [font operations](IMPORTING-AND-PREVIEWING.md#embedding-fonts-safely)
for embedding and import conflict handling.

`documentKind` is what PowerPoint reads to tell a `.pptx` from a `.potx` from a
`.ppsx`; the file extension is decoration. Leave it alone and a template stays a
template through any number of round trips. Set it and you get the other format
— but save under the matching extension, because a file named `.pptx` whose main
part still says `template` opens as a template and spawns a new untitled deck.

## Style and components

`deck.style` resolves the theme + applied design into a `DeckStyle` (type scale,
colors with WCAG auto-contrast, spacing/radius tokens):

```swift
let s = deck.style
let slide = try deck.slides.add()
try slide.setBackground(.solid(s.background))
try slide.addKicker("QUARTERLY", in: kickerRect, style: s)
try slide.addText("Highlights", in: titleRect, role: .title, style: s)
let card = try slide.addCard(in: cardRect, style: s)             // rounded + shadow
try slide.addStatTile("18.4M", caption: "ARR", in: card.content, style: s)
try slide.addButton("See details", in: buttonRect, style: s)     // pill, auto-contrast label
```

## Layout with the Grid

```swift
let grid = Grid(in: deck.bounds, columns: 12, rows: 12, gutter: .inches(0.2), margin: .inches(0.9))
let hero = grid.cell(column: 0, row: 0, columnSpan: 8, rowSpan: 6)
let (left, right) = deck.bounds.inset(by: .inches(1)).split(.horizontal, ratio: 0.5, gutter: .inches(0.3))
```

## Tables

```swift
let table = try slide.shapes.addTable(rows: 5, columns: 3, frame: frame)
table.setContents([["Region", "ARR", "YoY"], ["Arctic", "18.1", "−12%"], ...])
    .columnWidths([.inches(5), .inches(3), .inches(3)])
    .cellPadding(deck.style.spacing.sm)
    .styleBanded(style: deck.style)          // brand header + alternating rows, auto-contrast
```

## Charts

```swift
let data = ChartData(categories: ["Q1", "Q2", "Q3"], series: [
    .init(name: "Actual", values: [15.1, 16.6, 18.4]),
    .init(name: "Plan",   values: [15.0, 16.4, 17.9]),
])
try deck.chartSlide("Revenue", .line, data, options: ChartOptions(legend: .bottom))
// kinds: barClustered/barStacked/barPercentStacked/line/area/pie/doughnut, plus addScatterChart
```

## Sections, notes, footers

```swift
try deck.setSections([("Cover", 0), ("The Quarter", 1), ("Looking Ahead", 4)])
try deck.slides[2].setNotes(["Anchor on the iteration loop.", "Pause here."])
try deck.footer("Confidential — Northwind").showSlideNumbers()
```

## Merge decks

```swift
try dest.slides.importAll(from: source)   // brings images, charts, layouts, rels
```

## Inspect / validate output

```sh
swift run pptx-tool inspect out.pptx     # structured report
swift run pptx-tool validate out.pptx    # modeled structural lint; exit 1 on reported issues
```

A successful lint is not proof of PowerPoint acceptance: it checks modeled
required attributes, not every relationship or consumer requirement. For
packaging/XML changes also run `Tools/ppt-check.sh out.pptx` on macOS.

## Determinism

Same input → byte-identical output, always (fixed timestamps, sorted parts,
stable ordering). Two runs of the same program produce the same `.pptx` bytes —
useful for caching, diffing, and reproducible builds.
