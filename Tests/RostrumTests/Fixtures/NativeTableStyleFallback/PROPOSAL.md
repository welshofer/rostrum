# Fidelity19: partial custom-style edge defaults — native evidence, no production edits

Baseline b5407e49f1173edeeb3285fcef6ad763840d3f79, isolated branch codex/burndown/table-style-fallback19-20261004. Root independently opened the12-case/two-page source without repair in PowerPoint16.113.3, selected local Best for printing with online off, and did not save the source. Source SHA256 e261b6864780fb021e914dfcd4a0e19b3aae9825cc33b94b0168933dcf057268; native PDF SHA256 02d7eb7e7e727717ddd4e9a56cecb65f619eec747041f51eade7b22819d766a5. Capture receipt and raw ordered page content are retained.

## What the capture proves

All12 cases and72 visible body glyphs were consumed. Native paints49 canonical border intervals; baseline paints6 and omits43. All15 cell fills already match their native bounds, colors and opacities. Existing declared border keys match; their endpoints differ because missing neighbors cannot donate native corner extensions.

- Missing tcStyle, empty tcStyle, empty tcBdr, and fill-only styles all retain opaque black1pt grid edges.
- Referenced and inline fill-only definitions behave identically.
- A present empty left ln suppresses that edge, just as explicit noFill does; absence and emptiness must remain distinct.
- Explicit green2pt style left and blue4pt direct left retain their paint; unspecified other edges remain black1pt.
- Direct right noFill suppresses its edge while leaving the other default edges.
- Both2×2 controls retain unspecified outside and insideV edges as black1pt. A firstRow fill-only region overlays fill without erasing wholeTbl left/insideH declarations or the unspecified-edge defaults.

Public TableStyleResolver.border currently returns nil for missing edges, an existing empty ReadLine for an empty ln, and isNone for explicit noFill. The source cause is TableStyleResolver.styleProperties: properties starts empty and only explicit regional edges are appended. SVGRenderer.borderPaint deliberately rejects missing/noFill/no-color lines. Therefore the empty-line behavior is already correct and should remain unchanged.

## Bounded source proposal

After existing region/boundary resolution, before the direct-cell overlay, provide a black1pt solid line only for each absent cardinal edge in an actually resolved package-owned or inline style. Do not fill missing attributes or children within a present line. Do not create diagonals, change text/fills, mutate authored XML, add persistent caching, or change unknown/unresolved ID behavior. Leave synthesized built-in definitions and absent-ID17 behavior as they are. Missing-edge allocations should occur only for this custom-definition path and only for the edges still absent; avoid building discarded fallback XML for complete styles.

This shared resolver change must drive both the public resolved read API and rendering. The direct cell.border read remains authored-only. Existing inline precedence, style alias handling, neighboring region inheritance, explicit noFill/empty declarations, and live DOM behavior must survive. Slide import requires no new algorithm: controlled-font baseline preserves read results and full SVG on reopen/import, including an explicit custom-ID collision that remaps atomically. The initial unregistered import attempt is retained separately: slide import does not transfer presentation-level fonts; the controlled comparison registers the exact pinned face explicitly.

## Separate geometry consequence already exposed

The two partial-grid cases have color variation across different grid lines, outside S18's one-color-per-axis guard. They have constant color AND width along each individual grid line. Their native order is still interior vertical, interior horizontal, outer vertical, outer horizontal. Their terminal extension magnitudes exactly equal half of the perpendicular donor width (e.g. green2pt left means horizontal starts one point before frame). No collinear color or width transition appears in these two cases.

A style-only fix must NOT report these cases as full endpoint matches. Options for parent approval: retain their strict failures pending a separate geometry increment, or admit this additionally captured unmerged-LTR profile where every individual grid line has constant opaque solid color AND width. The latter would be a separate bounded renderer guard addition, leaving mixed/merged/RTL combinations and arbitrary collinear transitions unsupported. No tolerance widening or known-issue masking is proposed.

## Text and measurement limits

Glyph x origins differ at most0.008225pt. Native y origins differ by up to0.119995pt on the new non-grid-aligned frame/row positions: native78.959961 versus library79; native509.040039 versus509; native578.880005 versus579. These residuals are preserved in glyph-residuals.json, separate from border geometry. They resemble the already-recorded native print-grid baseline effects but this pass does not establish or change a text-positioning formula. Body count/text, exact source font, paint size and original library text output must remain protected. Existing native fixture tolerances are untouched; any new glyph assertion must label its finite vertical residual explicitly, rather than quietly adopting the previous .025pt two-axis bound.

## Required strict regression matrix

All12 native style choices, all49 intervals and raw ordered paths, explicit empty/noFill distinctions, and15 fills. Public resolved versus authored-only reads. Direct overrides, inline versus referenced definitions, missing entire containers, region inheritance, differently styled import destination with colliding IDs, live definition/default/style-ID edits, registered aliases, unknown ID unchanged, source/save/reopen purity and deterministic SVG. Existing17/18 vector and typography oracles stay strict. The generator and baseline helper contain no production modifications or timing claims.
