# Horizontal spans in native table layout

`TableLayoutEngine` measures a native horizontal merge once at its anchor, using
the sum of its column widths and the anchor's resolved text, padding and style.
The physical row-major grid stays intact. Anchors expose `columnSpan`; covered
positions expose `isMergeContinuation` and contribute zero height, issues or
diagnostics. Read-only planning retains hidden continuation XML unchanged.

`TemplateTableContent.merges` accepts `TableMergeRegion` values with `rowSpan == 1`
and `columnSpan >= 2`. Regions must be inside the rectangular grid and must not
overlap. Covered input strings must be exactly empty: neither words nor whitespace
are silently discarded. Single-slide and paginated composition validate before
inserting slides. Header spans repeat, while body spans move with their source
row. A validated native batch writes all merge flags once, avoiding a table scan
per span. Existing `Table.merge` retains its public semantics.

Vertical and rectangular multi-row spans remain unsupported by layout and report
`.mergedCell`. Malformed native topology throws without mutation. This milestone
does not implement native table autofit, imported-table pagination, or automatic
Lectern generation/recovery integration. Native PowerPoint visual acceptance is
pending; portable fitting and independent reopening do not establish it.

## Width search and bounded reuse

An anchor-column cache entry depends on its own width and the combined width of
each distinct span anchored there. Changing a neighboring width invalidates the
affected entry. Covered positions never prepare or measure hidden text. Text
preparation remains exact-byte keyed and expires with the operation.

Span demand constrains a combined width, rather than reserving an arbitrary share
in each constituent column. Candidate generation reserves unmet span demand in
the column with the greatest ordinary text demand, with deterministic ties. This
allows short identifier columns to donate width within a grouped header. Height
pressure is distributed across the participating columns. These are candidate
hints only: actual wrapping, fitting, page count, height and preferences retain
the existing score and acceptance order. Fresh calls observe fonts, content,
styles and merge topology again.

Search budgets remain 24 allocations and 32,768 additional physical cell visits.
Column reuse retains at most 128 entries / 32,768 cell results; cell preparations
retain at most 8,192 positions / 2 MiB estimated key payload, and text preparation
at most 1,024 contexts / 1 MiB estimated source-key payload. Existing per-context
limits apply. These are entry/payload budgets, not heap measurements. Budget
exhaustion retains a complete plan and uses ordinary measurement where necessary.

## Verification

The [verification record](benchmarks/2026-10-12-table-spans-verification.json) retains per-case counts, Lab preservation results and local gate outcomes.

Eight regressions cover combined-width rich text and padding, untouched hidden
continuation payload, neighbor-width invalidation, native band styles, saved
pagination, grouped headers, single-slide/header-only cases, bounds, invalid and
overlapping spans, protected source words, unsupported vertical/malformed native
topology, fresh fonts/text/topology, and a 3,000-row budget/fallback case.
The cache regression includes both two- and three-column spans anchored in the
same column, changing neighboring widths and revisiting prior allocations.

The existing six unmerged workloads compare baseline and candidate geometry,
ordered diagnostics, PPTX and SVG output. The new span workloads also repeat in
independent processes and reopen with python-pptx to check every source word,
grid width, row height, header and body merge, and page coverage. ZIP CRC checks
run on each saved deck. JSON object order is normalized; arrays remain ordered
and non-JSON files compare byte for byte.

All 740 unmerged artifacts match the baseline, including six PPTX files and
364 SVGs. All 740 new span artifacts match their independent repeat, also
including six PPTX files and 364 SVGs. Independent reopening verifies the new
topology and geometry. The 24-row distinct-label merged fixture uses four pages
with measured widths versus six with estimated widths, retaining every word.

The Templates Library Lab appends grouped-header and body-span pages on both
16:9 and 4:3 canvases. It uses the same public planning/composition, inspector,
export and reopen paths available to app users. Saved topology, exact source
rows, notes, caption clearance, combined-width fit and SVG preservation are
checked. Existing specimens remain in the complete deck.

Both final Lab variants pass all 52 checks. The complete decks have 13 slides
(16:9) and 16 slides (4:3), including two and four new span pages respectively.
All 50 earlier standalone deck/preview artifacts and 60 existing slide/notes
parts are byte-identical. Earlier Lab checks retain their results; the extraction
summary reflects the new slide counts. All 24 archives pass CRC validation and
all 16 PPTX files reopen independently. The generated spanning-table preview was
also inspected; this does not replace native PowerPoint review.

The full local `scripts/verify.sh --fast` gate passes: 1,324 library tests,
50 Release preparation/shaping/table tests, 309 LecternCore tests, all 36 saved
PowerPoint reference comparisons, portable oracles and README execution. The
final expanded span regression also passes separately in Debug. Apple app builds
and app-hosted tests are outside this Linux gate; the PR workflow checks Apple
builds separately.

## Performance measurements

The [raw record](benchmarks/2026-10-12-table-spans.json) retains all 30 unmerged process pairs and 20 new-span processes, plus a SHA-256 of the candidate library sources. Both binaries use Swift 6.1.3 Release on the same shared Linux AMD EPYC 9V74 host. No builds or tests ran during measurement. All arrows below are baseline → candidate; timings are milliseconds and peak RSS is MiB. Percentages are medians of paired changes, so they differ from ratios of aggregate medians.

| Unmerged rows / labels / sizing | Plan elapsed | Plan CPU | Paired plan CPU | Compose elapsed | Compose CPU | Paired compose CPU | Peak RSS |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 24 / repeated / measured | 3.050 → 3.075 | 3.051 → 3.076 | +0.89% | 4.480 → 4.541 | 4.482 → 4.542 | +1.46% | 22.98 → 23.23 |
| 24 / distinct / measured | 4.997 → 4.980 | 4.999 → 4.981 | -0.34% | 6.447 → 6.597 | 6.449 → 6.599 | +2.91% | 22.95 → 23.02 |
| 1,000 / repeated / measured | 61.491 → 62.017 | 61.496 → 62.023 | -1.57% | 125.823 → 123.747 | 125.826 → 123.753 | -1.29% | 30.85 → 31.14 |
| 1,000 / distinct / measured | 211.848 → 222.772 | 211.837 → 222.777 | +0.28% | 272.998 → 287.860 | 272.998 → 287.867 | +2.14% | 33.29 → 33.65 |
| 100 / distinct / measured | 7.195 → 7.147 | 7.196 → 7.148 | -0.12% | 11.689 → 11.353 | 11.692 → 11.355 | -3.40% | 23.23 → 23.27 |
| 1,000 / distinct / estimated | 61.489 → 61.728 | 61.494 → 61.725 | +3.74% | 154.132 → 152.803 | 154.137 → 152.809 | +0.90% | 32.52 → 32.80 |

The 1,000-row measured controls show paired planning CPU changes of −1.57% (repeated) and +0.28% (distinct); paired ranges are −2.75% to +8.02% and −4.74% to +13.18%. Composition changes are −1.29% and +2.14%, with ranges crossing zero. These runs do not establish a speedup or a universal nonregression guarantee. Median peak process memory increases about 0.29 and 0.36 MiB for those controls. The estimated-width control has +3.74% paired planning CPU, ranging −4.43% to +8.62%; its overhead remains visible in the record.

| New horizontal-span rows / labels | Plan elapsed | Plan CPU | Compose elapsed | Compose CPU | Peak RSS |
| --- | ---: | ---: | ---: | ---: | ---: |
| 24 / repeated | 4.636 | 4.637 | 6.033 | 6.036 | 23.14 |
| 24 / distinct | 15.916 | 15.918 | 17.590 | 17.592 | 23.12 |
| 1,000 / repeated | 68.867 | 68.869 | 134.365 | 134.367 | 31.37 |
| 1,000 / distinct | 625.725 | 625.728 | 703.769 | 703.770 | 35.93 |

Distinct merged anchors contain longer unique text and require substantially more wrapping work than repeated labels. These are absolute costs for the new workload, not comparisons with the unmerged fixture. Peak RSS includes font setup and all trials; it does not isolate span metadata or caches.

## Reproduction

Build the baseline at `bc0248e44280de0129a0843376703888e828eb7e` before changing
sources. Both unmerged binaries use the existing table-preparation driver:

```sh
mkdir -p /tmp/table-spans
swift build -c release --target RostrumLayout
swiftc -O -I .build/release/Modules \
  docs/benchmarks/2026-10-12-table-preparation.swift \
  .build/release/Rostrum.build/*.o .build/release/RostrumLayout.build/*.o \
  -o /tmp/table-spans/baseline
# Repeat after building this change, with output /tmp/table-spans/candidate.
swiftc -O -I .build/release/Modules \
  docs/benchmarks/2026-10-12-table-spans.swift \
  .build/release/Rostrum.build/*.o .build/release/RostrumLayout.build/*.o \
  -o /tmp/table-spans/spans
python3 docs/benchmarks/2026-10-12-table-preparation-preserve.py /tmp/table-spans
python3 docs/benchmarks/2026-10-12-table-spans-check.py /tmp/table-spans
python3 docs/benchmarks/2026-10-12-table-spans-collect.py \
  /tmp/table-spans /tmp/table-spans.json
```

Use the pinned oracle environment for independent reopening. Run timing only
after builds, tests and artifact checks finish. The collector alternates five
baseline/candidate process pairs per unmerged case and records five processes
per new span case. Each process has five plan/compose trials; trial zero is
excluded from timing medians. Monotonic elapsed and process CPU clocks cover
planning and composition separately, including fresh composition preflight.
Font setup, slide cleanup, serialization and rendering are outside those timers.
`wait4` peak RSS includes all process work and all five trials. New span fixtures
have a merged header and every third body row merged; their absolute costs are
not a speedup comparison against different unmerged content.
