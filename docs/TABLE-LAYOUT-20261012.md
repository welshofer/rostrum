# Shared native table layout

`TableLayoutEngine` measures the actual cell text, table-region styles, margins
and paragraph geometry that rendering uses. `TemplateTableContent` connects
that plan to template selection and composition, including caption reservation
and a fresh preflight before adding a slide. The first version handles unmerged,
horizontal cells without shrinking fonts or paginating rows. Native PowerPoint
acceptance of the newly computed table specimen remains pending.

## Performance scope

The small-table comparison uses baseline `34f86dbe2cf252795edfc466b0d59364961267b2`
and this implementation. Both binaries use Swift 6.1.3 Release optimization on
the same Linux x86-64 cloud host. Seven pairs alternate process order. Each
process runs seven samples per case, composing twenty eight-row, three-column
table slides per sample. The first sample is excluded from medians. Template
loading is outside the timer; layout selection, preflight, native table creation
and slide insertion are inside. This control uses deterministic fallback metrics
without registered fonts or a host callback.

The final raw measurements and summaries are in
[the benchmark record](benchmarks/2026-10-12-table-layout.json).

| Twenty composed table slides | Baseline median, ms | Shared planner median, ms | Median paired change |
| --- | ---: | ---: | ---: |
| Repeated rows | 36.534 | 39.773 | +5.22% |
| Distinct row labels | 36.671 | 43.490 | +15.26% |

Five of seven repeated-row pairs and all seven distinct-label pairs are slower.
The ratio of medians differs from the
median paired change; both definitions and every sample are retained in the raw
record. The added elapsed cost is roughly 0.16–0.34 ms per composed table here.

Small-table composition has a measured correctness cost: the old implementation
used fixed padding, line spacing and header weight; the new implementation
resolves native styles and checks the exact prospective cells before insertion.
These implementations intentionally choose different row heights, so this is
not a byte-preserving speedup comparison. The default column-allocation policy
is retained, with cumulative rounding to preserve the exact frame width.

The scaling comparison plans 1,000 and 10,000 existing cells with registered
regular DejaVu Sans. Repeated cells contain “Ready for review”; distinct cells
contain a unique row/column label and more text. Each case has five samples;
the first is excluded. An independent loop resolves each cell through the
existing single-cell fitting projection, lays it out and takes the row maximum.
Every row height agrees to one EMU. This loop is a geometry reference and a
comparison with repeated single-cell access, not the former template algorithm.

| Cells | Content | Bulk plan median, ms | Independent-cell reference median, ms |
| ---: | --- | ---: | ---: |
| 1,000 | Repeated | 4.393 | 188.936 |
| 1,000 | Distinct | 36.741 | 198.064 |
| 10,000 | Repeated | 43.569 | 2,696.967 |
| 10,000 | Distinct | 366.559 | 2,699.876 |

The bulk planner indexes the grid once, resolves only text style regions, and
reuses repeated measurements. Result reuse is limited to 64 entries with a
256 KiB estimated payload budget; text style reuse has its own 256 KiB budget.
Caches expire at the end of each call. The returned per-cell report and source
grid necessarily scale with table size. Peak RSS in the raw record is the maximum across benchmark child processes,
including composition, fonts, all four bulk scenarios and reference loops;
it does not isolate scratch memory (36.0 MiB in this run).
Shared-host elapsed times are observations, not CI thresholds or device-latency claims.

## Verification

The bulk text-style projection agrees with full renderer resolution across every
built-in style and flag combination. Regressions cover rich runs, paragraph
spacing, tabs/breaks, asymmetric padding, width changes, font registration,
ignored stored table scale, unsupported geometry, malformed grids, exact width
totals and rejected composition without a partial slide. Template source parts
remain byte-identical after saved-file reopening.
An [external Swift 5 consumer](benchmarks/2026-10-12-table-layout-compatibility.swift)
also compiles and runs with its original trailing validation closure. Swift 6
argument disambiguation is exercised in the package tests.

The Templates Library Lab now has a third slide for table planning, with both
16:9 and 4:3 variants. Thirty checks cover editable content, planned row heights,
individual saved-cell fitting, caption clearance, deterministic SVG and the
headless inspector/export path. All twenty-two PPTX/POTX/PPSX/SVG artifacts are
identical before and after the text-only style-resolution optimization. ZIP CRC
checks pass and python-pptx independently reopens all eight PPTX artifacts.
Native PowerPoint visual acceptance is separate from these portable checks.

The final fast-gate checks pass: 1,299 root tests, 25 Release preparation/shaping/
table tests, 309 LecternCore tests, 36 saved PowerPoint image comparisons,
portable semantic checks and README examples. The local gate was resumed at
Lectern after rebuilding a stale incremental test object from the API signature
change; its complete suite and the remaining README checks then passed. Apple
package/app builds run in PR CI. App-hosted tests and live PowerPoint are not
available in this Linux environment.

## Reproduction

Build each revision in its own checkout, preserving the baseline executable
before changing sources:

```sh
swift build --package-path Lectern -c release --target LecternCore -Xswiftc -enable-testing
```

Compile the [small-table driver](benchmarks/2026-10-12-table-layout-small.swift)
with `swiftc -O`, the build's `Modules` include path and all `.swift.o` files from
`Rostrum.build`, `RostrumLayout.build` and `LecternCore.build`. Run alternating
fresh baseline/candidate processes seven times and retain their JSON output.
The same linkage runs the [scaling driver](benchmarks/2026-10-12-table-layout-scaling.swift)
and [Lab export driver](benchmarks/2026-10-12-table-layout-lab.swift). Run scaling
from the repository root so its explicitly registered fixture font resolves.
The Lab driver takes a fresh output directory as its sole argument.

The scaling driver deliberately uses `@testable` access to build an independent
reference from the pre-existing single-cell fitting projection. Production
clients use the public `TableLayoutEngine.plan` API and need no testable access,
platform frameworks or external Swift dependencies.
