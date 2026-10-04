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

## List markers and hanging indents

`native-list-markers-v2.pptx` and `native-list-markers-followup-v1.pptx`
are byte-for-byte copies of the owned independent Python/OOXML inputs under
`Tests/RostrumTests/Fixtures/NativeListMarkers`. Their source SHA-256 values are
`db317bc89840fc1dea1d4abf11fdd26e8c08c470dd86dee822ed8f01987a92d8` and
`6baeaa1cb40ccd22f512aa6e9f14dcc9b21024139bde29cc14d96ed03095b1dd`.
PowerPoint 16.113.3 opened both without repair and exported local Best for
printing PDFs, with the online option off and source documents unchanged.
Native PDF pins are `4153ef4949c6aa554497ab16958f62016d8406d06d6cc88b1842e9d40920f1ea`
and `745576408a02c63c21dca8c243847ef1cf89163758e948e3c3faec61ee59452c`.

`ListMarkerReferences.json` retains all 24 cases, 277 visible glyphs and three
explicitly absent inherited markers, with source frames, bodies, font pins,
actual PDF paint matrices, source outline bounds, glyph origins and body line
strings. The decks embed licensed DejaVu Sans regular and bold and DejaVu Serif
regular; the existing `LICENSE-DejaVu.txt` applies. Identical bullet outlines
retain multiple compatible source faces rather than claiming unique identity.

The recipe imports the followup through public `slides.importAll`, retaining
its distinct master and placeholder inheritance. Native frames and text bodies
remain unchanged. Captions outside those frames use bundled DejaVu Sans instead
of the source's Calibri, so the demo does not require installed platform fonts.
Actual SVG font bytes must match the registered embedded faces. All native
marker and body scalars are consumed; per-case finite origin tolerance is
0.06 pt, baseline tolerance 0.121 pt, and paint/outline dimensions 0.002 pt.
These bounds cover the captured PDF export drift, not arbitrary long text or
pixel parity. Explicit x lists must not be replaced with glyph stretching.

A fifth slide compares two public computed fitting paths in 130 by 45 pt
copies. Both options retain all 24 originals; the alternative selects the
6 pt rather than 18 pt hanging indent for these copies. Fitting preserves
paragraph/run properties and is not a native-autofit-choice claim. Core tests
retain both generated decks and SVGs when `LECTERN_MARKER_ARTIFACTS` is set.
`LibraryListMarkerAppTests` exercises the real saved-file inspector, all five
previews, export, and return to the completed demo. Manual GUI and native
acceptance are separate integration checks, not implied by Core success.

Regenerate this reduced reference with
`python3 Lectern/scripts/generate-list-marker-references.py`. The development
script verifies fixed source, PDF and font pins before copying; it never derives
expected positions from Rostrum.

## Text alignment

`native-body-alignment-v1.pptx` is an exact copy of the independent native input
under `Tests/RostrumTests/Fixtures/NativeBodyAlignment`, SHA-256
`98c27b081f8ecb9c297d46e04019b83bcdc969ed3d42113f89491aa0b9d70dac`.
The PowerPoint reference PDF has SHA-256
`49b3001cee2777ec1c319c191f40836c4c20391a65224b49f6289d54908b6b66`.
`TextAlignmentReferences.json` projects all 24 cases and 172 visible glyphs from
that independent PDF extraction, retaining frames, line strings, exact face
identities, raw paint scales and source-outline/native-ink bounds. The embedded
DejaVu Sans regular/bold and Serif regular faces use the existing DejaVu license.

The four 720 pt reference pages retain every native specimen node, frame, table
property and master link. Only captions outside specimen frames switch from
Calibri to bundled DejaVu Sans. Each rendered page is parsed once and its actual
embedded font data is checked. Bounds remain 0.025 pt for each line's first
scalar x, 0.06 pt for subsequent scalar x, 0.121 pt for baselines and 0.002 pt
for paint scales and ink dimensions. These are finite captured cases, not a
claim of universal alignment or pixel parity. The two stored 50% table scales
remain diagnosed and render at the native full size.

The fifth page uses public text authoring and both public fitting APIs in
separate copies; the alternative chooses center or right alignment only there.
Its fitted scales are computed values, not native autofit choices. Core checks
cover exact source nodes, reopened fit attributes, face bytes and deterministic
SVGs. App tests exercise the actual inspector and folder export; the opt-in
WebKit test captures exact saved inspector SVGs after embedded fonts load.
Capture success alone does not establish native paint parity.

Regenerate the reduced resource with
`python3 Lectern/scripts/generate-text-alignment-references.py` once the pinned
native fixtures are present. Retain generated option decks/SVGs with
`LECTERN_ALIGNMENT_ARTIFACTS`; retain actual WebKit captures with
`LECTERN_ALIGNMENT_WEBKIT_OUTPUT` and `LECTERN_TEST_WEBKIT=1`.

## Mixed faces and exact spacing

The two owned source decks are copied byte-for-byte from
`Tests/RostrumTests/Fixtures/NativeMixedFaceSpacing`:

| Group | Source SHA-256 | Native PDF SHA-256 |
| --- | --- | --- |
| base | `4e12a5e02468873d34fadb0ea415836ee50fa92245d9e096721faee33013c014` | `9d8c125d036eb15b0b0c3f2cf84e6a2b47f0f79812ca003a056814d74ca7268b` |
| anchors | `ade8628fe0ca6c69691ad0790e9678bf92aaa7d2cd3178b5723dcb5c2adc9ea0` | `49ec14886c2dbee1701b25039f362c221569957742a20d82ea0b18dd84af1c64` |

`MixedFaceSpacingReferences.json` retains the 12 independently captured cases,
96 visible glyphs, two source page identities, per-glyph actual face, native
baselines/origins, raw paint scales and source-outline/native-ink bounds. The
source decks embed the licensed DejaVu Sans and Serif regular resources; the
existing DejaVu license applies. The projection script pins and verifies both
source/PDF pairs and actual font bytes before copying evidence. Expected glyph
geometry never comes from Rostrum.

The recipe imports the second page through `Slides.importAll`. All 12 native
specimen nodes, frames and master links remain intact. Only captions outside
the native frames switch from Calibri to bundled DejaVu Sans, so full generated
pages are not byte-identical to the native input. Per-page SVG parsing is reused
for every case. Each glyph must use its own actual embedded face; a case-wide
font assumption would miss the mixed runs. Tolerances remain 0.025 pt for the
line's first scalar x, 0.06 pt for remaining scalar x, 0.121 pt for baselines,
and 0.002 pt for paint scales and ink dimensions.

The supported extension requires actual distinct faces with equal normalized
Windows ascent share and height, shape context, exact point spacing, compatible
spacing and zero reduction. The demo checks the two real source font resources'
OS/2 and head fields against the independently projected metric signature.
Unequal metrics, mixed-face percentage spacing, table contexts and rejected
paint profiles retain their existing fallback/diagnostic boundaries. This is
not a universal mixed-font or pixel-parity claim.

A third page copies the captured mixed body into two outlined 290 by 40 pt
shapes and invokes the two public fitting APIs separately. The alternative
changes only these copies from top to bottom anchoring. Both compute 100% scale
and zero reduction from a 37.33489932885906 pt unrounded content extent. The
fitter writes the schema-default bare `a:normAutofit` element; paragraph/run
properties remain exact. These are computed fits, not native-selected autofit.

Core tests retain both generated variants when `LECTERN_MIXED_SPACING_ARTIFACTS`
is set. App tests cover real inspection and folder export. The opt-in WebKit
capture uses exact saved 640 px inspector previews of the first two pages,
waits for embedded fonts and retains raw PDFs; independent extraction remains
necessary to establish native paint agreement. Set
`LECTERN_MIXED_SPACING_WEBKIT_OUTPUT` and `LECTERN_TEST_WEBKIT=1` to retain it.
Regenerate resources with
`python3 Lectern/scripts/generate-mixed-spacing-references.py`.


## Table defaults and border joins (2026-10-04)

`native-table-default-builtin-v1.pptx`, `native-table-default-custom-v1.pptx`
and `native-table-joins-v1.pptx` are exact copies of the independently captured
library fixtures under `Tests/RostrumTests/Fixtures/NativeTableDefault/{builtin,custom}`
and `NativeTableJoins`. `TableDefaultsReferences.json` combines those three
`paint-reference.json` arrays without changing their values, adding source/group
and destination slide indexes. Its source records pin source PPTX, native PDF and
embedded DejaVu Sans bytes. The existing DejaVu license applies.

The runtime recipe preserves all 12 complete native table nodes and their
frames/font bytes. Only captions outside those specimens switch to the bundled
face. Three pages contain 72 visible glyphs: the glyph references are PDF text
traces of origins and sizes, not source-outline ink measurements. Independent
vector fill and border comparisons retain .001 pt geometry and .0001 normalized
RGB tolerances. Only touching collinear identically painted opaque strokes may
coalesce; widths, colors, opacity, gaps and different-color paint order survive.
Cell dimensions must exceed the widest stroke in the admitted rectangular,
unmerged LTR join profile. Glyph first-origin grouping is specific to the
captured unwrapped Agjp strings, one per cell. The fourth public authoring page
is outside the native numerical corpus.
