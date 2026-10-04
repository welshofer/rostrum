# Native marker fidelity: measured cost after projection

**Cycle2 retains +2.777%/+2.702% rendering costs for ordinary buNone controls and +1.136% for placeholders.** It improves the primary marker deck and ordinary inherited ASCII/Unicode controls. Independent review accepts cycle2 as a bounded fidelity tradeoff with these residual costs; cycle1 stays **WITHHELD**. These measurements do not establish universal nonregression or complete recovery.

The accepted perf13 baseline is source 2e57a2d, Sources tree 1fed769a7817b8da2c1381828dd6db5e364f0e81. Cycle1 marker source is bda2254 (equivalent 679cf5b); optimized cycle2 source is c522a9dacef797697c7b860ec1884dd84cced35b, Sources tree dda66f4a098cb995b6aa75e09e1e9d0dee4aa482. Both measured candidates exclude the separately accepted Table.cell acquisition change. The later integrated root HEAD in raw runner metadata does not replace frozen binary provenance.

The optimization projects inherited marker properties without copying unrelated master subtrees. It preserves the marker fidelity semantics: cycle2 SVG, ordered diagnostics, inheritance flags and saved packages are byte-identical to cycle1 across 148 cases/842 slides. No marker-policy, geometry, fixture tolerance or canonical driver change is part of the optimization.

Each cycle ran once against the same retained baseline: 418 fresh children, ten alternating retained pairs plus one excluded warmup pair per workload. Canonical 110, supplementary 66 and native 242 retain identical inputs, scenario order, fonts, drivers, compiler flags and launch-environment semantics. Native embedded faces are byte-verified before render timing; loading, font registration and saving are separate phases. Cycles ran in different windows, so their percentage differences are not a matched cycle1-versus-cycle2 optimization measurement.

## Primary findings

Negative deltas favor the candidate. These are median paired candidate/baseline ratios; the full records also report the distinct ratio of separate medians. Intervals are deterministic percentile bootstrap medians from 100,000 pair resamples, seed 20261004. Exact two-sided sign tests exclude ties. All 207 phase comparisons are exploratory and unadjusted for multiplicity.

| Workload/phase | Cycle1 paired Δ | Cycle2 paired Δ [95% interval] | Cycle2 faster/10 | Sign p |
|---|---:|---:|---:|---:|
| ordinary-buNone-200.pptx/render | +9.611% | +2.777% [+0.918,+4.844] | 1 | 0.02148438 |
| ordinary-buNone-large-style-200.pptx/render | +134.043% | +2.702% [+1.258,+4.761] | 0 | 0.00195312 |
| ordinary-inherited-bullet-ascii-200.pptx/render | +10.278% | -4.948% [-6.135,-2.802] | 10 | 0.00195312 |
| ordinary-inherited-bullet-unicode-200.pptx/render | +4.710% | -3.801% [-5.106,-2.707] | 10 | 0.00195312 |
| placeholder-inherited-bullet-200.pptx/render | +0.302% | +1.136% [+0.666,+2.304] | 1 | 0.02148438 |
| native-list-markers-v2.pptx/render | -4.037% | -8.127% [-9.353,-5.816] | 10 | 0.00195312 |
| native-list-markers-followup-v1.pptx/render | +1.693% | +0.972% [+0.041,+2.570] | 2 | 0.10937500 |
| shaped-table-100x20/render | +1.005% | +0.450% [-0.363,+0.735] | 3 | 0.34375000 |
| richtext-fit/richtext-fitting | -1.183% | +0.834% [-0.317,+1.402] | 4 | 0.75390625 |

The two buNone costs retain positive intervals; ordinary shapes are 9/10 slower and the large-style control 10/10 slower. Placeholder rendering is also 9/10 slower. These are explicit remaining costs, not dismissed as noise. The primary marker deck and both ordinary inherited-bullet controls are 10/10 faster. Followup has a positive bootstrap interval but only 8/10 slower, sign p=.109375; its mixed uncertainty remains. Every canonical and supplementary primary interval crosses zero, leaving possible regressions unresolved.

All 20 primary rows are retained in the [cycle2 original report](benchmarks/2026-10-04-native-marker-layout-14-cycle2-report.md) and primary analysis JSONs. The [cycle2 all-phase appendix](benchmarks/2026-10-04-native-marker-layout-14-cycle2-appendix.md) reports every 207 comparison, including the 187 secondary phases: 14 intervals are wholly positive and 11 wholly negative. Absolute milliseconds, all paired deltas and every raw phase remain available; opening/saving/traversal changes are not attributed automatically to marker rendering.

Whole-process RSS is mixed: registered rendering +0.0625MiB, native eligibility +0.1875MiB and placeholders +0.1016MiB, versus primary marker −2.8594MiB and ordinary inherited ASCII/Unicode −0.8125/−0.8281MiB. RSS includes opening, fonts, rendering, saving and allocator retention; it cannot isolate projection allocations or justify a general memory claim. All cycle2 native SVG byte counts equal cycle1, including primary marker 4,491,949 bytes, followup 2,460,669, ordinary ASCII 1,069,981 and ordinary Unicode 1,064,581. Every paired saved-package hash matches across baseline/candidate repetitions. Full native byte comparisons remain in the original report.

## Host load and preservation

Cycle1 execution receipt records 75.2337566660135s (final post-write log 75.23389283299912s); cycle2 records 74.32129858399276s (log 74.32157116697636s). Each run completed all 418 children without adaptive repetition. Separate start/during/pool-end/end snapshots show WindowServer 15.1–29.1% and backupd 1.6–134.1% in cycle1; WindowServer 28.4–30.4% and backupd 41.2–135.1% in cycle2. Photos/Spotlight are 0% in sampled snapshots. Agent builds/tests/GUI paused, but background load remained uncontrolled. Snapshots cannot establish continuous isolation or remove bias. No system settings changed.

Cycle2 proof executes 296 fresh corpus candidate processes and 305 external reopens (296 corpus, 9 fixed preservation). It separately rehashes 296 historical baseline/cycle1 artifact sets; those are reuse, not fresh proof executions. Small/large/image-heavy fixed preservation passes exact artifacts for baseline/cycle1/cycle2, deterministic saved packages, unchanged part payloads and reopened SVGs. Standalone shaping 101,310 combined records and layout/DOM 1,728 records, candidate twice, equal the accepted baseline. Source-pinned worker tests cover 24 marker cases/277 visible glyphs/3 omissions and 47 prior placement cases, with 1,162 library tests plus 18 layout tests passing. Root owns integrated application/GUI gates; these library receipts do not assert their completion.

## Retained evidence

- **Cycle1 WITHHELD:** [original report](benchmarks/2026-10-04-native-marker-layout-14-cycle1-report.md), [all 207-phase additive appendix](benchmarks/2026-10-04-native-marker-layout-14-cycle1-appendix.md), [canonical raw](benchmarks/2026-10-04-native-marker-layout-14-cycle1-canonical-paired.json), [supplementary raw](benchmarks/2026-10-04-native-marker-layout-14-cycle1-supplement-paired.json), [native raw](benchmarks/2026-10-04-native-marker-layout-14-cycle1-native-paired.json), [original manifest](benchmarks/2026-10-04-native-marker-layout-14-cycle1-verification.json).
- **Cycle2 accepted bounded fidelity tradeoff:** [canonical raw](benchmarks/2026-10-04-native-marker-layout-14-cycle2-canonical-paired.json), [supplementary raw](benchmarks/2026-10-04-native-marker-layout-14-cycle2-supplement-paired.json), [native raw](benchmarks/2026-10-04-native-marker-layout-14-cycle2-native-paired.json), [all 207 analysis](benchmarks/2026-10-04-native-marker-layout-14-cycle2-all-phase-analysis.json), [exact output proof](benchmarks/2026-10-04-native-marker-layout-14-cycle2-corpus-proof.json), [original manifest](benchmarks/2026-10-04-native-marker-layout-14-cycle2-verification.json).
- [Tracked export manifest](benchmarks/2026-10-04-native-marker-layout-14-verification.json) maps every byte-identical copy to its original path/hash. Original manifests retain their original scratch path context and review status at capture; final acceptance is recorded only in this report and the export wrapper. Historical report relative links also refer to that scratch context. This report supplies navigable tracked links.

Original physical evidence remains in .build/perf25-marker-cycle1, its additive followup directory and .build/perf26-marker-cycle2. Their manifests retain 93/115 pins respectively; cycle2 also verifies 10,741 artifact hashes including explicitly reused history. No production source, input, timing sample or original receipt was changed while preparing this documentation. Residual buNone/placeholder costs, followup uncertainty, mixed RSS and background load remain explicit limits; no universal, historical, cross-platform or clean-host recovery claim is made.
