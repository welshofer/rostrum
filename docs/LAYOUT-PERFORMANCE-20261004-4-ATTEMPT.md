# Unshipped ordered-property lookup experiment

Cycle 1 did **not** establish a fallback rendering improvement and is **not
shipped**. Fresh matched measurements against `e94ff88` found the 10,000-cell
fallback table 0.20% slower by median; all workload ranges overlap. The exact
source/test snapshots, patch, objects and logs remain in `.build/perf9-fallback/`.
Only this experiment's working source edit and new test were removed after their
retained copies were verified. No existing source or test assertion was weakened.

## Experiment and evidence

Profiles on freshly built `e94ff88e3e4094ab5f637297c8115e774870df04` showed
480 inclusive samples under layout construction for the large table, including
72 at run-style resolution and 52 at base-style resolution. The 200-cell table
showed 463, 82 and 63 respectively. These nested samples locate work; they are
not a measured speedup. An optimized Swift probe confirmed that
`lazy.compactMap(...).first` invokes a successful lookup twice (`[0, 1, 1]`).
The experiment replaced four first-match traversals with ordered loops, retaining
precedence and all parsing, style, color, geometry and diagnostic behavior. It
introduced no cache, dependency or global state. Removing duplicate lookups did
not establish an end-to-end fallback benefit.

[Ten-pair samples](benchmarks/2026-10-04-layout-property-traversal-4-paired-macos.json)
use the unchanged canonical runner, identical driver/compiler/font bytes, one
excluded warmup and ten alternating fresh-process pairs. The parent explicitly
held root GUI/builds and confirmed other lanes idle. The window was released
immediately after completion. Root later observed an unrelated external Release
Xcode compile, whose start time could not be recovered after it exited. Overlap
cannot be established retrospectively: external isolation is **unverified** and
this run is **inconclusive**, including its apparent absence of a gain. Profiling/build/correctness checks occurred on
October 3; authoritative timing occurred on October 4 after a blocked parent
app-state call was recovered. Earlier timings were not counted as new samples.

| Scenario / phase | e94ff88 median | Experiment median | Change | Faster pairs |
| --- | ---: | ---: | ---: | ---: |
| Fallback 200 × 50 table: render | 196.252 ms | 196.650 ms | +0.20% | 6 / 10 |
| Fallback 20 × 10 table: render | 3.799 ms | 3.752 ms | −1.21% | 6 / 10 |
| Registered 100 × 20 table: render | 83.162 ms | 83.130 ms | −0.04% | 4 / 10 |
| Rich fitting | 14.538 ms | 14.305 ms | −1.60% | 8 / 10 |
| Fitted text: render | 3.359 ms | 3.382 ms | +0.69% | 4 / 10 |
| Ten-slide deck, first slide: render | 0.580 ms | 0.571 ms | −1.46% | 6 / 10 |

Large-table ranges overlap at 191.464–201.653 versus 191.871–203.493 ms.
All other ranges also overlap. No performance or memory improvement is claimed.
New main commits arrived during the wait, so this receipt applies only to the
frozen e94ff88 experiment. Further work starts with a new `a9d870b` baseline.

## Correctness and retained proof

`swift test --jobs 2` passed 1,085 Rostrum tests in 151 suites and 18 RostrumLayout
tests in three suites. Both all-products Release builds passed. New parameterized
tests exercised empty/malformed first overrides, missing/empty font families,
defPPr styles, decorations, baseline shift, kerning, empty local spacing,
diagnostic ordering/deduplication and direct DOM/inheritance edits. Initial
new-test expectations incorrectly assumed duplicate warnings and natural height
for empty lnSpc; only those expectations were corrected, and all logs remain.

[Output identity](benchmarks/2026-10-03-layout-property-traversal-4-output-identity.json)
covers 92 fixture/font combinations and 734 slides, with byte-identical SVG,
ordered diagnostics, inheritance flags and saved PPTX, plus 184 independent
python-pptx reopen/table traversals.
[Preservation checks](benchmarks/2026-10-03-layout-property-traversal-4-preservation.json)
use the newly required `rostrum-benchmark` tool on fixed small, large-table and
image-heavy decks: all decoded part payloads preserved, deterministic saves,
reopened SVGs match, cross-version artifacts identical, six independent reopens.
Their single-sample timings ran amid other checks and are not performance proof.

The [verification manifest](benchmarks/2026-10-04-layout-property-traversal-4-verification.json)
pins 40 retained files, frozen source hashes, primary receipts and exact commands.
Native PowerPoint/GUI and cross-platform validation remain root-owned; this
unshipped experiment required no new native acceptance claim.
