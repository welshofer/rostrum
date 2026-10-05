# Integrated layout checkpoint — PRE-RECONCILIATION (2026-10-04)

This candidate is **not accepted as the final combined result**. The large fallback workload's observed median render time fell 1.35%, but its paired uncertainty includes no improvement. Its SVG grew by 2,500,000 bytes and median whole-process peak RSS rose by 19.37 MiB. The parent requested reconciliation of the repeated ligature-policy markup before shipping. This checkpoint preserves the measurements and output evidence; a replacement candidate requires a fresh build, proof, and explicitly authorized timing window.

The receipt filenames contain “final-combined” because that was the planned run before this cost was discovered. They now identify this supersedable pre-reconciliation source only. Raw samples and prior isolated performance evidence remain unchanged.

## Source and measurement boundary

Baseline: `a9d870b9f8145a40e76fd48998606da796e3e32d`. Worker candidate: `2a4c1b31fbd367deb14cbb45a9728450bba6215a`, including performance source integrated as `2d49cec` and typography source `3af4554`. It matches root `5860a71ebc2b15f626b5e04b1f072de130cbd9d3` at the complete Sources tree `a8393245a53e199f98afd678e3b8a3efb88600c9`. No production source was edited during this measurement pass.

Retained scratch: `.build/perf11-combined/` in the fonts worktree. Apple Swift 6.4 (swiftlang-6.4.0.34.1), arm64 macOS; the identical canonical driver and Arial font are hash-pinned. Release build completed. Candidate extended-driver SHA256: `a9d94b14d37f3d91196172ea7460ef4d408735e7264d322985ad4252b214aedd`.

A preparation error initially combined the candidate object with the retained baseline Swift module. It was caught **before authoritative timing**. That binary and its preliminary proof are retained under `preflight-baseline-module/`, excluded from accepted proof and all timed samples. The candidate was recompiled with its matching module, then all output/preservation checks reran. The driver compilation used the same canonical source path and flags as the baseline:

```sh
swift build -c release --jobs 2
swiftc -swift-version 6 -O -I .build/perf11-combined/candidate-module Tools/rostrum-bench/main.swift .build/perf11-combined/candidate-Rostrum.o -o .build/perf11-combined/candidate-extended-bench
ROSTRUM_BENCH_FONT=/System/Library/Fonts/Supplemental/Arial.ttf python3 Tools/rostrum-bench/run.py --binary .build/perf11-combined/candidate-extended-bench --paired-binary .build/perf11-combined/baseline-extended-bench --paired-revision a9d870b9f8145a40e76fd48998606da796e3e32d --runs 10 --warmups 1 --scenarios table-200x50 table-20x10 shaped-table-100x20 richtext-fit slides-10 --output docs/benchmarks/2026-10-04-final-combined-layout-4-paired-macos.json
```

The canonical runner was unchanged; the unused scratch output-aware runner was not used. Five workloads × (one excluded warmup pair + ten retained alternating pairs) × two variants produced 110 fresh processes and 100 retained samples. Saved PPTX equality met the original runner's requirement.

Root explicitly granted the window after its checks and manual GUI acceptance, with other lanes paused. Start/during/end snapshots were 06:00:03.519 / 06:00:18.401 / 06:00:35.902 PDT. Timing finished within 60 seconds and the window was released immediately. Backup processes showed 0.0% CPU at all three snapshots; WindowServer showed 80.6% / 75.0% / 75.4%. No external compiler/build/test was observed. This is a measurement under ongoing WindowServer load, not a clean-host speed claim; snapshots cannot establish continuous isolation. No system settings were changed.

## Timing and memory

Negative time deltas mean faster. Ratios of medians and medians of paired ratios are different statistics.

| Workload / phase | Baseline median ms | Candidate median ms | Ratio of medians | Faster pairs |
|---|---:|---:|---:|---:|
| Fallback table 200×50 / render | 188.9995 | 186.4458 | −1.35% | 7/10 |
| Fallback table 20×10 / render | 3.8171 | 3.7191 | −2.57% | 8/10 |
| Registered table 100×20 / render | 76.6261 | 76.7791 | +0.20% | 5/10 |
| Rich text / fitting | 14.3013 | 14.2443 | −0.40% | 5/10 |
| Fitted rich text / render | 3.3936 | 3.4316 | +1.12% | 2/10 |
| Ten-slide deck / first render | 0.5842 | 0.6005 | +2.80% | 5/10 |

| Phase | Median paired delta | Bootstrap 95% interval | Exact two-sided sign p |
|---|---:|---:|---:|
| Large fallback render | −2.36% | [−4.91%, +1.31%] | 0.34375 |
| Small fallback render | −2.47% | [−4.07%, −0.83%] | 0.109375 |
| Registered table render | +0.03% | [−1.02%, +1.25%] | 1 |
| Rich text fitting | −0.11% | [−1.64%, +1.66%] | 1 |
| Fitted text render | +2.82% | [+0.11%, +5.14%] | 0.109375 |
| Ten-slide first render | +0.21% | [−3.14%, +11.86%] | 1 |

The paired-analysis receipt retains every pair delta. Intervals use 100,000 percentile bootstrap resamples, seed 20261004; the sign test excludes ties. These are exploratory ten-pair estimates without multiple-workload correction. Neither method eliminates background-load bias. The primary large-fallback gain is unconfirmed; the fitted-text render observations also warrant retaining the full record rather than selecting favorable rows.

Median peak RSS (MiB) changed from 178.98 to 198.35 for large fallback (+19.37), 52.66 to 54.79 for registered tables (+2.13), 17.36 to 17.33 for small fallback, 21.47 to 21.49 for fitting, and 15.30 to 15.38 for slides. These are whole-process peaks, not isolated allocation measurements. The SVG growth coincides with the memory increase; this run does not establish that all extra RSS comes from markup.

## Output and preservation

The combined typography change intentionally suppresses optional standard ligatures for native ASCII left-to-right paragraphs and represents that policy in SVG. Standalone shaping retains its existing policy. This differs from the earlier output-preserving optimization.

Five workloads / 14 slides were rendered by the baseline once and the candidate twice. Candidate SVG, ordered diagnostics, inheritance metadata, and saved PPTX were deterministic. All saved PPTX bytes, ordered diagnostics, and inheritance metadata matched the baseline. Thirty independent python-pptx input/saved-file reopens and table traversals passed.

Only the three table SVGs changed. Removing exactly ` style="font-feature-settings: 'liga' 0"` from each candidate SVG yields its baseline bytes. These benchmark inputs therefore show no additional wrap/geometry changes; native ligature-boundary fidelity is covered separately by the root/engine's fixtures, not inferred from this benchmark.

| Table | Baseline SVG bytes | Candidate SVG bytes | Extra bytes | Candidate text / tspan elements |
|---|---:|---:|---:|---:|
| Fallback 200×50 | 11,527,344 | 14,027,344 | 2,500,000 | 62,500 / 62,500 |
| Fallback 20×10 | 51,384 | 59,384 | 8,000 | 200 / 200 |
| Registered 100×20 | 5,183,230 | 5,855,230 | 672,000 | 16,800 / 16,800 |

The preservation tool separately checked fixed small (`slides-10`), large (`table-200x50`), and image-heavy (`images-unique`) inputs, two samples per variant. Decoded part payloads, deterministic saves, and same-version reopened SVGs passed; six additional independent saved-file reopens passed. Small/image-heavy cross-version artifacts were identical; the large SVG changed intentionally. Preservation-tool timings are correctness diagnostics, not authoritative speed evidence.

This pass locally ran Release build and the retained proof/preservation tools. The parent reported full library/Core/headless/platform and native/manual acceptance before the window; those checks were not rerun here or represented as local test executions.

## Evidence and disposition

The verification manifest pins retained binaries, modules, source, driver, runner, font, scripts, logs, process snapshots, raw receipts, and proof artifacts. Read [the verification receipt](benchmarks/2026-10-04-final-combined-layout-4-verification.json), [raw samples](benchmarks/2026-10-04-final-combined-layout-4-paired-macos.json), [paired analysis](benchmarks/2026-10-04-final-combined-layout-4-paired-analysis.json), [output proof](benchmarks/2026-10-04-final-combined-layout-4-output-proof.json), [difference classification](benchmarks/2026-10-04-final-combined-layout-4-output-differences.json), and [preservation proof](benchmarks/2026-10-04-final-combined-layout-4-preservation.json).

The earlier [performance-only report](LAYOUT-PERFORMANCE-20261004-4.md) remains a distinct output-preserving stage with different load. Its rejected cycle-one record is unchanged. This combined checkpoint is **PRE-RECONCILIATION / UNACCEPTED MEMORY COST**, not final performance approval. The retained a9d870b baseline remains the comparator for the forthcoming reconciled candidate; no additional fallback optimization cycle is authorized.
