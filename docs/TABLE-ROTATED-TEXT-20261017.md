# Rotated table text

Native table cells with `a:tcPr vert="vert"` (90°) or `vert270` (270°) can now
participate in measured layout. SVG rendering and cell `fitText` already support
these directions; this change connects the planner, column search and template
composition to the same geometry. No text is converted to artwork and no fonts
are replaced. Existing public `TableCell.textDirection` remains the native API.

`TemplateTableContent.textDirections` supplies sparse source-grid overrides.
Each `TableCellTextDirection` has a zero-based row, column and direction. Directions
on repeated header rows repeat; body directions follow their source anchors to
continuations. Horizontal text remains the default. All text and native merges
remain editable after saving and reopening. See the
[usage example](LAYOUT-ENGINE.md#rotated-table-cell-text).

## Measurement and limits

Rotated cell layout swaps width and height in the horizontal text coordinate
system. Insets keep their existing text-relative meaning, matching SVG and
`fitText`; they are not reinterpreted as physical slide edges. Full-size text is
measured against the fixed physical column width. A bounded search chooses the
physical row height, which supplies the text's inline extent. It uses the native
eighth-point capacity grid and at most 22 layouts per style/column trial.
Paragraph/font preparation is reused during these probes. The chosen extent is
always an actually fitting candidate, not an untested interpolation. Height
selection also rejects emergency breaks inside an unbreakable word: a short
label such as “Source” stays whole instead of becoming two sideways fragments.
Normal word/Unicode break opportunities and explicit line breaks remain usable.
The existing horizontal renderer and its emergency wrapping behavior are unchanged.

Neighboring cells, minimum row heights and intersecting row spans can increase
that extent. A final layout checks each rotated anchor in its exact saved
rectangle after all row constraints have been resolved. Mixed run metrics need
not have a globally monotonic wrapping-height function, so a failed final check
produces a non-fitting plan. `wordSplit` identifies a forced word break in this
rotated-height policy; ordinary geometric overflow retains its existing issue.
Neither condition is silently accepted or fixed by shrinking.
Per-column caches retain preliminary requirements, not final checks that depend
on neighboring columns. Only rotated cell indices are retained for that final
pass; existing preparation/source payload budgets remain in effect.

The search is bounded deterministic fitting, not a global minimum or PowerPoint
native table autofit. Existing 64-line and 1,000,000-point bounds apply. The outer
column-search budgets count cell visits; each rotated visit can make the extra
probes above. Horizontal cells retain their single-layout path. All caches expire
with the operation, so changed fonts, text, padding, styles and directions remain
visible to later calls and fresh composition checks.

Template overrides reject duplicate/outside coordinates, covered merge cells,
and unsupported writing modes before mutation. Apply the direction to a merge's
anchor. Stacked WordArt, East Asian/Mongolian vertical writing, arbitrary
`bodyPr.rot`, nonhorizontal `bodyPr.vert`, multiple text columns, dynamic fields,
and unverified stored line-spacing reduction remain explicitly unsupported.
Native XML can still preserve those modes through the existing cell API.

## Lectern and native review

Templates Lab adds `rotated-text-output.pptx`, containing opposite quarter-turn
header labels, alternating body labels, merged anchors, repeated headers and
captions. Both 4:3 and 16:9 runs save/reopen the deck, check original source words,
cell directions, merge topology and full-size final-cell fit, then use production
Inspect/export. To retain the review files after pulling:

```sh
ROSTRUM_VERTICAL_MERGE_ARTIFACTS="$PWD/.build/rotated-table-review" \
  swift test --package-path Lectern --filter TableVerticalSpansLabTests
```

The Lab uses its existing redistributable fixture fonts. Caller-supplied fonts
can be used with the separate review generator below. Neither choice changes
library font policy. The generated Deck IR does not yet expose these native cell
directions; the capability is available to library callers and Templates Lab.

The user reported “Decks look good” for the delivered rotated-table review pack
on October 17, 2026. This records pack-level visual acceptance against the exact
hashes below. The reply did not identify the app version or separate slide-view
and PDF-export checks; those specific native checks remain unrecorded. Portable
fit, preserved XML and successful app compilation are separate evidence.

## Separate Calibri review files

Two new five-slide editable decks use the previously supplied Calibri faces,
with two- and three-row merged headers, quarter-turn labels, continuations and
captions. Independent read-back checks retain every source group, direction,
merge and table boundary. Representative portable previews were visually
inspected with the existing hash-verified exact-font adapter. They are not
PowerPoint screenshots. The user subsequently accepted the delivered pack as
recorded above; separate native slide-view/PDF evidence remains unrecorded.

| File | SHA-256 |
| --- | --- |
| Rotated-Tables-4x3.pptx | `950db0a24b9ad758b49a81445448958b0161b1e942b4a6fb66d7d755e7c23b55` |
| Rotated-Tables-16x9.pptx | `13c809c2ed5febdeb5d94b98b23ccef22517eeccfd97c9c26b374ae809a7148b` |

Font bytes and generated review decks remain outside Git. The generator below
reproduces the cases with caller-supplied faces; the offline Lab uses repository
fixtures and requires no private manifest.

## Reproduce caller-font decks and measurements

Build outside the measured process:

```sh
swift build -c release
swiftc -O -I .build/release/Modules \
  docs/benchmarks/2026-10-17-rotated-review.swift \
  .build/release/Rostrum.build/*.o .build/release/RostrumLayout.build/*.o \
  -o .build/rotated-table-review-tool
.build/rotated-table-review-tool /absolute/path/fonts.json /absolute/path/new-output
```

The private manifest has `family`, `regular`, `bold`, `italic`, and `boldItalic`
keys with absolute paths to exact face files. It stays outside Git, as do
proprietary font bytes and generated review decks. The generator embeds those
faces, produces both slide ratios, and checks every saved visible anchor against
its final native rectangle.

The `2026-10-17-rotated-tables.swift` benchmark driver accepts the same arguments
as the repeated-header driver, with optional `--rotated` at the end. Its default
is a horizontal control. Compile with the same Release modules/object files.
Use the native `wait4` collector to retain process CPU, elapsed time and peak RSS;
measure alternating variants without builds or tests running concurrently.

For the preserving comparison, retain the normal Release baseline binaries from
`fd605f2` as `baseline`, `baseline-spans`, `baseline-vertical`, and
`baseline-headers` in a fresh scratch directory, using respectively the existing
`2026-10-12-table-preparation.swift`, `2026-10-12-table-spans.swift`,
`2026-10-16-table-row-pagination.swift`, and `2026-10-16-repeated-headers.swift`
drivers under `docs/benchmarks`. Compile the same drivers with candidate modules
as `candidate` and the corresponding suffixes. Compile the new driver as
`rotated` in that directory. Use the same toolchain, normal Release arguments
and `swiftc -O` link command as above for both versions; build all binaries before
starting the collector.

```sh
python3 docs/benchmarks/2026-10-17-rotated-collect.py \
  /absolute/path/fresh-scratch /absolute/path/fresh-scratch/results.json
python3 docs/benchmarks/2026-10-17-rotated-feature.py \
  /absolute/path/fresh-scratch /absolute/path/fresh-scratch/feature.json
```

The first collector compiles `measure-child` before measuring. Both collectors
require the pinned Python oracles in `Tools/conformance/requirements.txt` and
refuse existing artifact directories, avoiding accidental comparison with stale
files. The benchmark-only launcher and Python oracles are not library dependencies.

## Captured portable evidence

Linux x86_64, Swift 6.1.3, normal Release builds. The baseline is
`fd605f2745fb3af8394f9d68fe1b1d4b711093c7`; every retained baseline source
digest was checked against that revision. Candidate source/binary hashes and
compiler arguments are recorded in the [provenance](benchmarks/2026-10-17-rotated-provenance.json).

All **264 existing horizontal control artifacts** preserve column widths, row
heights, page boundaries, source text and ordered diagnostics, with exact PPTX
and SVG bytes. All **84 accepted Calibri-profile artifacts** also match, excluding
the report containing timings. The **1,248 layout/shaping snapshots** retain every
existing field, including floating-point bit patterns. Their raw JSON differs:
672 reflected layouts now expose the new internal emergency-break boolean.
Comparison checks its type/count, removes only that named field, and compares
every remaining field. The new rotated cases reproduce **124 artifacts** and
pass independent python-pptx text/direction/merge/grid/page-boundary checks.

### Existing horizontal controls

Five alternating fresh-process pairs per workload, pinned to one logical CPU,
without concurrent builds/tests. Each process performs five plan/compose trials.
Phase medians exclude trial zero; process CPU/elapsed/peak RSS include setup
and all five trials. Planning/composition phases exclude saving and SVG work;
composition retains fresh preflight. Process elapsed includes the small native
wait4 launcher. Raw [paired samples](benchmarks/2026-10-17-rotated-results.json)
include every control and adverse result. Timing is not a native Mac measurement.

**This is a capability expansion, not a speedup claim.** Median paired process
CPU changes range from -1.16% to +7.07%. The small plain measured case retains
a 7.07% process-CPU slowdown, the small horizontal-span case 6.83%, and the large
horizontal-span case 2.73%. Peak RSS medians differ by less than 0.25 MiB.
The final path avoids extra per-cached-cell rotation lookups, keeps rotation
indices at operation scope and skips direction remapping for horizontal inputs.

The cells below show baseline → candidate medians and, in parentheses, the median
paired percentage change. The latter can differ from the ratio of aggregate medians.

| Workload | Plan CPU ms | Plan elapsed ms | Compose CPU ms | Compose elapsed ms | Process CPU ms | Process elapsed ms | Peak RSS MiB |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Plain, 24, distinct, measured | 7.4 → 7.1 (+3.53%) | 7.4 → 7.1 (+3.54%) | 8.4 → 9.0 (+5.33%) | 8.4 → 9.0 (+5.36%) | 106.9 → 114.2 (+7.07%) | 108.4 → 115.7 (+6.80%) | 23.45 → 23.34 |
| Plain, 1000, distinct, measured | 278.4 → 279.1 (-1.30%) | 278.4 → 279.1 (-1.30%) | 343.1 → 343.5 (-0.98%) | 343.1 → 343.5 (-0.98%) | 3221.3 → 3202.0 (-0.28%) | 3224.9 → 3206.8 (-0.30%) | 33.89 → 33.83 |
| Plain, 1000, repeated, measured | 80.6 → 79.3 (-2.10%) | 80.6 → 79.3 (-2.09%) | 142.7 → 144.7 (-2.08%) | 142.7 → 144.7 (-2.09%) | 1224.0 → 1210.9 (-1.16%) | 1226.1 → 1213.1 (-1.15%) | 31.27 → 31.14 |
| Plain, 24, distinct, estimated | 3.4 → 3.5 (-1.18%) | 3.4 → 3.5 (-1.17%) | 5.9 → 5.3 (-1.41%) | 5.9 → 5.3 (-1.40%) | 72.3 → 74.3 (+3.50%) | 73.9 → 75.7 (+3.41%) | 23.40 → 23.32 |
| Column spans, 24, distinct, measured | 18.4 → 19.8 (+6.91%) | 18.4 → 19.8 (+7.03%) | 21.4 → 21.4 (-2.04%) | 21.4 → 21.4 (-2.04%) | 235.1 → 250.4 (+6.83%) | 236.7 → 254.1 (+6.31%) | 23.51 → 23.28 |
| Column spans, 1000, distinct, measured | 725.4 → 733.9 (+1.18%) | 725.4 → 734.0 (+1.18%) | 783.9 → 785.3 (+0.18%) | 783.9 → 785.3 (+0.18%) | 7694.0 → 8232.0 (+2.73%) | 7696.9 → 8244.2 (+2.71%) | 36.58 → 36.48 |
| Row spans, 24, distinct, measured | 13.6 → 13.4 (-2.37%) | 13.6 → 13.4 (-2.37%) | 15.0 → 15.7 (+3.48%) | 15.0 → 15.7 (+3.44%) | 177.0 → 179.7 (+1.31%) | 178.9 → 181.9 (+1.50%) | 23.50 → 23.34 |
| Row spans, 1000, distinct, measured | 470.1 → 473.5 (+0.51%) | 470.2 → 473.6 (+0.52%) | 533.4 → 525.2 (-0.33%) | 533.4 → 525.2 (-0.34%) | 5209.8 → 5180.0 (-0.39%) | 5212.0 → 5181.9 (-0.39%) | 33.84 → 33.65 |
| Repeated headers, 24, distinct, measured | 15.2 → 15.6 (+2.92%) | 15.2 → 15.6 (+2.88%) | 17.7 → 17.2 (-1.75%) | 17.7 → 17.2 (-1.75%) | 193.2 → 195.5 (+2.98%) | 195.6 → 197.2 (+2.92%) | 23.44 → 23.26 |
| Repeated headers, 1000, distinct, measured | 457.5 → 467.1 (+1.45%) | 457.5 → 467.4 (+1.46%) | 532.5 → 544.2 (+0.99%) | 532.5 → 544.3 (+0.99%) | 5116.1 → 5162.2 (+0.90%) | 5118.1 → 5165.5 (+0.93%) | 33.79 → 33.63 |

### New rotated workloads

These were previously unsupported. Three batches per case retain absolute cost
in [raw samples](benchmarks/2026-10-17-rotated-feature.json); they are not a
before/after comparison. Each process uses the same five-operation timing scope.
Page counts exclude the benchmark constructor’s blank slide. The 1,000-row
workload includes repeated rotated headers and periodic rotated body anchors.

| Rows | Sizing | Pages | Plan CPU ms | Plan elapsed ms | Compose CPU ms | Compose elapsed ms | Process CPU ms | Process elapsed ms | Peak RSS MiB |
| ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 24 | estimated | 6 | 4.4 | 4.4 | 6.7 | 6.7 | 84.8 | 87.3 | 23.41 |
| 24 | measured | 4 | 28.1 | 28.1 | 30.2 | 30.2 | 316.4 | 318.6 | 23.41 |
| 1000 | estimated | 250 | 129.7 | 129.7 | 222.3 | 222.3 | 1917.1 | 1919.4 | 33.18 |
| 1000 | measured | 167 | 964.7 | 964.7 | 1033.9 | 1033.9 | 10286.3 | 10290.6 | 33.91 |

## Validation gate

The full local portable gate passed: **1,410 root tests, 116 optimized text/layout
tests and 357 LecternCore tests**, ten native-pack checks, 35 workflow checks
(two Mac-only skips), portable rendering references and runnable README examples.
Both retained Templates Lab runs passed all **43 checks**, including the new
rotated decks through production inspection/export. Required Apple package tests,
macOS/iOS builds and native test-host compilation run in PR CI. App-hosted test
execution and live PowerPoint review remain separate from these portable checks.
