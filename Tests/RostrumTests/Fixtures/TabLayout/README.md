# Standard tab layout oracle (FUNC-2)

The input decks are independently authored with python-pptx 1.0.2. Native
Microsoft PowerPoint for Mac 16.113.3 opened every source without a repair prompt
on 2026-10-03. Each `powerpoint*.pdf` is PowerPoint's local **Best for printing**
PDF export; PowerPoint did not save or alter the sources. No Rostrum geometry
supplies an expected position.

- Initial `tab-layout.pptx`: 24 probes. The template explicitly inherits a 36pt
  default interval. This does **not** establish an application fallback.
- V2: removes all template `defTabSz` attributes and confirms the bare 72pt
  fallback; adds missing/empty/overridden local tab lists, overflow and decimal
  controls. 30 cases.
- V3: 12 center-field wrapping, noWrap, prefix collision, explicit-break,
  following-tab and kerning controls. These distinguish whole-field centering
  from PowerPoint's adjustment when a wrapped center field exceeds the right edge.
- V4: 12 cases establish paragraph center/right alignment with all four tab
  modes, multiple fields and a leading tab.
- V5: six 18pt-wide boxes establish the exact right-edge exception, nearby
  inside/outside stops, tracking and right/center alignment. An exactly-on-edge
  left tab ends the current line; a tab that moves to a new line and still cannot
  fit its field can produce a blank line. This independently preserves the
  existing fallback-metrics control-character regression.

`capture_metrics.py` records all 60 V2–V5 cases, both word-start and word-end
coordinates, source/PDF/font SHA-256 hashes, and numeric ASCII advances and kern
pairs from local Arial/Arial Bold. No font programs or outlines are redistributed.
The tests create small synthetic metric fonts from those numbers and compare every
native word anchor within **0.25pt**, including exact glyph consumption and line
counts. Blank lines are reconstructed from the native 18pt/10pt baseline pitch;
vertical typography itself is outside this horizontal-layout oracle. Infinite PDF
extraction bounds retain noWrap text beyond the page edge, so these fields are
checked completely rather than silently truncated.

The tests first write every explicit stop through the public API, serialize,
reopen, verify byte stability, and then compare the reopened contents with the
native oracle. Setting `ROSTRUM_TAB_ORACLE_EXPORT` explicitly retains those
written decks for manual acceptance. Native PowerPoint also opened the retained
`rostrum-tab-layout-v2.pptx` (five slides) without repair on 2026-10-03; it was not
modified or saved there.

## Established behavior

Custom stops are considered in position order. Their coordinates are relative to
the text content's left edge; paragraph margins/first-line indents do not shift
the stop coordinate. Explicit intervals resume on the default grid after custom
stops. A missing local list inherits, an empty list overrides custom inherited
stops, and a populated local list replaces the inherited list. Inherited intervals
still apply with an empty list.

Left, center, right and period-decimal alignment measure the following field
through the next tab or explicit break, preserving mixed font runs and kerning.
Trailing spaces do not affect a field's center/right edge. Decimal fields align
at the first period; fields without a period align their right edge (including
comma-only text in the captured English environment). A field cannot move back
through preceding text. Paragraph center/right alignment then shifts the whole
line, including its tab fields.

With wrapping, a center field that would exceed the right edge and has positive
tab advance fits the longest whole-word prefix into the remaining width and
aligns that prefix's right edge with the box. noWrap retains full-field centering.
A field whose first word cannot fit can carry its tab to the next line and select
a stop again, except a tab exactly at the right edge ends its current line.
Tab-only overflow still affects fitting.

Justification expands U+0020 spaces only **after the last tab** on each line.
Earlier fields retain their positions; final paragraph lines remain natural and
explicit line breaks justify their preceding line. Repeated/edge spaces, inherited
styles, bullets, indentation, mixed runs, tracking, overflow and DOM purity retain
focused regression coverage.

## Support boundaries

The supported shaping profile is left-to-right Latin text. RTL/non-Latin tab
paragraphs retain a fidelity diagnostic and approximate left tab alignment.
Decimal preview uses period `.`; locale-sensitive alternate decimal separators
are not implemented. Columns, vertical text, distributed/Thai justification and
full glyph-raster parity remain outside this change. Unknown XML is untouched by
layout and reads. Explicitly setting the tab collection replaces modeled tab
entries while retaining extension children; setting nil removes the local list.

Primary descriptions of standard tab modes and DrawingML position/order semantics:

- https://support.microsoft.com/en-us/powerpoint/set-or-clear-tab-stops-in-powerpoint
- https://learn.microsoft.com/en-us/dotnet/api/documentformat.openxml.drawing.tabstop?view=openxml-3.0.1

Native captures above settle wrapping, inheritance and justification details that
those general descriptions leave unspecified.

## Reproduce

Run the four `generate*.py` scripts to independently generate V2–V5. Export each
through native PowerPoint to the corresponding `powerpoint-vN.pdf`, then run:

```sh
python3 Tests/RostrumTests/Fixtures/TabLayout/capture_metrics.py
swift test --jobs 2 --filter TabLayoutTests
ROSTRUM_TAB_ORACLE_EXPORT=Tests/RostrumTests/Fixtures/TabLayout swift test --jobs 2 --filter TabLayoutTests
swift test --jobs 2
```
