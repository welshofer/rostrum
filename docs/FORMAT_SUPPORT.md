# PowerPoint format support

This matrix distinguishes keeping a feature in a file from understanding, editing,
creating or previewing it. Unknown package parts and XML are preserved by the
round-trip machinery; that is not a promise that arbitrary edits to their related
objects are safe. PowerPoint remains the visual acceptance client.

This matrix describes current `main`, including post-1.0 enhancements. See the
[documentation index](README.md) for version selection and linked evidence.

| Feature | Current support | Remaining work |
| --- | --- | --- |
| PPTX / POTX / PPSX | Recognized document kinds; templates retain native master/layout/theme relationships | Macro-enabled document kinds are not recognized; legacy binary PPT is outside the OPC reader |
| Masters, layouts, themes | Import, preserve and author; template-aware composition; preview resolves shape fill/line/font style references and paragraph run defaults | Broader real-template corpus; full effects, color-transform and text/rendering equivalence is not certified |
| Groups | Read children and transforms; preview nested coordinate spaces, rotation and flips; honor hidden shapes and groups | Creation/ungroup APIs; native visual baselines for all transform/text combinations |
| Connectors | Read connections; preview straight lines, flips, direct/theme-reference colors, basic dashes and arrowheads | Attached-connector authoring/routing; bent and curved previews currently use straight lines with warnings |
| Shape geometry | Preset geometry authoring; common preset previews and bounded custom lines/quadratic/cubic curves with guide coordinates, per-path fill/stroke and scale-independent strokes | Unsupported presets/path commands retain diagnosed fallback; custom arcs, shaded path fills, custom text rectangles and a general editable freeform API remain |
| Text | Shared fit/render layout, inherited body/list styles, all-caps, anchored exact spacing, empty-paragraph handling, measured registered faces and explicit preview fallback; bounded kerning/ligatures and script support | Full complex-script, bidi and PowerPoint typography parity; small capitals, text warps and columns |
| Charts | Native classic chart APIs, chart-cache extraction and guarded replacement; embedded-workbook read fallback; editable workbooks | Date/number-format display, named or external workbook references, broader date-category editing, stock and ChartEx |
| Tables | Native cells, formatting and merges; embedded/custom regions and all 74 built-in table styles; shared measured layout | Broader native rendering baselines |
| Table composition | Read-only row planning from native cell styles; measured column search; complete-row pagination with repeated headers/captions and horizontal spans | Vertical spans, rotated/vertical text, dynamic fields and native table autofit in the layout engine; arbitrary imported rich-cell pagination |
| Text composition | Shared rich-text authored/template fitting; inherited placeholder styles; native soft breaks; fresh fit checks before slide insertion; exact-text measured pagination | Universal native autofit equivalence; fit diagnostics still require font/shaping review |
| Embedded fonts | Atomic validation of supplied faces; identical re-embedding reuses parts; slide import preserves families/styles and merges compatible faces | Conflicting face bytes/metadata and ambiguous references refuse; opaque fonts can be preserved without being locally decodable; native rendering acceptance varies by consumer |
| SmartArt | Block list, process, cycle and pyramid creation; text extraction; bounded saved drawing-cache preview | Broader layouts, multilevel data and nontrivial cache root transforms; absent/unsupported caches use a diagnosed placeholder |
| SVG pictures | Bounded self-contained SVG, including Office SVG-only relationships; original image bytes preserved | General SVG/CSS and active/external content are rejected; unsupported artwork is diagnosed |
| Audio/video | Embedding and read-back; basic transport timing | PowerPoint playback-effect sequences, autoplay and native acceptance |
| Animation/transitions | Existing XML carried through preservation machinery | General authoring API and dedicated feature corpus |
| OLE/other graphic payloads | Retained through package/XML preservation | Semantic editing; preview uses a labeled placeholder |

## Embedded chart data

Classic charts read stored values from their embedded Excel workbook when a chart
cache is absent. This covers series names, linked titles, category labels and
numeric values, including scatter axes and bubble sizes. Present caches remain
authoritative, including intentional gaps and empty caches. Lectern inspection and
previews use the same reader. Reading does not modify the deck or make a cacheless
chart eligible for guarded data replacement.

Read fallback is not a PowerPoint repair operation. In the native comparison on
2026-10-03, PowerPoint displayed the cached control chart, but left both the
original cacheless fixture and its Rostrum round-trip blank. All three opened
without repair prompts. Lectern displayed the embedded values and chart preview
for the cacheless fixture. The unreleased explicit
`Chart.rebuildMissingCachesFromWorkbook()` operation now constructs missing
caches under stricter write-time validation. Native acceptance of repaired decks
remains pending; ordinary open/save still preserves the source package. See
[repair scope, atomicity and the runnable Lab](CHART-CACHE-REPAIR.md).

The fallback accepts local A1 cells and horizontal or vertical ranges of up to
100,000 cells, quoted sheet names, shared/inline strings and cached formula results.
It never evaluates formulas or follows external links. Named ranges, multi-area
and two-dimensional references, and Excel date/number-format display are not
supported; numeric cells expose their stored values. Compressed and expanded
workbooks are limited to 64 MiB, with at most one million shared strings and one
million visited cells per sheet. Unsupported or malformed data stays unreadable
instead of being synthesized; the original workbook remains preserved.

## Preview diagnostics

`renderSVGReportingProblems` returns broken inheritance links and detected omitted or
approximated content. Groups are traversed on slides, layouts and masters; their
children retain the owning part for relationship resolution. Traversal stops at 64
levels with a warning. Malformed group coordinates also produce a warning.
Shape-tree `mc:AlternateContent` draws its `mc:Fallback`, so equations and ink show
the pictures Office saved for them; alternate content without a fallback is
diagnosed as omitted. Both branches stay in the saved part.

Lectern's inspector reports these separately from file damage, identifies the slide,
and includes limitations in preview accessibility labels. Generated/recovered decks
also retain preview messages separately from validation and layout warnings. Previewing does not rewrite the
original file. An empty diagnostic list does not certify full visual fidelity: text
layout, font substitution, image cropping, effects and chart appearance still have
approximation limits.

Gradient previews retain stop precision, clockwise linear direction and the
`scaled` aspect-ratio setting. RGB, scheme and system fallback colors apply tint,
shade, hue, saturation, HSL luminance, RGB channel, complement, inverse, grayscale,
gamma and alpha transforms in XML order, including style reference and placeholder
transforms. Ordinary outer shadows resolve direct or theme effects, color, opacity,
blur and offset; an explicit empty effect list suppresses theme effects. Scaled or
skewed shadows are diagnosed. Text inherits presentation, master and matched
placeholder run defaults per paragraph level, with local overrides merged by property.
Missing font resources are reported. Hosts can register exact faces or opt into
`FontLibrary.previewFallbackFamily` for matching fallback measurement and drawing;
the source typeface stays unchanged. See the [preview guide](IMPORTING-AND-PREVIEWING.md).
Path-gradient geometry, tile rectangles and rotation-independent fills remain
approximate. SVG definitions use a per-render counter for deterministic IDs,
avoiding repeated scans of accumulated gradient or embedded-image data.

Rich-text previews retain per-run size, color, bold, italic, underline, strike,
baseline shift and tracking through wrapping; hard breaks, hanging character or
Arabic/alphabetic bullets, paragraph spacing, alignment and saved normal-autofit
scale are applied. Lectern supplies CoreText advances for preview wrapping;
portable callers can provide `FontLibrary.previewAdvance` or register font metrics.
This does not modify document bytes. Full complex-script and PowerPoint line-layout
parity is not certified.

Picture and picture-fill previews use saved asymmetric source crops, destination
stretch rectangles and tile transforms instead of automatic center-cropping.
Table previews resolve merged cells, direct padding/fills/edge borders and embedded
table-style regions. All 74 built-in Office style definitions are available when a deck stores only
a style ID; native whole-slide equivalence still has open acceptance gaps. Classic chart previews honor explicit series/point colors,
line width/dashes, legend presence/position, linear value-axis bounds, major gridlines
and bounded numeric formats with quoted/escaped units. Chart previews use registered
font advances and line metrics to reserve space for titles, axes, legends and
bar/line/pie data labels. Long names wrap; crowded omissions are diagnosed.
Explicit line markers and pie percentage labels are supported. Manual layout,
native collision parity and advanced number formats remain approximate. See
[chart preview support](CHART-PREVIEW-FIDELITY.md) and
[measured chart layout](MEASURED-CHART-LAYOUT-20261018.md).
Source parts are preserved unchanged.

## Acceptance priorities

1. Complete PowerPoint-rendered baselines for nested groups, flips, rotation, text
   and connector arrowheads; extend common geometry and rich text previews.
2. Extend content checks to images, hyperlinks, sections and template relationships.
3. Complete native PowerPoint acceptance for explicit missing-chart-cache repair;
   extend workbook-backed reading to date categories and formatted labels.
4. Add group/connector/freeform authoring APIs.
5. Add verified media playback and a bounded animation/transition set.
6. Expand document-kind and SmartArt support with representative fixtures.

Use the fixed benchmark input and Release configuration for performance comparisons.
Keep private templates and exported visual baselines outside version control. Tests,
structural checks and successful imports are separate from native visual acceptance.
