# Reuse decoded table border paint — 2026-10-04

This pass removes repeated border decoding within a table render while requiring
the complete rendered output to stay identical. The integrated source checkpoint
is `5d3d888`, Sources tree `6d2e7cd2d2c057d4c9b916358882695cbe2c66d7`.
Platform and end-to-end checks pass. Independent numerical and preservation
review accepts the frozen performance experiment within its measured scope.

## Repeated work and bounded reuse

The preceding partial-style correction paints missing native borders correctly,
with measured costs of approximately 11–14% on partial-style table workloads.
Its evidence remains in the [S19 report](LAYOUT-FIDELITY-20261004-19.md).

`TableStyleResolver.RenderSession` already retains a bounded set of style
templates. Repeated cell edges reference the same immutable descendants, but
the renderer previously decoded their color, width, dash and supported line
properties on every encounter. Untimed instrumentation of a 200×50 table finds
40,250 border calls, including 20,000 nil diagonals. Shared-style controls
perform 20,250 nonnil decodes for only 84 distinct line nodes. The prototype
reduces those decodes to 84; unique direct-border controls still decode all
20,250 distinct nodes. These counts establish repeated work, not elapsed-time
or allocation savings.

The render session now registers border identities only when their owning
templates enter its existing estimated 1 MiB budget. It reserves an additional
estimated 512 bytes per admitted edge for bookkeeping and decoded paint.
The per-table paint map retains each XML owner and its optional decoded value,
including explicit no-paint results, with a hard 216-entry ceiling. Direct
overlays and unadmitted templates bypass insertion. Every returned nonnil
paint still contributes to maximum-border-width checks.

Both maps live within the current render operation. Public resolution and
fitting remain live; style, theme, alias and direct-cell edits are observed on
the next render. Ownership, border geometry, paint order, text layout and saved
XML are unchanged. Estimated storage accounting is not an allocator measurement.

## Source review and preservation

Independent source review covers retained owner identity, cached nil values,
bounded admission, budget exhaustion, oversized XML and live edits. The
prototype branch omitted an earlier ordinary-text inheritance optimization;
its review explicitly records that scope. Root integrated the table changes
onto accepted S19 with the earlier optimization intact. Formal benchmark
baseline and candidate pins match those integrated source trees exactly.

The prototype's first test run contained an invalid assumption that different
authored packages should have identical diagnostic locations. Materializing
unsupported style declarations into every cell legitimately changes those
locations. The corrected tests compare each actual input across reopen and
repeat rendering; the separate baseline/candidate proof uses identical input
bytes and exact ordered diagnostics. Failed and corrected logs remain retained.

Formal untimed preservation passes 190 cases and 886 slides in 570 fresh
baseline/candidate processes and external reopens. Every complete SVG, saved
package, ordered issue list and inheritance report is identical. No SVG
normalization or border counterfactual is needed for this change. Fixed small,
large-table and image-heavy controls also pass; 101,310 shaping records and
1,728 layout records remain exact.

## Lectern and platform checks

All 32 existing demonstrations exercise the same renderer. A focused app test
now runs both Cell appearance options through the real inspector and export,
checking all three saved previews against actual and fresh inspector output.
It also verifies custom-style reuse/remapping, exported content and unchanged
on-disk source bytes. Both parameter executions pass in the isolated worker
app build. An initial invocation selected zero tests; its log and xcresult
remain explicitly unaccepted, followed by the corrected selector and two
successful executions.

Root's complete gate passes 1,193 library tests in 174 suites, 18 layout tests
in three suites, 302 Lectern Core tests in 46 suites, and 94 app test definitions
in 28 suites. The app gate records 132 total test executions with no failures,
expected failures, skips or runtime warnings. macOS and iOS builds, four offline
checks and the README snippet checks pass. Environment diagnostics remain retained in the raw
log rather than being discarded.

Fresh browser captures pass 198 cases and 1,810 glyphs across 37 PDFs, retaining
six explicit marker omissions and all existing native and browser tolerances.
The complete input packages and SVGs match the previous accepted pass exactly,
so its native PowerPoint evidence transfers by input identity. This pass does
not claim new native exports or expand the supported table profiles.

External checks reopen 88 packages containing 289 slides and 3,293 XML parts;
84 packages are byte-identical to S19 and four differ only in comment UUIDs
and timestamps. All 236 SVG pairs are exact. The 32 demonstration reports and
six pipeline reports pass 1,049 checks, preserving their 413 reported findings.

Root visibly ran both Cell appearance options, inspected all three slides in
each, and completed Export Everything through its native folder picker. Both
runs pass 20 recipe checks with seven known findings; all six saved previews
match separate headless public-recipe outputs and both source packages remain
unchanged after export. The manual receipt records 32 pins and 27 exported text
nodes per option. This exercise also confirms an existing export omission:
the valid image shared by direct and table-style fills stays intact in the PPTX
but is absent from the exported folder, whose summary reports zero media. The
omission predates this renderer change and is recorded for the next export fix.

## Frozen performance plan

The approved finite plan retains all 594 S19 child processes and adds 66 for
three controls: unique direct borders at 200×50, partial template-budget
admission at 20×10 and oversized-template bypass at 6×6. It has 660 children,
31 primary comparisons and 339 measured phases. Each workload uses one excluded
warmup pair and ten alternating retained fresh-process pairs. Existing drivers,
font registration, original-render scope and all earlier workloads stay fixed.

An untimed audit of the actual render session confirms 40 shared and 760
unshared border encounters with 24 distinct admitted identities for the
near-budget control. Unique direct and oversized controls have no shared
encounters. This tests partial and complete template-budget rejection; it does
not claim to saturate the separate 216-entry paint map.

All 660 authorized child processes completed in one campaign, with all four
pools exiting successfully, in 187.26740933401743 seconds by the completion
receipt. All phases, adverse controls, process RSS and host activity are
retained without adaptive reruns. Percentages from successive experiments
cannot be added into a cumulative recovery claim.

## Measured gains and costs

The independently accepted paired median render deltas for partial-style
tables are −8.995% at 20×10, −15.599% at 100×20
and −14.438% at 200×50, with all ten retained pairs faster for each workload.
Their 95% bootstrap intervals are [−9.790%, −7.130%], [−17.625%, −14.886%] and
[−15.641%, −13.864%]. Separate baseline and candidate medians for the largest
case are 189.2138 and 161.6303 ms. These are measurements against the retained
accepted S19 Release products, with integrated S20 source equivalence verified
before the campaign.

The axis-color direct-border control slows +0.947% [+0.566%, +1.747%], with all
ten pairs slower. Four other unchanged controls have positive bootstrap
intervals but only eight of ten slower pairs; both statistical summaries are
retained. Unique direct borders, partial budget admission, oversized bypass
and canonical workloads have intervals crossing zero, including adverse upper
bounds. The result establishes a target-workload improvement, not universal
nonregression.

Median peak-process RSS deltas span −1.266 to +0.242 MiB, and do not isolate
cache allocation. Sampled WindowServer activity was 39.1–43.6% and backupd
60.0–146.2%, despite pausing agent builds, tests and GUI work. All 339 phase
comparisons, including sixteen positive and fifteen negative secondary
intervals, remain available in the [performance report](TABLE-PAINT-REUSE-PERFORMANCE-20261004-20.md).
The largest partial-style SVG remains 6,424,314 bytes on both builds.

Final independent integration review approves the assembled evidence. Its 633
source pins enumerate production Sources, Lectern, scripts, workflow files and
the new paint-reuse tests; this is a scoped source inventory, not a complete
repository count or the same denominator as S19. Native fixtures and historical
receipts are preserved separately in the [integration manifest](benchmarks/2026-10-04-table-paint-reuse-integration-verification.json).
