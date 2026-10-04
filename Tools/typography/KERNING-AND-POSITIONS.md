# DrawingML kerning thresholds and remaining Office raster differences

The `kern` attribute specifies the minimum point size at which a text run uses
font kerning. Zero, including an omitted inherited value, enables kerning at all
sizes. This is independent of ligature substitution. See the Microsoft-published
[Office Open XML primer, DrawingML text formatting](https://download.microsoft.com/download/e/1/4/e14fb96f-83b8-4a2a-84db-7fa8acbe061a/Office%20Open%20XML%20Part%203%20-%20Primer.pdf)
and [SVG 1.1 kerning](https://www.w3.org/TR/SVG11/text.html#KerningProperty).

The shared layout now resolves the threshold through the existing closest-first
run/paragraph/list/inherited style chain and compares it inclusively against the
rendered font size. Normal autofit scales the font size, not the threshold.
Both initial shaping and wrapped-line remeasurement use that policy. Disabling
kerning suppresses Latin legacy/GPOS and Arabic selected pair positioning; it
retains substitutions, joining, clusters, bidi and unsupported-feature warnings.
The original public `TextShaper.shape` signature remains available.

SVG emission includes `kerning="0"` only when the resolved threshold disables
kerning; the render style cache includes this decision. Merely adjusting a
span's `textLength` would otherwise stretch already-kerned glyphs. The pinned
resvg adapter honors SVG 1.1 `kerning="0"`; a `font-kerning="none"` attribute
alone was ignored in a direct development check. This does not establish every
browser's kerning behavior.

Portable regressions cover inclusive/zero/disabled thresholds, inheritance,
wrapping and fitting, normal autofit, cache separation, legacy kerning, deck
preservation, ligature independence and unsupported-script diagnostics. The
DejaVu `kern=0` advances/IDs/clusters are independently checked against:

```sh
hb-shape Tests/RostrumTests/Fixtures/Typography/DejaVuSans.ttf 'AV office' \
  --features=kern=0 --font-size=2048 --no-glyph-names --output-format=json
```

These semantics are not newly qualified against native Office captures. In the
existing Office fixture all text is at least 14pt with a 12pt threshold, so this
fix intentionally leaves its SVGs byte-identical. The unchanged corpus remains
an acceptance failure.

## Reproduce the unchanged Office acceptance failure

Build/render the source with the four licensed fonts as described in
[OFFICE-BASELINES.md](OFFICE-BASELINES.md), then run:

```sh
python3 Tools/typography/check_office_text_positions.py \
  --fonts /path/to/local-fonts.json --candidates /path/to/candidate-svg \
  --ablations --output /tmp/office-text-positions.json
```

The tool requires PyMuPDF 1.27.2.3, fonttools 4.60.1, HarfBuzz 14.4.0,
resvg-py 0.5.0 and Pillow 12.3.0. It verifies the pinned PPTX/PDF, all four local
fonts, all 268 PDF glyph outlines, and the archive/member PNG hashes. It refuses
inputs outside this ASCII corpus profile. It outputs numeric measurements only;
no font binaries, extracted outlines or replacement references are written.
Exit 1 is the expected acceptance failure, not a tool execution failure.

The [committed report](../../docs/benchmarks/2026-10-02-office-text-positions.json)
records all 268 horizontal glyph-origin comparisons, each span width, unchanged
baseline results, six native PNG comparisons, and diagnostic ablations:

- All 46 baselines still pass the existing 0.121pt tolerance; maximum error is
  0.12001709pt. Maximum SVG span-width error against independent HarfBuzz is
  0.00004844pt, within four-decimal SVG number serialization precision.
- Maximum glyph-origin x difference from the verified Office PDF is 0.16410183pt.
  This is a measurement, not a newly introduced acceptance tolerance.
- Removing span-wide `textLength` changes at most six differing pixels. It does
  not make any previously failing native PNG comparison pass.
- Rasterizing the Office PDF itself with pinned PyMuPDF also fails the same four
  PNG comparisons. This shows that even the native PDF's verified glyph outlines
  and coordinates do not ensure native PNG pixel equivalence with another
  rasterizer. It does not prove one exact cause of every residual pixel.

| Native PNG | Slide | Candidate differing pixels | Without textLength (diagnostic) | Office PDF raster (diagnostic) |
|---|---:|---:|---:|---:|
| 1200×700 | 1 | 5,068 | 5,068 | 5,288 |
| 1200×700 | 2 | 10,151 | 10,150 | 10,604 |
| 1200×700 | 3 | 5,679 | 5,681 | 6,185 |
| 2400×1400 | 1 | 12,601 | 12,606 | 13,257 |
| 2400×1400 | 2 | 24,844 | 24,850 | 27,370 |
| 2400×1400 | 3 | 14,584 | 14,585 | 15,370 |

The channel tolerance remains 16 and maximum differing fraction remains 0.005.
No baseline or PNG thresholds were relaxed. No family-specific, fixture-specific
or output-size-specific rules were added. Additional raster/hinting investigation
and independent native coverage remain necessary; this kerning correction does
not close FUNC-3 or REL-1.
