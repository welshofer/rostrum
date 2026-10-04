# PERF-1 / FUNC-2: measured fallback text fast path

Baseline: `bc9b2f6`, clean branch `codex/burndown/layout-performance-20261002`.
Both libraries were built with `swift build -c release --product rostrum-bench --jobs 2`
on the same macOS arm64 host. The baseline executable and object were retained
before changing `RichTextLayout.swift`; the candidate uses the same compiler and
flags. Binary/object hashes are in the [paired receipt](benchmarks/2026-10-02-layout-paired-macos.json).

A two-second `sample` profile of the existing warm 10,000-cell banded-table
driver found 361 inclusive samples inside shared layout out of 1,246 inside
rendering. `appendSegment` accounted for 62 inclusive samples; its fallback
path repeatedly materialized Unicode break opportunities and a scalar-offset
set for ASCII cell labels. These nested counts are not additive cost estimates.
The raw profile and retained executables remain in the worker's
`.build/layout-performance/`; the receipt records the profile hash.

The change creates fallback atoms directly when a segment is all ASCII and has
no font metrics. After the existing tab/newline split, ASCII has one scalar per
grapheme and space/hyphen are its only break opportunities. Atom widths retain
the original arithmetic and order. Registered-font shaping and non-ASCII
breaking still use the existing implementation. No persistent DOM cache,
font-selection change, Swift dependency, or renderer change was added.

The retained runner uses ten alternating fresh-process pairs after one excluded
warmup pair. Other workers held builds/tests during both measurement windows.

| Scenario | Baseline render median | Candidate render median | Candidate faster pairs | Baseline / candidate peak RSS median |
| --- | ---: | ---: | ---: | ---: |
| 200 × 50 table | 171.582 ms | 165.875 ms | 9 / 10 | 199.344 / 199.594 MiB |
| 100 × 20 table | 26.407 ms | 25.611 ms | 10 / 10 | 42.891 / 43.078 MiB |
| 10-slide mixed-text deck, first slide rendered | 0.504 ms | 0.508 ms | 6 / 10 | 12.672 / 12.781 MiB |

This supports a modest improvement on these fallback table workloads (3.33%
and 3.01% by median), with no memory improvement or general typography speed
claim. An earlier quiet pair on the same binaries measured 168.260 → 161.774 ms
and 26.314 → 25.050 ms. That exploratory receipt remains in worker scratch;
the committed receipt is the repeated run through the retained runner. The
historical 174.422 ms benchmark is not used as the matched comparison.

Reproduce the final pair with binaries built and retained from each revision:

```sh
python3 Tools/rostrum-bench/run.py \
  --binary .build/layout-performance/candidate-bench \
  --paired-binary .build/layout-performance/baseline-bench \
  --paired-revision bc9b2f6 --runs 10 --warmups 1 \
  --scenarios table-200x50 table-100x20 slides-10 \
  --output /tmp/layout-paired.json
```

`run.py` retains its original single-binary defaults. Paired mode captures raw
phase samples and per-child RSS and rejects unequal saved output hashes. The
checksum includes SVG length and is not treated as SVG identity.

The separate `rostrum-bench proof input.pptx output-directory` command captures
every slide's SVG, ordered fidelity issue array, inheritance flags, and saved
PPTX outside any timed path. The same current driver was compiled against both
retained release objects; exact commands and font hashes are in the
[identity receipt](benchmarks/2026-10-02-layout-output-identity.json).
All 52 fixture/font combinations (574 slides) matched byte for byte. This
includes the 30-case typography fixture, all 74 native table styles, real-deck,
image, border, notes, conformance fixtures, and the generated 10,000-cell table.
Both empty-font and four-face Arial/Calibri registries were checked; this is
output-preservation evidence, not new Office fidelity acceptance.

`swift test --jobs 2` passed **974 tests in 132 suites**. The added layout test
checks hyphen/space wrapping, tracking, tabs and CR/LF, ordered fallback
diagnostics, and fresh layout after direct DOM replacement with accented/CJK
text and a nonbreaking space. `python3 -m py_compile Tools/rostrum-bench/run.py`
and `git diff --check` passed. No configured lint command exists for this lane.

Local implementation is ready for integration; no push or deployment occurred.
