# Native Latin ligature layout

This fixture investigates DrawingML text behavior separately from the general
OpenType shaper. The old `LineBreakBoundaries` native `office` control draws
individual f/f/i glyphs while standalone TextShaper correctly enables `liga`.
The new matrix checks whether that native policy persists across common pairs,
run boundaries, tracking, kerning, scaling, wrapping, tabs and table cells.

`generate.py` independently authors 24 cases on four slides using python-pptx
and explicit standards-based OOXML/EOT construction. The bundled licensed
DejaVu Sans regular font is embedded; its SHA-256 and source deck hash are in
`input-manifest.json`. Input widths bracket independently calculated candidate
unligated advances; native PDF line strings and glyph origins, not those
candidate values, determine expected results. Synthetic bold/italic faces and
other fonts are outside this initial calibration.

`capture.py` retains actual PDF glyph IDs, origins, resource sizes and source
outline identity comparisons. This distinguishes individual f/f/i drawing from
PDF extraction that might expand a ligature's Unicode mapping. The PDF font
resource size can differ from the authored size, so both are retained.

## Primary-source scope

Microsoft's [OpenType liga definition](https://learn.microsoft.com/en-us/typography/opentype/spec/features_ko#tag-liga)
classifies standard ligatures as an application-controlled feature. This does
not establish PowerPoint's policy, which requires native observation. Required
script substitutions are separate and must remain active.

Microsoft's [DrawingML run-properties reference](https://learn.microsoft.com/en-us/dotnet/api/documentformat.openxml.drawing.runproperties?view=openxml-3.0.1)
lists the core `a:rPr` properties, without a ligature toggle. The documented
[`w14:ligatures`](https://learn.microsoft.com/en-us/openspecs/office_standards/ms-docx/fdfa0171-21e9-4e96-90f0-296b381f67ca)
property belongs to WordprocessingML. No guessed DrawingML extension is authored
or exposed as a public API. The [W3C EOT v2.1 format](https://www.w3.org/submissions/EOT/)
governs the independently built embedded font wrapper.

## Native receipt and results

`native-receipt.json` records the root agent's native PowerPoint 16.113.3 capture:
four slides opened without repair, File → Export → PDF → Best for printing,
online export deselected, source not saved. `native-geometry.json` retains the
source/PDF/font hashes and complete glyph data. All 24 cases use actual individual
source glyph outlines, including fi/fl/ff/ffi/ffl; the evidence is not merely a
PDF Unicode mapping. `capture.py` checks exact source-character consumption and
records each glyph's originating authored run, effective size and tracking.
The PDF's tab-space placeholder is explicitly mapped to its authored tab.

The first capture inherited a built-in table style that synthesized bold by
painting identical fill and stroke glyphs. It is rejected as a regular-table
oracle. Its hashes and native receipt remain in `native-receipt-initial.json`;
rejected binaries are local scratch only. The corrected generator removes the
table style and explicitly authors regular table runs. No duplicate glyphs are
silently discarded by extraction.

| Case | Width (pt) | Native lines |
| --- | ---: | --- |
| office-edge-below | 49.74 | `offic` / `eZ` |
| office-edge-above | 49.76 | `office` / `Z` |
| ffi-component-edge-below | 12.74 | `f` / `fi` / `Z` |
| ffi-component-edge-above | 12.76 | `ff` / `i` / `Z` |
| scaled-office-edge-below | 24.74 | `offic` / `eZ` |
| scaled-office-edge-above | 24.76 | `office` / `Z` |
| mixed-size-edge | 39.01 | `office` / `Z` |
| table-default | 120 | `office final ` / `waffle` |
| table-edge | 49.76 | `office` / `Z` |

Uniform boundary text is `officeZ` or `ffiZ`, 18 pt, explicit `kern=0`.
Scaled cases use authored 18 pt with 50% font scale. Mixed text is `of` at
18 pt followed by `ficeZ` at 12 pt. Exact source styles are in `cases.json`.
The captured wide controls include omitted/zero kerning, positive/negative
tracking, same-style/color run splits, tabs and hard breaks. This calibrates
regular DejaVu Sans in the captured left-to-right ASCII contexts; it does not
claim every font or script has identical native geometry.

HarfBuzz controls pin public standalone ligatures on, internal optional liga
off, and preserved kerning for `AV office`. Exact chosen public demo strings
`officeZ`, `of`, `ficeZ` have equal kern-on/off glyphs, advances and offsets.
This bounded equivalence permits public omitted-kern authorship without adding
an invented DrawingML ligature property or broad kerning-equivalence claim.

At baseline `a9d870b`, the original two-test fixture run passed standalone
HarfBuzz controls and failed the native layout test with 62 issues. The retained
native thresholds and numeric tolerances are unchanged during implementation.
The hard-break case retains the exact pre-existing unresolved-face diagnostic
for its unstyled `a:br`; break/empty-line vertical metrics are not newly
calibrated. Its horizontal glyph, line-content and span geometry remain fully
asserted. The other 23 cases require empty layout diagnostics.
Final verification: `swift test --jobs 2` passed 1,104 Rostrum tests in
153 suites and 18 RostrumLayout tests in three suites. Standalone defaults,
internal liga-off HarfBuzz controls, required Arabic shaping, conservative
mixed/RTL paragraph policy, exact native thresholds, alias/cache separation,
read-only layout, deterministic SVG and save/reopen checks pass. The bounded
policy is selected from source text after field substitution and before case
conversion; non-ASCII source remains on general shaping even if capitals would
convert it to ASCII. No runtime dependencies were added; no lint is configured.
`git diff --check` passed.


The SVG viewer policy uses only `font-feature-settings: 'liga' 0`.
[CSS Fonts §6.12](https://www.w3.org/TR/css-fonts-4/#font-feature-settings-prop)
defines a zero feature value as disabled; this does not disable `rlig`, `clig`
or every ligature feature. Browser verification is recorded separately from
PowerPoint's native PDF measurement.

`make_viewer_specimen.py` wraps an actual emitted SVG with same-font liga-on/off
controls and exposes per-character origins/extents. It is a reproducible
optional developer aid, not executed acceptance evidence: the root browser
tool blocked its local file URL under URL security policy. No alternate
browser or localhost workaround was attempted.
