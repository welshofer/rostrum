# Isolated fidelity and image follow-up — 2026-10-02

This continues [the first isolated handoff](ISOLATED-FOLLOWUP-20261002.md) at
`1284af1145baef8ab0e89e78a673ba0dfae0b98a`. Those commits remain intact. New
production source ends at `80f07da36539b2dc7fc600248fc8baef83fbe043`; later
tooling/evidence commits do not change that source. Everything remains local.
The original task owns integration, its checkout and its Office session.

## Demonstrated fixes

`80f07da36539b2dc7fc600248fc8baef83fbe043` corrects two table-border behaviors
verified against the existing independent Office PDF vectors: a terminal edge
extends by half the uniform stroke width where it meets a perpendicular edge,
and paint order is interior vertical, interior horizontal, outer vertical,
outer horizontal. Collinear color transitions retain their original endpoints.
Free ends retain their original length. RTL mirrors the physical endpoints.

This specialization requires valid, positive-size topology, uniform-width
opaque solid borders, and no diagonals. Mixed widths, alpha, dashes, compound
lines, decorations and degenerate/malformed grids keep the prior behavior.
Three tests pin the independently extracted 14 merged Office intervals and
paint order, RTL/odd-width/free-end behavior, and unsupported-style fallback.
Independent review caught unsupported dash/compound styles masquerading as
solid after fallback; source-level eligibility now excludes them.

`65f26d3cef9cb2c868c0147bc19c2c77c24ebbfb` fixes DrawingML paragraph spacing:
before-first and after-last spacing are suppressed unless
`bodyPr@spcFirstLastPara` is true. Interior spacing is unchanged. This follows
[Microsoft's ECMA remarks](https://learn.microsoft.com/en-us/dotnet/api/documentformat.openxml.drawing.bodyproperties.useparagraphspacing?view=openxml-3.0.1).
Three new regressions cover Boolean spellings, empty/interior paragraphs,
fitting, and vertical anchors. The v3 table fixture has no such spacing;
its text XML remains byte-identical after this fix and the border correction.

`d3951d6ca1c43455e6e5d297fd95724f88145c92` adds a bounded, render-local image
relationship index after measured linear-search work reaches twice the owner's
relationship count. Sparse early lookups stay linear. Limits are 16 owners,
4,096 indexed entries and 512 KiB accounted bytes, not a process-memory claim.
Reset observes later relationship/media edits; duplicate IDs retain first-match
semantics. Six tests cover admission, sparse/dense workloads, malformed IDs,
missing/external targets, owner separation, reset and per-shape diagnostics.

## Visual result and attribution

The unchanged native Office PNG gate improves from **18,145 to 18,082 differing
pixels**, or **2.160119% to 2.152619%**. It still **fails** the same 0.5% fraction
limit at channel tolerance 16. No reference or acceptance tool was changed.
See the [native comparison](benchmarks/2026-10-02-stage2-native-comparison.json).

The new [vector diagnostic](../Tools/render-regression/office_vector_diagnostic.py)
extracts the already pinned notes PDF's slide-background rectangle and renders
its glyph paths and border vectors through the same resvg backend as Rostrum.
Coordinates are normalized from that independently observed rectangle, with
no fitted translation, font offset, or resized candidate chosen to minimize
error. Its dependencies, inputs, imported helpers and outputs are hashed.
This is supplemental attribution, not an alternative acceptance test.

| Evidence | Before | Final |
| --- | ---: | ---: |
| Native PNG differing pixels | 18,145 | 18,082 |
| Common-renderer stroke-zone differences | 161 | **0** |
| Maximum border endpoint delta versus PDF extraction | 1.38894 px | **0.000107 px** |

All 14 coalesced stroke intervals match Office's geometry, widths and colors.
The tiny remaining coordinate delta is from floating-point PDF extraction.
The final common-renderer stroke-region output has no pixels differing beyond
the unchanged channel tolerance. [Before](benchmarks/2026-10-02-stage2-vectors-baseline.json)
and [final](benchmarks/2026-10-02-stage2-vectors-final.json) reports preserve
every endpoint and comparison result.

The final native residual separates as follows:

- **13,367 stroke-zone pixels:** exactly the same mask is produced by rendering
  Office's own vectors through resvg and comparing with Office's PNG. Mask
  intersection is 13,367; symmetric difference is zero. Thus this remaining
  stroke discrepancy is reproduced independently of Rostrum border geometry.
- **4,715 text pixels:** 3,203 across nine regular Calibri cells and 1,512 in
  the mixed Arial cell (1,178 on its first line, 334 on its second). The report
  retains every cell's count and fixed bounds.
- The common-renderer text comparison contains **5,469 table-text pixels**,
  plus **11 separately identified PDF print/crop pixels** at the bottom corners.
  Those 11 do not occur in the native candidate-versus-PNG comparison.

These pairwise threshold masks are not additive causes. The text masks from
candidate-versus-PNG and Office-vectors-versus-PNG overlap at 3,448 pixels;
their exclusive portions are 1,267 and 1,590. Office print typography itself
differs from its slide PNG, so the full PDF text residual is not a proven
Rostrum baseline error.

All **82 PDF glyph outlines** match the four hash-pinned font files. Rostrum's
SVG span advances match HarfBuzz 14.4 within **0.000061 px**; visible (nonwhite)
PDF glyph horizontal origins differ by at most **0.173 px**. The white-on-white
"Merged origin" reaches **0.468 px**. This rules out font
substitution and a material advance-width error for this fixture. The notes
PDF independently quantizes authored 18/24/14 pt to approximately
17.9416/24.6697/13.4562 pt, and its regular text baseline advances 124.9016 px
while grid rows advance 125 px. A universal baseline or mixed-line-height
correction is not justified by this print reference.

## Performance, including unfavorable measurements

Both image comparisons use the same unchanged driver against the separately
retained release binaries, AB/BA order, 99 measured renders per invocation and
198 per variant. All SVG bytes, ordered fidelity issues and inheritance flags
match exactly. Source baseline `9478ea9` has the same production trees as the
preserved `1284af1` handoff. No builds ran during these measurements.

| Warm image render | Baseline | Final | Measured change |
| --- | ---: | ---: | ---: |
| 2,000 unique images/rIDs | 22.449 ms | 20.133 ms | **10.32% faster** |
| 250 unique images | 1.822 ms | 1.845 ms | 1.26% slower; +0.023 ms |
| 250 repeated images | 1.660 ms | 1.664 ms | 0.22% slower; +0.004 ms |
| Two early image rIDs among 4,096 relationships | 0.042167 ms | 0.042709 ms | 1.28% slower; +0.000542 ms |

The [dense report](benchmarks/2026-10-02-stage2-dense-images-paired.json) supports
a scaling benefit. The [smaller/sparse report](benchmarks/2026-10-02-stage2-images-paired.json)
does not establish an improvement for ordinary 250-image cases. Dense images
are owned, valid, unique 1×1 PNGs overlapping at one frame: this is relationship
lookup stress evidence, not a representative image-content benchmark. The
measured scratch fixture is byte-identical to the retained
[dense fixture](../Tools/render-regression/fixtures/dense2000-images.pptx).

All 12 [fresh-process scenarios](benchmarks/2026-10-02-stage2-macos.json)
completed with one warmup, five measured samples, pinned Arial and independent
python-pptx reopening/table traversal. Saved-PPTX hash sets match the prior
handoff for all 12 scenarios. Large-table render is **196.723 ms** versus the
prior 201.482 ms, with median peak process RSS **199.5 MiB** versus 199.328 MiB. Table
SVG now intentionally changes for the geometry correction, so this is a final
behavior measurement, not an identical-output optimization claim. The much
older, simpler renderer's 70.805 ms/175.08 MiB result is not recovered.

## Verification, ownership and next work

Production source at `80f07da` passes **919 library tests / 122 suites** and
**168 Lectern core tests / 15 suites**. The macOS app and hosted test bundle
build successfully; the iOS simulator build succeeds for arm64 and x86_64.
All **737 border ownership probes** and **1,480 native-style fill probes** pass.
The final v3 text XML, ordered fidelity issues and inheritance flags match the
handoff exactly. Only the intended border SVG differs for that fixture.

Hosted-app execution and Linux validation remain unperformed. The supported
owner-task API still reports `waitingOnApproval`; its last visible action was
inspecting the Lectern test window. The actual pending approval request is not
exposed, even with tool outputs requested. No unknown approval was accepted.
The previous message tool returned success for the correct destination task,
but there is no visible owner acknowledgment or integration acceptance.

The remaining typography step requires an independent **direct-slide** PDF,
not another notes-page PDF, plus PNGs at 1200×700 and 2400×1400. A new owned
three-slide [fixture](../Tools/render-regression/fixtures/text-baseline-v1.pptx)
and [authored-coordinate manifest](../Tools/render-regression/fixtures/text-baseline-v1.manifest.json) accompany this handoff:
single-line font/size metrics, explicit-break size transitions, and mixed-run
wrapping controls. It is ready for the original session owner to export when
that session is available. No Office references or pass results are invented
for it. Use its direct vectors to test one general baseline/line-height rule
across the matrix before changing the renderer. Keep the current native gate
and all tolerances intact.

The [verification manifest](benchmarks/2026-10-02-stage2-verification.json)
pins the raw logs, binaries, source trees and reports. Incremental patches and
a bundle are supplied for the integration owner. No merge, push, CI run or
publication occurred in this follow-up.
