# PERF-1: LTR shaping bookkeeping (2026-10-04)

The first bounded cycle reduced registered-table render medians **78.6407 → 74.7802 ms (4.91%)** against the fresh integrated baseline `6e84bfbceffba18c0cf71e09dbd4837b65adbeb2` (Sources identical to root `a68f5c7`). All ten registered pairs were faster. The parent accepted this bounded result pending independent evidence review; no extra cycle was run. Every checked glyph record, SVG, ordered diagnostic, inheritance flag and saved package remained identical. WindowServer was busy throughout; these observations do not establish clean-host/general/cross-platform speed, lower memory, or recovery of the entire historical slowdown.

## Change and provenance

Both sides include the accepted recent-style cache and empty-line engine. Source commit: `44cf35e7c152d6602660fe8dfc4ea64ee7a33955`. Only `TextShaper.swift` and four focused tests change. When existing `hasRTL` is false, the paragraph base is LTR and no RTL cluster exists: digits and neutrals resolve to the default level zero. The shaper now skips three temporary arrays and their resolution traversals, then skips the final glyph-level maximum/reorder check. The RTL branch keeps its existing operations and order. No caching, font resolution, shaping arithmetic or diagnostic policy changes.

The retained registered Release profile attributes 142/3,689 main-thread samples to this redundant work: 103 at original lines 97–123 and 39 at line 283. Shaping accounts for 1,000 inclusive samples. These overlapping sampling counts locate work, not predicted speed. The profile predates the latest integration; the original TextShaper source was verified unchanged, while all matched timing uses the fresh integrated baseline.

## Matched measurement

| Workload / phase | Baseline median ms | Candidate median ms | Change | Faster pairs |
|---|---:|---:|---:|---:|
| Large fallback render | 190.7116 | 189.5328 | -0.62% | 8/10 |
| Small fallback render | 3.7514 | 3.7981 | +1.24% | 3/10 |
| Registered table render | 78.6407 | 74.7802 | -4.91% | 10/10 |
| Rich fitting | 14.3101 | 14.0144 | -2.07% | 8/10 |
| Fitted text render | 3.4344 | 3.3794 | -1.60% | 7/10 |
| Ten-slide render | 0.5946 | 0.5882 | -1.07% | 7/10 |

Registered median paired change is **−4.85%**, with percentile-bootstrap 95% interval **[−6.15%, −3.68%]**, exact two-sided sign p=0.001953125. Fitting has paired median **−3.07%**, interval **[−3.94%, −0.64%]**, sign p=0.109375: supportive but weaker evidence. Bootstrap uses 100,000 resamples, seed 20261004; raw pair deltas are retained. Estimates are exploratory, uncorrected across workloads and cannot remove host-load bias. Fallback and ten-slide work do not exercise this guarded shaper path; their changes are not attributed to this optimization.

Median peak RSS was **181.0547 → 181.0859 MiB** for large fallback, **54.8281 → 54.7500 MiB** for registered tables, and **21.4063 → 21.1641 MiB** for fitting. Whole-process RSS does not establish an allocation or memory improvement.

The explicitly coordinated window completed the unchanged canonical runner's 110 fresh processes (one excluded warmup pair and ten retained pairs per five workloads) in **24.30 seconds**, then was immediately released. At start/during/end, WindowServer used **91.5% / 92.6% / 93.0% CPU**; backupd and its helper were 0.0%. No external compiler/build/test was observed. Snapshots are not continuous isolation monitoring. No settings were altered.

Both sides retain matching Release objects/modules and compile the identical canonical driver with `swiftc -swift-version 6 -O`, Apple Swift 6.4 (swiftlang-6.4.0.34.1), and hash-pinned Arial. Both Release builds used `swift build -c release --jobs 2`. The candidate was measured as a frozen two-file patch; source/binary hashes bind it to the later commit.

```sh
ROSTRUM_BENCH_FONT=/System/Library/Fonts/Supplemental/Arial.ttf python3 Tools/rostrum-bench/run.py --binary .build/perf15-ltr/candidate-extended-bench --paired-binary .build/perf15-ltr/baseline-extended-bench --paired-revision 6e84bfbceffba18c0cf71e09dbd4837b65adbeb2 --runs 10 --warmups 1 --scenarios table-200x50 table-20x10 shaped-table-100x20 richtext-fit slides-10 --output docs/benchmarks/2026-10-04-ltr-bookkeeping-layout-6-paired-macos.json
```

## Correctness and evidence

Four focused tests pass with complete golden glyph/range/advance/offset/level/break/diagnostic records, explicit RTL/mixed Hebrew, controls, normalization, invalid sizes and internal ligature policy. A retained original/candidate oracle compares **100,734 complete records** byte-for-byte across Arial and DejaVu Sans: every ASCII singleton/pair in all three directions plus non-ASCII, combining, substitution, control, Arabic/CJK, size and kerning cases. All match.

Full `swift test --jobs 2`: **1,120 Rostrum tests / 156 suites passed with four existing known native empty-line issues**, plus **18 RostrumLayout tests / 3 suites passed**. Baseline/candidate Release builds and diff checks pass. Full corpus identity covers **96 cases / 748 slides** with 192 independent python-pptx reopens. Five fixed workloads / 14 slides match baseline and repeated candidate, with 30 reopens. Small, large and image-heavy preservation checks pass payload/save/reopened-SVG and cross-version identity, with six reopens: **228 reopens total**. The retained artifact check validates 4,965 input/artifact hashes. Root owns integrated application/native acceptance.

Evidence remains in `.build/perf15-ltr/`: [manifest](benchmarks/2026-10-04-ltr-bookkeeping-layout-6-verification.json), [raw pairs](benchmarks/2026-10-04-ltr-bookkeeping-layout-6-paired-macos.json), [paired analysis](benchmarks/2026-10-04-ltr-bookkeeping-layout-6-paired-analysis.json), [summary](benchmarks/2026-10-04-ltr-bookkeeping-layout-6-summary.json), [shaping identity](benchmarks/2026-10-04-ltr-bookkeeping-layout-6-shaping-identity.json), [corpus identity](benchmarks/2026-10-04-ltr-bookkeeping-layout-6-output-identity.json), [fixed proof](benchmarks/2026-10-04-ltr-bookkeeping-layout-6-output-proof.json), and [preservation](benchmarks/2026-10-04-ltr-bookkeeping-layout-6-preservation.json). Earlier checkpoints remain distinct and unchanged.
