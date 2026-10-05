# S21 table transitions: measured fidelity cost and preservation

Independent source and protocol reviews passed; final numeric/evidence review is pending. **All 35 primary paired bootstrap intervals include zero.** This run establishes neither a speedup nor nonregression. The newly admitted dense horizontal transition control is **+1.326% [95% interval −0.002%, +2.817%]**, with only 3/10 faster pairs (`p=0.34375`); its adverse upper bound remains unresolved. Dense vertical transitions are **+0.410% [−1.492%, +1.381%]**. Native vertical and horizontal files are **+0.218% [−1.909%, +2.256%]** and **+0.836% [−0.662%, +2.300%]**, respectively.

The unchanged input formerly labeled `reject-collinear-transition` is **newly admitted by S21**, not an unchanged rejection control. Its render result is **+1.051% [−1.281%, +2.409%]**. Other uncertain adverse observations include ten slides **+1.974% [−0.337%, +4.669%]**, direct override **+1.681% [−0.011%, +2.780%]**, and the near-budget control **+0.143% [−4.735%, +4.772%]**. None is erased by the zero-crossing interval. Canonical large fallback is +0.498% [−2.015%, +1.438%]; registered rendering is −0.715% [−1.777%, +0.419%]. There is no cumulative recovery or cross-platform claim.

Whole-process median RSS deltas range **−0.156 to +0.141 MiB**. These peaks include input/output, helper checks and allocator behavior; they do not isolate border admission or establish general memory improvement. Sampled **WindowServer was 38.7%–48.2%, backupd 16.9%–138.8%, photolibraryd 0%–1.7%, and managedcorespotlightd 0%–0.1%**. Root/agent build, test and GUI work was paused; uncontrolled background load remained. Periodic snapshots cannot establish continuous isolation or remove bias.

## Frozen source and correctness

Baseline `1a84f4f0af2e1566828959bcc64c4daed92aca09`, Sources `6d2e7cd2d2c057d4c9b916358882695cbe2c66d7`, uses retained matching accepted S20 Release products. All 112 baseline source files, compiler, object, modules and helper pins were checked; this is not a fresh baseline build. Candidate `73de22c42dc704c81f9fe8c03ee310def68c4dc3` applies only frozen engine `89aa1633cbbd07c152eb9e456c12e15686f7dbb8`. Candidate Sources `d555de4fa405e9c03217ebb966125a360cdd7f78` match root `33e484edf53f8b3ba817b28e6717d27fe265a94c` across 112 files. S15 renderer reuse and S20 paint reuse are included on both sides; later S22/S23 work is excluded.

Only `SVGRenderer.swift` differs in production. S21 removes the former constant-paint-per-grid-line requirement for the already bounded unmerged LTR join path. Existing exclusions and geometric safeguards remain; color and width transitions now use the existing signed donor endpoint calculation. No new cache or public API is introduced. Candidate Release completed in **57.92 seconds**; full tests passed **1,195 library tests / 175 suites** plus **18 RostrumLayout tests / 3 suites**. Root separately owns app, browser and native acceptance.

Fresh output proof covers **194 cases / 892 slides**, with **582 helper processes and independent python-pptx reopens** (baseline and two candidate runs). Exactly **five cases / seven SVGs** change: the prior collinear-transition stress slide; two slides in each new native vertical/horizontal deck; and the new dense vertical/horizontal stress slides. Every saved package, ordered diagnostic and inheritance record remains exact; repeated candidate artifacts remain exact. All other complete SVGs are byte-identical. The per-case classification lists every changed case and slide without dropping or renaming frozen inputs.

On every changed SVG, the complete actual non-line tree—including text, fonts and fills—is exact; line count and all non-coordinate paint attributes are exact. An independent Python signed-donor model verifies all ordered candidate endpoints from baseline line primitives and actual source guards. Every newly admitted table has explicit simple opaque cardinal declarations, positive cells larger than the maximum stroke, no merge, no RTL and no diagonal. This source-bounded semantic proof is not native validation. Separate native evidence covers **14 cases / 240 body glyphs**, including **13 admitted cases / 107 intervals** and one excluded colored-merge control that remains exact.

**101,310 shaping records and 1,728 layout records** match exactly across both sources and repeat candidate runs. Fixed small, large-table and image-heavy preservation passes with six additional external reopens. New inputs reproduce byte for byte. Original canonical/Unicode/file helper source and font bytes remain unchanged; native font registration and exact-byte verification occur outside measured rendering.

## One predeclared campaign

Exactly **748 children** completed once: canonical 110, Unicode 66, prior native/custom 418, cache controls 66, and transitions 88. Each workload used one excluded warmup pair and ten retained alternating fresh-process pairs; all five pools exited zero, with no adaptive rerun. Exact runner receipt elapsed time is `205.06162200000836` seconds (**205.06 seconds**). The final console observation is `205.06183141603833` seconds, read after receipt serialization. Neither value is the sum of child phase timers.

The four new workloads are two captured two-page native decks and vertical/horizontal 100×20 transition stress tables. The original 660-child scope, including unique-direct 200×50 and partial/complete template-budget controls, remains intact. The file helper renders original inputs before edits; verification lookup/acquisition, registration, save and reopen phases retain their prior scope. No cold-fit or universal table-complexity claim is made.

All **383 measured phase comparisons** are retained: **35 render/richtext-fitting primary comparisons** and **348 secondary comparisons**. Statistics use 100,000 paired-median bootstrap resamples with seed 20261004 (percentile indices 2499/97499), plus exact two-sided sign tests excluding ties. Results are exploratory and unadjusted for multiplicity. Negative values mean candidate faster.

| Workload / phase | Baseline → candidate median ms | Paired median Δ [95% interval] | Faster pairs | Sign p | RSS Δ MiB |
|---|---:|---:|---:|---:|---:|
| canonical/table-200x50/render | 178.8881 → 179.1710 | +0.498% [-2.015, +1.438] | 4/10 | 0.75390625 | +0.016 |
| canonical/table-20x10/render | 3.6233 → 3.6714 | +0.874% [-0.775, +1.743] | 4/10 | 0.75390625 | +0.117 |
| canonical/shaped-table-100x20/render | 62.4272 → 61.7963 | -0.715% [-1.777, +0.419] | 6/10 | 0.75390625 | +0.078 |
| canonical/richtext-fit/render | 2.3718 → 2.4010 | +0.290% [-3.061, +3.592] | 5/10 | 1.00000000 | -0.156 |
| canonical/richtext-fit/richtext-fitting | 9.2223 → 9.2408 | +0.886% [-1.224, +2.381] | 4/10 | 0.75390625 | -0.156 |
| canonical/slides-10/render | 0.5094 → 0.5202 | +1.974% [-0.337, +4.669] | 3/10 | 0.34375000 | +0.023 |
| supplement/unicode-latin.pptx/render | 116.4344 → 116.7498 | -0.003% [-0.261, +1.135] | 6/10 | 0.75390625 | +0.062 |
| supplement/mixed-rtl.pptx/render | 118.9091 → 119.1331 | -0.211% [-0.989, +0.693] | 6/10 | 0.75390625 | +0.047 |
| supplement/long-combining.pptx/render | 382.2525 → 382.0661 | +0.210% [-0.757, +1.828] | 4/10 | 0.75390625 | +0.141 |
| native/native-table-joins18-v1.pptx/render | 4.5757 → 4.5461 | -0.826% [-1.392, +0.128] | 8/10 | 0.10937500 | -0.125 |
| native/ltr-single-100x20.pptx/render | 52.1430 → 52.3561 | +1.039% [-1.256, +2.790] | 4/10 | 0.75390625 | -0.141 |
| native/rtl-single-100x20.pptx/render | 51.9489 → 52.3817 | +0.300% [-0.341, +1.344] | 4/10 | 0.75390625 | -0.133 |
| native/axis-colors-100x20.pptx/render | 52.6302 → 52.1549 | -0.479% [-1.675, +1.004] | 5/10 | 1.00000000 | -0.133 |
| native/horizontal-merges-100x20.pptx/render | 36.7000 → 36.5953 | -0.574% [-3.135, +1.610] | 6/10 | 0.75390625 | -0.016 |
| native/vertical-merges-100x20.pptx/render | 36.1653 → 36.4078 | +0.175% [-1.539, +2.105] | 5/10 | 1.00000000 | -0.008 |
| native/reject-rtl-colors-100x20.pptx/render | 51.6854 → 51.8274 | +0.018% [-0.583, +0.212] | 5/10 | 1.00000000 | -0.102 |
| native/reject-merge-colors-100x20.pptx/render | 36.4022 → 36.2639 | -0.411% [-1.052, +0.497] | 7/10 | 0.34375000 | -0.039 |
| native/uniform-100x20.pptx/render | 52.2733 → 52.0994 | -0.542% [-2.257, +0.843] | 6/10 | 0.75390625 | -0.086 |
| native/native-table-style-fallback19-v1.pptx/render | 3.6540 → 3.6347 | +0.105% [-1.270, +2.409] | 5/10 | 1.00000000 | -0.109 |
| native/partial-20x10.pptx/render | 5.4848 → 5.5081 | +0.126% [-1.340, +2.724] | 5/10 | 1.00000000 | -0.047 |
| native/partial-100x20.pptx/render | 33.8724 → 34.0229 | +0.654% [-0.826, +1.523] | 4/10 | 0.75390625 | -0.086 |
| native/partial-200x50.pptx/render | 159.5888 → 159.1240 | +0.203% [-0.852, +0.996] | 4/10 | 0.75390625 | -0.109 |
| native/explicit-empty-20x10.pptx/render | 4.9485 → 4.9904 | +0.636% [-0.586, +2.159] | 5/10 | 1.00000000 | -0.094 |
| native/explicit-noFill-20x10.pptx/render | 4.9934 → 4.9974 | +0.802% [-1.022, +3.800] | 4/10 | 0.75390625 | -0.094 |
| native/unresolved-20x10.pptx/render | 4.8725 → 4.9619 | +1.798% [-2.024, +2.589] | 3/10 | 0.34375000 | -0.039 |
| native/direct-override-20x10.pptx/render | 7.1896 → 7.3107 | +1.681% [-0.011, +2.780] | 3/10 | 0.34375000 | -0.094 |
| native/grid-line-constant-100x20.pptx/render | 52.8757 → 52.8094 | -0.165% [-0.834, +1.547] | 5/10 | 1.00000000 | -0.125 |
| native/reject-collinear-transition-100x20.pptx/render | 52.5419 → 52.6021 | +1.051% [-1.281, +2.409] | 4/10 | 0.75390625 | -0.078 |
| cache-controls/direct-unique-200x50.pptx/render | 252.1715 → 253.9625 | +0.420% [-0.732, +2.744] | 5/10 | 1.00000000 | -0.023 |
| cache-controls/budget-near-20x10.pptx/render | 16.5517 → 16.6246 | +0.143% [-4.735, +4.772] | 5/10 | 1.00000000 | -0.047 |
| cache-controls/oversize-bypass-6x6.pptx/render | 258.4260 → 259.0718 | +0.368% [-1.204, +1.972] | 4/10 | 0.75390625 | -0.031 |
| transitions/native-table-transitions21-v1.pptx/render | 4.7567 → 4.8238 | +0.218% [-1.909, +2.256] | 4/10 | 0.75390625 | -0.141 |
| transitions/native-table-transitions21-horizontal-v1.pptx/render | 4.3090 → 4.3542 | +0.836% [-0.662, +2.300] | 4/10 | 0.75390625 | -0.031 |
| transitions/vertical-transitions-100x20.pptx/render | 52.9005 → 53.2831 | +0.410% [-1.492, +1.381] | 4/10 | 0.75390625 | -0.086 |
| transitions/horizontal-transitions-100x20.pptx/render | 52.1740 → 52.8653 | +1.326% [-0.002, +2.817] | 3/10 | 0.34375000 | -0.109 |

Of 348 secondary intervals, 18 are wholly positive and 18 wholly negative. Every adverse outcome is retained. Opening, traversal, save and reopen changes are not automatically attributable to this one renderer branch; very small durations require attention to absolute values.

## SVG bytes and evidence

Across 26 file workloads, original-render byte counts are stable within each build. The newly admitted legacy transition input grows **1,942,175 → 1,942,663 bytes (+488)**; dense vertical grows **1,942,175 → 1,942,740 (+565)** and dense horizontal **1,924,595 → 1,925,053 (+458)**. Native files retain their byte counts while changing intended coordinates; equal sizes do not imply identical output. The other file workloads retain exact output as established separately by the full corpus proof. Saved package hashes match in every timed pair.

Raw samples: [canonical](benchmarks/2026-10-04-table-transitions-layout-21-canonical-paired.json), [supplement](benchmarks/2026-10-04-table-transitions-layout-21-supplement-paired.json), [native](benchmarks/2026-10-04-table-transitions-layout-21-native-paired.json), [cache-controls](benchmarks/2026-10-04-table-transitions-layout-21-cache-controls-paired.json), [transitions](benchmarks/2026-10-04-table-transitions-layout-21-transitions-paired.json). [Primary summary](benchmarks/2026-10-04-table-transitions-layout-21-summary.json), [all 383-phase appendix](benchmarks/2026-10-04-table-transitions-layout-21-APPENDIX.md), [all-phase JSON](benchmarks/2026-10-04-table-transitions-layout-21-all-phase-analysis.json), [host load](benchmarks/2026-10-04-table-transitions-layout-21-host-load.json), [SVG sizes](benchmarks/2026-10-04-table-transitions-layout-21-svg-byte-analysis.json), [frozen plan](benchmarks/2026-10-04-table-transitions-layout-21-timing-plan.json), [whole corpus proof](benchmarks/2026-10-04-table-transitions-layout-21-corpus-proof.json), [per-case semantic classification](benchmarks/2026-10-04-table-transitions-layout-21-semantic-classification.json), [root source equality](benchmarks/2026-10-04-table-transitions-layout-21-root-integration.json), and [verification](benchmarks/2026-10-04-table-transitions-layout-21-verification.json).

Physical binaries, modules, inputs and full per-case output proofs remain in `.build/perf33-table-transitions/`. The export wrapper maps tracked byte copies to retained originals. Prior evidence and original readiness/plan/proofs/raw timing remain immutable. Final independent numeric/evidence review is pending; no broad speedup or nonregression conclusion is accepted here.
