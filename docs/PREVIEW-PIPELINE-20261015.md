# Production preview pipeline measurements — 2026-10-15

The production pipeline now has opt-in stage measurements from font setup through
saved-deck SVG generation, plus a local Mac probe for the WebKit bitmap path.
The first measured optimization reuses accepted source-note page plans within
one table's preparation. On the fixed Linux template/table fixture, the median
paired whole-process CPU improvement is **2.30%** (six of seven pairs improve).
No native Mac speedup or general memory reduction is established.

## Method and retained evidence

Use the [profiler workflow](../Tools/preview-profile/README.md) to reproduce runs.
[Raw samples](benchmarks/2026-10-15-preview-pipeline.json) retain all CPU, elapsed,
peak RSS, stage records, outcomes, executable/input hashes and artifact-set hashes.
Both Release binaries include identical instrumentation; the baseline lacks only
the local accepted-note-plan cache. They are working-tree builds rooted at
`9557665`, not clean release revisions. Binary hashes identify the measured code.
Private inputs/fonts and full artifacts remain outside Git; their hashes remain
in the record. Source checkout identity is not proof of binary build provenance.

Six workloads ran one warmup and seven measured rounds per variant: 96 fresh
processes, alternating baseline/candidate order. Each inspection process performs
two operations, creating fresh presentations/registries. Composition runs once
per style. No concurrent builds/tests ran during collection. Input hashing and
warmups can warm filesystem caches. Swift 6.1.3 on Linux does not exercise
CoreText, CoreGraphics or WebKit.

The corpus includes a small control, a four-slide Calibri-embedded native table
pack, the user's 17-slide image-heavy deck, dense authored text from the existing
continuation fixture, the 28-row production table fixture with long sources, and
that fixture through the embedded-font synthetic template. The latter produces
14 slides. External fonts unavailable on Linux remain missing-font diagnostics;
this is not an exact-font native baseline for those cases.

Every sample has identical artifact hashes to its baseline: saved PPTX bytes,
SVGs, ordered preview/inspection diagnostics, extracted content and canonical
saved-content snapshots. Equal PPTX bytes include column widths, row heights and
page boundaries. Source decks/templates/replay inputs remain unchanged. These
checks do not establish PowerPoint visual acceptance.

## Observed costs and change

The initial stage trace isolated template source-note preparation as the largest
cost in the template fixture: 94 calls to the template planner. Six accepted
boundary plans were immediately requested again to construct the final pages.
The new cache retains only accepted plans for that one synchronous source block,
using exact UTF-8 paragraph keys. It admits at most 128 entries and 256 KiB of key
bytes; plan values are also bounded by that entry count. Rejections are not
cached. Cancellation is checked before lookup. The deck/fonts remain fixed
through this local operation; composition still performs its normal fresh
validation, and the next preparation starts empty.

On the paired runs, planner calls fall from 94 to 88. Source-note planning CPU
medians fall from 217.93 to 197.79 ms. Parent and child spans overlap; do not add
them. The table width search, source words and page-selection algorithm do not
change.

Whole-process medians below include generation/inspection, export/content checks,
startup and evidence writes. Inspection rows include **two operations per process**.
Positive paired change means less candidate CPU. The paired percentage is the
median of per-pair changes, not the ratio of the two independent medians.

| Workload | CPU baseline → candidate (ms) | Paired CPU improvement | Elapsed baseline → candidate (ms) | Peak RSS baseline → candidate (MiB) |
| --- | ---: | ---: | ---: | ---: |
| Small inspection | 39.01 → 39.22 | −1.46% | 43.90 → 45.08 | 26.32 → 25.84 |
| Embedded tables inspection | 259.74 → 263.22 | −1.00% | 270.12 → 273.29 | 42.70 → 42.46 |
| Image-heavy inspection | 618.27 → 603.94 | +2.34% | 671.08 → 649.29 | 101.07 → 100.61 |
| Dense authored generation | 109.14 → 108.48 | +0.61% | 114.21 → 113.27 | 27.81 → 27.51 |
| Authored tables | 287.33 → 278.83 | +1.73% | 295.57 → 285.55 | 29.84 → 29.61 |
| Template tables/source notes | 577.10 → 548.77 | +2.30% | 589.22 → 562.63 | 49.90 → 49.68 |

Only the last workload exercises the new reuse. Other changes, including apparent
improvements, are controls/variation rather than evidence of a benefit there.
The small and embedded-table controls have paired slowdowns. Process RSS is a
lifetime high-water mark with allocator variation; the retained cache does not
justify a general memory-reduction claim.

## Native boundary and next measurement

Core tracing separates package reads/parsing, embedded fonts, declared-family
discovery, installed registration, template/table/authored planning, composition,
validation, save/reopen and each SVG. The native probe separates queue wait,
WebKit navigation, font readiness and bitmap snapshot. Outcomes distinguish
cache hits, failures and successful rendering. Task-local bindings prevent one
operation's trace leaking into another; storage is bounded and dropped records
are explicit.

The Mac probe is implemented but **not run in this Linux environment**. Native
app-hosted tests are likewise pending. It measures first bitmap availability;
first visible display frame, lazy-grid scheduling and WebKit helper-process
CPU/memory require a production-app Instruments capture. App process peak RSS
includes test-host startup and excludes helpers. PowerPoint slide view and PDF
export acceptance remain separate from all of these measurements.

The next optimization decision should use the native Mac profile with the exact
intended fonts. Remaining portable costs are authored pagination, template
source-note planning and package opening/SVG generation; Linux timing does not
establish which dominates the Mac result screen.

Validation on the final implementation: `scripts/verify.sh --fast` passed with
1,363 Rostrum tests, 339 LecternCore tests, 63 optimized layout tests, nine native
pack checks, 12 Python fidelity tests, 36 portable reference cases and README
examples. The workflow suite passed 22 checks and skipped two requiring XcodeGen.
This includes traced/untraced output equality, task isolation, bounded storage,
failure reporting and fresh source-note decisions after font/content changes.
App-hosted tests and the native Mac bitmap probe remain unrun.
