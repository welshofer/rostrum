# Repeated multi-row table headers

`TemplateTableContent.headerRowCount` selects a leading source-row prefix to
repeat on every continuation. It defaults to one and must be between one and
the source row count. Header-only content creates one page. Each
`TemplateTablePagePlan` exposes the count alongside its original-source
`bodyRows` range, so consumers can distinguish repeated rows from new content.

Horizontal, vertical and rectangular merges can live entirely within the
header. They retain their native spans on every page. Body rows connected by
vertical merges still travel together. A merge crossing the header/body boundary
is refused before mutation; use single-slide composition for that topology.
Oversized headers and body groups refuse without shrinking text or losing words.

This is a pagination policy. Native `firstRow` styling continues to apply only
to row zero; additional header rows retain whole-table, band and edge styling.
The existing conservative style envelope reserves enough height for those styles.
The change does not create a new table style or modify a caller's font selection.

Column-width trials reserve the combined header height before scoring body-group
fit and page count. Integer EMU sums stop at the available height, including
overflowing prefixes. Page construction copies the complete header prefix and
remaps body merges into local grid coordinates. Existing search/preparation
budgets and fresh composition checks remain intact; there is no persistent cache.
Header copies add work proportional to the header cells emitted across pages.

See the [current usage guide](LAYOUT-ENGINE.md#table-continuations-in-templates)
for a two-row example. The API requires `main` or a later release than 1.0.0.
Lectern's generated deck IR still models a single header row; this expanded
capability is available to library callers and the offline Templates Lab.

## Lectern demonstration and acceptance

The Templates Library Lab adds `repeated-headers-output.pptx` with a two-row
header, vertical labels, a horizontal grouped heading and eight connected body
groups. It runs at 4:3 and 16:9, saves/reopens the native table grid, checks exact
source rows, headers, notes, combined cell fit and caption clearance, and compares
the resulting SVGs through production inspection/export.

To retain both Lab runs after pulling:

```sh
ROSTRUM_VERTICAL_MERGE_ARTIFACTS="$PWD/.build/table-header-review" \
  swift test --package-path Lectern --filter TableVerticalSpansLabTests
```

`TableRepeatedHeaderTests` covers three-row headers containing 2×2 and 3×1
merges, measured/estimated widths, header-only content, exact fits, source ranges,
native style bands, caption bounds, stale geometry, invalid counts, overflow and
header/body-crossing refusal. It runs in both Debug and optimized CI.

The earlier Calibri pack has [user-reported PowerPoint acceptance](POWERPOINT-REVIEW-20261016.md).
Regenerating all four accepted profiles with this implementation produces
byte-identical PPTX files, preserving the exact files the user approved.
These newly generated multi-row-header cases remain pending native PowerPoint
review. Passing portable checks and compiling the native app do not establish
slide-view or PDF-export fidelity. The Lab's redistributable fixture font is
separate from the caller-supplied faces used by the Calibri pack.

The full local portable gate passed: 1,399 root tests, 80 optimized text/layout
tests, 357 LecternCore tests, ten native-pack checks, portable fidelity references,
offline workflow checks and runnable README examples. Both retained Templates
Lab runs passed all 39 checks; independent python-pptx readback retained all 16
body rows and repeated native headers across two pages per aspect ratio.
Apple package tests, macOS/iOS builds and native test-host compilation are required
in PR CI. App-hosted test execution and live PowerPoint review remain separate.

## Separate Calibri review files

Two new five-slide decks were generated with the same supplied Calibri faces as
[the accepted pack](POWERPOINT-REVIEW-20261016.md). Each contains two pages with
2-row headers and three pages with 3-row headers, including 2×2 and 3×1 header
merges. Independent saved-file checks retain every body row, header and native
span. Representative portable previews were inspected using the existing
hash-verified font adapter. Native PowerPoint acceptance is **pending**.

| File | SHA-256 |
| --- | --- |
| Repeated-Headers-4x3-Calibri.pptx | `bb35a5f8fab7056b8d0f254c420a99ad8890e107557c84c6cea7d5c954c11711` |
| Repeated-Headers-16x9-Calibri.pptx | `8ab7a804e9b6febdf637590ee7baea2d847ddfbec3f5fc6d7cbbf8697bbefbd7` |

Fonts and generated review decks remain outside Git. The delivery bundle retains
the generator and manifest alongside the decks; the portable Lab above remains
runnable using only repository fixtures.

## Reproduce the Release comparison

Baseline: `5a936fcb68b08ad58614c5d834ac3548fde3d86e`. With the same Swift toolchain,
build the existing plain, horizontal and vertical drivers on that revision before
changing library sources. Keep the binaries outside the checkout, then build the
candidate counterparts and the new header driver:

```sh
mkdir -p /tmp/repeated-headers
git rev-parse HEAD > /tmp/repeated-headers/baseline-commit.txt
swift build -c release --target RostrumLayout
swiftc -O -I .build/release/Modules \
  docs/benchmarks/2026-10-12-table-preparation.swift \
  .build/release/Rostrum.build/*.o .build/release/RostrumLayout.build/*.o \
  -o /tmp/repeated-headers/baseline
swiftc -O -I .build/release/Modules \
  docs/benchmarks/2026-10-12-table-spans.swift \
  .build/release/Rostrum.build/*.o .build/release/RostrumLayout.build/*.o \
  -o /tmp/repeated-headers/baseline-spans
swiftc -O -I .build/release/Modules \
  docs/benchmarks/2026-10-16-table-row-pagination.swift \
  .build/release/Rostrum.build/*.o .build/release/RostrumLayout.build/*.o \
  -o /tmp/repeated-headers/baseline-vertical
# With candidate sources, repeat as candidate, candidate-spans, candidate-vertical.
swiftc -O -I .build/release/Modules \
  docs/benchmarks/2026-10-16-repeated-headers.swift \
  .build/release/Rostrum.build/*.o .build/release/RostrumLayout.build/*.o \
  -o /tmp/repeated-headers/headers
python3 docs/benchmarks/2026-10-16-repeated-headers.py \
  /tmp/repeated-headers /tmp/repeated-headers/results.json
```

Run with the pinned Python oracles installed and other builds/tests idle. The
collector uses the existing benchmark-only C launcher to measure child CPU and
peak RSS after exec. The shipped libraries remain pure Swift.

Nine existing controls compare widths, heights, page boundaries, ordered
diagnostics, exact decks and SVGs. New 24- and 100-row header cases repeat in
fresh processes; independent python-pptx checks verify the complete saved text,
native spans and geometry. Timings use five alternating process pairs for each
of seven existing workloads, and five processes each for four new header cases.
Each process performs five operations, with trial zero excluded from phase
medians. Planning/composition timers exclude setup, saving and SVG rendering;
composition includes its fresh preflight. Whole-process CPU/elapsed/RSS include
setup and all trials. Keep all samples, including adverse controls.

## Captured results

Linux x86_64, Swift 6.1.3 Release. All **142 existing control artifacts** retain
geometry, source page ranges and ordered diagnostics, with exact PPTX/SVG bytes.
The new header cases reproduce all **44 artifacts** and pass independent saved
text, native merge and row/column geometry checks.

**This feature is not a speedup claim.** Existing-control paired phase medians
range from a 3.1% improvement to a 4.6% slowdown; plain-table composition is
4.5% slower at 24 rows and 4.6% slower at 1,000 distinct rows. Process CPU
paired medians range from -4.7% to +1.0%, and peak RSS is essentially unchanged.
All samples, including adverse controls, are retained. Native Mac performance
remains unmeasured.

The cells below are baseline → candidate medians. Parentheses show the median
of paired percentage changes, which can have a different sign from the ratio
of the two aggregate medians. Phase values exclude trial zero; process values
include setup and all five trials. Process elapsed includes the small launcher.

| Workload | Plan CPU ms | Plan elapsed ms | Compose CPU ms | Compose elapsed ms | Process CPU ms | Process elapsed ms | Peak RSS MiB |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Plain, 24, distinct | 7.6 → 7.4 (-0.8%) | 7.6 → 7.4 (-0.8%) | 9.9 → 10.6 (+4.5%) | 9.9 → 10.6 (+4.5%) | 132.9 → 125.1 (-4.7%) | 134.9 → 126.9 (-4.2%) | 23.30 → 23.23 |
| Plain, 1000, repeated | 87.8 → 81.9 (+0.3%) | 88.0 → 81.9 (+0.3%) | 187.6 → 178.9 (+0.3%) | 187.6 → 178.9 (+0.2%) | 1461.0 → 1403.2 (-0.6%) | 1462.7 → 1404.8 (-0.5%) | 31.07 → 30.98 |
| Plain, 1000, distinct | 285.0 → 339.4 (+1.3%) | 285.0 → 339.7 (+1.3%) | 384.9 → 393.6 (+4.6%) | 384.9 → 393.6 (+4.6%) | 4066.8 → 3732.9 (-2.2%) | 4068.5 → 3738.7 (-2.2%) | 33.67 → 33.64 |
| Horizontal, 24, distinct | 19.9 → 19.6 (-1.8%) | 19.9 → 19.6 (-1.8%) | 22.7 → 23.0 (-3.1%) | 22.7 → 22.9 (-3.1%) | 244.2 → 242.7 (+1.0%) | 246.0 → 244.5 (+1.1%) | 23.29 → 23.29 |
| Horizontal, 1000, distinct | 744.4 → 746.3 (-0.4%) | 744.3 → 746.3 (-0.3%) | 833.9 → 848.9 (-0.6%) | 833.9 → 848.9 (-0.6%) | 8119.4 → 8161.4 (+0.3%) | 8121.0 → 8167.7 (+0.3%) | 36.29 → 36.25 |
| Vertical, 24, distinct | 13.8 → 13.9 (+0.5%) | 13.8 → 13.9 (+0.5%) | 17.0 → 16.6 (-3.1%) | 17.0 → 16.6 (-3.1%) | 182.4 → 184.0 (-0.8%) | 187.2 → 185.7 (-1.2%) | 23.29 → 23.31 |
| Vertical, 1000, distinct | 482.7 → 477.3 (-1.8%) | 482.7 → 477.3 (-1.8%) | 593.6 → 583.6 (-1.4%) | 593.6 → 583.6 (-1.4%) | 5526.8 → 5489.4 (-0.7%) | 5541.1 → 5491.0 (-0.7%) | 33.64 → 33.56 |

New multi-row header workloads (previously unsupported):

| Rows | Labels | Pages | Plan CPU ms | Plan elapsed ms | Compose CPU ms | Compose elapsed ms | Process CPU ms | Process elapsed ms | Peak RSS MiB |
| ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 24 | repeated | 4 | 7.2 | 7.2 | 9.6 | 9.6 | 115.0 | 117.0 | 23.43 |
| 24 | distinct | 4 | 15.2 | 15.2 | 17.9 | 17.9 | 195.0 | 197.4 | 23.32 |
| 1000 | repeated | 167 | 73.9 | 73.9 | 173.5 | 173.5 | 1334.6 | 1336.1 | 31.18 |
| 1000 | distinct | 167 | 480.2 | 480.2 | 589.2 | 590.1 | 5511.1 | 5513.6 | 33.64 |

Page counts exclude the constructor's retained blank slide in benchmark artifacts.
Standalone Lab/review decks contain only composed pages. These header cases use
the same full-size typography and search budgets; they do not shrink text to
reduce page count.

[Raw samples and source/binary hashes](benchmarks/2026-10-16-repeated-headers.json)
retain all 35 alternating pairs and 20 new-workload processes. No samples were
discarded or rerun to select a better result.
