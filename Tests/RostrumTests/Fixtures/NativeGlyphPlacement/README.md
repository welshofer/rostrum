# Native scalar placement and paint sizes

These 47 independently authored cases (9 slides, 669 visible glyphs) distinguish
PowerPoint glyph painting from horizontal measurement and wrapping. Python-pptx
and explicit DrawingML generate the inputs; Rostrum does not generate expected
coordinates. `native-capture-receipts.json` pins every accepted source and PDF.
Root operated PowerPoint 16.113.3 on macOS, opened each source without repair,
exported local **Best for printing** PDF with the online option disabled, and did
not save the source. All eight source/PDF SHA256 pins were checked on promotion.

| Folder | Cases | Slides | Purpose |
| --- | ---: | ---: | --- |
| primary | 18 | 3 | Fractional sizes, stored scale, wrap thresholds, half ties |
| autofit | 7 | 2 | Absent/bare/100% autofit, 99.99%, binary-exact 29×50% tie |
| eligibility | 18 | 3 | Actual second face/styles, integer ink, positive kern thresholds, tiny sizes, table, justification and decimal tab |
| kerning | 4 | 1 | Truly absent inherited kerning at fractional/scaled/8pt sizes, minimum schema-valid 1% scale |

All four licensed DejaVu faces are retained in `eligibility/fonts` with their
license. Source and subset outline identities are checked per visible glyph,
including bold, oblique and Serif; these are actual faces, not synthesized
styles. Tests run with these bundled bytes on macOS, Linux and iOS-compatible
library code; no installed Arial face is required for this new matrix.

## Evidence and bounded policy

At 100% scale, horizontal advances retain the authored fractional point size;
paint uses the nearest whole point with ties to even. Below 100%, measurement
and paint use the nearest whole point with half ties upward and an observed
minimum of 1pt. Explicit 100%, bare normAutofit and noAutofit agree. The 99.99%
control differs, so the rule is not based merely on normAutofit presence.
Authored XML and the public resolved run's `fontSize` remain unchanged.

Within the calibrated DrawingML paragraph policy, a fully absent or zero kern
threshold disables kerning; a positive inherited or direct threshold is tested
against the measurement size. The 14.6/15.1pt pair at authored 20×72.5% separates
measurement 15 from authored-effective 14.5. General TextShaper defaults and
required script shaping remain unchanged. Earlier source decks with omitted
local kern have inherited `kern="1200"`; `inherited-kerning-evidence.json` records
the exact master/default XML. Their tests now pass that actual inheritance to
the raw layout initializer, without changing native coordinates or tolerances.

SVG uses scalar x lists for admitted measured spans, including integer sizes,
and paints at its independently resolved size without `textLength` or
`lengthAdjust`. One-character spans reuse their single x value. This avoids
stretching glyph outlines to absorb advance rounding. `integer-stretch-counterexample.json`
records a 16pt control where stretching would alter ink width by 0.041949pt.
Separate list markers keep their existing general paint path because the body
run's eligibility does not establish the marker face/size/sequence. Unsupported
paragraphs retain authored painting and measurement; a post-shaping rejection
retries only that paragraph once. Neighboring paragraphs retain their policy.

The preflight requires LTR ASCII after field substitution but before case
conversion, resolved actual faces without synthetic bold/italic or baseline
shifts, and printable scalar/control input. Final glyph mapping must satisfy
the existing one-glyph-per-scalar native advance profile. Unsupported scripts,
missing glyphs and uncalibrated styles keep diagnostics and general rendering.
The tests also cover policy consistency for fractional scaled trailing empty
lines and wholly empty insertion styles; those controls are not additional
independently captured native cases. Synthetic or shifted empty insertion styles
receive the bounded native-paint warning. Empty missing-face metrics retain
their existing estimates and diagnostic policy; this pass does not add a new
warning for every missing-face empty paragraph.

Table cells are an explicit `RichTextLayout.Context.tableCell`, not inferred
from XML names or margins. Captured stored table fontScale is ignored; a public
cell TextFrame fit evaluates full-size 100/0 geometry once and leaves DOM
unchanged. Overflow returns false. Nonzero stored table spacing reduction is
uncalibrated, diagnosed, excluded from calibrated painting/explicit spacing,
and conservatively returns false from cell fitting. An explicit calculation
fontScale override remains available to generic layout callers. Shape fitting
continues its discrete shared-layout search; no native-selected fit parity is
claimed. Live table padding, anchor, direction, style and theme are resolved
for each cell fitting operation.

## Extraction, tolerances and limitations

`capture.py` matches PDF subset glyph outlines to the source sfnt, retains raw
PDF content streams and graphics/text matrices, and consumes every visible
source scalar. Independent PDF text origins plus exact outlines transformed by
raw matrices define geometric ink bounds. MuPDF's SVG path conversion rounds
some outline units (for example 1493→1494); its discrepancy is separately stored
as `vectorExporterInkDelta`, never absorbed into the ink tolerance.

Primary/autofit glyph x tolerance is 0.025pt; eligibility/kerning use 0.06pt for
this finite captured matrix. The latter is not a bound for arbitrary long
runs: PDF /Widths, Tc and TJ rounding can accumulate. `pdf-advance-audit.json`
reconstructs the bold 14.5 control from raw PDF commands within 0.0000191pt and
explains its 0.0492102pt displacement from the native eighth-point model.
Painting and ink dimensions retain 0.002pt tolerance; baseline retains 0.121pt.
All prior native line/span/spacing tolerances are unchanged. Absolute page print
snapping is explanatory PDF context only, not an SVG algorithm or raster parity
claim. Root's separate WebKit/app acceptance is not implied by these tests.

The first omitted-kerning research deck contained schema-invalid 0.1% fontScale
and PowerPoint requested repair. Root canceled without repair/save/export. Its
hash and correction are retained in `kerning/native-rejection-and-correction.json`;
only v2 at the schema minimum 1% is an accepted source. The original rejected
binary remains in the ignored research directory, outside this fixture set.

## Reproduction

Research tools require python-pptx, fontTools, lxml, PyMuPDF and pypdf; arithmetic
controls also use HarfBuzz `hb-shape`. These are offline fixture tooling, not
library dependencies. Run generators only in a copied fixture directory:
regeneration does not replace the pinned native acceptance. Capture a fresh PDF
through native PowerPoint, then run that folder's `capture.py`. The primary and
autofit arithmetic comparison is `autofit/model.py`; second-face comparisons are
`eligibility/model.py`. Raw streams, manifests, cases and all accepted outputs
are retained for independent re-extraction. Fixture maintenance must preserve
source/PDF pins or obtain a new native receipt.

Primary semantic context: [SVG2 text length adjustment](https://www.w3.org/TR/SVG2/text.html#TextElementLengthAdjustAttribute)
permits glyph stretching with spacingAndGlyphs; it does not promise exact scalar
origins. The [Microsoft Open XML SDK schema](https://github.com/dotnet/Open-XML-SDK/blob/main/data/schemas/schemas_openxmlformats_org_drawingml_2006_main.json)
bounds normAutofit fontScale to 1000…100000. Neither source supplies the native
rounding policy; the independent captures above establish its bounded profile.
