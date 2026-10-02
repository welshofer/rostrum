# Performance measurements — 2026-10-01

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

Resolved style templates are bounded per render (64 variants, approximately
1 MiB); media and diagnostic caches also live only for the current render.
They do not retain stale state across edits. No cross-platform speed claim or
net memory reduction is inferred from these warm render timings.


## Final integrated scenario run

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
