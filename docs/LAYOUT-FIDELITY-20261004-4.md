# Native common Latin words in layout

Rostrum's DrawingML layout now keeps optional common Latin ligature components
separate in left-to-right ASCII paragraphs, matching the captured PowerPoint
behavior. Layout, wrapped-fragment measurement, fitting and SVG use the same
policy. Standalone `TextShaper` retains its public ligature defaults and required
Arabic shaping is unchanged.

The [independent native matrix](../Tests/RostrumTests/Fixtures/NativeLigatureLayout/README.md)
contains 24 cases: fi/fl/ff/ffi/ffl, common words, run splits, mixed sizes,
tracking, kerning, scaling, wrap thresholds, table cells, tabs and a hard break.
PowerPoint 16.113.3 opened the independently authored embedded-font deck without
repair and exported it locally with Best for printing. Capture verifies every
painted glyph's outline against bundled DejaVu Sans, complete authored text
consumption, line contents and horizontal span geometry. The original table
probe's inherited synthetic bold was detected and corrected before acceptance.

At 18 pt, `officeZ` in a 49.74 pt box wraps as `offic / eZ`; at 49.76 pt it wraps
as `office / Z`. The prior layout's optional `ffi` substitution changed these
boundaries. The new regression failed with 62 assertions on a9d870b and passes
with the fix. The earlier 175-case boundary oracle now checks geometry for its
former `office` limitation too. Existing boundary/tab tolerances remain intact.

The policy is deliberately conservative: paragraph source text after field
substitution and before case conversion must be ASCII, and the paragraph must
be left-to-right. Other paragraphs retain general shaping and existing
diagnostics. No unverified DrawingML ligature property or public API is added.
SVG disables only optional `liga`; its style-cache key distinguishes that
policy from kerning and from general shaping. Aliased registered faces behave
consistently. Piece text is captured once per paragraph to avoid duplicate DOM
text materialization during the eligibility scan.

## Acceptance boundaries

- 23 native cases require no layout diagnostics. The unstyled hard-break case
  verifies horizontal glyph and span geometry while retaining its exact
  existing unresolved-face warning. Empty controls can affect vertical metrics;
  that warning has not been removed to make the test pass.
- Native evidence is calibrated to the bundled regular DejaVu face and tested
  contexts. It does not certify every font, script, whole-slide raster output,
  or PowerPoint's chosen autofit scales.
- The general shaper still matches independent HarfBuzz defaults; internal
  liga-off controls have separate oracle data and Arabic regression coverage.
- The optional local HTML viewer aid was not executed: browser security policy
  rejected its file URL. No alternative browser route was used to bypass that
  restriction. Native Lectern acceptance is recorded separately.

## Lectern and verification at checkpoint 5860a71

The existing paragraph recipe gains a fourth slide with original text and both
public fitting paths. Its office row uses the two native widths; its mixed-size
row stays at the verified 39.01 pt width. Public authorship omits kerning and
uses explicit 100% normAutofit for originals, while the source oracle uses
kern=0 and noAutofit. Exact-string HarfBuzz and layout equivalence checks record
the kerning distinction. PowerPoint acceptance checks those public-authored
specimens separately. Both four-slide decks opened without repair; local Best
for printing PDFs confirm all six new boxes per variant, including the 0.02 pt
wrap boundary and the fitted single-line words. Source hashes stayed unchanged.
Fitted scales are computed results, not native choices.

The [integration receipt](benchmarks/2026-10-04-fidelity4-integration-verification.json)
pins source `5860a71`, logs, output hashes and native observations. The complete
`./scripts/verify.sh` passed: four offline checks, 1,104 Rostrum tests,
18 RostrumLayout tests, 277 LecternCore tests, executable README examples,
macOS and universal iOS simulator builds, and 76 native app tests with no skips.
The supplemental headless run reports 76 tests with three native WebKit skips;
those native cases pass in the app-hosted gate.

All 26 Lab recipes pass 337 saved-file checks. Root independently checks ZIP
integrity and python-pptx reopening for all 52 generated decks. The paragraph
recipe has 31 checks, four slides and zero findings. The existing tab recipe
retains its one documented hard-break warning. Manual rebuilt Lectern acceptance
covers edited title, both widths, rendered inspector thumbnails, retained
results and Export Everything; the exported Markdown includes the native
boundary and computed 77.5% labels.

The initial combined gate stalled because an existing recovery test started a
real document-library scan. The focused reconciliation honors injected snapshot
storage and uses isolated test directories across restart. Independent review
approved it, and the full gate was rerun successfully. Production behavior with
no injected path remains unchanged.

The [performance report](LAYOUT-PERFORMANCE-20261004-4.md) covers the independent
fallback optimization. The first combined measurement found avoidable repeated SVG styling and higher
process memory. A focused serialization reconciliation is in progress; final
source verification and measurement must follow it. Saved-package preservation
and observed background-load limitations remain separate evidence.
