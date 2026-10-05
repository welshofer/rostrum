# RTL, colored and merged table borders — 2026-10-04

This checkpoint extends native table-border geometry to three captured profiles:
unmerged single-color RTL grids, unmerged LTR grids with one color per axis, and
single-color LTR merges sharing one orientation. Lectern's 31st offline recipe,
Table join profiles, exercises the same behavior through saved presentations,
the inspector and export. Production integration is `c8f91dc`, with Sources tree
`59c7beb3d5e49ebf49cecb361a36f5ce53b9b7b1`.

Native generated-deck, external package, fresh browser and manual workflow
checks pass, as does the full local app gate. Independent performance review also passes. Final independent integration review passes. The
[integration manifest](benchmarks/2026-10-04-table-join-profiles-integration-verification.json)
records the pinned evidence and retained intermediate verification history.

## Native evidence and implementation

The original two-page native fixture contains eight cases and 112 body glyphs.
It covers LTR and RTL unequal grids, two swapped vertical/horizontal color
assignments, and matching/conflicting hidden declarations under horizontal and
vertical merges. Before correction, seven cases fail 69 painted-interval checks,
with a maximum endpoint error of 1.5 pt. All glyphs retain their positions, with
maximum native origin residual of 0.008225 pt. The missing fidelity is border
geometry and order; no text-position correction is introduced.

The correction changes only SVGRenderer's mixed-width profile admission and
the mapping of horizontal endpoint extensions in RTL. Logical lower/upper
extensions are swapped when mapped to physical left/right. Existing donor
lookup, surviving border ownership, style resolution, cell geometry and text
layout are unchanged. Existing grouped emission paints interior verticals,
interior horizontals, outer verticals and then outer horizontals. The two native
color-swapped cases independently distinguish this order at nine crossing
midpoints each. Those finite checks are not a raster-equivalence claim.

Admission retains the previous rectangular-topology, opaque plain-solid,
no-diagonal and cell-dimension bounds. Every cell dimension must exceed the
widest stroke. A merged table must use one color, LTR direction, and exclusively
horizontal merges or exclusively vertical merges across the whole grid.
Combined RTL/color/merge profiles, mixed merge orientations, two-axis merges,
arbitrary collinear color transitions and other uncaptured profiles keep their
prior path. Existing uniform-width behavior remains unchanged. The algorithm
uses linear segment scans and bounded donor lookup without persistent DOM caches.

Vector bounds remain 0.001 pt and color bounds 0.0001 per channel. All 112 glyph
origins use 0.025 pt and raw painted sizes use 0.002 pt. Canonical intervals join
only adjacent strokes with identical opaque paint and width. Complete raw paths,
paint order, original fonts and native operators remain retained. Trace bounding
boxes do not establish glyph-ink or whole-slide visual equivalence.

## Lectern and generated native decks

Both recipe options retain the original eight specimen nodes, source master
bindings and embedded DejaVu Sans bytes on their first two pages. Only captions
outside the specimens change font. A third page exercises public direction,
border and merge APIs. Its option changes the right-hand table from a horizontal
merge to a vertical merge; the RTL and axis-colored controls remain fixed.
Each variant passes 44 saved-file checks with no findings.

Both generated three-slide files open without repair in PowerPoint 16.113.3.
Root exported local PDFs using Best for printing with online export disabled,
confirmed unchanged source PPTX hashes, and visually reviewed all six pages.
The first two pages are the numerical native-reference scope. The third page
is a separate public-API demonstration.

The recipe validator parses each page once, checks actual font bytes and aliases,
and rejects unmodelled text positioning, transforms, dash and cap changes.
App tests compare every inspector preview against both the saved SVG and a
fresh render, then recheck the on-disk source after export. Negative controls
cover reversed crossing order, changed width/color, transforms and glyph offsets.

Fresh native and browser extraction each pass 16 case comparisons and 224
glyphs across four reference-page comparisons, with all origins bounded by
0.025 pt in both axes. Complete border coverage, every region of the combined
stroke-edge arrangement and all nine crossing midpoints per colored specimen
agree. Actual embedded/subset font identity and raw PDF paint sizes are checked.
The initial raw-segmentation/page-selection harness failure is retained. An
S18-only adapter handles touching identical opaque subdivisions while retaining
paint order; extra, missing, gapped, recolored, resized and reordered strokes
are rejected by controls. An intermediate broader-baseline receipt is retained
and superseded by the final 0.025 pt baseline check.

Fresh browser regressions pass all prior paragraph/kerning (14 cases / 208
glyphs), markers (48 / 554, with six explicit omissions), alignment (48 / 344),
mixed-face spacing (24 / 192) and table-default (24 / 144) specimens at their
existing individual bounds. These use the actual new gate captures.

Root completed both Run Demo → Inspect Result → Export Everything workflows
through the native app. Each shows 44 successful checks, three loaded previews
and an export of three slides with no media or chart CSVs. All 52 source text
nodes per option survive the scoped Markdown unescaping. Source hashes taken
before inspection remain unchanged after export and match native capture inputs.
All six saved previews match the app-gate previews exactly; the raw-library
comparison needs only root viewport normalization. The receipt pins 38 files
and the tested app binary. UI creation times of 8.22 and 2.78 seconds are
observations, not controlled benchmark measurements.

## Verification

The library passes 1,183 tests in 172 suites; RostrumLayout passes 18 tests in
three suites; LecternCore passes 298 tests in 45 suites. The app gate passes
91 test definitions in 27 suites, covering 127 executions. Both macOS and iOS
simulator builds explicitly succeed; README and four offline checks pass.
The xcresult has zero failures, expected failures, skips or runtime warnings.
The console separately retains 12 clipboard-error, 249 preferences-daemon and
12 audio-component messages, DisplayLink notices and compiler warnings. No
contradictory quiet-build exit-zero diagnostic appears.

All 31 catalog recipes pass 649 checks and retain 413 findings describing other
support boundaries. Four separately retained table-default/profile pipeline
reports pass another 214 checks, for 863 checks across 35 executions. These
additional executions are not additional recipes.

Independent ZIP CRC, unique-member, XML and python-pptx validation reopens 80
packages, 268 slides and 2,979 XML/relationship parts. All 430 checked inputs
remain unchanged. All 49 native fixture files match the frozen engine commit,
and 16 generated/native-input identity checks pass. All 34 prior special SVGs
are byte-identical. Of 64 prior general and pipeline packages, 60 are exact;
four differ only in independently validated comment/author UUIDs and timestamps.

## Performance protocol

The frozen experiment compares the accepted preceding Sources tree with only
this SVGRenderer correction. Its baseline reuses byte-identical retained S17
Release products; the candidate is freshly built. The plan contains 374 fresh
child processes, one excluded warmup pair and ten alternating retained pairs
per workload. It foregrounds 18 comparisons and reports all 196 measured phases,
including unchanged and rejected controls, process RSS and host activity.

Untimed preservation covers 177 cases and 872 slides in 531 fresh processes
and external reopens. Seven cases change 12 SVGs only in line endpoints/order;
complete non-line trees, line counts and paint attributes remain exact. Saved
packages, diagnostics, inheritance and candidate repeat renders remain exact.
The 13 preceding table inputs and four unchanged/rejected profile controls are
entirely unchanged. Native fidelity evidence remains distinct from stress-case
classification. The approved single campaign and independent numerical review are complete. All 374 children finish once in 100.0253 seconds, without
a rerun. Native rendering observes −1.332% (95% bootstrap interval −2.040% to
+0.643%); RTL −0.382% (−1.275% to +0.898%); axis colors −0.186% (−1.281% to
+1.213%); horizontal merges +0.653% (−1.606% to +2.145%); and vertical merges
+0.872% (−0.721% to +2.106%). Every newly admitted target interval includes
zero. The unchanged rejected merge/color control retains an adverse upper
bound of +4.689%. Process RSS differences range from −0.422 to +0.359 MiB.
Backup activity reaches 135.9% in retained host snapshots. No speedup, isolated
allocation saving or universal nonregression claim follows from these samples.
The separate performance report retains all 196 phases and inconclusive controls.

## Next gap

Partial custom table styles still omit native default borders when an effective
edge is undeclared. Separate native research establishes thin black fallback
edges while preserving explicit empty and noFill declarations. That correction
and its measured cost remain separate from this checkpoint. Complete table and
whole-slide parity are not claimed.
