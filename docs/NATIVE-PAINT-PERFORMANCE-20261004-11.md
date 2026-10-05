# Native Latin paint fidelity: preservation and cost

**The fidelity change improved the registered-table workload in this run; native-deck timing remains inconclusive, and fitting retains a possible small cost.** This intentional fidelity change replaces stretched native ASCII text with explicit scalar positions and aligns measurement/paint sizing with the approved PowerPoint evidence. These are bounded observations under substantial background load, not a general speed or lower-memory claim.

Baseline: accepted perf10 e958499 (source 4118c97; root-equivalent 7fbb9bc). Candidate: b68f5a1 (engine 83a1c72; Sources identical to root e8841e3). The retained baseline module/object pair was not rebuilt. Both native helpers use identical source and Swift 6.4 Release flags. [Input/font pins](benchmarks/2026-10-04-native-paint-fidelity-11-native-inputs.json) retain the four accepted decks and exact embedded DejaVu regular/bold/oblique/serif bytes.

The separate native helper registers and byte-checks declared embedded faces before the render timer, then renders all nine slides. Its all-slide string retention is identical on both sides and must be considered when interpreting total-process RSS. Canonical five and existing supplementary three workloads and their drivers remain unchanged. The frozen comparison ran once in an explicitly granted window: 264 fresh child processes, ten alternating retained pairs plus one excluded warmup for each of twelve workloads. All succeeded in 55.17 seconds (exact 55.16647791699506); no adaptive rerun.

## Matched runtime and RSS

The registered table render was faster in 10/10 pairs: paired median −3.90%, bootstrap interval [−5.50%,−3.14%], exact two-sided sign-test p=.001953125. Its process RSS median decreased 3.125 MiB alongside the smaller SVG. This does not isolate allocation causes or establish a general memory benefit.

Fitting was slower in 8/10 pairs: paired median +2.45%, interval [−0.90%,+5.41%], sign-test p=.109375. Keep that unresolved directional cost visible. All other paired intervals cross zero; the accented/CJK lower endpoint is −0.0015% (rounds to −0.00%), so it is not a demonstrated regression or nonregression. Native RSS median differences range −0.297 to −0.539 MiB, while native runtime evidence remains inconclusive. Eligibility's ratio of separate medians and median paired ratio have opposite signs; the latter preserves pair correspondence. No historical percentages are added.

Canonical

| Workload/phase | Baseline→candidate ms | Median ratio Δ | Paired median Δ [95% interval] | Faster pairs | RSS Δ MiB |
|---|---:|---:|---:|---:|---:|
| Fallback 200×50 table | 192.1496→192.1825 | +0.02% | -0.24% [-0.95, +1.39] | 6/10 | -0.016 |
| Fallback 20×10 table | 3.8343→3.7369 | -2.54% | -2.40% [-6.21, +0.29] | 8/10 | +0.109 |
| Registered 100×20 table | 67.7053→64.8228 | -4.26% | -3.90% [-5.50, -3.14] | 10/10 | -3.125 |
| Rich-text render | 2.8698→2.8520 | -0.62% | +1.03% [-3.48, +5.96] | 4/10 | -0.141 |
| Rich-text fitting | 11.0746→11.2678 | +1.74% | +2.45% [-0.90, +5.41] | 2/10 | -0.141 |
| Ten slides | 0.6041→0.6210 | +2.80% | -0.94% [-2.71, +3.43] | 6/10 | +0.000 |

Supplementary

| Workload/phase | Baseline→candidate ms | Median ratio Δ | Paired median Δ [95% interval] | Faster pairs | RSS Δ MiB |
|---|---:|---:|---:|---:|---:|
| Accented/CJK | 126.4544→127.3299 | +0.69% | +1.06% [-0.00, +2.81] | 3/10 | -0.031 |
| Mixed RTL | 125.0953→124.9156 | -0.14% | -0.20% [-1.30, +1.47] | 6/10 | +0.125 |
| Long combining | 401.4117→402.3023 | +0.22% | -0.51% [-1.65, +3.10] | 6/10 | -0.086 |

Native embedded-font all-slide decks

| Workload/phase | Baseline→candidate ms | Median ratio Δ | Paired median Δ [95% interval] | Faster pairs | RSS Δ MiB |
|---|---:|---:|---:|---:|---:|
| Native primary (3 slides) | 3.5468→3.5617 | +0.42% | +0.74% [-3.56, +7.40] | 4/10 | -0.344 |
| Native autofit (2 slides) | 2.6589→2.5966 | -2.34% | -1.63% [-7.87, +3.09] | 6/10 | -0.359 |
| Native eligibility (3 slides) | 5.9706→5.8490 | -2.04% | +1.02% [-5.37, +2.65] | 4/10 | -0.539 |
| Native kerning (1 slide) | 2.1798→2.1677 | -0.55% | +0.12% [-7.91, +13.29] | 4/10 | -0.297 |

Negative deltas favor the candidate. RSS is whole-process peak median, including parsing, registered fonts, saved packages, helper-held SVG strings and other phases; the fitting row shares the render scenario's process RSS. Bootstrap intervals use 100,000 deterministic pair resamples (seed 20261004), with exploratory unadjusted intervals across workloads; raw paired deltas and sign tests are retained. [Canonical raw](benchmarks/2026-10-04-native-paint-fidelity-11-paired-macos.json), [supplementary raw](benchmarks/2026-10-04-native-paint-fidelity-11-supplement-paired-macos.json), [native raw](benchmarks/2026-10-04-native-paint-fidelity-11-native-paired-macos.json).

Seven [start/during/end snapshots](benchmarks/2026-10-04-native-paint-fidelity-11-host-load.json) show WindowServer 96.5–99.6%, photolibraryd 84.6–103.1%, managedcorespotlightd 2.1–34.3%, and backupd 0%. Root/workers paused builds, tests and GUI; no such competing jobs were observed in snapshots. Background load was substantial. This is not a clean-host benchmark, continuous isolation proof or evidence immune to shared-load bias. No user processes or system settings were altered.

## Verified output costs

| Workload | Baseline SVG bytes | Candidate SVG bytes | Difference |
|---|---:|---:|---:|
| Registered 100×20 table |5,277,230|4,730,430|−546,800|
| Native primary, 3 slides |3,041,127|3,041,651|+524|
| Native autofit, 2 slides |2,023,990|2,024,044|+54|
| Native eligibility, 3 slides |4,325,425|4,324,989|−436|
| Native kerning, 1 slide |1,011,840|1,011,963|+123|
| Native total, 9 slides |10,402,382|10,402,647|+265|

The registered table retains 16,800 text elements and 16,800 tspans; 16,800 textLength attributes are removed and 40,800 multi-position x entries are emitted. Native decks retain 111 text elements and 121 tspans: no per-glyph XML nodes were added. Their candidate emits 694 multi-position entries (including spaces; distinct from 669 native visible-glyph oracle records). Byte totals include embedded base64 font payloads. The [cost receipt](benchmarks/2026-10-04-native-paint-fidelity-11-cost.json) also reports payload-excluded bytes and per-deck position/attribute counts.

Actual compiled ResolvedTextRun stride remains 112 bytes (size 106→107). RichTextSpan stride rises 136→144 bytes, an 8-byte cost per stored span before array capacity or payload allocation. Scalar-position arrays exist only for admitted multi-scalar spans. These are type-layout facts, not RSS estimates. The earlier reference alternative uses the same pointer slot and adds a measured 32-byte minimal wrapper allocation; it was not implemented.

## Preservation

[Output proof](benchmarks/2026-10-04-native-paint-fidelity-11-output-proof.json) covers 134 cases and 824 slide comparisons: canonical 5 cases/14 slides, supplementary 3 cases/3 slides, native 4 cases/9 slides and corpus 122 cases/798 slides. Each candidate runs twice; every SVG, ordered diagnostic, inheritance flag and saved package repeats exactly. Every saved package matches the baseline bytes. All 134 input-to-candidate decoded ZIP payload checks pass, every scalar x-list is finite and matches its text scalar count, and concatenated SVG text is unchanged. Independent python-pptx reopens/traversals total 417, plus 6 for the fixed preservation inputs.

Cross-version SVG differences are retained, not hidden by an equality assertion: the registered canonical table, all four native decks, and 41 corpus/font-mode cases change. Fallback/small/fitting/ten-slide canonical cases and all three supplementary outputs remain byte-identical. The sole diagnostic addition is the explicit table stored-fontScale notice in native eligibility slide 3 (also encountered in its two corpus font modes); all existing diagnostics retain their order. [Validation details](benchmarks/2026-10-04-native-paint-fidelity-11-proof-validation.json).

The unchanged small, large and image-heavy [preservation checks](benchmarks/2026-10-04-native-paint-fidelity-11-preservation.json) pass part preservation, deterministic saves and reopened SVG equality. A further [native saved-file reopen proof](benchmarks/2026-10-04-native-paint-fidelity-11-native-reopen.json) confirms all nine candidate slides and diagnostics match after reopening their saved packages. Its expanded path manifest is used only for that proof; the paired native manifest stays unchanged.

Candidate Release build passed. 101,310 standalone shaping records remain byte-identical. Source equality with root e8841e3 and git diff --check passed. The engine lane supplied its full 1,148-test/162-suite plus 18-layout-test/3-suite green result; root owns integrated Core/app/native acceptance. Timing evidence is complete; independent evidence review and root integration acceptance remain pending.

Retained physical artifacts and scripts are under .build/perf21-native-paint in the fonts worktree. Earlier performance records and raw timing remain unchanged. This checkpoint measures the cost of intentional fidelity changes; it does not establish universal nonregression, historical recovery, clean-host behavior or cross-platform speed.
