# DrawingML baselines: direct PowerPoint evidence

The `text-baseline-v1` fixture contains 30 top-anchored, single-cell text cases:
Arial and Calibri, regular/bold, 14/18/24 points, absent and explicit 100% line
spacing, 24→14 / 14→24 / 18→18 transitions, explicit breaks and automatic wrapping.
The independently captured PowerPoint 16.113.3 direct-slide PDF and PNGs are
pinned in `Tests/RostrumTests/Fixtures/TypographyOffice/manifest.json`. Source
content is CC0; no standalone font binaries or extracted glyph paths are added.

Before measuring baselines, `check_office_baselines.py` verifies all 268 PDF
subset glyph outlines against the exact hash-pinned local Arial/Calibri files.
It checks contour coordinates, contour ends and flags, including composite glyph
coordinates. It then requires the candidate's embedded faces, point sizes, text,
line counts and wrapping to match the reference. All 30 cases produce 46 lines.

The metric rule separates DrawingML layout from generic font measurement:

- Natural line height is 1.2 times the largest point size on the line.
- A face contributes `usWinAscent / (usWinAscent + usWinDescent)` of that height
  above the baseline. Different faces share their largest normalized ascent and
  descent, renormalized to the line box. No family names or image dimensions
  participate in the rule.
- Line advances accumulate without rounding. The resulting content-relative
  baseline is rounded to whole points; body insets are added afterwards.
  Rounding each ascent before accumulation fails the transition/repeated-line
  cases. The SVG does not imitate the PDF export's separate 0.24-point grid.
- Fitting includes the last rounded descent when it exceeds the flow advance,
  particularly under exact spacing or line-spacing reduction. This extent does
  not alter the next line's advance.

The Windows metric pair is read only when both fields fit within OS/2 and ascent
is positive. Missing/truncated/zero metrics retain the existing fallback. Public
`FontMetrics.ascent`, `descent` and `lineHeight` retain their hhea/USE_TYPO_METRICS
contract. Existing explicit point/percentage spacing, fontScale and
lnSpcReduction transformations remain in the shared layout; portable tests cover
these transformations and `fitText`/SVG agreement.

The ratio and 1.2-em hypothesis was also corroborated by an independent producer's
[font-metric experiments](https://github.com/developer0hye/office2pdf/pull/1258).
The acceptance evidence here is our own pinned Office capture, not that project's
implementation. OpenType defines the
[OS/2 Windows metrics](https://learn.microsoft.com/en-us/typography/opentype/spec/os2#uswinascent)
but does not prescribe a universal application line-layout policy.

## Reproduce

Use local, licensed fonts listed in the capture manifest. Create a local font
manifest in the format accepted by `Tools/conformance/check_text_rendering.py`.
Then render the original source with all four `--font` paths:

```sh
swift build
.build/out/Products/Debug/pptx-tool render \
  Tests/RostrumTests/Fixtures/TypographyOffice/text-baseline-v1.pptx /tmp/baseline-svg \
  --font '/System/Library/Fonts/Supplemental/Arial.ttf' \
  --font '/System/Library/Fonts/Supplemental/Arial Bold.ttf' \
  --font '/Applications/Microsoft PowerPoint.app/Contents/Resources/DFonts/Calibri.ttf' \
  --font '/Applications/Microsoft PowerPoint.app/Contents/Resources/DFonts/Calibrib.ttf'
python3 Tools/typography/check_office_baselines.py \
  --fonts /path/to/local-fonts.json --candidates /tmp/baseline-svg \
  --output /tmp/baseline-vector-report.json
```

The checker requires PyMuPDF 1.27.2.3 and fonttools 4.60.1. Exit 0 means the vector
baseline check passes; 1 means baselines differ; 2 means evidence could not be
verified. Its fixed 0.121-point vector tolerance accommodates the PDF's 0.24-point
position grid and floating-point extraction. It does not replace or loosen the
PNG gate (channel tolerance 16, maximum differing fraction 0.005).

Before (`630ee31`, same library sources as the measured `0519cbb`) and after
reports are in `docs/benchmarks/2026-10-02-office-baselines-{before,after,pixels}.json`.
Maximum baseline difference decreases from 2.25480 to 0.12002 points.

| Native PNG | Slide | Before differing pixels | After differing pixels | After fraction | PNG gate |
|---|---:|---:|---:|---:|---|
| 1200×700 | 1 | 6,349 | 5,068 | 0.6033% | fail |
| 1200×700 | 2 | 14,135 | 10,151 | 1.2085% | fail |
| 1200×700 | 3 | 7,468 | 5,679 | 0.6761% | fail |
| 2400×1400 | 1 | 20,051 | 12,601 | 0.3750% | pass |
| 2400×1400 | 2 | 45,003 | 24,844 | 0.7394% | fail |
| 2400×1400 | 3 | 23,763 | 14,584 | 0.4340% | pass |

Raster comparisons use resvg-py 0.5.0, Pillow 12.3.0 and the existing font-aware
adapter, which validates embedded aliases and loads only the pinned local files.

## Evidence limits

This establishes baseline geometry for this fixture, not complete text fidelity.
Four native PNG comparisons still fail. It does not independently qualify glyph
horizontal positioning/rasterization, mixed-family lines, paragraph marks with
different metrics, superscript/subscript, bullets, non-Latin scripts, other
anchors, explicit non-100% spacing or normal autofit against Office. Portable
synthetic tests for some of these layout transformations are implementation
regressions, not native-Office conformance claims. Existing shaping/fallback
warnings remain; this change adds no new strict-rendering guarantee.
