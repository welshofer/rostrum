# Native collinear border transitions

Two independent python-pptx/OOXML decks calibrate unmerged LTR table-border color and width transitions. PowerPoint 16.113.3 opened each without repair and exported a local PDF using Best for printing, online conversion off. The source PPTX files were not saved by PowerPoint. Capture receipts and root visual review records accompany the exact sources and PDFs.

| Group | Cases | Body glyphs | Native intervals | Scope |
|---|---:|---:|---:|---|
| vertical | 8 | 124 | 56 | One existing positive control, six new unmerged cases, one rejected colored merge |
| horizontal | 6 | 116 | 59 | Outer/interior transitions in both directions, noFill donor, 3×3 transitions on both axes |

The production admission covers 13 cases and 107 intervals. The colored merged control remains on its exact pre-fix path, despite the offline endpoint hypothesis agreeing with that single native example. Its 12 glyphs still receive the native text checks. No new merged or colored RTL support is claimed.

All tables use the pinned embedded regular DejaVu Sans bytes from `../NativeListMarkers/fonts/DejaVuSans.ttf`, SHA256 `7da195a74c55bef988d0d48f9508bd5d849425c1770dba5d7bfc6ce9ed848954`. Every visible body run contains `Agjp`, authored at 14.5 pt with explicit kerning zero, full-size stored autofit and no cell inset. Direct border declarations use opaque solid flat centered strokes; neighboring declarations agree. Cell dimensions are at least 60 pt and exceed the widest 4 pt stroke. Explicit noFill controls suppress donors. Captions are outside the specimen frames.

## Independent evidence

- Vertical source: `5db74899fc18508281bc6787e4618a7bd471d27df213a2982cf86dfdccd022d2`; PDF: `b2cf2764cd381e441c7f0639d986905b42c06ba7969e7caa4495ff6c8e4691f7`.
- Horizontal source: `166cc0173a0ce1c899a1e11a29fc6d7f3d00d2da9d40818a7852249c4be07824`; PDF: `198360278444fa0b3c2fe7aa7fa2f528fa1adeb7959d922932538f2b15cbed4e`.
- `cases.json` pins authored frames, every cell property, text body and direct edge declaration. `native-vectors.json` retains complete PDF path order, operators and all 240 glyph traces. Raw page content is retained separately.
- `font-proof.json` records exact decomposed source/subset outlines and units-per-em identity for every body glyph. Trace bounds are not presented as independently transformed ink bounds or raster parity.
- `paint-reference.json` preserves native path order, coordinates, raw color channels, width, opacity and body glyphs. Canonicalization merges only adjacent identical paint and retains every distinct interval.
- The unchanged signed donor-extension hypothesis matches all 115 native intervals exactly and final color in all 1,131 open rectangles of the complete combined stroke-boundary subdivision. The admitted 13 cases cover 1,081 rectangles; the rejected merge contributes 50. This tests ordered overlap paint, not only unordered line unions.

Strict interval tolerance is 0.001 pt and raw RGB tolerance is 0.0001. Native body glyph bounds are x 0.025 pt, y 0.121 pt and painted size 0.002 pt; observed maxima are 0.008301, 0.080078 and 0.00000191 pt respectively. Earlier S17–19 bounds are unchanged. Complete original SVG text nodes and embedded font bytes are also checked exactly, so the new y bound does not permit any library text change.

## Baseline and reproduction

The original research used frozen S20 ancestry. Before implementation, the integrated baseline `5d3d888175d12f615a3f917e15d8c9b6a170f201` was rebuilt and rerendered: all four SVGs, two saved packages and four ordered diagnostic records were byte-identical to that research baseline. `baseline-paint.json` and `baseline-text.json` retain its projections. The text snapshot removes only the SVG namespace declaration introduced by lxml when serializing a detached element; the test parses both fragments and compares complete serialized nodes without removing attributes or painted content.

The strict test failed before the source change with 101 interval assertions and 12 complete ordered-paint assertions. All 240 glyph checks passed. An earlier harness attempt additionally reported 14 namespace-only snapshot differences; its log is retained separately, and the corrected fail-before run is the geometry receipt. The colored merged border projection remains exactly equal to baseline, including order.

Each `generate.py` regenerates its own source and manifest using python-pptx, lxml and fontTools; these are research dependencies only. Run `capture.py <accepted PDF SHA256>` after an independently captured PDF and its receipt are present. `font-proof.py` verifies actual subset outlines. `model.py` reproduces the signed-extension hypothesis using the retained baseline paint and native paths. `compare.py` optionally consumes freshly rendered `before/slide-N.svg` files. Model input is explicitly the pre-fix projection, never a candidate-derived expectation. No production runtime dependency is added.

Only the unmerged LTR branch of mixed-grid admission changes. Existing topology, stroke-size, positive rectangular dimensions, opacity, solid-paint, no-diagonal, uniform-grid, owner, donor and paint-group behavior remains. Colored RTL, colored merges, mixed merge orientations, invalid topology, dashes, translucency, compound borders and oversized strokes retain their previous paths. Three older synthetic transition-negative specimens become explicit positive terminal-extension checks; their rejection siblings remain unchanged.
