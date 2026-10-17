# Table measurement overhead

This follow-up profiles small-table cost after rotated-cell measurement landed in
`6bd5ca166aaf3c9c31547faf257a3e63bb9aa186`. Existing library and Lectern callers
receive the change when rebuilt; there is no new API or font policy.

## Profile and change

A 24-row plain measured table resolves 75 visible source cells, evaluates 18
width candidates, and performs 525 cell-input and measurement-cache lookups.
Its pagination-style envelope previously serialized effective text styles 291
times, including repeated visits to the same immutable region style. The
horizontal-span control similarly serialized styles 258 times for 66 anchors.
Diagnostic CPU timers identify style serialization and measurement-key lookup as
repeatable work outside text layout. Timers nest and perturb short operations;
their measurements describe work distribution, not a speedup.

The fitting session now keeps exact serialized bytes beside each resolved style.
Both the XML nodes and bytes count against its existing 256 KiB retention budget
and 64-entry cap. Oversized styles resolve without caching. The cell input key
hashes its immutable body/style bytes, insets and direction once, then reuses that
fingerprint across width trials. Full byte and geometry equality still guards
against hash collisions and Unicode canonical-equivalence aliases.

All caches expire with the operation. Changed source XML, native styles, themes,
registered faces and directions are observed on the next call. Composition still
performs its fresh preflight. Wrapping, column search, row-height arithmetic,
page partitioning, issue order and serialization rules are unchanged.

The earlier roughly 7% small-table result is not a stable constant. A separate
quiet nine-pair recheck of the pre/post-rotation binaries, with 40 operations per
process, observed median planning overhead of 2.33% for plain and 2.78% for
horizontal-span tables. Samples varied substantially in both directions. The
optimization below targets demonstrated repeated work rather than assigning all
of that timing variance to the rotation feature.

## Preservation and validation

All **264 horizontal** and **124 rotated** control artifacts match: column
widths, row heights, page boundaries, source text and ordered diagnostics are
unchanged, with byte-identical PPTX and SVG output. Independent python-pptx
readback checks native grids, source content, merges and directions.

All **1,248 detailed layout/shaping snapshots** match, including floating-point
bits and the emergency-word-break flag. All **84 prior Calibri artifacts** also
match (the report containing timings is excluded). The **two accepted rotated
PPTX files and ten SVGs** are byte-identical to the delivered review pack.
[Preservation records](benchmarks/2026-10-17-table-measurement-preservation.json)
retain exact hashes. No proprietary font bytes or generated review decks are
committed.

The full local `scripts/verify.sh --fast` gate passed: **1,411 root tests,
116 optimized text/layout tests, 357 LecternCore tests**, ten native-pack portable
checks, 35 offline workflow checks (two Mac-only skips), the portable fidelity
references and runnable README examples. The regression coverage checks every
built-in table style/flag combination, an oversized serialized style that exceeds
the retention budget, and fresh style/theme/font/content/direction changes.

Required Linux and Apple PR checks must pass before merge. The Apple gate covers
package tests, production macOS/iOS builds and isolated native test-host
compilation; app-hosted test execution and live PowerPoint checks remain separate.

The delivered rotated-table pack has [user-reported visual acceptance](TABLE-ROTATED-TEXT-20261017.md#lectern-and-native-review).
That record identifies exact deck hashes and does not infer separate app-version,
slide-view or PDF-export checks. Byte-identical output here preserves those
artifacts; portable tests do not establish new native visual coverage.

## Release comparison

Linux x86_64, Swift 6.1.3, identical normal Release compiler arguments. The
baseline is merged PR #82, verified by source and binary digests; the candidate
changes only style-byte and key-hash reuse in the runtime. See
[provenance](benchmarks/2026-10-17-table-measurement-provenance.json),
[diagnostic profiles](benchmarks/2026-10-17-table-measurement-profile.json),
[horizontal samples](benchmarks/2026-10-17-table-measurement-results.json), and
[rotated samples](benchmarks/2026-10-17-table-measurement-rotated.json).

Seven alternating fresh-process pairs per workload, pinned to one logical CPU,
with no concurrent builds/tests. Each process performs five plan/compose trials;
phase medians exclude trial zero. Process CPU, elapsed and peak RSS include setup
and all five trials. The native `wait4` launcher measures child CPU and peak RSS
without inheriting the Python collector's memory. Planning/composition timings
exclude saved-output checks and SVG rendering. Composition retains fresh preflight.

The small plain case has **7.98% lower planning CPU** and **3.01% lower process
CPU**. Large plain/repeated-text cases have **7.07%/19.33% lower process CPU**.
Large column-span and measured rotated tables are close to unchanged
(**0.53%/0.20% lower process CPU**). Every case's median paired process-CPU change
is negative, but individual pairs can be slower. These are observed Linux results,
not a native Mac or universal speedup claim. Peak RSS differences are small;
rotated estimated cases can use slightly more memory.

A separate [seven-pair long-run comparison](benchmarks/2026-10-17-table-measurement-pilot.json)
uses 30 operations per process for small plain/span/rotated tables. Plain
planning/composition CPU improves 8.32%/8.57% (all seven pairs), while column-span
phases improve 2.35%/2.54%; rotated planning is roughly unchanged. This supports
the direction of the small-table gain without treating any one percentage as fixed.
The [pre/post-rotation recheck](benchmarks/2026-10-17-table-measurement-rotation-recheck.json)
is the separate nine-pair historical comparison described above.

Table cells show baseline → candidate medians, followed by the median **paired**
percentage change. That percentage can differ from the ratio of the displayed
aggregate medians. Peak RSS is shown in MiB. All workloads are retained below.

| Workload | Plan CPU ms | Plan elapsed ms | Compose CPU ms | Compose elapsed ms | Process CPU ms | Process elapsed ms | Peak RSS MiB |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Plain, 24, distinct, measured | 7.27 → 6.75 (-7.98%) | 7.27 → 6.75 (-7.98%) | 9.26 → 8.57 (-3.33%) | 9.26 → 8.57 (-3.33%) | 114.59 → 111.14 (-3.01%) | 116.49 → 112.95 (-3.10%) | 23.47 → 23.26 |
| Plain, 1000, distinct, measured | 288.04 → 260.57 (-11.17%) | 288.53 → 260.57 (-10.37%) | 353.85 → 322.28 (-6.48%) | 353.84 → 322.28 (-6.48%) | 3329.90 → 3031.85 (-7.07%) | 3331.75 → 3034.51 (-6.93%) | 33.84 → 33.24 |
| Plain, 1000, repeated, measured | 79.50 → 57.54 (-29.19%) | 79.50 → 57.54 (-29.20%) | 138.76 → 119.68 (-14.62%) | 138.76 → 119.68 (-14.62%) | 1223.85 → 986.49 (-19.33%) | 1226.85 → 988.89 (-19.30%) | 31.25 → 30.88 |
| Plain, 24, distinct, estimated | 3.67 → 3.26 (-14.93%) | 3.68 → 3.26 (-14.94%) | 5.76 → 5.17 (-9.89%) | 5.76 → 5.17 (-9.89%) | 74.28 → 70.50 (-4.06%) | 76.70 → 72.03 (-3.67%) | 23.46 → 23.24 |
| Column spans, 24, distinct, measured | 19.16 → 18.42 (-5.27%) | 19.16 → 18.42 (-5.27%) | 21.31 → 20.75 (-5.48%) | 21.30 → 20.74 (-5.39%) | 234.59 → 227.09 (-3.47%) | 236.79 → 228.87 (-3.20%) | 23.43 → 23.27 |
| Column spans, 1000, distinct, measured | 743.44 → 719.28 (-1.77%) | 743.44 → 719.28 (-1.77%) | 810.80 → 808.85 (-0.61%) | 811.18 → 808.85 (-0.61%) | 7898.40 → 7856.29 (-0.53%) | 7902.33 → 7858.17 (-0.56%) | 36.50 → 35.89 |
| Row spans, 24, distinct, measured | 13.98 → 13.56 (-3.50%) | 13.98 → 13.55 (-3.53%) | 15.28 → 14.55 (-5.07%) | 15.28 → 14.55 (-5.07%) | 178.57 → 176.05 (-2.47%) | 181.10 → 178.04 (-3.37%) | 23.46 → 23.30 |
| Row spans, 1000, distinct, measured | 484.89 → 464.09 (-4.13%) | 484.89 → 468.54 (-4.13%) | 541.82 → 528.41 (-1.86%) | 541.82 → 528.41 (-1.86%) | 5460.32 → 5087.43 (-5.89%) | 5462.21 → 5089.37 (-5.77%) | 33.79 → 33.27 |
| Repeated headers, 24, distinct, measured | 17.22 → 15.06 (-12.58%) | 17.22 → 15.05 (-12.58%) | 18.02 → 16.99 (-5.29%) | 18.02 → 16.99 (-5.30%) | 214.78 → 194.15 (-8.23%) | 217.77 → 196.94 (-8.27%) | 23.43 → 23.31 |
| Repeated headers, 1000, distinct, measured | 495.64 → 464.65 (-8.43%) | 495.72 → 464.67 (-8.44%) | 546.71 → 542.26 (-4.02%) | 546.71 → 542.26 (-4.02%) | 5331.41 → 5321.45 (-5.77%) | 5335.09 → 5324.25 (-5.79%) | 33.77 → 33.30 |

### Rotated controls

| Workload | Plan CPU ms | Plan elapsed ms | Compose CPU ms | Compose elapsed ms | Process CPU ms | Process elapsed ms | Peak RSS MiB |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Rotated, 24, estimated | 4.84 → 4.22 (-13.88%) | 4.84 → 4.22 (-13.80%) | 6.82 → 6.85 (-4.13%) | 6.81 → 6.85 (-4.13%) | 87.36 → 82.94 (-5.05%) | 89.13 → 84.49 (-5.20%) | 23.36 → 23.43 |
| Rotated, 24, measured | 28.85 → 28.03 (-3.18%) | 28.85 → 28.03 (-3.18%) | 30.99 → 30.11 (-3.41%) | 30.98 → 30.13 (-3.41%) | 329.17 → 324.48 (-1.34%) | 331.16 → 326.91 (-1.39%) | 23.43 → 23.44 |
| Rotated, 1000, estimated | 134.26 → 121.82 (-7.83%) | 134.25 → 121.82 (-7.87%) | 233.27 → 219.12 (-4.93%) | 233.28 → 219.12 (-4.93%) | 1962.20 → 1832.50 (-5.64%) | 1964.62 → 1835.18 (-5.63%) | 33.16 → 33.22 |
| Rotated, 1000, measured | 995.74 → 1003.46 (-0.72%) | 995.76 → 1003.48 (-0.72%) | 1061.17 → 1044.70 (-0.55%) | 1061.19 → 1044.73 (-0.55%) | 10492.07 → 10465.16 (-0.20%) | 10494.44 → 10467.85 (-0.19%) | 33.87 → 33.51 |


## Reproduction

Build the baseline and candidate with the same normal Release compiler arguments
and toolchain. Keep their binaries before switching sources or running optimized
tests (which build with testability enabled). Use the four existing horizontal
drivers and the rotated driver listed in the
[previous comparison](TABLE-ROTATED-TEXT-20261017.md#reproduce-caller-font-decks-and-measurements).
In a fresh scratch directory name the binaries `baseline`, `baseline-spans`,
`baseline-vertical`, `baseline-headers`, `baseline-rotated` and the corresponding
`candidate` names. These benchmark-only drivers and Python oracles are not
library dependencies.

```sh
python3 docs/benchmarks/2026-10-17-table-measurement-collect.py SCRATCH SCRATCH/results.json
python3 docs/benchmarks/2026-10-17-table-measurement-rotated.py SCRATCH SCRATCH/rotated-results.json
```

The first collector builds the native `wait4` launcher before measuring; the
second reuses it. Both require the pinned conformance Python environment. Run
without concurrent builds/tests. The profile helper copies and instruments only
a scratch layout module, using the matching Release Rostrum objects. Its raw
results are separate from normal-build timing results.

To run the focused regression checks after pulling:

```sh
swift test --filter 'TableCellFittingProjectionTests|TableCellPreparationTests|RotatedTableLayoutTests'
```
