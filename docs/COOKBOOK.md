# Rostrum cookbook

Task-oriented recipes. Everything here is pure-Swift, zero-dependency, and
produces `.pptx` files PowerPoint opens without repair.

## A deck in four lines

```swift
import Rostrum

let deck = try Presentation()
try deck.titleSlide("Hello, Rostrum", subtitle: "A native deck engine")
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
// Open a real PowerPoint template — masters, layouts, theme, fonts intact.
let deck = try Presentation(contentsOf: URL(filePath: "brand.potx"))

// A template opens as a template and saves as one. Say when you want a deck
// out of it, so the conversion is yours rather than a surprise.
deck.documentKind = .presentation

// Or apply a design.md (fonts, palette, type/spacing/radius tokens).
deck.applyDesign(try Design(contentsOf: URL(filePath: "sunflower.md")))

try deck.bulletSlide("On brand", ["everything inherits the theme"])
try deck.save(to: URL(filePath: "out.pptx"))
```

Both compose: open a `.potx`, `applyDesign`, then build — the whole deck comes
out styled.

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
swift run pptx-tool validate out.pptx    # exit 0 if PowerPoint will accept it
```

## Determinism

Same input → byte-identical output, always (fixed timestamps, sorted parts,
stable ordering). Two runs of the same program produce the same `.pptx` bytes —
useful for caching, diffing, and reproducible builds.
