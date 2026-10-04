# PERF-1: normalized scalar storage experiments (2026-10-04)

**Cycle two is accepted for bounded registered-rendering and fitting improvements, with the residual long-combining and RSS costs explicitly retained.** Against the original pre-experiment baseline, its registered-render median decreased **2.53%** and rich-fitting median decreased **8.95%**. The long-combining median increased **0.44%**, with a paired interval spanning zero: a small overhead remains unresolved. Registered whole-process median RSS increased **0.2188 MiB**. These are separate observations, not a general speed or memory claim.

Both cycles preserve every checked glyph record, SVG, ordered diagnostic, inheritance flag and saved package. Both use baseline `72b9b710e288eb295e6b9b26f47d8c641c181452` (source `cbe830d`), including the three earlier accepted performance increments. Source/proof hashes bind source commit `92ea7af9ff255d81873d90a88788fc5d71b4f72a` to the frozen patch measured before that commit. Canonical and supplementary results remain separately labeled; neither earlier timings nor cycle one is used as cycle two's baseline.

## Fresh profile and two implementations

The fresh profile's Sources tree matches root `a98dd69`. Scalar-array construction at TextShaper.swift:59 accounts for **89/2,862 main-thread samples**; cluster append accounts for another 73 samples. These are overlapping attribution counts, not a predicted saving. The original array stored decoded scalars for every normalized character, including singletons.

Cycle one stored an owned `String.UnicodeScalarView` and captured its count during classification. The installed Swift interface confirms that the view owns string storage, but iteration decodes scalars repeatedly. Cluster stride rose from 40 to 56 bytes on this host. Although registered rendering and fitting improved, its long-combining median rose **1.75%**, paired median +1.39%, interval [−0.52%, +3.51%]. The parent did **not accept** that unresolved cost. Its exact source, test, object/module, binaries, raw receipts and proof remain retained; it is **not shipped**.

Cycle two stores a normalized singleton inline and retains the original decoded array for multi-scalar clusters. A local random-access collection preserves constant-time counts and existing consumers, including the original classification/count expressions, CRLF exclusion and original source ranges. It avoids repeated UTF-8 decoding for complex clusters but adds storage dispatch. Cluster stride is 48 bytes. No cache, DOM state, normalization policy, shaping arithmetic or diagnostic policy changes. Only TextShaper and three focused tests are modified. No third cycle has run.

## Cycle two: paired results against the original baseline

| Scope / phase | Baseline median ms | Candidate median ms | Change | Faster pairs |
|---|---:|---:|---:|---:|
| Canonical large fallback render | 191.5807 | 191.7737 | +0.10% | 4/10 |
| Canonical small fallback render | 3.8050 | 3.7956 | −0.25% | 4/10 |
| Canonical registered render | 71.4051 | 69.5988 | −2.53% | 9/10 |
| Canonical rich fitting | 13.1044 | 11.9310 | −8.95% | 10/10 |
| Canonical fitted render | 3.2330 | 3.0553 | −5.50% | 9/10 |
| Canonical ten-slide render | 0.6037 | 0.5978 | −0.98% | 6/10 |
| Supplement accented/CJK render | 136.9912 | 134.5575 | −1.78% | 8/10 |
| Supplement mixed Hebrew/RTL render | 131.2375 | 128.9862 | −1.72% | 9/10 |
| Supplement long-combining render | 418.7826 | 420.6326 | **+0.44%** | 3/10 |

Registered paired median change is **−2.25%**, bootstrap 95% interval **[−3.64%, −1.48%]**, exact two-sided sign p=0.021484375. Rich fitting is **−9.83%**, interval **[−11.77%, −7.57%]**, p=0.001953125. Fitted rendering is −7.01%, interval [−10.79%, −2.19%], p=0.021484375.

Long-combining paired median is **+0.48%**, interval **[−0.28%, +1.74%]**, p=0.34375; seven pairs were slower. This does not establish absence of regression. Accented/CJK and RTL paired medians are −1.95% and −1.35%, with intervals [−2.29%, −0.04%] and [−2.43%, −0.74%]; their sign tests are p=0.109375 and p=0.021484375. All raw deltas are retained. Bootstrap uses 100,000 paired resamples and seed 20261004. These exploratory estimates are uncorrected across workloads and cannot remove host-load bias. Fallback and ten-slide changes do not exercise this shaping storage path and are not attributed to it.

| Whole-process peak RSS | Baseline MiB | Candidate MiB | Change MiB |
|---|---:|---:|---:|
| Registered | 54.5469 | 54.7656 | **+0.2188** |
| Fitting | 21.2656 | 21.1719 | −0.0938 |
| Accented/CJK | 49.8906 | 49.5391 | −0.3516 |
| Mixed RTL | 48.0156 | 48.2344 | +0.2188 |
| Long combining | 41.4141 | 41.0859 | −0.3281 |

RSS includes rendering and serialization/proof-related process state; these small mixed changes do not demonstrate lower memory or isolate allocation cost.

## Protocol, load and preserved first attempt

Both sides retain Release objects and their matching modules, and use Apple Swift 6.4 (swiftlang-6.4.0.34.1), `swiftc -swift-version 6 -O`, and hash-pinned Arial. The pre-experiment baseline artifacts are identical in both cycles. Each cycle uses 110 canonical processes and 66 supplementary processes: one excluded warmup pair and ten retained alternating pairs per workload. Supplementary inputs contain 2,000 cells each and retain exactly the same paths/bytes across cycles. The separate supplementary Swift driver only enables registered fonts in the existing `file` scenario. Its timers and calls are otherwise unchanged. The canonical Swift driver and Python runner are unchanged.

The explicit cycle-two window completed canonical processes in **24.49 seconds**, supplementary in **22.50 seconds**, **47.10 seconds total**, then was immediately released. Six snapshots across the window show WindowServer **94.9 / 94.9 / 94.8 / 97.1 / 94.9 / 94.7% CPU**; backupd/helper were 0.0%. No external compiler/build/test was observed. Snapshots are not continuous isolation monitoring.

Cycle one's separate window took **47.23 seconds**, with WindowServer 94.7–96.2% and backupd 38.4–124.9%. Its registered ratio-of-medians change was −1.89% (9/10 faster), fitting −6.57% (10/10), and long-combining +1.75% (5/10). These separate-window results cannot establish a direct cycle-one-to-cycle-two gain. No system settings changed, no further unchanged-candidate timing ran, and no cumulative/historical recovery, clean-host/general/cross-platform, fallback or lower-memory claim is made.

Exact commands, binary/compiler/input/source pins and snapshots are retained in each manifest and `timing-plan.json`; both canonical and supplementary calls use the unchanged `Tools/rostrum-bench/run.py --runs 10 --warmups 1`.

## Correctness and evidence

Both cycles passed three focused normalized-cluster lifetime/range tests; full **1,126 Rostrum tests / 158 suites with four existing known native empty-line issues**, plus **18 RostrumLayout tests / 3 suites**; and Release builds. Each full oracle matches **100,734 records** plus **288 supplementary long-cluster/RTL/emoji records**, including complete glyph/range/advance/offset/level/break/ordered-diagnostic metadata. Each corpus proof covers **96 cases / 748 slides**, five fixed workloads, required small/large/image-heavy preservation, and three supplementary registered decks. Candidate output repeats deterministically. Each cycle independently reopens **237 PPTX files** with python-pptx. Cycle two verifies **5,004 input/artifact hashes** and unchanged cycle-one raw receipts. Root owns the subsequent integrated native/application gate if accepted.

Cycle two: [manifest](benchmarks/2026-10-04-scalar-hybrid-layout-8-cycle2-verification.json), [canonical raw](benchmarks/2026-10-04-scalar-hybrid-layout-8-cycle2-paired-macos.json), [supplement raw](benchmarks/2026-10-04-scalar-hybrid-layout-8-cycle2-supplement-paired-macos.json), [canonical analysis](benchmarks/2026-10-04-scalar-hybrid-layout-8-cycle2-canonical-paired-analysis.json), [supplement analysis](benchmarks/2026-10-04-scalar-hybrid-layout-8-cycle2-supplement-paired-analysis.json). Retained directory: `.build/perf18-scalar-hybrid/`.

Cycle one, **not shipped**: [manifest](benchmarks/2026-10-04-scalar-view-layout-8-verification.json), [canonical raw](benchmarks/2026-10-04-scalar-view-layout-8-paired-macos.json), [supplement raw](benchmarks/2026-10-04-scalar-view-layout-8-supplement-paired-macos.json). Retained directory: `.build/perf17-research/`. Both manifests link all shaping, corpus, fixed-workload, preservation and supplementary proofs. Earlier checkpoints remain unchanged.
