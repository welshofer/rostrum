# Fidelity and conformance

Support is evaluated separately for reading, authoring, editing, duplication,
import, round-trip preservation and rendering. Preserving unknown XML does not
imply the renderer understands it. Animation is outside this program. The [October 2 integrated record](IMPLEMENTATION-20261002.md) contains the current combined checks and acceptance failures.

## Operation-level evidence

| Feature | Implemented operations and regression suites | Remaining acceptance work |
| --- | --- | --- |
| Tables | Merge topology, atomic overlap refusal, unmerge, row/column insert/remove/reorder, dimension synchronization; `TableContractTests`, `TableConformanceTests` | PowerPoint visual equivalence, advanced vertical cell text |
| Table appearance | Typed compound/dash line settings, qualified solid double-border geometry, native style-boundary precedence, shared-edge ownership, merged-continuation/RTL borders, margins, image/gradient fills, embedded/custom regions and all 74 native style definitions, theme-owned image references, correct tint/shade/saturation and Office interpolation for endpoint-pair/mirrored-three-stop gradients; `BuiltInTableStyleTests`, `TableStyleContractTests`, `TableStyleImportTests`, `TableFillAtomicityTests` | Whole-slide Office equivalence; pattern fills, effects, unsupported compound/dashed-double/junction variants in preview |
| Typography | Exact regular/bold/italic face selection, mixed-run shared fit/render layout, Office-verified baseline subset, fields, breaks, tabs, spacing, bullets, autofit; `FontFaceTests`, `RichTextLayoutTests` | Whole-image typography equivalence, full paragraph bidi, justification, text decorations/warps/columns, language-specific typography |
| Shaping | Bounded Latin kerning/ligatures, Arabic joining/contextual GSUB, GDEF filtering, Calibri compatibility, NFC clusters, restricted Hebrew bidi and horizontal CJK breaks; `TextShaperTests`, `ArabicShapingTests`, `FontCompatibilityTests`, `FontLookupFilteringTests` and pinned HarfBuzz oracles | Complete Arabic/Indic shaping, mark/cursive attachment, full Unicode bidi/line-breaking |
| Pictures/crops | Source/destination crops, stretch/tile, transforms/clipping, isolated replacement; `PictureMappingTests`; resvg quadrant/transparency checks and 12 passing Office mapping cases | Broader native image/effect coverage; alternate SVG/layer/linked image replacement refuses atomically |
| Speaker notes | Rich notes, printable default page geometry, foreign placeholder inheritance, independent duplicates, source master/theme/media import, exact-master reuse; `NotesTests`, `NotesPageLayoutTests`, annotation lifecycle/import suites | Conflicting masters/page sizes are refused atomically; broader Office notes lifecycle coverage |
| Comments | Modern edit/reopen/delete, replies, slide/shape/text anchors; legacy read/create/edit/delete; author identity, slide-anchor remapping and bounded custom dependency graph transfer; `CommentEditingTests`, `CommentsTests`, `DeckMergeTests`, `AuthorDependencyImportTests` | Office thread lifecycle acceptance and broader custom author dependency interoperability |
| Sections | Slide add/remove/move/duplicate/import and section remove/move keep membership coherent; `SectionsTests`, `MetadataPreservationTests`, `SectionCompatibilityContextTests`; namespace aliases and inherited compatibility/XML contexts are preserved | Office membership acceptance across foreign producers |
| Package performance | Operation-local traversal, collision-checked media index, bounded compression reuse, streaming save, read-only lazy inspection | Cross-platform timing baselines and Linux execution for this change |

The test suite names are evidence pointers, not certification labels. A supported
operation must retain unrelated XML and relationships, fail before mutation when
it cannot preserve them, and produce deterministic saved bytes. No entry above
is a promise of universal Office rendering equivalence.

## Rendering contract

`renderSVGReportingProblems(slideAt:)` returns structured `FidelityIssue` values
with stable category, impact, slide index, part URI, shape ID and XML path.
`strictRendering: true` throws `StrictRenderingError` containing the same report
when known omissions, approximations or missing resources are encountered.
Strict mode detects known gaps; passing it is not a full OOXML certification.

Register exact font faces on `deck.fonts` before rendering. SVG embeds permitted
registered font bytes under renderer-owned family names. Restricted fonts,
missing faces, unsupported collection embedding and unsupported shaping remain
explicit diagnostics. `shape.fitText(fonts: deck.fonts)` and SVG use the same
`RichTextLayout` geometry and registered faces. The `fitText(using:)` overload
uses one supplied metrics face instead. Fitting does not return fidelity issues;
inspect `renderSVGReportingProblems` or `RichTextLayout.diagnostics`.

```sh
swift run pptx-tool render deck.pptx /tmp/slide-preview --font /path/to/font.ttf
swift run pptx-tool render deck.pptx /tmp/slide-preview --font /path/to/font.ttf --strict
```

`pptx-tool validate` is required-attribute/schema lint. It does not prove that
PowerPoint accepts a document or that a preview matches PowerPoint.

## Independent fixtures and gates

`Tools/conformance/make_table_fixture.py` authors redistributable fixtures using
python-pptx 1.0.2. The manifest pins hashes, producer, fonts and provenance.
It accepts a new `--id` and refuses to overwrite existing fixtures/references.

The original `python-tables` reference was exported by PowerPoint 16.113.3 at
1200×700. Its generator emitted table borders in reverse schema order.
`python-tables-v2` corrects ordering; `python-tables-v3` also registers the notes
master in presentation.xml, correcting a python-pptx 1.0.2 omission. Earlier
fixtures and failing references remain unchanged. Both v2/v3 now have Office
slide and notes-page references; v2's unpositioned notes are retained as a
producer defect. V3's notes print correctly. No repair dialog was observed.

The [notes corpus](../Tests/RostrumTests/Fixtures/NotesPages/manifest.json)
contains newly authored notes and a v3 import at the same slide size. Office
print-to-PDF output confirms the default slide image/body geometry. The imported
notes PNG matches its independent source reference exactly (0 differing pixels
at the existing channel-16 / fraction-0.005 limits). This is one successful
notes import, not evidence for conflicting-master reconciliation.

Font-aware comparisons must resolve SVG embedded aliases to the exact registered
font files. resvg-py 0.5.0 ignores CSS @font-face data URLs; an unconfigured resvg
run silently substitutes fonts and is not a typography oracle. No font binaries
from Office or the operating system are redistributed with these fixtures.

The preserved [October 1 v3 comparison](../Tests/RostrumTests/Fixtures/Conformance/python-tables-v3-comparison.json)
reports 18,145 / 840,000 pixels (2.1601%) above channel tolerance 16. The
[current integrated comparison](benchmarks/2026-10-02-integrated-table-comparison.json)
uses the same four hash-verified Arial/Calibri faces and reports **17,314 /
840,000 pixels (2.06119%)**, still exceeding the unchanged 0.5% gate. Shared
border centers match; stroke antialiasing and text residuals remain. Earlier
failing candidates and immutable Office references are retained separately.

```sh
python Tools/conformance/check_text_rendering.py --svg /path/to/slide.svg --reference Tests/RostrumTests/Fixtures/Conformance/python-tables-v3-office.png --fonts /path/to/local-fonts.json --width 1200 --height 700 --output /tmp/text-comparison
```

Development checks:

```sh
swift test --filter TableConformanceTests
python3 Tools/conformance/release_gate.py --semantic-only
python3 -m unittest discover -s Tools/conformance -p 'test_*.py'
```

Image mappings also have an independent raster check. Install the pinned
development-only `resvg-py==0.5.0` and `Pillow==12.3.0` in an isolated Python
environment, then run:

```sh
ROSTRUM_IMAGE_ORACLE_OUTPUT=.build/image-oracles swift test --filter PictureMapping
python Tools/conformance/check_image_mapping.py .build/image-oracles
```

The current fixture checks 14 exact quadrant/transparency pixels across stretch,
crops, rotation/flips and tiling, including overlapping shape/table fills.
Shared background-image mapping has separate structural test coverage. The
raster probes do not establish Office or text/font raster equivalence.

The release command is `python3 Tools/conformance/release_gate.py --rendered-dir
/path/to/candidate-pngs`. Missing references, semantic errors, pixel differences,
repair dialogs, inaccessible automation and timeouts fail. The pixel comparator
allows channel differences up to 16 in at most 0.5% of pixels at identical image
dimensions. Do not replace a reference merely to pass the check.

`Tools/ppt-check.sh FILE` opens a uniquely named owned temporary copy through
PowerPoint's normal open path. It closes only its own document on success and
retains failed copies. In this run the scripted automation timed out and failed;
a separate manual UI check/export of the owned fixture observed no repair dialog.
Those are different pieces of evidence, and the release gate remains open.

## Performance measurement

`OPCArchive` offers bounded read-only package inspection. `.strict` checks every
payload at open; `.onAccess` checks payload CRC/decoded size on first read while
still enforcing archive structure and aggregate/per-entry budgets at open.
The per-entry limit bounds both compressed input and declared decoded output.
`presentation()` materializes a separate complete editable document. Existing
`Presentation` initializers remain eager and retain their validation timing.

```sh
ROSTRUM_BENCH_FONT=/path/to/font.ttf python3 Tools/rostrum-bench/run.py --output /tmp/rostrum-bench.json
```

The release driver records one warmup plus five fresh process samples by
default, median/p95, peak RSS, compiler/OS, input/output/font hashes and independent
python-pptx parsing. Cold unchanged save and warm cached save are separate phases.
Compare like-for-like platforms, corpora, fonts and build configuration; measure
variance before setting regression limits.

See [PERFORMANCE.md](PERFORMANCE.md) for the October 1 and 2 measurements, including
the historical renderer regression, follow-up improvements and remaining
cross-platform validation.

## Native table-style fill references

The separate [74-style corpus](../Tests/RostrumTests/Fixtures/NativeTableStyles/manifest.json)
was authored with python-pptx 1.0.2, saved by PowerPoint Mac 16.113.3 and exported
through its PNG exporter at 1200x700. The saved fixture has no embedded style
definitions. Its original slide/notes content is project-authored; last-modified
author metadata is normalized to the project test identity. The catalog's
source/license provenance is independent and documented in
[the catalog README](../Tools/table-style-catalog/README.md).

All **1,480 sampled cell fills** pass, across all 74 native styles, with the
first-row header and horizontal banding enabled. The pinned initial report and [post-border follow-up](../Tests/RostrumTests/Fixtures/NativeTableStyles/fill-probe-followup.json) contain
candidate/reference hashes, viewport and a three-level per-channel tolerance.
This is fill-only evidence; it does not certify borders, text, effects, every
flag combination or complete Office equivalence. Theme effects remain visible
fidelity issues. No tolerance was changed to obtain this result.

```sh
swift run pptx-tool render Tests/RostrumTests/Fixtures/NativeTableStyles/native-styles.pptx .build/native-style-oracles/svg
python Tools/conformance/check_native_styles.py .build/native-style-oracles/svg --report .build/native-style-oracles/report.json
```

## Author dependency consumer check

The [pinned customXML import](../Tests/RostrumTests/Fixtures/AuthorDependencyImport/manifest.json)
and its augmented PowerPoint source open without repair in PowerPoint 16.113.3.
Accessibility reports one comment on imported slide 2; its body was not verified
in the Office pane. The manifest records the exact hashes and the earlier
synthetic arbitrary-URN relationship that failed before import. This verifies
one standard customXml relationship combination, not arbitrary Office extension
semantics. Conflicting author-list language/space/QName context and dependencies
on defined Office semantic parts refuse atomically.

## Shared table-border references

The independent [42-case corpus](../Tests/RostrumTests/Fixtures/TableBorders/manifest.json)
uses python-pptx 1.0.2 source geometry and PowerPoint 16.113.3 PNG exports.
All **737 probes** pass at a maximum one-channel rounding difference: ordinary
shared-edge ownership, noFill/absent edges, widths, alpha, dash gaps, RTL sides,
and merged continuations. The checker normalizes the SVG pixel viewport to
1200×700 while preserving its EMU viewBox. It separately reports neighborhood
residuals: Office and resvg stroke antialiasing are not pixel-identical.

```sh
python Tools/conformance/make_table_border_fixture.py /tmp/new-border-fixture.pptx
python Tools/conformance/check_table_borders.py Tests/RostrumTests/Fixtures/TableBorders/manifest.json Tests/RostrumTests/Fixtures/TableBorders/powerpoint-16.113.3-png.zip /path/to/SlideN-svgs
```

References are immutable evidence, not adjusted to match library output. The
74-style fill oracle and border oracle do not certify all table features.


## Additional native evidence — October 2

The [image corpus](IMAGE-OFFICE-20261002.md) has 12 independent, text-free cases
covering pictures and shape/table fills. All v2 mapping cases pass the unchanged
whole-PNG gate; three original v1 cases remain failing because their inherited
shadows are omitted. Strict diagnostics now expose those active effects and
unsupported format-scheme theme overrides. Empty direct overrides and namespace
aliases do not create false effect reports. Broader effects remain unsupported.

The [double-border corpus](../Tests/RostrumTests/Fixtures/DoubleTableBorders/README.md)
verifies 29 PDF geometry cases and 216 stable style-boundary PNG probes across
LTR and RTL. Whole-PNG results are separate: 26/29 double cases and 24/36 cases in
each style corpus pass. Solid flat centered double borders are a qualified
preview subset; unsupported compound/dash/cap/junction combinations report
fidelity issues. [Typed line settings](LINE-STYLES.md) support reading and writing
more styles than the renderer can accurately preview.

The [typography corpus](../Tools/typography/OFFICE-BASELINES.md) verifies 46 line
baselines across 30 Arial/Calibri cases against native PDF geometry. Exact local
font identities and PDF glyph outlines are checked first. Four of six native PNG
comparisons still fail. This baseline result is limited to the captured styles,
sizes, transitions, wrapping and breaks; it does not qualify all scripts or text
layout. Root repeated the vector check and verified unchanged candidate SVG
hashes on the final integrated code.

## Continued fidelity work — October 2

The [continued implementation record](FIDELITY-FOLLOWUP-20261002.md) supersedes
the style-image counts above. Bounded table-background shadows bring **both
LTR and RTL style corpora to 36/36 passing**, at the original PNG tolerance.
The shadow remains a diagnosed approximation. V3 table, three double-border
and four typography image failures remain; no reference or gate was relaxed.

DrawingML kerning thresholds now govern shaping, wrapping, fitting and SVG.
The [horizontal-position diagnostic](../Tools/typography/KERNING-AND-POSITIONS.md)
retains the failing native PNG evidence separately from the 46 passing baselines.

The [notes geometry corpus](../Tests/RostrumTests/Fixtures/NotesGeometry/manifest.json)
qualifies imports between otherwise identical masters with different complete
body/slide-image placeholder positions and sizes. Four native PDF page pairs
are pixel-identical at 1224×1584: original source/imported, existing target/imported,
and both imported pages before/after a PowerPoint save/reopen. A public
python-pptx geometry oracle independently covers differing placeholder indices.
Duplicate types and broader master/theme/page-size conflicts refuse atomically.

```sh
python3 Tools/conformance/check_notes_geometry.py --output /tmp/notes-geometry.json
```

Use `--candidates` and `--type-candidates` to check freshly generated outputs
from the environment-controlled `NotesImportGeometryTests` fixtures. The checker
pins original bytes and captured PDFs; it does not launch Office. Original v1
conformance notes now have a native reference too, retaining their producer
defect. The general release gate still fails for missing candidate renders,
including notes pages; these bounded native tests do not certify universal
notes-page rendering.
