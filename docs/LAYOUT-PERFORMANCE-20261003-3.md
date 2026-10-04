# PERF-1: reduce common layout copying while preserving output

Source commit `993447114aba8cdcc39c099ae80fa21c3e3d74b3` improves registered-font
2,000-cell table rendering by **7.56%** and rich fitting by **7.91%** versus
current baseline `5654d1b09e43d26f93a195270f8832b6be3a21e4`. Both workloads are
faster in all ten matched pairs, with nonoverlapping observed ranges. All
**628 compared slides** retain byte-identical output.

A separate matched comparison against pre-tab baseline `cf1b8a0` measures
registered table rendering 9.13% faster and rich fitting 5.91% faster, again with
nonoverlapping ranges. This recovers the demonstrated fitting regression on these
inputs. **Fallback table recovery remains unproven.** Its recovery comparison has
overlapping ranges and five faster/five slower pairs; no universal speed or
memory improvement is claimed. These measurements cover this output-preserving
change before the next fidelity integration, which requires its own final run.

## Changes and profiling

The fresh baseline release object/executable were retained before implementation.
Three-second profiles exercised repeated fallback/registered 2,000-cell table
rendering and rich fitting. One fallback emission branch contained 33 samples
under the height maximum and 27 under the ascent maximum, dominated by copying
and retaining complete styled atoms through lazy reductions. Fitting also showed
height/ratio reductions. These inclusive nested counts locate work, not speed.

The final implementation makes three bounded changes:

- Read height/ascent/DrawingML fields through indexed numeric scans. Maximum
  initialization, strict comparison order and the ascent formula are preserved.
- Store each nonempty piece's resolved style once in a paragraph-local array;
  atoms carry a style index. Run/source identity, cluster boundaries, resolution
  order and span-merging behavior remain unchanged. The table is rebuilt for each
  paragraph in each layout call and retains no DOM state between calls.
- Skip the fragment-shaping traversal when both registered faces and fallback
  metrics are absent. In that case `face()` always returns nil, so the former
  traversal could change no widths or diagnostics.

No arithmetic/geometry rule, public API, dependency, mutable global state or
native fixture changed. The earlier rejected no-tab RTL/carry experiment remains
unshipped and is not part of this change.

## Final matched measurements

The same benchmark source was compiled against each retained release library
object with `swiftc -swift-version 6 -O`. Each comparison used ten alternating
fresh-process pairs after one excluded warmup pair, on the same arm64 Mac,
compiler and Arial bytes. The root explicitly held GUI/build activity and obtained
other workers' pause confirmations before every authoritative window.

[Final samples against the current baseline](benchmarks/2026-10-03-layout-common-path-paired-macos.json):

| Scenario / phase | Current baseline | Candidate | Candidate faster pairs |
| --- | ---: | ---: | ---: |
| Registered Arial 100 × 20 table: render | 82.553 ms | 76.309 ms | 10 / 10 |
| Registered 2,600-character text: rich fitting | 15.176 ms | 13.975 ms | 10 / 10 |
| Fallback 200 × 50 table: render | 180.649 ms | 175.164 ms | 9 / 10 |
| Fitted text: render | 3.302 ms | 3.090 ms | 10 / 10 |
| Fallback 10-slide deck, first slide: render | 0.567 ms | 0.548 ms | 8 / 10 |

The registered table's observed ranges are 82.153–83.388 versus 75.399–77.458 ms;
rich fitting is 14.988–15.532 versus 13.787–14.335 ms. The other ranges overlap,
so their lower medians do not support additional speed claims.

[Separate recovery comparison against cf1b8a0](benchmarks/2026-10-03-layout-common-path-recovery-paired-macos.json):

| Scenario / phase | Pre-tab baseline | Candidate | Candidate faster pairs |
| --- | ---: | ---: | ---: |
| Registered Arial 100 × 20 table: render | 83.879 ms | 76.220 ms | 10 / 10 |
| Registered 2,600-character text: rich fitting | 14.783 ms | 13.909 ms | 10 / 10 |
| Fallback 200 × 50 table: render | 172.483 ms | 174.714 ms | 5 / 10 |
| Fitted text: render | 3.233 ms | 3.113 ms | 10 / 10 |
| Fallback 10-slide deck, first slide: render | 0.566 ms | 0.544 ms | 8 / 10 |

The registered table's observed ranges are 81.859–84.749 versus 75.207–77.076 ms;
rich fitting is 14.515–14.890 versus 13.733–14.304 ms. Fallback rendering is 1.29%
slower by median but ranges overlap substantially (169.601–187.140 versus
168.775–179.891 ms). This does not establish fallback regression recovery or a
new consistent regression. Small fitted-text/slide timings also overlap.

Whole-scenario median peak RSS against the current baseline is 199.69 → 199.42
MiB for fallback tables, 52.38 → 52.48 MiB for registered tables and 21.22 → 20.88
MiB for fitting. These process peaks do not isolate layout and establish no net
memory improvement. Linux/iOS speed and universal thresholds remain unmeasured.

## Preserved intermediate evidence

Three measured cycles were completed. Their candidate snapshots, patches, objects,
executables and logs remain separate; absolute timings from different cycles must
not be compared as if those candidates were paired directly.

1. Numeric scans alone: [current-baseline samples](benchmarks/2026-10-03-numeric-scans-paired-macos.json),
   [recovery samples](benchmarks/2026-10-03-numeric-scans-recovery-paired-macos.json),
   [verification receipt](benchmarks/2026-10-03-numeric-scans-verification.json).
   Current-baseline ranges overlapped; fallback recovery remained unproven.
2. Numeric scans plus paragraph-local styles: [current-baseline samples](benchmarks/2026-10-03-atom-styles-paired-macos.json),
   [recovery samples](benchmarks/2026-10-03-atom-styles-recovery-paired-macos.json),
   [verification receipt](benchmarks/2026-10-03-atom-styles-verification.json).
   Registered table/fitting improved against the current baseline with nonoverlap;
   recovery fitting and fallback ranges still overlapped.
3. Final nil-metrics guard added: the final samples above and
   [verification receipt](benchmarks/2026-10-03-layout-common-path-verification.json)
   pin the accepted source. The guard's incremental speed benefit was not isolated
   in a direct cycle-two/cycle-three comparison.

Scratch evidence is retained under `.build/perf5/`, `.build/perf6/` and
`.build/perf7/`, respectively. The older recovery baseline remains in `.build/perf4/`.

## Correctness and reproduction

The [final identity receipt](benchmarks/2026-10-03-layout-common-path-output-identity.json)
records 76 fixture/font combinations and 628 slides with identical SVG, ordered
diagnostics, inheritance flags and saved PPTX against `5654d1b`. All 152 saved
outputs independently reopened with python-pptx and table-cell traversal. The
proof command also checks that rendering does not mutate the document.

`swift test --jobs 2` passed **1,021 tests in 141 suites**, including all **60 native
PowerPoint tab-geometry cases**. Two new parameterized tests cover empty runs,
tabs, slide fields, paragraph resets, mixed styles, wrapping and direct DOM plus
inherited-style edits in both registered/fallback modes. Earlier layouts remain
unchanged after subsequent edits. Existing shaping and diagnostic preservation
tests remain green. No native fixture was edited.

Release build and `git diff --check` passed. No lint command is configured for
this lane. The root reported independent source-review approval for all three
changes. Integration tests and the upcoming fidelity change's final timing remain
separate gates.

```sh
ROSTRUM_BENCH_FONT=/System/Library/Fonts/Supplemental/Arial.ttf \
python3 Tools/rostrum-bench/run.py \
  --binary .build/perf7/candidate-extended-bench \
  --paired-binary .build/perf5/baseline-extended-bench \
  --paired-revision 5654d1b09e43d26f93a195270f8832b6be3a21e4 \
  --runs 10 --warmups 1 \
  --scenarios table-200x50 shaped-table-100x20 richtext-fit slides-10 \
  --output /tmp/layout-common-path-paired.json
```

For the separate recovery comparison, use `.build/perf4/baseline-extended-bench`
and declared baseline `cf1b8a0cec2cf680383cb683603785aeaa0f2011`.
