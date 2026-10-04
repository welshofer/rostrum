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

## Final SVG serialization and integration

The serialization checkpoint `f8b33ee` inherits optional ligature suppression once within a
homogeneous text body or line. Mixed policies keep their own span attributes;
cache identity includes the inherited context. Empty blocks add no policy, and
a defensive general-policy child restores normal defaults instead of forcing
optional ligatures on. Text positions, textLength, font resolution and
warnings remain unchanged.

The final large-table SVG is 11,997,344 bytes versus the initial combined
14,027,344, removing 2,030,000 redundant bytes (81.2% of this feature's initial
markup addition). It remains 470,000 bytes larger than a9d870b because the
native policy still needs representation. This is an exact output-size result,
not a timing or general memory claim.

The [final integration receipt](benchmarks/2026-10-04-fidelity4-final-integration-verification.json)
records another successful full gate: 1,107 Rostrum tests in 154 suites,
18 layout tests, 277 Core tests, 76 native app tests with zero failures/skips,
README examples, macOS build and both iOS simulator architectures. Supplemental
headless tests pass with the same three native WebKit exclusions. All 26 Lab
recipes again pass 337 checks, and 52 files independently reopen and pass ZIP
integrity checks.

Whole-tree comparisons on all four native fixture slides resolve effective
font-feature settings and remove only policy-only containers: every remaining
attribute, geometry and text value matches the earlier accepted output exactly.
Ordered diagnostics, inheritance and saved bytes match too. Both regenerated
manual Lectern variants pass 31 checks, show the expected four-slide previews,
and save bytes identical to the earlier manually exported specimens. Refreshed
native tests again exercise inspector/export for both variants.

The [fallback report](LAYOUT-PERFORMANCE-20261004-4.md) and final integrated
performance record separate source optimization from fidelity costs. Timing
remains workload-dependent and load-qualified; primary large-table performance
recovery and cross-platform performance remain open.

## Latest-main reconciliation

Main advanced to `6a1f56f` during verification. Merge `2953dc1` preserves its
automatic-number font selection and adjacent-run viewer advances alongside this
pass's native policy. Independent review compared both parents and approved.
The [merged integration receipt](benchmarks/2026-10-04-fidelity4-merged-integration-verification.json)
records a fresh full gate: 1,109 Rostrum tests, 18 layout tests, 277 Core tests,
76 native app tests with no skips, README and both Apple builds. The separate
headless run, all 337 Lab checks, and 52 independent deck reopens also pass.
The paragraph recipe's four SVGs and both saved width variants are byte-identical
to the prior checkpoint, preserving the recorded manual/native acceptance.
Performance against the new baseline is recorded separately from older timings.

The [current-main performance report](INTEGRATED-LAYOUT-PERFORMANCE-20261004-4-UPSTREAM.md)
records the remaining cost: observed large-table +3.97%, registered-table +2.51%,
and about 2 MiB additional process RSS under substantial background load. This
pass is a bounded fidelity tradeoff; it does not establish performance recovery.
