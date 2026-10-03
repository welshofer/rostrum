# PERF-1: scan ASCII break opportunities without grapheme allocation

Baseline: `cf1b8a0cec2cf680383cb683603785aeaa0f2011`, branch
`codex/burndown/layout-perf2-20261003`. This follow-up changes only
`TextShaper.lineBreaks(in:)`: an ASCII-only byte scan emits the existing space,
hyphen and CR/LF opportunities. CR/LF remains one mandatory break after both
scalars. Any non-ASCII input uses the unchanged general grapheme/CJK path.
There are no geometry, shaping arithmetic, font lookup, cache or diagnostic changes.

## Evidence and method

The current baseline release executable and library object were retained before
implementation. Three-second `sample` profiles covered repeated fallback and
registered 2,000-cell table rendering plus rich-text fitting. The registered
table profile shows a 39-sample branch entering line-break collection from
fragment reshaping; the fitting profile has a 68-sample branch. Character arrays,
temporary strings and repeated CJK neighbor checks are unnecessary for ASCII.
These nested inclusive samples locate work; they are not speed estimates.

Both libraries were built with
`swift build -c release --product rostrum-bench --jobs 2`. The unchanged benchmark
driver was compiled against each retained object with identical
`swiftc -swift-version 6 -O` flags. The
[verification receipt](benchmarks/2026-10-03-linebreaks-2-verification.json) pins
objects, executables, source, profiling/oracle drivers and check logs. Retained
scratch evidence is in the worker's `.build/perf4/`.

The [raw paired report](benchmarks/2026-10-03-linebreaks-2-paired-macos.json)
records ten alternating fresh-process pairs after one excluded warmup pair,
on the same arm64 Mac/compiler/Arial bytes. The orchestrator explicitly held
GUI/build/test activity and notified other workers to pause for this measurement.

| Scenario / phase | Baseline median | Candidate median | Candidate faster pairs |
| --- | ---: | ---: | ---: |
| Registered Arial, 100 × 20 table: render | 83.159 ms | 79.867 ms | 10 / 10 |
| Registered Arial, 2,600-character text: rich fitting | 14.640 ms | 14.502 ms | 9 / 10 |
| Same text after fitting: render | 3.170 ms | 3.189 ms | 6 / 10 |
| Fallback 200 × 50 table: render | 175.882 ms | 171.326 ms | 8 / 10 |
| Fallback 10-slide deck, first slide: render | 0.568 ms | 0.568 ms | 5 / 10 |

Registered table rendering improves **3.96%** by median. Its baseline range is
82.017–84.292 ms and candidate range is 78.776–80.640 ms, with every candidate
sample below every baseline sample. The smaller rich-fitting change (0.94%)
and fallback table change (2.59%) have overlapping observed ranges; they do not
support a broader performance claim. Rendering the fitted text is 0.62% slower
by median, also within overlapping ranges. Mixed/non-ASCII inputs retain the
general path and may pay a short extra ASCII check.

Whole-scenario median peak RSS is about 52.75 → 52.68 MiB for the registered
table and 199.77 → 199.56 MiB for the fallback table. These peaks do not isolate
the render phase and do not establish a net memory improvement. Linux/iOS speed
and general latency thresholds remain unmeasured.

```sh
ROSTRUM_BENCH_FONT=/System/Library/Fonts/Supplemental/Arial.ttf \
python3 Tools/rostrum-bench/run.py \
  --binary .build/perf4/candidate-extended-bench \
  --paired-binary .build/perf4/baseline-extended-bench \
  --paired-revision cf1b8a0cec2cf680383cb683603785aeaa0f2011 \
  --runs 10 --warmups 1 \
  --scenarios table-200x50 shaped-table-100x20 richtext-fit slides-10 \
  --output /tmp/linebreaks-paired.json
```

## Preservation and verification

The [identity receipt](benchmarks/2026-10-03-linebreaks-2-output-identity.json)
records **58 fixture/font combinations and 580 slides** with byte-identical SVG,
ordered diagnostics, inheritance flags and saved PPTX. It covers existing
fixtures, including the two paragraph-justification fixtures added since the
preceding pass, plus generated registered-table/fitted-text decks, under empty
and four-face Arial/Calibri registries. The proof command's before/after saves
also verify rendering does not mutate documents. All 116 saved outputs reopened
in python-pptx with table-cell traversal. This is preservation evidence, not new
Office fidelity acceptance.

Two tests add a compact frozen baseline oracle for all **16,384 ASCII pairs**
and explicit checks for chained CR/LF, empty strings and mixed Unicode grapheme
offsets. Existing 48-case frozen shaping, kerning, bidi, combining, Arabic/CJK
and direct-DOM-mutation checks remain green. The focused run passed 12 tests
in three suites; `swift test --jobs 2` passed **1,012 tests in 139 suites**.
Release build and `git diff --check` passed. No lint command is configured for
this lane. No runtime dependency, public capability, mutable global state or
GUI change was introduced. Integration verification remains the orchestrator's
separate gate; this is a local worker result.
