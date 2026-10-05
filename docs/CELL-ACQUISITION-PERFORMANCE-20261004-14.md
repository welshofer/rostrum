# Indexed table-cell acquisition

**Streaming lookup improves all four acquisition controls in this matched run. Rendering and fitting controls remain inconclusive; no end-to-end table-rendering or historical recovery claim follows.** Source equivalence, statistics, preservation and final evidence review passed for the bounded acquisition result.

Baseline is accepted perf13 source 308f20d/evidence e5bd107, Sources tree 1fed769a7817b8da2c1381828dd6db5e364f0e81. Candidate source/tests commit d64ddb31e7790b002bcfa819059ed657deb1a527 has Sources tree de42aa5fb48da53f255a5864a9a707c38a704528. The candidate was built from frozen source, then committed unchanged before timing. The original plan SHA256 301bbc76431cb21fa170edef9daecccdcc3edd5f6f84aded1cc0e059c77c58d8 is preserved; a separate mapping receipt records the commit and adjusts only the orchestration preflight HEAD check. Measured binaries, commands, order and timers did not change.

A fresh accepted-baseline acquisition profile counts main-thread samples 2,833/2,956/2,916 for 10×10/40×25/200×50 tables. Table.cell accounts for 2,432/2,864/2,908 inclusive samples; full-grid materialization accounts for 1,894/2,125/2,107 (66.9%/71.9%/72.3% of main-thread samples). These nested categories are attribution, not predicted savings; GUI/review/background work could overlap profiling. The profile driver consumes cell text separately and confirms unchanged saved bytes.

The candidate visits live a:tr children until the requested row, then live a:tc children until the requested column, returning the original element with the same owner/part/package. It stops without allocating a complete TableGridSnapshot or scanning other rows' cells. Exact negative/out-of-bounds errors, qualified-name filtering, ragged physical cells beyond declared columns, aliases and fresh mutable-XML behavior remain unchanged. No persistent cache, new public API, font policy or geometry change is introduced. Lookup still scans preceding rows and cells; this is not constant-time random access or a universal complexity claim.

The frozen protocol ran once: 264 fresh child processes, ten alternating retained pairs plus one excluded warmup per workload. Canonical 110 and existing supplementary 66 are unchanged. Separate acquisition 88 measures 10,000 row-major lookups for each table size and 1,000 last-cell requests for the large table. Input loading, dimensions, font registration, capacity reservation and returned-cell text consumption are outside the acquisition timer; each TableCell construction/append is inside. Every cell contains unique text, so selecting a wrong cell cannot pass the output proof. A genuine SVG render has its own timer. Prior perf13 retained-frame fitting timers excluded acquisition and are neither modified nor used for this claim.

All processes succeeded in **77.51 seconds** (exact 77.50994004204404), without adaptive reruns. Acquisition results:

| Workload/phase | Baseline→candidate ms | Ratio of medians Δ | Paired median Δ [95% interval] | Faster pairs | RSS Δ MiB |
|---|---:|---:|---:|---:|---:|
| 10×10 / 10,000 lookups | 23.7045→0.7429 | -96.87% | -96.84% [-96.92, -96.79] | 10/10 | -0.023 |
| 40×25 / 10,000 lookups | 142.9096→1.1825 | -99.17% | -99.18% [-99.19, -99.12] | 10/10 | -0.125 |
| 200×50 / 10,000 lookups | 1067.8362→3.3451 | -99.69% | -99.69% [-99.70, -99.68] | 10/10 | -0.0625 |
| 200×50 last cell / 1,000 lookups | 107.8619→0.5763 | -99.47% | -99.47% [-99.48, -99.44] | 10/10 | -0.047 |

All four acquisition controls have 10/10 faster pairs, exact two-sided sign-test p=.001953125. The 200×50 control's 10,000 calls decrease from 1,067.8362 to 3.3451 ms; the last-cell control avoids relying only on early-exit cells. These percentages describe the explicitly timed acquisition loops, not arbitrary table operations. Whole-process RSS medians differ by −0.023/−0.125/−0.0625/−0.047 MiB, respectively; this includes retained wrappers/text, DOM, rendering, serialization and allocator behavior, so it does not isolate lookup allocations or establish general lower memory.

Canonical and existing supplementary controls:

| Workload/phase | Baseline→candidate ms | Ratio of medians Δ | Paired median Δ [95% interval] | Faster pairs | RSS Δ MiB |
|---|---:|---:|---:|---:|---:|
| Fallback 200×50 render | 181.2696→181.2787 | +0.00% | -0.20% [-0.78, +1.02] | 6/10 | -0.031 |
| Fallback 20×10 render | 3.6317→3.6077 | -0.66% | -0.11% [-7.94, +0.84] | 5/10 | +0.023 |
| Registered 100×20 render | 62.1784→62.0948 | -0.13% | -0.10% [-1.14, +1.27] | 5/10 | +0.047 |
| Rich text render | 2.4502→2.4211 | -1.19% | +0.24% [-3.22, +2.14] | 4/10 | -0.141 |
| Rich text fitting | 9.2624→9.2148 | -0.51% | +0.23% [-3.35, +3.10] | 5/10 | -0.141 |
| Ten slides render | 0.5234→0.5183 | -0.97% | -1.13% [-3.18, +0.68] | 7/10 | -0.141 |
| Accented/CJK render | 117.4775→117.6322 | +0.13% | -0.33% [-1.25, +0.87] | 6/10 | -0.281 |
| Mixed RTL render | 119.9973→119.7764 | -0.18% | +0.15% [-0.95, +0.58] | 4/10 | -0.375 |
| Long combining render | 392.0817→384.9747 | -1.81% | -2.41% [-4.37, +0.90] | 7/10 | +0.000 |

Every interval crosses zero. Registered rendering is −0.097% [−1.135,+1.268]; rich-text fitting is +0.231% [−3.350,+3.103]. Possible regression remains within these bounds. Unrelated combining variation is not attributed to lookup. No canonical/fitting gain or universal nonregression is claimed.

Separate render phases from acquisition controls:

| Workload/phase | Baseline→candidate ms | Ratio of medians Δ | Paired median Δ [95% interval] | Faster pairs | RSS Δ MiB |
|---|---:|---:|---:|---:|---:|
| 10×10 / 10,000 lookups | 4.1485→4.1477 | -0.02% | -1.12% [-1.99, +0.54] | 7/10 | -0.023 |
| 40×25 / 10,000 lookups | 24.7005→24.5391 | -0.65% | -0.77% [-2.79, +0.49] | 7/10 | -0.125 |
| 200×50 / 10,000 lookups | 276.3490→276.7072 | +0.13% | -0.07% [-1.10, +0.60] | 5/10 | -0.0625 |
| 200×50 last cell / 1,000 lookups | 277.3820→276.0820 | -0.47% | -0.24% [-0.87, +0.63] | 6/10 | -0.047 |

These intervals also cross zero. Render and acquisition rows for a given workload share whole-process RSS. Negative runtime deltas favor the candidate. Ratios of separate medians and medians of paired ratios are reported separately. Intervals use 100,000 deterministic bootstrap pair resamples (seed 20261004); exact two-sided sign tests exclude ties. These exploratory results are not multiplicity-adjusted and cannot remove shared-load bias.

Nine process snapshots retain pool names and timestamps. Run start/end are 2026-10-04T14:01:12.773881−07:00 and 14:02:30.234957−07:00. WindowServer ranges 13.7–26.3%; backupd, Photos and Spotlight are 0% in these samples. Root/worker build/test/GUI jobs were paused, but this is not a clean-host guarantee; snapshots cannot prove continuous isolation. No system settings or user processes were changed.

Preservation passes against the retained baseline: 134 cases/824 slides, baseline plus two candidate outputs, exact SVG/ordered diagnostics/inheritance flags/saved packages; unchanged small/large/image-heavy checks verify part payloads, deterministic saves and reopened SVGs. Four acquisition controls preserve 31,000 returned-cell text records per variant, SVG/diagnostics/saved bytes; 972 exact mutation/error records cover 12 states ×81 queries, both sides twice. Independent python-pptx reopens total 435 (417 main, 6 preservation, 12 acquisition). Standalone shaping 101,310 records and reflected layout/DOM 1,728 records remain identical. The manifest verifies 7,896 retained artifact hashes in addition to input and primary pins.

Focused tests cover negative/extreme bounds and exact errors; missing/short grids, ragged physical cells, comments/text/unknown siblings and qualified-name changes; original node/owner identity; row/column insertion, reordering, merge/unmerge, direct replacement and aliases, retained frames and serialized reopen. The differential helper additionally checks renamed rows/cells and empty tables. Read-only lookup preserves DOM bytes and dirty state. Full swift test --jobs 2 passes 1,158 tests/165 suites plus 18 layout tests/3 suites; Release build 53.37s and git diff --check pass. Two scratch proof harness compile errors (an internal helper call and actor annotation) were corrected before proofs/timing; their logs are retained. Production source was unchanged by those corrections.

Evidence: [canonical raw](benchmarks/2026-10-04-cell-acquisition-layout-14-paired-macos.json), [supplementary raw](benchmarks/2026-10-04-cell-acquisition-layout-14-supplement-paired-macos.json), [acquisition raw](benchmarks/2026-10-04-cell-acquisition-layout-14-acquisition-paired-macos.json), [host context](benchmarks/2026-10-04-cell-acquisition-layout-14-host-load.json), [output proof](benchmarks/2026-10-04-cell-acquisition-layout-14-output-proof.json), [acquisition proof](benchmarks/2026-10-04-cell-acquisition-layout-14-acquisition-proof.json), and [verification manifest](benchmarks/2026-10-04-cell-acquisition-layout-14-verification.json). Physical binaries/modules/profiles/proof artifacts remain in .build/perf24-cell-acquisition. Prior checkpoints are unchanged; root owns full integrated Lectern/native/GUI gates.
