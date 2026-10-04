# Native hard-break metrics

Independent python-pptx/OOXML probes establish which style supplies an empty
line's metrics in PowerPoint. The 18 cases on three slides use the licensed
bundled DejaVu Sans 2.37 regular font. Every visible marker is A, B, or Z at
12 pt. Known paragraph/list font defaults isolate metric ownership from font
fallback. Following markers expose otherwise invisible blank-line advances.

Root opened the source in PowerPoint 16.113.3 without repair and exported
`powerpoint.pdf` locally with Best for printing. PowerPoint did not save the
source. Exact hashes and the capture receipt are in `native-receipt.json`.
`capture.py` checks every painted marker against the original font's glyph
outline and requires complete, ordered marker consumption. The PDF subset's
font name alone is not accepted as identity. Native expectations come from
this export, independently of Rostrum.

The calibrated rule is deliberately narrow:

- A populated line uses its visible run metrics; its terminating break's size
  does not enlarge that line (the 6/36 pt controls agree).
- An empty line terminated by a break uses that break's own properties over
  paragraph defaults. The second break in A / break36 / break6 / B supplies
  the 6 pt empty line. Leading breaks follow the same rule.
- The final empty line after a trailing break uses endParaRPr over paragraph
  defaults. It does not reuse the preceding break's properties.

All 16 ordinary-spacing cases match the native marker baselines within the
existing 0.121 pt bound, including inherited defaults, leading/consecutive/
trailing breaks, empty paragraphs, centered/bottom anchoring, and a regular
1-by-1 table cell. Tests use the bundled font on every supported platform.
Before the correction, eight cases failed with ten marker errors, including
14–22 pt blank-line errors. `baseline-comparison.json` retains that evidence;
`corrected-comparison.json` records the corrected result. The existing
unstyled-break missing-font warning in the separate NativeLigatureLayout
fixture remains unchanged.

Two additional cases deliberately remain unresolved: exact 12 pt spacing
places native baselines 1.96 pt above current output, and 150% spacing places
them about 5 pt below it. Their native equality assertions use narrowly scoped
Swift Testing known issues; glyph identity, marker count, horizontal origin,
diagnostics, and package purity remain ordinary assertions. A later spacing
correction must remove this classification. This change does not claim a new
spacing rule, modify anchor rounding, or broaden font/script fidelity.

To reproduce extraction, run `python3 capture.py` from any directory with
PyMuPDF and fontTools available. The generator additionally uses python-pptx
and lxml. These are research tools only, not package runtime dependencies.
`generate.py` locates the existing bundled font and can recreate the OOXML
source; generation is independent of library layout. ZIP metadata may differ.
Do not replace the retained native source/PDF or their hashes on regeneration.

Microsoft's [DrawingML Break reference](https://learn.microsoft.com/en-us/dotnet/api/documentformat.openxml.drawing.break?view=openxml-3.0.1)
and [end-paragraph properties reference](https://learn.microsoft.com/en-us/dotnet/api/documentformat.openxml.drawing.endparagraphrunproperties?view=openxml-3.0.1)
describe vertical breaks and saved insertion formatting. They do not specify
line-box ownership; native capture supplies that evidence here.

`probe.swift` is a scratch observation utility, compiled against the package's
Debug static library with `@testable import Rostrum`. Its arguments are this
fixture directory and the bundled font path. It writes `observed-layout.json`;
that file is actual library output, never an oracle. The checked-in comparison
receipts distinguish baseline and corrected library measurements. The focused
Swift tests are the portable verification entry point:
`swift test --jobs 2 --filter NativeBreakMetricsTests`.
