# PERF-1: exact initial glyph reservation (2026-10-04)

**Accepted for the bounded registered-rendering result after independent source, statistics and evidence review.** Registered rendering improved in all ten matched pairs against the fresh post-spacing baseline: median 70.4555 → 69.3345 ms (**−1.59%**); median paired change **−1.91%**, bootstrap 95% interval **[−3.01%, −1.14%]**, exact two-sided sign p=0.001953125. This supports a bounded registered-workload result under substantial background load. Fitting is inconclusive; no historical recovery, fallback, universal, cross-platform or lower-memory claim is made.

Baseline `fbbec90024dca2c7e43dca8201b4803dbf9aee6e` includes accepted singleton/array scalar storage and spacing engine `4da71de`; its Sources tree matches root `d494e55`. Both measured sides include that integration. Source commit `850a9185babafa3ba555b05d18bfe13f2b04056e` matches the frozen patch measured before commit. Retained Release objects, matching modules, compiler/driver/font hashes and the frozen candidate patch are pinned in the [verification manifest](benchmarks/2026-10-04-glyph-capacity-layout-9-verification.json).

## Profile and change

Fresh integrated registered-table sampling found **60 of 2,932 main-thread samples** attributed to initial glyph append (`TextShaper.swift:179`), including **51 nonoverlapping array-growth descendant samples**. These are attribution observations, not a predicted saving. The four-line change counts normalized scalars that emit initial glyphs during the existing classification pass, then reserves that capacity once. LF, CR and U+200B are excluded exactly as in unchanged emission. NFC can expand a source scalar, so the count uses normalized scalars while source ranges remain separate. Arabic delegation, glyph order, arithmetic, substitutions and diagnostic order are unchanged. No cache or retained DOM state is added.

Inspection of the integrated spacing work finds ordinary/100% paragraphs skip new raw-metric work, run snapshots and per-line calibration via `nativeSpacing`. Existing spacing lookup moved earlier rather than being duplicated. New branches, a guarded helper call and empty array context remain; no explicit spacing-metric frame appeared in this sample. Inlining and source attribution prevent a zero-overhead conclusion. No isolated pre/post-spacing speed comparison was performed.

## Paired results

“Change” compares medians; paired estimates resample each baseline/candidate pair together.

| Workload / phase | Baseline ms | Candidate ms | Change | Faster pairs |
|---|---:|---:|---:|---:|
| Large fallback render | 196.2362 | 196.4959 | +0.13% | 5/10 |
| Small fallback render | 3.8946 | 3.8697 | −0.64% | 5/10 |
| Registered render | 70.4555 | 69.3345 | **−1.59%** | **10/10** |
| Rich fitting | 12.2970 | 11.9684 | −2.67% | 7/10 |
| Fitted render | 3.0473 | 2.9498 | −3.20% | 7/10 |
| Ten-slide render | 0.6057 | 0.6122 | +1.06% | 4/10 |
| Supplement accented/CJK | 137.2088 | 135.1370 | −1.51% | 7/10 |
| Supplement mixed Hebrew/RTL | 131.6500 | 131.6966 | +0.04% | 5/10 |
| Supplement long combining | 432.0486 | 422.9408 | −2.11% | 8/10 |

Fitting paired median is −1.98%, interval [−6.68%, +0.48%], p=0.34375: inconclusive. Long combining has mixed statistical evidence: paired median −2.38%, interval [−6.66%, −0.26%], but sign p=0.109375. Accented/CJK and RTL intervals cross zero. Fallback and ten-slide inputs do not exercise this registered shaping path, so their changes are not attributed to it. All raw deltas are retained; 100,000 bootstrap resamples use seed 20261004. These exploratory, uncorrected estimates across several workloads cannot remove host-load bias or establish universal nonregression.

Whole-process median RSS is mixed: registered **54.7734 → 54.6563 MiB** (−0.1172); accented/CJK **49.5547 → 49.7656** (+0.2109); RTL **47.9219 → 48.1797** (+0.2578); long combining **41.3438 → 41.2813** (−0.0625). RSS includes the entire process, not just glyph storage; these observations do not establish lower allocation cost or memory use.

## Protocol and correctness

One authorized window ran **110 canonical + 66 supplementary fresh processes**, one excluded warmup pair plus ten alternating retained pairs per workload, using unchanged `Tools/rostrum-bench/run.py --runs 10 --warmups 1`. Both sides use Apple Swift 6.4 (swiftlang-6.4.0.34.1), `swiftc -swift-version 6 -O`, and identical hash-pinned Arial. The canonical driver is unchanged. The separate supplementary driver only enables registered fonts in existing `file` mode; timers/calls are unchanged. Three supplementary 2,000-cell decks retain the earlier exact input bytes and paths, but earlier timing results are not a baseline.

The window completed in **47.78 seconds** (canonical 24.82, supplementary 22.83), then was released. Six process snapshots show **WindowServer 97.6–99.3% CPU and backupd 30.7–43.4%**. No external compiler/xcodebuild/xctest was sampled. Snapshots do not establish continuous isolation. No settings changed and no repeat timing/cycle ran.

Three focused tests cover NFC expansion, CRLF/ZWSP-only output and mixed missing-glyph/mark diagnostic order. Full **1,136 Rostrum tests / 160 suites + 18 RostrumLayout tests / 3 suites**, Release build and `git diff --check` pass. All **101,022 full shaping records + 288 supplementary records** match byte for byte, including IDs, ranges, advance/offset bits, levels, breaks and ordered diagnostics. Expanded corpus proof covers **114 cases / 780 slides**, alongside five fixed workloads, required small/large/image-heavy preservation and three supplementary registered decks. SVGs, ordered diagnostics, inheritance flags and saved bytes are identical; repeated candidate outputs are deterministic. Independent python-pptx reopen/traversal passes for **273 saved files**. Parent owns the later integrated application/native gate.

Evidence: [canonical raw](benchmarks/2026-10-04-glyph-capacity-layout-9-paired-macos.json), [canonical paired analysis](benchmarks/2026-10-04-glyph-capacity-layout-9-canonical-paired-analysis.json), [supplementary raw](benchmarks/2026-10-04-glyph-capacity-layout-9-supplement-paired-macos.json), [supplementary analysis](benchmarks/2026-10-04-glyph-capacity-layout-9-supplement-paired-analysis.json). The manifest links all output/preservation receipts, source and compiler/module pins, exact commands, profile and process snapshots retained in `.build/perf19-glyph-capacity/`. Earlier experiments and evidence remain unchanged.
