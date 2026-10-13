# Measured native table columns

`TemplateTableContent.columnSizing` adds opt-in `.measured(constraints:)` width
allocation for plain native tables. The existing `.estimated` default and explicit
column weights retain their behavior. Measurement uses the same native cell
typography, padding and wrapped geometry that the row planner accepts.

The Templates Library Lab retains both estimated and measured output decks.
Its fixed 24-row specimen reduces six pages to five on 16:9 and eight pages to
five on 4:3. Every original cell, repeated header and caption survives export and
reopening. The text keeps its full authored size. This result depends on the
fixture and constraints; it is not a guaranteed reduction for arbitrary tables.

## Allocation and limits

- Hard minimum/maximum bounds must be feasible and match the grid. Defaults are
  a 24-point minimum and no additional maximum. Optional preferred widths are
  soft tie-breaks after fit, page count and total row height.
- The existing heuristic or explicit weights seed an integer-EMU allocation
  projected into the bounds. Every candidate fills the exact template slot width.
  Invalid inputs throw before mutation.
- Actual occupied glyph widths identify spare column space. A compact candidate
  and coarse-to-fine pair transfers explore alternatives. Only strictly better
  scores replace the constrained seed; fit/placeable rows outrank page count,
  which outranks total row height and preferred widths. Restrictive constraints
  can change the seed relative to the unconstrained heuristic.
- The search evaluates at most 24 allocations and 32,768 extra cell visits beyond
  the baseline. Pagination may measure up to four distinct native style positions
  per visit. Unchanged columns reuse at most 128 entries / 32,768 cell results.
  Counts and budget exhaustion are exposed in `TableColumnSearchSummary`.
  These limits apply to each search; considering more template layouts costs more.
- Scratch caches expire after planning. Single-slide composition freshly measures
  accepted widths. Pagination preflight repeats the bounded search with live
  fonts/styles and rejects changed geometry before inserting slides.
- This is a bounded local search, without global-optimality guarantees, native
  PowerPoint autofit, row splitting or font shrinking. The existing plain-grid,
  unmerged horizontal-cell and shaping support boundaries still apply.
- The API remains pure Swift with no new dependencies. Lectern generation and
  recovery do not automatically enable measured widths or continuation groups.

## Performance method

The [Release driver](benchmarks/2026-10-12-table-columns.swift) compares estimated
and measured widths on fixed 24- and 1,000-body-row description tables, plus a
100-row short-cell case. Each has three columns and repeated/distinct row labels,
a pinned object layout, registered regular/bold DejaVu Sans and five trials per
case. Trial zero is excluded from medians, and mode order alternates by trial.
Input setup and font registration are outside the timers. Composition includes
fresh preflight and native slide/table/caption creation; ZIP serialization, SVG
rendering and the 24-row saved-file checks are outside the timers.

The [collector](benchmarks/2026-10-12-table-columns-collect.py) also runs five
alternating baseline/candidate process pairs for the existing
[small-table](benchmarks/2026-10-12-table-layout-small.swift) and
[pagination](benchmarks/2026-10-12-table-pagination.swift) drivers. Baseline binaries
were preserved before algorithm changes, from the implementation merged at
`d9354b6`. These comparisons exercise the unchanged estimated-width path.

Results use Swift 6.1.3 Release on the shared Linux AMD EPYC 9V74 host, with no
concurrent builds/tests. Elapsed times describe these fixtures, not device
guarantees or CI thresholds. Raw samples are retained in the
[record](benchmarks/2026-10-12-table-columns.json).

All arrows below are **estimated → measured**. The description benchmark uses
default measured bounds rather than the Lab's explicit constraints and longer
caption, so its page counts differ from the Lab specimen.

| Body rows | Cells / labels | Pages | Plan, ms | Compose including preflight, ms |
| ---: | --- | ---: | ---: | ---: |
| 24 | Descriptions / repeated | 6 → 4 | 2.095 → 9.037 | 4.367 → 10.012 |
| 24 | Descriptions / distinct | 6 → 4 | 2.246 → 10.733 | 4.533 → 13.177 |
| 1,000 | Descriptions / repeated | 250 → 167 | 43.639 → 250.369 | 133.026 → 313.063 |
| 1,000 | Descriptions / distinct | 250 → 167 | 58.167 → 357.487 | 148.308 → 423.364 |
| 100 | Short / repeated | 10 → 10 | 5.160 → 5.067 | 9.213 → 9.506 |
| 100 | Short / distinct | 10 → 10 | 7.119 → 6.954 | 10.990 → 11.354 |

The description search evaluates 18 allocations. At 24 rows it performs 450
additional cell visits and reuses 825 column-cell results; at 1,000 rows it
performs 18,018 additional visits and reuses 33,033 results. Reuse counts include
repeated visits, so they can exceed the cache's retained-cell budget. Short cells
reach the hard minimum row height immediately and stop at one allocation with
zero extra cell visits. These results show a space/cost tradeoff: the description
fixture needs about 4–6 times the planning time to reduce its page count by about
one third. Composition repeats the search for reliable fresh preflight.

| Existing estimated-width workload | Labels | Baseline median, ms | Candidate median, ms | Median paired change |
| --- | --- | ---: | ---: | ---: |
| Twenty eight-row slides | Repeated | 40.098 | 40.773 | +1.32% |
| Twenty eight-row slides | Distinct | 43.451 | 44.751 | +0.80% |
| Plan 100 body rows | Repeated | 5.507 | 5.298 | −4.05% |
| Plan 100 body rows | Distinct | 7.720 | 7.307 | −0.83% |
| Plan 1,000 body rows | Repeated | 44.444 | 44.328 | +1.31% |
| Plan 1,000 body rows | Distinct | 64.480 | 63.865 | −0.67% |

Individual paired changes span approximately −9% to +9%; the small median
changes sit within observed shared-host variation. They do not establish a
default-path speedup or a statistically bounded regression guarantee. Median
paired changes differ from ratios of medians. The 100-row pagination comparisons
retain the same page boundaries as the existing prefix-fitting reference.

Peak child-process RSS across the collector's workloads is 32.6 MiB, including
input/font setup, plans, composed decks and saved-file checks. This does not
isolate the optimizer's allocations. The retained 24-row benchmark decks also
pass saved geometry and ordered-cell checks independently of the Lab.

To build the measured driver after building RostrumLayout in Release:

```sh
swift build -c release --target RostrumLayout
swiftc -O -I .build/release/Modules \
  docs/benchmarks/2026-10-12-table-columns.swift \
  .build/release/Rostrum.build/*.o .build/release/RostrumLayout.build/*.o \
  -o /tmp/table-columns-benchmark
/tmp/table-columns-benchmark /tmp/table-column-specimens > /tmp/table-columns.json
```

## Verification

Seven focused regressions cover actual page reduction, hard bounds and exact EMU
residuals, soft preferences, unchanged defaults, invalid constraints without
mutation, exhausted budgets on a complete 4,000-row grid, exact Unicode bytes,
fresh font registration, native band typography and deterministic saved geometry.
Existing table/pagination regressions continue to exercise stale-plan rejection
and no partial insertion on fit failures.

The complete local `scripts/verify.sh --fast` gate passed: 1,312 root tests,
38 Release preparation/shaping/table tests, 309 LecternCore tests, 36 saved
PowerPoint reference comparisons, portable oracle checks and README execution.

The Templates Library Lab runs through the actual export/inspector/reopen pipeline
on both canvas sizes. All 44 checks pass, including identical SVGs after reopening
and independent saved-cell fits. The complete decks now have 11 and 12 slides.
All 36 pre-existing comparison artifacts remain byte-identical, excluding the two
intentionally expanded complete decks. Independent python-pptx reopening passed
for 14 PPTX files; ZIP CRC checks passed for all 22 PPTX/POTX/PPSX archives. The
new 4:3 table preview was inspected with resvg.

The Lab retains its font/style diagnostics: the template bundles a regular face,
so bold preview styles can use viewer synthesis; existing notes report their
missing Calibri resource. The registered-font benchmark and tests are separate
from those Lab diagnostics. Native PowerPoint visual acceptance remains pending
for the new specimen. Portable geometry, SVGs and existing reference comparisons
do not establish that acceptance. Apple app builds and app-hosted tests are
unavailable in this Linux environment and remain separate CI checks.
