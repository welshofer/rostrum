# Prepared text fitting — October 12, 2026

Template and authored autofit now prepare scale-independent paragraph input once
per body that needs shrinking. Trials reuse inherited styles, font selection,
paragraph properties, Unicode clusters, bidi levels and break opportunities.
They still calculate scaled advances, kerning, glyph substitutions, paint policy,
wrapping, line geometry and diagnostics at every tested size. Arabic shaping
retains its existing dedicated path. Public APIs and fitting policies are unchanged.

Scratch state is discarded after fitting. Paragraph retention is capped at 64
entries, 512 pieces and 64 KiB of combined raw/resolved text. Unicode retention is
capped at 64 inputs and 64 KiB of source text. These are input limits, not a total
allocation budget. Oversized input is recomputed. Exact UTF-8 equality prevents
canonically equivalent strings from sharing incorrect source scalar offsets.

## Measured result

The [raw record](benchmarks/2026-10-12-prepared-fitting.json) compares complete
Release builds against `64234fd1a4e851c819e9125f855b5877e5a4a5e6`, the template
rich-text fitting change in PR #50. It includes source, binary, driver and font
hashes, all samples, output hashes and reopen checks. Swift 6.1.3 ran on one Linux
host with two warmup pairs and fifteen alternating AB/BA measured pairs per
scenario. No Swift builds or tests ran during measurement. CPU and elapsed time
cover fitting only; loading fonts, serialization and verification are outside
the timer. RSS covers the entire process, including that verification.

| Workload | Baseline → prepared median CPU, ms | Median paired CPU reduction | Faster pairs |
| --- | ---: | ---: | ---: |
| Template plans, repeated text (40) | 37.627 → 37.414 | 0.21% | 8/15 |
| Template plans, distinct text (40) | 38.783 → 38.206 | 1.07% | 8/15 |
| Template shrinking, repeated text (40) | 70.450 → 57.229 | 18.08% | 14/15 |
| Template shrinking, distinct text (40) | 85.900 → 72.042 | 16.02% | 15/15 |
| Template tabs/breaks (40) | 2.579 → 2.632 | −1.87% | 6/15 |
| Authored fallback, repeated text (100 shapes) | 1.064 → 1.054 | 2.91% | 8/15 |
| Authored registered font, repeated text (100) | 1.062 → 1.071 | −1.82% | 6/15 |
| Authored mixed sizes, repeated text (100) | 1.588 → 1.696 | −0.54% | 6/15 |
| Authored shrinking, repeated text (100) | 2.623 → 2.459 | 5.44% | 10/15 |
| Authored fallback, distinct text (100) | 2.817 → 2.753 | 2.30% | 9/15 |
| Authored registered font, distinct text (100) | 3.848 → 3.922 | 5.46% | 9/15 |
| Authored mixed sizes, distinct text (100) | 42.972 → 35.759 | 18.17% | 15/15 |
| Authored rejection, distinct shrinking text | 2.338 → 2.277 | 1.46% | 9/15 |

The last control rejects the first unfit body in both builds; it does not measure
100 completed fits. The authored fitter's existing repeated-body result cache
already avoids most repeated work. Small controls move both ways, and the ratio
of medians can disagree with the median paired change; no gain is claimed there.
The useful result is lower CPU for the three sustained shrinking workloads.
These measurements do not establish end-to-end composition or device latency.

Template median peak RSS increases by 172–216 KiB (about 22.6 → 22.8 MiB total).
Authored changes range from −60 to +144 KiB. These whole-process measurements do
not isolate scratch allocation. Shared-host timings are observations, not budgets.

## Preservation

All thirteen scenarios have identical decisions, reported fit counts/errors and
saved PPTX bytes between builds: 26 files pass ZIP CRC and python-pptx reopen.
Every template sample also preserves its source document bytes. An independent
build of the baseline Rostrum sources produces exactly the same 1,248 snapshots
as the candidate: 672 layouts and 576 shaped runs, including floating-point bits,
source ranges, styles, glyph order and ordered diagnostics. The snapshot SHA-256
and [driver](benchmarks/2026-10-12-prepared-fitting-snapshot.swift) are retained.

Differential tests exercise retained versus uncached input across sizes, widths,
shape/table contexts, line limits, mixed fonts, malformed attributes, bullets,
tabs, fields, empty paragraphs, Unicode and scratch limits. Additional controls
cover shared XML nodes and canonically equivalent text. The Release comparison
also exposed aliasing when replacing a glyph range with its own lazy reversed
slice; explicit in-place swaps preserve every original glyph. Source-position
regressions now run in Release in the local gate and Linux/macOS CI. The existing
facade-allocation test shares its counter's Debug guard so Release tests compile.

The existing Templates and Fonts/Fitting Library Lab recipes pass all 52 checks
across both variants, including save/reopen, inspector previews and export. All
24 saved-deck/SVG artifacts are byte-identical to the prior runs; artifact hashes
are retained in the raw record. Native PowerPoint acceptance of PR #50's new computed specimens
remains separate and unverified; byte preservation adds no new Office support
claim. The existing saved PowerPoint reference gate remains independent.

The local `scripts/verify.sh --fast` gate passes: 1,287 root tests, 13 optimized
preparation/shaping tests, 309 LecternCore tests, 36 saved PowerPoint reference
comparisons, portable semantic/image checks and README examples. macOS/iOS app
builds run in PR CI; app-hosted tests and live PowerPoint are not run on Linux.

## Reproduction

Use two separate checkouts: baseline `64234fd` and this change. With the same
Swift 6.1.3 toolchain, build `RostrumLayout` in Release in each checkout. Copy the
unchanged [template driver](benchmarks/2026-10-11-template-fitting-driver.swift)
and [authored driver](benchmarks/2026-10-11-authored-fitting-driver.swift) into a
scratch directory as `template.swift` and `authored.swift`.

Compile each driver with `swiftc -O -package-name rostrum`, the respective build's
`-I .build/release/Modules`, and all object files in `Rostrum.build` and
`RostrumLayout.build`. Name the four executables `template-baseline`,
`template-candidate`, `authored-baseline`, and `authored-candidate` in that scratch
directory. Do not define `LEGACY`: both comparators use their complete builds.

From the candidate repository root, with builds and tests idle, run
`python3 docs/benchmarks/2026-10-12-prepared-fitting.py SCRATCH_DIRECTORY`.
The Linux runner writes `paired-final.json` and byte-compared proof decks.
Compile the snapshot driver against each build's Rostrum objects and pass an
output JSON path to each executable; compare the two files byte for byte.
The saved record adds the independent snapshot hashes and external reopen checks
to the runner's timing output.
