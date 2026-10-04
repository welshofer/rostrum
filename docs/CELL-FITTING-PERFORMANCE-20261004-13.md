# Live table-cell fitting: text-only style resolution

**All four retained-cell fitting controls improve in this matched run. Canonical rendering and rich-text fitting retain unresolved regression risk because their intervals are wide under changing backup load.** Source, preservation and bounded statistical review passed; final report/manifest review is pending. This is a scoped fitting result, not universal nonregression or historical recovery.

Baseline is accepted perf12 evidence 7c26656/source 8503f44, Sources tree e1b7a510acd496f68b0fb11489fc422a823f3f75, identical to root 0734361 at preparation. The retained Release module/object pair was not rebuilt. Candidate source/tests/generator commit is 308f20d; its measured source was frozen before timing, and committing did not change those bytes. Canonical and supplementary drivers, font bytes, compiler and flags match on both sides.

A fresh attribution profile retains cell frames before its sampling loop. For 10×10, 40×25 and 200×50 tables, main-thread sample totals are 2,250, 2,338 and 2,298. Full-grid construction accounts for 17/92/486 samples; style-definition lookup/parsing for 1,105/1,137/770; drawing-view normalization for 630/615/471. These inclusive categories are separately reported, not added as predicted savings. Narrow identifiable identity-scan source-line samples are 0/1/9, with inlining/source-attribution limitations. GUI/review/background activity could overlap these attribution profiles.

The previous fitting context created a complete grid and full paint-capable style resolver for each cell. The candidate scans live XML for the first row-major cell identity, resolves the same ordered text regions, and reproduces direct root-attribute overlay for padding/anchor/direction. It does not resolve discarded fill/border properties. The catalog generator produces an internal text-only built-in definition from the same pinned 74-style data, preserving root/region attributes, region order and complete text subtrees. Inline and package-owned definitions retain the full existing namespace-normalization path, including precedence over built-in GUIDs. Every operation parses a fresh tree: no persistent DOM/style/coordinate cache and no new public API.

Identity lookup still has quadratic worst-case comparisons across independently fitting every cell. Table.cell acquisition also still builds full snapshots; acquisition is excluded from these fitting timers and remains a separate future target. No complexity improvement is claimed for those lookups.

The frozen protocol ran once: 264 fresh child processes, ten alternating retained pairs plus one excluded warmup for each workload. Canonical 110 and supplementary 66 processes remain unchanged. The separately labeled four retained-cell controls add 88 processes. Their helpers load the same inputs/font, retain all frames and serialize before the fitting timer; the fitting loop measures each retained frame once. A genuine SVG render has its own separate timer for unchanged-runner compatibility. All processes succeeded in 147.01 seconds (exact 147.01371350005502); there were no adaptive reruns.

Retained-cell fitting results:

| Workload/phase | Baseline→candidate ms | Ratio of medians Δ | Paired median Δ [95% interval] | Faster pairs | RSS Δ MiB |
|---|---:|---:|---:|---:|---:|
| Retained cells 10×10 fitting | 26.9865→10.2249 | -62.11% | -61.90% [-62.42, -61.15] | 10/10 | -0.219 |
| Retained cells 40×25 fitting | 277.4377→98.1541 | -64.62% | -64.59% [-65.26, -64.37] | 10/10 | -2.156 |
| Retained cells 200×50 fitting | 3753.4309→1083.7398 | -71.13% | -71.05% [-71.17, -70.92] | 10/10 | -21.602 |
| Inline-style cells 40×25 fitting | 140.8609→108.7346 | -22.81% | -22.30% [-23.57, -21.77] | 10/10 | +0.133 |

All four fitting controls have 10/10 faster pairs and exact two-sided sign-test p=.001953125. The large control decreases from 3,753.4309 to 1,083.7398 ms for fitting 10,000 retained cells; its paired median is −71.054% [−71.172,−70.920]. The inline-style control retains full custom-style parsing/normalization and still improves −22.303% [−23.573,−21.771]. These controls use short fixed text; the percentages do not generalize to arbitrary table text, style complexity or machines.

Whole-process RSS medians decrease 0.219, 2.156 and 21.602 MiB in the three built-in controls, while the inline control increases 0.133 MiB. RSS includes acquisition, DOM/style work, rendering, serialization and allocator retention; it does not isolate the fitting loop or establish which eliminated allocation caused a difference. There is no general lower-memory claim. Generated source adds immutable text projections; the retained Rostrum object grows 59,592 bytes (5,937,656→5,997,248), without a shared mutable cache.

Canonical and existing supplementary controls:

| Workload/phase | Baseline→candidate ms | Ratio of medians Δ | Paired median Δ [95% interval] | Faster pairs | RSS Δ MiB |
|---|---:|---:|---:|---:|---:|
| Fallback 200×50 table | 190.2485→191.6316 | +0.73% | +0.19% [-1.44, +2.74] | 5/10 | +0.070 |
| Fallback 20×10 table | 3.8065→3.8611 | +1.44% | +1.41% [-1.21, +2.80] | 4/10 | +0.047 |
| Registered 100×20 table | 102.5587→105.7507 | +3.11% | -0.31% [-28.37, +16.01] | 5/10 | -0.867 |
| Rich-text render | 4.5004→4.1662 | -7.43% | -11.50% [-18.21, +14.75] | 6/10 | -0.180 |
| Rich-text fitting | 15.7835→15.1140 | -4.24% | -4.95% [-8.87, +4.66] | 7/10 | -0.180 |
| Ten slides | 1.0366→1.0370 | +0.04% | -21.30% [-32.56, +24.96] | 6/10 | +0.133 |
| Accented/CJK | 174.6131→175.7877 | +0.67% | +2.37% [-5.34, +8.23] | 4/10 | +0.445 |
| Mixed RTL | 124.7375→125.2256 | +0.39% | -0.14% [-1.56, +2.43] | 6/10 | +0.000 |
| Long combining | 408.5487→401.7802 | -1.66% | -1.20% [-2.48, -0.22] | 9/10 | +0.047 |

Registered canonical rendering has paired median −0.310% [−28.368,+16.011], 5/10 faster; rich-text fitting is −4.950% [−8.873,+4.655], 7/10 faster. These wide intervals leave substantial regression risk unresolved, not demonstrated nonregression. No canonical speedup is claimed. The supplementary long-combining result is −1.203% [−2.480,−0.224], 9/10 faster, sign-test p=.021484375; this unrelated observation is not attributed to the fitting-only change. Other supplementary intervals cross zero.

Separate rendering phases from the retained-cell controls:

| Workload/phase | Baseline→candidate ms | Ratio of medians Δ | Paired median Δ [95% interval] | Faster pairs | RSS Δ MiB |
|---|---:|---:|---:|---:|---:|
| Retained cells 10×10 render | 3.6619→3.7409 | +2.16% | +2.66% [-0.66, +5.43] | 3/10 | -0.219 |
| Retained cells 40×25 render | 19.8667→20.1040 | +1.19% | +0.91% [-1.05, +2.09] | 4/10 | -2.156 |
| Retained cells 200×50 render | 205.4108→205.3405 | -0.03% | -0.07% [-2.39, +1.60] | 5/10 | -21.602 |
| Inline-style cells 40×25 render | 20.1499→20.1604 | +0.05% | -0.00% [-1.44, +2.96] | 5/10 | +0.133 |

Each retained-cell rendering interval crosses zero, including the small table's directional +2.664% [−0.664,+5.430]. Preserve these possible costs rather than treating successful fitting as a blanket rendering claim. The fitting/render rows for a given control share the same process RSS.

Negative runtime deltas favor the candidate. Paired ratios preserve pair correspondence and are distinct from ratios of separate medians. Intervals use 100,000 deterministic bootstrap pair resamples (seed 20261004); exact two-sided sign tests exclude ties. These exploratory intervals are not adjusted across workloads. [Canonical raw](benchmarks/2026-10-04-cell-fitting-layout-13-paired-macos.json), [supplementary raw](benchmarks/2026-10-04-cell-fitting-layout-13-supplement-paired-macos.json), [cell-control raw](benchmarks/2026-10-04-cell-fitting-layout-13-cell-paired-macos.json) and paired-analysis receipts retain every sample and paired delta.

Thirteen [host snapshots](benchmarks/2026-10-04-cell-fitting-layout-13-host-load.json) preserve timestamps and pool names: actual run start 13:23:22.763598 and end 13:25:49.722444, America/Los_Angeles on 2026-10-04. WindowServer ranges 65.1–71.5%; backupd ranges 0.1–1,195.4%. The highest backup observation is at canonical end; retained-cell during/end snapshots still range 0.4–156.6%. Photos and Spotlight are 0% in these snapshots. Root and workers paused builds/tests/GUI, but user/background load remained uncontrolled. This is not a clean host; snapshots cannot prove continuous isolation or remove shared-load bias. No system settings or user processes were changed.

Preservation is exact against the retained baseline. [Main output proof](benchmarks/2026-10-04-cell-fitting-layout-13-output-proof.json) covers 134 cases/824 slides with baseline plus two candidate runs: every SVG, ordered diagnostic, inheritance flag and saved package matches. The unchanged small/large/image-heavy preservation checks pass part payloads, deterministic saves and saved-file reopened SVG equality. The four cell controls preserve all 12,100 per-cell fitting results, SVGs, ordered diagnostics and saved bytes on both candidate repetitions. Independent python-pptx reopen/traversal totals 435 (417 main, 6 preservation, 12 cell controls).

Standalone shaping (101,310 records) and full reflected layout/DOM (1,728 records, both sides twice) remain byte-identical. Focused tests compare all 74 built-ins ×128 flags ×6 edge/parity positions against full resolution, plus exact catalog subtree projection, degenerate grids, inline namespace aliases and duplicate regions. Mutation tests retain frames across insertion/reordering, merge/unmerge, padding/anchor/direction/style/theme edits, duplicate malformed attributes, body replacement, identity aliases, ragged rows and detachment. Registered-font and explicit-metrics fitting match the full-resolution oracle, preserve DOM bytes and retain rendered diagnostics. Attached attributes keep ordered-overlay last-value semantics; detached cells keep first-present direct-property semantics.

Final swift test --jobs 2 passes 1,155 tests/164 suites plus 18 layout tests/3 suites. Release build, generator byte-for-byte regeneration and git diff --check pass. An initial focused-test harness compile typo was corrected before these green checks; its log is retained and no timing used that state. The root owns integrated Lectern/native/GUI gates. [Verification manifest](benchmarks/2026-10-04-cell-fitting-layout-13-verification.json) pins the source, generator/input, binaries/modules, drivers, fonts, profiles, raw measurements and proofs. Physical evidence remains in .build/perf23-cell-fitting; earlier checkpoints are unchanged.

Acceptance is limited to the measured retained-cell fitting workload. Canonical regression uncertainty, possible rendering costs, mixed RSS, substantial backup load and quadratic identity lookup remain explicit limitations.
