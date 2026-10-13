# Measured tables in Lectern generation

Lectern's production renderer now calls `planTablePages` with measured column
sizing and commits with `composeTablePages`. This covers new decks from designs
and templates, whole-deck rebuilds, and single-slide recovery. The app uses local
path dependencies; pulling this repository and rebuilding Lectern includes the
library changes without a separate package upgrade.

The previous authored builder kept only seven body rows from the 28-row regression
input. The new path writes all 28 across three editable slides. Headers, column
widths and speaker notes repeat; rows preserve source order. Captions reserve
space beneath each table. Long sources continue after the table; paragraph
boundaries are preferred, and authored source pages reserve running footer space.
A row that cannot fit with its header fails before a file is saved.

Generation registers embedded template faces before installed-font lookup.
Recovery imports those payloads through the library's atomic import behavior;
identical faces do not create duplicate font parts. Font families remain the
caller's choice. Missing-face diagnostics remain separate from schema validation.

Recovery retains existing slide identities, comments, notes and sections. It
refuses an alternative that would remove existing continuation pages; a whole-deck
rebuild remains the explicit route to a shorter deck. Read-back acceptance now
compares repeated headers and the concatenation of native body rows, catching
reordering, duplication and omission independently of visible-text token checks.

## Verification and reproduction

`TableRenderingTests` covers default and serif designs, real 720×540 and 960×540
templates, saved row geometry, consistent columns, caption clearance, deterministic
PPTX/SVG output, inspector/exporter coverage, source-note footer clearance, notes,
sections, ragged rows, colliding original IDs, embedded fonts, recovery annotations,
page-reduction refusal and oversized rows. It checks template parts remain unchanged.

From the repository root:

```sh
swift test --package-path Lectern --filter TableRenderingTests
swift run -c release --package-path Lectern CompositionRegression /tmp/lectern-tables --tables
# Append your POTX or design.md path to exercise its typography and layout.
Lectern/scripts/build.sh
```

In the app, generate a table-heavy deck, inspect the saved result, export it and
try saved-content recovery. The offline fixture supplies 28 table rows and a
second table with long sources without making provider calls. Native PowerPoint
visual acceptance remains pending; Linux tests and previews do not establish it.
Generated IR supports plain grids here, not merged cells or vertical spans.

## Release cost of preserving the complete input

Linux, Swift 6.1.3, three fresh-process runs of `CompositionRegression --replay`
with one 28-row table. Baseline: `d2df828`; implementation: `deb65d0`. Both use the
same input and available fonts (no installed Office faces in this measurement).
Times include launch, rendering, saving, previews and the saved-content check.
CPU is user + system time from `wait4`; memory is per-process peak RSS.

| Median | Previous path | Measured production path |
|---|---:|---:|
| Elapsed | 47.6 ms | 87.6 ms |
| CPU | 43.9 ms | 84.7 ms |
| Peak RSS | 26.88 MiB | 27.46 MiB |
| Saved slides | 1 | 3 |
| Body rows retained | 7 / 28 | 28 / 28 |
| Saved-content acceptance | Failed | Passed |

This is a correctness improvement with additional composition work, not a speedup
claim or an identical-output benchmark. Width-search budgets and operation-local
reuse come from the existing library implementation. Other compilers were active
on the host; these small-sample timings are indicative, not a performance gate.
