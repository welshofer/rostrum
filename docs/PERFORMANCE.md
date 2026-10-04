# Performance measurements

The latest [October 4 comparison](INTEGRATED-LAYOUT-PERFORMANCE-20261004-4-UPSTREAM.md)
compares integrated source `2953dc1` with current-main baseline `6a1f56f`.
Large fallback rendering is **3.97% slower** and registered-table rendering
**2.51% slower**, each in nine of ten matched pairs, with about 2 MiB additional
peak process RSS. Substantial background load limits attribution. This is an
explicit fidelity tradeoff; performance recovery remains open. Inherited SVG
styling removes 2.03 MB versus the first unhoisted implementation while retaining
470,000 bytes over the large-table baseline. See the October 4 section below.

The historical [October 3 combined checkpoint](INTEGRATED-LAYOUT-PERFORMANCE-20261003-3.md)
measures **4.44% faster registered-font table rendering and 5.92% faster fitting**
against that pass's `5654d1b` baseline. Both improve in all ten matched pairs with
nonoverlapping observed ranges, including the new native-calibrated geometry.
Fallback rendering has overlapping ranges. Against the older `cf1b8a0` baseline,
registered rendering improves 5.94%; fitting's 3.73% lower median has overlapping
ranges and one slower pair. Fallback recovery remains unproven. These are local
workload results, with no general speed, memory or cross-platform claim.

The [isolated preserving change](LAYOUT-PERFORMANCE-20261003-3.md) measured larger
registered/fitting gains before the fidelity rules were integrated. It retains
three separately measured cycles and 628-slide output identity; those results
do not replace the combined checkpoint above.

The preceding [combined layout checkpoint](INTEGRATED-LAYOUT-PERFORMANCE-20261003.md)
finds **2.26% slower fallback table rendering and 3.01% slower rich-text fitting**
against `cf1b8a0`, with both slower in all ten matched pairs. Registered-font
table rendering is 0.75% faster with overlapping ranges; there is no meaningful
net speedup claim. One [bounded fast-path attempt](INTEGRATED-LAYOUT-PERFORMANCE-20261003-ATTEMPT.md)
failed to remove these regressions and was discarded. That October 3 pass
profiles and reduces common layout copying while separately measuring the
additional fidelity work.

The preceding isolated [ASCII break-opportunity scan](LAYOUT-PERFORMANCE-20261003-2.md)
measures 83.159 → 79.867 ms for registered-font 2,000-cell table rendering over
ten alternating fresh-process pairs (3.96%), with identical output across 580
slide renders. Smaller fitting/fallback changes have overlapping observed
ranges. This isolated result does not describe the combined tab-layout batch;
no broad speed, memory or cross-platform improvement is claimed.

The preceding [registered-font shaping pass](LAYOUT-PERFORMANCE-20261003.md)
measures 95.177 → 83.413 ms for 2,000-cell table rendering and 19.260 → 14.623 ms
for rich-text fitting over ten alternating fresh-process pairs. Skipping redundant
ASCII normalization improves these workloads by 12.36% and 24.08%, respectively,
with identical output across 576 slide renders. Fallback workloads show no
improvement; no memory or cross-platform speed claim is made.

The preceding [ASCII fallback layout pass](LAYOUT-PERFORMANCE-20261002.md)
measures 171.582 → 165.875 ms median large-table rendering over ten alternating
fresh-process pairs, with identical output across 574 slide renders. It establishes
a 3.33% median improvement on that workload, with no memory improvement. The
[preceding integrated checkpoint](FIDELITY-FOLLOWUP-20261002.md) and measurements
below remain historical evidence; their timings are not matched speedup baselines.

The initial measurements below are retained unchanged; see the follow-up section
for later renderer optimizations. Bulk table edits are substantially faster. The richer renderer remains slower
and whole-scenario peak memory is higher. Cold saves, image insertion and eager
opening show little change in this run; they are not advertised as speedups.

## Method

The [recorded samples](benchmarks/2026-10-01-macos.json) compare library baseline
`83c1f1962e017cc10726fa13f911bff9338c54c8` with final implementation
`e3fc99bc790d7d7c23ca2acacd8f5274d3bdf3cd`. The baseline already contains the
atomic-fill and annotation-duplication repairs; it predates the performance
changes. This is not a comparison against an unchanged release tag.

- Same arm64 Mac, macOS 27.0.1, Apple Swift 6.4
  (`swiftlang-6.4.0.34.1 clang-2100.3.34.1`), optimized release builds.
- One warmup and five measured fresh processes per scenario. The reported p95
  is the maximum of five samples, not a well-estimated population tail.
- Eight synthetic scenarios: 10/100/1,000 slides; 20×10, 100×20 and 200×50
  tables; 250 repeated and 250 unique images. Four existing foreign-producer
  decks were also exercised locally; this compact sample file retains only
  the synthetic scenarios. Their corpus hashes matched between runs.
- Both runs used `/System/Library/Fonts/Supplemental/Arial.ttf`. The final font
  SHA-256 is `525979822591a3447cfc49d943d6f7683508e25543407871c0ed8fed05fd2bd9`.
  The baseline driver did not record a font digest, so its byte identity cannot
  be independently established from that report.
  The benchmark registers this font only for the separate text-fitting phase,
  after rendering. The timed render phase does not register fonts.
- Every scenario output was reopened by python-pptx, including traversal of
  table cells. Synthetic PPTX hashes agree across all five repetitions and
  across the two revisions. That proves neither SVG equivalence nor Office
  visual conformance; see [CONFORMANCE.md](CONFORMANCE.md).

## Comparable phases

All values are milliseconds, shown as **median / observed p95**. These are
same-scenario comparisons. Rendering does more work in the final implementation:
rich text layout, authored image mappings and fidelity diagnostics.

| Scenario and phase | Baseline | Final |
| --- | ---: | ---: |
| 10,000-cell table: populate | 45.259 / 46.223 | 2.943 / 3.165 |
| 10,000-cell table: style | 89.533 / 90.085 | 16.369 / 17.031 |
| 10,000-cell table: render | 70.805 / 71.286 | 259.671 / 264.445 |
| 10,000-cell table: cold unchanged save | 18.678 / 19.038 | 18.425 / 19.882 |
| 10,000-cell table: edit one cell and save | 39.583 / 40.033 | 40.208 / 40.404 |
| 1,000 slides: traversal | 71.769 / 72.382 | 59.163 / 59.849 |
| 1,000 slides: eager reopen | 43.043 / 43.245 | 42.582 / 43.880 |
| 1,000 slides: cold unchanged save | 27.740 / 27.936 | 27.665 / 27.785 |
| 250 unique images: insertion | 29.171 / 29.893 | 29.188 / 30.501 |
| 250 unique images: import | 10.316 / 10.519 | 10.016 / 10.506 |
| 250 unique images: render | 1.426 / 1.438 | 3.827 / 4.002 |

Table population improved **15.4×**, styling **5.5×**, and 1,000-slide traversal
**1.21×** by median. Table rendering takes **3.67×** the baseline time; unique
image rendering takes **2.68×**. These regressions remain open. An intermediate
quadratic scan of accumulated SVG definitions was removed, reducing the
250-unique-image render from 12.61 ms to 3.83 ms, but not back to baseline.

The raw record includes minimum, maximum and relative spread for every phase.
Small absolute timings are noisy; the results do not support universal latency
targets or claims that every operation improved.

## New phases and memory

Warm saves reuse bounded cached compression. The 10,000-cell table's warm
unchanged save is **0.142 / 0.149 ms**, compared with its final cold unchanged
save of **18.425 / 19.882 ms**. The 1,000-slide warm save is
**13.887 / 14.074 ms**, versus cold **27.665 / 27.785 ms**. The baseline did not
record the separate warm phase. Neither comparison predicts a changed-part save.

For 1,000 slides, `OPCArchive` on-access open is **5.315 / 5.451 ms** and first
part access adds **1.603 / 1.660 ms**. This does less work than eager presentation
opening: payload validation/loading is deferred until access. Materializing an
editable `Presentation` still loads and validates the complete document.

Median process peak RSS increased from **175.08 to 199.12 MiB** for the large
table scenario, and **37.31 to 40.41 MiB** for 1,000 slides. These peaks cover
the entire sequential scenario, including rendering and the new lazy/cache
phases; they do not isolate opening or saving. Bounded caches and fewer archive
copies are architectural changes, not evidence of a net process-memory reduction.

## Reproduce and follow up

```sh
ROSTRUM_BENCH_FONT=/path/to/Arial.ttf python3 Tools/rostrum-bench/run.py --runs 5 --output /tmp/rostrum-bench.json
```

Profile rich table layout/diagnostics next, preserving their accuracy contract.
Collect phase-isolated memory measurements and Linux/iOS baselines before
setting regression thresholds. The new save/loading paths were executed on
macOS in this run; Linux runtime validation remains open. No runtime dependencies
were added to the Swift library.


## Renderer follow-up

[Raw follow-up samples](benchmarks/2026-10-01-render-followup.json) retain stage
commits, fixture/output hashes, selected sample indices and caveats. These are
warm renders in one optimized process, a different method from the fresh-process
scenario timings above; do not compare the absolute numbers across methods.

| Stage, same input/output within stage unless stated | Before median | After median |
| --- | ---: | ---: |
| Lazy diagnostic paths/image cache, 10,000 cells | 254.469 ms | 214.984 ms |
| Lazy diagnostic paths/image cache, 250 unique images | 3.372 ms | 2.577 ms |
| Bounded resolved-style cache, 10,000 No Grid cells | 271.578 ms | 216.420 ms |
| Bounded resolved-style cache, 10,000 Grid cells | 381.966 ms | 244.342 ms |
| Office border ownership, 10,000 No Grid cells | 211.565 ms | 207.397 ms |
| Office border ownership, 10,000 Grid cells | 233.825 ms | 225.452 ms |

The diagnostic-path baseline included profiling; its reported table median uses
the final five samples, so treat that percentage as directional. The style-cache
stage checks byte-identical SVG and ordered diagnostics across 888 native
style/flag cases plus large/custom merged tables. The border stage intentionally
changes SVG geometry to match Office ownership; its diagnostic hashes match.
Correcting the historical No Grid GUID and native color/style fidelity changes
render semantics, so a single cumulative speedup would be misleading.

At this checkpoint, resolved style templates are bounded per render (64 variants, approximately
1 MiB); media and diagnostic caches also live only for the current render.
They do not retain stale state across edits. No cross-platform speed claim or
net memory reduction is inferred from these warm render timings.


## October 1 integrated scenario run

[The complete final report](benchmarks/2026-10-01-final-macos.json) records
revision `2783ea38616cfd7c30ad2358c1056b9dc3f19481`, the same local Arial hash,
one warmup and five fresh-process samples for all 12 scenarios. Each output
reopened with python-pptx and table traversal. Every synthetic scenario repeats
an identical output hash. Non-table synthetic output hashes match the earlier
pass; table hashes change with the corrected No Grid GUID. Those table timings
measure the final behavior, not byte-identical work against the earlier pass.

| Final scenario / phase | Median / observed p95 |
| --- | ---: |
| 10,000 cells: populate | 2.785 / 2.838 ms |
| 10,000 cells: style | 15.467 / 16.895 ms |
| 10,000 cells: render | 217.752 / 219.974 ms |
| 10,000 cells: cold unchanged save | 19.262 / 20.589 ms |
| 10,000 cells: warm unchanged save | 0.145 / 0.151 ms |
| 1,000 slides: traversal | 58.923 / 59.365 ms |
| 1,000 slides: eager reopen | 41.556 / 42.594 ms |
| 250 unique images: render | 2.940 / 2.951 ms |

The earlier pass measured table rendering at 259.671 ms and unique-image
rendering at 3.827 ms. Final table peak process RSS is 199.375 MiB, essentially
unchanged from 199.12 MiB in that pass and still above the initial baseline's
175.08 MiB. The 1,000-slide scenario is 41.031 MiB. These results show renderer
latency improvement, not a return to the simpler baseline renderer's speed or
a process-memory reduction. Cross-platform performance and thresholds remain
open.

## October 2 matched follow-ups

The isolated follow-ups are integrated locally. Their source, executable,
input/output and log hashes remain in the linked records. These comparisons
use distinct methods and should not be combined into a single speedup figure.

- [Renderer work](ISOLATED-PERFORMANCE-20261002.md) removes repeated text-style
  serialization, paragraph DOM copying and numeric geometry round trips. Stage
  three's paired warm 10,000-cell renders improve from 161.549 to 141.646 ms
  for the banded table and from 146.847 to 131.870 ms for the grid table. Its
  fresh-process large-table scenario improves from 196.723 to 175.184 ms;
  peak RSS remains essentially unchanged (199.391 versus 199.5 MiB).
- [Image lookup](ISOLATED-FIDELITY-20261002.md) builds a bounded index only
  after sufficient measured work, retaining a cheap path for sparse/small
  relationship collections. The dense 2,000-image case improves from 22.449
  to 20.133 ms in its matched measurement. This is not a claim for every image
  workload.
- [Sectionless construction](ISOLATED-CONSTRUCTION-20261002.md) skips namespace
  and compatibility-context scans when no section extension can exist. The
  1,000-slide median falls from 310.843 to 112.877 ms (63.69%); an independent
  replication measures 311.292 to 111.809 ms. All paired saved outputs are
  byte-identical. Existing ID/URI scans remain, so construction is not claimed
  to have linear complexity.

The richer renderer remains slower than the historical simpler renderer. A
separate frozen-input historical comparison measures 70.893 versus 171.288 ms
(2.416×), with intentionally different output semantics. Neither the measured
improvements nor bounded caches establish lower whole-process memory or
cross-platform performance.


## October 2 final integrated scenario run

[The final report](benchmarks/2026-10-02-final-macos.json) measures combined code
`00a3231` after the table, line API, typography and diagnostics changes. The
[receipt](benchmarks/2026-10-02-final-verification.json) pins the source inputs,
release executable, driver and logs. No build or test jobs ran concurrently.
The same Mac/compiler/font and fresh-process method were used: one warmup plus
five measured repetitions, all 12 outputs independently reopened by python-pptx.
All five saved hashes agree in each scenario; all eight synthetic hashes match
the October 1 final checkpoint. This verifies saved PPTX determinism, not SVG
identity or whole-slide equivalence.

| Scenario / phase | Median / observed p95 |
| --- | ---: |
| 10,000 cells: populate | 2.823 / 2.870 ms |
| 10,000 cells: style | 15.550 / 16.324 ms |
| 10,000 cells: render | 169.529 / 174.626 ms |
| 10,000 cells: cold unchanged save | 18.293 / 18.491 ms |
| 10,000 cells: warm unchanged save | 0.139 / 0.159 ms |
| 1,000 slides: construction | 111.517 / 113.304 ms |
| 1,000 slides: traversal | 58.675 / 60.286 ms |
| 1,000 slides: eager reopen | 41.614 / 41.828 ms |
| 250 unique images: render | 2.954 / 3.064 ms |

The table render median is 22.15% below the previous integrated checkpoint's
217.752 ms, with a 3.95% observed min-to-max spread in the final samples. This
comparison spans correctness changes and is not a claim of identical renderer
semantics. Unique-image rendering is essentially unchanged from 2.940 ms.
The richer table renderer remains about 2.39 times the initial 70.805-ms
baseline. Median table process peak RSS is 199.578 MiB versus 199.375 MiB at the
previous checkpoint; 1,000-slide RSS is 41.0 MiB. There is no measured net memory
reduction. The current style cache retains at most 36 templates and approximately
1 MiB per render. Linux/iOS timings and regression thresholds remain open.


## October 4 native Latin fidelity tradeoff

The [latest matched comparison](INTEGRATED-LAYOUT-PERFORMANCE-20261004-4-UPSTREAM.md)
uses fresh current-main `6a1f56f` and integrated source `2953dc1`. It does **not**
establish performance recovery: large fallback rendering is 3.97% slower and
registered-table rendering 2.51% slower in the observed run; both are slower in
nine of ten pairs. Median process RSS increases by 2.01 and 2.23 MiB respectively.
Substantial variable Time Machine and WindowServer load limits attribution, and
the directional results remain explicit. No general or clean-host speedup,
lower-memory or cross-platform performance claim is made.

The native Latin policy fixes independently measured PowerPoint wrap boundaries.
Its first implementation repeated 2.5 MB of SVG style markup in the large-table
fixture. Inherited styling removes exactly 2.03 MB of that addition while
preserving effective policy and geometry, leaving 470,000 bytes over baseline.
The final pipeline keeps that bounded fidelity cost visible. The fallback-only
optimization and earlier failed experiment remain documented separately;
PERF-1 fallback recovery and clean-host confirmation remain open.
