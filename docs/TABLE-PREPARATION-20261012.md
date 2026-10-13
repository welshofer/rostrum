# Reuse native cell inputs during width search

Measured table width trials previously resolved native band styles, serialized
the same XML and prepared the same paragraphs repeatedly. The search now retains
width-independent cell inputs and bounded rich-text preparations for its own
immutable table. The optimizer, width candidates, row/page scoring, full-size
typography and fresh composition preflight are unchanged.

## Profile

The baseline is `9359abd` (measured column sizing). GNU gprofng reported that its
collection timer changed and its samples could be unreliable; those samples were
discarded. An [isolated instrumented copy](benchmarks/2026-10-12-table-preparation-profile.py)
of Release RostrumLayout instead recorded disjoint elapsed-time scopes around
style resolution, input validation, body/key serialization and rich-text layout.
No profiler code is included in the library.

The [profile record](benchmarks/2026-10-12-table-preparation-profile.json) contains
five 1,000-row plans per case, with 18 allocations per plan. Percentages below
refer to time inside table measurement, including instrumentation overhead; they
exclude prototype construction, outer template planning and font registration.
They identify repeated work, not uninstrumented end-to-end speedups.

| Scoped work | Repeated labels | Distinct labels |
| --- | ---: | ---: |
| Resolve native cell/style and serialize style | 59.3% | 42.9% |
| Validate width-independent cell properties | 4.4% | 3.4% |
| Serialize body and construct measurement identity | 22.3% | 15.7% |
| Rich-text geometry | 0.7% | 27.5% |

Each logical plan visited style resolution 84,021 times and serialized bodies
21,021 times. Repeated labels needed only 42 geometry calls, while distinct labels
needed 7,035. The existing exact-cell and column-result caches already helped
geometry; repeatedly rebuilding their inputs was the main avoidable cost.

## Implementation and limits

- Resolve effective native styles, unsupported-cell issues, padding and exact
  body/style bytes once for each retained cell position. Preserve native band
  style order and the existing style de-duplication rule.
- After the first allocation, prepare text when a column needs a new width.
  Retained cell inputs hold the prepared context directly for subsequent trials.
  Exact XML bytes and insets identify a canonical read-only body and
  its inherited style. Different styles and canonically equivalent but byte-distinct
  text stay separate. Paragraph properties, run styles and eligible scalar/break
  inputs can be reused; size-dependent glyph measurements and wrapping remain fresh.
- The cell-input cache admits at most 8,192 positions and 2 MiB estimated key
  payload. The text cache admits at most 1,024 contexts and 1 MiB estimated source
  key payload. Each context retains the existing 64-paragraph / 512-piece /
  64 KiB paragraph-text and 64-segment / 64 KiB segment-text limits. These are
  entry/payload budgets, not measurements of heap usage. Rejected entries use
  ordinary measurement without dropping cells or changing diagnostics.
- All caches end with one search. A later operation observes new source text,
  styles, themes and fonts. Composition still remeasures before inserting slides.
  One-allocation searches create no rich-text preparation contexts.
- Public APIs and search budgets are unchanged. The library remains pure Swift
  and dependency-free. No new rendering or shaping profile is admitted.

## Performance method

The [driver](benchmarks/2026-10-12-table-preparation.swift) uses fixed inputs and
registered regular/bold/italic DejaVu Sans, a pinned layout and identical title
and caption. It records monotonic elapsed time and process CPU time independently
for planning and composition including fresh preflight. Setup, font registration,
slide removal, serialization and rendering are outside those phase timers.

The [collector](benchmarks/2026-10-12-table-preparation-collect.py) runs five
alternating baseline/candidate process pairs for each workload, each with five
trials. Trial zero is excluded from timing medians. Both binaries use the same
driver and Swift 6.1.3 Release configuration on the shared Linux AMD EPYC 9V74 host,
with no concurrent builds or tests. `wait4` records each child's peak RSS, including
font setup, planning, composition and cleanup across all five trials. RSS does
not isolate optimizer allocations. All raw samples are retained in the
[timing and memory record](benchmarks/2026-10-12-table-preparation.json).

All arrows below are **baseline → candidate**. Timing columns are milliseconds;
memory is median per-process peak RSS in MiB. Percentage columns use the median
of paired changes, which differs from the ratio of medians.

| Rows / labels | Plan elapsed | Plan CPU | Paired CPU change | Compose elapsed | Compose CPU | Peak RSS |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 24 / repeated | 7.822 → 2.979 | 7.824 → 2.981 | −62.38% | 9.434 → 4.564 | 9.436 → 4.564 | 22.97 → 23.04 |
| 24 / distinct | 10.421 → 4.862 | 10.423 → 4.863 | −53.91% | 11.983 → 6.543 | 11.985 → 6.545 | 23.16 → 23.11 |
| 1,000 / repeated | 260.396 → 60.597 | 260.339 → 60.601 | −76.72% | 321.826 → 124.667 | 321.816 → 124.665 | 30.64 → 30.85 |
| 1,000 / distinct | 358.994 → 210.845 | 358.997 → 210.847 | −41.27% | 424.976 → 273.994 | 424.981 → 273.658 | 30.76 → 33.36 |
| 100 / short distinct | 6.819 → 7.210 | 6.821 → 7.212 | +0.56% | 11.198 → 11.253 | 11.200 → 11.255 | 23.18 → 23.36 |
| 1,000 / distinct, estimated widths | 60.408 → 61.046 | 60.413 → 61.050 | +0.53% | 153.632 → 156.212 | 153.649 → 156.218 | 32.52 → 32.54 |

Every measured description-table pair improves planning CPU: the 1,000-row
repeated range is −77.75% to −73.99%, and distinct is −44.77% to −40.07%.
Composition CPU improves by median paired 60.63% and 35.07%, respectively. The
distinct workload trades about 2.6 MiB of peak process memory for less repeated
work. Repeated labels show a small peak-memory difference.

The one-allocation short case and estimated-width control do not establish a
speedup: paired planning changes span −3.22% to +9.74% and −5.49% to +8.02%.
Short-case composition has a +5.44% median paired CPU change, spanning −5.95% to
+17.48%; estimated composition is −2.85%, spanning −8.23% to +5.30%. These small
workloads retain some metadata overhead and show shared-host variation. The
measurements are fixture-specific evidence, not latency or memory guarantees.

## Exact-output verification

The [preservation driver](benchmarks/2026-10-12-table-preparation-preserve.py)
compares separate baseline and candidate processes on six fixed cases: 24 rows,
mixed scripts, two 1,000-row description tables, a short-cell table, and the
estimated-width path. Across 740 artifacts, all column widths, row heights, page
boundaries, fit flags, cell issues and ordered diagnostics agree. Six saved PPTX
files and all 364 SVG previews are byte-identical. JSON object key order is
normalized; array and diagnostic ordering compare exactly. Each deck passes ZIP
CRC validation and each source row appears exactly once in the plan.
Independent python-pptx reopening also confirms the six candidate decks' headers
and body-row counts.

Four new regressions compare retained preparations against fresh measurement for
rich cells across changing widths, native bold/italic bands, tabs, spacing,
combining sequences, Arabic/CJK, missing fonts and unsupported geometry. They also
exercise the 1,024-context limit and fresh text/style/font changes. Existing tests
cover read-only planning, pagination, fresh composition preflight and saved files.

The complete local `scripts/verify.sh --fast` gate passes: 1,316 root tests,
42 Release preparation/shaping/table tests, 309 LecternCore tests, all 36 saved
PowerPoint reference comparisons, portable oracle checks and README execution.

Both Templates Library Lab variants pass all 44 export/inspector/reopen checks.
All 52 PPTX/POTX/PPSX/SVG artifacts, including the complete 11- and 12-slide decks,
are byte-identical to the baseline. Ordered inspector findings and every Lab
check also agree. Independent reopening passes for all 14 Lab PPTX files, and
all 22 Lab archives pass CRC validation.

The optimization preserves existing portable output. Native PowerPoint visual
acceptance for the measured-column specimen remains pending; these comparisons
do not independently establish it. Apple app builds and app-hosted checks remain
separate from the local Linux gate.

## Reproduction

Preserve a baseline Release binary before editing algorithms. Build the same
driver against baseline and candidate Rostrum/RostrumLayout objects:

```sh
mkdir -p /tmp/table-preparation
swift build -c release --target RostrumLayout
swiftc -O -I .build/release/Modules \
  docs/benchmarks/2026-10-12-table-preparation.swift \
  .build/release/Rostrum.build/*.o .build/release/RostrumLayout.build/*.o \
  -o /tmp/table-preparation/candidate
python3 docs/benchmarks/2026-10-12-table-preparation-collect.py \
  /tmp/table-preparation /tmp/table-preparation.json
python3 docs/benchmarks/2026-10-12-table-preparation-preserve.py \
  /tmp/table-preparation
```

For scoped profiling, check out `9359abd` separately, build its Release libraries,
then run the profile-copy script with that checkout and a scratch directory. Use
`swiftc -O -g -whole-module-optimization -parse-as-library -package-name rostrum
-module-name RostrumLayout -emit-module -emit-object` to compile the copied sources
against baseline Rostrum. Link the driver with that module/object and baseline
Rostrum objects. Run `1000 distinct measured 5 plan` and
`1000 repeated measured 5 plan`; stderr contains one JSON record per allocation.
