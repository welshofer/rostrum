# Native line-break boundaries

These probes investigate a concrete counterexample in the existing native
paragraph fixture: 18pt Arial places `SupercalifragilisticexpialidociousSupe`
on a 300pt line although its unrounded hmtx advances sum to 300.1640625pt.
There is no kerning adjustment in that prefix. The original fixture and its
thresholds remain unchanged.

The source decks are independently authored with python-pptx 1.0.2, fontTools
and explicit OOXML/EOT construction. No Rostrum measurement or serialization
is used to choose expected results. Candidate rounded widths select *inputs*;
PowerPoint's actual line contents and PDF character origins provide the oracle.
`capture.py` extracts those observations and portable ASCII font metrics.

PowerPoint 16.113.3 on macOS opened the initial 12-slide, follow-up 11-slide and
final 3-slide decks without repair. The root operator exported each locally
with **Best for printing**, without saving the source. Source/PDF SHA-256s are
retained in each `native-geometry*.json`. The original failing baseline is
`baseline-observations.json` (23 mismatches among the initial 72 cases).

## Observations

* For tested Arial regular/bold and embedded DejaVu Sans ASCII glyphs, base
  advances round to the nearest 1/8pt. Pair positioning and tracking remain
  separate from that base rounding.
* Actual wrap thresholds, not only PDF drawing positions, establish that the
  available line capacity rounds down to 1/8pt. Twelve Arial B glyphs at 10pt
  with +.07pt tracking draw with 6.695pt advances (total 80.34 pt); a width of
  80.374pt wraps, while 80.376 pt fits.
* Explicit `kern="0"` disables pair positioning in native PowerPoint. Omission
  enables it; a positive threshold enables it at or above the rendered size.
  The factorial varies omitted/zero/positive thresholds independently of
  omitted/zero/nonzero tracking. This is an observed PowerPoint compatibility
  distinction, not a claim that the OOXML default convention requires it.
* Center alignment uses the original box extent. Right alignment uses the
  floored capacity in the narrow fractional-tracking probes.
* Body insets preserve fractional coordinates. Paragraph margins and indent
  undergo separate coordinate conversion; the coordinate probes calibrate it.

The exact bundled DejaVu font is embedded independently in the source decks.
`embedded-font-identity.json` verifies that B, Z and m glyph outlines and hmtx
values extracted from the initial native PDF subset match the bundled source
font. The numeric Arial metrics permit portable tests without distributing
proprietary font data. The embedded DejaVu font retains its existing license
in `Fixtures/Typography`.

The calibrated advance profile is bounded to left-to-right ASCII with one
scalar per shaped glyph. Complex scripts, bidi text and multi-scalar OpenType
substitutions require separate native evidence. The DejaVu `office` control
shows that native PowerPoint's character advances differ from the standalone
shaper's ffi ligature. Standalone TextShaper behavior and its HarfBuzz oracle
are independent contracts and are not changed by this work.

Primary format references: [OOXML Primer](https://download.microsoft.com/download/e/1/4/e14fb96f-83b8-4a2a-84db-7fa8acbe061a/Office%20Open%20XML%20Part%203%20-%20Primer.pdf)
and [W3C EOT v2.1](https://www.w3.org/submissions/EOT/).

## Final calibrated rules and checks

The five captured decks contain 175 cases across 30 slides. All 175 assert exact
native line contents, line starts within 0.025 pt and advance widths within
0.06 pt. The `office` control originally required an unsupported-shaping
diagnostic; the independent [NativeLigatureLayout](../NativeLigatureLayout/README.md)
capture now establishes its individual glyph policy, enabling the same numeric
assertions for that case. Prior tab and paragraph oracle tolerances are unchanged.

149 cases use portable synthetic metric fonts reconstructed from retained Arial
regular/bold ASCII advances and kerning numbers. The remaining 26 use the
bundled DejaVu font (26 calibrated cases). Swift tests
need no system Arial and skip no cases on Linux. FontTools is used only for
independent fixture generation/capture, not library execution or Swift tests.

The four autofit probes distinguish two rounding orders. DejaVu B at 18pt has
raw advance 12.3486328125pt: rounding then halving gives 6.1875pt, whereas halving
then rounding gives 6.125pt. Native 12-B text at 50% scale fits at 73.51pt and wraps
at 73.49pt, establishing rounding **after** effective font scaling.

The coordinate probes establish nearest 0.05pt paragraph margins and indent:
.024→0, .026→.05, .074→.05, .076→.10. Body width minus body insets is floored to
1/8pt **before** subtracting those paragraph coordinates. A negative indent at
zero left margin clamps the text start to the body edge. Body insets themselves
retain their original precision. Center alignment uses the original extent;
right alignment uses the floored capacity.

Supported segments retain calibrated advances even when another segment in the
same paragraph contains unsupported clusters. Such a paragraph retains raw
paragraph coordinates/capacity and reports the explicit approximation; it does
not claim native boundary parity. RTL paragraphs retain raw segment advances
and raw paragraph geometry with a diagnostic. Empty unresolved-font runs do
not change paragraph eligibility. Standalone shaping remains unchanged.

The PDF's declared font resource size can be rounded (24pt for authored 23.5pt)
while its positioned character advances retain the source size. Both raw PDF
sizes (`native-geometry*.json`) and authored sizes/scales (`cases*.json`) are
retained. Width reconstruction uses PDF origins and the independent source size
for the final glyph, whose following origin is unavailable; it does not widen
the tolerance to accommodate resource-size rounding.

`native-export-receipt.json` is the root GUI operator's independent hash/page
receipt. `kerning-equivalence.txt` records HarfBuzz 14.4.0 kern-off/on outputs for
`mmmmZ`; both are identical, allowing the Lectern recipe to omit kerning through
the public API while exercising the same native DejaVu boundary. The styled
recipe uses native cases `dejavu-mixed-size-1/-2`: four m at 18pt followed by
`mmmmZ` at 10pt, widths 108.99/109.01pt, yielding 7m/mZ versus 8m/Z. Its fit-selected
scale is a computed result, not an independently native-certified scale.

Reproduce extraction with `python3 capture.py` and flags `--followup`, `--final`,
`--scale`, `--coordinates` on the capture host. Run the portable regression with
`swift test --jobs 2 --filter LineBreakBoundaryTests`. Optional environment
variables `ROSTRUM_BOUNDARY_OBSERVATIONS` and `ROSTRUM_BOUNDARY_SAVED` retain the
observed library geometry and a saved/reopened initial deck. Layout also checks
that every source deck serializes identically before and after measurement.
