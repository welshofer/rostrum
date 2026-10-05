# S17 table defaults and mixed-width joins: cost and preservation

Independent source, protocol and final numeric/evidence reviews approved this bounded fidelity tradeoff. This is a fidelity-cost comparison, with intentional SVG changes. The custom native deck observed **+4.852% render time [95% bootstrap interval +3.222%, +7.633%]**, and the 100×20 mixed-width join control observed **+0.976% [+0.719%, +2.541%]**. Both had 10/10 slower pairs (`p=0.001953125`). The unchanged mixed-RTL control also slowed **+1.466% [+0.791%, +2.507%]**, 10/10 slower. These adverse results remain explicit; the RTL result cannot be attributed to the table algorithm merely because it appeared in the same campaign.

The three built-in absent-ID scaling controls observed −9.748%, −8.653% and −7.838% median paired render changes, each with 10/10 faster pairs. They now render a different intended table style; these are scoped observations, not output-preserving optimization or general recovery claims. Registered rendering was inconclusive at −0.237% [−0.820%, +0.587%]. The explicit-style, uniform-join and other controls retain nonzero adverse bounds.

Whole-process median RSS changes ranged from **-2.188 to +0.180 MiB**. The large absent-ID control accounts for the largest reduction; this does not establish an isolated allocation saving. Sampled WindowServer load was **28.3%–44.6%**, backupd **0.1%–156.7%**, and Photos/Spotlight **0%**. Agents paused builds, tests and GUI work, but this was not a clean or controlled host. Snapshot timing and every raw sample remain retained.

## Sources and preservation

Fresh baseline `a88540380d4b041af08f1db21f3224337ddd4c01` includes S16 and accepted renderer reuse. Candidate `d088ee9a0c63927dac1d757b0a507cb0744a1ce3` cherry-picks engine `5d3d3b5a8d88c685c80c03813a3e13e4522d57fe`; the candidate Sources tree `d757ef297061474cd3faf2961e49e17877746fd3` matches the root integration. Only `TableStyleResolver.swift`, `DeckMerge.swift`, `RenderDiagnostics.swift`, `TableBorderSegments.swift` and `SVGRenderer.swift` differ in production. Both complete Release builds, compiler, object/module files and helper commands are pinned. Candidate tests passed **1,180 library tests / 171 suites** and **18 RostrumLayout tests / 3 suites**; `git diff --check` passed. Root owns the integrated app/native/platform gate.

An existing table without an applied style ID now resolves NoStyleGrid rather than treating the table-style-list insertion default as applied formatting. Inline and explicit styles retain their resolution path. Slide import preserves absent IDs and missing table properties. The separate join change admits only bounded opaque solid, unmerged LTR mixed-width grids, preserving the established uniform path and rejection fallbacks. Native evidence covers three captured source decks and 12 paint cases; it does not establish general table-text parity.

Fresh output proof covers **168 cases / 862 slides**, with **504 independent helper processes and python-pptx reopens**. All saved packages, ordered diagnostics and inheritance reports match across versions, and two candidate runs match exactly. **21 cases / 51 SVGs** change. Every actual output is retained. Full SVG text trees have **zero differences**, including the older corpus; no text or style attributes were silently removed from comparison.

The semantic proof records source tables and applies an explicit NoStyleGrid ID only to absent-ID, non-inline tables in separate counterfactual decks. Candidate counterfactual SVGs must equal original candidate SVGs byte for byte. Baseline counterfactual versus candidate comparison then proves the entire non-line tree exact and all line counts/paint attributes exact; only endpoint coordinates and paint order remain different on 39 slides. The full old/new line records are retained. This is source-based attribution, not additional native validation. All 21 actual changed case IDs and their artifacts remain in the corpus receipt.

Four import cases each run baseline plus two candidate processes: original builtin/custom decks and variants with missing table properties plus unknown XML. All **12 target packages reopen independently**; source part payloads remain untouched. Candidate imported table trees preserve explicit/inline/direct styles, child order and unknown XML exactly, and absent IDs/properties stay absent. Baseline default stamping is recorded as an intentional cross-version target difference. Candidate repeated saves, SVGs, ordered issues and reopened renders match.

The fixed small, large-table and image-heavy preservation cases pass with **6 additional external reopens** and exact cross-version SVG/package maps. **101,310 shaping records and 1,728 layout records** match for baseline and two candidate runs. The first counterfactual harness incorrectly expected Python-compressed ZIP container bytes to equal Rostrum serialization; it was corrected to exact entry-payload identity and cross-version saved identity. That failed preflight script, log and output remain retained. No production change or timed rerun resulted.

## Frozen campaign

One approved **462-child** campaign completed in **109.68 seconds**: canonical 110, Unicode 66, and table/native 286. Receipt wall time is `109.68313366600s`; the subsequent completion-log reading is `109.68327612500s`, sampled after receipt serialization. Neither is a sum of child timers. Each workload uses one excluded warmup pair and ten alternating retained fresh-process pairs. No adaptive rerun occurred.

The canonical five and Unicode three drivers and inputs remain unchanged. The additive table pool has three captured native inputs plus ten scaling, explicit-style and uniform-join controls, including 200×50 tables. Its helper differs from the earlier native helper only in a post-edit validation lookup that finds the first table frame instead of assuming the first shape is a table. This identical change is linked into both binaries. Original rendering precedes any cell edit. Embedded font registration and exact DejaVu Sans byte verification occur outside the render timer. There is no new fitting phase. Existing first-slide, reopen, traversal and save phases remain separately reported.

All **240 measured phases** are reported, with **22 primary** render/richtext-fitting comparisons. Paired median intervals use 100,000 bootstrap resamples with seed 20261004; exact two-sided sign tests exclude ties. Analyses are exploratory and unadjusted for multiplicity. Negative deltas mean candidate faster.

| Workload / phase | Baseline → candidate median ms | Paired median Δ [95% interval] | Faster pairs | Sign p | RSS Δ MiB |
|---|---:|---:|---:|---:|---:|
| canonical/table-200x50/render | 180.8374 → 179.6419 | -0.735% [-2.418, +0.677] | 8/10 | 0.10937500 | -0.219 |
| canonical/table-20x10/render | 3.6004 → 3.5780 | -1.260% [-1.800, -0.171] | 8/10 | 0.10937500 | -0.203 |
| canonical/shaped-table-100x20/render | 62.6635 → 62.9008 | -0.237% [-0.820, +0.587] | 6/10 | 0.75390625 | +0.078 |
| canonical/richtext-fit/render | 2.4471 → 2.4199 | -1.300% [-3.791, +3.138] | 7/10 | 0.34375000 | -0.125 |
| canonical/richtext-fit/richtext-fitting | 9.3277 → 9.1801 | -1.424% [-3.078, +0.011] | 7/10 | 0.34375000 | -0.125 |
| canonical/slides-10/render | 0.5448 → 0.5290 | -2.647% [-4.244, +2.633] | 7/10 | 0.34375000 | +0.062 |
| supplement/unicode-latin.pptx/render | 116.9444 → 118.5407 | +0.780% [+0.059, +1.879] | 2/10 | 0.10937500 | -0.094 |
| supplement/mixed-rtl.pptx/render | 119.7307 → 121.1939 | +1.466% [+0.791, +2.507] | 0/10 | 0.00195312 | +0.109 |
| supplement/long-combining.pptx/render | 384.3450 → 381.6117 | -0.601% [-2.768, +2.469] | 6/10 | 0.75390625 | -0.109 |
| native/native-table-default-builtin-v1.pptx/render | 2.9425 → 2.7678 | -5.833% [-8.523, -4.650] | 10/10 | 0.00195312 | +0.125 |
| native/native-table-default-custom-v1.pptx/render | 2.3841 → 2.5014 | +4.852% [+3.222, +7.633] | 0/10 | 0.00195312 | +0.164 |
| native/native-table-joins-v1.pptx/render | 3.0233 → 3.0165 | +0.661% [-1.505, +1.416] | 4/10 | 0.75390625 | +0.133 |
| native/absent-20x10.pptx/render | 6.5935 → 5.9629 | -9.748% [-12.599, -9.207] | 10/10 | 0.00195312 | +0.094 |
| native/absent-100x20.pptx/render | 40.6094 → 37.2376 | -8.653% [-9.014, -7.531] | 10/10 | 0.00195312 | -0.023 |
| native/absent-200x50.pptx/render | 188.8510 → 173.4936 | -7.838% [-9.366, -6.266] | 10/10 | 0.00195312 | -2.188 |
| native/explicit-20x10.pptx/render | 6.6954 → 6.7034 | +0.145% [-0.990, +6.104] | 4/10 | 0.75390625 | +0.141 |
| native/explicit-200x50.pptx/render | 189.8891 → 189.4616 | +0.293% [-1.399, +0.845] | 4/10 | 0.75390625 | +0.156 |
| native/custom-absent-20x10.pptx/render | 5.9838 → 5.9288 | -0.768% [-2.315, +0.538] | 7/10 | 0.34375000 | +0.125 |
| native/custom-explicit-20x10.pptx/render | 5.9186 → 5.9681 | +0.634% [-1.179, +2.657] | 4/10 | 0.75390625 | +0.109 |
| native/mixed-joins-20x10.pptx/render | 7.4632 → 7.5566 | +0.950% [-0.269, +1.725] | 3/10 | 0.34375000 | +0.125 |
| native/mixed-joins-100x20.pptx/render | 51.4780 → 52.0618 | +0.976% [+0.719, +2.541] | 0/10 | 0.00195312 | +0.180 |
| native/uniform-joins-100x20.pptx/render | 51.8524 → 51.6471 | -0.538% [-0.786, +0.946] | 6/10 | 0.75390625 | +0.117 |

Of 218 secondary intervals, 11 are wholly positive and 11 wholly negative; all are retained in the appendix. They include sub-millisecond phases and cannot each be attributed to table fidelity. Unicode Latin rendering has mixed evidence at +0.780% [+0.059%, +1.879%], with 8/10 slower pairs and p=0.109375. Fallback, fitting, most join/style controls and several native results remain inconclusive. No historical, cumulative, cross-platform, universal nonregression or memory-improvement claim is made.

## Actual original-render SVG bytes

| Input | Baseline bytes | Candidate bytes | Delta |
|---|---:|---:|---:|
| native-table-default-builtin-v1.pptx | 1013794 | 1013717 | -77 |
| native-table-default-custom-v1.pptx | 1014181 | 1014104 | -77 |
| native-table-joins-v1.pptx | 1017028 | 1017028 | +0 |
| absent-20x10.pptx | 1119911 | 1104731 | -15180 |
| absent-100x20.pptx | 2093443 | 1942663 | -150780 |
| absent-200x50.pptx | 6342805 | 5586855 | -755950 |
| explicit-20x10.pptx | 1119911 | 1119911 | +0 |
| explicit-200x50.pptx | 6342805 | 6342805 | +0 |
| custom-absent-20x10.pptx | 1119943 | 1104731 | -15212 |
| custom-explicit-20x10.pptx | 1119943 | 1119943 | +0 |
| mixed-joins-20x10.pptx | 1104603 | 1104731 | +128 |
| mixed-joins-100x20.pptx | 1942175 | 1942663 | +488 |
| uniform-joins-100x20.pptx | 1942785 | 1942785 | +0 |

These are exact sizes from every retained timed render. Saved edited packages match across builds; original source-package preservation is proved separately. Different table paint and endpoint strings can change SVG sizes without changing text.

Raw samples: [canonical](benchmarks/2026-10-04-table-default-joins-layout-17-canonical-paired.json), [supplement](benchmarks/2026-10-04-table-default-joins-layout-17-supplement-paired.json), [native](benchmarks/2026-10-04-table-default-joins-layout-17-native-paired.json). [Primary summary](benchmarks/2026-10-04-table-default-joins-layout-17-summary.json), [all 240-phase appendix](benchmarks/2026-10-04-table-default-joins-layout-17-APPENDIX.md), [all-phase JSON](benchmarks/2026-10-04-table-default-joins-layout-17-all-phase-analysis.json), [host load](benchmarks/2026-10-04-table-default-joins-layout-17-host-load.json), [frozen plan](benchmarks/2026-10-04-table-default-joins-layout-17-timing-plan.json), [semantic classification](benchmarks/2026-10-04-table-default-joins-layout-17-semantic-classification.json), [merge proof](benchmarks/2026-10-04-table-default-joins-layout-17-merge-proof.json), and [verification](benchmarks/2026-10-04-table-default-joins-layout-17-verification.json).

Physical binaries, modules, source snapshots and output files remain in `.build/perf29-table-fidelity/`. The export wrapper maps tracked byte copies to their retained originals. Original proposal, readiness, preflight verification, timing plan and raw records remain immutable.
