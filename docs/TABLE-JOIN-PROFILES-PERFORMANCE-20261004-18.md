# S18 table-join profiles: measured cost and preservation

Independent source, protocol and final numeric/evidence reviews approved this bounded fidelity tradeoff. **Every newly admitted native/profile render interval crosses zero.** Horizontal merges observed **+0.653% [95% bootstrap interval −1.606%, +2.145%]**, vertical merges **+0.872% [−0.721%, +2.106%]**, and the unchanged rejected merge/color control **+1.182% [−1.149%, +4.689%]**. These unresolved adverse upper bounds remain explicit. The captured native deck was −1.332% [−2.040%, +0.643%], RTL single-color −0.382% [−1.275%, +0.898%], and axis colors −0.186% [−1.281%, +1.213%]. This supports no speedup or universal nonregression claim.

Whole-process median RSS differences ranged from **-0.422 to +0.359 MiB** across all workloads. These are process peaks, not isolated allocation measurements. Sampled WindowServer load was **35.7%–46.6%**, backupd **0.1%–135.9%**, and Photos/Spotlight **0%**. Agents paused builds, tests and GUI work; other user/background processes were preserved. This was not a controlled clean host, and snapshots cannot remove shared-load bias.

## Sources and output proof

Baseline `ce8551e69350ba5f5808df1c2337e40add9548d2` has accepted S17 production Sources tree `d757ef297061474cd3faf2961e49e17877746fd3`. Its object, module, helpers and preservation executable are **exact retained copies of the matching S17 candidate Release products**, with original build/compiler/source pins verified; no new baseline build is claimed. Candidate `e8c8b1642635c7542e5e075f0a904c8bf908e0ea` adds engine `b5407e49f1173edeeb3285fcef6ad763840d3f79` only in `SVGRenderer.swift`. Candidate Release completed in 56.88 seconds. Both helper sets use the same compiler and flags. Full tests passed **1,183 library tests / 172 suites** and **18 RostrumLayout tests / 3 suites**. Root owns integrated app/native/platform validation.

The engine admits opaque solid single-color unmerged RTL grids, unmerged LTR grids with one consistent color per axis, and single-color LTR merges with one merge orientation. Existing dimension, topology, stroke and diagonal guards remain; horizontal RTL emission swaps logical signed extensions. Uniform profiles and unsupported combinations retain their prior paths. Eight independently captured cases on two slides establish the admitted paint profiles and preserve 112 body glyphs. Performance controls are not additional native evidence.

Fresh proof covers **177 cases / 872 slides**, with baseline plus two candidate runs: **531 helper processes and independent python-pptx reopens**. Saved packages, ordered diagnostics and inheritance reports are exact across builds; candidate repeats match. All **13 prior S17 inputs** and the four existing/rejected S18 controls are fully byte-identical.

**Seven cases / 12 SVGs change only border endpoints and paint order.** Every full non-line tree, including text and all attributes, is exact; line counts and all non-coordinate paint attributes are exact. Complete old/new line records and source table/profile descriptors remain retained. Changes comprise the two-slide native source, four admitted stress controls, and `DoubleTableBorders/style-precedence-rtl.pptx` slides 12, 15 and 16 (zero-based) in both fallback and registered corpus modes. This older RTL fixture is explicitly classified rather than waived or stripped broadly.

The fixed small, large-table and image-heavy preservation cases have exact SVG/package maps and **six further external reopens**. **101,310 shaping records and 1,728 layout records** match baseline and both candidate runs. Stress inputs reproduce byte for byte. No existing source, plan, raw timing or prior S17 evidence was overwritten.

## Frozen campaign

One approved **374-child** campaign completed in **100.03 seconds**: canonical 110, Unicode 66 and native/profile 198. Receipt elapsed time is `100.02530400001s`; the later completion-log reading is `100.02547079098s`, after receipt serialization. Neither is a sum of child timers. Each workload has one excluded warmup pair and ten alternating retained fresh-process pairs. No adaptive rerun occurred.

Canonical and Unicode drivers/inputs are unchanged. The table pool uses the captured native deck plus eight 100×20 controls: existing LTR single-color, newly admitted RTL single-color, axis colors, horizontal merges, vertical merges, rejected RTL+colors, rejected merge+colors and unchanged uniform. All stress tables explicitly apply NoStyleGrid. Physical dimensions exceed the largest 3-point stroke. Embedded DejaVu Sans registration and exact face-byte verification occur outside rendering. The accepted S17 table helper is unchanged: original rendering precedes any cell edit, with the later first-slide/reopen/edit-save phases separately retained. There is no new fitting phase.

All **196 measured phases** are reported; **18 render/richtext-fitting comparisons** are primary. Intervals use 100,000 median bootstrap resamples, seed 20261004. Exact two-sided sign tests exclude ties. These exploratory comparisons are not adjusted for multiplicity. Negative deltas mean candidate faster.

| Workload / phase | Baseline → candidate median ms | Paired median Δ [95% interval] | Faster pairs | Sign p | RSS Δ MiB |
|---|---:|---:|---:|---:|---:|
| canonical/table-200x50/render | 178.2198 → 176.3835 | -2.022% [-3.096, +0.082] | 7/10 | 0.34375000 | +0.062 |
| canonical/table-20x10/render | 3.5255 → 3.5254 | +0.388% [-0.419, +1.069] | 4/10 | 0.75390625 | +0.156 |
| canonical/shaped-table-100x20/render | 61.7822 → 61.5585 | -0.417% [-1.328, +1.143] | 6/10 | 0.75390625 | +0.047 |
| canonical/richtext-fit/render | 2.3715 → 2.4017 | +1.162% [-2.683, +4.414] | 3/10 | 0.34375000 | +0.039 |
| canonical/richtext-fit/richtext-fitting | 9.2307 → 9.2466 | +1.190% [-2.105, +4.284] | 4/10 | 0.75390625 | +0.039 |
| canonical/slides-10/render | 0.5286 → 0.5046 | -4.638% [-7.514, -1.821] | 8/10 | 0.10937500 | -0.016 |
| supplement/unicode-latin.pptx/render | 117.0325 → 116.9876 | -0.141% [-1.371, +0.858] | 5/10 | 1.00000000 | +0.359 |
| supplement/mixed-rtl.pptx/render | 119.7085 → 119.5169 | +0.036% [-0.751, +1.100] | 5/10 | 1.00000000 | -0.422 |
| supplement/long-combining.pptx/render | 384.3841 → 387.5813 | +0.417% [-0.930, +2.767] | 4/10 | 0.75390625 | +0.281 |
| native/native-table-joins18-v1.pptx/render | 4.5165 → 4.4970 | -1.332% [-2.040, +0.643] | 7/10 | 0.34375000 | +0.062 |
| native/ltr-single-100x20.pptx/render | 51.7505 → 51.9861 | +0.306% [-0.910, +1.036] | 4/10 | 0.75390625 | +0.031 |
| native/rtl-single-100x20.pptx/render | 51.7050 → 51.5114 | -0.382% [-1.275, +0.898] | 7/10 | 0.34375000 | +0.031 |
| native/axis-colors-100x20.pptx/render | 51.9279 → 51.8328 | -0.186% [-1.281, +1.213] | 5/10 | 1.00000000 | +0.016 |
| native/horizontal-merges-100x20.pptx/render | 36.1859 → 36.3466 | +0.653% [-1.606, +2.145] | 4/10 | 0.75390625 | -0.008 |
| native/vertical-merges-100x20.pptx/render | 35.9720 → 36.2065 | +0.872% [-0.721, +2.106] | 3/10 | 0.34375000 | -0.008 |
| native/reject-rtl-colors-100x20.pptx/render | 51.6930 → 51.3957 | -0.051% [-0.811, +0.711] | 5/10 | 1.00000000 | +0.016 |
| native/reject-merge-colors-100x20.pptx/render | 36.2003 → 36.6109 | +1.182% [-1.149, +4.689] | 4/10 | 0.75390625 | -0.016 |
| native/uniform-100x20.pptx/render | 52.6716 → 51.6362 | -0.950% [-2.550, -0.000] | 8/10 | 0.10937500 | +0.055 |

Of 178 secondary intervals, 2 are wholly positive and 14 wholly negative; all remain in the appendix. The unchanged uniform render interval ends at −0.000405%, which rounds to −0.000% in the table; its 8/10 faster pairs have inconclusive sign-test p=0.109375. Ten-slide rendering also has mixed evidence: −4.638% [−7.514%, −1.821%], 8/10 faster, p=0.109375. Neither is attributed as a table-profile speedup. Registered rendering, fallback, fitting and Unicode controls retain unresolved adverse bounds. No cumulative, historical, cross-platform or memory-improvement claim is made.

## Original-render SVG sizes

| Input | Baseline bytes | Candidate bytes | Delta |
|---|---:|---:|---:|
| native-table-joins18-v1.pptx | 2038996 | 2038996 | +0 |
| ltr-single-100x20.pptx | 1942663 | 1942663 | +0 |
| rtl-single-100x20.pptx | 1942175 | 1942764 | +589 |
| axis-colors-100x20.pptx | 1942175 | 1942663 | +488 |
| horizontal-merges-100x20.pptx | 1480607 | 1481055 | +448 |
| vertical-merges-100x20.pptx | 1476801 | 1477089 | +288 |
| reject-rtl-colors-100x20.pptx | 1942175 | 1942175 | +0 |
| reject-merge-colors-100x20.pptx | 1480607 | 1480607 | +0 |
| uniform-100x20.pptx | 1942785 | 1942785 | +0 |

Exact sizes come from every retained timed render. Endpoint strings and paint order can change while byte counts remain equal. All saved edited packages match across builds; source preservation is proved separately.

Raw samples: [canonical](benchmarks/2026-10-04-table-join-profiles-layout-18-canonical-paired.json), [supplement](benchmarks/2026-10-04-table-join-profiles-layout-18-supplement-paired.json), [native](benchmarks/2026-10-04-table-join-profiles-layout-18-native-paired.json). [Primary summary](benchmarks/2026-10-04-table-join-profiles-layout-18-summary.json), [all 196-phase appendix](benchmarks/2026-10-04-table-join-profiles-layout-18-APPENDIX.md), [all-phase JSON](benchmarks/2026-10-04-table-join-profiles-layout-18-all-phase-analysis.json), [host load](benchmarks/2026-10-04-table-join-profiles-layout-18-host-load.json), [frozen plan](benchmarks/2026-10-04-table-join-profiles-layout-18-timing-plan.json), [semantic classification](benchmarks/2026-10-04-table-join-profiles-layout-18-semantic-classification.json), and [verification](benchmarks/2026-10-04-table-join-profiles-layout-18-verification.json).

Physical source snapshots, binaries/modules and complete proof outputs remain in `.build/perf30-table-join-profiles/`. The export wrapper maps tracked byte copies to those originals. Original readiness, preflight verification, plan and timing evidence remain immutable.
