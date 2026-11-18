# Keynote Interchange

`KeynoteInterchange` is a zero-external-dependency SwiftPM product alongside
`Rostrum`, `RostrumLayout`, and `LecternIR`. It reads and writes Apple's `.keyx`
ZIP/JSON interchange format directly. It does not read native `.key`/IWA files,
create a PowerPoint intermediate, call Apple's cloud exporting service, or bundle
Apple theme artwork.

## Editing an existing interchange document

```swift
import KeynoteInterchange

var document = try KeyxDocument(contentsOf: inputURL)
try document.editSlide(at: 0) { slide in
    slide.setNote(.value(KeyxText("Updated presenter notes")))
}
try document.save(to: outputURL)
```

Documents, nodes, text, slides, and authoring results are owned, `Sendable` value
snapshots. No source file, security scope, or shared mutable document is retained.
An edit closure commits only if it returns successfully. Callers choose a new
output URL when the original must remain unchanged.

`KeyxNode` retains unknown fields. `KeyxProperty` distinguishes `.inherited`
(absent), `.cleared` (JSON null), and `.value`. Null is not interchangeable with
absence and is rejected where a modeled property does not permit it.
`KeyxStyleResolver` resolves presets and stylesheet references without writing
inherited values back into the original JSON.

Untouched JSON entries and all untouched resource/extension entries keep their
original bytes. Edited JSON is encoded with stable key ordering; unknown numeric
values retain their exact spelling, not a rounded `Double`. ZIP entry order and
timestamps are deterministic. ZIP encoding itself is not promised to match the
input archive byte-for-byte.

The reader bounds archive bytes, expanded bytes, entries, JSON depth/nodes,
resource bytes, and table traversal. It rejects duplicate ZIP names and JSON
members. Semantic checks report preset cycles/ambiguity, duplicate object IDs,
missing resources/layouts, invalid geometry and table ranges. A save refuses
errors. Missing presets have the format's default-fallback semantics and produce
a warning. Package and object versions are independent; newer declarations are
never silently replaced with older versions.

## Authoring from shared intent

```swift
import LecternIR
import KeynoteInterchange

let deck = DeckIR(meta: Meta(title: "Quarterly review"), slides: [
    IRSlide(id: "intro", layout: "title", title: "Quarterly review",
            body: Body(subtitle: "A native editable interchange presentation"),
            notes: "Welcome")
])
let result = try KeyxAuthor.render(deck)
try result.document.save(to: outputURL)
```

`KeyxAuthor.render(_:options:images:template:measure:)` returns
`KeyxAuthoringResult`: a document, explicit warnings, and `slideGroups` mapping
each original intent ID to its authored pages. Supply image bytes by IR slide ID.
The portable measurement fallback is approximate; Apple hosts can supply a
`KeyxTextMeasurer` backed by native shaping. Long text and unmerged tables
paginate without summarizing or dropping content.

The useful authoring subset is native text/runs, vector framing, PNG/JPEG/GIF
resources, notes, rectangular tables including merges, and numeric bar/line/pie
charts. Richer IR layouts use measured reading-order text with a warning rather
than pretending to reproduce the PPTX design. Rotated table text, oversized
merged tables, ambiguous template placeholders, and multi-series pie charts
fail explicitly rather than discard data. Full image crop inference, complex
diagram layout, chart style parity, and advanced table formatting remain outside
the initial authoring subset.

User-owned `.keyx` templates retain their slide size, theme, layout definitions,
presets, resources, and unknown fields. Template authoring requires self-contained
layouts with explicit usable title/body (or object) slots. Starter slides are
replaced intentionally; normal open/save does not remove them. Source-only
unreferenced template resources are retained, so templates must not contain
private example attachments the caller would not want in the generated file.

## Inspection, preview, and acceptance

`inspectSlide(at:)` reads text, notes, tables, numeric chart data, resources,
fonts, and shape counts, with per-slide extraction warnings.
`KeyxPreviewRenderer.render(_:slideAt:fonts:)` creates a self-contained SVG
directly from interchange geometry. It can reuse Rostrum's `FontLibrary` and
`TextMeasurer`; it never constructs a `Presentation`.

Previews are explicitly approximate. Unsupported objects stay in the document,
and warnings describe effects, inherited external theme artwork, merged-cell
display, text layout, media, and chart limitations. A preview is not evidence of
Keynote fidelity. Semantic validation is not full JSON Schema validation.

Run the public example and validate against the separately downloaded Apple
schemas (the validator is test-only, not a runtime dependency):

```sh
swift run KeyxExample /tmp/keyx-example
python3 scripts/check-keyx-schema.py --schemas /path/to/keynote-interchange-format-json-schema.zip \
  "/tmp/keyx-example/Native Keynote Interchange.keyx"
```

Native Keynote acceptance is a separate manual gate. The format is **1.0 beta**:
builds/transitions/Magic Move, comments, Skip Slide, soundtracks/recordings, dynamic
backgrounds and some media/chart features cannot be made lossless through unknown
JSON preservation. Keynote regenerates slide identifiers on opening interchange
documents; recovery must not assume those identifiers survive external edits.
No general PPTX/interchange conversion API is claimed.

## References and provenance

The initial acceptance used the 242-schema archive with SHA-256
`8d72b25e155597dbab95b18b208e193146f31de5009e005b13c6a449ffdea6d3`.
The generated mixed-content example passes that archive's Draft 2020-12 checks.
Native Keynote acceptance is recorded separately, never inferred from this result.

- [Format documentation](https://developer.apple.com/documentation/keynoteinterchangeformat)
- [Authoring requirements](https://developer.apple.com/documentation/keynoteinterchangeformat/understanding-authoring-requirements-for-keynote-interchange-format)
- [Authoritative schema download](https://developer.apple.com/download/files/keynote-interchange-format-json-schema.zip)
- [Python reference implementation](https://github.com/apple/creator-studio-doc-format/tree/995911cae658ffc98a1f63ccf314b5dd120d7652)

The Swift code implements the documented semantics independently. Apple schema
files and artwork are not redistributed. Apple's Python reference library has
its own Apache-2.0 license; the separately downloaded schema archive carries
Apple copyright notices and is not assumed to share that license.
