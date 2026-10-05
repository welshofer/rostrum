# S20 shared table-border paint reuse: gains, costs and preservation

Independent source, protocol, numerical and preservation reviews approve this **bounded target-workload improvement with explicit adverse controls and host-load limits**. **The targeted partial-style tables improve, with a small adverse direct-border result and unresolved controls.** Paired render changes are **−8.995% [95% bootstrap interval −9.790%, −7.130%]** at 20×10, **−15.599% [−17.625%, −14.886%]** at 100×20, and **−14.438% [−15.641%, −13.864%]** at 200×50. All three are faster in 10/10 pairs (`p=0.001953125`). Their separate baseline→candidate medians are 5.9952→5.4536 ms, 40.0408→33.6672 ms and 189.2138→161.6303 ms. Output is byte-identical.

**The axis-color direct-border control slows +0.947% [+0.566%, +1.747%], with 10/10 slower pairs (`p=0.001953125`)**: separate medians 51.5816→52.3680 ms. The unchanged mixed-RTL, prior native S18, RTL-table and rejected merge-color controls also have wholly positive bootstrap intervals, but only 8/10 slower pairs (`p=0.109375`): +0.581%, +2.034%, +0.957% and +2.712%, respectively. Both statistical summaries are retained; those adverse observations are not omitted or declared harmless.

The added unique-direct 200×50 control is **+0.965% [−0.179%, +1.470%]**; partial-budget admission is **−1.195% [−5.036%, +3.567%]** and oversized-template bypass is **−0.348% [−1.885%, +1.611%]**. All three remain inconclusive, including their adverse upper bounds. Canonical intervals also cross zero: large fallback is +1.783% [−0.507%, +3.732%] and registered table +0.713% [−0.545%, +1.273%]. This experiment supports only a bounded target-workload result, not universal nonregression or cumulative recovery of historical costs.

Whole-process median RSS differences span **-1.266 to +0.242 MiB**. Partial 200×50 is −1.180 MiB, but partial 20×10 and 100×20 are +0.016 and +0.047 MiB; the direct-unique control is −1.266 MiB while fallback is +0.242 MiB. These process peaks include input, output, helper checks and allocator behavior; they do not isolate the cache or establish a general memory benefit. Sampled **WindowServer was 39.1%–43.6% and backupd 60.0%–146.2%**; Photos/Spotlight were 0%. Agent builds, tests and GUI work were paused, but this was not a clean host. Snapshots cannot remove shared-load bias.

## Source and exact preservation

Baseline `007efa9c5b1c56af36d5251937fe95244ffaa289` uses retained matching accepted S19 Release products, Sources `11ead6fd725008f26757f839abda10aa97761adb`. All 111 original source files, compiler, object, module and helper pins were verified before applying S20; this is not a fresh baseline build. Candidate `20e4a3556724f20937fcbca7208728798b658fcd` applies only approved engine `3bab3d552ea016035921ce97671356152718ee05` and documentation `119b1c107ff9911bdc86241e0e86a7a323a3b087`. Candidate Sources `6d2e7cd2d2c057d4c9b916358882695cbe2c66d7` match root `5d3d888175d12f615a3f917e15d8c9b6a170f201` across all 112 production files, including prior S15 ordinary inherited-style reuse. The prototype worker baseline omitted that earlier change and its Debug binaries are excluded from this comparison.

Only `SVGRenderer.swift`, `TableStyleResolver.swift` and new `TableBorderPaintCache.swift` differ in production. A local cache reuses decoded paint for admitted, read-only style-border nodes during one table render. It retains owners to prevent recycled-identity hits, distinguishes cached nil from absent entries, caps entries at 216, and accounts for an estimated additional 512 bytes per border within the existing 1 MiB template-admission budget. Direct and unadmitted nodes bypass insertion. Maximum width is still updated for every nonnil paint use. There is no persistent cache, public API, or policy/geometry change.

Candidate Release completed in **58.56 seconds**. Full tests passed **1,193 library tests / 174 suites** and **18 RostrumLayout tests / 3 suites**. Focused source tests cover owner lifetime, cached nil, hard-cap overflow, direct edits, oversized unknown XML, shared/direct paint, maximum width, alpha, dashes, double lines, and renderer reuse after aliased style/theme/direct mutations. Root owns the integrated app, native and platform acceptance gate.

Fresh proof covers **190 cases / 886 slides** in baseline and two candidate processes: **570 helper runs and independent python-pptx reopens**. Every complete SVG, saved package, ordered diagnostic and inheritance artifact matches byte for byte, with zero changed artifacts. No text/paint stripping or counterfactual substitution is used. All S17–S19 native sources/references remain preserved; the three new stress controls add no native fidelity claims. Fixed small, large-table and image-heavy preservation passes with six more external reopens. **101,310 shaping records and 1,728 layout records** match exactly across baseline and two candidate runs.

An additional untimed probe links the actual candidate Debug module with `@testable import Rostrum` and inspects `RenderSession.ownsSharedBorder`. The 10,000-cell direct control has **0 shared / 40,000 unshared** border encounters. The 200-cell near-budget control has **40 shared / 760 unshared**, with **24 distinct admitted identities**. The 36-cell oversized control has **0 shared / 144 unshared**. Serialization is unchanged after each audit. These are resolution encounters, not renderer decode-call counts; the probe does not measure performance. They establish partial/complete estimated template-budget admission, not a real-workload 216-entry saturation claim. Initial probe compilation needed optional table unwrapping; its failed source/log are retained, and no production or campaign code changed.

## Frozen campaign

Exactly one **660-child** campaign completed in **187.27 seconds**. Exact receipt wall time is `187.26740933401743s`; completion-log time is `187.2675900000031s`, read after receipt serialization. Neither is a sum of child timers. The original S19 scope stays intact: canonical 110, Unicode 66 and native/custom 418 children. A separately labeled 66-child pool adds only three controls. Each workload uses one excluded warmup pair and ten retained alternating fresh-process pairs. All four pools exited zero; no adaptive rerun occurred.

The canonical runner and three helpers are unchanged. All 19 original file inputs, font bytes, iteration counts and measured scopes are preserved. The added controls are unique direct borders at 200×50, unknown 40,000-character comments on six style edges at 20×10 to force partial template-budget admission, and 1,100,000-character comments at 6×6 to force complete bypass without multiplying huge subtrees over 10,000 cells. Input generation was repeated byte-identically. These are finite stress cases, not a universal complexity or input-size guarantee.

Embedded font registration and exact font-byte verification remain outside render timing. Each file helper renders the original source before editing; first-slide/reopen/traversal/save phases remain separate, and no new fitting phase is added. Acquisition/verification scope is unchanged. All **339 measured phase comparisons** are retained; **31 render/richtext-fitting comparisons** are primary. Statistics use 100,000 median bootstrap resamples, seed 20261004, and exact two-sided sign tests excluding ties. They are exploratory and unadjusted for multiplicity. Negative deltas mean candidate faster.

| Workload / phase | Baseline → candidate median ms | Paired median Δ [95% interval] | Faster pairs | Sign p | RSS Δ MiB |
|---|---:|---:|---:|---:|---:|
| canonical/table-200x50/render | 177.7185 → 178.3483 | +1.783% [-0.507, +3.732] | 3/10 | 0.34375000 | +0.242 |
| canonical/table-20x10/render | 3.5890 → 3.6276 | +1.596% [-6.394, +5.378] | 4/10 | 0.75390625 | +0.141 |
| canonical/shaped-table-100x20/render | 61.9660 → 62.3563 | +0.713% [-0.545, +1.273] | 3/10 | 0.34375000 | +0.062 |
| canonical/richtext-fit/render | 2.3919 → 2.3888 | -1.540% [-4.011, +2.582] | 6/10 | 0.75390625 | +0.164 |
| canonical/richtext-fit/richtext-fitting | 9.2549 → 9.2084 | -0.425% [-1.823, +0.222] | 6/10 | 0.75390625 | +0.164 |
| canonical/slides-10/render | 0.5156 → 0.5130 | -0.821% [-2.783, +2.814] | 5/10 | 1.00000000 | +0.047 |
| supplement/unicode-latin.pptx/render | 116.5198 → 116.8570 | +0.388% [-0.289, +0.549] | 2/10 | 0.10937500 | -0.328 |
| supplement/mixed-rtl.pptx/render | 119.1671 → 119.6265 | +0.581% [+0.083, +1.684] | 2/10 | 0.10937500 | +0.172 |
| supplement/long-combining.pptx/render | 382.4724 → 381.5018 | +0.017% [-1.891, +0.856] | 5/10 | 1.00000000 | -0.344 |
| native/native-table-joins18-v1.pptx/render | 4.5095 → 4.5682 | +2.034% [+0.274, +4.058] | 2/10 | 0.10937500 | +0.086 |
| native/ltr-single-100x20.pptx/render | 51.8161 → 52.1957 | +0.707% [-1.370, +1.420] | 3/10 | 0.34375000 | +0.023 |
| native/rtl-single-100x20.pptx/render | 52.0062 → 52.2009 | +0.957% [+0.123, +2.834] | 2/10 | 0.10937500 | +0.047 |
| native/axis-colors-100x20.pptx/render | 51.5816 → 52.3680 | +0.947% [+0.566, +1.747] | 0/10 | 0.00195312 | +0.016 |
| native/horizontal-merges-100x20.pptx/render | 37.0843 → 36.9931 | +0.219% [-1.548, +1.611] | 5/10 | 1.00000000 | -0.023 |
| native/vertical-merges-100x20.pptx/render | 36.5679 → 37.0113 | +1.743% [-0.820, +4.624] | 3/10 | 0.34375000 | +0.000 |
| native/reject-rtl-colors-100x20.pptx/render | 51.6556 → 51.8100 | +0.590% [-0.527, +1.183] | 2/10 | 0.10937500 | +0.016 |
| native/reject-merge-colors-100x20.pptx/render | 36.1258 → 36.8926 | +2.712% [+0.088, +3.766] | 2/10 | 0.10937500 | -0.008 |
| native/uniform-100x20.pptx/render | 51.8521 → 52.2102 | +0.434% [-0.709, +1.875] | 3/10 | 0.34375000 | -0.008 |
| native/native-table-style-fallback19-v1.pptx/render | 3.6039 → 3.6668 | +1.548% [-0.151, +3.549] | 3/10 | 0.34375000 | +0.047 |
| native/partial-20x10.pptx/render | 5.9952 → 5.4536 | -8.995% [-9.790, -7.130] | 10/10 | 0.00195312 | +0.016 |
| native/partial-100x20.pptx/render | 40.0408 → 33.6672 | -15.599% [-17.625, -14.886] | 10/10 | 0.00195312 | +0.047 |
| native/partial-200x50.pptx/render | 189.2138 → 161.6303 | -14.438% [-15.641, -13.864] | 10/10 | 0.00195312 | -1.180 |
| native/explicit-empty-20x10.pptx/render | 4.9445 → 4.9574 | +0.303% [-0.566, +1.327] | 4/10 | 0.75390625 | -0.023 |
| native/explicit-noFill-20x10.pptx/render | 4.9659 → 5.0519 | +2.140% [-1.605, +3.893] | 3/10 | 0.34375000 | +0.000 |
| native/unresolved-20x10.pptx/render | 4.9252 → 4.9260 | +0.241% [-2.498, +1.124] | 5/10 | 1.00000000 | -0.062 |
| native/direct-override-20x10.pptx/render | 7.1467 → 7.2380 | +0.897% [-0.180, +1.922] | 3/10 | 0.34375000 | +0.031 |
| native/grid-line-constant-100x20.pptx/render | 52.6556 → 52.9766 | +1.047% [-0.515, +2.116] | 3/10 | 0.34375000 | -0.023 |
| native/reject-collinear-transition-100x20.pptx/render | 52.0544 → 52.2845 | +0.650% [-0.757, +1.124] | 3/10 | 0.34375000 | +0.000 |
| cache-controls/direct-unique-200x50.pptx/render | 250.9860 → 253.7685 | +0.965% [-0.179, +1.470] | 3/10 | 0.34375000 | -1.266 |
| cache-controls/budget-near-20x10.pptx/render | 16.3109 → 16.1652 | -1.195% [-5.036, +3.567] | 6/10 | 0.75390625 | +0.016 |
| cache-controls/oversize-bypass-6x6.pptx/render | 261.0336 → 260.8916 | -0.348% [-1.885, +1.611] | 5/10 | 1.00000000 | -0.055 |

Of **308 secondary intervals**, 16 are wholly positive and 15 wholly negative. Every comparison, including adverse outcomes, remains in the appendix. Opening, traversal and serialization results are not automatically attributed to paint decoding; sub-millisecond percentages must be read alongside absolute times. No cumulative recovery, universal nonregression, general memory improvement or cross-platform claim is made.

## SVG size and retained evidence

All 22 file workloads have identical original-render byte counts in every retained sample. The partial 200×50 table remains **6,424,314 bytes** on both builds; this optimization does not remove S19 fidelity markup. Complete SVG content identity is established separately by the corpus proof. The full byte table is retained in the linked JSON.

Raw samples: [canonical](benchmarks/2026-10-04-table-paint-reuse-layout-20-canonical-paired.json), [supplement](benchmarks/2026-10-04-table-paint-reuse-layout-20-supplement-paired.json), [native](benchmarks/2026-10-04-table-paint-reuse-layout-20-native-paired.json), [cache-controls](benchmarks/2026-10-04-table-paint-reuse-layout-20-cache-controls-paired.json). [Primary summary](benchmarks/2026-10-04-table-paint-reuse-layout-20-summary.json), [all 339-phase appendix](benchmarks/2026-10-04-table-paint-reuse-layout-20-APPENDIX.md), [all-phase JSON](benchmarks/2026-10-04-table-paint-reuse-layout-20-all-phase-analysis.json), [host load](benchmarks/2026-10-04-table-paint-reuse-layout-20-host-load.json), [frozen plan](benchmarks/2026-10-04-table-paint-reuse-layout-20-timing-plan.json), [whole-output proof](benchmarks/2026-10-04-table-paint-reuse-layout-20-corpus-proof.json), [actual budget audit](benchmarks/2026-10-04-table-paint-reuse-layout-20-budget-audit-receipt.json), [SVG sizes](benchmarks/2026-10-04-table-paint-reuse-layout-20-svg-byte-analysis.json), and [verification](benchmarks/2026-10-04-table-paint-reuse-layout-20-verification.json).

Physical products, source snapshots and complete output proofs remain in `.build/perf32-table-paint-reuse/`. The export wrapper maps tracked byte copies to retained originals. Original readiness, preflight verification, timing plan, raw records and accepted S19 evidence remain immutable. Independent numerical and preservation review accepted the bounded result. The additive audit-helper history map resolves the original source pin to its retained initial copy; original physical receipts remain unchanged.
