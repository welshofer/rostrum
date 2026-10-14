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
Unexpected errors are not retained. If an unused IR field cannot be encoded as
JSON, key construction is skipped and ordinary rendering proceeds unchanged. The cache holds at most 64 entries, each with
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
new-operation isolation, errors and cancellation. A production regression also
compares exact saved bytes and previews when a bullet slide carries unused
non-finite chart metadata. Existing authored continuation,
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
| control | 2 | 23.94 → 24.61 | +3.41% | 24.24 → 25.09 | 26.87 → 26.88 |
| comparison | 4 | 123.85 → 117.00 | -3.78% | 124.28 → 117.56 | 28.05 → 28.17 |
| dense | 3 | 77.76 → 73.12 | -6.20% | 78.19 → 73.57 | 27.39 → 27.52 |
| source | 1 | 18.17 → 18.49 | -0.92% | 18.71 → 18.74 | 26.77 → 26.58 |
| long-source | 3 | 80.55 → 72.70 | -10.37% | 80.99 → 73.20 | 27.58 → 27.58 |
| cited-dense | 3 | 90.54 → 85.64 | -7.59% | 91.36 → 86.66 | 27.51 → 27.58 |
| repeated-source | 8 | 71.62 → 70.32 | -1.99% | 72.03 → 70.82 | 28.64 → 28.72 |
| table | 3 | 38.69 → 36.91 | -1.86% | 39.13 → 37.31 | 27.54 → 27.65 |

The final long-source median improves 10.37%, recovering the preceding layout
pass's increase in this fixture. Dense text improves 6.20%, cited text 7.59%, and
comparison 3.78%. Individual samples vary; none establishes a universal speedup.
All adverse samples are retained:

| Fixture | Paired CPU range |
| --- | --- |
| control | -16.30% to +11.88% |
| comparison | -8.16% to +5.89% |
| dense | -15.63% to +2.94% |
| source | -24.27% to +6.36% |
| long-source | -32.20% to +33.02% |
| cited-dense | -13.80% to +4.33% |
| repeated-source | -8.21% to +7.95% |
| table | -8.72% to +5.22% |

Citation-only and table cases perform no cached page probes. Their changes help
show the timing noise of these short workloads. Peak RSS rises about 0.1 MiB on
several cases and is effectively unchanged for long sources. This is a CPU
improvement with bounded extra retention, not a memory reduction. The collector
peaked at 12.50 MiB before spawning; the smallest child peak was
26.48 MiB.

The earlier batch before the non-JSON-key fallback is retained in
[commit ba895c1](https://github.com/welshofer/rostrum/blob/ba895c11233592bf6016d2fb8d3c4edeedc314a3/docs/benchmarks/2026-10-14-continuation-performance.json).
It measured long-source CPU at −13.71% and RSS increases up to about 0.3 MiB.
The current record above measures the final implementation and retains its slower
samples too; no builds or tests ran concurrently with either collection.

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
