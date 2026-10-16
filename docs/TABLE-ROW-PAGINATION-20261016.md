# Template tables with vertical merges — 2026-10-16

`TemplateTableContent` accepts vertical and rectangular merges for single-slide
composition and continued native tables. Covered cells must be exactly empty;
overlap, invalid dimensions and source text in a covered cell are refused before
adding a slide. Existing horizontal-only validation keeps its fast path.

## Page boundaries and width search

Pagination repeats one header row. A vertical merge crossing row zero is refused;
use single-slide composition for that case. Body rows connected by merge intervals
stay together. Intersecting intervals in different columns connect transitively:
a span over rows 1–2 and another over rows 2–3 make rows 1–3 indivisible. Adjacent,
nonintersecting groups remain separate and can break across slides.

The planner computes these intervals before trying layouts. Each column-width
search prepares the same groups once and reuses them across trials when scoring
unplaceable content and page count.
Final page partitioning greedily packs complete groups, using integer EMUs to
accept exact fits. A group taller than the available area beside its repeated
header throws before mutation. The engine does not shrink fonts, split merged
cells or discard words to force a fit. Search and text-preparation budgets are
unchanged; groups are operation-local and require no cross-operation cache.

Each saved page retains the original merge dimensions and remaps its anchor row
into the local grid. Header text and horizontal header merges repeat. Titles and
captions repeat verbatim; callers retain control of notes and section membership.
`bodyRows` continues to index the exact original source rows. Composition freshly
checks fonts, content, styles, canvas and all page geometry before inserting any
slides. Changed geometry requires a new plan.

The existing-table measurement policy still applies: ordinary cell minima first,
then equal distribution of each multi-row anchor's remaining height deficit in
row-major order. The pagination style envelope may reserve more room than a
specific saved page needs. Independent verification therefore checks each
anchor against the **sum of saved row heights across its span**, rather than
requiring a fresh planner to distribute spare height identically among rows.
This is deterministic fitting, not a claim of globally optimal pagination or
PowerPoint native autofit.

```swift
let table = TemplateTableContent(
    rows: [["Group", "Evidence", "State"],
           ["Research", "First exact observation", "Ready"],
           ["", "Second exact observation", "Ready"]],
    columnSizing: .measured(),
    merges: [TableMergeRegion(row: 1, column: 0, rowSpan: 2, columnSpan: 1)])
let engine = TemplateLayoutEngine(presentation: deck)
let plan = try engine.planTablePages(title: "Evidence", table: table,
    caption: "Original source text retained.")
let slides = try engine.composeTablePages(plan)
```

## Verification and local review

`TableVerticalPaginationTests` exercises connected intervals, exact-fit boundaries,
single-slide header rectangles, measured and estimated column sizing, changing
band typography, native merge remapping, independent saved-cell fitting, source
rows/notes, oversized-group refusal, invalid/overlapping rectangles, covered
whitespace and stale canvas refusal. Existing cache tests now exercise the
pagination style envelope with vertical anchors.

The Templates Library Lab adds `vertical-pagination-output.pptx` on both 4:3 and
16:9 canvases. Its checks reopen every page, verify native merge topology and
source content, independently fit combined cell areas, check table/caption
bounds, and compare saved previews. The integration test exercises production
Inspect/export and retains one preview per slide.

```sh
ROSTRUM_VERTICAL_MERGE_ARTIFACTS="$PWD/.build/vertical-merge-review" \
  swift test --package-path Lectern --filter TableVerticalSpansLabTests
```

Open the retained standalone merged-cell and pagination decks for native review.
Portable SVG checks and structural validation do not establish PowerPoint
slide-view/export fidelity. The bundled Lab fixture font is a test input, not a
library font restriction. Live PowerPoint acceptance and Mac performance remain
separate evidence.

The first complete local run exposed an unrelated provider-test deadline failure:
the mocked dropped-connection test resumed after 349 seconds of CPU-heavy suite
work and exceeded its real 300-second request budget. It passed alone in 6.3
seconds. The internal provider test interface now accepts a clock and wait
function; public production initialization still uses real time and the original
deadline. Controlled tests assert the 2/4-second retry schedule, decreasing
request timeouts, and refusal after a delayed wait exhausts the budget, for both
transport errors and retryable HTTP responses. They complete without sleeping.

All portable gate stages passed after that correction: 1,394 root tests, 75
optimized text/layout tests, 355 LecternCore tests, nine native-pack checks,
portable fidelity references, offline workflow checks and runnable README
examples. The affected LecternCore stage was rerun in full, followed by the
remaining README stage; unchanged root/optimized stages retained their passing
results. The two controlled-clock tests also passed separately.
Both retained Lab runs passed all 35 checks. Independent python-pptx readback
confirmed all six source groups across three pages per aspect ratio, native
2×1 and 2×2 topology, exact text and notes, and table/caption bounds. Representative
4:3 and 16:9 continuation previews were visually inspected.
macOS/iOS builds and native test-host compilation run separately in PR CI;
hosted test execution and live PowerPoint acceptance require a Mac.

## Reproduce the Release comparison

Use the same Swift toolchain for baseline `0ddd08e` (the measurement milestone)
and this change. Build the two existing drivers on the baseline before changing
sources, then build their candidate counterparts and the new pagination driver.
Keep the executables in an untracked scratch directory:

```sh
mkdir -p /tmp/row-pagination
git rev-parse HEAD > /tmp/row-pagination/baseline-commit.txt
swift build -c release --target RostrumLayout
swiftc -O -I .build/release/Modules \
  docs/benchmarks/2026-10-12-table-preparation.swift \
  .build/release/Rostrum.build/*.o .build/release/RostrumLayout.build/*.o \
  -o /tmp/row-pagination/baseline
swiftc -O -I .build/release/Modules \
  docs/benchmarks/2026-10-12-table-spans.swift \
  .build/release/Rostrum.build/*.o .build/release/RostrumLayout.build/*.o \
  -o /tmp/row-pagination/baseline-spans
# Repeat with candidate sources, naming binaries candidate and candidate-spans.
swiftc -O -I .build/release/Modules \
  docs/benchmarks/2026-10-16-table-row-pagination.swift \
  .build/release/Rostrum.build/*.o .build/release/RostrumLayout.build/*.o \
  -o /tmp/row-pagination/vertical
python3 docs/benchmarks/2026-10-16-table-row-pagination.py \
  /tmp/row-pagination /tmp/row-pagination/measurements.json
```

The collector requires the pinned portable Python oracles and `cc` for its
benchmark-only resource launcher. Rostrum and Lectern gain no C or Python runtime
dependency. The launcher records child CPU and peak RSS after a fresh exec,
avoiding inheritance of the Python collector's memory peak.

Six existing plain/horizontal controls compare column widths, row heights,
page boundaries and ordered diagnostics, plus exact saved decks and SVGs.
New 24- and 100-row merged fixtures repeat deterministically; python-pptx reads
every saved page to check native topology and geometry independently.

Timings use five alternating fresh-process pairs for each existing workload
and five fresh processes per new workload. Each performs five trials; trial zero
is excluded from phase medians. Planning and composition timers exclude font
setup, serialization and rendering; composition includes its fresh preflight.
Process CPU and peak RSS include setup and all trials. Keep other builds and
tests idle during collection. The new fixture alternates two-row rectangular
and vertical groups; transitively connected four-row groups are covered by
the regression suite and both Lab decks.

## Captured results

Linux x86_64, Swift 6.1.3 Release, with no concurrent builds or tests. All 96
existing control files preserve geometry, page boundaries and ordered diagnostics
(JSON objects and ordered arrays), plus exact PPTX and SVG bytes. The two new
merged fixtures reproduce all 36 artifacts; independent python-pptx checks pass
for every page's native spans, widths and combined row heights.

**These measurements do not establish a general speedup or universal
nonregression.** Small plain/horizontal controls have adverse paired phase
medians of about 5%; repeated 1,000-row composition is +3.4%. Other large controls
improve, but individual pairs vary substantially: the small horizontal planning
pairs range from -6.2% to +40.2%. All samples are retained. Existing control
process medians use about 23–36 MiB peak RSS; new merged pagination uses about
23–34 MiB. Native Mac performance remains unmeasured.

Cells below show baseline → candidate process medians; percentages are medians
of paired ratios, not ratios of those aggregate medians. Their signs can differ
when process timings vary. Phase medians exclude trial zero. Whole-process CPU
and peak RSS include setup and all five trials.

| Workload | Plan CPU ms | Plan elapsed ms | Compose CPU ms | Compose elapsed ms | Process CPU ms | Peak RSS MiB |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Plain, 24, distinct | 8.9 → 9.9 (+5.4%) | 8.9 → 9.9 (+5.4%) | 13.2 → 12.6 (+5.1%) | 13.2 → 12.6 (+4.9%) | 161.7 → 180.7 (-1.0%) | 23.47 → 23.27 |
| Plain, 1000, repeated | 105.3 → 103.9 (-1.4%) | 105.3 → 103.9 (-1.3%) | 238.1 → 246.3 (+3.4%) | 238.2 → 246.3 (+3.4%) | 1868.2 → 1931.4 (+3.2%) | 31.18 → 31.07 |
| Plain, 1000, distinct | 458.8 → 402.2 (-8.2%) | 458.9 → 402.2 (-8.2%) | 525.2 → 504.5 (-3.9%) | 525.4 → 504.6 (-3.9%) | 5150.9 → 5127.6 (-5.6%) | 33.82 → 33.67 |
| Horizontal, 24, distinct | 22.4 → 28.1 (+5.5%) | 22.4 → 28.1 (+5.5%) | 28.7 → 28.9 (+5.6%) | 28.6 → 28.9 (+5.6%) | 302.2 → 333.9 (+10.5%) | 23.53 → 23.25 |
| Horizontal, 1000, distinct | 1082.8 → 989.3 (-6.2%) | 1082.8 → 989.4 (-6.3%) | 1220.4 → 1079.3 (-2.0%) | 1221.8 → 1079.5 (-1.9%) | 11161.2 → 10816.7 (-3.1%) | 36.36 → 36.25 |

New merged pagination workloads (previously unsupported):

| Rows | Labels | Planned pages | Plan CPU ms | Plan elapsed ms | Compose CPU ms | Compose elapsed ms | Process CPU ms | Peak RSS MiB |
| ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 24 | repeated | 4 | 6.7 | 6.7 | 9.1 | 9.1 | 145.1 | 23.30 |
| 24 | distinct | 4 | 19.8 | 19.8 | 21.5 | 21.4 | 287.4 | 23.32 |
| 1000 | repeated | 167 | 94.4 | 94.3 | 300.4 | 300.4 | 2085.4 | 30.67 |
| 1000 | distinct | 167 | 761.8 | 761.9 | 808.2 | 808.3 | 8359.8 | 33.58 |


Page counts are planned table pages. Benchmark artifact decks also retain the
constructor's original blank slide; the standalone Lab decks contain only their
three composed pages. The stress cases use the same full-size typography and
bounded search as smaller inputs; they do not shrink merged groups to reduce
page count.

[Raw samples and source/binary hashes](benchmarks/2026-10-16-table-row-pagination.json)
retain all five alternating pairs and all new-workload processes. No samples were
discarded or rerun to select a better outcome. The library remains pure Swift;
the small C resource launcher is benchmark infrastructure only.
