# Combined layout follow-up: attempted fast path NOT SHIPPED

The retained integration code remains `7fca2ee`. Its matched checkpoint measured
**2.26% slower fallback table rendering and 3.01% slower rich-text fitting** than
`cf1b8a0`; registered table rendering was 0.75% faster with overlapping ranges.
The earlier isolated ASCII-scan result does not describe combined performance.
See the unchanged [combined checkpoint](INTEGRATED-LAYOUT-PERFORMANCE-20261003.md).

One bounded no-tab fast-path attempt passed correctness checks but did not resolve
those regressions. **The attempted source change was discarded and is not shipped.**
This report preserves that negative result; it is not a new performance claim.

## Scope and evidence

Combined-code profiles identified an unnecessary `rtl` lookup for paragraphs
without tabs (four samples in the fallback table profile) and the hot word-carry
path in repeated fitting (a 602-sample inclusive branch that includes line
emission). Those nested counts do not isolate the cost of the carried-width sum.
They motivated a small experiment, not proof of the regression's cause.

The [retained patch](benchmarks/2026-10-03-integrated-layout-unshipped-attempt.patch)
gated standard-tab RTL resolution on `hasTabs` and restored the original ordered
`carry.reduce` for paragraphs without tabs. Tab paragraphs kept their existing
re-anchoring loop. The attempt added no caching or geometric/arithmetic changes.
No further implementation iteration was made.

Release build passed. The same benchmark driver was compiled with identical
`swiftc -swift-version 6 -O` flags against the retained candidate object. In a new
explicitly granted quiet window, ten alternating fresh-process pairs followed
one excluded warmup pair against the retained `cf1b8a0` baseline executable.
The [raw samples](benchmarks/2026-10-03-integrated-layout-fix-paired-macos.json)
and [verification receipt](benchmarks/2026-10-03-integrated-layout-fix-verification.json)
pin binaries, source, patch, profiles and check logs.

| Scenario / phase | Baseline median | Unshipped attempt median | Attempt faster pairs |
| --- | ---: | ---: | ---: |
| Fallback 200 × 50 table: render | 173.066 ms | 179.163 ms | 0 / 10 |
| Registered Arial, 100 × 20 table: render | 84.338 ms | 83.460 ms | 8 / 10 |
| Registered Arial, 2,600-character text: rich fitting | 14.842 ms | 15.385 ms | 1 / 10 |
| Same text after fitting: render | 3.251 ms | 3.366 ms | 3 / 10 |
| Fallback 10-slide deck, first slide: render | 0.565 ms | 0.580 ms | 2 / 10 |

The attempted code remained **3.52% slower** on fallback table rendering and
**3.66% slower** on rich fitting versus its matched baseline. Registered table
rendering was 1.04% faster with overlapping ranges. The fallback candidate's
175.903–191.208 ms range was entirely above the baseline's 170.763–175.749 ms
range. This experiment does not establish an acceptable regression fix. The
pre-attempt and attempted candidates were measured in separate paired runs;
their absolute timings are not a direct matched comparison with each other.

Whole-scenario median peak RSS was 199.80 → 199.67 MiB for the fallback table,
52.75 → 52.63 MiB for the registered table, and 20.96 → 21.03 MiB for fitting.
No net memory or cross-platform performance improvement is established.

## Correctness preservation and disposition

`swift test --jobs 2` passed **1,019 tests in 140 suites**, including all 60 cases
in the native PowerPoint tab-geometry oracle. The
[full corpus comparison](benchmarks/2026-10-03-integrated-layout-fix-output-identity.json)
against the retained `7fca2ee`-equivalent binary covered **76 fixture/font
combinations and 628 slides**, including all tab fixtures. SVG, ordered diagnostics,
inheritance flags and saved PPTX were byte-identical. All 152 saved outputs
reopened with python-pptx/table-cell traversal. These checks establish that this
attempt preserved output, not that it improved performance.

Only the worker's attempted source delta was restored after preserving its patch,
source hash and binaries. Root source was never changed by this experiment.
Existing integrated app verification therefore still describes the retained
engine. The next investigation should profile common layout overhead separately;
there is no further implementation or timing in this pass. Scratch evidence
remains in `.build/perf4-fix/`.
