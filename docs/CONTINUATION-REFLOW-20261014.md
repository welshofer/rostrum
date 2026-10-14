# Authored continuation reflow

Lectern used the same two-panel layout on every comparison continuation, even
after one column ended. It also sent a source to a new slide as soon as the narrow
citation box overflowed. The user's deck exposed both behaviors: an otherwise
empty panel beside one leftover bullet, and one citation on its own source slide.

## Behavior

- One-sided comparison/two-column continuation tails are measured again at full
  width. The active column heading stays with its text. The opening comparison
  retains both headings; per-column source order stays intact.
- When the final text page occupies less than 40% of its body frame and the
  previous page is over 20 percentage points fuller, the consumer measures up to
  eight alternative boundaries between those two pages. Both pages must fit;
  the occupied-fraction difference must improve by at least five points. Whole
  paragraph fragments move in order. Larger original paragraphs retain the
  existing exact-substring splitting behavior. Titles are never lengthened.
- Sources first try the existing citation box. If it fails, they try an unused
  full-width band of up to 72 points above the running furniture, using 10–14pt
  caption text. Complete content and reserved image frames, with explicit gaps,
  bound that band. A source that still cannot fit retains its source-note pages.
- Source probes discard their temporary chart/diagram parts as well as their
  slide. They cannot leave an unused workbook or chart in a successful export.

These are Lectern's authored-composition policies. The portable library API,
`MeasuredPaginator`'s maximal-prefix contract, imported template composition and
native table pagination are unchanged. Font families remain caller-controlled.
The balance score uses shared text geometry after the full fit check; it does not
override native-host checks or authorize an otherwise rejected fit.

New page IDs, images, notes and section membership follow the existing continuation
rules. Cancellation interrupts measurement. Recovery preserves existing page IDs
and review annotations; a shorter result requires a whole-deck rebuild from saved
content into a new copy, rather than deleting reviewed pages.

## Verification

The local `scripts/verify.sh --fast` gate passed 1,363 library tests, 63 optimized
layout tests, 328 LecternCore tests, all 36 saved PowerPoint reference comparisons,
offline workflow checks and executable README examples. Coverage includes:

- Both left- and right-sided tails, active headings, source order and section IDs.
- Bounded balancing, rejected moves, image associations and cancellation.
- Production saved/reopened continuation geometry, exact fact counts, notes,
  section membership and recovery comments without modifying the original file.
- Citation/content/furniture separation on 4:3 and 16:9 canvases, reserved images,
  oversized-source refusal and rollback, and matching generated/Inspect previews.
- No orphan chart/workbook parts after failed source-placement probes.

Independent python-pptx and ZIP checks pass on all five baseline/candidate
specimens. The already-fitting control retains byte-identical decks and SVGs.
The dense-text and long-source decks also remain byte-identical in these fixtures;
the comparison and moderate-source layouts intentionally change. Native PowerPoint
visual acceptance remains separate. Linux SVG review with fallback fonts is only
diagnostic evidence, not acceptance of arbitrary installed fonts on a Mac.

## Release measurements

The baseline is `783af36640c736c3c80e56f4f61919b24c3f55aa`. The fixed
[driver](benchmarks/2026-10-14-continuation-reflow.swift) runs the production
renderer, including save and previews, without model/network calls. The
[collector](benchmarks/2026-10-14-continuation-reflow.py) alternates baseline and
candidate processes, excludes one warm-up pair, and retains five timed pairs per
workload. Both binaries use Swift 6.1.3 Release on the same Linux x86_64 host.
No builds or tests ran concurrently with the final collection.

The [complete record](benchmarks/2026-10-14-continuation-reflow.json) includes
binary/driver hashes, all 60 processes, ordered warnings, missing-font reports and
independent saved-output checks. Calibri faces were unavailable on this Linux host;
this is a bounded headless-generation comparison, not a Mac font-performance claim.

Times are milliseconds, baseline → candidate medians. CPU change is the median
within-pair change, not the ratio of the displayed medians. RSS is whole-process
peak MiB from `wait4`, including startup and read-back. The collector peaked at
12.5 MiB before spawning; every child exceeded 26.4 MiB.

| Fixed workload | Slides | CPU | Paired CPU change | Elapsed | Peak RSS |
| --- | --- | --- | --- | --- | --- |
| Already-fitting control | 2 → 2 | 22.90 → 23.37 | −0.69% | 23.30 → 23.82 | 26.94 → 26.82 |
| Unequal comparison columns | 9 → 4 | 148.75 → 123.64 | −14.63% | 149.44 → 124.13 | 30.60 → 28.22 |
| Dense text | 3 → 3 | 78.68 → 78.84 | +2.24% | 79.17 → 79.37 | 27.42 → 27.32 |
| Moderate closing citation | 2 → 1 | 22.70 → 18.12 | −19.70% | 23.24 → 18.53 | 26.90 → 26.64 |
| Long chart source | 3 → 3 | 75.94 → 80.07 | +8.38% | 76.51 → 80.43 | 27.49 → 27.49 |

All comparison and moderate-source pairs improve CPU. Extra source-placement and
tail measurements have a cost: the long-source median increases 8.38%, with a
−6.34% to +17.33% range; dense text is +2.24%, ranging −15.70% to +10.15%.
The short control is noisy (−17.58% to +46.94%). These results establish neither
a universal speedup nor a general memory reduction. Page-count changes account
for part of the gain where fewer slides must be written and previewed.

## Reproduce

Build and retain a baseline executable before changing the source. Repeat for the
candidate with the same compiler and inputs, using a fresh scratch directory:

```sh
mkdir -p /tmp/continuation-reflow
swift build -c release --package-path Lectern --target LecternCore
swiftc -O -parse-as-library -I Lectern/.build/release/Modules \
  docs/benchmarks/2026-10-14-continuation-reflow.swift \
  Lectern/.build/release/LecternCore.build/*.o \
  Lectern/.build/release/Rostrum.build/*.o \
  Lectern/.build/release/RostrumLayout.build/*.o \
  -o /tmp/continuation-reflow/baseline
# Repeat after the change, writing /tmp/continuation-reflow/candidate.
python3 docs/benchmarks/2026-10-14-continuation-reflow.py \
  /tmp/continuation-reflow /tmp/continuation-reflow-report.json
```

Each specimen retains its input JSON and PPTX. Replay that JSON with
`CompositionRegression --replay` and a caller-selected design, then review the
saved deck in PowerPoint. Source words, heading associations, body width, native
wrapping, sources and footer separation are the visual acceptance targets.
