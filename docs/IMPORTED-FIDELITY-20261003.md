# Imported slide fidelity — 2026-10-03

The acceptance input was a private 22-slide PowerPoint deck whose Duo screenshots exposed missing curved decorations, missing SVG-only images, an empty SmartArt placeholder, overlapping titles/body text, mid-word title breaks, and blank numbered paragraphs rendered as list entries. Source files, fonts, and rendered references remain outside version control.

## Changes

- Render DrawingML custom paths with lines and quadratic/cubic curves, guide coordinates, per-path fill/stroke, and stroke widths independent of the path coordinate scale.
- Resolve basic self-contained SVG images, including Office SVG extension relationships with no raster fallback. Reject unsupported or active/external SVG content while preserving the original package bytes.
- Render an existing SmartArt drawing cache and its saved text bounds. Missing or unsupported caches retain an explicit placeholder and diagnostic.
- Inherit text-body properties and placeholder list styles through the layout and master. Apply all-caps before text measurement. Preserve empty-paragraph spacing without drawing/advancing list markers. Move center/right-aligned bullets with their text and use the text size without its underline or baseline shift.
- Honor hidden flags on shapes and entire groups without deleting their content.
- Keep viewer glyph proportions when only estimated font widths are available; force measured widths only for registered faces.
- Use a registered regular face when a requested style is unavailable, with an explicit synthesis diagnostic. No platform font lookup was added to portable Rostrum.
- Cache bounded base64 font resources across slide renders, invalidating on registration. Avoid dictionary construction and sorting for verified, ordered, single-scalar ASCII glyph runs.
- Add the offline **Imported artwork and text** Library Lab recipe with saved/reopened, source-preservation, and preview checks.

## Visual acceptance and limits

All 22 slides were compared with native PowerPoint PNG exports, using the same explicitly registered local fonts in Rostrum. WebKit rasterized the resulting SVGs after fonts loaded. The comparison establishes substantial improvement for this deck, not universal or pixel-identical PowerPoint compatibility.

The missing curves, rings, triangular decorations, patterned panels and saved SmartArt text now appear. The overlapping title/body and blank list markers are corrected. A follow-up corrects bottom/center anchoring with exact line spacing: the final line no longer carries the gap reserved for a following line. Against native PowerPoint at 960×540, title ink rows on slides 4, 14, 18 and 19 moved from 9–13 pixels too high to within 0–1 pixel of the reference. A native PowerPoint probe also established that automatic numbers use the paragraph text face, even when an explicit or themed bullet face is present; character bullets still use the bullet face. The renderer now makes that distinction. The image-heavy slide’s extra number was explicitly hidden in the source; hidden-shape rendering is now corrected.

Custom arcs, shaded per-path fills, custom geometry text rectangles, nontrivial SmartArt root transforms, and general SVG/CSS are not supported by this change. SmartArt rendering uses the saved drawing snapshot; PowerPoint can regenerate its layout. Small capitals remain diagnosed. The source deck does not embed its fonts: consumers must register appropriate fonts, and iOS font availability differs from the Mac reference. These fixes do not themselves update an installed Duo build.

## Verification method

`ImportedGeometryRegressionTests` covers custom coordinates/strokes, unsupported paths, inherited anchors, all-caps and empty lists, aligned markers, marker decoration, cached/missing SmartArt, SVG-only image resolution, rejected active/external SVG, deterministic reopen, and read-only rendering. `FontFaceTests` covers encoded-resource invalidation and exact lookup versus preview fallback.

The completion gate is `./scripts/verify.sh`: workflow checks, Rostrum and RostrumLayout tests, LecternCore tests and all Library Lab recipes, README examples, macOS/iOS builds, and app-hosted tests. Mac build/test wrappers explicitly apply their existing manual signing policy to SwiftPM resource bundles too; the configured stable signing identity is retained.

The private Release timing harness loads one fixed deck and four explicit font faces once, then renders all 22 slides 16 times at 960 pixels. Every repeated SVG must be byte-identical. The first pass is excluded from the warm median; file I/O, font registration, and WebKit rasterization are excluded. Interleaved runs compare the implementation before the cache/ASCII optimization with the final implementation. This measures library rendering only, not device scrolling or startup latency.

## Measured result

Five interleaved Release runs (15 warm full-deck passes each) measured a pooled median of 57.30 ms before the font-resource/ASCII optimization and 47.85 ms after it, a 16.5% reduction on this Mac. Both binaries include the new geometry and SVG support; a small marker-style correction also separates them. This is a bounded workload result, not an isolated attribution to each optimization.

The generated Imported artwork and text PPTX was opened in native PowerPoint without a repair prompt. Its curved decoration, SVG triangle, and numbered list were visible; PowerPoint regenerated the SmartArt layout from the model, as expected.

## Exact line spacing follow-up

The title master declares 48.75pt exact line spacing, while slides 14 and 18 use 30pt text (36pt natural DrawingML line box). A 12.75pt trailing gap was incorrectly counted in the anchored block height. The fix preserves line pitch between lines and paragraph spacing, excludes only the final surplus gap for supported DrawingML metrics, and retains the measured descent for reduced/overlapping lines. Generic fallback metrics are unchanged. Regression cases cover top/center/bottom anchoring, one/multiple lines, mixed sizes and fitting. The private comparison records per-line ink bands before and after; it is not a claim of pixel-identical rendering.

## List style inheritance follow-up

Marker font and size choices now inherit as groups. A nearer `buFontTx` or `buSzTx` explicitly follows the first text run and suppresses a farther fixed font or size. A nearer percentage size likewise suppresses inherited point sizing. Previously independent lookups could apply both size alternatives or ignore follow-text. A regression reproduces six failed assertions before the fix across paragraph, layout and master styles, and checks the expected font/size after 50% autofit without changing the body run. The separate automatic-number font correction is documented below.

## Automatic-number font follow-up

A six-row probe opened in native PowerPoint without repair compares automatic numbering with explicit Arial Black, themed major, explicit Times New Roman, and follow-text font choices against two character-bullet controls. With Times New Roman body text, all four automatic numbers use Times New Roman; both character controls use Arial Black. Rostrum now applies a separate bullet face only to character bullets. The regression covers local and inherited explicit/theme faces and fails four assertions before the fix. Only slide 5 changes in the private 22-slide SVG comparison.

The first scratch probe had its bullet elements after `defRPr`, violating paragraph-property child order; PowerPoint ignored those markers. That probe was rejected and rebuilt in schema order before recording native behavior. No private deck or proprietary font is committed.

## Viewer-font run positioning

The actual iOS simulator check exposed overlapping mixed-style runs when the requested font is unavailable: each run started at an estimated absolute position, while WebKit drew the preceding run at its real substitute-font width. Adjacent runs now follow the viewer's actual advance after an unregistered face. Explicit line, tab and list-marker boundaries retain absolute positions; fully measured lines retain their existing output. A regression checks mixed registered/unregistered faces, style changes, tab and list boundaries, and unchanged source bytes. Missing-font diagnostics remain; this prevents intra-line overlap without claiming equivalent font substitution or exact wrapping.

### Measured missing-font previews

The final iOS sweep exposed title/image collisions when an unavailable font was measured with generic advances but drawn by WebKit with wider fallback glyphs. Hosts can now explicitly select a registered `FontLibrary.previewFallbackFamily`; the layout and SVG use the same face, while exact lookup and document font names remain unchanged. Lectern inspection and Duo register Arial as their preview fallback. Missing-family diagnostics and strict refusal remain. This improves readable fallback rendering, not native-font equivalence.
