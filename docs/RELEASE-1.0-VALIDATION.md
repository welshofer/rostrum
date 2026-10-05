# Rostrum 1.0 release validation

Recorded October 4, 2026 (America/Los_Angeles), for the release candidate based
on `8c069ec37a69cb39424af90b7099422bb7d0ea70` plus the 1.0 changes. This receipt
separates package tests, focused headless app checks, builds and an actual offline
UI run. It does not treat them as a complete native PowerPoint fidelity result.

## Results

| Check | Result | Scope |
| --- | --- | --- |
| Rostrum package suite | 1,221 tests in 178 suites passed | Document model, archive/XML, rendering and regression coverage |
| RostrumLayout suite | 18 tests in 3 suites passed | Template selection, composition and measured pagination |
| LecternCore suite | 315 tests in 50 suites passed | Portable application core and offline library recipes |
| Focused headless persistence suite | 11 test definitions; 14 executions passed | `LibraryLabPersistenceAppTests`, including parameterized cases; compiled app source with isolated dependencies |
| Canonical macOS build | Passed | `Lectern/scripts/build.sh` |
| Canonical iOS simulator build | Passed | `Lectern/scripts/build-ios.sh`; build evidence, not an on-device UI run |
| Actual isolated Library Lab UI batch | 34 saved `.pptx` files containing 168 slides; zero generation or save failures | Credential-disabled documentation instance running the offline recipes |
| Reveal and inspection UI | Reveal All selected all 34 files in Finder; Inspect Result opened the table deck and expanded its 4×4 cells | Actual UI interaction with the saved results |
| Native PowerPoint table check | The one-slide “Edit a table grid” deck opened without repair; vertically centered row text was visually confirmed | One isolated saved demo; no deck files changed by PowerPoint |
| Demo release archive | All 34 decks passed ZIP CRC checks and reopened with python-pptx 1.0.2 | Actual saved PPTX bytes retained; archive entry filenames shortened |
| Existing README examples | Source synchronization check passed; both examples ran, saved and reopened | Generated executable snippet blocks remain unchanged |
| New documentation examples | Five non-manifest Swift blocks typechecked and executed | Introduction, table, native template, SVG preview and paginator examples |
| Offline Python helper checks | 12 tests passed | Acceptance helper, project wrappers and publication audit safety |

The new documentation examples produced a two-slide introduction deck, a
one-slide table deck and a one-slide template deck. All three reopened through
Rostrum with the expected slide counts and passed ZIP CRC checks. The example
SVG and ordered-content pagination paths also completed. These examples are
intentionally small; the 34-demo UI batch is the separate 168-slide result.

The focused persistence checks ran **headlessly**, not as an Xcode app-hosted
suite. The documentation batch ran in an isolated credential-disabled app
instance. The user's running Lectern instance remained running; this release
pass did not replace it or change its stored API keys. A complete app-hosted
suite was not rerun during this pass. Earlier hosted/native evidence remains
historical and is identified separately in the conformance records.

## Inspectable release artifacts

`rostrum-v1.0.0-demo-decks.zip` contains the 34 actual saved PowerPoint decks,
168 slides in total, a README and `manifest.json`. The manifest records each
deck's archive name, slide count, byte size and SHA-256 digest. Packaging changes
only the archive entry filenames; each `.pptx` payload retains the saved bytes.
`SHA256SUMS` records the archive digest. The archive and checksum file accompany
the GitHub release so the generated decks can be inspected independently.

The [Library Lab screenshot](images/lectern-library-lab.png) and
[table inspector screenshot](images/lectern-table-inspector.png) were captured
from the isolated app and visually checked. They document the saved-results and
inspection workflows; they are not native PowerPoint comparison images.

The [PowerPoint table screenshot](images/powerpoint-table-centering.png) records
the separate native check. PowerPoint was at its idle Home screen before opening
only the isolated “Edit a table grid” saved demo. The one-slide deck opened
without a repair prompt, and centered row text was confirmed visually. This is
a bounded native open/visual check of one deck, not a corpus-wide pixel comparison.

## Migration and observable behavior

- Newly authored table cells center text vertically, including new cells from
  row/column insertion. Imported cells preserve their authored alignment.
  Call `cell.verticalAnchor = .top` or `.bottom` explicitly when that is the
  desired authoring behavior.
- Lectern saves an individual PowerPoint deck for each completed demo. Saved
  results show file and slide totals and provide Reveal in Finder on macOS.
  Inspection does not cancel a running batch, and failed saves can be retried.
- Add the separate `RostrumLayout` product for native-template composition,
  measured fit and pagination. `Rostrum` continues to own the document model,
  package I/O and shared preview/text geometry.

## Publication and acceptance boundaries

The [publication audit](RELEASE-1.0-AUDIT.md) records current-tree and reachable
history scans, archived-document inspection, finding classification and limits.
It found no unresolved credential candidate in its reviewed scope. The
python-pptx gratitude, acknowledgment and licensing are retained; the audit
also distinguishes current-tree cleanup from rewriting repository history.

This pass does not establish universal PowerPoint pixel parity, native autofit
choices, complete table rendering equivalence or a new release-wide performance
improvement. Use the [conformance matrix](CONFORMANCE.md) for scoped acceptance
and the [performance ledger](PERFORMANCE.md) for measured baselines and costs.
GitHub CI status is recorded by the release commit's checks, separately from
these local results.

For adoption, see [Getting started](GETTING-STARTED.md),
[Layout engine](LAYOUT-ENGINE.md), [Architecture](ARCHITECTURE.md) and the
[Lectern guide](../Lectern/README.md).
