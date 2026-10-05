# Fallback base-style parsing: bounded change and qualified measurements

Source commit `0a26b86431b285857162ed189c8ddb084f033d34` avoids resolving unused
base-style paint and font properties when layout has neither registered fonts
nor explicit fallback metrics. Output remains byte-identical across **734
compared slides** against current baseline `a9d870b`. The registered-font and
explicit-metrics paths still resolve the full style.

The ten matched pairs favor large fallback-table rendering, but **Time Machine
and WindowServer were active throughout the observed window**. The result is an
observation under background load, **not a confirmed clean-host speedup**. No
unqualified 2% improvement is claimed. The root accepted the small removal of
unused parsing after correctness verification; final combined measurement and
native integration remain separate gates.

## Source and profiling

Fresh baseline `a9d870b9f8145a40e76fd48998606da796e3e32d` includes the latest
native-grid atom append, body inheritance, final line-spacing and bullet-choice
changes. Historical `e94ff88` and pre-tab timings are not this baseline.
Three-second samples of repeated large/small fallback-table and ten-slide rendering
are retained. The large-table profile has 479 inclusive samples under layout
construction, 49 at full base-style resolution and 87 at required run resolution.
These nested samples locate work; they are not speed measurements.

Without any font metrics, the empty-line box only needs the inherited size.
The change preserves the exact first-present `sz` selection, malformed/empty
parsing, bounds, scaling and endPara defaults. It retains full style resolution
for registered/explicit metrics, and resolves a full style lazily if the defensive
bullet fallback needs it. Normal bullets retain their first run's style. No
atomization, arithmetic, geometry, diagnostic ordering, public API, dependency,
DOM mutation or persistent state was changed.

Cycle 1's ordered lookup-loop experiment remains **unshipped**, with separate
[attempt report](LAYOUT-PERFORMANCE-20261004-4-ATTEMPT.md), patch, tests, binary
snapshots and receipts. Its external-load isolation could not be verified. None
of those lookup-loop edits is included here. Two source cycles were completed;
no third iteration was made to chase measurement noise.

## Paired observations and load limitation

[Raw samples](benchmarks/2026-10-04-fallback-base-size-4-paired-macos.json) use the
unchanged canonical runner, identical Swift driver/compiler/Arial bytes, ten
alternating fresh-process pairs and one excluded warmup pair. Root stopped lane
build/test/GUI work and confirmed two process scans without compiler, build, test
or benchmark jobs before granting the window. Start/during/end snapshots then
revealed `backupd` at 139.8/129.1/128.1% CPU and WindowServer at
75.0/80.7/77.7%. No external compiler/build/test was observed. CPU percentages can
exceed 100% for multi-core work; these are snapshots, not continuous monitoring.
No backup or system setting was altered. The timing window was released
immediately after successful completion.

| Scenario / phase | a9d870b median | Candidate median | Ratio change | Faster pairs |
| --- | ---: | ---: | ---: | ---: |
| Fallback 200 × 50 table: render | 188.090 ms | 184.192 ms | −2.07% | 9 / 10 |
| Fallback 20 × 10 table: render | 4.001 ms | 3.900 ms | −2.52% | 6 / 10 |
| Registered 100 × 20 table: render | 75.462 ms | 75.698 ms | +0.31% | 4 / 10 |
| Rich fitting | 14.284 ms | 14.475 ms | +1.34% | 4 / 10 |
| Fitted text: render | 3.385 ms | 3.411 ms | +0.78% | 4 / 10 |
| Ten-slide deck, first slide: render | 0.586 ms | 0.587 ms | +0.26% | 6 / 10 |

All unpaired observed ranges overlap. That alone does not reject paired evidence.
The [paired analysis](benchmarks/2026-10-04-fallback-base-size-4-paired-analysis.json)
records primary large-table pair deltas, candidate/baseline percent:

`−3.317, −2.698, −2.809, −1.521, −2.251, −1.391, −1.425, −7.902, +1.561, −2.156`.

Their median is **−2.203%**. A seeded 100,000-resample percentile bootstrap of
the paired median gives a 95% interval of **−3.008% to −1.425%**; the exact
two-sided sign test gives **p = 0.021484**. These exploratory ten-pair estimates
favor the candidate under the measured conditions but cannot remove background
load bias. They are not corrected across workloads. A clean confirmation is
still needed before advertising a speedup.

Every other paired interval contains zero. In particular, registered rendering
has an interval of −1.912% to +1.287%, and fitting −0.704% to +2.300%.
Their small increases are consistent with measurement noise; full registered-font
and explicit-metrics style resolution remains unchanged. Process-wide median RSS
is 178.95 → 179.02 MiB for the large fallback table, 52.64 → 52.80 MiB for the
registered table and 21.42 → 21.44 MiB for fitting. No memory, general speed,
cross-platform or future combined-source improvement is claimed.

## Correctness and retained evidence

The fresh baseline passes 1,097 Rostrum tests and 18 RostrumLayout tests.
The candidate passes **1,098 tests in 152 Rostrum suites** and **18 tests in three
RostrumLayout suites**, including existing native tab and boundary tests.
Both all-products Release builds pass. No lint command is configured;
`git diff --check` passes.

The new seven-case size matrix crosses empty, malformed, nonfinite, zero, normal
and clamped sizes with three bullet choices, six paragraph forms, scaling,
endPara defaults, fields, breaks, inherited decoration/baseline properties and
subsequent DOM/inheritance edits. It compares the optimized no-font path with the
full-resolution path selected by a nonempty unrelated font library: both have
nil metrics and must return identical lines, extents and ordered diagnostics.
Layouts do not mutate source XML or retain stale style state across edits.

[Current output identity](benchmarks/2026-10-04-fallback-base-size-4-output-identity.json)
covers 92 fixture/font combinations and 734 slides with identical SVG, ordered
diagnostics, inheritance flags and saved PPTX; 184 saved presentations independently
reopen with python-pptx and table-cell traversal.
[Required preservation checks](benchmarks/2026-10-04-fallback-base-size-4-preservation.json)
run `rostrum-benchmark` on fixed small, 10,000-cell and image-heavy decks. Both
versions preserve all decoded payloads, deterministic saves and reopened SVG;
their SVG/PPTX artifacts match each other, with six additional independent
reopens. Their single-sample timings ran amid other checks and are diagnostic only.

The [verification manifest](benchmarks/2026-10-04-fallback-base-size-4-verification.json)
pins source/test hashes, retained objects/executables, profiles, logs, process
snapshots and the four primary receipts. All evidence is retained in
`.build/perf10-fallback/`; cycle 1 remains in `.build/perf9-fallback/`.
The source commit was made only after frozen source hashes were rechecked.

```sh
swift test --jobs 2
swift build -c release --jobs 2
swiftc -swift-version 6 -O -I .build/perf10-fallback \
  Tools/rostrum-bench/main.swift .build/perf10-fallback/candidate-Rostrum.o \
  -o .build/perf10-fallback/candidate-extended-bench
ROSTRUM_BENCH_FONT=/System/Library/Fonts/Supplemental/Arial.ttf \
python3 Tools/rostrum-bench/run.py \
  --binary .build/perf10-fallback/candidate-extended-bench \
  --paired-binary .build/perf10-fallback/baseline-extended-bench \
  --paired-revision a9d870b9f8145a40e76fd48998606da796e3e32d \
  --runs 10 --warmups 1 \
  --scenarios table-200x50 table-20x10 shaped-table-100x20 richtext-fit slides-10 \
  --output /tmp/fallback-base-size-4-paired.json
```

Commands assume retained matching objects/modules. Native PowerPoint, full app,
cross-platform checks and any final combined measurement are root-owned.
