# PERF-1: ASCII combining-category guard (2026-10-04)

The first bounded cycle reduced registered-table render medians **75.2026 → 71.8619 ms (4.44%)** and rich-fitting medians **14.2224 → 13.2483 ms (6.85%)** against fresh post-bidi baseline `474a08d952435b02960aaba3872aa1b3dd744790` (source `44cf35e`). Both targets were faster in all ten alternating pairs. The parent accepted these bounded results pending independent raw review; no further cycle was run. All checked shaping and presentation output remains byte-identical.

These are observations under substantial WindowServer and variable Time Machine load. They do not establish clean-host/general/cross-platform speed, lower memory, fallback gains or cumulative/historical regression recovery. Earlier increments and their windows remain separate.

## Change and source proof

Source commit: `cbe830dca5090e6d2984873dea3fade30251b95b`. Only `TextShaper.swift` and three focused tests change. The one-line guard requires a normalized singleton's scalar value to be at least 0x80 before asking whether its Unicode category is a mark. ASCII scalars cannot be combining marks. The old mark-category expression remains unchanged behind that short-circuit; the multi-scalar branch and final CRLF exclusion remain unchanged. No normalization, source ranges, arithmetic, caching or diagnostic policy changes.

The retained registered Release profile attributes **163/3,689 main-thread samples** to the original combining-category condition at TextShaper.swift:74, counting only the first exact shaping frame and excluding nested closure duplication. This locates work, not a speed prediction. The retained profile predates recent increments, but this condition remained unchanged in the fresh post-bidi baseline. Timing uses only the fresh baseline; no historical binaries supply this result.

## Matched measurement

| Workload / phase | Baseline median ms | Candidate median ms | Change | Faster pairs |
|---|---:|---:|---:|---:|
| Large fallback render | 193.2309 | 191.8120 | -0.73% | 8/10 |
| Small fallback render | 3.9322 | 3.8937 | -0.98% | 6/10 |
| Registered table render | 75.2026 | 71.8619 | -4.44% | 10/10 |
| Rich fitting | 14.2224 | 13.2483 | -6.85% | 10/10 |
| Fitted text render | 3.4748 | 3.3169 | -4.55% | 8/10 |
| Ten-slide render | 0.6122 | 0.6114 | -0.12% | 6/10 |

Registered median paired change is **−4.25%**, with percentile-bootstrap 95% interval **[−5.32%, −3.43%]**. Rich fitting is **−8.47%**, interval **[−9.27%, −6.63%]**. Both exact two-sided sign tests give p=0.001953125. Fitted rendering has weaker directional evidence (8/10, sign p=0.109375). Bootstrap uses 100,000 resamples and seed 20261004; every raw paired delta is retained. These exploratory estimates are uncorrected across workloads and cannot remove host-load bias. Fallback and ten-slide phases do not exercise the guarded shaping condition; their intervals cross zero and no gain is attributed to this change.

Median whole-process peak RSS changed **181.0547 → 180.9297 MiB** for large fallback, **54.6953 → 54.5234 MiB** for registered tables, and **21.1953 → 21.2813 MiB** for fitting. This does not establish an allocation or memory improvement.

The root explicitly granted the window after its full gate and all lanes paused. The unchanged canonical runner completed **110 fresh processes** (one excluded warmup pair and ten retained pairs per five workloads) in **24.32 seconds**, then the window was immediately released. Start/during/end snapshots show WindowServer **94.7% / 92.6% / 92.4% CPU**, backupd **87.6% / 32.3% / 32.5%**, helper 0.0%. No external compiler/build/test was observed; snapshots are not continuous monitoring. No system settings changed.

Both sides retain matching Release objects/modules and compile the identical driver with `swiftc -swift-version 6 -O`, Apple Swift 6.4 (swiftlang-6.4.0.34.1), and hash-pinned Arial. Both use `swift build -c release --jobs 2`; the baseline invocation confirmed its already-current post-bidi Release build (0.28 seconds), and the candidate built in 56.17 seconds. The candidate was measured as a frozen two-file patch, with source and binary hashes bound to its subsequent commit.

```sh
ROSTRUM_BENCH_FONT=/System/Library/Fonts/Supplemental/Arial.ttf python3 Tools/rostrum-bench/run.py --binary .build/perf16-combining/candidate-extended-bench --paired-binary .build/perf16-combining/baseline-extended-bench --paired-revision 474a08d952435b02960aaba3872aa1b3dd744790 --runs 10 --warmups 1 --scenarios table-200x50 table-20x10 shaped-table-100x20 richtext-fit slides-10 --output docs/benchmarks/2026-10-04-combining-category-layout-7-paired-macos.json
```

## Correctness and retained evidence

Three new focused tests pass: all ASCII scalars in all three directions, exact CRLF glyph/break/source ranges, and nonspacing/spacing/enclosing non-ASCII marks plus residual multi-scalar diagnostics. The retained full shaping oracle matches **100,734 records** byte-for-byte across Arial and DejaVu Sans, including glyph IDs, ranges, advances/offsets as bit patterns, levels, breaks and ordered diagnostics. Inputs cover every ASCII singleton/pair in three directions plus non-ASCII scripts, controls, combining, substitutions, sizes and kerning. Existing native ligature-policy tests also pass.

Full `swift test --jobs 2`: **1,123 Rostrum tests / 157 suites passed with four existing known native empty-line issues**, plus **18 RostrumLayout tests / 3 suites passed**. Release builds and diff checks pass. Corpus identity covers **96 cases / 748 slides** and 192 independent python-pptx reopens. Five fixed workloads / 14 slides match baseline and repeated candidate with 30 reopens. Required small/large/image-heavy preservation passes decoded payloads, deterministic save, reopened SVG and cross-version identity with six reopens: **228 reopens total**. The artifact check validates **4,965 input/artifact hashes**. Root owns final integrated application/native acceptance.

Retained files are under `.build/perf16-combining/`: [verification manifest](benchmarks/2026-10-04-combining-category-layout-7-verification.json), [raw pairs](benchmarks/2026-10-04-combining-category-layout-7-paired-macos.json), [paired analysis](benchmarks/2026-10-04-combining-category-layout-7-paired-analysis.json), [summary](benchmarks/2026-10-04-combining-category-layout-7-summary.json), [shaping identity](benchmarks/2026-10-04-combining-category-layout-7-shaping-identity.json), [corpus identity](benchmarks/2026-10-04-combining-category-layout-7-output-identity.json), [fixed proof](benchmarks/2026-10-04-combining-category-layout-7-output-proof.json), and [preservation](benchmarks/2026-10-04-combining-category-layout-7-preservation.json). Earlier evidence, including rejected experiments, remains unchanged.
