# Crowded panel recovery — October 18, 2026

A real Lectern design-style generation stopped at “cards panel ‘Graduate costs’
needs 111 pt; the frame allows 66 pt.” The strict panel composer correctly caught
overflow, but Lectern's pagination only supported older text layouts. One card
therefore prevented the whole deck from saving.

## Behavior

Fitting panels retain their original composition. Four crowded cards first try
two measured two-card slides. Other overflow becomes full-width headed text,
partitioned with the production builder and font measurement. Each split detail
keeps its heading; numbered steps keep their original numbers. Kicker, lead,
source, notes and section membership survive. IDs are deterministic and avoid
collisions with existing slides. There is no model call or rewrite.

Template preparation uses the same read-only planning function as composition.
Overflow continuations retain the template's existing body scale, including an
intentionally stored scale, instead of using additional normal autofit to pack
more text onto a page. Recovery checks both its selected first-page variant and
the best-fit continuation variant. Template master, layout and theme parts stay
unchanged. The library's strict `PanelLayout` API remains strict.

The bundled-design sweep also exposed rejected slide-number fields in 35 styles.
Those fields inherit caption paragraph spacing from the design master. The final
authored pass now retries only rejected number fields with explicit single-line,
zero-before/after paragraph spacing, then validates the entire slide again. It
retains the live field and its font size. Already-fitting output takes the prior
path; content errors and cancellation still propagate.

Saved render sessions use the corrected renderer for rebuilding and group
recovery. Regression coverage checks exact UTF-8 detail fragments, stable step
numbers, colliding IDs, preserved review comments and untouched neighboring
slides, notes, sections, saved-file content, Inspect parity and deterministic
serialization. Empty detail cannot cause an unfit heading to disappear.

## Reproduce and recover

`Lectern/Tests/LecternCoreTests/Fixtures/crowded-panels.json` is synthetic, deliberately
dense content. The pre-fix Release binary at `ddab73b` rejects its first card.
`Lectern/scripts/test-layouts.sh` now writes both the ordinary layout pack and a
`crowded-panels` subdirectory, with saved decks, SVGs, diagnostics and content checks.

After rebuilding Lectern, use **Recover Saved Content… → Preview Layout → Save
Revised Copy**. A `render-session-*.json` preserves the original design, images,
template and rendering options. A raw `rejected-draft-*.json` preserves the source
deck and can be replayed through `CompositionRegression --replay` with a design or
template path; the app's import picker expects a render session. See the
[usage guide](GENERATED-LAYOUTS.md).

## Validation and resource measurements

The full `scripts/verify.sh --fast` gate passes: 1,413 Rostrum tests, 118 optimized
tests, 370 LecternCore tests, native text/table checks, portable fidelity references
and executable README examples. The post-pull `Lectern/scripts/test-layouts.sh`
also passes its 13 focused tests and writes both six-slide ordinary packs and
eleven-slide crowded packs for the supplied 16:9 and 4:3 templates. Required
Linux and Apple PR checks gate the merge; their outcome is recorded on the PR.
Native Lectern UI and PowerPoint slide-view/export acceptance remain separate;
Linux previews and package checks cannot establish those results.

The dense fixture passes saved-content/schema checks across **all 150 bundled
designs**, producing 1,659 slides in total. [Style and deck hashes with results](benchmarks/2026-10-18-panel-reflow-styles.json.gz)
retain missing-font diagnostics: this validates the available Linux font policy,
not every commercial face on a Mac. The previous sweep failed in 35 styles on
slide-number spacing; all 35 now complete without dropping their fields.
Independent saved-XML inspection retains all 1,509 expected live slide-number
fields (the first slide of each deck intentionally has none). Reproduce the sweep:

```sh
swift run -c release --package-path Lectern CompositionRegression /tmp/panel-styles \
  --replay Lectern/Tests/LecternCoreTests/Fixtures/crowded-panels.json \
  Lectern/App/Resources/Styles/*.md
```

The exact-Calibri template checks retain all words and keep shapes within both
canvases. Independent python-pptx and ZIP/XML checks pass for all three measured
decks. [Deck hashes](benchmarks/2026-10-18-panel-reflow-review.json) identify the
reviewed bytes. The following portable contact sheet was inspected with resvg;
for this raster-only check, embedded-font CSS was removed and its aliases resolved
to the supplied exact font files. The original PPTX/SVG bytes were unchanged.

![Crowded panel continuations, 16:9 and 4:3](benchmarks/2026-10-18-panel-reflow.png)

The [collector](benchmarks/2026-10-18-panel-reflow.py) compares retained normal
Swift Release binaries with their SwiftPM resources against `ddab73b`. Each
unchanged control renders three decks per process. There is one warmup and seven
alternating-order measured pairs, CPU affinity is fixed, and builds/tests do not
run concurrently. Native `wait4` records process CPU and peak RSS; wall time also
includes process startup and file writes. The crowded workload is an absolute
measurement because the baseline cannot finish it.

[Final raw measurements](benchmarks/2026-10-18-panel-reflow.json.gz).
Median paired candidate/baseline changes (negative means lower):

| Unchanged control | CPU | Elapsed | Peak RSS |
| --- | ---: | ---: | ---: |
| Mixed deck | −0.32% | +0.62% | +0.16% |
| Fitting panels and tables, authored | +1.51% | +1.34% | +0.30% |
| Fitting panels and tables, template | −0.50% | −0.38% | +0.85% |

All 111 canonical control artifacts match the baseline in every pair, including
PPTX, SVG, ordered diagnostics and normalized manifests. The canonicalizer removes
only run paths, snapshot UUIDs, timings and JSON key order. This is a reliability
fix with extra panel fit checks, not a speedup claim. An
[earlier implementation run](benchmarks/2026-10-18-panel-reflow-initial.json.gz)
measured CPU increases of 1.04%, 3.77% and 5.38% respectively; those adverse samples
remain available rather than being discarded after the follow-up fixes.

The final crowded workload renders the same three source slides using the
default design and both private exact-Calibri template ratios. Across seven
fresh measured processes its median CPU is 2,375.67 ms, elapsed 2,441.38 ms and
peak RSS 50,004 KiB. This is Linux rendering, saving and SVG production; it does
not measure the macOS UI or WebKit processes. Private font/template bytes remain
outside Git. The baseline's rejected output cannot provide a throughput comparison.
