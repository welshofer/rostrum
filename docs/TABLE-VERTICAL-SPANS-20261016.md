# Existing-table vertical merge measurement — 2026-10-16

`TableLayoutEngine.plan` measures horizontal text in existing native tables with
vertical and rectangular merges. It remains read-only: callers check `fits`
before applying the returned column widths and row heights.

## Height policy and boundaries

Only the top-left anchor is measured, using its resolved style, full text size,
padding and the sum of the merged column widths. `TableCellLayout.rowSpan` and
`columnSpan` describe that visible cell. `requiredHeight` is the height of the
whole merged cell. The physical row-major grid remains intact; continuations
have zero required height and empty issues/diagnostics. Their hidden XML is
preserved, including text or unsupported properties that do not paint.

First establish row minima from ordinary cells and `minimumRowHeight`. Then
visit multi-row anchors in row-major order and divide any remaining height
deficit equally across their rows, assigning leftover integer EMUs to earlier
rows. Rows only grow, preserving earlier constraints when merges in different
columns cover intersecting row ranges. This is deterministic fitting, not a
claim of globally minimal height or PowerPoint native autofit. Existing saved
row heights do not act as minima, consistent with the previous planner.

The two span counts use OOXML's positive signed 32-bit integer range internally,
while the public API remains `Int`. They share one metadata word. On this 64-bit
host the cell-result stride is 48 bytes; an earlier separate `Int` row-span field
increased it to 56 bytes for ordinary cells too. Out-of-range native spans are
rejected rather than truncated.

The extra row visits are bounded by the physical grid: validated merge
rectangles never overlap. The result array reserves the validated physical grid size once per trial,
avoiding repeated metadata copies while it grows. Column-cache hits retain the
measured anchor and its span but recompute row constraints for every width trial. A neighboring column
can change both combined width and available row height. Caches remain bounded
and operation-local; later font, text, style and topology edits are remeasured.

Malformed native topology still throws. Horizontal overflow, line limits,
invalid insets, vertical/rotated text, dynamic fields and nonzero line-spacing
reduction retain their existing issues. `maximumHeight` is checked after the
row constraints are resolved. No source words are removed to make a plan fit.

`TemplateTableContent` and template pagination still reject row spans. The
internal pagination measurement also returns `.mergedCell` for multi-row
anchors. Keeping connected rows together and refusing oversized groups is the
next change; this measurement API alone does not prevent callers from placing
a large table outside the slide.

## Verification

`TableVerticalSpanTests` covers combined widths/heights, deterministic EMU
remainders, independent saved-cell fitting, hidden continuation XML, intersecting
row ranges, maximum-height boundaries, cached/fresh width trials, fresh fonts,
text, padding and unmerging, explicit pagination refusal and a 2,048-row span.
Existing horizontal, malformed-grid and unsupported-text cases remain covered.
The optimized CI and local gate include the new suite.

The Templates Library Lab adds a separate, editable example on 16:9 and 4:3
canvases. It retains `vertical-spans-output.pptx` and checks source cell text,
merge topology, combined-area fits, deterministic row heights and reopened SVGs.
`TableVerticalSpansLabTests` runs the production Inspect/export path on both
ratios. Set `ROSTRUM_VERTICAL_MERGE_ARTIFACTS` to retain these artifacts locally.
The existing bundled fixture font is a test input, not a library font policy.
Portable previews have been visually inspected; PowerPoint slide-view/export
acceptance with exact fonts and native Mac performance remain pending.

After pulling, collect both complete Lab runs (including the standalone merged
table decks, previews and reports) with:

```sh
ROSTRUM_VERTICAL_MERGE_ARTIFACTS="$PWD/.build/vertical-merge-review" \
  swift test --package-path Lectern --filter TableVerticalSpansLabTests
```

The complete Linux fast gate passed: 1,388 root tests, 69 optimized text/layout
tests, 354 LecternCore tests, nine native-text/table pack checks, portable fidelity
references, offline workflow checks and runnable README examples. The focused
Lab integration ran both canvas ratios. macOS/iOS builds and native test-host
compilation run separately in PR CI; hosted test execution requires a Mac.
After the final capacity/storage changes, all 38 focused table tests passed,
including the full native span integer range. The final comparison repeats every
preservation control using those exact benchmark binaries.

## Reproduction and performance

Build the baseline at `7b7b23c1a45ddf1d6885114aa7db8db44cc19f71` before changing
sources. Build the candidate from this change using the same Swift toolchain.
Use a scratch directory outside the tracked tree.

```sh
mkdir -p /tmp/row-spans
swift build -c release --target RostrumLayout
swiftc -O -I .build/release/Modules \
  docs/benchmarks/2026-10-12-table-preparation.swift \
  .build/release/Rostrum.build/*.o .build/release/RostrumLayout.build/*.o \
  -o /tmp/row-spans/baseline
swiftc -O -I .build/release/Modules \
  docs/benchmarks/2026-10-12-table-spans.swift \
  .build/release/Rostrum.build/*.o .build/release/RostrumLayout.build/*.o \
  -o /tmp/row-spans/baseline-spans
# Repeat with the candidate sources, naming binaries candidate and candidate-spans.
swiftc -O -I .build/release/Modules \
  docs/benchmarks/2026-10-16-table-vertical-spans.swift \
  .build/release/Rostrum.build/*.o .build/release/RostrumLayout.build/*.o \
  -o /tmp/row-spans/vertical
python3 docs/benchmarks/2026-10-16-table-vertical-spans.py \
  /tmp/row-spans /tmp/row-spans/measurements.json
```

The collector uses six existing unmerged/horizontal-span preservation controls,
including mixed-script diagnostics, and a repeated new rectangular/vertical
fixture. It compares geometry, page boundaries, diagnostics, PPTX and SVG output
and independently reads saved grids with python-pptx. Timings use five alternating
fresh-process pairs across five existing workloads, plus five fresh processes
per new workload. Each process performs five trials, with trial zero excluded
from phase medians. Process CPU and peak RSS include setup; phase timers exclude
font setup, serialization and rendering. No other builds/tests should run during
collection. Large new tables are stress measurements, not paginated examples.

The Python collector builds a small, benchmark-only C launcher with `cc`. It
executes before forking the measured child, then reads that child's `wait4`
usage. Directly forking from Python inherited its larger resident-memory peak
and masked these workloads' actual RSS. The launcher is outside every library
and app target; Rostrum's runtime remains pure Swift with no new dependencies.
A 160 MiB Python-parent control reported 384 KiB for `/bin/true` and 71,680 KiB
for a Python child touching 64 MiB, independently of the collector's peak.
The standalone vertical workload's repeated merge setup is outside phase timers
but included in process CPU and RSS.

## Captured results

Linux x86_64, Swift 6.1.3 Release; five alternating fresh-process pairs per
existing workload and five fresh processes per new workload. All 96 existing
control files compare identically (JSON objects plus ordered arrays, exact PPTX
and SVG bytes). The four new fixture artifacts reproduce exactly; python-pptx
independently verifies native spans, columns and combined row-height constraints.

The initial implementation enlarged every cell result from 48 to 56 bytes.
The first comparison exposed adverse timings. Preallocating the result array
alone did not remove them; the final implementation also stores both native
32-bit spans in one word. All three campaigns are retained below. The initial
RSS values are invalid because the collector's inherited memory peak masked the
children; only the later launcher-based RSS measurements are usable.

**These are exploratory measurements, not a speedup or universal nonregression
claim.** Individual paired phase ratios vary widely: one small-table composition
pair was +111%; two repeated-table baseline processes were unusually slow. Those
samples remain included. The final 24-row horizontal-span control still has
adverse paired medians (+5.8% planning CPU, +3.0% composition CPU). The layout
feature and restored metadata footprint are established; native Mac performance
remains pending. Each rerun followed a collector or implementation change; all
samples remain in the raw evidence.

Cells show baseline → candidate process medians. Percentages are medians of
paired ratios, **not** ratios of those two aggregate medians; their signs can
differ when process times vary. Phase medians exclude trial zero; whole-process
CPU and peak RSS include setup and all five trials.

| Workload | Plan CPU ms | Plan elapsed ms | Compose CPU ms | Compose elapsed ms | Process CPU ms | Peak RSS MiB |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Plain, 24, distinct | 8.6 → 9.8 (+0.2%) | 8.5 → 9.8 (+0.2%) | 10.8 → 11.0 (-6.4%) | 10.8 → 11.0 (-6.4%) | 132.4 → 153.8 (+8.1%) | 23.23 → 23.26 |
| Plain, 1000, repeated | 110.1 → 96.1 (-14.2%) | 110.1 → 96.1 (-14.3%) | 205.1 → 229.6 (-2.2%) | 205.2 → 229.9 (-2.3%) | 2123.7 → 1760.8 (-12.8%) | 31.25 → 31.06 |
| Plain, 1000, distinct | 352.2 → 336.3 (+0.3%) | 352.3 → 336.3 (+0.3%) | 465.5 → 455.0 (-0.6%) | 465.5 → 455.0 (-0.5%) | 4181.0 → 4116.1 (+0.9%) | 33.93 → 33.59 |
| Horizontal, 24, distinct | 21.9 → 21.4 (+5.8%) | 21.9 → 21.4 (+5.8%) | 24.7 → 25.0 (+3.0%) | 24.8 → 25.0 (+3.0%) | 268.0 → 269.5 (+0.5%) | 23.33 → 23.31 |
| Horizontal, 1000, distinct | 923.4 → 878.8 (-6.3%) | 923.6 → 879.0 (-6.3%) | 1064.9 → 1012.6 (-4.3%) | 1065.0 → 1014.6 (-4.3%) | 10354.2 → 9785.6 (-4.8%) | 35.90 → 36.24 |

New existing-table row-span workloads (no prior supported implementation):

| Rows | Labels | Plan CPU ms | Plan elapsed ms | Process CPU ms | Peak RSS MiB |
| ---: | --- | ---: | ---: | ---: | ---: |
| 24 | repeated | 1.2 | 1.2 | 41.8 | 22.97 |
| 24 | distinct | 2.7 | 2.7 | 46.7 | 23.03 |
| 1000 | repeated | 24.3 | 24.3 | 859.1 | 29.22 |
| 1000 | distinct | 122.7 | 122.7 | 1294.1 | 29.29 |


Raw evidence: [final](benchmarks/2026-10-16-table-vertical-spans.json),
[initial, invalid RSS](benchmarks/2026-10-16-table-vertical-spans-initial-invalid-rss.json),
[array-capacity refinement](benchmarks/2026-10-16-table-vertical-spans-capacity.json),
and [memory-launcher control](benchmarks/2026-10-16-memory-launcher-verification.json).
Each campaign records source/binary hashes and all raw samples. The final
comparison followed the 38 focused tests; no builds or tests ran alongside it.
