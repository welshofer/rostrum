# Native partial custom table styles — Fidelity 19

This finite oracle covers 12 cases on two 720 pt pages: ten single-cell tables
and two 2×2 tables, with 72 visible body glyphs, 15 fills and 49 canonical border
intervals. The independent python-pptx/OOXML source embeds the same licensed
DejaVu Sans bytes retained in `../NativeListMarkers/fonts/DejaVuSans.ttf`.

PowerPoint 16.113.3 opened the source without repair. The root agent selected
local **Best for printing**, with the online option off, and did not save the
source. `capture-receipt.json` retains the GUI receipt. Source and PDF pins:

- Source: `e261b6864780fb021e914dfcd4a0e19b3aae9825cc33b94b0168933dcf057268`
- PDF: `02d7eb7e7e727717ddd4e9a56cecb65f619eec747041f51eade7b22819d766a5`
- Font: `7da195a74c55bef988d0d48f9508bd5d849425c1770dba5d7bfc6ce9ed848954`

## Observed behavior and implemented boundary

Missing `tcStyle`, empty `tcStyle`, empty `tcBdr`, and fill-only custom styles
retain black 1 pt grid edges. An explicitly present empty line or `noFill`
suppresses its edge. Explicit style and direct cell lines retain their paint;
fill-only regional overrides preserve applicable edges from `wholeTbl`.
Referenced and inline fill-only definitions agree.

The resolver supplies defaults only for absent effective cardinal declarations
in actual package or inline custom definitions. An active unresolved wrapper or
`lnRef` blocks default insertion; it does not erase a previously resolved line.
Direct cell overrides remain last. This does not change synthesized built-in
styles, unknown IDs, absent applied IDs, text styles, or import algorithms.
Public `TableStyleResolver.border` reports resolved defaults; `cell.border`
continues to report authored properties. Reading/rendering never materializes
these defaults in document XML.

The two partial grids add a separately calibrated join profile: unmerged LTR
positive grids with opaque solid borders, where every individual grid line has
one color and width. Existing donor, ownership, draw-order and uniform-grid
paths are unchanged. Arbitrary collinear color/width transitions outside the
previously calibrated axis-color profiles, combined colored RTL or merged grids,
and the previous unsupported paint/geometry conditions retain their existing
fallback. Earlier S17/S18 assertions and
bounds are unchanged.

## Independent references and strict checks

`capture.py` retains raw PDF content, vector operators, path order and all body
text traces in `native-vectors.json`, then mechanically projects
`paint-reference.json`. It asserts that all fills precede strokes in each
specimen. It does not infer border ownership or synthesize expected geometry.
Glyph trace bounds are not an independent source-outline ink proof.

The native vector bound is 0.001 pt; normalized RGB is 0.0001; opacity and width
are preserved. Identically painted adjacent intervals alone may coalesce.
Ordered paint is checked across the complete rectangular subdivision formed by
all native and renderer fill/stroke bounds. This protects colored overlap
ownership, not merely the unordered union of strokes. There is no raster or
antialias boundary claim.

All native body scalars are consumed. Glyph x uses 0.025 pt and paint size uses
0.002 pt. These new frame positions expose a maximum vertical print-position
residual of 0.119995 pt; the test uses the already established 0.121 pt bound and
retains each residual in `glyph-residuals.json`. No typography formula changed.
`baseline-text.json` additionally pins every complete original library body
text node, including scalar x lists, transforms, paint sizes, face/feature
attributes, and text. The test compares these exactly and verifies actual
registered font bytes against the licensed fixture.

Before production changes, the strict native test failed with 30 issues:
12 interval counts, 12 complete-paint comparisons and six existing endpoint
comparisons. Glyph and fill checks already passed. `model-proof.json` is the
retained pre-edit offline proof: all 49 intervals match with zero endpoint
residual, and every open region in the complete opaque paint subdivision
matches. `model.py` reproduces that proof using compact frozen baseline
public-read/fill inputs in `model-input.json`; it writes a separate
`model-reproduction.json` rather than overwriting the original receipt.

The Swift suite also covers unresolved and valid references, higher-ranked
neighbor declarations, explicit empty/noFill, namespace aliases, live style
and insertion-default edits, direct overrides, unknown IDs, style-ID import
collisions, deterministic SVG, source purity and save/reopen. Controlled import
preview comparisons explicitly register the source font; slide import does not
claim to transfer presentation-level embedded fonts.

## Reproduction and status

Use a copy of this directory beneath the repository's ignored `.build` folder.
Research-only Python dependencies are python-pptx, lxml, fontTools, PyMuPDF and
pypdf; they are not runtime dependencies of Rostrum. `generate.py` reproduces
the source PPTX byte-for-byte. After restoring the accepted PDF and capture
receipt, run:

```sh
python3 capture.py 02d7eb7e7e727717ddd4e9a56cecb65f619eec747041f51eade7b22819d766a5
python3 model.py
```

Both raw and compact extraction outputs reproduce byte-for-byte. The offline
model reproduces all 49 intervals and every paint region. Run the portable
regression with `swift test --jobs 2 --filter NativeTableStyleFallbackTests`.
The final local full suite passed 1,185 Rostrum tests in 172 suites and 18
RostrumLayout tests in three suites. `verification.json` pins commands, logs,
source and scripts. Independent review, combined app/native acceptance and
performance measurement remain parent-owned. No speed or memory claim is made.
`PROPOSAL.md` and `baseline-receipt.json` are historical pre-implementation
research records; their pending language describes that earlier checkpoint.
