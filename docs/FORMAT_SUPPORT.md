# PowerPoint format support

This matrix distinguishes keeping a feature in a file from understanding, editing,
creating or previewing it. Unknown package parts and XML are preserved by the
round-trip machinery; that is not a promise that arbitrary edits to their related
objects are safe. PowerPoint remains the visual acceptance client.

| Feature | Current support | Remaining work |
| --- | --- | --- |
| PPTX / POTX / PPSX | Recognized document kinds; templates retain native master/layout/theme relationships | Macro-enabled document kinds are not recognized; legacy binary PPT is outside the OPC reader |
| Masters, layouts, themes | Import, preserve and author; template-aware composition; preview resolves shape fill/line/font style references and paragraph run defaults | Broader real-template corpus; full effects, color-transform and text/rendering equivalence is not certified |
| Groups | Read children and transforms; preview nested coordinate spaces, rotation and flips | Creation/ungroup APIs; native visual baselines for all transform/text combinations |
| Connectors | Read connections; preview straight lines, flips, direct/theme-reference colors, basic dashes and arrowheads | Attached-connector authoring/routing; bent and curved previews currently use straight lines with warnings |
| Shape geometry | Preset geometry authoring; preview 13 common outlines including diamonds, triangles, chevrons and directional arrows; literal adjustments and preset text regions | Other presets/custom geometry use rectangles with warnings; formula-based adjustments, effects and additional shape text rules remain; editable freeform API |
| Text | Runs, paragraphs, fonts, bullets, spacing and autofit; CoreText measurement adapter in Lectern | Full rich-run shaping/measurement parity; portable metrics do not apply kerning, ligatures or complex-script shaping |
| Charts | Native classic chart APIs, chart-cache extraction and guarded replacement; embedded-workbook read fallback; editable workbooks | Date/number-format display, named or external workbook references, broader date-category editing, stock and ChartEx |
| Tables | Native cells, formatting and merges; measured layout in Lectern | Broader native rendering baselines |
| SmartArt | Block list, process, cycle and pyramid creation; text extraction | Broader layouts and multilevel data; preview uses a labeled placeholder |
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

Lectern's inspector reports these separately from file damage, identifies the slide,
and includes limitations in preview accessibility labels. Generated/recovered decks
also retain preview messages separately from validation and layout warnings. Previewing does not rewrite the
original file. An empty diagnostic list does not certify full visual fidelity: text
layout, font substitution, image cropping, effects and chart appearance still have
approximation limits.

## Acceptance priorities

1. Complete PowerPoint-rendered baselines for nested groups, flips, rotation, text
   and connector arrowheads; extend common geometry and rich text previews.
2. Extend content checks to images, hyperlinks, sections and template relationships.
3. Extend workbook-backed chart reading to date categories and formatted labels.
4. Add group/connector/freeform authoring APIs.
5. Add verified media playback and a bounded animation/transition set.
6. Expand document-kind and SmartArt support with representative fixtures.

Use the fixed benchmark input and Release configuration for performance comparisons.
Keep private templates and exported visual baselines outside version control. Tests,
structural checks and successful imports are separate from native visual acceptance.
