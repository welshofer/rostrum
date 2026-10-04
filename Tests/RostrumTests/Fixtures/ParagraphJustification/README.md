# Paragraph justification oracle (FUNC-2)

`generate.py` independently authors the source with python-pptx 1.0.2. The
single slide contains 300pt-wide, 18pt Arial paragraphs for regular and mixed
runs, explicit line breaks, edge/repeated spaces, a long word, a hanging bullet,
a tab and a one-line paragraph. No Rostrum output supplies the expected geometry.

The source was opened in native Microsoft PowerPoint for Mac 16.113.3 on 2026-10-03
without a repair prompt, then exported through File > Export > PDF using the
local **Best for printing** option. The source was not saved by PowerPoint.
The PDF is the independent oracle; the PNG is a 2x rasterization of that PDF
by PyMuPDF, not another application's interpretation of the PPTX.

Version 1 captured regular, mixed-run and explicit-break geometry. Its bullet
probe had `a:buChar` after `a:defRPr`, so PowerPoint ignored that bullet.
Version 2 corrects this element order and lengthens the single-word probe to
force wrapping. Version 1 is retained as the initial native capture; the regression uses version 2.

`capture_metrics.py` records first-line word positions from the native PDF and
ASCII advance numbers from macOS Arial and Arial Bold using fontTools. The JSON
contains font/PDF SHA-256 hashes. It contains no font program or glyph outlines.
The regression constructs tiny synthetic metric fonts from these numbers, so it
runs on all platforms without requiring installed Arial. Native word-start
positions for regular, mixed, explicit-break and bulleted paragraphs are checked within
0.25pt, accommodating PowerPoint's coordinate quantization and metric rounding.
These tests establish horizontal word spacing, not full glyph raster equivalence.

Microsoft's official PowerPoint alignment documentation states that justification
expands word spacing on every line except the paragraph's last line:
https://support.microsoft.com/en-gb/powerpoint/change-text-alignment-indentation-and-spacing-in-powerpoint
The native explicit-break probe additionally establishes that `a:br` still
justifies its preceding line; it does not terminate the paragraph.

Supported scope is U+0020 word-space expansion in left-to-right Latin paragraphs,
including mixed style runs and inherited paragraph alignment. Edge spaces are
preserved but not expanded; trailing spaces do not define the visible right edge.
One-word lines retain natural spacing. Bullets are outside the expansion slots.
Tabs, RTL/non-Latin paragraphs, and `justLow`, `dist`, `thaiDist` retain a diagnosed
approximation. These boundaries remain explicit in render fidelity reports.

The native forced-word probe confirms natural character advances without word-space
slots. A word exactly on the width boundary can break one character differently
because Office rounds font advances; general line-break/metric parity is outside
this bounded justification change. Native tabs expand the segment after the tab,
which this implementation deliberately diagnoses rather than approximating silently.
