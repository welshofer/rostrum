# Marker projection cycle2 — pending independent review

**Ordinary buNone controls retain approximately 2.7–2.8% directional rendering costs, and the placeholder control retains a 1.136% cost.** ASCII/Unicode ordinary inheritance and the primary marker deck improve. These results do not establish universal nonregression or complete recovery. Source/corpus equivalence passed; performance acceptance is pending. Cycle1 remains WITHHELD and immutable.

Baseline remains accepted perf13 source 2e57a2d, Sources tree 1fed769a7817b8da2c1381828dd6db5e364f0e81. Optimized marker-only candidate c522a9dacef797697c7b860ec1884dd84cced35b has Sources tree dda66f4a098cb995b6aa75e09e1e9d0dee4aa482. Neither side includes Table.cell acquisition d64ddb3. Root's later current HEAD is recorded by the unchanged runner for context; frozen binary/source pins identify what was actually measured.

The native worker built this frozen source once with Swift 6.4, `swift build -c release --jobs 2 --scratch-path .build/list-marker-projection-release`; the object and matching complete module were copied and rehashed before helpers were linked with the unchanged `swiftc -swift-version 6 -O` commands. Baseline binaries were copied unchanged, not rebuilt. All inputs, drivers, font bytes, scenario order, runs/warmups and environment semantics match cycle1. The final 11-input native manifest was copied verbatim, avoiding duplicate setup entries. Candidate source uses a read-only projection of inherited marker properties; this measurement does not by itself assign causal cost to a particular allocation or call site.

The 418-child run occurred exactly once under explicit quiet grant, with no rerun: canonical 110 + supplementary 66 + native 242, ten alternating retained pairs plus one excluded warmup pair for each of 19 workloads. There are 20 primary render/richtext-fitting comparisons and 207 total measured phases. Exact plan SHA256 aefbef92d9ab5d62bb3ccb17864ac106e9e800f16e091b5e7bfafe2e310d49bb and launch/execution/environment receipts are retained. Arial is loaded for canonical/supplement; exact embedded native faces are registered and byte-verified before render, with no unrelated Arial fitting phase in native. Input loading, font registration, saving and frame/object setup are outside render timing. Whole-process RSS includes them.

## Primary results

Negative runtime deltas favor the candidate. Paired medians differ from ratios of separate medians. Intervals use 100,000 deterministic bootstrap pair-ratio resamples, seed 20261004, indices 2499/97499. Exact two-sided sign tests exclude ties. These are exploratory, unadjusted comparisons; they cannot eliminate shared-load bias.

| Pool/workload/phase | Baseline→candidate ms | Ratio of medians Δ | Paired median Δ [95% interval] | Faster/10 | Sign p | RSS Δ MiB |
|---|---:|---:|---:|---:|---:|---:|
| canonical/table-200x50/render | 180.2530→180.5226 | +0.150% | +0.191% [-1.081,+0.820] | 4 | 0.75390625 | +0.047 |
| canonical/table-20x10/render | 3.5942→3.5840 | -0.285% | +0.086% [-1.508,+1.765] | 5 | 1.00000000 | +0.031 |
| canonical/shaped-table-100x20/render | 61.4818→61.6258 | +0.234% | +0.450% [-0.363,+0.735] | 3 | 0.34375000 | +0.062 |
| canonical/richtext-fit/render | 2.3502→2.3736 | +0.996% | +0.222% [-2.458,+2.893] | 5 | 1.00000000 | -0.078 |
| canonical/richtext-fit/richtext-fitting | 9.1775→9.2168 | +0.427% | +0.834% [-0.317,+1.402] | 4 | 0.75390625 | -0.078 |
| canonical/slides-10/render | 0.5164→0.5248 | +1.618% | +0.534% [-1.907,+5.270] | 4 | 0.75390625 | +0.062 |
| supplement/unicode-latin.pptx/render | 117.7546→117.0228 | -0.621% | -0.224% [-0.880,+0.669] | 5 | 1.00000000 | -0.094 |
| supplement/mixed-rtl.pptx/render | 118.4231→119.5976 | +0.992% | +1.123% [-0.323,+2.070] | 2 | 0.10937500 | -0.258 |
| supplement/long-combining.pptx/render | 383.3448→386.7552 | +0.890% | +0.559% [-0.743,+2.060] | 4 | 0.75390625 | +0.000 |
| native/native-paint-placement-v2.pptx/render | 3.2051→3.2270 | +0.684% | +0.632% [-0.975,+2.177] | 4 | 0.75390625 | -0.008 |
| native/native-paint-autofit-controls-v1.pptx/render | 2.4224→2.3968 | -1.054% | -1.187% [-2.429,+2.286] | 7 | 0.34375000 | +0.094 |
| native/native-paint-eligibility-v1.pptx/render | 5.1656→5.2489 | +1.612% | +2.063% [-0.928,+5.329] | 3 | 0.34375000 | +0.188 |
| native/native-paint-omitted-kern-v2.pptx/render | 2.0730→2.0362 | -1.775% | -1.754% [-3.438,+2.511] | 6 | 0.75390625 | +0.023 |
| native/native-list-markers-v2.pptx/render | 4.5363→4.1964 | -7.493% | -8.127% [-9.353,-5.816] | 10 | 0.00195312 | -2.859 |
| native/native-list-markers-followup-v1.pptx/render | 3.2725→3.3045 | +0.978% | +0.972% [+0.041,+2.570] | 2 | 0.10937500 | +0.078 |
| native/ordinary-buNone-200.pptx/render | 6.6346→6.8240 | +2.855% | +2.777% [+0.918,+4.844] | 1 | 0.02148438 | +0.070 |
| native/ordinary-buNone-large-style-200.pptx/render | 9.5577→9.8119 | +2.660% | +2.702% [+1.258,+4.761] | 0 | 0.00195312 | +0.047 |
| native/ordinary-inherited-bullet-ascii-200.pptx/render | 7.8389→7.4745 | -4.649% | -4.948% [-6.135,-2.802] | 10 | 0.00195312 | -0.812 |
| native/ordinary-inherited-bullet-unicode-200.pptx/render | 14.5991→14.0916 | -3.476% | -3.801% [-5.106,-2.707] | 10 | 0.00195312 | -0.828 |
| native/placeholder-inherited-bullet-200.pptx/render | 8.1791→8.2842 | +1.285% | +1.136% [+0.666,+2.304] | 1 | 0.02148438 | +0.102 |

The four previously adverse controls are foregrounded below. Each cycle is matched against the same retained baseline, but the two cycles ran in separate host windows; subtracting their percentages is not a matched optimization effect.

| Control | Cycle1 paired Δ | Cycle2 paired Δ [95% interval] | Cycle2 slower/10 |
|---|---:|---:|---:|
| ordinary-buNone-200.pptx | +9.611% | +2.777% [+0.918,+4.844] | 9 |
| ordinary-buNone-large-style-200.pptx | +134.043% | +2.702% [+1.258,+4.761] | 10 |
| ordinary-inherited-bullet-ascii-200.pptx | +10.278% | -4.948% [-6.135,-2.802] | 0 |
| ordinary-inherited-bullet-unicode-200.pptx | +4.710% | -3.801% [-5.106,-2.707] | 0 |

Both buNone intervals remain positive; ordinary 9/10 slower has sign p=.021484375 and large-style 10/10 slower p=.001953125. These remaining regressions are not dismissed as noise. Both ordinary inherited bullet controls are 10/10 faster, p=.001953125. The placeholder control is +1.136% [+0.666,+2.304],9/10 slower, p=.021484375. The primary marker deck is −8.127% [−9.353,−5.816],10/10 faster. Followup is +0.972% [+0.041,+2.570],8/10 slower with sign p=.109375: bootstrap and sign evidence differ, and the possible cost remains. All canonical and supplementary intervals cross zero; this leaves their possible regression unresolved rather than demonstrating nonregression.

RSS is mixed: canonical registered +0.0625MiB, native eligibility +0.1875MiB and placeholder +0.1016MiB, while primary marker −2.8594MiB and ordinary inherited ASCII/Unicode −0.8125/−0.8281MiB. These whole-process differences cannot isolate projection allocations or support a general memory claim.

## Every secondary phase retained

[APPENDIX.md](APPENDIX.md) and [all-phase-analysis.json](all-phase-analysis.json) contain all 207 comparisons, with the 20 primary rows flagged. Among 187 secondary phases, 14 bootstrap intervals are wholly positive and 11 wholly negative. This is descriptive, unadjusted multiplicity, not independent acceptance tests. The positive-interval secondary outcomes are listed explicitly; the appendix retains the remaining outcomes and every paired delta.

| Pool/workload/phase | Paired median Δ [95% interval] | Slower/10 | Sign p |
|---|---:|---:|---:|
| canonical/table-20x10/first-slide | +2.124% [+0.003,+3.350] | 8 | 0.10937500 |
| canonical/table-20x10/lazy-open | +6.503% [+0.329,+9.709] | 8 | 0.10937500 |
| supplement/unicode-latin.pptx/traversal | +3.163% [+0.931,+14.206] | 8 | 0.03906250 |
| supplement/long-combining.pptx/warm-unchanged-save | +3.405% [+0.244,+4.333] | 8 | 0.10937500 |
| native/native-paint-placement-v2.pptx/reopen | +1.290% [+0.159,+3.410] | 8 | 0.10937500 |
| native/native-paint-placement-v2.pptx/unchanged-save | +1.360% [+0.750,+1.839] | 9 | 0.02148438 |
| native/native-paint-eligibility-v1.pptx/initial-save | +0.371% [+0.046,+2.005] | 8 | 0.10937500 |
| native/native-list-markers-followup-v1.pptx/initial-save | +0.358% [+0.066,+1.164] | 9 | 0.02148438 |
| native/native-list-markers-followup-v1.pptx/unchanged-save | +0.973% [+0.274,+1.757] | 9 | 0.02148438 |
| native/ordinary-buNone-large-style-200.pptx/initial-save | +0.688% [+0.265,+1.203] | 9 | 0.02148438 |
| native/ordinary-buNone-large-style-200.pptx/unchanged-save | +0.369% [+0.014,+1.042] | 8 | 0.10937500 |
| native/ordinary-inherited-bullet-unicode-200.pptx/unchanged-save | +1.080% [+0.032,+2.497] | 8 | 0.10937500 |
| native/placeholder-inherited-bullet-200.pptx/initial-save | +0.631% [+0.266,+1.889] | 9 | 0.02148438 |
| native/placeholder-inherited-bullet-200.pptx/unchanged-save | +0.421% [+0.286,+0.949] | 9 | 0.02148438 |

Opening/saving/traversal outcomes are not silently attributed to marker rendering. Tiny absolute phases can have large percentage changes; see complete baseline/candidate milliseconds in the appendix. All raw other phases remain available for review.

## Native bytes and preservation

| Input | Baseline SVG bytes | Candidate SVG bytes | Delta |
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

Every candidate native byte count matches cycle1. Equal counts alone do not prove geometry, so separate exact corpus proof compares all artifacts: 148 cases/842 slides, two fresh cycle2 runs per case, every SVG/ordered diagnostic/inheritance flag/saved package byte-identical to cycle1. The 296 baseline/cycle1 artifact sets are rehashed historical reuse, not new executions; 296 candidate proof processes and 296 independent python-pptx reopens are fresh. All original baseline-to-marker deltas remain unchanged. Fixed small/large/image-heavy preservation additionally runs all three variants fresh and passes exact artifacts, deterministic save, unchanged part payloads and reopened SVGs, with 9 additional external reopens.

Standalone shaping 101,310 combined records and layout/DOM 1,728 records, candidate twice, equal retained accepted baseline. Source-pinned worker focused/full tests cover 24 marker cases/277 visible glyphs/3 omissions and 47 prior native placement cases without tolerance changes. Full worker tests pass 1,162/166 plus 18/3; final alias-focused test refinement passes 3 tests. Native source fixtures/metrics/font hashes and logs are pinned in native-proof.json. Historical transfer proofs are background; they are not misrepresented as a fresh GUI export of cycle2. Root owns integrated app/GUI verification; no such gate is claimed from these library proofs.

## Host and timing scope

Nine snapshots span 2026-10-04T14:36:29.667745-07:00 to 2026-10-04T14:37:43.941318-07:00. WindowServer 28.4–30.4%; backupd 41.2–135.1%; Photos/Spotlight 0% in sampled observations. Root/agent builds/tests/GUI were paused; background load was not controlled. No settings changed. Snapshots cannot prove continuous isolation or remove load bias.

Execution receipt elapsed 74.32129858399276s; final post-write log 74.32157116697636s (both 74.32s). All three pools exited 0. Plan/launch/host snapshots, every raw phase and binaries/source pins are retained in this directory. No adaptive timing repeat occurred.

Candidate benefits are bounded to the observed marker/ordinary-inheritance workloads. Residual buNone/placeholder costs, followup uncertainty, mixed RSS and backup load remain explicit acceptance questions. No net historical recovery, universal nonregression, cross-platform or clean-host claim is made. Cycle1 remains WITHHELD.
