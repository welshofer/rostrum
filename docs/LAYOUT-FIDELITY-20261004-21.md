# Native table border transitions — 2026-10-04

This pass corrects collinear color and width transitions in unmerged LTR table
borders. The reviewed implementation is `89aa163`, based on integrated S20
`5d3d888`. Root integrated it with Lectern at `33e484e`, Sources tree
`d555de4fa405e9c03217ebb966125a360cdd7f78`. The complete root gate, browser/native
numerical comparisons and both manual Lectern workflows pass. Comparative
performance analysis and final integration evidence pass independent review.
The experiment establishes no speedup or nonregression claim.

## Native evidence and bounded admission

Two independently authored decks contain fourteen cases on four pages: vertical
and horizontal transitions in both directions, outer and interior junctions,
suppressed perpendicular donors, and multiple transitions on both axes. Root
opened both exact sources in PowerPoint 16.113.3 without repair and exported
local PDFs using Best for printing with online conversion disabled. PowerPoint
did not save either PPTX. All four captured pages were visually inspected.

The native corpus contains 240 body glyphs, 115 distinct border intervals and
1,131 ordered overlap regions. Thirteen cases are admitted, covering 107
intervals and 1,081 regions. A colored merged case stays on its exact previous
rendering path; agreement of an offline model with that one example does not
establish combined color-and-merge support.

The existing signed donor-extension rule matches these native transitions.
The production change therefore removes obsolete color-profile scans from the
unmerged LTR admission branch. It preserves physical ownership, perpendicular
donor lookup, signed extensions and the four border paint groups. Existing
topology, rectangular-grid, positive-dimension, maximum-stroke, opaque-solid
and no-diagonal guards remain in force. Uniform borders, colored RTL, colored
merges, mixed merge orientations, dashes, translucency and compound borders
retain their previous paths.

Strict before-change tests fail 101 interval assertions and twelve complete
ordered-paint comparisons. They pass after the admission change. The earlier
harness also reported fourteen detached-XML namespace differences; that log is
retained separately, and the corrected geometry failure is the accepted
before-change result.

## What is checked

The committed fixtures retain complete native PDF path order, raw operators,
stroke coordinates, colors, widths, opacity and glyph traces. Ordered paint is
compared over the full subdivision induced by stroke boundaries, rather than
checking only unordered line unions. The actual embedded DejaVu Sans subset
outlines and units per em match the pinned source font.

Interval tolerance is 0.001 pt and raw RGB tolerance is 0.0001. Body glyph
limits are 0.025 pt horizontally, 0.121 pt vertically and 0.002 pt for painted
size; observed maxima are 0.008301, 0.080078 and 0.00000191 pt respectively.
Complete original SVG text nodes and font bytes remain identical. Earlier
native bounds remain unchanged. These measurements establish vector and glyph
trace behavior within this scope, not universal raster or whole-slide parity.

The focused gate passes seventeen tests in four suites. The complete worker
gate passes 1,195 library tests in 175 suites and eighteen layout tests in three
suites. A seven-input, 29-artifact comparison preserves all prior S17–19 native
outputs exactly. Only border-line primitives change in four SVGs from the new
transition sources; packages, ordered diagnostics, text, fonts, fills and
container structure remain exact. The excluded merged specimen remains exact.

Independent source review verifies all 52 changed Git blobs, 45 fixture pins,
the failed and passing logs, native intervals and glyphs, ordered paint, and
output preservation. It approves the bounded source change; the separate root
integration checks below cover the app, generated references and manual exports.

## Lectern and integration

Lectern's 33rd demonstration exposes the native specimens on four pages and a
public authoring control on a fifth, with the excluded combined profile
explicitly identified. Both options pass 68 checks with zero findings. The
worker Core gate passes 306 tests in 47 suites, and the catalog passes 779
checks while retaining 413 existing findings. A targeted actual app test passes
both parameter executions, checking five saved previews against the inspector,
export and source purity. Its initial missing-try compile failure and a catalog
test's missing new ID are retained with their corrections.

Both generated decks have their own local PowerPoint PDF captures because their
bytes differ from the original fixtures. Root opened both without repair,
selected Best for printing with online conversion off, and inspected all ten
pages. Every original table graphic frame, first-four-page text and obfuscated
font-part byte remains exact. A preflight helper initially compared package font
bytes with the decoded TTF hash; that incorrect comparison and the corrected
raw-byte identity check remain separate. No production or package change was
needed. Independent numerical acceptance passes both generated PDFs: 28 table
cases and 480 body glyphs, including 26 admitted native border cases. The two
merged controls retain strict glyph checks and exact fallback SVG behavior;
their borders are excluded from native acceptance. The fifth public control
page is visually inspected, outside native numerical acceptance.

Fresh inspector browser captures pass eight new PDFs, 28 cases and 480 glyphs
at the same strict bounds. All 37 prior PDFs also pass, preserving their exact
PPTX/SVG inputs. Combined browser coverage is 45 PDFs, 226 cases, 2,290 visible
glyphs and six explicit prior omissions. One positive and nine negative parser
and paint controls pass. Initial generated-native exclusion-parser and browser
descriptor-count mistakes remain retained with their corrected helpers and
receipts; no tolerance or input was adjusted to obtain acceptance.

The root completion gate passes 1,195 library tests, eighteen layout tests,
306 Core tests and 96 app test definitions / 135 total executions. macOS and
iOS simulator builds, four offline checks and the separate README check pass.
The app result has zero failed, expected-failure or skipped tests and zero
xcresult runtime warnings. Console preference, pasteboard, audio and compiler
warnings remain in the complete log and audit; those are separate measures.

External verification reopens 96 packages, containing 320 slides and 3,752 XML
parts, and validates 1,253 checks across 41 reports. The catalog retains 413
existing findings. All 236 prior SVG files are byte-identical; 84 of 88 prior
packages are exact and the other four differ only in expected comment IDs and
timestamps. All 118 frozen fixture files and 504 generated input files remain
unchanged.

Root ran both options through the actual Library Lab, inspected all five loaded
previews and completed Export Everything through the native folder picker.
Each run passes 68 checks with zero findings and exports five slides. All 82
source text nodes are preserved in each export. Saved previews match the
app-hosted gate exactly; raw recipe SVGs differ only by the root viewport size.
Each source PPTX remains unchanged through inspection and export and matches
its separately captured native source. The UI's 3.52 and 12.62 second creation
readouts are observed workflow timings, not comparative benchmark results.

## Performance experiment

The frozen performance preparation retains S20 as the baseline and all 660
existing child processes. Four additional inputs add 88 processes: the two native
decks and dense vertical/horizontal transition controls. The total is 748
children, 35 primary comparisons and all 383 measured phases. Untimed proof
passes 194 cases / 892 slides through 582 fresh processes and external reopens.
Five cases change seven SVGs only in border endpoints and ordering, with complete
non-line content, line paint attributes, packages and ordered diagnostics exact.
The old rejected-collinear-transition input becomes explicitly admitted rather
than being mislabeled unchanged. All 748 children completed once across five
successful pools in 205.06 seconds, with builds and owned verification UI idle.
All 35 primary paired confidence intervals include zero. Dense horizontal
transitions measure +1.326% [−0.002%, +2.817%], with three of ten pairs faster;
the adverse upper bound remains unresolved. Dense vertical transitions measure
+0.410% [−1.492%, +1.381%]. All 383 measured comparisons and whole-process RSS
remain in the [independently reviewed performance report](TABLE-TRANSITIONS-PERFORMANCE-20261004-21.md).
Background backup and window-server activity limits generalization. This is a
verified fidelity improvement with uncertain comparative cost, not an accepted
speedup or nonregression result.

The [accepted integration manifest](benchmarks/2026-10-04-table-transitions-integration-verification.json)
retains the final independent review, original draft histories, capture and
manual receipts, and accepted performance evidence. Its 685 source pins are an
explicitly scoped inventory of Sources, Lectern, scripts and relevant tests and
fixtures; they are not a complete repository count or a denominator comparable
to earlier passes.
