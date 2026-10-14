# Explicit missing-chart-cache repair

`Chart.rebuildMissingCachesFromWorkbook()` adds absent classic chart caches
using stored values in the chart's embedded XLSX. It addresses a confirmed
interoperability gap: Lectern can preview workbook-backed values while
PowerPoint leaves the cacheless chart blank. The rebuilt files still require
native PowerPoint slide-view and export acceptance; this API is unreleased.

```swift
let deck = try Presentation(contentsOf: inputURL)
if let chart = deck.charts.first {
    let rebuilt = try chart.rebuildMissingCachesFromWorkbook()
    for cache in rebuilt {
        print(cache.formula, cache.numeric, cache.pointCount)
    }
}
try deck.save(to: outputURL) // save a new copy
```

Repair is explicit. Ordinary open/save, inspection, previews and extraction do
not invoke it. Existing caches remain authoritative, even when empty or stale.
Use the separate chart editing APIs when deliberately replacing chart data.

## Supported inputs

| Input | Behavior |
| --- | --- |
| Local A1 cell or one-dimensional range | Read the referenced sheet and cells in order; quoted sheet names and absolute references work |
| Missing `strCache` | Shared strings, inline/rich strings, stored text results and Boolean text are materialized |
| Missing `numCache` | Finite decimal numeric stored values with General workbook formatting are materialized |
| Blank cells | Preserve point counts and gap indices |
| Series names, linked titles, categories, values, XY axes, bubble sizes and custom error values | Each supported reference gets its own cache |
| Formula cell with a stored result | Use that result as saved; do not calculate or refresh it |
| Existing cache | Leave it unchanged; a fully cached chart needs no workbook read |

External relationships, named ranges, two-dimensional ranges, missing multilevel
category caches and conditional chart markup refuse the operation. No formula
evaluation, date/number-format conversion or numeric-to-text label formatting is
performed. The strict reader also refuses ambiguous relationships/names, duplicate
cells, invalid namespaces, merged cells, inherited row/column styles, non-General
numeric styles, formula cells without stored results and unsupported/error cells.
Unsupported data must not become a saved blank cache.

## Preservation and limits

All missing references in **one chart** are validated and built before the first
edit. Failure leaves that chart and the deck's saved bytes unchanged. This is not
a transaction across a caller's loop over several charts: earlier successful
calls remain applied if a later chart fails. Open a separate copy when the host
needs a whole-deck transaction.

Only the chart part is marked dirty. Workbook bytes, relationships, formulas,
formatting, comments/extensions, notes, sections and unrelated parts are retained.
New caches are inserted before reference extensions. Repeating the operation
returns an empty report and preserves saved bytes. Each operation reads the
current workbook; it does not reuse a stale snapshot after content changes.

The reader permits a 64 MiB compressed/uncompressed workbook, at most 250,000
shared strings and visited cells, 250,000 visited chart nodes, 1,024 missing
references and 100,000 total materialized points per chart. Referenced sheets are
parsed once per operation and reused across its references. The ordinary
read-only preview fallback keeps its existing, more permissive behavior.

`Chart.CacheRepairProblem` describes unsupported references/cells and repair
limits. Underlying ZIP, OPC and XML parsing errors can also propagate.

## Runnable evidence

In Lectern, choose **Library Lab → Missing chart caches → Run Demo**. The alternate
option exercises an XY scatter chart. Both save a cacheless before deck, a repaired
deck, a repair report, inspector SVGs and extracted chart CSV. The demo checks
exact values/gaps, unchanged workbook and unrelated parts, unchanged previews,
notes/sections, atomic refusal and a second repair after reopening.
The current scatter SVG remains a diagnosed placeholder; identical before/after
previews do not establish plotted XY rendering. Saved XY values and CSV are
verified independently.

Headless checks use the same production Core paths:

```sh
swift test --filter 'ChartCacheRepairTests|ChartWorkbookReaderTests'
LECTERN_LAB_ARTIFACTS=/tmp/chart-cache-review \
  swift test --package-path Lectern --filter ChartCacheRepairLabTests
```

Portable validation on 2026-10-14 passed 18 focused chart reader/repair tests
(including parameterized malformed/reference cases) and 11 document/Lab tests.
Both Lab variants also passed independent python-pptx read-back and ZIP/XML
checks: only `ppt/charts/chart1.xml` changed, with exact numeric values and gaps.
The full local `scripts/verify.sh --fast` gate passed: 1,374 Rostrum tests,
335 LecternCore tests, 63 optimized-layout tests, nine pack checks, portable
references, workflow checks and README examples. Native app builds/app-hosted
tests are not part of the Linux fast gate. These are content and preservation
results, not a performance or native-rendering claim.

The retained before/after files are the native review inputs. Check opening without
repair, slide view, exported PDF/images and Edit Data in PowerPoint. A matching
SVG, passing lint or successful python-pptx read does not establish those results.
Native review remains pending in [PLAN.md](../PLAN.md).
