# S16: mixed-face exact spacing cost and preservation

Independent source, protocol, numeric and evidence review approved bounded acceptance of this fidelity cost, with the limitations below. This is a fidelity-cost comparison, not a speedup claim. The admitted 200-body mixed-face **warm fitting** workload observed **+2.110% [95% bootstrap +0.615%, +3.312%]**, with 8/10 slower pairs; its exact two-sided sign test is inconclusive (`p=0.109375`). Long-combining rendering also observed **+1.161% [+0.316%, +2.678%]**, 8/10 slower, `p=0.109375`. Both adverse intervals remain explicit; neither mixed statistical evidence nor source scope establishes nonregression.

The affected mixed-face render result is **+1.019% [−0.348%, +3.041%]**, and both captured native render results are inconclusive. Native/spacing whole-process median RSS increased **0.016–0.211 MiB**; across all workloads it ranged from **−0.281 to +0.211 MiB**. These are process peaks, not isolated allocations. Sampled WindowServer load was **36.7%–41.2%**, backupd **0%–0.2%**, and Photos/Spotlight **0%**. Agents paused builds/tests/GUI, but this was not a controlled clean host.

## Sources, footprint and proof scope

Fresh baseline `9ccc87e575b8edbe5096db09e48a38a6667c19f7` includes accepted PERF15 renderer reuse. Candidate `bba9c700921b33107a39920f8d05f0b325454c0f` adds only approved engine `1b5125b84ec396d68348217a0dad4734216417e2`; its only production difference is `RichTextLayout.swift`. Both complete Release builds, matching modules, objects, compiler and driver commands are retained. Candidate tests passed **1,174 library tests / 170 suites** and **18 RostrumLayout tests / 3 suites**; `git diff --check` passed. Root owns the integrated Lectern/native/platform gate.

The engine admits distinct actual registered faces for compatible, explicit point spacing in shape context only when their Windows ascent share and height are exactly equal, existing paint eligibility holds, and reduction/scale values are valid. Same-face and rejected profiles retain prior policy. The once-per-paragraph admission guard short-circuits before extra parsing for ordinary paragraphs; existing metric snapshots still populate only for native-spacing runs.

A footprint probe using the actual linked `FontFaceKey` and honestly mirrored local tuple declarations reports optional spacing-metric stride **40→56 bytes** on this arm64 Swift toolchain: two additional Double values, +16 bytes per stored metric entry. This is neither an actual allocator measurement nor a whole-process RSS attribution. Four qualified attribution profiles put layout at 1768/2872, 1863/2973, 1756/2900 and 1841/2956 main-thread samples for baseline mixed, baseline same-face, candidate mixed and candidate same-face respectively; `spacingMetric` itself had only 1, 2, 1 and 2 inclusive samples. Nested sample shares are not paired timings or predicted cost.

- **155 cases / 849 slides** were freshly rendered by baseline and candidate twice: **465 processes and external python-pptx reopens**. Saved packages are identical across builds, and candidate outputs repeat exactly.
- All prior **148 cases / 842 slides** remain byte-identical. Four new same-face/percentage/table/unequal-signature controls also remain exact. Only the two captured native decks and admitted mixed stress input change.
- Strict DOM comparison proves only vertical `<text>` origins change; every other tree node, text, x position, font resource, painted size and attribute remains exact. Ordered diagnostics differ only by removal of the now-supported mixed-face warning. Of **96 native visible glyphs in 12 cases**, **72 origins move** (16 base + 56 anchor glyphs); all 96 are checked against the existing native bounds. The stress input changes 1,600 line origins / 12,800 glyphs and is a performance workload, not an additional native fidelity claim.
- **101,310 shaping records** and **1,728 layout records** remain exact across three fresh variants. Small/large/image-heavy preservation passes on both builds, including **6** external reopens.
- In the separate public 40-point fitting proof, both TextFrame and Shape APIs change **77.5% font scale / 10% reduction → 100% / 0%**, with deterministic saves, exact reopen SVGs and **4** external reopens. This is computed fitting using the native-constrained extent, not a native-selected autofit oracle.

## Prelaunch correction and frozen campaign

V1 was frozen but never timed. Review identified that its mutating fit phase preceded render. V2 retains every V1 file/binary/plan/ready receipt unchanged, but measures the **original render first**. Frame acquisition and exact embedded-face registration are outside both timers. One fit pass then uses 200 retained frames after the completed render; this is explicitly **warm fitting**, with no cold-fit claim. Functional V2 output dumps prove the actual measured-render SVGs equal the original corpus proof. Post-fit saved packages, scales/reductions, paragraphs and geometry match V1 and both builds; 14 additional packages reopen independently. Only the two spacing helper executables were rebuilt for V2.

One approved **330-child** V2 campaign completed in **71.66 s**: canonical 110 + Unicode 66 + native/spacing 154. Seven new files comprise two captured native decks and five 200-body stress controls; each stress control has 8 lines × 4 styled runs per body (6,400 runs). They deliberately stack over one canvas to measure traversal and are not intended authored slide designs. Every workload uses one excluded warmup pair and ten alternating retained fresh-process pairs. No adaptive rerun occurred. All **173 phases** remain reported, with **21 primary** render/fitting comparisons; intervals use 100,000 bootstrap median resamples, seed 20261004, and exact two-sided sign tests excluding ties. These are exploratory, unadjusted comparisons.

The retained execution receipt records **71.662098541972 s** for campaign wall time, sampled after the final process snapshot and before writing that receipt. The completion log samples the clock again after the write and records **71.66224804200465 s**, about **0.1495 ms** later. Both round to 71.66 s. These are orchestration wall times, not sums of individual child measurements; the three recorded pool durations sum to 71.565076625033 s. No measurement was replaced or rerun.

| Workload / phase | Baseline → candidate median ms | Paired median Δ [95% interval] | Faster pairs | Sign p | RSS Δ MiB |
|---|---:|---:|---:|---:|---:|
| canonical/table-200x50/render | 178.0268 → 175.7062 | -1.263% [-3.310, -0.316] | 9/10 | 0.02148438 | +0.023 |
| canonical/table-20x10/render | 3.5591 → 3.5295 | -0.167% [-1.382, +1.501] | 5/10 | 1.00000000 | +0.156 |
| canonical/shaped-table-100x20/render | 60.8948 → 61.3959 | +0.725% [-0.185, +2.412] | 2/10 | 0.10937500 | -0.078 |
| canonical/richtext-fit/render | 2.3355 → 2.3348 | -0.473% [-2.299, +2.638] | 6/10 | 0.75390625 | -0.078 |
| canonical/richtext-fit/richtext-fitting | 9.0338 → 9.0158 | -0.616% [-1.840, +1.595] | 6/10 | 0.75390625 | -0.078 |
| canonical/slides-10/render | 0.5045 → 0.5155 | +2.658% [-1.222, +5.417] | 3/10 | 0.34375000 | +0.031 |
| supplement/unicode-latin.pptx/render | 116.0035 → 116.1314 | +0.414% [-0.567, +0.988] | 4/10 | 0.75390625 | -0.281 |
| supplement/mixed-rtl.pptx/render | 118.8247 → 118.7772 | -0.825% [-1.291, +0.764] | 6/10 | 0.75390625 | +0.109 |
| supplement/long-combining.pptx/render | 381.8648 → 383.2486 | +1.161% [+0.316, +2.678] | 2/10 | 0.10937500 | -0.281 |
| native/native-mixed-face-spacing-v1.pptx/render | 2.3281 → 2.2909 | -1.542% [-3.286, +2.752] | 6/10 | 0.75390625 | +0.211 |
| native/native-mixed-face-spacing-anchors-v1.pptx/render | 2.5889 → 2.5322 | -2.078% [-2.877, +0.181] | 7/10 | 0.34375000 | +0.188 |
| native/mixed-exact-200.pptx/render | 33.7565 → 34.0721 | +1.019% [-0.348, +3.041] | 4/10 | 0.75390625 | +0.062 |
| native/mixed-exact-200.pptx/spacing-fitting | 18.3579 → 18.7625 | +2.110% [+0.615, +3.312] | 2/10 | 0.10937500 | +0.062 |
| native/same-face-exact-200.pptx/render | 33.0140 → 33.2251 | +0.854% [-0.518, +1.566] | 4/10 | 0.75390625 | +0.188 |
| native/same-face-exact-200.pptx/spacing-fitting | 18.1946 → 18.2997 | +0.742% [-0.876, +3.167] | 4/10 | 0.75390625 | +0.188 |
| native/mixed-percentage-200.pptx/render | 34.0143 → 34.1643 | +1.419% [-0.762, +3.074] | 4/10 | 0.75390625 | +0.141 |
| native/mixed-percentage-200.pptx/spacing-fitting | 129.6788 → 129.6682 | +0.429% [-1.670, +3.160] | 5/10 | 1.00000000 | +0.141 |
| native/mixed-table-200.pptx/render | 34.2189 → 34.0054 | -0.497% [-1.200, +0.066] | 8/10 | 0.10937500 | +0.016 |
| native/mixed-table-200.pptx/spacing-fitting | 37.7740 → 37.5156 | -0.101% [-1.320, +0.924] | 6/10 | 0.75390625 | +0.016 |
| native/unequal-signature-200.pptx/render | 34.0394 → 33.9839 | -0.333% [-1.595, +0.859] | 5/10 | 1.00000000 | +0.141 |
| native/unequal-signature-200.pptx/spacing-fitting | 18.6252 → 18.6627 | +0.890% [-2.046, +1.936] | 4/10 | 0.75390625 | +0.141 |

Of 152 secondary intervals, 7 are wholly positive and 3 wholly negative. They remain in the all-phase appendix. The large fallback direction is not attributed to a speed optimization: this change targets calibrated mixed-face spacing. Registered rendering, ten-slide rendering and most controls retain nonzero adverse upper bounds. No historical, cumulative, cross-platform, universal nonregression or memory improvement claim is made.

## Original-render SVG sizes

| Input | Baseline bytes | Candidate bytes | Delta |
|---|---:|---:|---:|
| native-mixed-face-spacing-v1.pptx | 1519631 | 1519631 | +0 |
| native-mixed-face-spacing-anchors-v1.pptx | 1523970 | 1523970 | +0 |
| mixed-exact-200.pptx | 2443596 | 2443594 | -2 |
| same-face-exact-200.pptx | 1937143 | 1937143 | +0 |
| mixed-percentage-200.pptx | 2443607 | 2443607 | +0 |
| mixed-table-200.pptx | 2515280 | 2515280 | +0 |
| unequal-signature-200.pptx | 2443596 | 2443596 | +0 |

Changes to vertical numeric values do not necessarily change byte counts. Saved source packages remain exact. Fitted packages are separately checked; they are not falsely compared to unmodified source bytes.

Raw: [canonical](benchmarks/2026-10-04-mixed-face-spacing-layout-16-canonical-paired.json), [supplement](benchmarks/2026-10-04-mixed-face-spacing-layout-16-supplement-paired.json), [native](benchmarks/2026-10-04-mixed-face-spacing-layout-16-native-paired.json). [Primary summary](benchmarks/2026-10-04-mixed-face-spacing-layout-16-summary.json), [all 173-phase appendix](benchmarks/2026-10-04-mixed-face-spacing-layout-16-APPENDIX.md), [all-phase JSON](benchmarks/2026-10-04-mixed-face-spacing-layout-16-all-phase-analysis.json), [host load](benchmarks/2026-10-04-mixed-face-spacing-layout-16-host-load.json), [V2 plan](benchmarks/2026-10-04-mixed-face-spacing-layout-16-timing-plan.json), [untimed V1 plan](benchmarks/2026-10-04-mixed-face-spacing-layout-16-v1-timing-plan.json), [output classification](benchmarks/2026-10-04-mixed-face-spacing-layout-16-output-classification.json), [post-fit V2 proof](benchmarks/2026-10-04-mixed-face-spacing-layout-16-v2-validation.json), and [verification](benchmarks/2026-10-04-mixed-face-spacing-layout-16-verification.json).

Physical evidence is retained in `.build/perf28-mixed-face-spacing/` and additive sibling `.build/perf28-mixed-face-spacing-v2/`. The tracked export wrapper maps exact copies to originals. Initial functional output-path correction is disclosed in the fit40 proof; it changed no bytes and caused no timing rerun.
