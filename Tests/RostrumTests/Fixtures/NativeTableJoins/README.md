# Native opaque mixed-width table joins

The four independent controls supplement the style-selection corpus. PowerPoint
16.113.3 opened the one-slide source without repair; root captured local Best for
printing, online off, without saving the source. The exact receipt and raw PDF
operators are retained.

- Source SHA256: `23b9cde5274eda35b5278042caf7a9b9d49f5557a4038be1c4646ffd73d42ede`
- Native PDF SHA256: `36c33f2e3bf35ac8116bc5e4a47d74357f4774f63bfb7b75a055bb9970e94045`
- Four cases, 40 visible body glyphs: unequal four edges; missing top edge; 2×2 mixed shared grid; the same grid with conflicting later-cell edges.

All specimens are 111.01 × 160 pt, use explicit No Style, Table Grid, transparent
cells, flat centered opaque black strokes and actual embedded DejaVu Sans. Full
per-cell XML and edge widths are in `cases.json`. The conflicting controls have
identical native paint, retaining the earlier logical cell's ownership.

## Observed join model

A terminal extends by half the largest perpendicular painted donor's width.
A missing donor contributes zero. Where collinear widths change, the wider line
occupies the crossing, moving their common seam toward the thinner line by that
same perpendicular half-width. Equal-width continuations keep their common seam.
For example, a vertical 2→3 pt transition at y=430 with a 3 pt crossbar has native
seam y=428.5 for both segments. These observations are independent of Rostrum.

The source implementation retains the existing uniform-width path. The new path
requires an unmerged, rectangular, positive-size LTR grid with opaque plain solid
strokes and no diagonals. Multi-cell specimens admit a single stroke color; the
separate one-cell green/black override in NativeTableDefault proves differing
corner colors for that bounded case. Every cell dimension must exceed the maximum
stroke width, conservatively preventing signed contractions from crossing.
Other profiles retain their prior geometry. No new dashed, translucent, compound,
merged, RTL, arbitrary-color crossing or oversized-stroke fidelity is claimed.

The PDF coalesces adjacent identical black strokes. Tests compare contiguous
collinear intervals only when width, color and opacity agree; they do not discard
paint or compare screenshots. All distinct intervals and native endpoints remain
strict within 0.001 pt, with colors/opacities/widths checked separately. The 29
pre-fix interval failures are retained in the worker receipt. The original
mixed-width synthetic L case is retained with independently grounded endpoint
expectations; every other old unsupported-junction assertion remains unchanged.

## Reproduction

```
python3 Tests/RostrumTests/Fixtures/NativeTableJoins/generate.py
python3 Tests/RostrumTests/Fixtures/NativeTableJoins/capture.py
swift test --jobs 2 --filter NativeTableDefaultTests
```

The Python dependencies are development tools only, matching NativeTableDefault.
The raw glyph traces establish complete text consumption; they do not establish
a new font-outline or raster-parity guarantee. Font bytes and licensing reuse
`../NativeListMarkers/fonts/DejaVuSans.ttf`.
