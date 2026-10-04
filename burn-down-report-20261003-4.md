# Fidelity and performance pass 4

Status: scoped fidelity implementation and full local verification delivered to
draft [PR #39](https://github.com/welshofer/rostrum/pull/39). Performance recovery
remains open; observed costs are explicit. Final-head hosted status is tracked
in the [PR checks](https://github.com/welshofer/rostrum/pull/39/checks). No merge
to main or deployment.

## Scope and baseline

Continues PERF-1 and the bounded native typography portion of FUNC-2/FUNC-3 from
`lift-up-plan-20261001.md`. Animation remains excluded. Prior PR 33 was externally
merged as e94ff88. The branch first updated to a9d870b, then incorporated
6a1f56f (PR 38) as merge 2953dc1 when main advanced during verification. Each
performance report names its actual baseline; earlier numbers are not treated
as measurements of later merged source.

## Result

| Item | Delivered behavior | Source commits |
| --- | --- | --- |
| PERF-1 | Skip unused fallback base-style resolution; inherit identical SVG ligature policy within a text block/line | 2d49cec, f8b33ee |
| FUNC-2/FUNC-3 | Native separate-letter Latin wrapping, measurement, fitting and SVG for bounded LTR ASCII paragraphs | a31f120 |
| Lectern | Fourth paragraph slide, two native widths, both fitting APIs, saved/reopen, inspector and export coverage | 645fd8e |
| Integration | Snapshot import respects injected diagnostics; recovery test owns temporary storage across restart | 5860a71 |
| Upstream reconciliation | Retain automatic-number font and missing-font adjacency fixes together with inherited styling | 2953dc1 |

Standalone TextShaper keeps its public defaults. No external runtime dependency
or invented OOXML ligature switch was introduced. Existing warnings and native
geometry tolerances remain intact. Twenty-three new native cases require no
warnings; the unstyled hard-break case retains its exact unresolved-face warning.

## Evidence and limits

The independently authored, embedded-font PowerPoint matrix contains 24 cases.
The old a9d870b layout failed 62 assertions. PowerPoint 16.113.3 accepted the corrected
fixture without repair; local Best for printing PDF capture verifies complete
text consumption, source glyph outlines and horizontal span geometry. A synthetic
bold inheritance mistake in the initial table specimen was caught and corrected
before acceptance. The 175-case prior boundary oracle now checks its former
office-word geometry limitation as well.

Lectern keeps 26 recipes and adds a fourth paragraph slide: the 49.74/49.76 pt
officeZ boundary and fixed 39.01 pt mixed 18/12 pt row. Both fitting APIs compute
77.5% for the demonstrated boxes. Those scales are Rostrum choices, not a claim
about native autofit. Both saved specimens open in PowerPoint without repair;
PDF text confirms all six boxes per variant. Manual rebuilt Lectern checks
cover edited title, both widths, four thumbnails, retained results and Export
Everything. After SVG reconciliation, regenerated deck bytes match those earlier
manually exported specimens exactly.

At f8b33ee the complete local gate passed: 4 offline checks, 1,107 Rostrum tests,
18 layout tests, 277 Core tests, README examples, macOS and both iOS simulator
architectures, and 76 native app tests with zero failures/skips. Supplemental
headless testing reports 76 tests with 3 native WebKit exclusions covered by the
native gate. All 26 Lab pipelines pass 337 checks; 52 PPTX files pass ZIP integrity
and independent python-pptx reopening. The later upstream integration passed the
same gate, as recorded below.

Performance records retain failed experiments and tradeoffs:

- The first ordered-lookup experiment showed no reliable gain and was not shipped.
- The fallback-only change preserved 734 slides across 92 fixture/font combinations;
  the observed roughly 2% large-table gain was under substantial background load.
- Initial combined SVG repeated 2.5 MB of policy markup and showed 19.37 MiB extra
  large-table RSS; this version was rejected for shipping.
- Hoisting removed 2,030,000 bytes (81.2% of added markup). Four native slides and
  all benchmark artifacts retain exact geometry/effective-policy, diagnostics and
  saved-byte equivalence. The final f8b33ee run still showed about 2 MiB additional
  RSS and a directional 2.46% registered-render slowdown under load. Large-table
  recovery was unproven. These results are a bounded fidelity tradeoff, not a net
  speed or memory improvement claim.

The final current-main comparison uses fresh baseline 6a1f56f and integrated
source 2953dc1. It measures large fallback rendering at 188.8149 → 196.3060 ms
(+3.97%) and registered rendering at 77.2920 → 79.2300 ms (+2.51%), both slower
in nine of ten pairs. Residual peak RSS is +2.0078/+2.2344 MiB respectively.
Time Machine and WindowServer were active; paired uncertainty/load limitations
are retained rather than used to dismiss the directional regressions. The exact
SVG saving remains, but no net speedup or memory reduction is claimed. This is
accepted as a bounded fidelity tradeoff in a draft PR; PERF-1 recovery stays open.

At merged source 2953dc1, the full gate passes again: 1,109 Rostrum tests in
154 suites, 18 layout tests, 277 Core tests, 76 native app tests with zero skips,
README and macOS/iOS builds. Headless tests, 337 Lab checks and 52 external
reopens pass. Four paragraph SVGs and both saved variants are byte-identical
across the merge. The benchmark's ten-slide SVGs retain main's intentional
viewer-flow correction; no false premerge SVG identity is claimed.

Records: [fidelity](docs/LAYOUT-FIDELITY-20261004-4.md),
[latest performance](docs/INTEGRATED-LAYOUT-PERFORMANCE-20261004-4-UPSTREAM.md),
[latest integration receipt](docs/benchmarks/2026-10-04-fidelity4-merged-integration-verification.json).
Root independently verified 58 pre-reconciliation, 341 reconciled-checkpoint and
254 latest-main primary evidence hashes, with exact native projection reruns.
Worker verification additionally checks the fresh baseline sources and output
artifacts against receipts. Historical results retain their original scope.

## Routing and review

Four slots: root integration, isolated performance/fonts worktree, native/tables
worktree, and Lectern/metadata worktree, with source writes serialized where they
overlap. Requested implementation routing was gpt-6-astra/high and independent
review routing gpt-6.1-sol/high; runtime identities are unattested. Independent
read-only review approved the fallback, native policy, Lectern, isolation fix,
SVG inheritance source/tests and both-parent upstream merge. Root rechecked the
cited source, retained evidence hashes and complete native SVG projections.
Historical worker artifacts were preserved and excluded from commits.

The first full gate stalled in a pre-existing recovery test that enumerated the
real Documents library. It was interrupted, fixed with existing injected storage
seams, and rerun green. The optional local HTML viewer was not executed after a
browser file-URL security rejection; no alternative route bypassed that block.
Native app and PowerPoint acceptance were completed through their normal paths.

Remaining scope: broader fonts/scripts and raster parity, native-selected autofit,
existing hard-break/complex-script limitations, clean-host performance confirmation,
and further fallback performance recovery. No animation, release, deployment or
App Store submission is included. No separate lint gate is configured;
`git diff --check` is the whitespace gate.


## Burn-down — 20261004, fourth layout pass

Delivered to draft [PR #39](https://github.com/welshofer/rostrum/pull/39), against
main, without merging to main or deploying. The [compact report](burn-down-report-20261003-4.md)
contains the full acceptance scope and retained limitations. Final-head hosted
status is recorded in the [PR checks](https://github.com/welshofer/rostrum/pull/39/checks);
it is separate from the completed local gates below.

Requested routing used gpt-6-astra/high for implementation and gpt-6.1-sol/high
for independent read-only review; runtime identities are unattested. Four slots
separated root integration, fonts/performance, tables/native, and metadata/Lectern
worktrees. Overlapping source writes were serialized. Source, both-parent merge,
native evidence, paired arithmetic and final report received independent review.

| Item | Status | Source commit | Accepted proof |
| --- | --- | --- | --- |
| PERF-1, fallback base-style work | Implemented; performance recovery remains open | 2d49cec | FallbackBaseMetricsTests and 734 preserving-stage slides |
| FUNC-2/FUNC-3, native Latin policy | Bounded fidelity increment delivered | a31f120 | 24 native cases, 175 prior boundary cases, consistent fitting and SVG |
| PERF-1, inherited SVG policy | Implemented; residual costs documented | f8b33ee | Exact effective policy/geometry; 2,030,000 redundant bytes removed versus first implementation |
| Lectern demonstration and E2E | Delivered | 645fd8e | Fourth paragraph slide, two widths, both fitting APIs, 31 saved-file checks and actual inspector/export |
| Test isolation | Delivered | 5860a71 | Injected diagnostics across recovery/restart; native app gate passes |
| Current-main integration | Verified | 2953dc1 | Both-parent review, full gate and paragraph artifact identity |

At checkpoint `2953dc1`, the integrated tree passes 1,109 Rostrum tests, 18 layout tests, 277 Core
tests and 76 native app tests with zero failures/skips, plus README samples and
macOS/iOS builds (arm64 and x86_64 simulator). The separate headless run reports
76 tests with three native WebKit exclusions covered by the native gate. All 26
Lab recipes pass 337 checks, and 52 decks pass ZIP integrity and independent
reopening. Both saved paragraph variants opened in PowerPoint without repair;
local PDF geometry and actual rebuilt Lectern inspection/export were checked.

The [latest integration receipt](docs/benchmarks/2026-10-04-fidelity4-merged-integration-verification.json)
pins source 2953dc1 and all checks. The [current-main performance report](docs/INTEGRATED-LAYOUT-PERFORMANCE-20261004-4-UPSTREAM.md)
compares fresh 6a1f56f with that source: large fallback +3.97%, registered render
+2.51%, and +2.01/+2.23 MiB RSS, with nine of ten slower pairs for each render.
Background load limits attribution; it does not erase these observed costs.
This is accepted as a bounded fidelity tradeoff, not performance recovery.
Root verified 254 latest primary evidence hashes; baseline-source and retained
artifact checks are separately labeled in the evidence.

Broader fonts/scripts, raster parity, native-selected autofit, existing complex
script/hard-break limits, and fallback performance recovery remain open. Earlier
rejected experiments and initial integration failures remain documented. The
optional file-URL viewer was security-blocked and no workaround was attempted.
Animation, release, deployment and App Store submission remain outside this pass.


### Final preview-fallback reconciliation

Main advanced again to `40f28e5` with an explicit preview fallback font. Merge
`a47d94b` preserves that measured/drawn family together with the inherited
ligature policy. Independent review compared both parents and approved. The
fresh full gate passes 1,111 Rostrum, 18 layout, 277 Core and 76 native app tests
(zero native failures/skips), README samples, and macOS/iOS builds. All 26 Lab
recipes now pass 339 checks; the two additions belong to upstream's fallback
demo. All 52 decks reopen independently. Four paragraph SVGs and both saved
width variants remain byte-identical to the native-accepted checkpoints.
See the [final integration receipt](docs/benchmarks/2026-10-04-fidelity4-preview-fallback-integration-verification.json).
The earlier supplemental headless run and timing evidence retain their exact
source scope; this later merge was not retimed. Performance recovery stays open.

Linux Swift 6.0/6.1 and macOS CI passed at the first published head `e1650ae`;
final-head build status is tracked on PR #39 after this merge. GitGuardian's
four findings all identify the same verified source-file SHA-256 checksum,
not a credential. Its incident #37859419 requires authenticated dismissal;
the security check remains visible and monitoring has not been disabled.
No merge to main or deployment occurred.

## Continued empty-line fidelity and shaping performance — October 4

The subsequent [integration report](docs/LAYOUT-FIDELITY-20261004-5.md) records
native empty-line metric ownership, the fifth Lectern paragraph slide, and three
separately measured optimizations. At `a98dd69`, the full local gate passes
1,123 library, 18 layout, 279 Core and 76 native app tests. Four known native
exact/percentage-spacing assertions remain visible. All 348 Lab checks and 54
independent reopens pass. Both manual app variants pass 40 checks with no preview
findings and export five slides. Native geometry and output-preservation evidence
are pinned in the [receipt](docs/benchmarks/2026-10-04-empty-lines-shaping-integration-verification.json).

This remains an ongoing draft PR. Exact/percentage spacing calibration and the
next allocation experiment continue; no general fidelity or cumulative historical
performance claim is made.

## Continued explicit-spacing fidelity and allocation performance — October 4

The [explicit-spacing integration report](docs/LAYOUT-FIDELITY-20261004-6.md)
records 103 strict native cases, removal of the four earlier known-issue
assertions, six-slide Lectern demonstrations for both options, and the accepted
singleton scalar-storage optimization. At `d338c42`, the full gate passes
1,133 library, 18 layout, 281 Core and 76 native app tests with no known issues.
All 362 Lab checks and 56 independent reopens pass. Both manual app variants
pass 54 checks without preview findings and export six slides. Native geometry
and all source/data pins are in the
[receipt](docs/benchmarks/2026-10-04-explicit-spacing-integration-verification.json).
The scalar-storage result is workload-specific; its possible small combining
cost and mixed RSS remain disclosed. Glyph reservation and painted glyph-size
research continue in separate experiments. No merge or deployment occurred.

## Continued glyph allocation performance — October 4

The [glyph-reservation integration report](docs/LAYOUT-FIDELITY-20261004-7.md)
records the exact normalized emitting-scalar capacity change and its bounded
registered-rendering median improvement of 1.59%. Fitting is inconclusive and
whole-process RSS is mixed. At `051cf5b`, the full gate passes 1,136 library,
18 layout, 281 Core and 76 native app tests, with no known issues or native
failures/skips. All 362 Lab checks and 56 independent reopens pass. Both final
paragraph decks exactly match the prior PowerPoint-accepted specimens; the
rebuilt app inspector/export tests pass. Prior native/manual evidence is
transferred by source identity, without claiming a fresh manual capture.
The [receipt](docs/benchmarks/2026-10-04-glyph-capacity-integration-verification.json)
pins the source and 302 unchanged external inputs. Glyph paint/placement and
duplicate-break research continue. No merge or deployment occurred.
