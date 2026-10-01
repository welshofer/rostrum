# Fidelity and conformance

Support is evaluated separately for reading, authoring, editing, duplication,
import, round-trip preservation and rendering. Preserving unknown XML does not
imply the renderer understands it. Animation is outside this program.

## Operation-level evidence

| Feature | Implemented operations and regression suites | Remaining acceptance work |
| --- | --- | --- |
| Tables | Merge topology, atomic overlap refusal, unmerge, row/column insert/remove/reorder, dimension synchronization; `TableContractTests`, `TableConformanceTests` | PowerPoint visual equivalence, advanced vertical cell text |
| Table appearance | Explicit edge/diagonal borders, margins, image/gradient fills, embedded/custom style regions and theme colors, custom-style dependency graphs and GUID remapping; `TableStyleContractTests`, `TableStyleImportTests`, `TableFillAtomicityTests` | Native style GUID catalog when definitions are absent; pattern fills and compound borders in preview |
| Typography | Exact regular/bold/italic face selection, mixed-run shared fit/render layout, fields, breaks, tabs, spacing, bullets, autofit; `FontFaceTests`, `RichTextLayoutTests` | Full paragraph bidi, justification, text decorations/warps/columns, language-specific typography |
| Shaping | Bounded Latin kerning/ligatures, NFC clusters, restricted Hebrew bidi and horizontal CJK breaks; `TextShaperTests` and pinned HarfBuzz oracle | Contextual Arabic/Indic shaping, mark positioning, full Unicode bidi/line-breaking |
| Pictures/crops | Source/destination crops, stretch/tile, transforms/clipping, isolated replacement; `PictureMappingTests`; resvg quadrant/transparency pixel checks | Pinned Office comparisons; alternate SVG/layer/linked image replacement refuses atomically |
| Speaker notes | Rich notes, independent duplicates, source master/theme/media import, exact-master reuse; `NotesTests`, annotation lifecycle/import suites | Conflicting masters/pagesizes are refused atomically; Office notes-page references |
| Comments | Modern edit/reopen/delete, replies, slide/shape/text anchors; legacy read/create/edit/delete; author identity and slide-anchor remapping; `CommentEditingTests`, `CommentsTests`, `DeckMergeTests` | Office thread lifecycle acceptance, richer unknown author dependency graphs |
| Sections | Slide add/remove/move/duplicate/import and section remove/move keep membership coherent; `SectionsTests`, `MetadataPreservationTests` | Namespace aliases currently refuse mutation; Office membership acceptance across foreign producers |
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
1200×700. Its generator originally emitted table borders in reverse schema
order. The original remains unchanged as evidence. `python-tables-v2` corrects
border ordering and needs its own Office export; it does not replace a failing
reference. The earlier preview comparison failed with native-style/text
differences; it predates the final SVG font-embedding changes and is not a
measurement of the final render. The final preview still reports unresolved
native-style and font/shaping issues. Notes-page references remain missing.

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

See [PERFORMANCE.md](PERFORMANCE.md) for the 2026-10-01 measurements, including
the table rendering regression and remaining cross-platform validation.
