# Native applied table style versus insertion default

PowerPoint 16.113.3 opened both owned one-slide decks without repair. Root exported
local Best for printing with online conversion off and left source PPTX files
untouched. Each group retains the exact source, accepted PDF, capture receipt,
raw PDF content/operators and extracted vector paths.

| Group | Source SHA256 | Native PDF SHA256 |
| --- | --- | --- |
| builtin | `3583235fd4a0caf7be17fad4e79d250ac1098e0a4f64ce462c9a396d91a5873b` | `8b668d179dbf79a9d77265c24e986cab648244ab7ea134e89e4ebbedf7170b27` |
| custom | `5506d837f8a12b4f6a54cca287c9f2943b22d2537270aa084e83792aad65652e` | `db76f7094ee5d2eea822aac578f1a21e30389bd73f9dc5ba51b09c0e2246ee31` |

All eight cases use a colored background and fixed 111.01 × 160 pt tables.
Every body retains actual embedded DejaVu Sans, `Agjp`, 14.5 pt, zero kerning,
center alignment, zero insets and stored 100% font scale. The 32 visible body
glyphs are consumed by the PDF trace. This is a paint/style-selection oracle;
these traces do not establish new general font identity or text-style rules.
The source font bytes reuse `../NativeListMarkers/fonts/DejaVuSans.ttf` and its
license. Font pins are in each manifest.

Both absent-ID controls draw transparent cells and black 1 pt grid borders,
whether the insertion preference names a built-in or a package-defined style.
Explicit Medium 2 uses pale fill and white lines. Explicit No Style, Table Grid
matches absent ID; explicit No Style, No Grid has no paint. Explicit and inline
custom styles use magenta fill and cyan 2 pt borders. The absent-ID direct
control keeps its orange fill, green 2 pt left edge and suppressed right edge;
the other edges remain black 1 pt.

Before the correction the resolver promoted `tblStyleLst@def` to an applied ID.
Its public rendering and slide-import path therefore assigned unrequested paint.
Ten native/import assertions failed before production changes. The read-only
style correction uses the existing transparent grid definition for an absent
applied ID, while preserving explicit IDs, unknown-ID behavior, inline precedence,
direct overrides and live DOM changes. Slide import retains absent properties
and IDs instead of materializing the source insertion preference. Earlier synthetic
implicit-default import assertions are reconciled against this independent evidence;
explicit dependency and collision checks remain intact.

The direct control also exposed the renderer's previously excluded mixed-width
corner joins. Its exact endpoint regression is retained without tolerance changes;
the supplemental `NativeTableJoins` evidence governs the separate geometry
correction. No general dashed, translucent, compound or diagonal join claim follows.

## Reproduction

Python tooling requires python-pptx, lxml, fontTools, PyMuPDF and pypdf, exclusively
for development oracles. The library remains dependency-free.

```
python3 Tests/RostrumTests/Fixtures/NativeTableDefault/generate.py
python3 Tests/RostrumTests/Fixtures/NativeTableDefault/capture.py builtin
python3 Tests/RostrumTests/Fixtures/NativeTableDefault/capture.py custom
swift test --jobs 2 --filter NativeTableDefaultTests
```

The compact `paint-reference.json` is a mechanical projection of the complete
`native-vectors.json`; no Rostrum output supplies expected paint. Tests compare
fill counts/bounds/colors/opacities and every border's endpoints/color/width/opacity.
Bounds are 0.001 pt for raw native coordinate precision and 0.0001 normalized RGB
for the PDF color quantization. These are finite vector comparisons, not raster
parity assertions. Native glyph-position fixture tolerances are unchanged.

Microsoft's published ISO text corroborates the distinction: `tblStyleLst@def`
is a preference usable when inserting a table, while `tableStyleId` identifies
the currently applied style. These descriptions do not replace the native oracle:
[TableStyleList](https://learn.microsoft.com/en-us/dotnet/api/documentformat.openxml.drawing.tablestylelist?view=openxml-3.0.1),
[TableStyleId](https://learn.microsoft.com/en-us/dotnet/api/documentformat.openxml.drawing.tablestyleid?view=openxml-3.0.1).
