# Native centered/right body alignment calibration

This is regression coverage for existing behavior, not a production fix. The
24 independent cases / 172 visible glyphs agree with the unchanged marker14
library baseline `05613d0`. No alignment formula was inferred from Rostrum output.

PowerPoint 16.113.3 opened the four 720 × 720 pt slides without repair. Root
explicitly observed Best for printing selected and the online option off before
saving the accepted PDF. The source was not saved. `capture-receipt.json` pins
that observation and retains the hash/reason for an earlier mode-unconfirmed
export, which is excluded and is not this fixture's PDF.

- Source SHA256: `98c27b081f8ecb9c297d46e04019b83bcdc969ed3d42113f89491aa0b9d70dac`
- Accepted PDF SHA256: `49b3001cee2777ec1c319c191f40836c4c20391a65224b49f6289d54908b6b66`

## Finite matrix

Each of the following has both centered and right paragraph alignment:

| Conditions | Text and geometry |
| --- | --- |
| Fractional width pair | Agjp, regular 14.5 pt; widths 110.99 and 111.01 pt |
| Trailing spaces and manual break | Agjp + two spaces / BBBB; zero versus 7.2/3.6 pt left/right padding |
| Wrap boundary pair | Twelve B characters + Z, 13.51 pt; widths 110.99 and 111.01 pt |
| Positive kerning thresholds | AVATAR ToTo, 20 pt × stored 72.5%; thresholds 14.6 and 15.1 pt |
| Actual style/face pair | Agjp, 14.5 pt Sans Bold versus Serif regular |
| Table stored-scale pair | Real single cell, zero margins, Agjp 14.5 pt; stored 100% versus 50% |

The source manifest records every frame, run and property. All are top anchored,
with ordinary line spacing and no list markers. Real licensed DejaVu Sans
regular/bold and Serif regular bytes are embedded; their pinned source files are
shared with `../NativeListMarkers/fonts`, including the license. There are no
system-font dependencies, so all cases run on macOS, iOS and Linux.

Independent hmtx arithmetic selects the wrap boundary: B has advance 1405/2048 em;
at 13.51 pt its previously calibrated eighth-point advance is 9.25 pt. Twelve
advances total 111 pt. Native output independently shows 11 B / BZ at 110.99 pt
and 12 B / Z at 111.01 pt. Native first origins confirm raw available width for
centering and eighth-floor capacity for right alignment. Trailing spaces affect
alignment. Table scale 50% still paints full-size text and retains the existing
unsupported stored-scale diagnostic.

## Independent extraction and checks

`generate.py` uses python-pptx and explicit OOXML, with fixed ZIP timestamps.
`audit.py` checks parsed XML/relationships, source text/frames and actual embedded
sfnt bytes. `capture.py` requires the accepted source and PDF hashes, matches
source/subset glyph outlines exactly, parses raw PDF graphics/text matrices and
retains every visible glyph origin, painted scale and geometric ink bounds.
Ordinary spaces are counted in the authored input and recorded separately when
present in the PDF; they have no visible ink. Every non-space scalar must be
consumed. Raw content streams are retained. MuPDF SVG path-conversion deltas are
separate extraction artifacts, not substitutes for native geometric ink.

Scripts require python-pptx, lxml, fontTools, PyMuPDF and pypdf; none are runtime
library dependencies. Run from the repository root:

```
python3 Tests/RostrumTests/Fixtures/NativeBodyAlignment/audit.py
python3 Tests/RostrumTests/Fixtures/NativeBodyAlignment/capture.py
swift test --jobs 2 --filter NativeBodyAlignmentTests
```

`NativeBodyAlignmentTests` compares the independent numeric references with both
shared layout wrapping and the actual SVG glyph origins/paint/font bytes. It
requires complete case/line/scalar consumption, deterministic rendering, unchanged
serialized DOM and stable reopen. Unchanged bounds: 0.025 pt line starts, 0.06 pt
finite captured-style scalar origins, 0.121 pt baselines, and 0.002 pt painted size
and ink dimensions. Line-start assertions distinguish raw from floored centering;
the looser per-glyph bound only accommodates existing finite PDF TJ/font-width
rounding. It does not promise uniform error for arbitrarily long text.

Baseline maxima were 0.0271454 pt per-glyph origin, 0.1199952 pt baseline,
0.0000008 pt paint and 0.0000008 pt ink dimension. All 24 line groupings agree.
No known failure is hidden and no tolerance was widened to obtain this result.
