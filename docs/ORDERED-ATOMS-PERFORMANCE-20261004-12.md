# Ordered non-ASCII atom ranges: two measured iterations

**Cycle 2 reduces fitting and accented/CJK rendering time in this matched run. Cycle 1 remains withheld because it slowed the registered table.** The final helper's registered-table interval crosses zero; this does not prove nonregression. Fallback and combining controls also retain possible costs. Independent review accepted the final source and evidence packet, including the retained adverse cycle 1 result and bounded cycle 2 claims.

Both iterations compare against the same accepted perf11 baseline: evidence 76aa45d, source b68f5a1 (engine 83a1c72; root equivalent e8841e3), Sources tree 36791fc7d7d2e0c89b0720e7d50fda1d14944af8. Its retained Release module/object pair was not rebuilt. Cycle 2 source/tests are committed as 8503f44; they were measured as a frozen uncommitted patch with RichTextLayout SHA-256 6e4e1567395526cef9bddd7d755e8a847c428394cfdf2b55e8295fb15a7da055. No production source changed after timing.

Fresh baseline sampling attributed 384/2,907 fitting main-thread samples (13.21%) and 84/2,917 accented/CJK render samples (2.88%) to outermost appendSegment dictionary/sort work, excluding TextShaper descendants and nested duplicates. Root GUI work could overlap this attribution profile; sample shares are not expected speedups. The fitting input contains café, so it takes general shaping and does not allocate native scalar-position arrays. No native-policy or paint change is made.

The candidate validates nonempty, ordered, nonoverlapping source ranges with bidi level zero before appending any atom. Accepted ranges avoid dictionary grouping and sorting. Single-glyph arithmetic retains the original default-zero addition (0.0 + advance), original source substring, tracking calculation, breaks and all atom fields. Repeated, overlapping, reordered and RTL ranges retain the original dictionary path. Native-grid processing is unchanged.

Cycle 1 inserted the loops in appendSegment. It measured fitting −16.36% and accented/CJK −4.34% paired medians, but registered-table rendering regressed +1.34% [+.54,+2.66], with 9/10 slower pairs and exact sign-test p=.021484375. That result is withheld, not dismissed as noise. Its [checkpoint](benchmarks/2026-10-04-ordered-atoms-layout-12-cycle1-checkpoint.json), raw measurements, source, objects and assembly remain intact.

Cycle 2 moves only those loops into one local @inline(never) helper with explicit inputs and an inout atom array, no captures or temporary atom array. The compiled common function spans 4,960 bytes at baseline, 5,656 in cycle 1 and 5,084 in cycle 2; the outlined helper is 744 bytes. The common stack frame is unchanged, but register allocation still differs. This is evidence for a bounded code-generation hypothesis, not proof that code size caused either timing result.

Each iteration ran once under its own explicit quiet-window grant: unchanged canonical 110 and supplementary 66 child processes, plus a separately labeled 22-child late-combining rejection control. Ten alternating retained pairs and one excluded warmup per workload use identical drivers, compiler flags, inputs and Arial bytes on both sides. Fonts are registered outside rendering. Cycle 2 completed all 198 children in 50.69 seconds (exact 50.68576808297075); cycle 1 took 50.62903050001478. Context recovery delayed cycle 2 launch after the grant; the execution receipt records actual run duration. No adaptive rerun occurred.

| Workload/phase | Baseline→candidate ms | Ratio of medians Δ | Paired median Δ [95% interval] | Faster pairs | RSS Δ MiB |
|---|---:|---:|---:|---:|---:|
| Fallback 200×50 table | 192.4662→194.6260 | +1.12% | +0.79% [-0.01, +1.42] | 3/10 | -0.039 |
| Fallback 20×10 table | 3.8024→3.8560 | +1.41% | +0.36% [-2.93, +4.87] | 4/10 | -0.094 |
| Registered 100×20 table | 65.9399→66.1401 | +0.30% | +0.24% [-1.53, +1.70] | 4/10 | +0.055 |
| Rich-text render | 2.9708→2.7280 | -8.17% | -7.07% [-11.16, -5.13] | 10/10 | +0.094 |
| Rich-text fitting | 11.2129→9.6412 | -14.02% | -14.05% [-15.59, -11.58] | 10/10 | +0.094 |
| Ten slides | 0.6144→0.6102 | -0.68% | -1.05% [-5.58, +4.35] | 6/10 | +0.016 |
| Accented/CJK | 127.8456→123.4783 | -3.42% | -3.40% [-3.87, -2.81] | 10/10 | -0.258 |
| Mixed RTL | 126.4446→125.7733 | -0.53% | -0.19% [-0.69, +0.35] | 7/10 | +0.172 |
| Long combining | 402.6884→405.4288 | +0.68% | +0.25% [-1.03, +1.45] | 4/10 | -0.078 |
| Late-combining control | 143.5710→142.4529 | -0.78% | -0.81% [-1.58, +0.29] | 8/10 | -0.117 |

Fitting and accented/CJK are faster in 10/10 pairs, each exact two-sided sign-test p=.001953125. Rich-text rendering also has 10/10 faster pairs. The registered-table paired result is +0.244% [−1.531,+1.699], p=.75390625; cycle 1's directional regression is not reproduced, without establishing recovery or universal nonregression. Fallback 200×50 is +0.791% [−0.013,+1.417], 7/10 slower, p=.34375; its unchanged source path does not justify erasing the observed possible cost.

Mixed RTL, long combining and the late-combining control remain inconclusive. The late control has 1,419 source scalars per cell and first rejects at glyph index 1,350 of 1,418, testing traversal of a long accepted prefix before dictionary fallback. It is separate from the unchanged three supplementary workloads. None of these results establishes a bound for every Unicode input.

RSS is whole-process peak median, including parsing, shaping, saved packages and helper-held data. It rises 0.094 MiB for fitting and 0.055 MiB for registered rendering, while accented/CJK decreases 0.258 MiB; the other signs are mixed. No lower-memory claim is made. Negative runtime deltas favor the candidate. The fitting and rich-text render rows share one process RSS. Bootstrap intervals use 100,000 pair resamples with seed 20261004, and exact two-sided sign tests exclude ties. These are exploratory unadjusted comparisons across workloads.

Seven cycle 2 snapshots show WindowServer 97.4–100.7%, with backupd, Photos and Spotlight at 0%. Root and other workers paused builds/tests/GUI during the run. This was not a clean host; snapshots cannot prove continuous isolation or remove shared-load bias. Cycle 1 separately had WindowServer 96.9–99.7% and backupd 49.1–139.6%. Cross-window medians do not measure cycle 2 versus cycle 1. No user process or system setting was changed.

[Cycle 2 canonical raw](benchmarks/2026-10-04-ordered-atoms-layout-12-cycle2-paired-macos.json), [supplementary raw](benchmarks/2026-10-04-ordered-atoms-layout-12-cycle2-supplement-paired-macos.json), [late-control raw](benchmarks/2026-10-04-ordered-atoms-layout-12-cycle2-late-combining-paired-macos.json) and corresponding paired-analysis receipts retain every sample and paired delta.

Preservation is exact against accepted perf11. The [output proof](benchmarks/2026-10-04-ordered-atoms-layout-12-cycle2-output-proof.json) covers 134 cases/824 slides: canonical 5/14, supplementary 3/3, native 4/9 and corpus 122/798. Every baseline SVG, ordered diagnostic, inheritance flag and saved package matches both candidate runs. No SVG byte or node-count growth is introduced. Native 47-case/669-glyph assertions pass in the full suite. Separately, 101,310 standalone shaping records and 1,728 full reflected layout/DOM records are byte-identical; each layout side is run twice.

Small, large and image-heavy [preservation checks](benchmarks/2026-10-04-ordered-atoms-layout-12-cycle2-preservation.json) pass part preservation, deterministic saves and saved-file reopened SVG equality. The late-control outputs also match twice. Independent python-pptx reopen/traversal checks total 426 (417 main proof, 6 preservation, 3 control). Focused tests cover NFC/ligatures, expansion, repeated/reordered ranges and control segmentation in registered and explicit fallback-metrics modes, with baseline-derived exact width bits, wrap lines, ordered diagnostics and unchanged DOM.

Cycle 2 passes swift test --jobs 2: 1,151 tests/163 suites plus 18 layout tests/3 suites; Release build and git diff --check pass. Actual run/span strides remain 112/144 bytes. The root owns integrated Lectern/native/GUI verification. The [verification manifest](benchmarks/2026-10-04-ordered-atoms-layout-12-verification.json) pins source, toolchain, binaries, input fonts, raw receipts, proofs, assembly and retained cycle 1 history. Physical artifacts are retained under .build/perf22-ordered-atoms, with cycle 2 in its own subdirectory.

This is a bounded non-ASCII layout optimization, not evidence of historical cumulative recovery, fallback improvement, universal nonregression, clean-host behavior or cross-platform speed.
