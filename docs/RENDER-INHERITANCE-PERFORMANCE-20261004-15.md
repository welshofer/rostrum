# PERF15: ordinary inherited defaults within one SVG render

Independent source, performance and evidence review approved bounded acceptance for the ordinary-shape rendering target. This fresh-baseline experiment targets repeated ordinary-shape master resolution. The four 200-shape ordinary controls improved in all ten matched pairs, with median paired render reductions of **9.089%–18.118%**. Placeholder, registered-table and fitting controls remain inconclusive. Large fallback rendering is **+1.500% [−0.084%, +13.038%]**, an unresolved adverse interval; this is not a universal nonregression or historical recovery claim.

Background activity remained substantial: sampled `backupd` was **1.0%–460.1% CPU** and WindowServer **22.8%–39.1%**. Root and workers paused build/test/GUI jobs, but the host was not clean. Snapshots cannot remove shared-load bias. Whole-process median RSS differences ranged from **−0.516 to +0.172 MiB**; these do not establish an allocation or memory improvement.

## Change and source proof

Fresh baseline `6a3f61b5fb85f767096e87d3c14a2a1ceb74d410` (`Sources` tree `61ebb33b5b765ab5fd965eddea1e134ec294d7af`) includes accepted marker projection and Table.cell acquisition. Candidate `bc0ec62662467f3ce434eb4c261ffcd2c8684734` (`Sources` tree `ae809cfa6235d67eea2b505acc0973ac7fe1ac25`) changes only `SVGRenderer.swift` plus focused tests. The source commit exactly matches the precommit source map and patch used to build and time the candidate. Historical marker-only binaries were not reused as this baseline.

Ordinary shapes owned by the rendered slide share one inherited-default result for that render, including an empty result. Entry reset plus deferred cleanup releases the scratch value on success or failure, including reused renderer instances. Notes, placeholders and other owners retain their original resolution paths. There is no persistent DOM cache or public API change.

Fresh attribution profiles found `inheritedRunDefaults` in 566/2625, 599/2706, 584/2697 and 287/2670 main-thread samples for ordinary buNone, large style, ASCII and Unicode controls respectively. These inclusive 21.56%, 22.14%, 21.65% and 10.75% shares include nested relationship resolution and style projection; they must not be added or interpreted as predicted speedups. Placeholder attribution was 549/2707 (20.28%); tables had zero such samples. The eight attribution runs are separate from comparative timing.

## Frozen matched comparison

One **418-child** campaign completed in **75.28s**: canonical 110, supplementary 66 and native/control 242. Every workload retained ten alternating fresh-process pairs after one excluded warmup pair. Identical unchanged drivers, compiler flags, scenario arrays, font bytes and per-render iteration counts were linked against fresh baseline/candidate Release objects and matching modules. Native embedded-font registration occurs outside the render phase. All children exited zero, with no adaptive rerun. All 207 measured phase comparisons are retained, including the 187 secondary outcomes; bootstrap intervals use 100,000 resamples with seed 20261004 and sign tests are exact two-sided tests excluding ties. Comparisons are exploratory and unadjusted for multiplicity.

| Workload / primary phase | Baseline → candidate median ms | Paired median Δ [95% bootstrap interval] | Faster pairs | Sign p | RSS Δ MiB |
|---|---:|---:|---:|---:|---:|
| canonical/table-200x50/render | 184.6885 → 185.5742 | +1.500% [-0.084, +13.038] | 3/10 | 0.34375000 | -0.141 |
| canonical/table-20x10/render | 3.5756 → 3.6311 | +1.201% [-0.179, +3.057] | 2/10 | 0.10937500 | -0.094 |
| canonical/shaped-table-100x20/render | 62.4631 → 62.6512 | -0.062% [-0.633, +1.939] | 5/10 | 1.00000000 | -0.312 |
| canonical/richtext-fit/render | 2.4150 → 2.4298 | +0.072% [-2.445, +3.796] | 5/10 | 1.00000000 | -0.156 |
| canonical/richtext-fit/richtext-fitting | 9.2614 → 9.1756 | -0.077% [-2.051, +0.911] | 5/10 | 1.00000000 | -0.156 |
| canonical/slides-10/render | 0.5457 → 0.5403 | -0.269% [-3.268, +1.349] | 5/10 | 1.00000000 | -0.125 |
| supplement/unicode-latin.pptx/render | 119.5057 → 118.7146 | -0.525% [-1.326, +0.039] | 8/10 | 0.10937500 | -0.516 |
| supplement/mixed-rtl.pptx/render | 122.2198 → 122.6723 | +0.434% [-1.428, +0.712] | 4/10 | 0.75390625 | +0.031 |
| supplement/long-combining.pptx/render | 399.7822 → 399.8252 | -0.293% [-1.341, +2.123] | 6/10 | 0.75390625 | -0.391 |
| native/native-paint-placement-v2.pptx/render | 3.4742 → 3.2007 | -6.915% [-10.064, -4.278] | 10/10 | 0.00195312 | +0.086 |
| native/native-paint-autofit-controls-v1.pptx/render | 2.4913 → 2.4928 | -1.180% [-7.009, +1.422] | 6/10 | 0.75390625 | +0.000 |
| native/native-paint-eligibility-v1.pptx/render | 5.4063 → 5.1548 | -5.909% [-7.438, +0.770] | 8/10 | 0.10937500 | +0.172 |
| native/native-paint-omitted-kern-v2.pptx/render | 2.0162 → 1.9941 | -1.029% [-4.723, +0.980] | 6/10 | 0.75390625 | +0.000 |
| native/native-list-markers-v2.pptx/render | 4.1782 → 4.0019 | -5.616% [-7.335, -0.801] | 8/10 | 0.10937500 | +0.031 |
| native/native-list-markers-followup-v1.pptx/render | 3.4031 → 3.3336 | -2.835% [-5.470, +0.484] | 8/10 | 0.10937500 | -0.047 |
| native/ordinary-buNone-200.pptx/render | 7.0390 → 5.8062 | -17.872% [-18.781, -15.520] | 10/10 | 0.00195312 | +0.031 |
| native/ordinary-buNone-large-style-200.pptx/render | 10.0697 → 8.6358 | -14.622% [-15.389, -13.150] | 10/10 | 0.00195312 | -0.031 |
| native/ordinary-inherited-bullet-ascii-200.pptx/render | 7.5658 → 6.0802 | -18.118% [-20.704, -16.237] | 10/10 | 0.00195312 | +0.031 |
| native/ordinary-inherited-bullet-unicode-200.pptx/render | 14.0084 → 12.6920 | -9.089% [-10.673, -7.783] | 10/10 | 0.00195312 | +0.000 |
| native/placeholder-inherited-bullet-200.pptx/render | 8.3675 → 8.4389 | +0.770% [-2.237, +2.120] | 4/10 | 0.75390625 | +0.062 |

Of 187 secondary phase intervals, 10 lie wholly above zero and 9 wholly below. They remain visible in the all-phase appendix, but opening, saving and other phases cannot be causally attributed to ordinary inherited-default reuse. Native placement shows a separate render improvement; the primary marker interval is negative but its exact sign test is not below 0.05. No blanket fitting, fallback, memory, cross-platform or cumulative recovery claim is made.

## Correctness and retained evidence

- Full library tests: **1,169 tests / 168 suites**; RostrumLayout: **18 / 3**. Release build and `git diff --check` passed. Four focused tests exercise reused renderer instances across direct and alias master edits, empty results, relationship/resource changes, font alias replacement, placeholders, inherited furniture and notes.
- **148 cases / 842 slides**: fresh baseline plus candidate twice, **444 proof processes and independent python-pptx reopens**. Every SVG, ordered diagnostic/inheritance record and saved package is byte-identical. Existing 24 native marker cases, 277 visible marker glyphs / 3 omissions, and 47 positioning cases remain covered by the full native tests and exact output proof.
- **101,310 shaping records** and **1,728 layout records** match baseline and both candidate repetitions exactly.
- **80 direct/alias/missing-resource mutation states**, with **320 render invocations**, match baseline/candidate outputs and saved packages. **140** saved mutation packages reopened independently; **20** deliberately missing-layout intermediates are explicitly excluded from external reopening. These public mutation checks supplement the internal same-renderer tests.
- Small, large and image-heavy fixed decks pass payload preservation, deterministic save and reopened-SVG checks on both builds, with **6** independent external reopens. These functional helper durations are not benchmark claims.
- **9,606 output artifacts** are hash-pinned. All old evidence stays untouched. Initial scratch helper compile/script errors (including a missing-object path) were corrected before proof/timing; their logs remain retained, and no measurements came from failed builds.

Raw comparisons: [canonical](benchmarks/2026-10-04-render-inheritance-layout-15-canonical-paired.json), [supplement](benchmarks/2026-10-04-render-inheritance-layout-15-supplement-paired.json), [native](benchmarks/2026-10-04-render-inheritance-layout-15-native-paired.json). Primary analysis: [summary](benchmarks/2026-10-04-render-inheritance-layout-15-summary.json). Full outcomes: [207-phase appendix](benchmarks/2026-10-04-render-inheritance-layout-15-APPENDIX.md), [analysis JSON](benchmarks/2026-10-04-render-inheritance-layout-15-all-phase-analysis.json). [Host snapshots summary](benchmarks/2026-10-04-render-inheritance-layout-15-host-load.json), [frozen protocol](benchmarks/2026-10-04-render-inheritance-layout-15-timing-plan.json), [verification manifest](benchmarks/2026-10-04-render-inheritance-layout-15-verification.json), and [source mapping](benchmarks/2026-10-04-render-inheritance-layout-15-source-commit-mapping.json).

Physical retained evidence: `.build/perf27-render-inheritance/` in the fonts worktree. The export wrapper maps tracked byte copies to original paths and hashes. Root owns the integrated app/native acceptance gate.
