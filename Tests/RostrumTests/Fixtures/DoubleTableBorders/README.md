# Static double borders and style boundary precedence

This packet adds render/import fidelity, not new public border-authoring APIs.
Independent inputs use python-pptx 1.0.2, not Rostrum. PowerPoint Mac 16.113.3
opened each original without repair, exported every slide at 1200 × 700, then
closed without saving. The original 29-page fixture was also exported locally
as PDF (Best for printing), at 864 × 504 points per page. Manifests pin the input,
generator, PNG archive and individual reference hashes; the 29-case manifest
also pins the PDF.

- `double-borders.pptx`: 24 direct cases (1, 4 and 9 points; horizontal, vertical,
  RTL, paired/mixed merges, both diagonals), then five native styles with
  `lastRow` enabled.
- `style-precedence.pptx`: 36 controls across `lastRow`, `firstRow`, `bandRow`,
  `firstCol` and `lastCol`, varying earlier/later direct solid/noFill overrides.
- `style-precedence-rtl.pptx`: the same 36 controls with only `rtl` enabled.

The Office PDF establishes stroke/gap/stroke widths of one third of the total
width, with diagonal offsets along the line normal. All 24 direct cases compare
their eight component vertices against the actual PDF. The five native examples
compare coalesced component bounds, including terminal extensions to
perpendicular ordinary borders. Maximum error is 0.000116943 point; the gate is
0.001 point. The PNG controls establish that style boundaries apply to both
adjacent cells before the earlier logical donor's direct formatting; later
direct formatting does not replace that donor. All 216 stable LTR/RTL boundary
probes pass with a tolerance of one RGB level.

Whole-image results remain separate, at the unchanged 0.5% pixel gate and
16-channel tolerance: 26/29 double cases and 24/36 in each style-control set pass.
Failures remain recorded as failures in the JSON reports. Double cases 21/24
(wide diagonals) and 28 (Medium Style 3) have antialiasing residuals. Themed Style 1
control cases 25–36 also contain omitted shadow effects. Exact PDF geometry does
not establish pixel-equivalent rasterization. No global conformance gate has
been relaxed. Unsupported compound types, dashed/capped/inset double borders,
unverified double/diagonal junction combinations and effects continue to produce
fidelity diagnostics.

Generate fresh independent inputs with the two named generators (they refuse
existing outputs). Export SVG with `render_table_oracle.swift`, compiled against
the current Rostrum module. On the validated macOS Swift build layout:

```sh
swift build
swiftc Tools/conformance/render_table_oracle.swift -I .build/debug -Xlinker .build/debug/Rostrum.o -o /tmp/render-table-oracle
/tmp/render-table-oracle Tests/RostrumTests/Fixtures/DoubleTableBorders/double-borders.pptx /tmp/double-svg
python3 Tools/conformance/check_double_table_borders.py /tmp/double-svg Tests/RostrumTests/Fixtures/DoubleTableBorders --pdf --output /tmp/double-vector.json
```

The PDF checker requires PyMuPDF 1.27.2.3; raster checking requires resvg-py 0.5.0
and Pillow 12.3.0 in a separate environment. Omit `--pdf` for the whole-image
checker. Use `--styles` or `--styles --rtl` with the corresponding SVG directory.
Raster checks intentionally exit 1 when the recorded whole-image gate fails.
The returned `boundaryPassed` fields separately report the scoped boundary probes.
