# Partial custom table styles — 2026-10-04

Resolved custom table styles now supply native black 1 pt borders when their
effective cardinal edges are absent. Explicit empty lines, `noFill`, unresolved
references and direct overrides retain their distinct behavior. Lectern's
32nd offline demonstration, Partial table styles, exercises the correction
through saved files, previews, inspection and export. Production integration
is `481586e`, with Sources tree `11ead6fd725008f26757f839abda10aa97761adb`.

The full local gate, native captures, fresh browser comparisons, external
package checks and both manual app workflows pass. Independent performance
review accepts the measured fidelity cost. Final independent integration review
passes. The [integration manifest](benchmarks/2026-10-04-partial-table-styles-integration-verification.json)
pins the evidence and retained verification history.

## Native evidence and implementation

The original two-page fixture has twelve specimens, 72 body glyphs, 15 fills
and 49 canonical border intervals. Before correction, only six intervals are
painted: 43 native default intervals are missing. Existing fill and glyph
positions already agree. The independent border model reproduces all 49
intervals with zero endpoint residual and agrees across the complete ordered
fill/stroke arrangement. No typography adjustment is introduced.

Fallback applies only when an actual custom definition is resolved from a
style part or an inline style. The resolver tracks declarations separately
from successfully resolved paint, preserving explicit empty wrappers and
unresolved references. It supplies missing cardinal defaults after regional
and neighboring declarations are resolved; direct cell properties are applied
last. Diagonals, unknown style IDs and synthesized built-in definitions do not
gain this fallback. Public effective-border reads see inherited black borders,
while authored cell-border reads and saved XML preserve absence.

The renderer additionally admits unmerged LTR joins whose opaque solid color
and width are constant along each grid line. This bounded extension follows
the existing uniform and axis-color admission paths and preserves ownership,
donor lookup and emission order. Other combinations, including uncaptured
collinear transitions, RTL/color combinations and merged color profiles, keep
their previous paths. The earlier axis-color cases retain their existing
admission; no broader table-parity claim follows.

Native interval tolerance is 0.001 pt and RGB tolerance is 0.0001 per channel.
Glyph x origins use 0.025 pt; native y origins use 0.121 pt for this fixture's
existing print-grid residual, whose maximum is approximately 0.120 pt. Painted
sizes use 0.002 pt. Actual source/subset font outlines and raw PDF matrices are
checked. Trace positions do not establish whole-slide raster equivalence.

## Lectern and end-to-end evidence

Both recipe options preserve the twelve reference specimens, master bindings
and original embedded font bytes on their first two pages. A third page
demonstrates four public controls: a referenced fill-only style, an empty edge,
an explicit `noFill` edge and a direct blue 4 pt left override with the right
edge suppressed. The alternative clears the direct left override, restoring
the inherited black 1 pt edge. Both variants pass 62 saved-file checks with
zero findings and three slides.

Both generated partial-style decks and both refreshed Table join profiles
decks open without repair in PowerPoint 16.113.3. Root exported local PDFs
using Best for printing with online export disabled, verified unchanged source
PPTX bytes and visually reviewed all twelve pages. The profiles refresh changes
only the third-page caption that previously named partial-style defaults as a
remaining gap. Public third pages are visually reviewed demonstrations;
numerical native acceptance remains scoped to the reference pages.

Fresh partial-style native and actual-inspector browser comparisons each pass
24 cases and 144 glyphs across four page comparisons. Complete opaque ordered
fill/stroke coverage, all glyphs and font identity pass. Negative controls
reject paint gaps, extra paint, changed colors, opacity and ordering; touching
identical subdivisions pass without losing order. Refreshed profiles each
pass 16 cases and 224 glyphs, retaining their stricter 0.025 pt bound in both
axes. The older paragraph/kerning (14 cases / 208 glyphs), markers (48 / 554,
with six explicit omissions), mixed-face spacing (24 / 192), alignment
(48 / 344) and table-default (24 / 144) browser regressions pass their existing
bounds using the new gate's captures.

Root completed both Run Demo → Inspect Result → Export Everything workflows
through native app controls. Each showed three loaded previews and a successful
three-slide export with no media or chart CSVs. All 41 source text nodes per
variant survive the scoped Markdown unescaping. All saved previews match the
app-gate previews exactly; comparison with raw library output requires only
the root viewport change. Source hashes recorded before inspection remain
unchanged after export and match the native capture inputs. The manual receipt
pins 38 files and the actual app binary. The observed creation times, 27.01 and
9.73 seconds, are UI observations rather than controlled measurements.

## Verification

The root library gate passes 1,189 tests in 173 suites; RostrumLayout passes
18 tests in three suites; LecternCore passes 302 tests in 46 suites. The app
gate passes 93 definitions in 28 suites, covering 130 executions. Both macOS
and iOS simulator builds explicitly succeed. README and four offline checks
pass. The xcresult has zero failures, expected failures, skips or runtime
warnings. Console output separately retains 13 clipboard-error, 270
preferences-daemon and 13 audio-component messages, DisplayLink notices and
compiler warnings. No contradictory exit-zero compiler failure appears.

All 32 catalog recipes pass 711 checks, retaining 413 findings describing other
support boundaries. Six separately retained pipeline executions pass another
338 checks: 1,049 checks across 38 reports. These are executions, not additional
recipes. External ZIP CRC, unique-member, XML and python-pptx validation reopens
88 presentations, 289 slides and 3,293 XML/relationship parts. All 462 checked
inputs remain unchanged. All 71 fixture files match the frozen source, and
21 generated/native input identities pass.

Of 70 prior packages, 63 are byte-identical. Four differ only in independently
validated comment/author UUIDs and timestamps; three contain the revised
profiles caption only. Of 40 prior special SVGs, 37 are exact. The table-default
public page gains exactly four black 1 pt lines from the corrected custom
fallback. Each profile variant's public page changes only its final caption
text and corresponding x position. Remaining XML is exact.

The initial worker compile error and invalid literal-prefix fixture lookup
remain retained. The corrected lookup resolves the namespace and requires
nonvacuous specimen/style counts. Focused and full worker checks were rerun,
followed by the independent root gate. Verification failures remain part of
the evidence history rather than being recast as passes.

## Performance and next work

The frozen comparison retains the accepted S18 Release baseline and freshly
builds only this production correction. Untimed preservation covers 187 cases,
883 slides and 561 fresh processes with external reopen checks. Nine cases
change 66 SVGs; all non-line/fill/text trees, saved packages, ordered issues and
inheritance records remain exact. Fourteen public-read files identify 24,295
logical cardinal defaults. Independent XML checks prove effective source
absence; eighteen counterfactual renders isolate those defaults and the
remaining join geometry. After inserting explicit fallback edges, 65 SVGs
retain join-only differences. The preceding unchanged and rejected controls,
101,310 shaping records and 1,728 layout records remain exact.

The single approved campaign completed all 594 children in 148.1358 seconds,
with no adaptive rerun. It uses one excluded warmup pair and ten alternating
retained pairs per workload, foregrounds 28 comparisons and retains all 306
measured phases, process RSS and host activity. The results show a material
fidelity cost: native rendering slows 8.188% (95% bootstrap interval +4.511%
to +10.315%); partial tables slow 11.369% (+9.045% to +13.116%) at 20×10,
14.392% (+11.427% to +16.104%) at 100×20, and 13.338% (+11.525% to +14.960%)
at 200×50. All four have ten of ten slower pairs. The largest partial table
adds 6.508 MiB of median peak process RSS and 998,010 SVG bytes.

Costs also affect unchanged controls: unresolved references slow 3.354%
(+2.274% to +4.982%) and rejected collinear transitions slow 0.652% (+0.157%
to +1.549%). The admitted grid-line profile slows 1.833% (+0.929% to +2.921%).
Canonical, Unicode and prior profile intervals cross zero. All 278 secondary
phases remain reported, including fifteen wholly positive and eight wholly
negative intervals. Sampled backup activity reaches 135.8%; these measurements
do not isolate allocations, explain all costs or establish universal
nonregression. Independent numerical/evidence review passes. The separate
[performance report](TABLE-CUSTOM-EDGES-PERFORMANCE-20261004-19.md) retains all
phase vectors, adverse controls and exact input/output provenance.

The next isolated optimization reuses decoded border paint for strongly owned
style-template nodes within one render. Untimed diagnostics establish repeated
work, and the output-preserving prototype passes independent source review.
Integrated verification and separate measurement against this corrected
baseline remain pending. Complete table and whole-slide parity remain ongoing
work.
