# PowerPoint fidelity and performance plan

Agreed 2026-10-14. Starting revision: `2032208af1bad8b1a44de78fd753d37616ce1402`.

## Goal

Deliver a highly performant, pure-Swift PowerPoint library with reliable native
typography, strong template/table composition and consistent Lectern previews.
Users choose their fonts. Preserve editable native content, exact source words,
notes, sections, unrelated package parts and deterministic output.

## First milestone: native text/table regression pack

Status: **portable pack validated and delivered Calibri pack accepted by the user in PowerPoint; native UI/export evidence incomplete**.

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
- [x] Record the user's pack-level PowerPoint acceptance against the delivered Calibri hashes; see the review record below.
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

Status: **two native Mac runs received on different decks; paired comparison and broader corpus pending**.

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
readiness, queue wait and bitmap capture. The user supplied one successful
28-slide Mac run; see the cache continuation below.
The post-pull `Lectern/scripts/test-preview.sh` runner now collects the Release
profile and native thumbnail regressions in one command and creates a shareable
evidence ZIP. An updated 17-slide Mac run at `e71b087` passed all 12 native
regressions, rendered every slide and hit all 17 cached thumbnails on repeat.
Its first bitmap arrived in 698/257 ms; all repeated thumbnail requests totaled
1.53 ms. SVGs and diagnostics matched between inspections. Its input differs from
the earlier 28-slide deck, so this does not establish a before/after speedup.
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

Native cache continuation (2026-10-15): the supplied Mac Release trace at
`e35bf24` has 28 successful renders followed by 28 bitmap cache hits and no
dropped samples. The user confirmed its dirty checkout flag reflects generated
or untracked output only. Repeat cache hits consumed 287 ms despite no WebKit
work. Prepare exact UTF-8 content identity once per preview record, retain it
through generation/recovery/Inspect views, and replace SVG-bearing recency scans
with constant-time promotion. Limit retained cache entries by both count and
accounted SVG/bitmap bytes. The [cache decision record](docs/THUMBNAIL-CACHE-20261015.md)
contains paired Release cache-only evidence on the supplied SVGs, adverse small
controls, unchanged-input checks and memory limits. Native app tests passed in the
subsequent 17-slide run; a paired Mac comparison, first-visible-frame latency and
helper-process memory remain pending.
Sharing repeated embedded-font resources is a separate follow-up; standalone
SVG bytes and caller-selected fonts remain intact in this change.

WebKit-loading experiment (2026-10-15): the new Mac run spends 828 ms of 1,113 ms
of first-pass thumbnail requests in navigation. An opt-in transport shares exact
font bytes through a bounded in-memory handler while preserving font rules and
standalone SVGs. It reduces HTML payload on the earlier 28-slide corpus but adds
preparation CPU, so it is **not enabled in the app**. The new
`Lectern/scripts/compare-preview-loading.py` runner collects alternating native
runs and requires exact bitmap and SVG parity. Native adoption is pending those
results. See the [experiment record](docs/PREVIEW-FONT-RESOURCES-20261015.md).

Font-registration continuation (2026-10-15): the same Mac trace reports
143–190 ms in installed-font registration. Lectern parsed each accepted face
while validating candidates, then parsed it again to register it. A new immutable
`PreparedFont` keeps source bytes, collection index and metrics together; public
registration overloads and Lectern's operation-local session reuse that parse.
Fresh operations still reread files. Embedded-face priority, aliases, exact
style checks and resource budgets remain unchanged. Five paired Linux Release
workloads retain identical saved decks, SVGs, diagnostics and registration
receipts across 80 fresh processes. Available-font registration CPU falls
30–40% first-use and 44–47% on a second fresh operation; a missing-font control
has no demonstrated benefit. See the [registration record](docs/FONT-REGISTRATION-20261015.md)
for raw CPU/elapsed, memory and control results. Paired native Mac timing remains pending.

Recent Linux results include about 10% lower long-source CPU and 6–8% lower dense
text CPU. They establish neither a current native Mac speedup nor a general memory
reduction. See [the performance ledger](docs/PERFORMANCE.md).

## Third milestone: confirmed interoperability repairs

Status: **portable implementation validated; native PowerPoint acceptance pending**.

- [x] Add an explicit, validated operation to rebuild missing classic-chart
  caches from supported embedded workbook references. Lectern can currently show
  these values while PowerPoint leaves the chart blank. Ordinary open/save must
  remain lossless and must not repair caches implicitly.
- [x] Cover unsupported references, malformed workbooks, atomic refusal and
  deterministic save/reopen.
- [ ] Complete native PowerPoint acceptance before shipping.
- [x] Demonstrate any new public API in an offline Library Lab recipe with
  inspector/export coverage and clear support boundaries.

Implementation: [explicit cache repair](docs/CHART-CACHE-REPAIR.md). The API
validates every absent reference in one chart before mutation, preserves existing
caches and exact workbook bytes, and rereads current workbook content on each
operation. The strict reader supports local one-dimensional A1 ranges, text and
General numeric stored values; unsupported data refuses the whole operation.
The Missing chart caches Lab retains category/scatter before/after decks, saved
checks, production inspector previews and extracted CSV. Native PowerPoint
opening, slide view, export and Edit Data acceptance remain pending.
Focused portable evidence (2026-10-14): 18 chart reader/repair tests and 11
Document/Lab tests passed. Both repaired Lab decks pass independent python-pptx
read-back and ZIP/XML checks, with only chart XML changed. Production inspector
SVGs/diagnostics and exported CSV match before/after; the scatter SVG remains a
diagnosed placeholder. The full local fast gate passed: 1,374 Rostrum tests,
335 LecternCore tests, 63 optimized-layout tests, nine fidelity-pack checks,
portable references, workflow checks and README examples. Native app builds,
app-hosted tests and live PowerPoint acceptance remain separate.

## Next layout milestone: multi-row merged cells

Status: **portable measurement and connected-row pagination validated; delivered Calibri pack accepted by the user in PowerPoint, export evidence pending**.

- [x] Measure vertical/rectangular merge anchors across their combined width;
  distribute height deficits across spanned rows deterministically.
- [x] Retain covered XML and fresh font/content checks; recompute cross-row
  constraints during cached width trials.
- [x] Add an editable Templates Lab example with save/reopen and Inspect/export
  checks on 4:3 and 16:9 canvases.
- [x] Verify existing-output preservation and record CPU, elapsed time and peak memory.
  Timings are mixed/noisy; no universal speedup or nonregression claim.
- [x] Include both merged-cell suites in optimized Linux and Apple CI.
- [ ] Capture PowerPoint slide-view and export evidence with exact fonts.
- [x] In a separate change, support template composition and page partitioning
  that keeps connected row-span groups intact, with explicit oversized refusal.
- [x] Complete portable pagination regressions, both Lab ratios, independent
  saved-file checks and preservation/performance comparisons. Small controls
  retain adverse timing results; no general speedup claim.

Both Linux and Apple PR gates must pass before merging. Native visual acceptance
and native Mac performance remain separate from these portable results.

See [vertical-merge measurement](docs/TABLE-VERTICAL-SPANS-20261016.md) and
[connected-row pagination](docs/TABLE-ROW-PAGINATION-20261016.md).

## Typography and first-preview continuation (2026-10-16)

- [x] Profile the opt-in shared-font transport on the supplied 28-slide corpus.
  Repeated scans and large-key hashing dominate preparation; decoding is small.
- [x] Use bounded word scanning and hash reuse with exact byte equality. Keep
  resource budgets, changed-font checks and inline fallback intact.
- [x] Compare Release preparation CPU, elapsed and process peak RSS across five
  alternating pairs and retain adverse controls. Prepared SVGs/font resources
  and exact reconstruction match; memory is essentially unchanged.
- [x] Extend the exact caller-font pack with vertical/rectangular merged groups,
  source/geometry evidence and independent saved-grid checks.
- [ ] Run the paired native Mac transport comparison and measure WebKit helper
  resources/actual first-visible-frame latency before claiming a product gain.
- [ ] Review the extended pack in PowerPoint slide view and PDF/image export;
  fix confirmed typography discrepancies against those exact bytes and fonts.

The normal app remains on inline font loading. This Linux environment can
prepare and test the candidate but cannot establish native visual acceptance.
See [preparation measurements and native commands](docs/PREVIEW-PREPARATION-20261016.md).

## Multi-row repeated headers (2026-10-16)

Status: **portable implementation, full local gate, both Lab ratios and Release preservation/resource comparison validated; new native PowerPoint review pending**.

- [x] Add an explicit header-row count with the existing one-row default.
- [x] Repeat native header merges and refuse merges crossing the header/body boundary.
- [x] Reserve the entire header prefix in page partitioning and width-search scoring.
- [x] Verify saved/reopened grids, body order, diagnostics, caption bounds and fresh checks.
- [x] Exercise the capability in Lectern's Templates Lab and production Inspect/export.
- [x] Compare existing default output exactly and measure Release CPU, elapsed and peak RSS.
- [x] Include the new regressions in optimized Linux and Apple CI. The full local portable gate passes; green Apple checks are required before merge.
- [ ] Obtain native PowerPoint review of the new header cases.

The [repeated-header report](docs/TABLE-REPEATED-HEADERS-20261016.md) retains
142 unchanged control artifacts, 44 repeatable new artifacts and all resource
samples, including the 4–5% plain-composition slowdowns. No general speedup claim.

## Calibri pack acceptance (2026-10-16)

The user reports: “Decks look great in PowerPoint. Proceed.” Record this as
pack-level visual acceptance of the four delivered Calibri decks at `837e2bc`,
with exact deck/font hashes in the [review record](docs/POWERPOINT-REVIEW-20261016.md).
No separate per-profile verdict, PowerPoint version or PDF/image export accompanied
this message. The broader native evidence checklist above remains open where it
requires those details. This acceptance covers the delivered connected-body-merge
cases; it does not extend to new multi-row headers, chart repair or WebKit transport.

## Composition performance follow-up (2026-10-17)

- [x] Recheck the earlier 4–5% table-composition slowdowns with ten alternating
  pairs of the exact retained Release binaries. The magnitudes did not reproduce
  consistently; retain all results rather than attributing a fixed regression.
- [x] Profile composition phases. Repeated template-style resolution accounts
  for about 27 ms and 337 calls on a 167-page table.
- [x] Resolve that immutable style once per composition operation, retaining
  fresh replanning, per-page title checks and current font/style validation.
- [x] Require exact output preservation and measure CPU, elapsed and peak RSS.
  All 264 artifacts match across 16 controls; retain all 70 alternating pairs.
- [x] Complete the full local portable gate. Apple CI remains a required
  pre-merge check; native app-hosted execution and Mac timings are separate.

See the [composition measurement record](docs/TABLE-COMPOSITION-20261017.md).

## Text layout follow-up (2026-10-17)

- [x] Run current native typography/fitting regressions and profile the remaining
  table layout work. Existing geometry references pass; the historical PNG gate
  lacks three exact pinned faces and remains unqualified by this work.
- [x] Discard a span-assembly experiment with inconsistent performance; reuse
  already resolved run metrics during line-fragment measurement instead, retaining
  current font/content checks and exact output.
- [x] Preserve the table corpus, native typography decks, detailed bit-pattern
  snapshots, authored fitting results and user-approved Calibri pack.
- [x] Compare freshly built Release variants with identical compiler arguments;
  retain CPU, elapsed, peak RSS, every raw sample and adverse controls.
- [x] Complete the full portable gate, including expanded optimized text checks.

Green Apple CI remains required before merging.

See the [text-layout record](docs/TEXT-LAYOUT-20261017.md). This removes repeated font
lookup without extending native autofit/typography qualification or changing
users' font choices. Paired Mac timing and broader native evidence remain open.

## Subsequent scope

These are known gaps, not promises that the first milestone implements them:

| Area | Remaining work |
| --- | --- |
| Table layout | Stacked/complex vertical text, dynamic fields and native table autofit; multi-row headers tracked above |
| Imported artwork | Custom arcs, bent/curved connectors and broader effects |
| Typography | Full bidirectional and complex-script layout; broader native autofit equivalence |
| Charts | Date/conditional formats beyond the numeric subset, broader workbook references and advanced layouts |

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


## Rotated table text — October 17 continuation

- [x] Measure native 90°/270° cell text at full size with bounded preparation reuse.
- [x] Retain directions through template composition, merges, repeated headers and pagination.
- [x] Verify final rectangles after shared row heights are resolved; retain explicit unsupported-mode diagnostics.
- [x] Complete regression, saved-file, horizontal preservation and CPU/elapsed/RSS checks.
- [x] Provide the implementation, usage documentation and runnable Lectern Templates Lab review path.
- [x] Record user-reported visual acceptance of the delivered rotated-table pack.
- [ ] Capture separate native slide-view and PDF-export evidence for the rotated cases.

See [support and evidence](docs/TABLE-ROTATED-TEXT-20261017.md) for the accepted
deck hashes and the limits of the pack-level review.

## Small-table measurement overhead

- [x] Profile the measured small-table slowdown in normal Release builds.
- [x] Reuse effective-style bytes and immutable cell-key hashes within each operation.
- [x] Compare CPU, elapsed time and peak memory; preserve all 388 control artifacts,
  1,248 snapshots, 84 Calibri artifacts and the accepted rotated PPTX/SVG files.
- [x] Complete the full portable gate and prepare the validated change for PR checks.

[Measurements and validation](docs/TABLE-MEASUREMENT-20261017.md) retain the full
comparison. Required Linux and Apple PR checks must pass before merging.


## Generated table integration and layout variety (2026-10-17)

- [x] Extend DeckIR with optional additional header rows, rectangular merges and
  cell directions; retain plain-input defaults and reject lossy metadata.
- [x] Preserve full-grid coordinates through page splitting, recovery and read-back.
- [x] Add measured editable cards, three-column panels and numbered steps to the
  generation vocabulary, provider schema and template/authored rendering paths.
- [x] Add an offline Lab recipe in both ratios and a post-pull review script.
- [x] Complete output-preservation/CPU/elapsed/RSS controls and the full portable gate.
- [ ] Review the new compositions in PowerPoint; retain slide-view/export evidence.

Required Linux and Apple PR checks gate the merge; their outcome is recorded
on the PR. See [the usage contract](docs/GENERATED-LAYOUTS.md) and
[measurements](docs/GENERATED-LAYOUTS-20261017.md). Plain inputs keep their prior
output; the new layouts are explicitly selected rather than silently reassigning
existing slides. Native PowerPoint review and native timing remain separate.

## Crowded-panel generation recovery (2026-10-18)

The first real design-style run exposed a missing connection: one oversized card
aborted the deck because the new panel layouts bypassed authored pagination.

- [x] Reproduce the failure class with a synthetic, offline “Graduate costs” fixture.
- [x] Try roomier card pages, then measured full-width headed continuations in both
  design and template rendering; retain exact words and original step numbers.
- [x] Exercise saved-content rebuilding and continuation recovery, notes, sections,
  comments, untouched neighbors, template parts, determinism and saved Inspect.
- [x] Complete Release preservation/resource controls and the full portable gate.
- [ ] Confirm the user's recovered deck in Lectern and PowerPoint for Mac.

The offline `Lectern/scripts/test-layouts.sh` now includes crowded panels.
Recovery uses saved content without spending another model request.
Required Linux and Apple PR checks gate the merge; their outcome is recorded
on the PR. See [the validation report](docs/PANEL-REFLOW-20261018.md).

## Chart and symbol preview fidelity (2026-10-18)

The supplied 33-slide higher-education deck exposed incorrect percentage units,
missing bar labels/line markers, ignored chart text styling, and misleading
inspection findings. The original presentation remains outside version control.

- [x] Preserve numeric literals and units; compile formats once per axis/label style.
- [x] Honor chart text styles and render requested bar labels and line markers.
- [x] Render three-segment elbow connectors and report actual preview omissions.
- [x] Add explicit, registered fallback faces for missing standalone symbols,
  without changing authored fonts or splitting emoji sequences.
- [x] Group repeated inspector findings and separate unverified native text cases.
- [x] Add saved/reopened chart and symbol checks to the offline Library Lab.
- [x] Complete the final portable gate: 1,424 library tests, 371 LecternCore
  tests, 118 optimized controls, native-pack checks and portable fidelity references.
- [ ] Pass Apple PR checks (including app and native test-host compilation).
- [ ] Review the new previews on macOS with the deck's exact fonts.

See [the behavior and validation guide](docs/CHART-PREVIEW-FIDELITY.md).
Chart collision/layout parity, other chart kinds, and full complex-script shaping
remain outside this change.
