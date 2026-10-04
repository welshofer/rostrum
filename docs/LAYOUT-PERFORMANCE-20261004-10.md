# PERF-1: reuse shaped line-break results (2026-10-04)

**Accepted for bounded registered-rendering, fitting and supplementary-text results after independent source, statistics and evidence review.** One matched run against accepted perf9 supports bounded gains in registered rendering (**−0.76%** median), rich fitting (**−5.51%**), accented/CJK rendering (**−5.52%**) and long-combining rendering (**−3.58%**). Registered/fitting/long-combining improved in nine pairs; accented/CJK improved in ten. These are workload-specific observations under substantial WindowServer load. Mixed RSS readings do not support a lower-memory claim; fallback changes are not attributed to this patch.

Baseline `c1b7edf56f8025734d0509a1c7c1ae646eba004f` contains accepted source `850a918` and matches root `051cf5b` Sources. Both sides include the spacing engine and exact glyph reservation. Source commit `4118c97ae0c18c2053eeaae5163e990d3e7a0f05` exactly matches the frozen patch measured before commit. The baseline reuses that accepted Release object, its matching module and benchmark binaries, with a fresh paired measurement here; earlier timings are not substituted or combined.

## Source proof and focused change

Fresh accepted-source profiling found **36/2,627 main-thread samples** in line breaking: **9** in the direct layout call, **13** when initial shaping returned breaks, and **14** when fragment shaping returned breaks. The duplicated direct call is a small **0.34% attribution target**, not a predicted saving; this registered sample does not quantify non-ASCII costs.

`RichTextLayout.appendSegment` computed breaks directly before calling `TextShaper.shape` on the same segment. The patch builds its existing break-offset set from `shaped.breaks` in the metrics branch and retains the original direct breaker in the non-ASCII unregistered branch. The ASCII fallback shortcut is untouched. Neither shaper changes. This removes duplicate scanning and temporary break storage without adding caching, persistent state, different arithmetic or a new Unicode algorithm.

The return-path audit covers Arabic delegation: every valid-size Latin/Arabic return computes breaks from the original source text, irrespective of normalization/substitution or caught execution-limit diagnostics. Only invalid point sizes return empty breaks. Layout already bounds font size to 1…4000 points and scale to finite 0.001…1, making that return unreachable here even for malformed/nonfinite authored/default size or scale. Source-coordinate offsets, control segmentation, diagnostics and DOM remain unchanged.

## Single matched run

| Workload / phase | Baseline ms | Candidate ms | Change | Faster pairs |
|---|---:|---:|---:|---:|
| Large fallback render | 192.2448 | 193.3777 | +0.59% | 3/10 |
| Small fallback render | 3.8751 | 3.7983 | −1.98% | 8/10 |
| Registered render | 68.3360 | 67.8185 | −0.76% | 9/10 |
| Rich fitting | 11.8264 | 11.1753 | −5.51% | 9/10 |
| Fitted render | 2.9996 | 2.8616 | −4.60% | 6/10 |
| Ten-slide render | 0.6241 | 0.6092 | −2.40% | 5/10 |
| Supplement accented/CJK | 133.8163 | 126.4296 | −5.52% | 10/10 |
| Supplement mixed Hebrew/RTL | 128.2402 | 124.3832 | −3.01% | 8/10 |
| Supplement long combining | 417.8840 | 402.9409 | −3.58% | 9/10 |

Changes above compare medians. Paired median changes and bootstrap 95% intervals are: registered **−0.61% [−2.26%, −0.29%]**; fitting **−5.48% [−7.48%, −2.78%]**; accented/CJK **−5.06% [−5.80%, −4.49%]**; long combining **−3.58% [−3.98%, −2.38%]**. Their exact two-sided sign p-values are 0.021484375, 0.021484375, 0.001953125 and 0.021484375. Mixed RTL has mixed statistical evidence: paired −2.63%, interval [−4.02%, −0.89%], but sign p=0.109375. Fitted-render, fallback and ten-slide intervals span zero. Raw paired deltas are retained; bootstrap uses 100,000 resamples and seed 20261004. Exploratory comparisons are uncorrected across workloads and cannot remove shared-load bias.

Whole-process median RSS is mixed: registered **54.6719 → 54.5078 MiB** (−0.1641), fitting **21.1797 → 21.1875** (+0.0078), accented/CJK **49.7891 → 49.8750** (+0.0859), RTL **48.1875 → 47.8906** (−0.2969), long combining **41.2656 → 41.4297** (+0.1641). These do not isolate break-array allocations or establish lower memory.

## Protocol and preservation

The single authorized window ran unchanged canonical **110 processes** and supplementary **66 processes**, one excluded warmup pair plus ten retained alternating pairs per workload. Both sides use Apple Swift 6.4 (swiftlang-6.4.0.34.1), `swiftc -swift-version 6 -O`, matching modules and identical pinned fonts/inputs. Canonical driver and Python runner are unchanged. The separate supplementary driver only enables registered fonts in existing `file` mode; its timers/calls are unchanged. Three 2,000-cell supplementary inputs retain their earlier exact paths/bytes. No further cycle or retiming ran.

Canonical completed in **24.48 seconds**, supplementary **22.45**, total **47.06**, followed by explicit release. Six start/during/end snapshots show **WindowServer 97.1–99.4% CPU**, backupd 0.0%, and no external compiler/xcodebuild/xctest. Snapshots cannot establish continuous isolation. No system settings changed. No cumulative/historical recovery, clean-host, universal/nonregression, cross-platform, fallback or lower-memory claim is made.

Four focused tests each run across registered faces, explicit fallback metrics and unregistered estimates. They cover Arabic controls/ZWSP, CJK punctuation, caps/NFC expansion, CRLF/tab segmentation, malformed size/scale clamps, exact wrap/width goldens, diagnostic order and DOM preservation. Full **1,140 Rostrum tests / 161 suites + 18 RostrumLayout tests / 3 suites**, Release and `git diff --check` pass.

Baseline/candidate proof matches **1,728 complete reflected layout/DOM records** across those three font modes, 12 texts, eight size/scale cases, three widths and two caps settings; candidate repeats identically. Reflection also records internal ligature/adjacency fields under the pinned compiler. Separate **101,022 + 288 full shaping records** match, including glyph/range/advance/offset bits/levels/breaks/diagnostics. Corpus proof covers **114 cases / 780 slides**; five fixed workloads, three supplementary decks and required small/large/image-heavy preservation also pass. SVGs, ordered diagnostics, inheritance flags and saved bytes remain identical; **273** saved files pass independent python-pptx reopen/traversal. Parent owns subsequent integrated application/native checks.

[Verification manifest](benchmarks/2026-10-04-break-reuse-layout-10-verification.json), [canonical raw](benchmarks/2026-10-04-break-reuse-layout-10-paired-macos.json), [canonical analysis](benchmarks/2026-10-04-break-reuse-layout-10-canonical-paired-analysis.json), [supplement raw](benchmarks/2026-10-04-break-reuse-layout-10-supplement-paired-macos.json), [supplement analysis](benchmarks/2026-10-04-break-reuse-layout-10-supplement-paired-analysis.json), [three-mode layout proof](benchmarks/2026-10-04-break-reuse-layout-10-layout-proof.json). Exact commands, profile/audit, binaries/modules, source pins, process snapshots and output receipts remain in `.build/perf20-break-reuse/`. Prior evidence is unchanged.
