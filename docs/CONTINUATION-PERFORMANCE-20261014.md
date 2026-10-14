# Authored continuation performance — 2026-10-14

This follow-up preserves the layouts introduced by PR #64. It changes no public
Rostrum API, font policy, pagination boundary, citation placement or saved content.

## Profile and change

Temporary Release instrumentation on baseline
`27bf372db83aea787afab096af2143025aa6f622` counted production builder, fitting and
usage probes. Exact candidate identity used sorted JSON bytes plus image presence.
Timing included instrumentation overhead and is diagnostic, not the performance
comparison below.

| Fixture | Fit/usage probes | Distinct candidates | Pagination CPU (instrumented ms) |
| --- | ---: | ---: | ---: |
| Control | 2 | 2 | 2.25 |
| Unequal comparison | 54 | 51 | 85.90 |
| Dense text | 37 | 35 | 49.74 |
| Long chart source | 17 | 11 | 53.71 |
| Dense text with citation | 37 | 35 | 60.39 |

The long-source search repeated six candidate checks. Both paragraph splitting
and page-boundary search can reject the same candidate; tail balancing also asks
about candidates already visited. Reusing these exact decisions avoids building
and fitting another temporary slide. Shared headings repeat more often, but this
change does not introduce broader per-shape caching or change the library fitter's
host-callback contract.

`AuthoredProbeCache` lives only inside a single synchronous `DeckRenderer.paginate`
call, after font registration and style setup. The renderer owns the presentation
throughout that call; fonts, theme, styles and measurement policy remain fixed.
The next render creates a fresh cache. Keys include the complete input slide and
image-presence flag, using exact UTF-8 JSON bytes so canonically equivalent Unicode
strings cannot accidentally share a decision.

Accepted fits and original rejection messages are reusable. A fit without a
fullness score still performs the usage probe when balancing first requests one.
Cancellation is checked before every lookup and after every newly computed result.
Unexpected errors are not retained. The cache holds at most 64 entries, each with
at most 64 KiB of input, and 256 KiB total serialized input/error payload. Swift
container overhead is additional. Excess input uses the original path; no slide,
XML, font or presentation objects are retained in the cache.

## Verification

The fixed-input comparison requires identical PPTX bytes, every SVG, and ordered
generation, schema, missing-font and preview diagnostics for every sample. PPTX
byte equality includes table column widths/row heights, typography, page
boundaries, sections, notes, chart/workbook parts and relationships. Independent
ZIP CRC and python-pptx read-back also check saved content and sections.

Focused regressions cover rejection-message reuse, a fresh usage measurement,
changed content/layout/image presence, exact Unicode identity, cache bounds,
new-operation isolation, errors and cancellation. Existing authored continuation,
source placement, recovery and table tests exercise the production renderer.

## Release measurement

The [driver](benchmarks/2026-10-14-continuation-performance.swift) runs production
rendering, saving and saved-deck previews. The
[collector](benchmarks/2026-10-14-continuation-performance.py) alternates isolated
baseline/candidate processes: one warm-up pair and ten retained pairs per fixture.
It records CPU time, elapsed time and whole-process peak RSS via `wait4`, including
startup and read-back. Heavy oracle imports happen after all timing/memory samples.
Both binaries use the same Swift 6.1.3 Release toolchain and driver. Builds and
tests must not run concurrently with this collection.

Calibri faces are unavailable on this Linux host; missing faces are recorded in
each sample. This measures headless production rendering, not PowerPoint or native
Mac font performance. Native PowerPoint visual acceptance remains separate.

The [raw record](benchmarks/2026-10-14-continuation-performance.json) retains all
176 processes, binary/driver hashes and independent read-back checks. Every PPTX,
SVG and diagnostic record is byte-identical to the baseline. Each binary also
produces identical saved output across all eleven repetitions of each fixture.

Median times are milliseconds, baseline → candidate. CPU change is the median
within-pair change, not the ratio of the displayed medians. RSS is peak MiB.

| Fixture | Slides | CPU | Paired CPU change | Elapsed | Peak RSS |
| --- | ---: | --- | ---: | --- | --- |
| control | 2 | 24.08 → 24.38 | +1.72% | 24.42 → 24.76 | 26.94 → 26.90 |
| comparison | 4 | 122.84 → 122.46 | -2.08% | 123.24 → 122.79 | 27.99 → 28.29 |
| dense | 3 | 76.37 → 71.65 | -6.27% | 76.78 → 72.13 | 27.42 → 27.52 |
| source | 1 | 18.02 → 18.61 | +3.33% | 18.21 → 18.92 | 26.66 → 26.62 |
| long-source | 3 | 82.24 → 70.65 | -13.71% | 82.62 → 71.07 | 27.60 → 27.56 |
| cited-dense | 3 | 91.16 → 83.38 | -8.89% | 91.94 → 83.85 | 27.38 → 27.67 |
| repeated-source | 8 | 69.63 → 70.37 | +0.86% | 70.21 → 70.72 | 28.58 → 28.70 |
| table | 3 | 37.03 → 38.51 | +4.01% | 37.57 → 38.81 | 27.54 → 27.55 |

All ten pairs improve CPU for long-source (−25.82% to −1.82%), dense text
(−8.37% to −1.72%) and cited dense text (−14.14% to −4.60%). This recovers the
previous long-source CPU increase in this fixture. Comparison improvement is
smaller and not consistent in every pair (−10.99% to +2.34%).

Adverse samples remain in the record: short controls range from −6.98% to +12.20%,
moderate sources from −3.99% to +13.72%, repeated sources from −5.83% to +13.11%,
and tables from −8.36% to +56.65%. Citation-only and table cases perform no cached
page probes; these timings do not establish a universal speedup. Median RSS rises
about 0.3 MiB on comparison/cited text and is nearly unchanged on long sources.
This is a CPU improvement with bounded extra retention, not a memory reduction.
The collector peaked at 12.5 MiB before spawning; all children exceeded 26.3 MiB.

## Reproduce

Retain a baseline executable before editing sources, then compile the candidate
against the same driver and toolchain. Use a fresh directory for each collection:

```sh
mkdir -p /tmp/continuation-performance
swift build -c release --package-path Lectern --target LecternCore
swiftc -O -parse-as-library -I Lectern/.build/release/Modules \
  docs/benchmarks/2026-10-14-continuation-performance.swift \
  Lectern/.build/release/LecternCore.build/*.o \
  Lectern/.build/release/Rostrum.build/*.o \
  Lectern/.build/release/RostrumLayout.build/*.o \
  -o /tmp/continuation-performance/baseline
# Repeat after the change, writing /tmp/continuation-performance/candidate.
python3 docs/benchmarks/2026-10-14-continuation-performance.py \
  /tmp/continuation-performance /tmp/continuation-performance-report.json
```
