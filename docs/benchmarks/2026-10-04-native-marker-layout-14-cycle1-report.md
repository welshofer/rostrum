# Marker fidelity cycle 1 — WITHHELD

**Four ordinary-shape controls regress in all ten pairs. This cycle is withheld pending source optimization.** The primary marker deck improves, but that does not justify accepting the unrelated ordinary-shape costs. No new source or comparative timing was produced in this analysis.

Baseline source 2e57a2d has Sources tree 1fed769a7817b8da2c1381828dd6db5e364f0e81 (accepted perf13). Candidate source bda22542d5f259c560b32ed9d874eb56b0830ee1 is equivalent to marker 679cf5b, Sources tree 04b077b848134c590fcda9654d52b1073cf3537e. Table.cell acquisition d64ddb3 is not included in either side. Root HEAD at launch de9162f is a later checkpoint; frozen binaries map to bda2254 explicitly.

The frozen 418-child protocol ran once: canonical 110, supplementary 66 and native 242, ten alternating retained pairs plus one excluded warmup pair for each of 19 scenarios. There are 20 primary comparisons because rich-text has separate render and fitting phases. All other measured phases and all retained samples remain in immutable raw files. No adaptive repeat or sample exclusion occurred.

Plan SHA256 17c67ba7ccab5a8ff2d871e459b94d77cb144845ef164e06d97f0fb7110cd1a9 and launch SHA256 2ef7254340a635d5a6338d2bb12b538b65701b799a5db5dae245346a009755fc are retained. Baseline/candidate use the same compiler flags, driver and input/font bytes. The launch clears inherited profile/native/font settings and explicitly configures each pool: Arial for canonical/supplementary; the native manifest for native, without the unrelated Arial text-fitting phase. Native inputs register embedded fonts and verify exact decoded bytes before the render timer. Loading, registration, serialization and object setup are outside that timer; retained SVG output generation is inside. Whole-process RSS includes all these phases and allocator retention.

## All primary results

Negative deltas favor the candidate. Paired ratios preserve correspondence and are distinct from ratios of separate medians. Intervals are percentile bootstrap medians from 100,000 deterministic paired-ratio resamples, seed 20261004, indices 2499/97499. Exact two-sided sign tests exclude ties. These exploratory comparisons are not multiplicity-adjusted and cannot remove shared-load bias.

| Pool/workload/phase | Baseline→candidate ms | Ratio of medians Δ | Paired median Δ [95% interval] | Faster/10 | Sign p | RSS Δ MiB |
|---|---:|---:|---:|---:|---:|---:|
| canonical/table-200x50/render | 178.5710→180.7286 | +1.208% | +0.777% [-0.112,+3.493] | 3 | 0.34375000 | +0.000 |
| canonical/table-20x10/render | 3.5616→3.5282 | -0.937% | -1.422% [-2.616,+0.153] | 7 | 0.34375000 | -0.047 |
| canonical/shaped-table-100x20/render | 61.5691→62.0980 | +0.859% | +1.005% [-0.225,+1.578] | 2 | 0.10937500 | -0.297 |
| canonical/richtext-fit/render | 2.5637→2.5035 | -2.349% | -1.112% [-4.339,+0.364] | 8 | 0.10937500 | -0.016 |
| canonical/richtext-fit/richtext-fitting | 9.6305→9.5273 | -1.072% | -1.183% [-1.756,+0.162] | 7 | 0.34375000 | -0.016 |
| canonical/slides-10/render | 0.5510→0.5691 | +3.270% | +2.793% [-1.701,+6.286] | 3 | 0.34375000 | -0.023 |
| supplement/unicode-latin.pptx/render | 117.1289→117.8817 | +0.643% | +0.960% [+0.242,+1.178] | 2 | 0.10937500 | -0.391 |
| supplement/mixed-rtl.pptx/render | 119.3204→121.1863 | +1.564% | +0.963% [-0.189,+1.532] | 2 | 0.10937500 | -0.102 |
| supplement/long-combining.pptx/render | 385.1326→385.8120 | +0.176% | +0.003% [-1.731,+0.672] | 5 | 1.00000000 | -0.438 |
| native/native-paint-placement-v2.pptx/render | 3.3514→3.3964 | +1.341% | +1.435% [-0.111,+2.829] | 2 | 0.10937500 | -0.328 |
| native/native-paint-autofit-controls-v1.pptx/render | 2.4811→2.4670 | -0.567% | -0.346% [-1.890,+2.254] | 6 | 0.75390625 | -0.258 |
| native/native-paint-eligibility-v1.pptx/render | 5.2359→5.2174 | -0.353% | -0.929% [-2.415,+0.560] | 6 | 0.75390625 | -0.172 |
| native/native-paint-omitted-kern-v2.pptx/render | 2.1100→2.0692 | -1.935% | -2.015% [-3.753,+0.032] | 8 | 0.10937500 | -0.234 |
| native/native-list-markers-v2.pptx/render | 4.4829→4.2747 | -4.644% | -4.037% [-6.274,-3.000] | 10 | 0.00195312 | -3.180 |
| native/native-list-markers-followup-v1.pptx/render | 3.3248→3.3976 | +2.189% | +1.693% [+0.130,+3.533] | 2 | 0.10937500 | -0.203 |
| native/ordinary-buNone-200.pptx/render | 6.7637→7.4131 | +9.600% | +9.611% [+8.634,+10.051] | 0 | 0.00195312 | -0.195 |
| native/ordinary-buNone-large-style-200.pptx/render | 9.6712→22.9832 | +137.647% | +134.043% [+129.365,+144.233] | 0 | 0.00195312 | -0.141 |
| native/ordinary-inherited-bullet-ascii-200.pptx/render | 8.0115→8.8042 | +9.895% | +10.278% [+6.804,+13.204] | 0 | 0.00195312 | -1.047 |
| native/ordinary-inherited-bullet-unicode-200.pptx/render | 14.6366→15.3855 | +5.116% | +4.710% [+3.376,+6.531] | 0 | 0.00195312 | -1.172 |
| native/placeholder-inherited-bullet-200.pptx/render | 8.2583→8.2504 | -0.096% | +0.302% [-1.151,+1.385] | 5 | 1.00000000 | -0.195 |

The adverse buNone/large-style/ASCII-inheritance/Unicode-inheritance controls have positive intervals and 10/10 slower pairs, exact sign p=.001953125. Their +9.611%,+134.043%,+10.278%,+4.710% paired effects should not be dismissed as noise. The large-style control renders the same SVG byte count on both sides and magnifies the cost without a visible-output gain. This supports investigating traversal/copying overhead; measurements alone do not establish allocation causality.

The primary marker deck is −4.037% [−6.274,−3.000],10/10 faster. Accented/CJK and marker-followup show positive bootstrap intervals but only 8/10 slower, sign p=.109375; their mixed uncertainty remains explicit. Canonical registered rendering is +1.005% [−0.225,+1.578], so possible cost remains. No net, cumulative, universal nonregression or lower-memory claim is made. Small/large native inputs represent different output workloads and are not combined into a weighted headline.

## Native SVG bytes

Byte counts are deterministic within each variant. Equal counts alone are not geometry or diagnostic equality; intended marker/layout differences are governed by separate native/corpus proofs. Every paired saved-package hash is identical across variants and repetitions. All native samples report identical registered-face identities across variants.

| Native input | Baseline bytes | Candidate bytes | Delta |
|---|---:|---:|---:|
| native-paint-placement-v2.pptx | 3041651 | 3041651 | +0 |
| native-paint-autofit-controls-v1.pptx | 2024044 | 2024044 | +0 |
| native-paint-eligibility-v1.pptx | 4324989 | 4324989 | +0 |
| native-paint-omitted-kern-v2.pptx | 1011963 | 1011963 | +0 |
| native-list-markers-v2.pptx | 5000711 | 4491949 | -508762 |
| native-list-markers-followup-v1.pptx | 2461070 | 2460669 | -401 |
| ordinary-buNone-200.pptx | 1069981 | 1069981 | +0 |
| ordinary-buNone-large-style-200.pptx | 1069981 | 1069981 | +0 |
| ordinary-inherited-bullet-ascii-200.pptx | 1611232 | 1069981 | -541251 |
| ordinary-inherited-bullet-unicode-200.pptx | 1605432 | 1064581 | -540851 |
| placeholder-inherited-bullet-200.pptx | 1611432 | 1601632 | -9800 |

## Host context and evidence limits

Actual snapshots span 2026-10-04T14:13:34.543385−07:00 to 14:14:49.726288−07:00. WindowServer is 15.1–29.1%; backupd 1.6–134.1%; Photos/Spotlight 0% in nine snapshots. Native during/end snapshots still observe backupd 43.3–99.8%; canonical/supplementary peak 134.1/129.5%. Root and lanes paused task builds/tests/GUI, but background activity remained uncontrolled. Snapshots cannot prove continuous isolation or remove its bias, and no host settings changed.

The execution receipt records 75.2337566660135s; the final log after receipt writing records 75.23389283299912s. Both round 75.23s and are retained without substituting one for the other. Pool elapsed values are 22.84180449997075s canonical,20.804639084031805s supplementary,31.482987124996725s native. All exit codes are 0.

The immutable retained directory contains 83 files, including all three raw reports, original plan/launch/execution, process snapshots, source helpers, baseline/candidate objects/binaries/modules, build/proof receipts and controls. Native/corpus artifacts themselves remain root-owned; their proof receipts are retained here, but this statistical analysis does not independently re-review their geometry classifications. Source optimization belongs to the native worker. Existing accepted acquisition/perf13 evidence remains unchanged.

Primary analysis receipts: canonical-paired-analysis.json, supplement-paired-analysis.json, native-paired-analysis.json. Raw files: retained/{canonical,supplement,native}-paired.json. Host detail: host-load.json. Pins: verification.json and retained-pins.json. Status remains WITHHELD, pending changed-source investigation and fresh authorized measurement.
