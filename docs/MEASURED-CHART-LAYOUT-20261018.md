# Measured chart preview layout

The chart preview now reserves text space from the requested font's measured
advances and line metrics. Titles, axis titles, value ticks, categories, legends
and data labels share that measurement path. These changes require the development
revision containing this work; they are not part of Rostrum 1.0.0.

## Behavior

- Automatic chart layout reserves space for the labels actually present. Chart
  titles and category/legend labels wrap at measured widths, including natural
  dash breaks in compound names, instead of truncating by character count.
  A text-height outer inset also keeps endpoint ticks away from the frame edge;
  this prevents the top tick crowding the saved slide 27 annotation.
- Category labels no longer disappear solely because there are more than 12.
  Legends no longer stop at six entries. Dense category axes sample labels in
  source order when necessary; actual omissions produce a preview finding.
- Native value/category axis titles receive their own space. Vertical titles
  rotate as a block, preserving the font, size and color.
- Bar labels use measured rectangles at their requested inside/outside position.
  Labels that cannot fit a small bar are reported instead of painting outside it.
- Line and area previews render requested values/category/series labels, including
  per-point deletion and formatting overrides. Labels and markers are outside the
  plot's clipping container; points outside an explicit axis range remain omitted.
- Pie/doughnut previews support category/value/percentage labels. Outside labels
  are packed separately on each side with leader lines. Percentages use the
  positive plotted values; zero/nonpositive values retain the existing omission
  behavior. Combined values and percentages retain distinct default units
  (for example, `30, 25%`). First-slice angle and doughnut hole size are respected.
- Percent-stacked bars now use fractional axis units: 25/75 plots against 0–1
  with 25%/75% segments. The previous renderer mixed percentages with those
  native fractional bounds. Normalized sums avoid overflowing large finite values.

Registered fonts supply the metrics. The host's explicit `previewAdvance` adapter
can supply supported native advances. Missing fonts remain a diagnosed estimate;
this does not install fonts, choose a new document font, or hide a substitution.
The source text, native chart XML, embedded workbook and saved PPTX are unchanged
by rendering.

Measurements are reused within one chart operation, with at most 2,048 cached
strings and 256 KiB of retained text. Each new operation observes current fonts,
content and measurement policy. Labels are bounded to 1,024 grapheme clusters;
data-label placement is bounded to 512 labels and uses a fixed spatial grid.
The existing 32-series/512-category preview limits remain explicit. A text block
that cannot fit is omitted with a finding; source strings are never ellipsized
or rewritten. Ordinary wrapping normalizes inter-word spaces in the preview.

## Support boundaries

This is measured, bounded automatic layout, not an implementation of PowerPoint's
complete chart layout engine. Manual positions, rotated tick text, rich custom
labels, multi-plot/secondary-axis composition, exact pie-sector label containment,
advanced axes/formats and full complex-script shaping remain approximate. Dense
charts may still have diagnosed omissions. Caller-selected fonts and the existing
strict-rendering diagnostic contract remain intact.

The renderer's `data-rostrum-chart-role`/`data-rostrum-chart-bounds` SVG attributes
identify text blocks for regression inspection. Bounds describe measured advance
and line boxes, not a claim of exact glyph ink bounds or native PowerPoint layout.

## Review and regressions

In Lectern, open **Library Lab → Document → Chart gallery**. The gallery now
includes a long-category slide with axis titles, and checks saved/reopened line
and pie labels through the normal inspection/export pipeline. It retains editable
charts and their source workbooks. Missing installed fonts still produce findings.

Focused portable regressions:

```sh
swift test --filter 'MeasuredChartLayoutTests|ChartPreviewFidelityTests|PreviewSymbolTests|ChartAppearanceTests|SlideBuildersTests'
swift test --package-path Lectern --filter 'DocumentLabRecipesTests|SavedDeckPreviewTests'
```

The regressions exercise differing glyph widths, explicit line/dash breaks,
nonbreaking spaces, replacement fonts, fresh host measurements, long categories,
eight-entry legends, dense label collisions, mixed-sign bars, 25/75 percent stacks,
large finite values, line-label gaps/deletion, pie percentages, label bounds, axis titles,
frame-edge annotations, source-byte preservation and deterministic output. Existing symbol, overflow,
contrast and image-reference suites remain part of the full gate. A saved agenda
link check also retains explicit color, no underline and its destination through
SVG inspection; this is not native PowerPoint hyperlink-appearance acceptance.

The private 33-slide higher-education deck remains outside Git. The comparison
requires all 20 previously rendered bar labels and eight line markers, unchanged
extracted content/exports, and unchanged SVGs and diagnostics on slides without
charts. The chart slides are 7, 8, 10, 12, 23, 26, 27 and 28.

## Release and native performance

The retained baseline is `dc5d2a3`, built with Swift 6.1.3 in Release mode.
The final `scripts/verify.sh --fast` gate passed: 1,439 library tests, 142 optimized
tests, 371 LecternCore tests, 38 offline workflow checks, 10 saved native-pack
checks, 14 exact image probes, 36 pinned PowerPoint image comparisons and both
README examples. App builds, hosted tests and the new chart cases' native visual
acceptance were not run on this Linux host.

Final paired Release medians (baseline → measured layout):

| Input | First inspection SVG CPU | Process CPU | Process elapsed | Peak process RSS |
| --- | ---: | ---: | ---: | ---: |
| Higher education, 33 slides | 53.1 → 57.9 ms | 886.0 → 887.6 ms | 1007.1 → 1011.7 ms | 33.5 → 33.3 MiB |
| Embedded Arial, six chart slides | 18.6 → 24.3 ms | 277.2 → 283.7 ms | 325.1 → 328.2 ms | 39.9 → 39.8 MiB |
| Simple PowerPoint, one slide | 1.17 → 1.11 ms | 87.4 → 79.1 ms | 101.0 → 90.7 ms | 27.1 → 26.7 MiB |
| Image mapping, 12 slides | 3.37 → 2.81 ms | 144.0 → 143.4 ms | 215.1 → 215.8 ms | 27.4 → 27.2 MiB |

Process totals include two inspections and their exports, unlike the first-
inspection SVG column. Five measured pairs were collected for each chart input,
three for each unchanged-output control, after one warm-up pair. On the 33-slide
input, individual paired SVG CPU deltas ranged from −7.8 to +19.0 ms, with a
median of +1.6 ms; the difference of the two overall medians is +4.8 ms. The
Arial fixture's median paired delta was +4.9 ms. These are noisy single-host
measurements, not evidence of a pipeline speedup or a precise fixed overhead.

The 33-slide candidate's first-operation stage medians were 48.6 ms CPU to open,
45.2 ms to validate, 37.4 ms to extract and 57.9 ms for all SVGs. Its first SVG
slot completed at 142.5 ms versus 140.8 ms. Linux does not perform native Mac
font registration, WebKit loading or bitmap capture.

All 25 non-chart SVGs and 15 exports in the real deck were byte-identical to the
baseline. All 13 control SVGs, their diagnostics and exports were identical.
The six Arial chart SVGs changed as expected, with their seven exports unchanged.
Every repeated output was deterministic, every slide rendered, source hashes
were unchanged, and there were no read/schema errors. All 20 bar labels and
eight line markers remained present in the real deck, with no chart omissions.

[Raw samples, resource measurements and hashes](benchmarks/2026-10-18-measured-chart-layout.json.gz)
identify both executables, the inputs and final production source files. The
private deck, review fixture and licensed Arial file remain outside Git. The
collector streams hashes to avoid an executable-sized parent allocation masking
the child's peak RSS, and compares sparse diagnostics by original slide number.

The dedicated comparison script allows only explicitly named chart SVG changes
and their diagnostics. It still requires identical extracted content/export
bytes, unchanged non-chart previews, deterministic repetitions and unchanged
source inputs. Performance-only experiments must use the stricter
[output-preserving profiler](../Tools/preview-profile/README.md).

```sh
python3 docs/benchmarks/2026-10-18-chart-layout-measure.py \
  --baseline /absolute/retained-baseline/InspectionRegression \
  --candidate Lectern/.build/release/InspectionRegression \
  --input /absolute/the-state-of-higher-education-2026-1790864774198.pptx \
  --changed-slides 7,8,10,12,23,26,27,28 \
  --pairs 5 --output /absolute/new-chart-layout-measurements
```

Build both executables in Release before measuring; keep the SwiftPM resource
bundle alongside a relocated binary. Stop other builds/tests. Each sample starts
a fresh process and inspects twice with new presentation/font registries. Raw
stage CPU/elapsed, process CPU/elapsed and process peak RSS are retained. First
SVG completion is not a bitmap or a visible frame. Linux lacks the deck's exact
Arial Narrow/Courier New faces and cannot qualify native font/layout behavior.

On an idle Mac after quitting Lectern, use the same saved deck:

```sh
bash Lectern/scripts/test-preview.sh "/path/to/the-state-of-higher-education-2026-1790864774198.pptx"
python3 Lectern/scripts/compare-preview-loading.py "/path/to/the-state-of-higher-education-2026-1790864774198.pptx" --pairs 5
```

The first command collects production Release inspection and native thumbnail
regressions. The second alternates inline/shared-font WebKit loading and requires
exact bitmap and SVG parity. Shared-font loading remains experimental and off by
default until paired native timing supports adoption. These collectors report
app-process resources; WebKit helper-process memory/CPU and actual first visible
frame latency still require native tracing. Compare chart wrapping and label
placement with PowerPoint slide view and exported images using the same fonts;
portable tests and substitute-font raster checks do not establish that acceptance.
