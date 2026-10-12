# Measured native table continuations

`TemplateLayoutEngine.planTablePages` plans plain rectangular table content in
actual template slots. `composeTablePages` creates editable native tables, repeats
the header/title/caption, and exposes source row ranges for callers' document
metadata. Columns remain fixed across the group. Each page reserves the caption
height and an eight-point gap before assigning body rows.

The implementation measures the complete prospective grid, reusing matching
candidate widths, typefaces and themes within its bounded cache. Body rows can move between native band/edge text styles;
the planner takes the maximum required height across those bounded positions.
Identical styles are measured only once per cell, and the existing bounded
measurement cache reuses repeated cells. A linear integer-EMU pass partitions
the rows. It does not reshape successively shorter table prefixes.

Composition performs one fresh whole-table measurement and preflights every
page's title before adding slides. Changed fonts/styles that change the accepted
geometry require replanning. A single oversized row fails without partial slide
insertion. Unknown template/master/theme XML remains untouched. Native page styles
restart on each page; this is deliberately not a conversion of imported rich tables.

## Boundaries

- One repeated header row, plain strings, rectangular horizontal cells. A
  header-only grid yields one page. Font shrinking and splitting a row are excluded.
- The existing default column heuristic or explicit positive column weights are
  used. This change does not optimize widths.
- Custom band text styles may produce conservative extra row height. This
  prevents overflow when a row changes its page position.
- Candidate reuse remains bounded to 64 entries / 8,192 cell results, with the
  existing 64-entry / 256 KiB estimated text-measurement payload budget per grid.
  Grids larger than the candidate budget may be measured again for another layout.
  The input, prospective XML and returned plans necessarily use linear memory.
- Fit rejection is preflighted. Arbitrary package failures during writing are
  not covered by a transaction/rollback guarantee.
- Callers attach notes, provenance, sections and recovery identity. Automatic
  Lectern generation/recovery pagination is a separate integration task.
- Native PowerPoint visual acceptance is pending. Portable geometry and saved
  reference comparisons do not establish native equivalence for the new specimen.

## Performance method

The [Release driver](benchmarks/2026-10-12-table-pagination.swift) uses fixed
100- and 1,000-body-row inputs, three columns, a pinned object layout, registered
regular/bold DejaVu Sans and five trials per case. The first trial is excluded
from medians. Repeated and distinct-label cases retain identical other columns.
Input setup and font registration are outside the timer. Composition timing
includes fresh preflight and native slide/table/caption creation, excluding ZIP
serialization and SVG rendering.

For 100 rows, the reference calls the existing single-slide planner through
`MeasuredPaginator.pages`, repeatedly fitting prefixes. This is a reference
strategy, not a previously shipped automatic table-pagination implementation.
The driver requires identical page boundaries. Scaling measurements are elapsed
times on a shared Linux host, not device guarantees or CI budgets.

Swift 6.1.3 Release results on the Linux AMD EPYC 9V74 host (five available
logical CPUs, no concurrent builds or tests) are retained in the
[raw record](benchmarks/2026-10-12-table-pagination.json).

| Body rows | Labels | Pages | Plan, ms | Compose including fresh preflight, ms | Prefix-fitting reference, ms |
| ---: | --- | ---: | ---: | ---: | ---: |
| 100 | Repeated | 10 | 5.291 | 9.369 | 77.916 |
| 100 | Distinct | 10 | 7.049 | 11.093 | 99.299 |
| 1,000 | Repeated | 100 | 43.379 | 84.952 | — |
| 1,000 | Distinct | 100 | 61.807 | 102.301 | — |

The 100-row comparison takes about 14–15 times less planning time than the
prefix-fitting reference while choosing identical boundaries. This is a
fixed-order, within-process comparison, not a speedup over previously shipped
automatic pagination. Peak child-process RSS was 28.5 MiB across the pagination
driver, including fonts, input setup, reference fits, plans and composed decks;
it does not isolate the planner's allocation.

The existing [small-table driver](benchmarks/2026-10-12-table-layout-small.swift)
also ran seven alternating baseline/candidate process pairs against the merged
planner at `91bcf62`. Each process composes twenty eight-row, three-column slides
per trial using fallback font metrics. The
[collector](benchmarks/2026-10-12-table-pagination-collect.py) retains every sample.

| Twenty existing single-table slides | Baseline median, ms | Candidate median, ms | Median paired change |
| --- | ---: | ---: | ---: |
| Repeated labels | 37.153 | 36.764 | +0.27% |
| Distinct labels | 39.592 | 40.716 | +1.20% |

Four of seven pairs are slower in each case, with individual changes ranging
from roughly −8% to +12%. The median paired change differs from the ratio of
medians. These small changes sit within the observed shared-host variation;
they do not establish a single-table speedup.

To build the pagination driver after a Release library build:

```sh
swift build -c release --target RostrumLayout
swiftc -O -I .build/release/Modules \
  docs/benchmarks/2026-10-12-table-pagination.swift \
  .build/release/Rostrum.build/*.o .build/release/RostrumLayout.build/*.o \
  -o /tmp/table-pagination-benchmark
/tmp/table-pagination-benchmark > /tmp/table-pagination.json
```

## Verification

The regression suite checks exact-EMU boundaries, header-only and single-page
tables, variable row heights, repeated headers, complete ordered source coverage,
caption fit, notes, unchanged original slide/template parts, deterministic saves,
custom band typography, oversized rows/headers/captions, malformed grids and
stale-plan rejection without insertion.

The Templates Library Lab creates a multi-page specimen on 16:9 and 4:3 canvases
through the actual inspector/export pipeline. Reopened tables must reproduce
every source row, retain headers/notes/captions, fit their reserved regions and
render the same SVGs. The generated `paginated-table-output.pptx` is retained for
native PowerPoint review.

The complete local `scripts/verify.sh --fast` gate passed: 1,305 root tests,
31 Release preparation/shaping/table tests, 309 LecternCore tests, 36 saved
PowerPoint reference comparisons, portable oracle checks and README execution.
The two Lab runs passed 38 checks total (six and seven slides including the
existing specimens). All 20 pre-existing comparison artifacts, excluding the
two intentionally expanded complete decks, remain byte-identical. Independent
python-pptx reopening passed for ten PPTX files and ZIP CRC checks passed for
all eighteen PPTX/POTX/PPSX archives. The 4:3 continuation preview was inspected.
Apple app builds and app-hosted tests are unavailable in this Linux environment;
the PR's Apple CI remains separate from local validation.
