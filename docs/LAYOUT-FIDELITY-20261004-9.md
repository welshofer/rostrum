# Native glyph paint integration — 2026-10-04

The shared layout now separates authored, measured and painted font sizes for
its calibrated Latin profile. Admitted runs emit explicit scalar x positions
without glyph stretching. Absent resolved kerning and explicit zero disable pairs; positive
thresholds use the measured size. Public table-cell context ignores stored font
scale, and cell fitting reads live padding/style/anchor at 100% scale with zero
reduction without mutating the document. Unverified stored table line reduction
remains diagnosed and fitting returns false.

At integration `15204a9`, independent source review and the retained automated
stages pass. This is a partial native/manual acceptance checkpoint: the table
PDFs, alternative table opening, current manual Lectern demo runs and new bullet
capture remain pending. The
[integration receipt](benchmarks/2026-10-04-native-paint-integration-verification.json)
pins the exact source, logs, external inputs and review receipts.

## Demonstration and drawing evidence

The existing paragraph recipe now has seven slides. Its final slide selects
six of 12 native regular DejaVu Sans specimens, preserving their original text
bodies and frame sizes. The alternative switches to scaled examples. Separate
copies exercise both public fitting APIs; computed fits are not claimed to be
PowerPoint-selected autofit. Both options pass 74 checks without preview
findings. The cell-appearance recipe adds a third slide and passes 20 checks;
its stored-scale diagnostic remains visible. A retained cell text frame first
rejects cramped padding, then accepts the updated padding/style/anchor without
changing either stored body. Saved-file checks compare exact properties, live
fit results, layout and actual SVG.

Actual WebKit captures use the same offscreen host as Lectern's bitmap path,
with bounded embedded-font readiness, page scripting disabled, and retained
raw SVG/PDF plus source hashes and viewport/MediaBox information. The final
paragraph captures consume the exact saved inspector SVG. Independent PDF
subset-outline and raw-matrix checks pass for 14 cases / 208 visible glyphs:
12 paragraph specimens / 188 glyphs, plus a separately labeled raw-library
positive/disabled kerning pair / 20 glyphs. Extractor controls reject wrong
paint size, origin and source font. Real-host tests also reject invalid used
font data, recover on the same host, check actual glyph-region bitmap ink, and
cancel an active navigation before a distinct successful replacement capture.

Both final seven-slide paragraph PPTX variants opened in PowerPoint without
repair. PDFs were produced through local printing with online printing off.
Independent seventh-slide checks pass for all 188 original glyphs: maximum
current PDF-versus-SVG x/baseline residuals are 0.01504/0.08002 pt, with source
outline ink dimensions agreeing within 0.000000388 pt. Prior-reference print-grid
residuals remain separately recorded; their maxima are not silently substituted
for current-output tolerances. A separate review verifies 32 spacing markers
and 24 earlier empty-line markers. Root also visually inspected PDF slides 6
and 7 for both variants. Source and PDF pins remain unchanged.

The default three-slide table deck opened without repair, but PowerPoint stalled
during Save As. That opening alone does not establish rendering acceptance.
Table PDFs, alternative opening and native checks of the new table Lab remain
pending. Actual app tests do cover the inspector/export flow for both paragraph
options and the table recipe; current manual Lectern GUI runs are still pending.
No general raster parity, native autofit selection or new bullet acceptance is
claimed.

## Automated stages and retained failures

The original full `./scripts/verify.sh` run passed 1,148 Rostrum tests in 162
suites, 18 layout tests in three suites, 286 Core tests in 40 suites, offline
checks, README examples and macOS/iOS simulator builds. Its app stage failed
three newly added SVG equalities, so that command exited 65. The assertions had
compared raw library rendering (1280×720 and embedded-only fonts) with inspector
rendering (640×360 and installed/Arial fallback). Painted glyphs and font data
were identical; 18 empty decorative text baselines differed. The corrected
assertions retain byte-exact comparison against the actual fresh inspector
preview and retain every independent native glyph/body check. Paragraph WebKit
capture was also corrected to consume that exact inspector preview.

An intervening app rerun is invalid evidence: an accidental concurrent build
removed fixtures while tests were executing, producing 19 issues. Its log is
retained. The final serial canonical app run at `a065a4e` passes 80 tests in 22
suites / 110 executions, with zero failures, expected failures, skips or
xcresult runtime warnings. Production library/Core/app sources are unchanged
from the initial gate; only the two test corrections followed it. The final
performance-evidence commit changes documentation only.

Eleven contradictory quiet-build messages saying a command failed with exit
code zero remain in the initial log: four macOS and seven iOS. Both stages
returned success. Additional canonical nonquiet macOS/iOS confirmations explicitly
report `BUILD SUCCEEDED`; the diagnostics were not suppressed.

Independent external checks pass all 387 checks across 26 Lab recipes, 60 ZIP
CRC/python-pptx reopens covering 225 slides, and parsing of 1,683 XML/relationship
parts. All 313 external input hashes remain unchanged. The catalog reports 411
findings across its full supported/unsupported examples; these are not hidden
or confused with failing checks.

## Performance and remaining work

The separately reviewed [performance report](NATIVE-PAINT-PERFORMANCE-20261004-11.md)
measures registered-table rendering 4.257% faster by the ratio of medians and
3.901% faster by paired median, with 10/10 pairs faster. Fitting retains an
inconclusive possible cost, native-deck timing is inconclusive, and substantial
WindowServer/Photos/Spotlight load limits inference. These are workload-specific
results, with no cumulative historical speedup or general memory claim.

This remains ongoing work on draft PR #39. Complete the stalled table-native
checks, current manual Lectern demonstrations and the separate 18-case bullet
capture before claiming those acceptance steps. No merge or deployment is
recorded by this checkpoint.
