# Ordered atom layout integration — 2026-10-04

Ordered, nonoverlapping non-ASCII shaping ranges now append layout atoms without
building a dictionary and sorting its keys. Repeated, overlapping, reordered
and RTL ranges retain the existing fallback. Native glyph sizing, placement,
wrapping and diagnostics are unchanged. Independent source/performance review
accepted the second measured implementation; the first iteration's registered
rendering regression remains retained and withheld.

The integrated source at `aded5d2` has a passing full local gate at `b5076bf`,
followed by a separately passing new Unicode app test. The
[integration receipt](benchmarks/2026-10-04-ordered-atoms-integration-verification.json)
pins source, logs, current performance-report acceptance, external comparisons
and both bounded native table checks. The preceding
[checkpoint](LAYOUT-FIDELITY-20261004-9.md) remains unchanged, including its
failed assertions, invalid concurrent run and then-pending native steps.

## Actual Lectern coverage and automated checks

The existing Fonts and fitting Lab now has an app-hosted test with composed
`café` / `naïve`, decomposed `café`, and `ffi`, at both fitting widths.
It runs LibraryLabModel → real AppState inspection → export, requiring the
recipe's existing checks, exact UTF-8 text preservation, embedded-font recovery,
saved-inspector preview identity and visible native-profile limitations. The
recipe and UI are unchanged. This verifies usable offline coverage of the
optimized path without claiming native Unicode painting or a native-selected
fit scale.

The full `./scripts/verify.sh` gate returned zero: 1,151 Rostrum tests in 163
suites, 18 layout tests in three suites, 286 Core tests in 40 suites, offline
checks, README examples, macOS/iOS simulator builds and 80 app tests in 22
suites / 110 executions all pass. The app xcresult reports no failures, expected
failures, skips or runtime warnings. Afterward, the new app test passes in a
separate serial run: one test / two parameter cases, 7.429 seconds. This is
**80 full-gate tests plus one focused test**, not an 81-test full-gate run.
Production library/Core/app sources are unchanged between those runs.

The first focused command selected the nonexistent `LecternTests` target and
exited 70 without executing tests. Its log remains; the corrected selector uses
`LecternAppTests`. The full gate also retains eight exact quiet-build messages
claiming failure with exit code zero (four macOS, four iOS). Seven additional
app-host WebContent clipboard console lines contain `error:`, explaining the
broader 15-line grep count. Separate nonquiet macOS/iOS confirmations both
explicitly report `BUILD SUCCEEDED` with zero `error:` lines.

The portable kerning pipeline fixture now embeds the licensed DejaVu Sans face
instead of depending on an installed font. Strict absent/zero kerning-off and
positive-threshold expectations remain, with exact saved font bytes/family and
an explicitly unregistered missing-font fallback control. The earlier Linux
failure and passing four-test focused Core run are pinned; no Linux rerun is
asserted by this local receipt.

Independent checks pass all 387 checks across 26 Lab recipes, retaining 411
reported findings. All 313 input files are unchanged; 60 ZIP CRC/python-pptx
reopens cover 225 slides and 1,683 XML/relationship parts. All 12 special deck/SVG
comparisons match the prior checkpoint, including all four native paragraph and
table source packages. Fresh actual WebKit PDFs pass 14 cases / 208 visible
glyphs at unchanged bounds: 12 paragraph specimens / 188 glyphs from exact saved
inspector SVGs, plus the separately scoped raw-library kerning pair / 20 glyphs.

## Native evidence and remaining scope

Earlier independently verified PowerPoint paragraph evidence transfers by exact
source and inspector-SVG identity: 188 glyphs, 32 spacing markers and 24 empty-line
markers. No new paragraph PowerPoint capture is claimed here.

After recovering from the retained Save As stalls, both three-slide table
variants opened in PowerPoint without repair and produced local PDFs with online
printing off. Root visually inspected page three of both: two complete lines at
full 20 pt. Independent checks now pass all 30 visible cell glyphs per variant,
60 total, against actual subset outlines and raw PDF font transforms. Stored
50% scale, authored 20 pt, middle anchor and exact padding remain in the source;
left padding is 18 pt by default and 32 pt in the alternative.

The table expectations come from saved SVG/source-font geometry, not a prior
independent native-case JSON. The captured PowerPoint PDFs supply the independent
oracle. Both variants stay within the original 0.06 pt x, 0.121 pt baseline and
0.002 pt paint/ink bounds: maximum x/baseline errors are 0.010004/0.079993 pt,
maximum ink-dimension error is below 0.000001 pt. Source bytes stay unchanged;
current exports match those sources and SVGs exactly. A separate independent
review re-extracted all 30 alternative glyphs and confirmed that transfer. Original parser warnings
remain in the receipts. This establishes the page-three cell specimens, not
whole-deck table/manual Lectern acceptance, raster parity or native autofit choice.

Current manual Lectern demonstrations and the separate new 18-case bullet capture
remain pending. Automated inspector/export and WebKit checks do not replace those
steps. Work remains on draft PR #39; no merge or deployment is claimed.

## Bounded performance result

The [reviewed performance report](ORDERED-ATOMS-PERFORMANCE-20261004-12.md)
retains both measured iterations and unchanged raw evidence. In cycle two,
paired medians improve fitting 14.05%, rich-text rendering 7.07% and accented/CJK
rendering 3.40%, each with 10/10 faster pairs. Registered rendering is +0.244%
with an interval crossing zero; fallback and combining controls retain possible
costs. RSS signs are mixed, and substantial WindowServer load limits inference.
The first cycle's registered regression is not erased. There is no cumulative
historical speedup, universal nonregression, clean-host or cross-platform claim.
