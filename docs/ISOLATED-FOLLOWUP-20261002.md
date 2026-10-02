# Isolated performance and fidelity follow-up — 2026-10-02

This work is local on `codex/isolated-performance-20261002`, based on
`2783ea38616cfd7c30ad2358c1056b9dc3f19481`. The original checkout and its active
task remain the integration owner. No merge, push, publication, PowerPoint
interaction, or original-checkout changes were performed by this follow-up.

## Implemented changes

- `a36d07d82fc77cf6584720448685dee622b75f62`: reuse serialized SVG text style
  attributes within a render. The cache is bounded to 128 entries and 65,536
  accounted bytes, resets between renders, and preserves exact UTF-8 names.
  Font resolution and diagnostics still run for every shape. Text, positions,
  and layout are not cached. A fast path skips character-by-character escaping
  when no XML metacharacters exist. Four tests cover escaping, style changes,
  byte preservation, cache bounds, reset, and diagnostic retention.
- `a589fb48d83ab805030bca634a3e7eb11874b5d9`: Lectern's generated-deck and
  inspected-deck previews retain per-slide fidelity issues, inheritance flags,
  and render failures. A disclosure displays these separately from generation
  warnings. Contact sheets retain original deck numbering when previews are
  missing. Six new core tests pass; two app-hosted numbering tests compile.
- `9478ea9a6a5f3182dc96081d90b4dfcbdc9e2bce`: retain a fixture-specific rasterizer
  diagnostic and standalone fractional-stroke SVG. This is investigative
  tooling, with no production geometry changes or acceptance changes.

Lectern's existing local Rostrum package dependency automatically includes the
renderer optimization when these commits are integrated. The new UI exposes
known limitations; an empty diagnostic report is not visual certification.

## Performance evidence

The [paired report](benchmarks/2026-10-02-render-paired.json) compares separately
compiled release binaries at the exact base and candidate revisions on this
MacBook Pro. Both use the same driver, no registered fonts, two rounds in AB/BA
order, and 22 measured warm renders per variant after excluding first renders.
Builds and profiling were stopped before the final run.

| Warm render | Base median | Candidate median | Change |
| --- | ---: | ---: | ---: |
| 10,000 cells, banded | 193.238 ms | 162.185 ms | 16.07% faster |
| 10,000 cells, grid | 169.998 ms | 140.519 ms | 17.34% faster |
| 250 unique images | 1.818 ms | 1.867 ms | 2.68% slower; +0.049 ms |
| 250 repeated images | 1.658 ms | 1.678 ms | 1.24% slower; +0.021 ms |

All four scenarios have byte-identical SVG, ordered fidelity issues, and
inheritance flags. Image sample ranges overlap; no image speedup is established.
The small image changes are retained rather than interpreted as a reliable
regression or improvement from this run alone.

The existing fresh-process driver also ran all 12 scenarios with one warmup,
five measured samples, pinned Arial, and independent python-pptx reopening and
table traversal. The [fresh baseline](benchmarks/2026-10-02-isolated-baseline-macos.json)
and [final report](benchmarks/2026-10-02-isolated-macos.json) record:

- 10,000-cell render: **225.062 → 201.482 ms**, 10.48% faster. Peak process RSS
  median is **199.328 MiB** in both runs.
- Unique images: 3.008 → 3.002 ms. Repeated images: 2.815 → 2.788 ms.
- Every scenario's saved-PPTX output hash set matches between base and final.
  The reports retain all samples, including small timing increases elsewhere.

These comparisons use the same base behavior. They do not claim a return to
the older, simpler renderer's 70.805 ms large-table result or its 175.08 MiB
process RSS. Memory reduction and cross-platform performance remain open.

## Visual acceptance remains failed

The pinned v3 Office comparison remains **18,145 / 840,000 pixels (2.160119%)**
over channel tolerance 16, versus the unchanged **0.5%** fraction limit. The
final candidate's SVG, ordered issues, and inheritance flags are byte-identical
to this follow-up's base render with the same pinned Arial/Calibri font inputs.
The optimization therefore preserves the existing failure, not a new pass.

The [diagnostic report](benchmarks/2026-10-02-fidelity-diagnostic.json) partitions
13,430 differing pixels into the fixture's stroke zones and 4,715 outside them
(text for this specific fixture). A standalone 2.7778-pixel-wide SVG stroke
reproduces the resvg coverage discrepancy without Rostrum or fonts. At pixel
(300, 98), Office is RGB (236, 178, 159), native resvg (229, 153, 128), and the
supplemental 2× box-filtered primitive (236, 179, 160).

This evidence supports investigating rasterizer coverage separately from text
placement. It does not establish that all remaining differences are harmless.
Small text offsets remain; no speculative baseline shift was introduced.
Supersampling is diagnostic only and is not an accepted replacement comparator.

## Verification and limits

The combined production source at `a589fb48d83ab805030bca634a3e7eb11874b5d9`
passed **907 library tests / 120 suites** and **168 Lectern core tests / 15
suites**. The later diagnostic commit has identical `Sources`, `Tests`, and
`Lectern` trees. Its release build supplied the final benchmarks.

Lectern's macOS app and app-hosted test bundle built successfully with
`build-for-testing`. Its iOS simulator app built successfully for arm64 and
x86_64. The generated local Xcode project used an isolated bundle identifier,
dedicated DerivedData and package caches; source project settings are unchanged.
Existing compiler warnings remain.

App-hosted tests were **compiled but not executed**. App startup accesses
Keychain and performs deck-store migration/pruning, so launching it was outside
this follow-up's isolation boundary. The original task's pending approval was
not accepted or bypassed. Controlled app-hosted and UI testing remains for the
integration owner. Linux execution was not performed.

The first sandboxed core run failed an existing Trash operation; the new tests
passed. The Trash test and then the complete 168-test core suite passed with
approved filesystem access. This environment failure is resolved, not a
remaining test failure. An interrupted intermediate run is retained locally
but is not counted as verification.

The [verification manifest](benchmarks/2026-10-02-isolated-verification.json)
pins source trees, binaries, reports, comparison identities, and raw log hashes.
Raw build/test logs are retained in the local handoff evidence archive. No CI,
remote branch, released build, or published application is represented by these
local results.

## Integration handoff

Apply the commits in order to the integration owner's chosen branch after
review. The local bundle and format-patch directory include this evidence
record. They do not contain the original checkout's uncommitted documentation
and comparison artifacts. Reconcile that documentation without discarding it.
Run the controlled hosted-app/UI checks and required platform checks on the
integrated commit. Keep whole-slide visual acceptance open.
