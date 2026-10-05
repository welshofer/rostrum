# Live table-cell fitting integration — 2026-10-04

Fitting a retained table-cell text frame now resolves its live text styles and
properties without constructing a complete grid or resolving discarded paint
styles. Built-in text definitions are generated from the same 74-style catalog;
custom definitions retain their existing normalization and precedence. Every fit
reads current cell identity, padding, anchor, direction, style and theme. There
is no persistent mutable cache or new public API, and stored text bodies remain
unchanged.

The source/performance evidence is independently accepted at `3a03ba8`, after
the full local gate passes at source `2e57a2d`. The
[integration receipt](benchmarks/2026-10-04-cell-fitting-integration-verification.json)
pins the gate, fresh external/WebKit proof, source identity transfers and current
acceptance wording. Earlier checkpoints and measured packets remain unchanged.

## Automated and actual app coverage

The full `./scripts/verify.sh` gate passes 1,155 Rostrum tests in 164 suites,
18 layout tests in three suites, 286 Core tests in 40 suites, offline checks,
README examples, macOS/iOS simulator builds and 81 app tests in 22 suites.
The composed/decomposed Unicode Fonts and fitting test is now part of this whole
gate, including both width options through real inspector/export. This supersedes
the preceding checkpoint's separate 80-test gate plus one focused test without
rewriting that earlier result.

The app run comprises 112 executions, with no failures, expected failures, skips
or xcresult runtime warnings. Five exact quiet-build exit-zero messages remain
in the log (three macOS, two iOS), alongside seven app-host WebContent clipboard
console lines containing `error:`. Separate serial nonquiet macOS and iOS
confirmations return zero and explicitly report `BUILD SUCCEEDED`, with no
`error:` lines. Source is unchanged between the gate and acceptance-only docs.

The existing table-appearance Lab continues to exercise a retained frame across
live padding/style/anchor changes, full-size table context, computed fit results,
unchanged document bytes, save/reopen and actual inspector/export. The ignored
stored-scale diagnostic and refusal of unverified nonzero line reduction remain.
No new recipe or UI change is required to expose this implementation change.

Independent external checks pass 387 checks across all 26 recipes, retaining
411 findings. All 313 inputs remain unchanged during verification; 60 ZIP
CRC/python-pptx reopens cover 225 slides and 1,683 XML/relationship parts.
Special paragraph/table packages and SVGs match the preceding checkpoint exactly.
Four general Lab PPTX files differ in authored comment UUIDs/timestamps; the
reviewer's XML projection verifies all remaining attributes, text and children.
Those four files are not claimed byte-identical or used to transfer native
acceptance. Fresh WebKit PDFs pass 14 cases / 208 glyphs at the original bounds:
12 paragraph specimens / 188 glyphs from exact saved inspector previews, and
2 separately scoped raw-library kerning specimens / 20 glyphs.

Root also completed both table-appearance workflows manually using the exact
built app: Library Lab Run Demo → Inspect Result → native folder export.
Each showed 20 checks, three slides and seven findings, then exported three
slides with zero media files or chart CSVs. Both inspectors exposed three
previews and two limitations; the default specimen was visually checked with
two complete lines. Exported Markdown retains the exact cell text and stored
scale, and both source packages remain unchanged.

The manual slide-three XML equals the verified gate. Manual inspector SVGs use
a 640×360 root viewport and the raw gate SVGs use 1280×720; replacing only that
root dimension pair yields exact equality, including every descendant and the
viewBox. Raw SVG and whole-package identity are not claimed. The first default
export action encountered a closed automation pipe; resetting the automation
connection recovered the existing panel and export completed while Lectern
remained alive. That recovery and the initial cross-viewport identity assertion
remain in the manual receipt.

## Native evidence and scope

Prior independent PowerPoint evidence transfers only through exact accepted
PPTX/SVG inputs: 188 paragraph glyphs, 32 spacing markers, 24 empty-line markers
and 30 cell glyphs on page three of each table variant. The original source-font
outline/raw-matrix checks and tolerances remain unchanged. This checkpoint
adds fresh WebKit captures and manual table workflows; it does not relabel the
earlier PowerPoint captures as new native operations.

Other current manual Lectern demonstrations remain pending. The separate new 18-case
bullet PDF has been captured, but its proposed engine correction is future work
and is not accepted by this checkpoint. Automated inspector/export tests and
bounded native specimen checks do not establish whole-deck raster parity or
PowerPoint-selected autofit. No merge or deployment is claimed.

## Measured retained-cell fitting benefit

The [reviewed performance report](CELL-FITTING-PERFORMANCE-20261004-13.md)
retains one frozen matched run, all raw pairs, source/generator pins and exact
output checks. Paired fitting medians improve 61.90%, 64.59% and 71.05% for
10×10, 40×25 and 200×50 retained built-in cells; inline-style 40×25 cells improve
22.30%. Each has 10/10 faster pairs. Frame acquisition and serialization occur
outside these fitting timers; their costs are not represented by those gains.

Canonical rendering/rich-text fitting intervals are wide and leave substantial
regression risk unresolved. Separate cell-rendering controls also retain possible
costs. Whole-process RSS is mixed, including a small increase for inline styles;
no general memory reduction is claimed. WindowServer and changing backup load
limit inference. Identity lookup still has quadratic worst-case comparisons when
fitting every cell, and cell acquisition still builds full snapshots.

Preservation covers 134 cases / 824 slides, all 12,100 cell results per variant,
435 independent reopens, 101,310 shaping records and 1,728 reflected layout/DOM
records. The 74 built-ins × 128 flags × six positions are checked against full
resolution, alongside live mutation and malformed-cell edge cases. These results
support the bounded retained-cell fitting change, not historical cumulative
recovery, universal nonregression or cross-platform performance.
