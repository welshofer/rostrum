# Getting started with Rostrum 1.0

Rostrum ships two Swift libraries in one package. Use `Rostrum` for PowerPoint
files and their editable contents; add `RostrumLayout` for template selection,
measured composition, authored-slide fitting and pagination. Both work on
macOS, iOS and Linux without external Swift package dependencies.

## Install with Swift Package Manager

This complete manifest creates a command-line application. Put your Swift code
in `Sources/DeckExample/main.swift`, then run `swift run DeckExample`.

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DeckExample",
    platforms: [.macOS(.v13), .iOS(.v16)],
    dependencies: [
        .package(url: "https://github.com/welshofer/rostrum", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "DeckExample",
            dependencies: [
                .product(name: "Rostrum", package: "rostrum"),
                .product(name: "RostrumLayout", package: "rostrum")
            ])
    ]
)
```

For an Xcode app, add the same repository under Package Dependencies and select
the products your target imports. `RostrumLayout` depends on `Rostrum`; it is a
separate import because document editing does not require composition.

## Create, save and reopen a deck

A new `Presentation()` contains one blank 16:9 slide. High-level builders append
slides, so remove that starter when it is not part of the intended output.
Create the output directory before saving. Reopening checks the saved package,
not only the in-memory object.

```swift
import Foundation
import Rostrum

func writeIntroduction(to outputURL: URL) throws -> Presentation {
    let deck = try Presentation()
    _ = try deck.titleSlide("Quarterly review", subtitle: "A saved, editable deck")
    let detail = try deck.bulletSlide("Progress", [
        "The document remains editable in PowerPoint.",
        "Speaker notes travel with the slide."
    ])
    try detail.setNotes("Discuss the evidence behind each result.")
    try deck.slides.remove(at: 0)
    try deck.setSections([("Overview", 0), ("Details", 1)])

    try FileManager.default.createDirectory(
        at: outputURL.deletingLastPathComponent(),
        withIntermediateDirectories: true)
    try deck.save(to: outputURL)
    let reopened = try Presentation(contentsOf: outputURL)
    precondition(reopened.slides.count == 2)
    return reopened
}

let output = URL(fileURLWithPath: "output/review.pptx")
let savedDeck = try writeIntroduction(to: output)
```

Open an existing deck with `Presentation(contentsOf:)`, make only the desired
edits, and save to a new URL to retain the original. Ordinary open/save preserves
untouched package-part payloads, including XML that the public API does not model.
The ZIP archive itself is written deterministically; its container bytes need
not match the producer's original ZIP.

## Add an editable table

New table cells center text vertically. Explicitly set `verticalAnchor` when a
particular cell needs top or bottom alignment. Existing decks keep their saved
alignment; loading an imported cell does not apply the new-authoring default.

```swift
import Foundation
import Rostrum

func writeTable(to outputURL: URL) throws {
    let deck = try Presentation()
    let slide = try deck.slides[0]
    let table = try slide.shapes.addTable(
        rows: 3, columns: 2,
        frame: Rect(x: .points(48), y: .points(72),
                    width: .points(600), height: .points(180)))
    table.setContents([
        ["Milestone", "Status"],
        ["Implementation", "Complete"],
        ["Native visual review", "Scheduled"]
    ])
    table.columnWidths([.points(380), .points(220)])
    table.rowHeights([.points(48), .points(66), .points(66)])
    let statusCell = try table.cell(1, 1)
    statusCell.verticalAnchor = .middle

    try FileManager.default.createDirectory(
        at: outputURL.deletingLastPathComponent(),
        withIntermediateDirectories: true)
    try deck.save(to: outputURL)
}
```

Rows and columns start evenly distributed within the frame. Width/height helpers
update the table extent. Row geometry remains your responsibility when content
wraps; setting a frame does not automatically paginate a table. For composition
inside a template, provide measured row height through `measureObjectHeight` and
reserve a caption before accepting the layout. See the
[layout table workflow](LAYOUT-ENGINE.md#tables-and-other-structured-objects).

The table API also supports row/column insertion, deletion and reordering,
merges, unmerge, padding, fills, cardinal/diagonal borders and style inspection.
Read the [cookbook](COOKBOOK.md) for individual editing operations and the
[conformance record](CONFORMANCE.md) for preview boundaries.

## Compose from a PowerPoint template

`Presentation.fromTemplate(data:)` starts a new PPTX from a POTX. It removes
starter slides and their unused parts while retaining masters, layouts, themes,
slide dimensions and linked template assets. This is an explicit authoring
operation; ordinary `Presentation(contentsOf:)` preserves the original document.
A template resource that points to a removed starter slide is rejected rather
than left with a broken relationship.

```swift
import Foundation
import Rostrum
import RostrumLayout

func writeFromTemplate(
    templateURL: URL,
    outputURL: URL,
    measure: TextHeightMeasurer? = nil
) throws {
    let deck = try Presentation.fromTemplate(data: Data(contentsOf: templateURL))
    let engine = TemplateLayoutEngine(presentation: deck, measure: measure)
    let columns = [[
        LayoutParagraph("Results grounded in the source material"),
        LayoutParagraph("Supporting detail retains its outline level", level: 1)
    ]]
    let plan = try engine.plan(
        title: "Quarterly progress",
        columns: columns,
        preferredTypes: ["obj", "tx"])
    let slide = try engine.compose(plan, title: "Quarterly progress", columns: columns)
    try slide.setNotes("Explain the sources and assumptions behind this slide.")
    try deck.validateTemplateBindings()
    try FileManager.default.createDirectory(
        at: outputURL.deletingLastPathComponent(),
        withIntermediateDirectories: true)
    try deck.save(to: outputURL)
}
```

`plan` evaluates compatible placeholders and measured fit before it creates a
slide. `compose` fills the selected placeholders and records permitted local
geometry/autofit changes without rewriting the template's master or layout.
The title and columns passed to `compose` should be the content used to make the
plan. `plan.score.reasons` explains selection; `masterURI` or `layoutURI` can
restrict candidates, and `variant` chooses another ranked result.

Supply a stable `TextHeightMeasurer` for the faces and shaping rules your host
will use. Lectern supplies an Apple measurement adapter. Without one, the engine
uses explicitly registered font metrics where available and an estimate where
they are absent. A successful estimated fit is not native PowerPoint acceptance.
For explicit fit failure, choose a roomier layout, adjust the content, or use
[`MeasuredPaginator`](LAYOUT-ENGINE.md#paginate-with-the-same-fit-rule).

## Render a preview and keep its diagnostics

Font registration is explicit. Register the actual regular/bold/italic faces
required by the document before measuring or rendering. Font data registered
for preview is separate from intentionally embedding a font in the saved PPTX.
The [font guide](IMPORTING-AND-PREVIEWING.md) explains permitted embedding,
missing-face fallback and strict rendering.

```swift
import Foundation
import Rostrum

func writePreview(deckURL: URL, fontURL: URL, svgURL: URL) throws -> SlideRenderProblems {
    let deck = try Presentation(contentsOf: deckURL)
    _ = try deck.fonts.register(contentsOf: fontURL)
    let result = try deck.renderSVGReportingProblems(slideAt: 0, pixelWidth: 1280)
    try FileManager.default.createDirectory(
        at: svgURL.deletingLastPathComponent(),
        withIntermediateDirectories: true)
    try result.svg.write(to: svgURL, atomically: true, encoding: .utf8)
    return result.problems
}
```

`result.problems` separates broken inheritance and detected unsupported content
from the saved document. `fidelityIssues` carry stable codes, impacts and source
locations. Set `strictRendering: true` to throw when a known preview problem is
present. Strict success does not guarantee pixel identity with PowerPoint;
unsupported content can also survive safely in a document whose preview is
incomplete.

## Exercise the library in Lectern

The [Lectern app](../Lectern/README.md) provides template selection and a Library
Lab with 34 offline demos. Run a demo to produce its own saved PowerPoint deck,
inspect the result, and use Reveal to locate it on disk. Run All retains an
individual result for every demo; slide counts depend on the recipe. A demo's
reported support boundary and reopen checks describe what it actually exercised.

Use [architecture](ARCHITECTURE.md) to understand mutation boundaries,
[layout](LAYOUT-ENGINE.md) for composition details and
[conformance](CONFORMANCE.md) to plan native visual acceptance.
