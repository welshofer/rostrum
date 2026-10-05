# S19 partial custom table edges: measured cost and preservation

Independent source, protocol and final numeric/evidence reviews approved this bounded fidelity tradeoff with its measured costs retained. **This fidelity change has material observed render and memory costs.** The native deck slowed **+8.188% [95% bootstrap interval +4.511%, +10.315%]**. Partial-style tables slowed **+11.369% [+9.045%, +13.116%]** at 20×10, **+14.392% [+11.427%, +16.104%]** at 100×20, and **+13.338% [+11.525%, +14.960%]** at 200×50. All four had 10/10 slower pairs (`p=0.001953125`). Large-table median process RSS increased **6.508 MiB**. These results are not dismissed as noise or a speedup.

The unchanged unresolved-reference control also slowed **+3.354% [+2.274%, +4.982%]**. The newly admitted grid-line-color profile slowed **+1.833% [+0.929%, +2.921%]**, and the unchanged rejected collinear-transition control slowed **+0.652% [+0.157%, +1.549%]**. Each had 9/10 slower pairs (`p=0.021484375`). These controls show that observed cost is not limited to extra emitted lines. Canonical, Unicode and retained S18 profile intervals all cross zero; their adverse upper bounds remain unresolved.

Whole-process median RSS differences span **-0.109 to +6.508 MiB**; the captured native deck adds 0.578 MiB and the 100×20 partial table adds 0.453 MiB. Process peaks do not isolate resolver allocations, retained SVG strings or allocator behavior. Sampled WindowServer load was **25.2%–38.3%**, backupd **45.1%–135.8%**, and Photos/Spotlight **0%**. Agents paused builds, tests and GUI work, but ambient user/background activity was uncontrolled. The consistent adverse directions remain reported under that qualification.

## Sources and preservation

Baseline `a3766dbbff72447538037ea4c60015c74c50bfaf` uses exact retained matching accepted S18 Release products, Sources `59c7beb3d5e49ebf49cecb361a36f5ce53b9b7b1`. Original source/compiler/object/module/helper pins are verified; this is not a new baseline build. Candidate `a9776a1741b3ede7c7a8d9daac3ca131731ca6b5` adds engine `85e1e3946f9d34a93e500cd977e4741e249a8425` and documentation-only `dc40a98b09d0db7c132c82c9e8f41b12dd4c5638`. Only `TableStyleResolver.swift` and `SVGRenderer.swift` differ in production; S20 work is excluded. Candidate Release completed in 57.05 seconds. Full tests passed **1,189 library tests / 173 suites** and **18 RostrumLayout tests / 3 suites**. Root owns the integrated app/native/platform gate.

The resolver supplies a black 1-point cardinal edge only when an actual package/inline custom definition has no applicable declaration. Present empty lines, noFill, unresolved wrappers and direct overrides retain their meaning. Built-in, unknown and absent applied-style behavior is unchanged. A separate join extension admits unmerged LTR profiles with constant color and width along each grid line; unsupported collinear transitions retain the prior path. The finite native reference covers **12 cases, 72 body glyphs, 49 intervals and 15 fills**. It is separate from the performance stress inputs and source counterfactual.

Fresh proof covers **187 cases / 883 slides**, each in baseline and two candidate processes: **561 independent helper runs and python-pptx reopens**. Saved packages, ordered issues and inheritance reports are exact; candidate repeats match. Actual complete non-line SVG trees—including every fill, glyph/text node and attribute—remain exact. **Nine cases / 66 SVGs** change borders. All nine prior S18 native/profile inputs and the new empty/noFill/unresolved/direct-override/rejected-transition controls are fully byte-identical.

Fourteen public border dumps isolate **24,295 nil-to-black-1-point logical cardinal edges**. A separate source check requires actual custom definitions and absence of direct, active own-region and active neighbor-region declarations before authoring each edge in a retained counterfactual. Structural XML whitelisting proves all other values, child order and package parts unchanged. **18 counterfactual renders** require candidate SVGs to match the original candidate byte for byte; remaining differences on **65 SVGs** are only endpoints/paint order, with exact line counts and all non-coordinate paint attributes. The native deck contributes 55 defaults and the three scaling cases 400, 3,940 and 19,900. This explains intended paint changes without treating counterfactuals as native evidence.

Older changed corpus files are `DoubleTableBorders/style-precedence.pptx` and `NativeTableStyles/native-styles.pptx`, each exercised in fallback and registered modes. Their 60 changed SVGs add no default edges; only the new per-grid-line join path changes endpoints/order. Every original and counterfactual output remains retained. Fixed small, large-table and image-heavy preservation passes with six additional external reopens; **101,310 shaping records and 1,728 layout records** are exact across baseline and two candidate runs. Focused tests cover live style/default/direct/alias/reference/import behavior; no persistent cache or DOM mutation was introduced by this measurement work.

## Frozen campaign

One approved **594-child** campaign completed in **148.14 seconds**: canonical 110, Unicode 66 and native/custom 418. Exact receipt wall time is `148.13580429199s`; the later completion-log reading is `148.13597087498s`, after receipt serialization. Neither is a sum of child timers. Every workload uses one excluded warmup pair and ten alternating retained fresh-process pairs. No adaptive rerun occurred.

Canonical/Unicode helpers and all nine S18 files are unchanged. Ten new files comprise the captured S19 deck, three partial-style scales, four separate 20×10 suppression/override controls, and admitted/rejected 100×20 grid-color profiles. Scaling tables keep 24×12-point cells, larger than the maximum 3-point stroke; the largest stress table extends beyond the canvas and is not an authored slide design. The same accepted table helper renders the original deck before mutation. Embedded font registration and exact byte verification occur outside rendering. Subsequent first-slide/reopen/traversal/save phases remain separate; no new fitting phase was added.

All **306 measured phases** remain reported; **28 render/richtext-fitting comparisons** are primary. Statistics use 100,000 median bootstrap resamples, seed 20261004, and exact two-sided sign tests excluding ties. They are exploratory and unadjusted for multiplicity. Negative deltas mean candidate faster.

| Workload / phase | Baseline → candidate median ms | Paired median Δ [95% interval] | Faster pairs | Sign p | RSS Δ MiB |
|---|---:|---:|---:|---:|---:|
| canonical/table-200x50/render | 181.9767 → 181.5904 | -0.731% [-1.666, +0.987] | 7/10 | 0.34375000 | -0.047 |
| canonical/table-20x10/render | 3.7403 → 3.7939 | +1.166% [-0.371, +3.732] | 3/10 | 0.34375000 | -0.109 |
| canonical/shaped-table-100x20/render | 63.0207 → 63.2860 | +0.423% [-0.294, +1.708] | 3/10 | 0.34375000 | +0.055 |
| canonical/richtext-fit/render | 2.5661 → 2.5735 | -0.540% [-1.119, +2.870] | 6/10 | 0.75390625 | -0.031 |
| canonical/richtext-fit/richtext-fitting | 9.7580 → 9.7374 | -0.218% [-0.936, +0.580] | 6/10 | 0.75390625 | -0.031 |
| canonical/slides-10/render | 0.5537 → 0.5636 | +1.305% [-2.269, +2.862] | 4/10 | 0.75390625 | -0.070 |
| supplement/unicode-latin.pptx/render | 119.7164 → 120.0047 | +0.268% [-1.140, +1.197] | 4/10 | 0.75390625 | +0.164 |
| supplement/mixed-rtl.pptx/render | 122.0680 → 121.9969 | +0.075% [-1.065, +0.835] | 5/10 | 1.00000000 | +0.312 |
| supplement/long-combining.pptx/render | 390.5317 → 391.5769 | +1.286% [-1.097, +3.035] | 4/10 | 0.75390625 | +0.156 |
| native/native-table-joins18-v1.pptx/render | 4.5308 → 4.6035 | +1.477% [-1.152, +3.883] | 4/10 | 0.75390625 | -0.078 |
| native/ltr-single-100x20.pptx/render | 51.9617 → 52.2447 | +0.707% [-0.366, +2.050] | 3/10 | 0.34375000 | -0.047 |
| native/rtl-single-100x20.pptx/render | 52.1580 → 52.4640 | +0.947% [-0.200, +2.383] | 3/10 | 0.34375000 | -0.031 |
| native/axis-colors-100x20.pptx/render | 52.1236 → 52.1298 | -0.275% [-1.268, +0.912] | 5/10 | 1.00000000 | -0.047 |
| native/horizontal-merges-100x20.pptx/render | 36.7089 → 36.5051 | +0.010% [-1.601, +0.886] | 5/10 | 1.00000000 | -0.008 |
| native/vertical-merges-100x20.pptx/render | 36.8186 → 36.6032 | -0.881% [-2.252, +0.498] | 7/10 | 0.34375000 | -0.008 |
| native/reject-rtl-colors-100x20.pptx/render | 51.7236 → 51.6993 | +0.211% [-0.859, +0.797] | 4/10 | 0.75390625 | -0.039 |
| native/reject-merge-colors-100x20.pptx/render | 36.3454 → 36.4334 | +1.101% [-0.850, +1.938] | 3/10 | 0.34375000 | -0.055 |
| native/uniform-100x20.pptx/render | 51.8368 → 51.7854 | -0.036% [-0.834, +1.486] | 5/10 | 1.00000000 | -0.031 |
| native/native-table-style-fallback19-v1.pptx/render | 3.3847 → 3.6532 | +8.188% [+4.511, +10.315] | 0/10 | 0.00195312 | +0.578 |
| native/partial-20x10.pptx/render | 5.4104 → 5.9923 | +11.369% [+9.045, +13.116] | 0/10 | 0.00195312 | +0.000 |
| native/partial-100x20.pptx/render | 35.3392 → 40.1066 | +14.392% [+11.427, +16.104] | 0/10 | 0.00195312 | +0.453 |
| native/partial-200x50.pptx/render | 167.5731 → 189.9302 | +13.338% [+11.525, +14.960] | 0/10 | 0.00195312 | +6.508 |
| native/explicit-empty-20x10.pptx/render | 4.8735 → 4.9192 | +0.834% [-1.180, +1.878] | 3/10 | 0.34375000 | -0.016 |
| native/explicit-noFill-20x10.pptx/render | 5.0169 → 4.9458 | -0.802% [-3.725, +0.341] | 8/10 | 0.10937500 | -0.023 |
| native/unresolved-20x10.pptx/render | 4.8651 → 5.0216 | +3.354% [+2.274, +4.982] | 1/10 | 0.02148438 | -0.008 |
| native/direct-override-20x10.pptx/render | 7.1398 → 7.1757 | +0.569% [-1.631, +1.605] | 4/10 | 0.75390625 | -0.008 |
| native/grid-line-constant-100x20.pptx/render | 51.8089 → 52.6519 | +1.833% [+0.929, +2.921] | 1/10 | 0.02148438 | -0.008 |
| native/reject-collinear-transition-100x20.pptx/render | 51.5973 → 52.0504 | +0.652% [+0.157, +1.549] | 1/10 | 0.02148438 | -0.055 |

Of 278 secondary intervals, 15 are wholly positive and 8 wholly negative; every value remains in the appendix. Opening, traversal and serialization results are not automatically attributed to border resolution, and sub-millisecond percentages require their absolute times. No cumulative recovery, universal nonregression, memory improvement or cross-platform claim is made.

## Original-render SVG sizes

| Input | Baseline bytes | Candidate bytes | Delta |
|---|---:|---:|---:|
| native-table-joins18-v1.pptx | 2038996 | 2038996 | +0 |
| ltr-single-100x20.pptx | 1942663 | 1942663 | +0 |
| rtl-single-100x20.pptx | 1942764 | 1942764 | +0 |
| axis-colors-100x20.pptx | 1942663 | 1942663 | +0 |
| horizontal-merges-100x20.pptx | 1481055 | 1481055 | +0 |
| vertical-merges-100x20.pptx | 1477089 | 1477089 | +0 |
| reject-rtl-colors-100x20.pptx | 1942175 | 1942175 | +0 |
| reject-merge-colors-100x20.pptx | 1480607 | 1480607 | +0 |
| uniform-100x20.pptx | 1942785 | 1942785 | +0 |
| native-table-style-fallback19-v1.pptx | 2031280 | 2036196 | +4916 |
| partial-20x10.pptx | 1097100 | 1118050 | +20950 |
| partial-100x20.pptx | 1890039 | 2088209 | +198170 |
| partial-200x50.pptx | 5426304 | 6424314 | +998010 |
| explicit-empty-20x10.pptx | 1077241 | 1077241 | +0 |
| explicit-noFill-20x10.pptx | 1077241 | 1077241 | +0 |
| unresolved-20x10.pptx | 1077241 | 1077241 | +0 |
| direct-override-20x10.pptx | 1118029 | 1118029 | +0 |
| grid-line-constant-100x20.pptx | 1942175 | 1942663 | +488 |
| reject-collinear-transition-100x20.pptx | 1942175 | 1942175 | +0 |

The 200×50 partial table grows by **998,010 bytes** (5,426,304 → 6,424,314); 100×20 grows by 198,170 and 20×10 by 20,950. The native deck adds 4,916 bytes and the grid-line profile adds 488. These exact markup costs include intended border paint. They do not by themselves explain all runtime or RSS differences. Saved edited packages match across builds; source preservation is proved separately.

Raw samples: [canonical](benchmarks/2026-10-04-table-custom-edges-layout-19-canonical-paired.json), [supplement](benchmarks/2026-10-04-table-custom-edges-layout-19-supplement-paired.json), [native](benchmarks/2026-10-04-table-custom-edges-layout-19-native-paired.json). [Primary summary](benchmarks/2026-10-04-table-custom-edges-layout-19-summary.json), [all 306-phase appendix](benchmarks/2026-10-04-table-custom-edges-layout-19-APPENDIX.md), [all-phase JSON](benchmarks/2026-10-04-table-custom-edges-layout-19-all-phase-analysis.json), [host load](benchmarks/2026-10-04-table-custom-edges-layout-19-host-load.json), [frozen plan](benchmarks/2026-10-04-table-custom-edges-layout-19-timing-plan.json), [semantic classification](benchmarks/2026-10-04-table-custom-edges-layout-19-semantic-classification.json), [source whitelist](benchmarks/2026-10-04-table-custom-edges-layout-19-counterfactual-whitelist.json), and [verification](benchmarks/2026-10-04-table-custom-edges-layout-19-verification.json).

Physical products, source snapshots and complete output proofs remain in `.build/perf31-table-custom-edges/`. The export wrapper maps tracked byte copies to retained originals. Original readiness, preflight verification, timing plan and raw records are immutable; accepted S18 evidence remains untouched.
