# Table background shadows — 2026-10-02

FUNC-1 / REL-1 follow-up at baseline `189250a4d52f9b0a7bd38c1b5beeb74fe925ae87`.
The [measurement receipt](benchmarks/2026-10-02-table-shadow.json) pins source,
input and reference hashes and records each before/after case. All existing
Office outputs and comparison thresholds are unchanged.

The table renderer now approximates a single background `outerShdw`, either
inline under `tblBg/effect` or resolved through `tblBg/effectRef`. It uses the
authored offset direction/distance, theme-aware color and alpha. A Gaussian
filter uses half the DrawingML blur radius as its standard deviation. Its alpha
mask comes from the combined cell/background fills and borders; text stays
outside that group. Filter bounds include blur, offset and border width.

This is a bounded approximation. The DrawingML attributes specify the
[shadow geometry and color](https://learn.microsoft.com/en-us/dotnet/api/documentformat.openxml.drawing.outershadow?view=openxml-3.0.1);
SVG provides the [Gaussian filter primitives](https://www.w3.org/TR/SVG11/filters.html).
Those specifications do not establish identical Office and SVG blur kernels.
The renderer therefore retains a located approximation issue and strict-mode
refusal. Scaled/skewed shadows, multiple effects, missing colors, malformed
coordinates and 3D combinations retain omission diagnostics. Only the exact
background effect that is drawn changes from omission to approximation; other
cell/style/shape effects retain their existing reports. Source XML is not edited.

## Independent comparisons

All whole-image comparisons use 1,200 × 700 pixels, channel tolerance 16 and a
maximum differing fraction of 0.005. Boundary probes are separate evidence.

| Comparison | Before | After |
| --- | --- | --- |
| Style-boundary LTR whole PNGs | 24 / 36 pass | **36 / 36 pass** |
| Style-boundary RTL whole PNGs | 24 / 36 pass | **36 / 36 pass** |
| The 12 shadow cases in each set | 5,594–5,878 differing pixels | 12–280 differing pixels |
| All stable style-boundary probes | 216 / 216 pass | 216 / 216 pass |
| Double-border whole PNGs | 26 / 29 pass | 26 / 29 pass, identical reports |
| Double-border PDF geometry | 29 / 29 pass | 29 / 29 pass, identical reports |
| Independent v3 whole PNG | 17,314 differing pixels, fails | 17,314 differing pixels, fails; identical SVG |
| Native-style fill probes | Previously 1,480 / 1,480 | 1,480 / 1,480 pass |

The full style corpus's worst residual is 2,010 pixels (0.2393%), in an unchanged
case. The PDF run's maximum error is 0.0001220703125 pt (native slide 25 band
bounds), under the unchanged 0.001-pt gate. Direct-case vertex maximum is
0.00011694204865608683 pt. The earlier checkpoint quoted only the latter maximum.

The v3 and double-image failures have substantial border-coverage residuals.
At a representative v3 horizontal edge, Office's pixel is RGB (236,178,159),
while resvg produces (229,153,128). Replacing SVG line primitives in scratch
experiments with mathematically equivalent filled rectangles/paths, or requesting
`geometricPrecision`, did not change the rendered differences. No vector
coordinates or widths were distorted to fit those rasterizer differences.
Typography residuals and the wide diagonal cases also remain open.

The independent style controls are text-free. They qualify the bounded visual
change in those tables, not every custom background, text-shadow interaction,
advanced compound border, effect, or complete table/PowerPoint fidelity.

## Verification and reproduction

- `swift test --jobs 2`: **958 tests / 130 suites pass**, 38.671 seconds.
- Focused table/shadow/diagnostic checks: **39 tests / 5 suites pass**, 1.786 seconds.
- `swift build --jobs 2`: pass.
- New tests cover direct and theme-reference shadows, placeholder color/alpha
  transforms, live theme edits, effect locations, strict refusal, source-byte
  preservation, save/reopen, diagonal stroke bounds, and unsupported inputs.

The first development test attempt found a test call missing its required text
style; the second found four lexical number assertions that expected `0.25`/`0`
instead of equivalent `0.2500`/`0.0000`. Tests now compare numeric attributes
numerically. The final focused and full runs above passed; no renderer tolerance
or behavioral assertion was relaxed.

Use the existing [double-border checker instructions](../Tests/RostrumTests/Fixtures/DoubleTableBorders/README.md)
to compile `render_table_oracle.swift`. Render the three unchanged `.pptx` files
and run `check_double_table_borders.py` with `--styles`, `--styles --rtl`, or no
flag respectively. Run `--pdf` separately with PyMuPDF 1.27.2.3. The raster
interpreter for this run was `/tmp/rostrum-visual-oracle/bin/python`, with
resvg-py 0.5.0 and Pillow 12.3.0; the system `python3` provided PyMuPDF. The double
PNG command still exits 1, while both style PNG commands and the PDF command
exit 0.

For v3, register the four hash-pinned faces in the receipt before rendering the
first slide. `pptx-tool render` accepts repeated `--font PATH` arguments. Pass
the resulting SVG and a `{"fonts":[{"family":...,"path":...,"sha256":...}]}`
manifest to `check_text_rendering.py`, with the pinned `python-tables-v3-office.png`
reference and `--width 1200 --height 700`. This remains an expected failing gate
(exit 1). The receipt retains exact aliases, font hashes and candidate SVG hash
from the measured 1,200-pixel renderer invocation.
