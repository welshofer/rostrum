# Layout fidelity and performance — 2026-10-03

This follow-up to FUNC-2 and PERF-1 implements paragraph word-space justification,
removes measured redundant shaping work, and makes the new layout behavior
exercisable offline in Lectern. Animation remains outside this pass.

## Paragraph layout

`RichTextLayout` now expands interior U+0020 spaces for DrawingML `algn="just"`
after natural line breaking and font shaping. The same measured spans feed
fitting and SVG rendering. Mixed styles, inherited alignment, margins and hanging
bullets retain their geometry; paragraph-final lines and one-word lines retain
natural spacing. Explicit `a:br` breaks still justify the preceding line.

The [independent PowerPoint fixture](../Tests/RostrumTests/Fixtures/ParagraphJustification/README.md)
was authored with python-pptx, opened without repair in PowerPoint 16.113.3,
and exported through its local print PDF renderer. Portable numeric metric
fixtures check first-line word starts within 0.25 points for regular, mixed,
explicit-break and bulleted paragraphs. This is horizontal spacing evidence,
not whole-slide pixel parity. The integrated engine's saved v2 deck also opened
in PowerPoint without repair.

Tabs, RTL/non-Latin justification, `justLow`, `dist` and `thaiDist` remain
explicitly diagnosed approximations. Existing near-boundary font rounding can
still cause a different character wrap from Office. General bidi, columns,
decoration geometry and the outstanding table raster differences remain open.
No existing native reference or fidelity threshold was weakened.

## Measured shaping improvement

The [matched performance report](LAYOUT-PERFORMANCE-20261003.md) records ten
alternating fresh-process baseline/candidate pairs. ASCII graphemes now skip
Foundation NFC normalization; non-ASCII normalization, scalar offsets and
shaping behavior stay unchanged.

| Workload | Baseline | Candidate | Improvement |
| --- | ---: | ---: | ---: |
| Registered-font 2,000-cell table rendering | 95.177 ms | 83.413 ms | 12.36% |
| Rich-text fitting | 19.260 ms | 14.623 ms | 24.08% |

Both improved in all ten pairs. The performance-only change produced identical
SVG, ordered diagnostics, inheritance flags and PPTX across 54 fixture/font
combinations and 576 slides. All 108 saved outputs reopened with python-pptx.
Fallback-font workloads showed no meaningful improvement. These are macOS
arm64/Arial results, without a memory or cross-platform speed claim.

## Lectern

Library Lab now has 24 recipes. **Paragraph spacing and justification** compares
left and justified paragraphs with sentence-count and narrow-width controls,
mixed sizes/colors, a bundled embedded font, both public fitting entry points,
and a table-cell example. Its saved-file checks compare exact spans and SVG
after reopening. App tests exercise both width variants through inspection and
export, checking expanded spaces and exported text. The catalog states the
supported scope and remaining limitations.

## Next fidelity targets

1. Font advance rounding and line-break parity at narrow boundaries, with native
   fixtures before changing the shared layout rules.
2. Paragraph bidi and tab-aware justification, including mixed-direction runs.
3. Multi-column flow and decoration geometry in the same fitting/rendering path.
4. Remaining table border/text raster mismatches against the fixed native gate.

For performance, profile repeated line-fragment shaping and table diagnostics
next. Any reuse must be scoped to one layout/render so mutable source XML cannot
leave stale geometry behind; require paired measurements and output identity.

Integration verification is recorded in the accompanying burn-down report.
