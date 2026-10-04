# Reconciled combined layout measurement (2026-10-04)

The reconciled candidate removes 2.03 MB of repeated markup from the large table while preserving exact geometry and effective ligature policy. Its observed large-table peak RSS remains 2.01 MiB above the baseline. The primary large-fallback timing gain is **unproven**: median render time is 0.54% higher, with five of ten pairs faster and a paired interval crossing zero. Registered-table render time is 2.46% higher and all ten pairs are slower. Small fallback rendering is faster in all ten pairs.

These are mixed results under substantial Time Machine and WindowServer load. They do not establish a clean-host, general, or cross-platform speedup. No further fallback optimization cycle was performed. The parent accepted this as a bounded fidelity tradeoff with the exact markup reduction, while keeping fallback recovery open. This is not acceptance of a net speedup or lower memory than a9d870b.

## Source and protocol

The fresh retained baseline is `a9d870b9f8145a40e76fd48998606da796e3e32d`. Candidate worker source is `67593ee93cbee714c46828682eb86716b26a826a`, matching root `f8b33ee` at the complete Sources tree `1784f7c9fe64b3500eafcb25b518ce957303c8aa`. This combines the earlier removal of unused fallback base-style parsing, the native ASCII ligature policy, and the policy-inheritance reconciliation from `7a434edd43b3a035cb926299bc0721834ef33f50`. The latter emits a shared policy on homogeneous text blocks or lines, retaining span overrides where needed. No source was edited during this measurement pass.

All new artifacts are retained under `.build/perf12-reconciled/` in the fonts worktree. The previous [pre-reconciliation checkpoint](INTEGRATED-LAYOUT-PERFORMANCE-20261004-4-PRE-RECONCILIATION.md), its raw timings, and its binaries remain unchanged in `.build/perf11-combined/`. Their “final-combined” filenames identify the superseded candidate, not this result. The earlier [performance-only result](LAYOUT-PERFORMANCE-20261004-4.md) and rejected cycle-one evidence remain distinct.

The baseline object, module, executables, fixed input decks, canonical driver, compiler and Arial font were retained unchanged. The candidate was built in Release, its matching Swift module copied with its object, and the identical driver compiled with the same flags and canonical source path. Candidate executable SHA256 is `6cf55cd4d51f1d95a883dd9f184e6cda6edff0cab7d1cca1b891405f17a398b3`. Compiler: Apple Swift 6.4 (swiftlang-6.4.0.34.1), arm64 macOS.

```sh
swift build -c release --jobs 2
swiftc -swift-version 6 -O -I .build/perf12-reconciled/candidate-module Tools/rostrum-bench/main.swift .build/perf12-reconciled/candidate-Rostrum.o -o .build/perf12-reconciled/candidate-extended-bench
ROSTRUM_BENCH_FONT=/System/Library/Fonts/Supplemental/Arial.ttf python3 Tools/rostrum-bench/run.py --binary .build/perf12-reconciled/candidate-extended-bench --paired-binary .build/perf12-reconciled/baseline-extended-bench --paired-revision a9d870b9f8145a40e76fd48998606da796e3e32d --runs 10 --warmups 1 --scenarios table-200x50 table-20x10 shaped-table-100x20 richtext-fit slides-10 --output docs/benchmarks/2026-10-04-reconciled-combined-layout-4-paired-macos.json
```

Root explicitly granted the timing window after full local, headless, native and manual acceptance, with other lanes idle and the verification app closed. The unchanged canonical runner completed 110 fresh processes: five workloads, one excluded warmup pair and ten retained alternating pairs each. All 100 retained samples completed in 24.33 seconds; the window was released immediately. Source and executable hashes were checked before launch.

Start/during/end snapshots (06:16:07.179 / 06:16:22.374 / 06:16:31.505 PDT) showed backupd at **90.6% / 96.4% / 93.4% CPU**, WindowServer at **75.8% / 79.0% / 80.3%**, and the backup helper at 0.0%. No external compiler/build/test was observed; the middle snapshot includes this run's baseline process. Snapshot monitoring cannot prove continuous isolation. No system or backup settings were changed.

## Paired results against a9d870b

Negative deltas mean faster. Ratio-of-medians and median-paired-percent changes are different statistics.

| Workload / phase | Baseline median ms | Candidate median ms | Ratio of medians | Faster pairs |
|---|---:|---:|---:|---:|
| Fallback table 200×50 / render | 189.8454 | 190.8676 | +0.54% | 5/10 |
| Fallback table 20×10 / render | 3.9515 | 3.6993 | −6.38% | 10/10 |
| Registered table 100×20 / render | 76.4976 | 78.3821 | +2.46% | 0/10 |
| Rich text / fitting | 14.3175 | 14.1634 | −1.08% | 5/10 |
| Fitted rich text / render | 3.3892 | 3.3789 | −0.30% | 5/10 |
| Ten-slide deck / first render | 0.6027 | 0.5872 | −2.57% | 8/10 |

| Phase | Median paired delta | Bootstrap 95% interval | Exact two-sided sign p |
|---|---:|---:|---:|
| Large fallback render | +0.57% | [−2.15%, +2.31%] | 1 |
| Small fallback render | −6.50% | [−7.97%, −3.57%] | 0.001953125 |
| Registered table render | +3.06% | [+1.66%, +4.02%] | 0.001953125 |
| Rich text fitting | −0.12% | [−3.76%, +2.74%] | 1 |
| Fitted text render | +0.20% | [−4.55%, +2.30%] | 1 |
| Ten-slide first render | −2.28% | [−11.79%, +4.45%] | 0.109375 |

Every pair delta is retained. The deterministic percentile bootstrap uses 100,000 resamples of pairs and seed 20261004. The exact two-sided sign test excludes ties. These exploratory ten-pair estimates are not corrected across workloads and cannot remove background-load bias. The registered slowdown is a directional observation in this run and must remain visible; it is not dismissed merely because load was present. The primary fallback-recovery objective remains unresolved.

| Workload | Baseline median peak RSS MiB | Candidate MiB | Delta MiB |
|---|---:|---:|---:|
| Large fallback | 179.0078 | 181.0156 | +2.0078 |
| Small fallback | 17.3594 | 17.5234 | +0.1641 |
| Registered table | 52.6484 | 54.5938 | +1.9453 |
| Rich fitting | 21.4609 | 21.5156 | +0.0547 |
| Slides | 15.3047 | 15.4375 | +0.1328 |

These are whole-process peak RSS medians, not attributed allocation costs or guarantees for other decks. The earlier unhoisted run observed +19.37 MiB for large fallback; this run observes +2.01 MiB against the same retained baseline. Those runs occurred under different load, so their timings are not a matched estimate of the hoist alone. The residual SVG size is exact; no claim attributes the entire residual RSS to it.

## Output size and fidelity proof

| Workload | a9d870b SVG bytes | Unhoisted bytes | Reconciled bytes | Reduction from unhoisted | Residual over baseline |
|---|---:|---:|---:|---:|---:|
| Fallback 200×50 | 11,527,344 | 14,027,344 | 11,997,344 | 2,030,000 | 470,000 |
| Fallback 20×10 | 51,384 | 59,384 | 59,384 | 0 | 8,000 |
| Registered 100×20 | 5,183,230 | 5,855,230 | 5,277,230 | 578,000 | 94,000 |

Five workloads / 14 slides were rendered with the baseline once and the reconciled candidate twice. Candidate SVG, ordered diagnostics, inheritance metadata and saved packages were deterministic. All saved PPTX, ordered diagnostics and inheritance metadata matched both baseline and unhoisted candidate. Thirty independent python-pptx input/saved-package reopens and table traversals passed.

Whole-tree projection compared all 47 output artifacts against the retained unhoisted candidate. It resolves inherited font-feature-settings on painted text, removes only policy-only group wrappers, and retains all other attributes, text, ordering and geometry exactly. Every SVG's geometry and effective policy matched the unhoisted source. Geometry also matched a9d870b after additionally excluding the intentional ligature policy; raw cross-version SVG identity is not required. This preserves the prior native-fidelity behavior rather than reverting its intended policy.

The native four-slide fixture was independently rerendered with the retained Release candidate. Exact whole-tree geometry/effective policy, ordered diagnostics, inheritance metadata and saved package bytes matched pre-hoist output. Two additional independent python-pptx native-package reopens passed. The first local native rerun used Arial while the engine's retained SVG embedded another font; this mismatched-font attempt is retained and excluded. Rerunning with the exact embedded font bytes (SHA256 `7da195a74c55bef988d0d48f9508bd5d849425c1770dba5d7bfc6ce9ed848954`) passed. That native-only correction does not affect the canonical benchmark's unchanged Arial font.

The small/large/image-heavy fixed-deck preservation tool passed decoded-part payload preservation, deterministic saves and same-version reopened SVG identity for both variants, plus six independent saved-package reopens. Small and image-heavy cross-version artifacts were byte-identical; the large SVG intentionally differs. These two-sample preservation timings were not used as speed evidence.

The prior pre-reconciliation preparation had a baseline-module/candidate-object mismatch caught before any authoritative timing. That excluded preflight remains documented in its original checkpoint. Both measured candidates were compiled with matching modules; this pass introduced no module mismatch.

## Verification and evidence

Local work in this pass: Release build, repeated workload proof, fixed-deck preservation, native Release projection, 38 independent python-pptx reopens in total, and hash verification. Root reported its final full gate: 1,107 library tests, 18 layout tests, 277 Core tests and 76 native app tests with zero skips; headless and both final manual GUI variants passed. These parent-run checks were not rerun or represented as local executions here.

The [verification manifest](benchmarks/2026-10-04-reconciled-combined-layout-4-verification.json) pins source, objects/modules/executables, driver/runner/font, retained scripts and logs, process context and artifacts. See [raw timings](benchmarks/2026-10-04-reconciled-combined-layout-4-paired-macos.json), [paired uncertainty](benchmarks/2026-10-04-reconciled-combined-layout-4-paired-analysis.json), [summary](benchmarks/2026-10-04-reconciled-combined-layout-4-summary.json), [deterministic outputs](benchmarks/2026-10-04-reconciled-combined-layout-4-output-proof.json), [whole-tree projection](benchmarks/2026-10-04-reconciled-combined-layout-4-projection.json), [native projection](benchmarks/2026-10-04-reconciled-combined-layout-4-native-projection.json), and [preservation](benchmarks/2026-10-04-reconciled-combined-layout-4-preservation.json). Originals and rejected attempts remain retained. Performance approval cannot be inferred from correctness approval.
