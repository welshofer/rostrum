# Final current-upstream comparison (2026-10-04)

Against a fresh current-main baseline, the integrated candidate's large fallback render time was **3.97% higher** and registered-table render time **2.51% higher**. Both were slower in nine of ten matched pairs. Large-table peak RSS was **2.0078 MiB higher**; registered-table peak RSS was **2.2344 MiB higher**. These observed regressions remain explicit despite substantial, variable backup and WindowServer load.

The parent accepted this as a **bounded fidelity tradeoff**, with no net-speedup or lower-memory claim. PERF-1 fallback recovery remains open. No further source optimization or repeat timing was performed. The exact markup reduction from policy inheritance is preserved, but is a separate output-size result rather than evidence of faster rendering.

## Fresh baseline and integrated source

Upstream added automatic-number font and missing-font adjacent-run flow fixes after the prior measurement. This run uses fresh baseline `6a1f56f0a79049a3223a6a42f9d506492f324749`, not the earlier a9d870b baseline. The candidate is worker merge `157f607f3a4539e9df75914326a38e2102b4eb43`, matching root `2953dc1` at complete Sources tree `24a6b72201b2866ad49e386d9452c960bac6af20`. A local SVGRenderer merge conflict was resolved by taking root's exact integrated file; the entire Sources tree was then verified equal.

Retained evidence is `.build/perf13-upstream/` in the fonts worktree. Baseline source came from `git archive 6a1f56f` into a separate directory; 115 source/package/tool files were checked against that revision's Git bytes. Both Release builds succeeded (candidate 71.34 seconds; baseline 77.32 seconds). Each object was retained with its matching Swift module and executables. The identical canonical driver was compiled from the same path with `-swift-version 6 -O` for both; driver, runner and preservation-tool sources match upstream. Apple Swift 6.4 (swiftlang-6.4.0.34.1), arm64 macOS, and the same hash-pinned Arial font were used. Candidate executable SHA256: `83cef9c57f935a375d92134ab49ee5d401411b38c35f4d37c58ec0cccdd6a554`.

```sh
git archive 6a1f56f | tar -x -C .build/perf13-upstream/baseline-source
swift build -c release --jobs 2
swift build -c release --jobs 2 --package-path .build/perf13-upstream/baseline-source --scratch-path .build/perf13-upstream/baseline-build
swiftc -swift-version 6 -O -I .build/perf13-upstream/candidate-module Tools/rostrum-bench/main.swift .build/perf13-upstream/candidate-Rostrum.o -o .build/perf13-upstream/candidate-extended-bench
swiftc -swift-version 6 -O -I .build/perf13-upstream/baseline-module Tools/rostrum-bench/main.swift .build/perf13-upstream/baseline-Rostrum.o -o .build/perf13-upstream/baseline-extended-bench
ROSTRUM_BENCH_FONT=/System/Library/Fonts/Supplemental/Arial.ttf python3 Tools/rostrum-bench/run.py --binary .build/perf13-upstream/candidate-extended-bench --paired-binary .build/perf13-upstream/baseline-extended-bench --paired-revision 6a1f56f0a79049a3223a6a42f9d506492f324749 --runs 10 --warmups 1 --scenarios table-200x50 table-20x10 shaped-table-100x20 richtext-fit slides-10 --output docs/benchmarks/2026-10-04-upstream-combined-layout-4-paired-macos.json
```

The earlier [perf12 report](INTEGRATED-LAYOUT-PERFORMANCE-20261004-4.md) remains tied to f8b33ee/a9d870b and is historical. Its ten-slide faster-pair row was corrected from 7/10 to 8/10 to match the unchanged raw/analysis receipts; its report hash was updated. The [pre-reconciliation report](INTEGRATED-LAYOUT-PERFORMANCE-20261004-4-PRE-RECONCILIATION.md) and rejected cycle-one record remain unchanged. No historical timing substitutes for this fresh current-main comparison.

## Final paired window and limitations

Root explicitly granted the final quiet window after its complete integration gate, with no root GUI/build/test/verification jobs. The unchanged runner completed five workloads × (one excluded warmup pair + ten retained alternating pairs) × two variants: **110 fresh processes, 100 retained samples**, in **24.97 seconds**. Source and executable hashes were checked first, and the window was released immediately on completion.

Start/during/end snapshots at 06:25:08.434 / 06:25:23.706 / 06:25:33.395 PDT showed backupd **73.7% / 144.5% / 121.2% CPU**, WindowServer **76.2% / 77.9% / 75.9%**, and backup helper 0.0%. No external compiler/build/test was observed. Snapshot coverage is not continuous monitoring. The changing load limits causal attribution and generalization; it does not justify hiding the repeated directional slowdown. No system or backup settings were altered.

Negative deltas mean faster; ratio-of-medians and median-paired-percent changes are different statistics.

| Workload / phase | Baseline median ms | Candidate median ms | Ratio of medians | Faster pairs |
|---|---:|---:|---:|---:|
| Fallback table 200×50 / render | 188.8149 | 196.3060 | +3.97% | 1/10 |
| Fallback table 20×10 / render | 3.8725 | 3.7607 | -2.89% | 6/10 |
| Registered table 100×20 / render | 77.2920 | 79.2300 | +2.51% | 1/10 |
| Rich text / fitting | 14.1825 | 14.1542 | -0.20% | 6/10 |
| Fitted rich text / render | 3.3206 | 3.4378 | +3.53% | 2/10 |
| Ten-slide deck / first render | 0.6570 | 0.6110 | -7.01% | 7/10 |

Large fallback median paired delta is +4.25% (bootstrap 95% interval [+1.95%, +5.03%]); registered is +2.99% ([+1.32%, +4.05%]). Both exact two-sided sign tests give p=0.021484375. The receipt retains every delta and 100,000-resample percentile bootstrap (seed 20261004). These exploratory ten-pair estimates are not corrected across workloads and cannot remove load bias. Small fallback and fitting intervals cross zero. Primary performance recovery is not demonstrated.

Large fallback median peak RSS: **179.1406 → 181.1484 MiB (+2.0078)**. Registered table: **52.5859 → 54.8203 MiB (+2.2344)**. Other workloads and all raw samples are in the summary receipt.

RSS values are whole-process peak medians, not isolated allocation costs or bounds for all decks. The large fallback residual is approximately 2.01 MiB and the registered residual approximately 2.23 MiB versus the fresh baseline. Attribution to particular code or SVG buffers would require allocation profiling. Earlier unhoisted and reconciled measurements occurred in separate windows against a9d870b; their timings and RSS must not be treated as matched comparisons of this current-main candidate.

## Output and preservation

| Table | Fresh baseline SVG bytes | Candidate SVG bytes | Residual bytes |
|---|---:|---:|---:|
| Fallback 200×50 | 11,527,344 | 11,997,344 | 470,000 |
| Fallback 20×10 | 51,384 | 59,384 | 8,000 |
| Registered 100×20 | 5,183,230 | 5,277,230 | 94,000 |

Candidate table bytes equal the retained perf12 candidate. Against the historical unhoisted output, inheritance still removes exactly 2,030,000 bytes on the large table and 578,000 on the registered table. This is an exact file-size comparison, not a cross-window timing claim.

Five workloads / 14 slides were rendered by the fresh baseline once and candidate twice. All candidate outputs were deterministic. Saved PPTX bytes, ordered diagnostics and inheritance metadata were equal across variants. Thirty independent python-pptx input/saved-file reopens and table traversals passed. The unchanged canonical paired runner's saved-PPTX identity requirement also passed.

The whole-tree comparison covered 47 artifacts. Only the three table SVGs differ against the new baseline; their geometry matches exactly when the intentional ligature policy is excluded. Projection resolves inherited font-feature-settings and removes only policy-only wrappers, keeping other attributes, text, order and geometry. It does not assert raw SVG identity across the intentional policy change.

Compared with the premerge perf12 candidate, 37/47 artifacts remain byte-identical. The ten slides-10 SVGs each remove exactly one absolute x attribute from a following tspan; their tree, text and every other attribute remain identical. This is the upstream missing-font adjacent-run flow fix. Both the new baseline and final candidate contain it; it is not erased to manufacture premerge identity.

The required fixed small (`slides-10`), large (`table-200x50`) and image-heavy (`images-unique`) preservation checks passed for both variants: decoded part payloads, deterministic saves and same-version reopened SVG identity. Six additional independent saved-package reopens passed, for **36 local reopens** in this pass. Small/image-heavy artifacts were cross-version byte-identical; large SVG differences are intentional. Preservation-tool timings are correctness diagnostics, not speed evidence.

This pass locally ran both Release builds, repeated workload proof, preservation, geometry projection, baseline-source byte verification, hash checks and diff checks. Root reported the merged full gate green: 1,109 library tests, 18 layout tests, 277 Core tests, 76 native app tests with zero skips; headless 76 tests / 21 suites; 26 Lab inputs, 337 checks and 52 external reopens. Root also verified four paragraph SVGs and both saved variants byte-identical to its premerge acceptance output. Those root checks were not rerun or represented as local executions here.

## Retained evidence and disposition

See the [verification manifest](benchmarks/2026-10-04-upstream-combined-layout-4-verification.json), [raw samples](benchmarks/2026-10-04-upstream-combined-layout-4-paired-macos.json), [paired uncertainty](benchmarks/2026-10-04-upstream-combined-layout-4-paired-analysis.json), [summary and upstream-output classification](benchmarks/2026-10-04-upstream-combined-layout-4-summary.json), [deterministic proof](benchmarks/2026-10-04-upstream-combined-layout-4-output-proof.json), [geometry projection](benchmarks/2026-10-04-upstream-combined-layout-4-projection.json), and [preservation](benchmarks/2026-10-04-upstream-combined-layout-4-preservation.json). All prior artifacts are preserved.

Accepted only as an explicit fidelity tradeoff: observed large fallback +3.97%, registered render +2.51%, and residual memory above current main, with substantial variable-load qualification. No clean-host, general, cross-platform, net-speedup or lower-memory claim. PERF-1 fallback recovery remains open.
