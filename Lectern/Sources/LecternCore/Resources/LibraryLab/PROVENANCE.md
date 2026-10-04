# Library Lab offline fixtures and verification

The eight platform recipes call shipped public Rostrum APIs. Their checks run
against authored data and reopen the serialized presentation; no network,
provider, Office font, or external user document is required.

## Assets

- `DejaVuSans.ttf` and `LICENSE-DejaVu.txt` are copied from
  `Tests/RostrumTests/Fixtures/Typography/`. Only the available regular face is
  bundled. Font bytes are unchanged; trailing license whitespace is removed.
  The font is read by pure Swift FontMetrics/TextShaper, not CoreText.
  SHA-256: `7da195a74c55bef988d0d48f9508bd5d849425c1770dba5d7bfc6ce9ed848954`.
- `PlatformSample.mp4` is an owned, synthetic solid-color 32×24 H.264 movie.
  SHA-256: `77251c88edc63eb3527c7b22d33d854c8c4934d20d2f8ae5f93331cfe75ef367`.
- `PlatformSample.wav` is an owned synthetic 440 Hz tone, 8 kHz mono PCM.
  SHA-256: `382562326a4ebe12c7f63acec89d630640bff00a67271331bcf37a8d8c5e8ba9`.

Clips were generated offline with FFmpeg:

```sh
ffmpeg -hide_banner -loglevel error -f lavfi -i color=c=0x276D89:s=32x24:r=4 -t 0.5 -c:v libx264 -pix_fmt yuv420p -map_metadata -1 -fflags +bitexact -flags:v +bitexact PlatformSample.mp4
ffmpeg -hide_banner -loglevel error -f lavfi -i sine=frequency=440:sample_rate=8000 -t 0.125 -c:a pcm_s16le -map_metadata -1 -fflags +bitexact PlatformSample.wav
```

Independent ffprobe inspection on 2026-10-02 confirmed `h264`, 32×24,
0.500000 seconds; and `pcm_s16le`, 8000 Hz, 0.125000 seconds. FFmpeg is a
fixture-generation tool, not a runtime dependency. The owned attachment XLSX
is generated at runtime by Rostrum's chart workbook writer. Group, connector,
and OLE XML is authored in PlatformAssetRecipes; the recipe labels this as
low-level reading/preservation rather than high-level OLE authoring.

## Coverage and limits

Public API sources audited: Presentation/SlideBuilders.swift,
Presentation/Components.swift, Presentation/Design.swift,
Presentation/DeckStyle.swift, Presentation/Theme.swift,
Presentation/Layouts.swift, Presentation/FontEmbedding.swift,
Presentation/Media.swift, Presentation/ShapeTypes.swift,
Presentation/DocumentProperties.swift, OPC/OPCArchive.swift,
Presentation/Validation.swift, and Presentation/DeckExport.swift.
Paths are relative to Sources/Rostrum.

- Layouts compare cloning with public title/bullet builders that bind layouts.
- Fonts compare real glyph positions after exact embedded-font recovery.
- Theme checks scheme links and resolved colors; template outputs reopen as
  POTX/PPSX with typed metadata and chosen canvas dimensions.
- Design runs all 19 shipped builders plus components. Complete slide XML is
  compared across reopening with both sides parsed to normalize attribute order.
- Media verifies extraction bytes, deduplication, group transforms, connector
  target IDs, and preservation of the owned OLE spreadsheet package.
- Package exercises strict/on-access lazy loading, bounded cache, independent
  XML inspection trees, promotion, an explicit decompression-budget refusal,
  and unknown-part/relationship preservation.
- Extraction compares actual Markdown, PNG and chart CSV after reopening.
  Strict supported rendering and expected strict refusal are separate checks;
  notes preview diagnostics remain explicit.

No recipe claims full SmartArt/media SVG fidelity or universal shaping support.
Required-attribute validation is not full XSD validation. Office no-repair and
Linux execution remain integration checks, not outcomes established by this
macOS headless test run.

## Validation receipt

2026-10-02, branch codex/burndown/lectern-platform-20261002:
`swift test --package-path Lectern --jobs 2` exited 0:
`Test run with 201 tests in 21 suites passed after 8.900 seconds.`
PlatformLabRecipesTests runs all eight recipes with both alternatives,
sample-size bounds 2 and 12, actual serialization, reopening, semantic checks,
unchanged-save identity, required-attribute validation, and extra-file checks.
No existing tests were weakened or skipped. Asset-header and pure Swift font
checks and invalid-input tests also passed.

## Native paragraph boundary reference subset — 2026-10-03

`ParagraphBoundaryReferences.json` copies four measured cases from
`Tests/RostrumTests/Fixtures/LineBreakBoundaries/cases.json` and
`native-geometry.json`: `dejavu-18-1`, `dejavu-18-2`,
`dejavu-mixed-size-1` and `dejavu-mixed-size-2`. The source deck was independently
authored with python-pptx; PowerPoint 16.113.3 exported the native PDF. The JSON
retains both hashes, the exact bundled DejaVu Sans font hash and expected line
strings. The full fixture README records native provenance and font-outline
identity verification. No Rostrum result was used as an expected line string.

The native source disables kerning explicitly. Independent HarfBuzz shaping
confirmed identical output for the demonstrated `m/m` and `m/Z` pairs with
kerning enabled and disabled, allowing the public recipe to omit that setting.
Only the unfitted native boundaries are oracle expectations; displayed fitting
scales are computed by the public APIs and checked for persistence and fit.
## Native common Latin words — fidelity4, 2026-10-04

`ParagraphLigatureReferences.json` selects `office-edge-below`,
`office-edge-above`, and `mixed-size-edge` from the independent PowerPoint
`NativeLigatureLayout` fixture. It pins the corrected source presentation, native
PDF, bundled regular DejaVu Sans bytes, and independent HarfBuzz control receipt
by SHA-256. The full capture verifies the native subset glyph outlines against
the embedded font. The selected runs are black; the mixed style is size only.

Native `officeZ` at 18 pt wraps as `offic` / `eZ` at 49.74 pt and `office` / `Z`
at 49.76 pt. The mixed `of` at 18 pt plus `ficeZ` at 12 pt wraps as `office` / `Z`
at the fixed 39.01 pt width. The native fixtures use explicit `kern=0` and
`noAutofit`. Public authoring omits kerning because independent `liga=0`
HarfBuzz controls give identical glyph IDs, advances and offsets with kerning
on/off for exactly `officeZ`, `of` and `ficeZ`. Public originals explicitly call
`setAutoFit(fontScale: 1)` and retain `normAutofit fontScale=100000`; they do not
reproduce the reference's autofit element. Fitted copies use the two public
fitting entry points. Their selected scales are computed, not native autofit
choice expectations. No hidden XML writes or new font resources are needed.
## Native glyph painting — seventh paragraph slide

`ParagraphPaintReferences.json` contains 12 approved cases from the independent
`NativeGlyphPlacement/primary` and `NativeGlyphPlacement/autofit` PowerPoint
fixtures. Each record pins its source deck, source slide, PDF and regular
DejaVu Sans font hash, and retains the original text-body XML, frame dimensions,
PDF paint matrix, visible character origins, source-outline bounds and geometric
ink bounds. Six original cases appear per alternative without modifying their
text bodies or frames. The alternative selects stored font scaling cases.

The recipe reads explicit scalar positions and painted `font-size` from public
SVG output, rejects `textLength`/`lengthAdjust` glyph stretching, and compares
origins within 0.025 pt, baselines within 0.121 pt, and paint scale/outline-derived
ink dimensions within 0.002 pt. These tolerances retain native print-grid
residuals separately; they do not equate authored `Run.fontSize` with painted
glyph size or claim general Office pixel parity. The profile is the bundled
regular face, calibrated printable ASCII, zero insets and the exact recorded
properties; bold/italic, other faces and broad script behavior are outside this
demonstration.

Separate 100 by 20 pt boxes exercise `Shape.fitText` and `TextFrame.fitText`.
Their labels identify computed choices, and their original paragraph/run XML
survives fitting; they do not claim native-selected autofit steps. Captions and
fitting copies use distinct x positions from the original boxes, allowing SVG
checks to select only the original glyphs. Saved checks retain original XML,
fitting attributes, line geometry and deterministic SVG. The exported
`native-glyph-reference.json` carries the complete selected evidence.

The seventh paragraph slide is also captured through Lectern's real offscreen
WebKit host by the opt-in `GlyphPaintWebKitTests` (`LECTERN_TEST_WEBKIT=1`).
The capture saves unmodified SVG/PDF, hashes, loaded embedded-font receipts,
viewport and PDF bounds, and exact original specimen frames. The independent
PDF comparison is a separate acceptance step; serialized SVG attributes and
successful capture alone do not establish native paint parity. The additional
kerning capture uses `eligibility/native-paint-eligibility-v1.pptx`, page 2,
with `kern-threshold14.6-scaled20x72p5` and
`kern-threshold15.1-scaled20x72p5` as the enabled/disabled pair.

The third cell-appearance slide exercises `RichTextLayout.Context.tableCell`
and the live public cell fitting path with bundled DejaVu Sans. It retains a
text frame before changing cell padding, style and anchor: the initial narrow
content width fails, while the final visible cell fits. Both results are
100% scale / zero reduction and leave the stored 50% scale untouched. Explicit
context, actual SVG and saved/reopened state agree; ignored stored table scale
remains a visible diagnostic. A separate Core input fixture verifies that
nonzero stored line reduction is diagnosed and fitting refuses it without
mutation. This demonstrates the native host rule, not a native autofit search.
