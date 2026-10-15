# PowerPoint fidelity and performance plan

Agreed 2026-10-14. Starting revision: `2032208af1bad8b1a44de78fd753d37616ce1402`.

## Goal

Deliver a highly performant, pure-Swift PowerPoint library with reliable native
typography, strong template/table composition and consistent Lectern previews.
Users choose their fonts. Preserve editable native content, exact source words,
notes, sections, unrelated package parts and deterministic output.

## First milestone: native text/table regression pack

Status: **in progress**.

- [x] Build a repeatable, offline pack using explicit caller-supplied font files
  and font identities. Include installed/external and embedded-font cases,
  regular/bold/italic text, mixed-size runs, line breaks, tabs, bullets, inherited
  template styles, dense tables and horizontal spans on 4:3 and 16:9 canvases.
- [x] Save every deck, reopen it, retain SVGs and ordered diagnostics, and verify
  source text, table rows, notes, sections, template bindings and geometry.
- [x] Record source revision, exact font/deck hashes, platform, build mode and
  explicit support boundaries. Keep proprietary fonts and private templates out
  of Git. Missing required faces must not silently become a passing exact-font case.
- [x] Exercise the pack through production LecternCore Inspect and export as well
  as the library, retaining deterministic artifacts and verifying source content.
- [ ] Review the same pack in Lectern's native UI, including WebKit thumbnails.
- [ ] Capture PowerPoint for Mac slide-view and PDF/image-export evidence for
  the same saved bytes and fonts. Extend the existing native corpus; keep these
  two rendering paths distinct because the earlier glyph overlap affected only
  slide view.
- [ ] Compare wrapping, baselines, clipping, table/caption bounds and page
  boundaries. Fix reproducible failures and rerun the affected corpus.

Completion requires native evidence for each claimed profile. A successful build,
schema check, saved-file read-back or SVG comparison is not native visual acceptance.
This Linux environment can prepare and validate the pack; PowerPoint and native
Mac measurements require a Mac. Track that work as pending until evidence exists.

Implementation: [native-fidelity tool](Tools/native-fidelity/README.md). The first
pack uses a controlled synthetic template, 24 source table rows and a merged
header. External profiles require installing the exact faces for native review;
the portable tool registers the supplied files explicitly. The collector checks
identical artifacts across fresh processes and records per-phase CPU/elapsed
time and whole-process CPU/elapsed/peak RSS. These are measurement probes; the
production Mac pipeline and UI first-preview baseline below remain pending.

Portable evidence (2026-10-14): the six integration checks generate every profile
twice with licensed fixture faces. A separate Release run with the supplied
Calibri regular/bold/italic/bold-italic faces also produced identical artifacts
across eight fresh processes. Independent python-pptx read-back retained all 24
source rows in each profile (six slides at 4:3, four at 16:9). Accented-text
shaping approximation diagnostics remain recorded; no native path is approved.
The local fast gate passed: 1,363 library tests, 63 optimized-layout tests, 334
LecternCore tests, the six pack checks, portable fidelity references and README
examples. Apple CI and live native acceptance are separate gates.

## Second milestone: end-to-end Mac performance baseline

Status: **measurement tooling in progress; native Mac baseline pending**.

The pack's optional `InspectionRegression` runner now calls production
`DeckInspector` and `DeckExporter` with their normal embedded/installed-font
policy. It retains stable inspection results, SVGs, diagnostics and exports,
checks unchanged source artifacts, and compares fresh-process repetitions.
It measures complete inspection and export CPU/elapsed time, cumulative progress
events and first-SVG-slot completion; the collector measures process peak RSS.
The [pipeline profiler](Tools/preview-profile/README.md) now separates package
opening, font discovery/registration, layout, composition, saving/reopening and
per-slide SVG CPU/elapsed time. It retains paired, alternating fresh processes
and repeated inspections, process peak RSS and exact artifact comparisons.
A local Release app-hosted probe instruments production WebKit navigation, font
readiness, queue wait and bitmap capture; execution on a Mac remains pending.
First-bitmap availability is separate from actual first visible display latency;
WebKit helper-process CPU/memory and compositor presentation need native traces. External faces unavailable to the host remain missing
font diagnostics; supplying manifest files does not inject them into Lectern.

Continuation evidence (2026-10-14): all four fixture profiles repeat identically
through production Core inspection/export. Independent checks retain all 24
source rows, mixed-face text, tabs, bullet indentation, notes, sections and slide
aspect ratios. The local fast gate passed with 1,363 Rostrum tests, 334
LecternCore tests, 63 optimized-layout tests, portable references, workflow checks,
README examples and eight pack checks. A Release run passed all nine pack and
provenance checks, including simulated host/container Git ownership mismatch.
These results establish neither native visual acceptance nor a Mac speedup.

- [ ] Measure font discovery/registration, layout, saving, saved-deck reopening,
  SVG generation and thumbnail rasterization separately on fixed real-world inputs.
- [ ] Measure CPU, elapsed time, whole-process peak memory and time to first
  preview. Distinguish first-use and repeated operations; report the timing scope
  and any excluded work. Do not describe Linux or Debug timings as Mac results.
- [ ] Include small controls, dense text, large tables, image-heavy decks and
  representative templates with the intended fonts. Reuse the fidelity pack where
  appropriate and retain the production Lectern generation/Inspect paths.
- [ ] Profile the largest measured cost before changing algorithms. Use bounded
  reuse with fresh font/content checks across operations.
- [ ] Compare Release builds with alternating fresh processes, warmups and raw
  samples. Avoid concurrent builds/tests while collecting timings.
- [ ] Require identical widths, row heights, page boundaries, ordered diagnostics,
  saved decks and SVGs for performance-only changes. Record adverse controls and
  peak-memory costs; do not add percentages across different baselines.

Profiling continuation (2026-10-15): six Release workloads, one warmup and
seven alternating pairs per workload (96 fresh processes) retain identical deck,
SVG, snapshot, diagnostics and export artifacts. The largest template cost was
source-note planning; bounded reuse removes six of 94 planner calls within one
source block, with fresh composition checks. Median paired process CPU improves
2.30% on that fixture; small/embedded inspection controls show slight slowdowns.
See the [pipeline measurement record](docs/PREVIEW-PIPELINE-20261015.md).
The full portable gate passed: 1,363 Rostrum tests, 339 LecternCore tests,
63 optimized layout tests, nine pack checks, portable fidelity references,
workflow checks and README examples. Mac bitmap execution, app-hosted tests,
actual first-visible-frame latency, helper-process resource measurements and
native visual acceptance remain unchecked above.

Recent Linux results include about 10% lower long-source CPU and 6–8% lower dense
text CPU. They establish neither a current native Mac speedup nor a general memory
reduction. See [the performance ledger](docs/PERFORMANCE.md).

## Third milestone: confirmed interoperability repairs

Status: **pending; prioritize failures found in the native pack**.

- [ ] Add an explicit, validated operation to rebuild missing classic-chart
  caches from supported embedded workbook references. Lectern can currently show
  these values while PowerPoint leaves the chart blank. Ordinary open/save must
  remain lossless and must not repair caches implicitly.
- [ ] Cover unsupported references, malformed workbooks, atomic refusal,
  deterministic save/reopen and native PowerPoint acceptance before shipping.
- [ ] Demonstrate any new public API in an offline Library Lab recipe with
  inspector/export coverage and clear support boundaries.

## Subsequent scope

These are known gaps, not promises that the first milestone implements them:

| Area | Remaining work |
| --- | --- |
| Table layout | Vertical merged cells, rotated/vertical text, dynamic fields and native table autofit |
| Imported artwork | Custom arcs, bent/curved connectors and broader effects |
| Typography | Full bidirectional and complex-script layout; broader native autofit equivalence |
| Charts | Date/number formatting, broader workbook references and advanced layouts |

## Working and acceptance rules

- Use the existing checkout and small reviewable commits. Keep Rostrum and
  RostrumLayout portable and dependency-free; Apple adapters remain in the host.
- Preserve user-selected fonts. Fixture fonts and preview fallback are explicit
  test/host policies, never a global library requirement.
- Keep visual acceptance, content preservation, schema validity and performance
  evidence separate. Unreviewed cases stay unreviewed.
- Run meaningful focused regressions and `scripts/verify.sh --fast` on Linux;
  Apple CI covers native package paths and app builds. App-hosted tests and live
  PowerPoint review remain separate checks.
- Publish validated work through GitHub checks, retain native-only outstanding
  work here, and update this plan as each milestone produces evidence.

Evidence map: [documentation](docs/README.md), [conformance](docs/CONFORMANCE.md),
[native layout review](docs/POWERPOINT-LAYOUT-20261013.md),
[composition regression workflow](Lectern/Tools/CompositionRegression/README.md).
