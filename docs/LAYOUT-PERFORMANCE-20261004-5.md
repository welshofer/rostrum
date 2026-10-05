# PERF-1: recent text-style reuse (2026-10-04)

The bounded cycle-one change reduced observed large-fallback render time **3.75%** and registered-table render time **2.26%** against fresh baseline `59efb229c94f484666c9dd2a7e0ea7044f54f94b`. Both workloads were faster in all ten alternating pairs. All checked SVG, ordered diagnostics, inheritance metadata and saved PPTX bytes remained identical. The parent accepted this increment subject to independent evidence review; no further implementation cycle or retiming was run.

These are current-baseline observations under substantial variable host load. They do **not** establish complete recovery of earlier regressions, a clean-host/general/cross-platform speedup, or lower memory.

## Profile and change

The retained Release render-loop profiles sampled five seconds at 1 ms intervals. Text-attribute lookup accounted for 125/3,569 main-thread samples in the large fallback case and 111/3,689 in the registered case. Most were at the existing dictionary-hit lookup (106 and 104 samples respectively). These inclusive attribution counts locate work; they are not timing measurements. The profile also retained layout, shaping and font-resolution costs; this change targets only the shared text-attribute lookup.

Source commit: `5a4cebfd84392c058474c7bd1a2473c052a7eced`. Only `RenderTextAttributes.swift` and its focused tests changed. A single recent-entry lookaside compares the existing exact key before hashing it. Dictionary hits retain the dictionary's canonical stored key/value; new entries enter the lookaside only after the existing 128-entry / 65,536-byte admission checks. Refused entries are not retained, and reset clears the lookaside. No DOM, layout, font-resolution, arithmetic or diagnostic policy changed.

Tests cover repeated and revisited style variants, inherited ligature context, byte-distinct Unicode aliases, exhausted admission, oversized values and reset readmission. Existing reused-renderer mutation and per-shape diagnostic tests also passed.

## Matched measurement

| Workload / phase | Baseline median ms | Candidate median ms | Change | Faster pairs |
|---|---:|---:|---:|---:|
| Large fallback render | 193.0468 | 185.8117 | -3.75% | 10/10 |
| Small fallback render | 3.7498 | 3.7422 | -0.20% | 4/10 |
| Registered table render | 79.2009 | 77.4137 | -2.26% | 10/10 |
| Rich fitting | 14.4866 | 14.3436 | -0.99% | 5/10 |
| Fitted text render | 3.3685 | 3.3682 | -0.01% | 6/10 |
| Ten-slide first render | 0.5965 | 0.5938 | -0.46% | 5/10 |

Large fallback median paired change was **−3.47%**, with a 95% percentile-bootstrap interval **[−4.74%, −1.99%]**. Registered table was **−2.34%**, interval **[−4.74%, −1.34%]**. Both exact two-sided sign tests give p=0.001953125. All pair deltas are retained; bootstrap uses 100,000 resamples and seed 20261004. These exploratory ten-pair estimates are not corrected across workloads and cannot remove load bias. Smaller workloads and fitting have intervals crossing zero; fitting does not execute the changed SVG attribute path.

Median peak RSS changed **180.8125 → 180.9531 MiB (+0.1406)** for large fallback and **54.6484 → 54.6016 MiB (−0.0469)** for registered tables. These whole-process peaks do not demonstrate an allocation or memory improvement.

Root explicitly granted the window after both lanes paused; source review had no findings. The unchanged canonical runner completed 110 fresh processes (one excluded warmup pair and ten retained pairs per five workloads), 100 retained samples, in **24.28 seconds**. The window was released immediately. At start/during/end, backupd used **124.9% / 22.8% / 124.5% CPU**, and WindowServer **76.6% / 78.2% / 76.2%**; helper was 0.0%. No external compiler/build/test was observed. These snapshots are not continuous isolation monitoring. No settings were changed.

Baseline and candidate retained matching Release objects/modules and used the identical canonical driver, `swiftc -swift-version 6 -O`, Apple Swift 6.4 (swiftlang-6.4.0.34.1), and the same hash-pinned Arial font. Both were built with `swift build -c release --jobs 2`. The raw runner records base revision 59efb22 because the candidate was measured as a frozen two-file patch before its green source commit; the manifest pins the measured binary, patch and source/test hashes to the commit above.

```sh
ROSTRUM_BENCH_FONT=/System/Library/Fonts/Supplemental/Arial.ttf python3 Tools/rostrum-bench/run.py --binary .build/perf14-profile/candidate-extended-bench --paired-binary .build/perf14-profile/baseline-extended-bench --paired-revision 59efb229c94f484666c9dd2a7e0ea7044f54f94b --runs 10 --warmups 1 --scenarios table-200x50 table-20x10 shaped-table-100x20 richtext-fit slides-10 --output docs/benchmarks/2026-10-04-recent-style-layout-5-paired-macos.json
```

## Correctness and retained evidence

Focused tests: 6 passed. Full `swift test --jobs 2`: **1,113 Rostrum tests / 154 suites and 18 RostrumLayout tests / 3 suites passed**. Release baseline/candidate builds passed. Exact output identity passed **94 current-corpus cases / 742 slides** across fallback and registered modes, with 188 independent python-pptx reopens. Five fixed workloads / 14 slides matched baseline and repeated candidate with 30 reopens. Required small, large and image-heavy preservation passed decoded payloads, deterministic saves, reopened SVGs and cross-version artifacts, with six further reopens: **224 local reopens total**. Source hashes and diff checks passed. Root owns the subsequent integrated app/native/full gate.

All evidence is retained under `.build/perf14-profile/`. See the [verification manifest](benchmarks/2026-10-04-recent-style-layout-5-verification.json), [raw timing](benchmarks/2026-10-04-recent-style-layout-5-paired-macos.json), [paired analysis](benchmarks/2026-10-04-recent-style-layout-5-paired-analysis.json), [summary](benchmarks/2026-10-04-recent-style-layout-5-summary.json), [full corpus identity](benchmarks/2026-10-04-recent-style-layout-5-output-identity.json), [fixed workload proof](benchmarks/2026-10-04-recent-style-layout-5-output-proof.json), and [preservation](benchmarks/2026-10-04-recent-style-layout-5-preservation.json). Earlier failed, pre-reconciliation and upstream tradeoff receipts remain unchanged and are not substituted for this baseline.
