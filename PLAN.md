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
- [ ] Exercise the pack through Lectern Inspect and export as well as the library.
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

Status: **pending; measurement tooling starts with the first milestone**.

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
