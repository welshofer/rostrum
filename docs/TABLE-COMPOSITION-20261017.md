# Template-table composition: resolve repeated styles once

`composeTablePages` now resolves the common layout/object-slot style once after
fresh pagination, then uses that immutable value for each native table and
caption. The value lives only within that composition call. Single-slide
composition retains its normal style resolution. Font selection, native styles,
search budgets, text measurement and page partitioning are unchanged.

Every composition still replans with current fonts, content and template styles,
compares the accepted page geometry and prepares every page before insertion.
Title measurement and table-slot validation remain per-page. A new save/reopen
regression changes the theme's font identity between two compositions of the
same plan and verifies that every new cell and caption uses the current font,
while previously written slides retain their explicit font identity.

## Reproduce before attributing a regression

The preceding header feature report observed 4–5% slower composition on two
controls. Ten new alternating pairs using the exact retained binaries did not
reproduce those magnitudes consistently. Median paired composition CPU changed
by -3.17% on 24 distinct rows, +1.07% on 1,000 distinct rows and +1.78% on 1,000
repeated rows. Whole-process CPU changed by -2.96%, approximately 0.00% and
+2.67%, respectively. All samples are retained; this does not establish that the
header feature caused the earlier slowdown or that this change reverses it.

## Profile the composition operation

A separate instrumented copy of baseline `097733b` records nested process-CPU
timers. It leaves production sources untouched. On a 1,000-row, 167-page table,
composition resolves the same object style 337 times: three during replanning,
167 during page preparation and 167 while writing captions. Style resolution
takes approximately 27 ms, including palette and typography resolution.

The fresh replan is the largest phase: approximately 254 ms with distinct labels
and 78 ms with repeated labels. Page preparation takes 26–28 ms, slide/table
writing about 38 ms and caption creation about 21 ms. These timers overlap:
style resolution occurs inside several phases. They must not be summed, and
instrumented timings are not the reported speedup comparison.

The optimization removes the repeated style work. It deliberately retains the
fresh replan and the per-page title checks identified above.

## Release comparison

Baseline: `097733b90d0cad61d8246ce5ffe2dbf58d6250b3`. Candidate source and binary
hashes accompany the raw evidence. Both builds use Swift 6.1.3 Release on Linux
x86_64. Builds/tests are idle during the measurements.

Sixteen controls cover plain tables, horizontal spans, connected vertical spans
and multi-row headers, with measured/estimated columns and mixed-script text.
All 264 retained artifacts match: geometry and ordered diagnostic arrays are
identical, and PPTX/SVG bytes are exact. Independent python-pptx read-back checks
native spans, widths, heights and source rows where the driver retains them.

Seven alternating fresh-process pairs per workload record planning and
composition CPU/elapsed time plus whole-process CPU/elapsed/peak RSS. Each process
performs five operations; trial zero is excluded from phase medians and retained
in raw data. Whole-process measurements include setup and all five operations.
They exclude saving/rendering, which the separate preservation runs exercise.
The collector's elapsed interval includes launcher/subprocess overhead and JSON
result decoding; child process CPU and peak RSS come from `wait4`.
The small native `wait4` launcher avoids inheriting the Python collector's peak
RSS. It is benchmark tooling only; the shipped library remains pure Swift.

Composition CPU improves by 6.99% and 9.72% on the distinct-text plain controls,
and 19.93% on the repeated-text control. Whole-process CPU improves by 3.16%,
4.39% and 12.92%, respectively. These are separate scopes, not additive gains.
All seven composition pairs improve on both large plain controls; six of seven
improve on the 24-row control. Other workloads are mixed: small horizontal spans
retain a +0.43% process-CPU change and large
vertical spans +0.13%. Planning is a control; its paired CPU medians vary from
-2.35% to +3.01% despite no planning algorithm change. Peak RSS is essentially
unchanged. No general or native Mac speedup is claimed.

Cells show baseline → candidate medians; parentheses give the median paired
percentage change, which can differ from the ratio of aggregate medians.

| Workload | Plan CPU ms | Plan elapsed ms | Compose CPU ms | Compose elapsed ms | Process CPU ms | Process elapsed ms | Peak RSS MiB |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Plain, 24, distinct | 7.20 → 7.19 (-0.53%) | 7.21 → 7.21 (-0.29%) | 9.19 → 8.36 (-9.72%) | 9.18 → 8.43 (-8.98%) | 111.67 → 106.12 (-4.39%) | 113.16 → 107.80 (-2.58%) | 23.29 → 23.29 |
| Plain, 1000, distinct | 272.14 → 269.19 (+0.10%) | 272.22 → 269.46 (+0.01%) | 354.75 → 326.03 (-6.99%) | 355.09 → 326.12 (-7.02%) | 3218.35 → 3116.60 (-3.16%) | 3221.02 → 3121.59 (-3.09%) | 33.66 → 33.59 |
| Plain, 1000, repeated | 78.50 → 76.86 (-1.11%) | 78.50 → 76.86 (-1.09%) | 164.07 → 133.02 (-19.93%) | 164.07 → 133.04 (-19.88%) | 1309.13 → 1167.34 (-12.92%) | 1312.19 → 1169.82 (-12.89%) | 31.02 → 31.05 |
| Plain, 24, distinct (estimated) | 3.34 → 3.33 (-1.60%) | 3.34 → 3.33 (-6.06%) | 6.33 → 5.30 (-17.74%) | 6.33 → 5.30 (-17.65%) | 76.35 → 72.69 (-4.58%) | 78.59 → 75.01 (-4.79%) | 23.24 → 23.24 |
| Horizontal, 24, distinct | 18.70 → 18.32 (-0.07%) | 18.70 → 18.31 (-0.09%) | 20.78 → 20.32 (-3.00%) | 20.78 → 20.32 (-3.00%) | 227.48 → 227.59 (+0.43%) | 229.03 → 229.33 (+0.28%) | 23.26 → 23.28 |
| Horizontal, 1000, distinct | 688.72 → 694.06 (-1.66%) | 688.80 → 694.18 (-1.59%) | 775.73 → 760.74 (-1.93%) | 776.78 → 760.73 (-2.07%) | 7497.57 → 7377.56 (-1.39%) | 7502.76 → 7380.22 (-1.33%) | 36.25 → 36.23 |
| Vertical, 24, distinct | 13.20 → 13.00 (-1.79%) | 13.20 → 13.00 (-1.79%) | 15.34 → 14.57 (-5.49%) | 15.34 → 14.58 (-5.21%) | 172.63 → 169.51 (-3.19%) | 174.43 → 171.00 (-3.00%) | 23.22 → 23.20 |
| Vertical, 1000, distinct | 451.01 → 462.56 (+3.01%) | 451.01 → 462.65 (+3.06%) | 540.66 → 513.79 (-4.14%) | 541.21 → 513.81 (-4.07%) | 5085.96 → 4998.91 (+0.13%) | 5088.49 → 5001.73 (+0.14%) | 33.50 → 33.55 |
| Two-row header, 24, distinct | 14.55 → 14.21 (-2.35%) | 14.55 → 14.21 (-2.35%) | 16.78 → 16.41 (-1.96%) | 16.78 → 16.40 (-1.99%) | 190.16 → 184.43 (-2.02%) | 192.00 → 186.10 (-1.98%) | 23.24 → 23.20 |
| Two-row header, 1000, distinct | 441.74 → 449.04 (+1.01%) | 441.74 → 449.50 (+1.41%) | 534.35 → 511.15 (-4.35%) | 534.41 → 511.16 (-4.35%) | 5026.55 → 4937.82 (-1.77%) | 5029.25 → 4940.39 (-1.77%) | 33.62 → 33.62 |

The small header case improves in only four of seven composition pairs; its
1.96% median reduction is weak evidence compared with the plain controls.
A separate one-page supplement uses the same binaries and seven pairs for each
sizing policy. It retains adverse startup-dominated process results:

| One-page control | Compose CPU ms | Compose elapsed ms | Process CPU ms | Process elapsed ms | Peak RSS MiB |
| --- | ---: | ---: | ---: | ---: | ---: |
| measured | 2.98 → 2.77 (-9.07%) | 2.97 → 2.79 (-9.17%) | 54.37 → 53.55 (+1.68%) | 56.15 → 55.11 (+1.78%) | 23.29 → 23.28 |
| estimated | 1.66 → 1.66 (-2.23%) | 1.66 → 1.66 (-2.24%) | 39.55 → 38.64 (+0.44%) | 41.02 → 39.99 (-1.23%) | 23.29 → 23.27 |

The one-page measured/estimated median paired process-CPU changes are +1.68%/+0.44%;
only two/three of seven process pairs improve. The estimated composition result
also improves in only four pairs. These controls do not establish a general
startup or single-slide improvement. All samples remain in the evidence.

## Reproduction and evidence

Build the baseline and candidate outside measured runs. At each source revision,
run `swift build -c release --target RostrumLayout`, then link each existing Swift
driver with `swiftc -O -I .build/release/Modules DRIVER.swift
.build/release/Rostrum.build/*.o .build/release/RostrumLayout.build/*.o -o BINARY`.
The names expected by the collector are:

| Binary suffix | Driver under `docs/benchmarks/` |
| --- | --- |
| none | `2026-10-12-table-preparation.swift` |
| `-spans` | `2026-10-12-table-spans.swift` |
| `-vertical` | `2026-10-16-table-row-pagination.swift` |
| `-headers` | `2026-10-16-repeated-headers.swift` |

Keep the eight `baseline*` / `candidate*` binaries in a scratch directory, with
the pinned Python oracles installed. The collector creates a new `preservation/`
directory beneath that directory:

```bash
python3 docs/benchmarks/2026-10-17-table-composition.py /tmp/composition /tmp/composition/results.json
python3 docs/benchmarks/2026-10-17-table-composition-single-page.py /tmp/composition /tmp/composition/single-page.json
```

The separate profiling script copies and instruments the current layout module,
links it with the built Release Rostrum objects and retains three operations per
case. Its JSON labels the checkout commit separately from source hashes because
a candidate can be measured before committing. CPU timers nest and perturb the
run. In the candidate, object-style calls fall from 337 to **4**, about 0.4 ms;
title/context/prepare/write call counts remain unchanged.

```bash
python3 docs/benchmarks/2026-10-17-table-composition-profile.py /tmp/composition-profile
```

- [Main comparison and preservation](benchmarks/2026-10-17-table-composition.json)
- [One-page controls](benchmarks/2026-10-17-table-composition-single-page.json)
- [Historical slowdown reproduction](benchmarks/2026-10-17-table-composition-reproduction.json)
- [Nested profiles, exact source and executable identities](benchmarks/2026-10-17-table-composition-profile.json)
- [Exact Calibri deck hashes](benchmarks/2026-10-17-table-composition-calibri.json)

All four user-approved Calibri decks and both new repeated-header review decks
regenerate byte-for-byte unchanged. The latter still await their own native
PowerPoint visual review; this performance change adds no new layout behavior.
Fonts and generated review decks remain outside Git.

## Verification

The 24 focused layout tests pass, including changed theme-font identity between
composition calls, stale geometry refusal, connected merges and multi-row
headers. `scripts/verify.sh --fast` passes: 1,400 library tests, 81 optimized
tests, 357 LecternCore tests, 35 offline workflow tests, ten native-pack checks,
portable fidelity references and runnable README examples. Apple CI remains a
required pre-merge check.
Native app-hosted execution and Mac performance remain separate from these
Linux comparisons and CI app builds.
