# Isolated slide-construction performance — 2026-10-02

Current integrated status: [October 2 implementation and verification](IMPLEMENTATION-20261002.md).
The checkpoint details below remain historical evidence.

Production commit **`6dd6eb6c14712bb40d22e9c92126fc93001ec424`** removes a
reproduced slide-construction regression without changing serialized output.
This work continues stage-three production `ca522e8be30dfff9ac4c5bc17b74d4128008c9e9`.
Its tools and evidence were committed separately as `7ea8818465cd678a3955638347814b0bdd56beec`
and **`b44ce0b974fa15a2074b37eeed286ec04fd7b669`** before this source change.
Those artifacts and the prior stage-two handoff remain unchanged.

## Reproduction and measured fix

The unchanged `rostrum-bench` driver runs fresh processes on the same Mac,
with Swift 6.4 release builds, no debug information, and two build jobs.
Builds and profiling finish before measurements. Every study excludes one
warmup pair and alternates measured AB/BA process order. Inputs are the same
slide-creation loop, geometry, multilingual text and run properties. Every
warmup and measured output must have identical saved-PPTX bytes and size.
Arial is used only by the separate post-render text-fitting phase; timed
rendering does not register fonts.

Fresh builds first reproduce the original regression from `e3fc99b` to
`2783ea3`: **112.919 → 315.574 ms**, or **2.795×**, for 1,000 slides.
All 12 pairs regress, with separated sample ranges. The 100-slide case rises
**5.026 → 7.601 ms**. The [historical reproduction](benchmarks/2026-10-02-stage4-historical-reproduction.json)
pins actual source, executable and output hashes instead of relying solely
on earlier declared revisions.

The [primary comparison](benchmarks/2026-10-02-stage4-matched-fix.json) measures
stage-three source against the fixed source, with 20 measured pairs per size:

| Construction | Stage three | Fixed | Median reduction |
| --- | ---: | ---: | ---: |
| 10 slides | 0.789 ms | 0.720 ms | 8.69% |
| 100 slides | 7.504 ms | 5.167 ms | 31.15% |
| 1,000 slides | 310.843 ms | 112.877 ms | **63.69%** |

The ten-slide ranges overlap. The 100- and 1,000-slide cases improve in all
20 pairs and their ranges do not overlap;
the latter are **307.197–323.487 versus 111.671–120.289 ms**.
A separate [12-pair replication](benchmarks/2026-10-02-stage4-replication.json)
measures **311.292 → 111.809 ms**, a **64.08%** reduction.
Both studies preserve exact PPTX output in every invocation.

A direct [12-pair comparison with the earlier fast revision](benchmarks/2026-10-02-stage4-recovered-vs-e3fc.json)
measures **111.133 ms historical versus 112.648 ms fixed**: the fixed median
remains **1.36% slower** (1.515 ms; slower in 10 of 12 pairs), with overlapping ranges. This establishes recovery
of most of the regression, not identical speed or a universal latency target.
All phases and unfavorable samples remain in the reports; no memory improvement
or cross-platform performance claim is made. Small unfavorable 1,000-slide
medians remain: initial save rises 0.97% (0.24% in replication), unchanged
save 0.50% (0.49%), and warm save 0.34% (0.24%). Text fitting rises 2.38%
(2.85%), only 14–17 microseconds. All non-construction phase ranges overlap;
these measurements do not establish causal regressions.

## Cause and bounded change

The section namespace/context changes introduced by `21f4227` and `ddd1545`
made each sectionless slide addition build namespace, inherited compatibility
context and parent maps over the growing presentation DOM before discovering
that no section extension exists. `Slides.add()` itself is unchanged across
the reproduced historical revisions. At 1,000 slides, the unnecessary scans
visit roughly 499,500 existing slide entries in aggregate.

A two-second [diagnostic profile](benchmarks/2026-10-02-stage4-construction-profile.json)
of a separately launched, owned 5,000-slide baseline process conserves all
1,165 main-thread snapshots. Namespace construction accounts for 781 (67.04%);
remaining section lookup/cleanup accounts for 23 (1.97%). These are mutually
exclusive categories. The combined section path is 804 (69.01%); nested
inclusive counts are not added. This partial larger-workload profile supports
attribution, not exact milliseconds or a percentage allocation of the separate
1,000-slide timing difference.

The fix adds a conservative direct-child preflight before namespace indexing
when section creation is not requested. It only returns early when no possible
`extLst → ext` with the exact section URI exists. Local-name matching admits
aliases, default namespaces and namespace lookalikes; every possible match
still uses the unchanged full validator. No absence is cached across calls.
Malformed/duplicate section structures still fail atomically, and inherited
XML/compatibility context remains protected. Existing slide ID and URI scans
remain; repeated slide addition is not claimed to have linear complexity.

Four new tests cover ten cases: aliased/default extension
containers, malformed and duplicate sections, opaque unrelated markup, and
sections installed later through the public DOM. Independent source review
found no blocking findings. The image lookup policy and renderer are unchanged.

## Exact-source validation

At production `6dd6eb6`:

- **930 library tests / 126 suites pass** in 36.198 seconds.
- **168 Lectern core tests / 15 suites pass** in 7.763 seconds.
- macOS app and hosted-test bundle **compile successfully**; hosted tests were
  not executed. iOS simulator app builds pass for arm64 and x86_64.
- [Preservation checks](benchmarks/2026-10-02-stage4-preservation.json) retain
  exact SVG and ordered diagnostics for eight first-slide cases (four with
  verified registered fonts), plus all 116 border/native-style fixture slides.
- The unchanged [native whole-slide gate](benchmarks/2026-10-02-stage4-native-comparison.json)
  is rerun and **fails at 18,082/840,000 pixels (2.152619%)**, versus the
  unchanged 0.5% limit and channel tolerance 16. SVG and corrected PNG remain
  byte-identical to stage three. No fidelity acceptance improvement is claimed.

Initial build/test failures are retained. The first historical reference build attempts had
an incorrect CLI flag and then a sandbox-denied default module cache; corrected
commands use isolated caches. The first core run could not trash its own
temporary fixture under the sandbox; the authorized rerun passes unchanged.
Initial app compiles hit sandboxed macro services, then null local package
resolution. Permitted runs with absolute cache paths and an explicit manifest
module cache resolve both local packages and pass. No production changes or
test weakening were used to obtain those passes. Linux and app-hosted runtime
validation remain unperformed.

## Provenance and handoff status

The [verification manifest](benchmarks/2026-10-02-stage4-verification.json)
pins source trees, raw logs, build commands, executables, samples, profiles,
representative PPTXs and reports. Extracted historical build sources were
checked against their Git blob identities. The runner rehashes actual source,
package, driver, executable, optional font and itself after each study. Retained
build logs and executed commands document linkage; file hashes alone cannot
independently infer which source produced an executable.

At **2026-10-02 05:32:16 UTC**, the original owner task still reports
`waitingOnApproval`. Its checkout remains `2783ea38616cfd7c30ad2358c1056b9dc3f19481`
with the same dirty documentation and untracked reports. That checkout, index,
branch, pending approval and PowerPoint session were not modified. No merge,
push, remote CI, PR or deployment was performed by this task, and no owner
integration is observed.

The stage-three incremental message was rejected twice by automatic approval
review: it requires direct end-user authorization for disclosing internal
repository paths/artifacts/results and did not accept the forwarded permission
record. A direct approval question is pending. The rejection receipt and
reviewable handoff artifacts are retained locally; no alternate delivery route
was attempted. The original task remains the sole integrator. Independent
Office typography capture and the existing fidelity acceptance gap remain open.
