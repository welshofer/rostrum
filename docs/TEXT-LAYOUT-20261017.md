# Reuse resolved run metrics during line measurement

Rich-text layout resolves each source run's font while preparing its paragraph.
After wrapping, it remeasures complete line fragments so kerning across a line
break cannot distort the final advance. That step now uses the source run's
existing metrics instead of looking up the same family/style in the font library
again for every fragment.

Text atoms retain a one-based source-piece index, including empty pieces. Tabs
have separate geometry identifiers and are skipped before metric access. Native
paint fallback retries reset source indices before rebuilding atoms. The selected
metrics therefore remain attached to the original source run, independently of
span indices, tab gaps, line breaks or empty runs.

This introduces no cache, retained state or public API. Each operation still
resolves current fonts, content, theme and styles. Paragraph preparation's
existing immutable-operation contract and budgets are unchanged. Shaping,
wrapping, autofit selection, output-span construction, table pagination,
floating-point arithmetic and ordered diagnostics are unchanged.

## Investigation and scope

All 60 selected baseline typography/fitting tests passed, including the retained
native glyph, spacing, line-break, body-alignment and list-marker references.
There was no newly reproduced geometry discrepancy to justify a fidelity rule
change. The older TypographyOffice whole-image gate was not rerun: three of its
four hash-pinned faces are unavailable among the supplied uploads. Its historical
raster failures remain unresolved; they are not reclassified by this work.
The supplied Calibri files are valid different font versions and remain the
inputs for the user-approved review pack.

An isolated instrumented copy of Rostrum records nested process-CPU scopes.
On the 1,000-row distinct-text horizontal-merge workload, a plan executes 18,045
rich layouts and emits 30,448 lines. The baseline resolves a font again for each
of those 30,448 fragments, even though paragraph preparation already retained
its metrics. The lookup scope takes about 23 ms in that instrumented run. Plain
tables perform 7,045 such lookups; repeated labels perform far fewer because
existing table caches already remove most layouts.

Line emission and shaping remain larger costs, but an initial local-span
assembly experiment showed inconsistent gains and slower fitting controls. That
source rewrite was discarded. Its controlled Release results and patch remain
in the unshipped evidence below; they do not describe the implemented change.
The final comparison also pins both variants to the same allowed logical CPU
and batches short fitting cases to reduce cross-CPU and short-run variation.

Profile timers nest and add overhead; they do not isolate the net cost saved.
Do not sum their times or treat them as the uninstrumented comparison. The
implemented change removes only the redundant lookup; fragment reshaping and
all layout decisions still execute. The candidate profile records zero calls to
that lookup in these table cases; every other instrumented call count matches.

## Preservation

Baseline source is `91fcb55ceaca41c702a906d6ea7d9764c6343a69`. PPTX/SVG comparisons
are byte-for-byte; geometry and diagnostic JSON comparisons ignore object-key
order while retaining array order. The snapshot comparison is also byte-for-byte.

- All 264 files across 16 table controls retain identical geometry, ordered
  diagnostics and page boundaries, with exact PPTX/SVG bytes. Controls include
  plain cells, horizontal spans, connected row spans, repeated multi-row headers,
  measured/estimated sizing and mixed scripts. Independent python-pptx read-back
  checks native grids and available source-row records.
- Twenty retained native typography decks (42 slides) produce 104 identical
  saved-deck, SVG and ordered-diagnostic results. All PPTX/SVG bytes match; JSON
  comparison ignores object-key order and preserves array order (101 of 104 files
  are also byte-identical). Rendering does not mutate saved bytes, and reopening
  preserves them.
- All 1,248 detailed layout/shaping snapshots match byte for byte, including
  floating-point bit patterns, original source bytes, scalar positions, font
  scales, tabs, breaks, missing faces, mixed scripts and line limits.
- Five authored fitting cases retain identical saved decks and results. Four
  finish with all 100 shapes fitting; the unique long-text case retains its
  explicit readable-size refusal and zero fitting shapes. It is a refusal
  control, not a successful 100-shape fitting workload.
- All four user-approved Calibri packs retain exact deck/SVG bytes and identical
  geometry and diagnostics (84 files). Their timed `report.json` files are excluded
  from byte comparison. Proprietary faces and generated decks remain outside Git.

The new regression includes empty runs before visible text, distinct regular
and bold metrics, an alias, tabs, hard breaks and repeated width trials. It also
replaces a registered face between operations and verifies the new widths.
Existing independent native geometry assertions and tolerances are unchanged.
Optimized Linux/macOS CI and the local gate now also run native glyph-placement,
justification and tab tests.

## Release comparison

Both variants are freshly built with the same Swift 6.1.3 Linux Release compiler
arguments. The recorded arguments are compared for both Rostrum and
RostrumLayout. An initial timing run reused objects from a prior Release test
build; it was stopped and excluded because the compiler settings were not a
controlled match. The final comparison uses fresh normal Release builds only.

Seven alternating fresh-process pairs cover each table workload, with five
plan/compose operations per process. Trial zero is excluded from phase medians
and retained in raw data. A separate fitting comparison uses one excluded warmup
pair and seven alternating pairs of five fresh processes per variant/scenario.
Fitting summaries use the median of each five-process batch; all samples remain
in the raw record. Phase timings exclude font setup
and artifact generation; process CPU and peak RSS include setup and all trials.
The fitting process also includes its post-fit geometry verification. Process
elapsed includes launcher/subprocess and JSON-decoding overhead. Peak RSS comes
from a small native `wait4` launcher, outside the shipped Swift library.
No builds or tests run alongside the final measurements.

Negative paired changes mean lower time. All times below are milliseconds.

| Table workload | Plan CPU, baseline → candidate | Paired change | Compose CPU, baseline → candidate | Paired change |
|---|---:|---:|---:|---:|
| Plain, 24 distinct | 6.89 → 6.81 | +0.40% (3/7 lower) | 8.45 → 8.57 | -1.30% (4/7 lower) |
| Plain, 1000 distinct | 270.12 → 269.10 | +0.51% (3/7 lower) | 330.46 → 329.86 | -0.65% (4/7 lower) |
| Plain, 1000 repeated | 78.43 → 79.64 | +1.73% (2/7 lower) | 136.49 → 135.77 | -0.99% (5/7 lower) |
| Plain, 24 distinct (estimated) | 3.33 → 3.36 | -1.34% (5/7 lower) | 5.35 → 5.38 | -1.31% (4/7 lower) |
| Horizontal spans, 24 distinct | 18.52 → 18.41 | +0.63% (1/7 lower) | 20.50 → 19.59 | -5.98% (5/7 lower) |
| Horizontal spans, 1000 distinct | 695.57 → 689.40 | -1.15% (4/7 lower) | 763.86 → 757.07 | -1.17% (4/7 lower) |
| Row spans, 24 distinct | 13.88 → 13.68 | -5.47% (4/7 lower) | 16.36 → 15.87 | -9.43% (6/7 lower) |
| Row spans, 1000 distinct | 454.25 → 448.41 | -1.43% (5/7 lower) | 517.70 → 508.85 | -2.01% (4/7 lower) |
| Repeated headers, 24 distinct | 14.89 → 14.59 | -0.33% (4/7 lower) | 16.63 → 17.14 | +1.70% (3/7 lower) |
| Repeated headers, 1000 distinct | 453.98 → 457.82 | -3.09% (5/7 lower) | 518.18 → 515.29 | -0.35% (5/7 lower) |

| Table workload | Process CPU change | Process elapsed change | Peak RSS MiB, baseline → candidate |
|---|---:|---:|---:|
| Plain, 24 distinct | -2.08% | -2.14% | 23.45 → 23.24 |
| Plain, 1000 distinct | -0.79% | -0.78% | 33.83 → 33.62 |
| Plain, 1000 repeated | +1.07% | +1.06% | 31.20 → 31.05 |
| Plain, 24 distinct (estimated) | +0.23% | -0.16% | 23.42 → 23.28 |
| Horizontal spans, 24 distinct | -1.03% | -0.81% | 23.48 → 23.28 |
| Horizontal spans, 1000 distinct | -3.55% | -3.54% | 36.42 → 36.25 |
| Row spans, 24 distinct | -1.06% | -1.06% | 23.52 → 23.23 |
| Row spans, 1000 distinct | -2.50% | -2.50% | 33.78 → 33.49 |
| Repeated headers, 24 distinct | -2.41% | -2.17% | 23.42 → 23.24 |
| Repeated headers, 1000 distinct | -3.15% | -3.06% | 33.84 → 33.60 |

| Fitting control | Fit CPU, baseline → candidate | Paired CPU change | Paired elapsed change | Process CPU change | Peak RSS MiB, baseline → candidate |
|---|---:|---:|---:|---:|---:|
| plain-unique | 7.43 → 7.48 | +0.09% (3/7 lower) | +0.09% | -1.29% | 20.38 → 20.04 |
| plain-fallback-unique | 4.87 → 5.15 | +2.55% (0/7 lower) | +2.56% | -1.45% | 18.32 → 17.93 |
| mixed-unique | 54.68 → 50.73 | -6.82% (6/7 lower) | -6.84% | -5.23% | 20.45 → 20.14 |
| shrink | 3.89 → 4.05 | +1.54% (1/7 lower) | +1.55% | +0.55% | 20.39 → 20.03 |
| shrink-unique | 2.49 → 2.47 | -2.12% (6/7 lower) | -2.11% | -0.04% | 20.38 → 20.11 |

The paired percentage is the median of seven within-pair ratios, not the ratio
of the separately reported medians; those values can therefore move in different
directions. Small controls are sensitive to run variation. Large horizontal-span,
row-span and repeated-header process CPU improves by 2.50–3.55%, while their
phase results are smaller and not every pair improves. Distinct mixed-text
fitting improves 6.82% in six of seven paired batches. Already-fitting fallback
text is 2.55% slower in all seven batches, and the short shrink control is 1.54%
slower; the fallback path does not execute the changed fragment lookup. These
adverse controls remain in the record. No universal speedup is established.

Peak process RSS is about 0.1–0.4 MiB lower in these runs. This is a small
observation, not evidence of a general memory reduction; the implementation
adds no retained storage. All phase elapsed and whole-process CPU/elapsed/RSS
samples remain in the raw records below.

The unshipped span-assembly experiment used unpinned processes and one process
per fitting variant. It is separate evidence, not a paired comparison with the
final implementation.

## Reproduce

Build each revision before linking its drivers; do not reuse a preceding test
build's objects. Use the same toolchain and compiler options for both revisions.
From each revision, link the four table drivers listed in the
[composition report](TABLE-COMPOSITION-20261017.md#reproduction-and-evidence) as
`baseline{,-spans,-vertical,-headers}` or `candidate{,-spans,-vertical,-headers}`.
Also link `docs/benchmarks/2026-10-11-authored-fitting-driver.swift` as
`baseline-fitting` / `candidate-fitting`. The commands use:

```bash
swift build -c release --target RostrumLayout
swiftc -O -I .build/release/Modules DRIVER.swift \
  .build/release/Rostrum.build/*.o .build/release/RostrumLayout.build/*.o -o BINARY
```

Run with pinned portable oracles and an unused scratch artifact directory. For
the Linux comparison, pin every collector to the same allowed logical CPU
(`taskset -c 0` in this run). Omit `taskset` on platforms without it and record
that difference:

```bash
taskset -c 0 python3 docs/benchmarks/2026-10-17-text-layout.py /tmp/text-layout /tmp/text-layout/results.json
taskset -c 0 python3 docs/benchmarks/2026-10-17-text-layout-fitting.py /tmp/text-layout preserve
taskset -c 0 python3 docs/benchmarks/2026-10-17-text-layout-fitting.py /tmp/text-layout measure
```

The table collector also accepts `preserve` and `measure` modes to separate
artifact checks from the quiet timing window. Save the first mode's output as
`/tmp/text-layout/preservation.json`; the second verifies the binary hashes before
reusing its results. Retain all raw samples and adverse controls.

The diagnostic profile can be reproduced independently from each source revision:

```bash
python3 docs/benchmarks/2026-10-17-text-layout-profile.py /tmp/text-layout-profile
python3 docs/benchmarks/2026-10-17-text-layout-profile-rerun.py /tmp/text-layout-profile
```

The second command retains five quiet trials per case in `quiet-profile.json`.
Use the existing prepared-fitting snapshot driver for exact geometry/bit-pattern
comparison. The native-corpus driver takes a JSON array of fixture paths, an
unused output directory, and an optional private font manifest in the existing
conformance format; its input list is retained in the preservation record.

## Evidence and verification

Archived source hashes use explicit `path`/`sha256` records. This labels the
algorithm for secret scanners; measured values and digest values are unchanged
from the collectors' original source-hash maps.

- [Final paired table CPU, elapsed and RSS](benchmarks/2026-10-17-text-layout.json)
- [Final paired fitting CPU, elapsed and RSS](benchmarks/2026-10-17-text-layout-fitting.json)
- [Native corpus, snapshots, Calibri preservation and compiler arguments](benchmarks/2026-10-17-text-layout-preservation.json)
- [Nested profiles and call counts](benchmarks/2026-10-17-text-layout-profile.json)
- [Table collector](benchmarks/2026-10-17-text-layout.py), [fitting collector](benchmarks/2026-10-17-text-layout-fitting.py), [corpus driver](benchmarks/2026-10-17-text-layout-corpus.swift)
- [Unshipped span-assembly comparison](benchmarks/2026-10-17-text-layout-span-attempt.json)
- [Unshipped span-assembly patch](benchmarks/2026-10-17-text-layout-span-attempt.patch)

`bash scripts/verify.sh --fast` passed on Linux with Swift 6.1.3:

- 1,401 root package tests, 107 optimized layout/shaping tests and 357 LecternCore tests.
- Ten native-pack checks, 35 workflow checks (two Mac-only cases skipped),
  portable semantic/image probes and all 36 retained PowerPoint image comparisons.
- Runnable README examples saved and reopened successfully.

The existing Lab/inspection/export checks pass. This internal reuse adds no
public capability and requires no new Lab recipe. Linux `--fast` skips native
app builds and app-hosted execution; the macOS PR gate remains required for
package tests, both production app builds and test-host compilation before merge.

PowerPoint slide-view/PDF capture and paired Mac performance remain separate.
This is output-preserving performance work, not a claim of broader native
wrapping/autofit equivalence or a measured Mac/WebKit improvement.
