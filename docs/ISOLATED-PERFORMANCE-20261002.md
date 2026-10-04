# Isolated renderer performance pass — 2026-10-02

Current integrated status: [October 2 implementation and verification](IMPLEMENTATION-20261002.md).
The checkpoint details below remain historical evidence.

This continues the immutable [stage-two handoff](ISOLATED-FIDELITY-20261002.md)
at `af5a011db7eb63f47c2cde0f48a38eae83237973`. Production source ends at
`ca522e8be30dfff9ac4c5bc17b74d4128008c9e9`. The original task remains the sole
integration owner. Its checkout, index, branch and PowerPoint session were not
changed. These are local results, with no merge, push or publication.

## Measured gains with unchanged output

The same release driver, inputs and compiler compare stage two against the new
source. Two invocation pairs run in AB then BA order, with 30 renders each;
the first render of each invocation is excluded, leaving 58 measured samples
per variant. No builds or profiling ran concurrently. All four scenarios retain
byte-identical SVG, ordered fidelity issues and inheritance flags.

| Warm render | Stage two | Current | Reduction |
| --- | ---: | ---: | ---: |
| 10,000 cells, banded | 161.549 ms | 141.646 ms | **12.32%** |
| 10,000 cells, grid | 146.847 ms | 131.870 ms | **10.20%** |
| 250 unique images | 1.844 ms | 1.823 ms | 1.11% |
| 250 repeated images | 1.685 ms | 1.630 ms | 3.26% |

The [paired report](benchmarks/2026-10-02-stage3-render-paired.json) retains
every sample and output hash. Small image differences are not universal gains.

The unchanged [fresh-process suite](benchmarks/2026-10-02-stage3-macos.json)
completes all 12 scenarios, one warmup and five measured samples each. Every
saved-PPTX hash set matches stage two; independent python-pptx reopening and
table traversal pass. Large-table rendering changes **196.723 → 175.184 ms**,
a **10.95%** reduction. Median peak process RSS is **199.391 MiB** versus
199.500 MiB; this does not establish a meaningful memory improvement.

Unfavorable measurements remain visible: 1,000-slide construction changes
306.042 → 313.816 ms (+2.54%) and MovieAndComments unchanged-save changes
29.429 → 30.014 ms (+1.99%), both with separated observed sample ranges.
GoogleSlides and MovieAndComments render medians rise 2.40% and 3.49%, with
overlapping ranges. Repeated-image fresh rendering changes 2.765 → 2.771 ms.
The production changes are in rendering; these observations do not establish
that they caused construction, reopening or saving differences.

**Font-method clarification:** none of these table/image render measurements
registers fonts. In `rostrum-bench`, `ROSTRUM_BENCH_FONT` loads the pinned Arial
file only for the separate text-fitting phase after rendering. The recorded
font hash must not be interpreted as evidence of registered-font rendering.
Registered-font fidelity preservation is checked separately below.

## What changed

- `5d785b2`: resolve paragraph line spacing/alignment once, avoid temporary
  arrays for line maxima, and skip face-key construction when the font registry
  is empty. Percentage multiplication/division order is preserved. Table text
  now receives numeric margins and an explicit anchor directly, eliminating
  per-cell body XML copying and integer/string roundtrips. Wrap, autofit,
  rotation, inherited properties and nonmutation retain their existing behavior.
- `0714695`: diagnostic traversal processes empty and single-child wrappers
  without allocating a child-element array. Every node's issue checks still
  run; malformed descendants, document order, same-name path indices and
  disabled inline-style exclusion remain intact.
- `ca522e8`: owners with fewer than 512 relationships use the original lookup.
  A four-entry prefix serves sparse early references without owner-state
  allocation. Larger searches retain measured-work admission and the existing
  16-owner, 4,096-entry and 512-KiB accounting limits. First-match behavior,
  Unicode equality, external/missing targets and reset remain unchanged.

Seven new tests cover table geometry/rotation/mutation, paragraph metrics and
malformed spacing, diagnostic traversal through mixed markup, and image lookup
boundaries. The combined source has been independently reviewed.

## Image scaling and its tradeoffs

The [ten-case sweep](benchmarks/2026-10-02-stage3-images.json) uses 198 measured
samples per variant. Every SVG and ordered diagnostic result matches exactly.
Owned valid PNG fixtures span 100, 250, 510, 511, 768, 1,024 and 2,000 pictures;
the slide also has one layout relationship. Thus 510/511 pictures straddle the
512-relationship policy boundary. Source/generator/input hashes are retained
in the [fixture manifest](benchmarks/2026-10-02-stage3-image-fixtures.json).

Most stage-three differences are small. The 510-picture case is **1.32% slower**
(5.084 → 5.151 ms) in both rounds. The two-picture/4,096-relationship case is
**1.54% slower** overall (0.041896 → 0.042542 ms), with a 4.14% slowdown in its
second pair. Its earlier exploratory run improved, so no reliable sparse-case
gain is established. The policy is not a promise that every small case improves.

The dense workload is only 0.57% faster than stage two in the final sweep.
Against the separately retained pre-index `9478ea9` binary, it remains
**10.46% faster**, **22.719 → 20.343 ms**, with both invocation pairs improving
and exact outputs. That [comparison](benchmarks/2026-10-02-stage3-dense.json)
demonstrates preservation of the earlier scaling benefit. These overlapping
one-pixel pictures stress relationship lookup, not representative image content.

## Reproducing and interpreting the historical gap

Historical source `83c1f1962e017cc10726fa13f911bff9338c54c8` was extracted into
a separate local directory and built with the same compiler and release mode.
Both eras execute the same standalone driver on one frozen, hashed PPTX, open
and traverse shapes before rendering, and register no fonts. Only modern
post-timing diagnostic serialization uses an extra compilation define because
the historical issue API does not exist. Historical issue count is unavailable,
not zero. Source files, binaries, driver, flags and input hashes are retained.

The [historical comparison](benchmarks/2026-10-02-stage3-historical.json) uses
20 measured process pairs after one warmup pair, alternating AB/BA. Four renders
per process yield 20 first-render and 60 warm samples per era:

| Same frozen PPTX | Historical | Current | Current / historical |
| --- | ---: | ---: | ---: |
| First render after open/traversal | 74.644 ms | 175.020 ms | **2.345×** |
| Warm renders | 70.893 ms | 171.288 ms | **2.416×** |

This reproduces a material historical gap under matched inputs and instrumentation,
but **the work semantics differ**. Both outputs contain 10,001 rectangles and
62,500 text elements. Historical output draws 10,000 gray borders despite the
No Grid table style; current output draws none. Current output adds 62,500
styled `tspan` elements with explicit layout widths (estimated because no fonts
are registered) and preserves padding, anchors, tracking and whitespace.
Historical rendering flattened run styles and omitted
the modern fidelity diagnostics. Output size changes 10,509,694 → 14,787,534 bytes.
Current rendering reports two missing-font and two viewer-font-dependency issues.

These are unusually narrow 200×50 cells: their authored four-point margins leave
only 6.4 points of text width. They stress repeated wrapping and emission. The
historical report cannot identify all extra cost as unavoidable correct work,
nor can its timing be used as an identical-output optimization target. The
unchanged-output stage-two comparison above measures the avoidable cost removed.
Directly authored warm inputs and reopened-PPTX inputs also have different
preparation paths; compare timings within each study.

The [pre-change sampled profile](benchmarks/2026-10-02-stage3-profile.json)
partitions 4,897 main-thread snapshots without double-counting inclusive frames:
30.26% rich layout, 31.84% text rendering outside layout, 17.50% diagnostic XML
inspection, 19.05% remaining table/style/paint, and 1.35% other work. The text
bucket includes post-layout diagnostics, font lookup and cleanup, alongside SVG
serialization. Worker waits are excluded. Inlined/unwound frames stay with their
visible ancestor; these shares are not precise milliseconds or speedup forecasts.
The remaining useful target is repeated layout/emission work under the full
current contract, especially the parsed-deck path, without dropping spans or issues.

## Verification and remaining blockers

The exact production source at `ca522e8` passes **926 library tests / 125 suites**
and **168 Lectern core tests / 15 suites**. macOS app and hosted-test-bundle
compilation succeeds; iOS simulator builds succeed for arm64 and x86_64.
Hosted-app execution and Linux testing remain unperformed. No app was launched.

[Preservation checks](benchmarks/2026-10-02-stage3-preservation.json) compare
eight first-slide cases, including four with hash-verified Calibri/Arial fonts,
and all 116 slides of the border/native-style fixtures. SVG and diagnostic
results match. Prior combined CLI logs interleaved one stdout path with a
diagnostic; extraction retains diagnostic-message order without requiring a
line-start prefix. No issue is dropped or reordered to obtain the match.
All **737 border probes** and **1,480 fill probes** pass again.

The unchanged [native v3 gate](benchmarks/2026-10-02-stage3-native-comparison.json)
was rerun and **still fails at 18,082 / 840,000 pixels (2.152619%)**, against
the unchanged 0.5% limit and channel tolerance 16. Its SVG and corrected PNG
are byte-identical to stage two. This pass changes performance, not acceptance.
The direct-slide typography reference requested in stage two remains outstanding.

At 2026-10-02 04:57:37 UTC, the supported owner-task API still reports
`waitingOnApproval`, without exposing the request. The authorized message asking
for approval details, safe exports and integration status was delivered, but no
answer or integration acknowledgment is visible. Original checkout HEAD remains
`2783ea38616cfd7c30ad2358c1056b9dc3f19481` with its existing dirty documentation
and reports. No unknown approval was accepted. The [verification manifest](benchmarks/2026-10-02-stage3-verification.json)
pins tested source, raw logs, binaries, reports and preserved prior evidence.
