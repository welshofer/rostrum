# Reuse complete fragment advances during table width search

The table width search still shapes initial text, assembles atoms and wraps each
prospective width. After selecting a line, the shared rich-text engine reshapes
its complete run fragments: a kerning pair crossing a line boundary must not
change the final glyph's advance. Repeated complete fragments now reuse that
advance within the same immutable table search. New fragments take the original
shaping and native-rounding path, with the same arithmetic order.

## Profile

The baseline is `d6aaefdd695db18502109cbed3030f1e82ba9473`. An
[isolated copy of Rostrum](benchmarks/2026-10-13-table-shaping-profile.py) records
nested monotonic scopes around paragraph preparation, initial atom assembly,
initial shaping, wrapping and line-fragment shaping. It uses Swift 6.1.3 Release
WMO, linked to the baseline layout module. No timing probes enter the library.
The [raw profile](benchmarks/2026-10-13-table-shaping-profile.json) retains five
plans per workload; trial zero is excluded from the medians below.

For the 1,000-row distinct-text merged workload, a plan takes about 637 ms of CPU
in the instrumented binary. Its 18,045 rich-text layouts take about 501 ms of
elapsed scoped time. Initial atom assembly takes 135 ms, including 55 ms of
initial shaping. Wrapping takes 273 ms, including 92 ms for 30,448 complete
fragment shapes. Paragraph input preparation takes 25 ms. These are nested
scopes, not additive totals; instrumentation affects timings. The profile
identifies repeatable work, not an end-to-end speedup.

The repeated-label merged case requires only 79 rich-text layouts and 119
fragment shapes because existing cell/column caches already remove most work.
That workload is a control, not the expected source of a large improvement.

## Ownership and bounds

The cache belongs to `TableCellPreparation` and is shared by its retained text
preparations after the starting width allocation. Default rich-text preparation,
ordinary rendering, authored autofit and estimated-width planning do not opt in.
A search that stops at the starting allocation does not populate this cache.

Each key includes exact UTF-8 fragment text, the requested family/bold/italic
style, effective measurement point size, kerning and standard-ligature policy,
and whether native left-to-right advance rounding is eligible. Requested face
names identify metrics only within the fixed font environment of this operation.
New searches and composition preflight resolve fonts, content and styles again.
Cached values contain only the pre-tracking scalar advance; tracking, wrapping,
line positions, justification, diagnostics and page scoring remain unchanged.

At most 2,048 entries and 256 KiB of source-text/family-name bytes are retained.
These bounds are not a heap-size claim. No glyph arrays or complete layouts are
retained by this cache. Full caches still serve existing keys and measure new
ones normally; oversized fragments are measured without retention. All existing
cell-input, text-preparation, column-result and search budgets remain unchanged.
The library stays pure Swift with no external dependencies or public API changes.

## Verification

The [preservation checker](benchmarks/2026-10-13-table-shaping-preserve.py)
compares 12 workloads, including mixed scripts, repeated/distinct labels, short
cells and estimated-width controls, with and without horizontal spans. Across
1,480 artifacts, all widths, heights, page boundaries, fit flags, cell issues and
ordered diagnostics agree. All 12 PPTX files and 728 SVGs compare byte for byte.
JSON object ordering alone is normalized. ZIP CRC and independent python-pptx
reopening verify native widths/heights, every source row/word and merge topology.

New regressions compare complete geometry and floating-point bit patterns across
shared fragments with different faces, sizes, kerning, ligatures, tracking,
direction, tabs and line boundaries. They cover exact source-byte identity,
entry/payload admission limits, saturated-cache fallback, and replacement of a
font under the same requested family between separate searches. Existing rich
text and table tests also cover unsupported scripts, missing fonts, native bands,
span dependencies and fresh content/style changes.

The Templates Library Lab passes all 52 checks across 16:9 and 4:3 variants
(13 and 16 slides). All 68 exported files are byte-identical, including 66
decks/previews. Complete inspector reports match after excluding elapsed time;
checks, findings and their ordering are unchanged. All 24 archives pass CRC
validation, and all 16 PPTX files reopen independently. The
[Lab comparison helper](benchmarks/2026-10-13-table-shaping-lab.py) retains this
comparison separately from benchmark timings.

The complete `scripts/verify.sh --fast` gate passes 1,326 root tests, 52 Release
preparation/shaping/table tests, 309 LecternCore tests and all 36 saved PowerPoint
reference comparisons, plus oracle preflight, offline workflow checks and README
execution. The [verification record](benchmarks/2026-10-13-table-shaping-verification.json)
retains case counts and source identity. Apple app builds remain a separate PR CI
check; the Linux gate cannot run app-hosted tests.

Native PowerPoint visual acceptance for the measured/merged table corpus remains
pending. Byte preservation and portable oracles protect existing behavior; they
do not independently establish native PowerPoint equivalence.

## Measurement method

The [collector](benchmarks/2026-10-13-table-shaping-collect.py) uses the unchanged
table-preparation and table-span drivers from October 12. Both baseline and
candidate are built with Swift 6.1.3 Release on the same Linux AMD EPYC 9V74 host.
Five alternating baseline/candidate process pairs cover each of 12 cases. Each
process performs five plan/compose trials; trial zero is warmup. No builds or
tests run alongside final timing.

Monotonic elapsed and process CPU clocks cover planning and composition
separately, including fresh composition preflight. Font setup, serialization,
rendering and slide cleanup are outside those phase timers. `wait4` peak RSS
covers the entire process and all trials, including font setup; it does not
isolate cache allocation. Raw samples retain source and binary SHA-256 values.
Checksums stream through bounded buffers so large binary reads do not inflate
the collector before spawning a child. Each sample also records the collector's
own peak RSS before spawning, making a possible inherited memory floor visible.
Paired percentages are medians of per-pair changes, not ratios of aggregate
medians. Shared-host variation and workload scope limit generalization.

## Results

The [raw paired record](benchmarks/2026-10-13-table-shaping.json) retains all 120
processes and 600 trials. Negative changes are faster; paired percentages are
calculated within process pairs. CPU timings below are milliseconds, RSS is MiB.

| Grid / body rows / labels / sizing | Plan CPU | Paired change | Compose CPU | Paired change | Peak RSS |
| --- | ---: | ---: | ---: | ---: | ---: |
| unmerged / 24 / repeated / measured | 3.218 → 3.310 | +1.99% | 4.790 → 4.911 | -0.19% | 23.004 → 23.035 |
| unmerged / 24 / distinct / measured | 5.114 → 4.986 | -3.49% | 6.723 → 6.541 | -6.84% | 23.090 → 22.992 |
| unmerged / 1000 / repeated / measured | 63.699 → 63.796 | -0.41% | 126.395 → 126.842 | +0.75% | 31.102 → 31.094 |
| unmerged / 1000 / distinct / measured | 225.757 → 228.198 | +1.08% | 293.217 → 299.731 | -2.09% | 33.629 → 33.652 |
| unmerged / 100 / distinct / measured | 7.108 → 7.300 | +3.23% | 11.109 → 11.458 | +3.14% | 23.387 → 23.367 |
| unmerged / 1000 / distinct / estimated | 63.638 → 64.828 | +0.02% | 159.583 → 163.957 | +0.43% | 32.770 → 32.707 |
| spans / 24 / repeated / measured | 4.695 → 4.259 | -8.06% | 6.743 → 5.872 | -9.27% | 23.047 → 23.086 |
| spans / 24 / distinct / measured | 15.647 → 14.279 | -9.02% | 17.440 → 16.162 | -9.94% | 23.082 → 23.082 |
| spans / 1000 / repeated / measured | 71.802 → 69.448 | -0.62% | 137.869 → 132.767 | -1.66% | 31.559 → 31.465 |
| spans / 1000 / distinct / measured | 657.206 → 570.188 | -13.24% | 722.319 → 639.755 | -13.02% | 36.008 → 35.684 |
| spans / 100 / distinct / measured | 7.471 → 7.676 | +2.75% | 11.848 → 11.412 | +1.47% | 23.363 → 23.438 |
| spans / 1000 / distinct / estimated | 81.965 → 84.501 | +2.14% | 170.268 → 173.067 | +2.43% | 31.832 → 31.777 |

The intended 1,000-row distinct merged case improves in all five pairs:
planning CPU has a −13.24% paired median (range −15.38% to −7.64%), and
composition has −13.02% (−15.35% to −7.71%). Its elapsed medians are
657.223 → 570.225 ms for planning and 722.323 → 639.760 ms for composition.
The 24-row distinct merged case also improves in all five pairs: −9.02% planning
CPU and −9.94% composition CPU. Its elapsed medians are 15.644 → 14.277 ms
and 17.436 → 16.159 ms, respectively.

Controls do not establish a universal improvement. In particular, the unmerged
100-row short case is slower in all five planning pairs (+3.23%, range +0.84%
to +6.73%). Estimated merged composition is also slower in all five pairs
(+2.43%, +0.63% to +4.92%), even though it does not use fragment reuse.
Small unmerged repeated planning has a +1.99% paired median with one +49.53%
pair; composition includes a +55.84% pair. All samples remain in the record.
Shared-host variation limits attribution and does not erase these observed costs.

The distinct fixture uses unique row identifiers and longer unique merged anchors
with recurring phrases. This establishes a benefit for that workload, not for
arbitrary wholly novel prose. Peak process RSS shows no meaningful general
reduction. The collector stays at 13.0–13.125 MiB before spawning; every child
peaks above it (22.91–36.18 MiB). An earlier collection was discarded because
whole-binary checksum reads inflated the parent and imposed an invalid small-case
memory floor; the corrected streaming collector is the source for all results above.

## Reproduction

Preserve baseline binaries at `d6aaefdd695db18502109cbed3030f1e82ba9473` before
changing sources. Build baseline and candidate with the same commands:

```sh
mkdir -p /tmp/table-shaping
swift build -c release --target RostrumLayout
swiftc -O -I .build/release/Modules \
  docs/benchmarks/2026-10-12-table-preparation.swift \
  .build/release/Rostrum.build/*.o .build/release/RostrumLayout.build/*.o \
  -o /tmp/table-shaping/baseline-unmerged
swiftc -O -I .build/release/Modules \
  docs/benchmarks/2026-10-12-table-spans.swift \
  .build/release/Rostrum.build/*.o .build/release/RostrumLayout.build/*.o \
  -o /tmp/table-shaping/baseline-spans
# Repeat with candidate sources, using candidate-unmerged and candidate-spans.
python3 docs/benchmarks/2026-10-13-table-shaping-preserve.py /tmp/table-shaping
python3 docs/benchmarks/2026-10-13-table-shaping-collect.py \
  /tmp/table-shaping /tmp/table-shaping.json
```

Use the pinned oracle environment for independent reopening. The preservation
checker requires a fresh artifact directory. To reproduce the profile, run the
profile-copy script from a clean baseline checkout, compile its copied Swift
sources as module `Rostrum` with `-O -g -whole-module-optimization -parse-as-library
-package-name rostrum`, and link each generated profile driver with that object
and baseline `RostrumLayout` objects. Run `1000 distinct measured 5 plan` and
`1000 repeated measured 5 plan`, retaining stderr JSONL separately from stdout.
