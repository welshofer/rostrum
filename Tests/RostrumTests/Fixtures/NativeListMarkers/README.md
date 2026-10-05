# Native list marker placement and painting

These independent Python-pptx/OOXML sources contain 24 cases on four slides.
PowerPoint 16.113.3 opened both sources without repair. Root opened the original
three-slide source; the worker, under transferred sole GUI ownership, exported
both PDFs using Save As > PDF > Best for printing with the online service off.
Neither source was saved. The adjacent `native-capture-receipt.json` files pin
source and PDF SHA256 values and record the native capture separately from tests.

| Source | Cases | Visible glyphs | Explicitly absent marker scalars |
| --- | ---: | ---: | ---: |
| `native-list-markers-v2.pptx` | 18 | 214 | 2 |
| `followup/native-list-markers-followup-v1.pptx` | 6 | 63 | 1 |

Every visible marker and body glyph is matched to pinned embedded DejaVu Sans,
Sans Bold, or Serif outlines and raw PDF graphics/text matrices. Fonts and their
license are retained in `fonts`; all three faces permit embedding. No system
font is required. All 280 anticipated source scalars are accounted for: 277
painted glyphs and three explicit marker omissions. No missing bullet is silently
removed from the audit. Identical regular/Serif bullet outlines remain ambiguous;
`matchingSourceFaces` preserves that ambiguity. Bold body character bullets use
the regular PDF subset, whereas bold Arabic numbering uses the bold subset.

## Observed correction

Follow-text marker sizing follows the first ordinary body run's measurement and
paint policy. Direct 14.5 pt paints 14 pt; stored 29 pt at 50% paints 15 pt. A 75%
marker on direct 14.5 pt paints 11 pt. A 90% marker on scaled 29×50% paints 14 pt:
the percentage uses the rounded 15 pt body measurement size, followed by nearest
half-up marker sizing. Explicit `buSzPts=1450` paints 15 pt independently of body
scaling, including the 20×72.5% control. The 27 pt oversized bullet does not
increase the 18 pt body line pitch.

Marker x is marL + indent. First body x is max(marL, marker end), without an
additional ordinary-space clearance. Arabic digits and punctuation use scalar
origins on the calibrated eighth-point advance grid. Continuation lines return
to marL, even when the marker is wider than the hanging indent. The two wide
number controls have native three/four-line bodies; the pre-fix library has
five/eight lines. Captured baseline x errors reach 80.8291 pt and baseline errors
107.9199 pt. The shared layout correction also serves shape fitting.

Ordinary shapes, both text boxes and non-text-box shapes, do not inherit the
master `otherStyle` marker activation/font/size choices. Explicit local bullets
and numbers use their local or follow-text choices. Body placeholders do inherit
those master choices; local follow-text overrides them. The followup separates
these cases rather than inferring inheritance from a generic marker omission.
Only transient inherited-style copies change; source XML and placeholder chains
remain intact.

## Bounded profile and preservation

New marker paint/advance calibration requires the admitted scalar Latin body
profile, a shape context, left alignment, ordinary line spacing, zero tracking,
no effective kerning, and an ordinary printable first body scalar. It covers
U+2022 character bullets and Arabic-period numbering with real resolved faces.
Character bullets use the regular selected family; numbering retains body bold.
Italic, leading hard/tab/LF/space controls, other marker sequences/schemes, table
cells, and explicit line-spacing combinations retain the previous marker path.
Missing or malformed sizes and values outside the schema ranges decline the new
calibration, preserving existing fallback/clamping instead of silently changing
invalid values to a native minimum. General body shaping and standalone shaper
behavior are unchanged. No broader script, numbering, native-selected fit, or
raster-parity claim is made.

The finite captured glyph-origin tolerance is 0.06 pt, accounting for PDF font
width/TJ export drift (the bold body reaches 0.0421 pt). Baseline tolerance is
0.121 pt; paint and ink dimensions use 0.002 pt. These are bounds for the captured
strings, not arbitrarily long sequences. All earlier native oracle tolerances
remain unchanged. MuPDF SVG path conversion rounding is retained separately as
`vectorExporterInkDelta`; exact source outlines under raw matrices define the
geometric ink reference.

## Reproduction and verification

`generate.py` authors independent source XML and embeds licensed faces; it does
not compute expected layout using Rostrum. `capture.py` consumes the native PDF
and retains raw content streams, matrices, subset hashes, scalar origins and
outline identity. Run it in each fixture folder after dependencies Python-pptx,
lxml, fontTools, PyMuPDF and pypdf are available for offline test tooling. These
are not runtime dependencies. Re-generating creates new ZIP timestamps; retain
frozen source/PDF pins when reproducing an accepted capture.

`NativeListMarkerTests` checks all visible scalar origins, body wrapping, actual
resolved faces, paint/ink dimensions, SVG scalar positions without textLength,
diagnostics, deterministic rendering, read-only DOM and save/reopen stability.
`baseline-native-comparison.json` retains the independent pre-fix comparison.
The initial18-case regression failed372 assertions before production changes.
Final commands and exact source/log hashes are recorded in `verification.json`.
Root separately owns Lectern demonstration, app/native generated-output checks,
integration, and Release performance acceptance.

Microsoft's schema documentation defines the authoring choices, not the native
quantization model: [bullet percentage](https://learn.microsoft.com/en-us/dotnet/api/documentformat.openxml.drawing.bulletsizepercentage?view=openxml-3.0.1),
[bullet points](https://learn.microsoft.com/en-us/dotnet/api/documentformat.openxml.drawing.bulletsizepoints?view=openxml-3.0.1),
[follow-text size](https://learn.microsoft.com/en-us/dotnet/api/documentformat.openxml.drawing.bulletsizetext?view=openxml-3.0.1),
[bullet font](https://learn.microsoft.com/en-us/dotnet/api/documentformat.openxml.drawing.bulletfont?view=openxml-3.0.1).
