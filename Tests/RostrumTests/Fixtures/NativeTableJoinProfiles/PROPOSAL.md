# Fidelity18 grounded proposal — production unchanged

Baseline: 5d3d3b5a8d88c685c80c03813a3e13e4522d57fe on isolated branch codex/burndown/table-joins18-20261004. Parent independently captured source39a1ed0ccef5faeda6608bb74528b541dc197a6f4ab3f6d6a05e54cfdd0a663e as local PowerPoint16.113.3 PDF76fb8fb6e663efe692e15873ee51d21bc1e6a85e759d0a4527c02742a1874e46, no repair/source save, printing on/online off. Exact receipt and all raw page operators are retained.

## Strict evidence

`baseline-comparison.json` and `strict-fail-before.log` retain7 failing cases and69 failing painted intervals, maximum endpoint error1.5pt at unchanged .001pt bound. The LTR control passes. Same-paint adjacent collinear intervals are compared without discarding any distinct width/color/opacity. All edge coordinates excluding terminal extensions, widths, colors and opacities agree. No missing/extra body scalar:112 total; maximum origin residual .008225pt at existing .025pt bound. Render is deterministic, read-only, and saved/reopened output is exact.

The two horizontal-merge glyph groups have identical frame-relative origins; absolute360pt displacement is their source-frame offset. Both vertical merge controls likewise agree. No text-placement defect is established.

Native merged matching/conflicting controls have identical frame-relative border paint. Existing owner selection already discards the conflicting hidden continuation declarations correctly. No ownership or merge topology change is proposed.

`model.py` applies signed endpoint extension to the actual retained raw fallback line primitives entirely outside the library. It matches all69 native failing intervals with zero endpoint residual. RTL horizontal physical left/right ends require swapping logical lower/upper extensions. This is a direct mirror of observed geometry, not a text mirror.

Native colored controls preserve paint sequence: interior vertical, interior horizontal, outer vertical, outer horizontal. With corrected geometry but old cell-order painting,1 of9 distinct-color overlap midpoint samples per case is wrong. Grouped order yields0 wrong samples in both color-swapped cases (`model-proof.json`). Full path seqno/raw content remains primary evidence; midpoint checks are a separate finite paint-order discriminator, not screenshot/raster parity.

## Small proposed implementation

Only SVGRenderer mixed-join admission and horizontal RTL extension selection need change. TableBorderSegments donor lookup, selected owners, cell geometry, body layout, styles and the established uniform-width path remain unchanged.

Maintain all17 guards: validated rectangular topology, opaque flat centered solid strokes, no diagonals, and each physical row/column dimension greater than maximum stroke width. Extend only these independently captured profiles:

1. Unmerged RTL with a single stroke color.
2. Unmerged LTR with one consistent vertical color and one consistent horizontal color (covers two-color axis crossings, not arbitrary collinear color changes).
3. LTR single-color one-axis merges (rowSpan1 or columnSpan1); retain fallback for mixed RTL+merged, merged+multicolor, or simultaneous two-axis merge interactions.

Existing admitted17single-cell differing corner colors and same-color unmerged LTR remain unchanged. Use linear segment scans/constant donor lookup, no persistent cache or per-glyph work. Map logical mixed extensions to physical left/right for horizontal RTL before the existing emission. Grouped paint order is already present and becomes active through admission.

## Tests and ownership

Add frozen eight-case native fixture and strict before/after vector comparisons, preserving source/PDF/font pins and every body glyph. Add paint-overlap order checks for both swapped colors and source/live-DOM/determinism/save-reopen checks. Preserve old17native expectations; update only synthetic fallback expectations for newly proven profiles, retaining rejection controls for alpha/dash/diagonal/oversized/ragged and uncaptured profile combinations. Keep complete text positions as unchanged controls. Parent owns independent review, Lectern extension, generated native acceptance and measured performance gates.

No production source has changed; no new timing or speed claim. Await parent approval before implementing this scope.
