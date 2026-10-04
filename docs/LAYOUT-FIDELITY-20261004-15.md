# Text alignment and rendering performance — 2026-10-04

This checkpoint adds native-backed center/right alignment coverage, the 28th
offline Lectern demonstration, and two independently measured performance
improvements. It does not change the alignment algorithm: the 24 new specimens
already pass. The separate mixed-face spacing correction belongs to checkpoint 16.

The complete local gate passes with production source `6377ccd` and library
Sources tree `ae809cfa6235d67eea2b505acc0973ac7fe1ac25`. Later commits in this
checkpoint record evidence only. The [integration manifest](benchmarks/2026-10-04-alignment-integration-verification.json)
pins source, tests, native captures, external reopens and manual workflows.

## Native text alignment and Lectern

The four native pages contain 24 cases and 172 visible glyphs: fractional center
and right alignment, trailing spaces, hard breaks, asymmetric insets, wrapping,
scaled kerning thresholds, actual bold/serif faces and table cells. First-glyph
origins retain the strict 0.025 pt bound, other x coordinates 0.06 pt, baselines
0.121 pt and paint/ink dimensions 0.002 pt. Exact source font outlines establish
face identity. Table cells retain and report their ignored stored font scale.

The Text alignment demo preserves the entire specimen bodies, frames and master
bindings. Captions outside those frames use bundled DejaVu Sans for offline
preview consistency; complete source-slide XML byte identity is not claimed.
A fifth page authors the same text with both public fitting APIs. Its alternative
changes center to right alignment. Each option passes 60 checks with two expected
table-scale findings. Computed fitting is distinct from PowerPoint-selected
autofit and is excluded from numerical native acceptance.

Both generated five-slide decks opened in PowerPoint 16.113.3 without repair.
Local Best for printing export was selected with online export off, and source
PPTX bytes remained unchanged. Fresh independent extraction of the first four
pages verifies 48 cases / 344 glyphs across both options. Native x, baseline,
paint scale and source-outline ink dimensions match the original reference
exactly. Root visually inspected all ten exported pages.

Fresh WebKit vector captures independently pass 48 alignment cases / 344 glyphs,
48 marker cases / 554 glyphs with six recorded omissions, and 14 paragraph/kerning
cases / 208 glyphs. Alignment and marker captures use the exact saved inspector
SVG bytes; the existing raw kerning control stays explicitly raw-library scoped.
All source, reference, actual font and before/after hashes pass. Browser/SVG
coordinates keep the 0.025 pt bound; native bounds remain unchanged.

Root completed both real workflows: Run Demo, Inspect Result and Export
Everything through the native folder picker. Each showed five loaded previews
and a five-slide export. All 64 source text nodes per option survive extraction;
the recipe and manual Markdown exports match exactly. Source hashes taken before
inspection remain unchanged through export and match the captured native decks.
All ten manual SVGs match the app-gate saved previews exactly. The first four
raw-library pages per option differ only in viewport dimensions. The authored
fifth page's three precisely identified empty border text nodes have a separate
fallback-font baseline difference, explicitly bounded by the app test; painted
content is not omitted or normalized.

## Verification and performance

`scripts/verify.sh` passes: 1,170 Rostrum tests / 169 suites, 18 RostrumLayout
tests / three suites, 290 LecternCore tests / 42 suites, offline checks, README
examples, macOS and iOS simulator builds, and 85 app test definitions / 24 suites
covering 118 executions. The xcresult has zero failures, expected failures,
skips or runtime warnings. Nine WebContent clipboard error lines are retained
in the successful app-host log. Shell output-directory variables did not propagate
through the Xcode test scheme; fresh browser captures were audited at their
actual default paths without rerunning or substituting earlier evidence.

All 28 Lab reports pass 505 checks and retain 413 findings. Independent ZIP CRC,
unique-member, XML and python-pptx validation reopens 60 packages / 214 slides /
1,866 XML and relationship parts. All 345 inputs remain unchanged. The prior
27 recipes preserve package bytes except four comment packages: their only
differences are valid, consistently mapped author/comment UUIDs and timestamps.
Every other node, attribute, part and payload remains exact. Both alignment and
marker option packages match their independently captured native inputs.

The [ordinary inheritance performance report](RENDER-INHERITANCE-PERFORMANCE-20261004-15.md)
records 9.09–18.12% lower paired rendering medians across four ordinary 200-shape
controls, each faster in all ten pairs. Defaults are reused only within one SVG
render, with entry and deferred cleanup; live DOM edits remain visible on the
next render. Large fallback rendering retains an unresolved +1.50% result with
an interval spanning −0.08% to +13.04%. Other controls and mixed memory results
do not establish universal nonregression or cumulative recovery.

The separate [Lectern marker performance report](LECTERN-MARKER-PERFORMANCE-20261004-15.md)
measures one parse per rendered page instead of one parse per specimen. Complete
headless runs improve from roughly 2.06 s to 1.01 s, with paired reductions of
51.02% and 50.88% and all ten pairs faster for both options. Paired peak whole-process
RSS is 67.648 MiB lower. Every generated artifact and non-timing report field
matches within its option. These frozen binaries exclude the inheritance change;
the experiments cannot be added together. Both reports retain uncontrolled
background load, all outcomes and their original evidence.

## Observed next gap

This is text-geometry acceptance, not whole-slide visual parity. The manual
walkthrough exposed a separate table appearance defect: four cells with no
applied table style appear pale-filled with white borders in Lectern, while
PowerPoint paints no cell fill and black borders. The renderer resolves the
table-style list's insertion default as an applied style. A native discriminator
corpus is being prepared before changing that behavior. Existing evidence and
the known mismatch remain visible; no complete table-fidelity claim is made.
