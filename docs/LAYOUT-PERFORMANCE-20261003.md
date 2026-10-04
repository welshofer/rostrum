# PERF-1: bypass redundant ASCII normalization in registered-font shaping

Baseline: `57dfe35337fb466d14a995ebe1f7ed4f15735ad5`, branch
`codex/burndown/layout-performance-20261003`. This pass changes only the
normalization step in `TextShaper`; rich layout, kerning, bidi, font selection,
GSUB/GPOS and diagnostics retain their behavior. ASCII graphemes are already
NFC, so they now use their original scalars. Graphemes containing any non-ASCII
byte still use Foundation normalization. CR/LF remains one grapheme with two
scalar offsets.

## Evidence and method

The current release library and benchmark executable were retained before source
changes. Three-second `sample` profiles exercised repeated fallback and registered
2,000-cell table rendering plus rich-text fitting. In the registered-table
profile, the normalization call accounts for a 110-sample branch under line
fragment reshaping; fitting has a 213-sample branch under segment shaping.
These inclusive, nested counts identify redundant work, not a speed estimate.
The [verification receipt](benchmarks/2026-10-03-normalization-verification.json)
pins the baseline/candidate objects, executables, profiles, driver, source and
check logs. Scratch evidence remains in the worker's `.build/perf3/`.

Both release libraries used `swift build -c release --product rostrum-bench --jobs 2`.
The identical extended driver was then compiled against each retained library
object with `swiftc -swift-version 6 -O`. All measurements use the same arm64
Mac, compiler and Arial file. Other local workers held builds/tests and the
orchestrator held GUI work during measurement. The
[raw paired report](benchmarks/2026-10-03-normalization-paired-macos.json) records
ten alternating fresh-process pairs after one excluded warmup pair, binary and
font hashes, phase samples and per-child peak RSS. Peak RSS covers the whole
scenario, not the isolated phase.

| Scenario / phase | Baseline median | Candidate median | Candidate faster pairs |
| --- | ---: | ---: | ---: |
| Registered Arial, 100 × 20 table: render | 95.177 ms | 83.413 ms | 10 / 10 |
| Registered Arial, 2,600-character text: rich fitting | 19.260 ms | 14.623 ms | 10 / 10 |
| Same text after fitting: render | 3.863 ms | 3.139 ms | 10 / 10 |
| Fallback 200 × 50 table: render | 172.096 ms | 173.422 ms | 3 / 10 |
| Fallback 10-slide deck, first slide: render | 0.556 ms | 0.569 ms | 5 / 10 |

The measured improvement is **12.36%** for the registered table render and
**24.08%** for rich fitting. Fallback table rendering is 0.77% slower by median,
within its observed spread; this pass does not improve the fallback path.
The small mixed-text fallback timings are noisy and support no speed claim.
Whole-scenario median peak RSS is approximately 52.72 → 52.59 MiB for the
registered table and 199.54 → 199.76 MiB for the fallback table. No net memory
improvement or Linux/iOS performance claim is made.

The new `shaped-table-ROWSxCOLS` scenario explicitly requests Arial and registers
`ROSTRUM_BENCH_FONT` before rendering. `richtext-fit` measures `TextFrame.fitText`
with the same explicit registry, followed by rendering the fitted text. Supply
Arial for these scenarios; they are not an implicit font substitution benchmark.
Existing scenarios retain their previous behavior and defaults.

```sh
ROSTRUM_BENCH_FONT=/System/Library/Fonts/Supplemental/Arial.ttf \
python3 Tools/rostrum-bench/run.py \
  --binary .build/perf3/candidate-extended-bench \
  --paired-binary .build/perf3/baseline-extended-bench \
  --paired-revision 57dfe35337fb466d14a995ebe1f7ed4f15735ad5 \
  --runs 10 --warmups 1 \
  --scenarios table-200x50 shaped-table-100x20 richtext-fit slides-10 \
  --output /tmp/normalization-paired.json
```

## Preservation and verification

The [identity receipt](benchmarks/2026-10-03-normalization-output-identity.json)
records **54 fixture/font combinations and 576 slides** with byte-identical SVG,
ordered diagnostic arrays, inheritance flags and saved PPTX. It covers all
existing deck fixtures plus generated registered-table/fitted-text decks, with
empty-font and four-face Arial/Calibri registries. Both binaries use the same
`proof` driver, whose save-before/save-after guard also verifies that rendering
does not mutate the document. All 108 saved outputs independently reopened in
python-pptx, including table-cell traversal. This establishes preservation, not
new Office fidelity acceptance.

The added tests compare 48 frozen pre-change shaping outputs, including glyph
IDs, original ranges, advances, offsets, bidi levels, break opportunities and
ordered diagnostics. They cover ASCII/control text, CR/LF, ligatures, kerning
on/off, forced RTL, decomposed/non-ASCII normalization, Hebrew, Arabic, CJK and
unsupported sequences. Additional tests check all 128 ASCII scalars and fresh,
read-only layout after direct DOM mutation. Existing HarfBuzz and rendering
checks remain intact.

`swift test --jobs 2` passed **1,000 tests in 137 suites**. The focused shaping,
filtering, layout and normalization run passed 30 tests in four suites.
`python3 -m py_compile Tools/rostrum-bench/run.py` and `git diff --check` passed.
No lint command is configured for this lane. No runtime dependency, global cache,
public capability or GUI change was added. Root integration tests remain a
separate gate; this worker result is local and has not been pushed.
