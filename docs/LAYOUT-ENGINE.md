# RostrumLayout and shared text layout

Rostrum separates document layout from slide composition. The shared text engine
measures existing DrawingML for fitting and previews. The `RostrumLayout` product
chooses and fills native template regions or finishes slides authored from a
design system. Neither is a replacement for PowerPoint's complete layout engine.

Version 1.0 ships `RostrumLayout` as a separate SwiftPM product. Add both products
to a composing application and `import RostrumLayout` alongside `import Rostrum`.
The [getting-started guide](GETTING-STARTED.md) includes a complete manifest and
native-template example. Read this guide with the
[preview guide](IMPORTING-AND-PREVIEWING.md), [format support matrix](FORMAT_SUPPORT.md)
and [conformance record](CONFORMANCE.md).

## Components and responsibilities

| Component | Responsibility | Mutation boundary |
| --- | --- | --- |
| `RichTextLayout` in `Rostrum` | Resolve inherited rich text, shape and measure runs, break lines, place spans and compute occupied height and fit | Read-only geometry and diagnostics |
| `FontLibrary`, `FontMetrics`, `TextShaper` | Explicit face registration, advances and bounded shaping; optional host measurement and measured preview fallback | Registration changes the host's font registry, not source typeface names |
| `shape.fitText(fonts:)` | Use shared rich-text geometry to compute saved normal autofit | Explicit editing operation; writes computed fit settings |
| `SVGRenderer` | Draw resolved content using text geometry and collect fidelity issues | Read-only preview; does not repair or relayout the saved document |
| `TemplateLayoutEngine` in `RostrumLayout` | Evaluate native layouts, measure content, score compatible candidates and fill placeholders | Composes new slide content; retains the supplied master/layout/theme |
| `AuthoredLayoutEngine` in `RostrumLayout` | Check and fit design-authored text regions, then publish a reusable layout | May adjust authored typography and spacing; not used to rewrite imported templates |
| `StructuredLayout` in `RostrumLayout` | Preflight and compose editable metrics, process, cycle, pyramid, timeline, quadrant and band structures | Adds native shapes and text inside the chosen region |
| `MeasuredPaginator` in `RostrumLayout` | Partition ordered content according to a caller's actual fit predicate | Returns partitions without dropping or reordering content |

```mermaid
flowchart TD
    Source["DrawingML text + master/layout/theme ancestry"] --> Resolve["Resolve body, paragraph, run and list styles"]
    Fonts["Explicit fonts + optional host measurement"] --> Measure["Shape and measure runs"]
    Resolve --> Measure
    Measure --> Lines["Wrap lines, place spans, compute anchors and fit"]
    Lines --> Preview["SVG preview + fidelity report"]
    Lines --> Fit["Explicit fit operation → saved autofit"]
    Template["Native template layouts + generated content"] --> Candidates["Measure and rank compatible regions"]
    Candidates --> Compose["Fill native placeholders or report cannotFit"]
```

The composition adapters are distinct from `RichTextLayout`. They can accept a
`TextHeightMeasurer` supplied by the host, such as Lectern's Apple measurement
adapter. Do not assume that every composition decision is made by the portable
rich-text algorithm or that a computed fit matches PowerPoint's chosen autofit.

## Choose the right operation

| Input and intent | API | Result |
| --- | --- | --- |
| Inspect an existing slide | `renderSVGReportingProblems(slideAt:)` | SVG plus known fidelity issues; source content is preserved |
| Explicitly fit a text shape | `shape.fitText(fonts:)` | Saved normal-autofit settings computed from shared rich-text layout |
| Start from a `.potx` | `Presentation.fromTemplate(data:)`, then `TemplateLayoutEngine` | New PPTX slides connected to the source template's layouts and masters |
| Finish slides built from a `Design` or `DeckStyle` | `AuthoredLayoutEngine` | Checked/adjusted authored text and optional published native layouts |
| Break ordered content across pages | `MeasuredPaginator` | Fitting partitions; the caller creates slides and retains document context |

### Measurement contract

`TextHeightMeasurer` receives a `TextMeasureRequest`: text, family name, point
size, bold flag, tracking and available width in points. Return the occupied
height in points for that request. The engine applies its own paragraph/body
spacing and fit rules around this measurement. Keep the adapter deterministic
and the font environment fixed while an engine is in use.

Lectern's [adapter](../Lectern/Sources/LecternCore/Rendering/TemplateRendering.swift)
uses CoreText when available. The portable library does not discover installed
fonts or fetch missing resources. With no adapter, it uses registered font
metrics when available and an estimated character-width path otherwise. The
adapter contract measures a single styled text value, so it does not imply the
full DrawingML semantics of `RichTextLayout`. Preserve those different evidence
boundaries when evaluating fit results.

The layout code uses point coordinates around `Rect`/`EMU`; OOXML stores lengths
in EMUs. Construct lengths with `.points(...)` or `.inches(...)` instead of mixing
raw EMU integers with measured point heights.

## Shared text layout

`RichTextLayout` produces positioned lines/spans, `contentHeight`, `fits`,
`truncated` and shaping diagnostics in point coordinates. Resolution combines
local text-body properties with layout/master defaults, then resolves paragraph
levels and run properties. It accounts for insets, mixed sizes and styles,
tracking, explicit breaks, fields, supported tabs, bullets, paragraph spacing,
saved normal autofit, wrapping and vertical anchoring. The default line bound is
4,096; reaching a bound is observable through truncation rather than an
unbounded layout loop.

The imported-fidelity update fixes several interactions:

- Inherit body properties and placeholder list styles; apply all-caps before
  measuring rather than changing only the displayed glyphs.
- Keep empty-paragraph spacing without emitting a marker or advancing numbering.
  Treat bullet font/size alternatives as inheritance choice groups.
- Use the paragraph text face for automatic numbers and the configured bullet
  face for character bullets. Center/right-aligned markers move with their text.
- Separate interline pitch from final occupied height. Exact line spacing no
  longer adds a following-line gap to the final line of an anchored block.
- Keep viewer advances for adjacent unmeasured runs instead of placing each at
  an estimated absolute x coordinate. Explicit tabs, lines and list boundaries
  retain their positioning.
- Allow an explicit registered `previewFallbackFamily` so unavailable-font
  previews use the same face for measuring and drawing. Missing-font diagnostics
  and strict refusal remain; source font names are preserved.

The native acceptance record includes four title anchors improving from 9–13
pixels too high to within 0–1 pixel at 960×540. This scoped result does not certify
all fonts, scripts, line-breaking rules or native text effects.

## Template composition

`TemplateLayoutEngine.plan` filters layouts by requested content, optional master
or layout identity, usable title/body/object/picture placeholders and geometry.
It measures candidate regions before selecting one. Captions reserve measured
space alongside their objects; fixed artwork and other placeholders bound title
flow. A custom cover can use one body placeholder with separate title/subtitle
levels without flattening its source template.

The candidate score considers semantic layout preference, headline hierarchy,
required shrinking, usable content area, column balance and image aspect ratio.
Equal scores retain stable source order. `TemplateSlidePlan.score.reasons`
exposes the decision factors; `variant` selects among the ranked candidates.
Empty canvas is not itself treated as a defect.

Template autofit respects the source body's policy. Supported normal autofit
uses a bounded search and readable lower limits; eligible overflow or shape
autofit can grow a slide-local region into available space. `noAutofit` does not
mean that wrapping is forbidden. The engine does not rewrite a master to force
a candidate to fit. If no compatible candidate works, it throws
`LayoutError.cannotFit` with the relevant constraints.

Structured objects inherit the content placeholder's typeface and master palette.
Generated object typography scales with slide height relative to a 540-point
canvas. Tables, charts, diagrams and captions therefore participate in measured
composition rather than consuming arbitrary leftover rectangles.

### Plan, inspect, compose, validate

```mermaid
flowchart TD
    Input["POTX + exact content + optional measurement adapter"] --> New["fromTemplate: retain template library, remove starter slides"]
    New --> Filter["Filter by master/layout identity and content placeholders"]
    Filter --> Fit["Measure title, body, object and caption"]
    Fit --> Valid{"Compatible readable candidate?"}
    Valid -- yes --> Rank["Score semantic match, shrink, area and balance"]
    Rank --> Plan["TemplateSlidePlan: frames, font scales and reasons"]
    Plan --> Compose["compose: fill inherited text placeholders"]
    Compose --> Objects["Caller inserts pictures, tables, charts or structures"]
    Objects --> Save["Validate layout/master/theme bindings and save PPTX"]
    Valid -- no --> Retry["cannotFit: choose another layout or paginate"]
```

A plan records the layout and its selected title/body/object/picture slots,
measured text frames and font scales, separate object/caption frames and scoring
reasons. Build and compose with the same title and column content. Planning does
not create a slide; `compose` creates and fills text placeholders. The caller
adds the requested picture or structured object in the returned region.

Call `validateTemplateBindings()` before saving to check the resulting
slide → layout → master → theme chain. This verifies package relationships,
not visual acceptance. The [template example](GETTING-STARTED.md#compose-from-a-powerpoint-template)
shows the complete save path.

### Tables and other structured objects

Object geometry must leave room for both its content and its caption. For a
table, use `object: "tbl"` and compatible preferred types such as `["tbl", "obj"]`.
Provide `objectCaption`, `minimumObjectHeight` and, when rows wrap,
`measureObjectHeight(width, style)`. The callback is evaluated for each candidate
width and should account for cell widths, padding, text styles, every row and
borders. Use `validateObject(frame, style)` for additional rejection conditions.

After planning, use `objectFrame` for the table or chart and `captionFrame` for
its explanatory text. `objectStyle(layout:slot:)` resolves the placeholder's
font and the owning master's palette. Object type sizes scale relative to the
presentation's height, using a 540-point reference canvas. The caller writes
row heights and cell content; the planner does not automatically divide an
existing table across slides.

`StructuredLayout` provides native editable shapes for metrics, process, cycle,
pyramid, timeline, quadrant and band arrangements. It accepts 1–12 items,
measures heading/detail content before adding shapes and throws when content
cannot fit its region. Use `StructuredLayout.validate` from `validateObject`
during planning, then `StructuredLayout.compose` after text composition. This
path creates shapes and text; it is separate from a SmartArt diagram part.

Newly authored `TableCell`s have `.middle` vertical anchoring. Set `.top` or
`.bottom` explicitly for another authoring choice. Imported cells preserve the
source setting, including the OOXML top fallback when no anchor is present.
The read-only table fit/preview path uses the cell's current anchor, padding
and effective style rather than assuming a text-box body.

## Authored slides and pagination

For a design you own, create a presentation, apply `Design`/`DeckStyle`, then
call `compileThemeMaster()` to publish shared theme typography and backgrounds.
Compose the slide content and call `AuthoredLayoutEngine.finish(_:layoutName:)`
to fit authored text and publish a real subordinate layout. Published layout
prototypes retain geometry and reusable styles; actual slide text stays on the
slide. Native tables, charts and pictures remain editable slide objects with
insertion placeholders in the layout. Use this flow for authored designs;
imported POTX content follows the template engine's inheritance path.

`AuthoredLayoutEngine` is the final pass for design-authored slides. It rejects
text frames outside the slide and checks occupied height within the insets.
Where needed it compacts spacing and reduces type within readable bounds,
preserving intentionally small captions. A failed fit is reported; it does not
silently discard text. `finish` fits the slide and publishes its layout.

`MeasuredPaginator.pages` accepts a deterministic, monotonic fit predicate and
finds fitting prefixes without changing their order. A single item that cannot
fit produces an error. `MeasuredPaginator.text` splits at word boundaries into
exact substrings whose concatenation reproduces the original. Cancellation is
checked during partitioning. The consumer remains responsible for creating
continuation slides and retaining notes and other document context.

### Paginate with the same fit rule

For a known template text slot, reuse `engine.fits` as the predicate. This example
partitions paragraphs against a selected plan's first text slot; the caller can
then compose one page at a time with the same template and title constraints.

```swift
import Rostrum
import RostrumLayout

func paragraphPages(
    _ paragraphs: [LayoutParagraph],
    plan: TemplateSlidePlan,
    engine: TemplateLayoutEngine
) throws -> [[LayoutParagraph]] {
    guard let slot = plan.textSlots.first, let frame = slot.frame else {
        throw LayoutError.cannotFit("The selected layout has no body text region.")
    }
    return try MeasuredPaginator.pages(paragraphs) { candidate in
        engine.fits(candidate, in: frame, layout: plan.layout, slot: slot.index)
    }
}
```

The predicate must be deterministic and monotonic: adding content must not make
an otherwise oversized prefix fit. Keep the chosen layout and measurement
policy stable for the partitioning operation. Recheck the complete final plan
when titles, captions or other occupied regions change. For one oversized
paragraph, `MeasuredPaginator.text` splits at word boundaries while retaining
exact substrings, including whitespace. A single unfit item is an explicit
failure, not permission to omit it.

The consumer owns continuation titles, notes, source references, sections and
stable review identity. Lectern's composition layer carries that context and
reports expanded slide counts. The paginator itself neither creates slides nor
selects how to redistribute comments or notes.

## Performance and determinism

Template measurement caching is scoped to an engine and keyed by text, font,
size, bold, tracking and width. It clears at 8,192 entries; a cache miss does not
change the layout rule. Use a stable measurement adapter and font environment
for an engine's lifetime, and create a new engine after changing them or the
template layouts it evaluates.

Font-resource encoding retains at most 4 MiB of cached base64 data and invalidates
on registration. Ordered single-scalar ASCII shaping avoids unnecessary lookup
construction and sorting while retaining the general path for other input.
These are separate optimizations from candidate measurement caching.

The imported-deck checkpoint measured 16.5% lower warm library rendering time.
Other text/table benchmarks use different baselines, and some richer fidelity
paths cost more. Do not sum the percentages or infer device latency from them.
The [performance ledger](PERFORMANCE.md) preserves workloads, baselines and limits.

## Native glyph placement and table context

The calibrated left-to-right Latin profile keeps authored, measured and painted
font sizes separate. Supported runs emit explicit scalar positions without
stretching glyphs to fit a guessed width. Absent or explicit-zero resolved kerning
disables pairs in this profile; positive thresholds use the measured size.
General or unsupported runs retain their separate fallback policy. This boundary
is why cross-platform tests must embed the face they intend to measure rather
than depend on the host's installed fonts.

`RichTextLayout.Context.tableCell` selects table semantics explicitly. Cell
fitting reads current padding, table style and vertical anchor from the owning
cell, including after those properties change. The supported table path ignores
stored font scaling and measures at 100% with zero reduction; unverified stored
line reduction remains diagnosed and prevents a positive fit result. None of
these read-only calculations rewrites the saved body.

Repeated-style attribute lookup, compact scalar storage, reserved glyph capacity
and reuse of shaped line breaks reduce repeated layout work. The
[initial glyph integration record](LAYOUT-FIDELITY-20261004-9.md) and its linked benchmark
retain source revisions, independent glyph/spacing evidence and tradeoffs.
Lectern's paragraph demonstration has seven slides; the cell-appearance
example has three. Their integration tests exercise saved-file inspection and the WebKit paint path;
acceptance remains scoped to the recorded source and test environment.

## Later native corrections and demonstrations

The 1.0 engine includes these bounded additions, reconciled before the release:

- List markers use native-calibrated sizing and continuation placement for the
  admitted profiles. Threshold-crossing sizes keep the earlier shaping path.
  The list-marker demonstration preserves the native reference specimens and
  distinguishes computed fitting from source geometry.
- Center/right alignment has native coverage for fractional origins, trailing
  spaces, hard breaks, insets, wrapping, actual faces and table context. This
  evidence expands coverage without claiming a new universal alignment algorithm.
- Mixed-face exact spacing admits distinct resources with equivalent normalized
  Windows vertical metrics. It corrects vertical origins while preserving glyph
  x positions, painted sizes and source faces. Unequal metrics, mixed-face
  percentage spacing and table contexts keep their separate fallback behavior.
- A table without an applied style renders as the native unstyled black grid;
  the style-list insertion default is not treated as an applied style. Import
  preserves absent style IDs and properties. Bounded opaque solid, unmerged LTR
  borders with unequal widths use surviving perpendicular edges to determine
  join endpoints. Later native cases extend bounded admission to axis-color
  profiles, partial custom styles and unmerged LTR collinear color/width
  transitions. Explicit empty edges, noFill and direct overrides retain their
  distinct behavior; missing effective cardinal edges in resolved custom styles
  receive native black 1 pt defaults without rewriting authored XML.
- Selected image-fill inventory retains the owning slide, theme or style part
  while resolving relationships. Shape/table fills, backgrounds and active
  inherited furniture contribute selected resources to inspection and export.
  Direct overrides suppress inherited selections; unresolved or external
  resources produce deterministic warnings without fetching remote content.

Ordered glyph-range assembly, indexed cell lookup, resolving only live cell text
styles, operation-local marker parsing and reuse of ordinary inherited SVG
attributes reduce repeated work. These changes preserve their own measured
baselines and admission rules. See [performance measurements](PERFORMANCE.md).

Lectern has 34 offline recipes, including native list markers, text alignment,
mixed-face spacing, table defaults, join profiles, partial custom styles,
border transitions and image ownership. Each uses saved-file checks and the
inspector/export paths. The [table transitions record](LAYOUT-FIDELITY-20261004-21.md),
[partial styles record](LAYOUT-FIDELITY-20261004-19.md) and
[image inventory record](LAYOUT-FIDELITY-20261004-22.md) distinguish source,
native, browser and manual acceptance. Later image-inventory integration has
standalone AppState evidence; fresh native UI acceptance and comparative
image-inventory performance remain deferred in that record.

Acceptance remains bounded. Marker comparisons retain six explicit omissions;
computed-fit pages do not prove native autofit choices. Colored RTL/merged
combinations, dashed or translucent transitions and compound borders retain
separate fallback paths. Neither workflow checks nor the native specimens
establish complete table or whole-slide equivalence. Historical [publication evidence](PUBLICATION-HYGIENE.md) distinguishes checks
rerun for that publication pass from upstream acceptance records. It is not a
replacement for the current release gate.

## Source and verification map

- [Shared rich-text layout](../Sources/Rostrum/Presentation/RichTextLayout.swift)
  and [SVG renderer](../Sources/Rostrum/Presentation/SVGRenderer.swift).
- [Font registry](../Sources/Rostrum/Fonts/FontLibrary.swift) and
  [shaping](../Sources/Rostrum/Fonts/TextShaper.swift).
- [Template engine](../Sources/RostrumLayout/TemplateLayoutEngine.swift),
  [authored engine](../Sources/RostrumLayout/AuthoredLayoutEngine.swift), and
  [paginator](../Sources/RostrumLayout/MeasuredPaginator.swift).
- [Imported-fidelity acceptance](IMPORTED-FIDELITY-20261003.md) and
  [operation-level conformance](CONFORMANCE.md).

Regression coverage includes rich-text layout, font faces, inherited imported
geometry, native line boundaries, template composition and pagination. Run the
complete `./scripts/verify.sh` gate and inspect native/consumer output before
claiming visual acceptance. Full complex-script, bidi, unsupported geometry and
unavailable native-font equivalence remain outside the documented guarantees.
