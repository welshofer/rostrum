# Native mixed-face exact line spacing

These 12 independently authored PowerPoint cases demonstrate a real vertical
layout defect and a bounded correction. Before the change, both top-anchored
mixed-face cases placed glyphs about 9.08 pt too low. All horizontal origins,
painted sizes and exact per-run font outlines already matched. The old path
truthfully diagnosed the unverified combination, then used natural ascent.

## Native observations

| Group | Cases / glyphs | Source SHA256 | Accepted PDF SHA256 |
| --- | --- | --- | --- |
| base | 4 / 32 | `4e12a5e02468873d34fadb0ea415836ee50fa92245d9e096721faee33013c014` | `9d8c125d036eb15b0b0c3f2cf84e6a2b47f0f79812ca003a056814d74ca7268b` |
| anchors | 8 / 64 | `ade8628fe0ca6c69691ad0790e9678bf92aaa7d2cd3178b5723dcb5c2adc9ea0` | `49ec14886c2dbee1701b25039f362c221569957742a20d82ea0b18dd84af1c64` |

PowerPoint 16.113.3 opened both one-slide decks without repair. Root captured
local Best for printing, explicitly observing printing=1 and online=0 before
saving. Source PPTX files were never saved. Each group's receipt records these
observations. Every glyph is matched to its own authored actual face's outline;
case-wide defaults are insufficient for the mixed runs.

The base controls use 24 pt Sans alone, 24 pt Serif alone, 12 pt Sans `Ag` plus
24 pt Serif `jp`, and reversed run order. All have two identical lines, exact
18 pt spacing, zero insets and top anchoring. The native mixed baselines are
13.920044/31.920044 pt versus the pre-change library's 23/41 pt. The established
whole-point content baseline model gives 14/32 pt; the small residual is the
previously measured PDF print-grid phase, not an SVG snapping prescription.

The eight followup cases use the same mixed runs in fixed 290 × 140 pt frames:
exact18/36 × stored100/72.5% × center/bottom. They constrain anchored content
extent and scaled metrics independently. At 72.5%, actual paint remains 9/17 pt
for authored effective sizes 8.7/17.4 pt. These are authored scale controls, not
native-selected autofit settings. `math-proof.py` applies the earlier single-face
exact-spacing model to source font fields and all 12 independent captures. Its
unrounded extent model passes all cases within 0.121 pt; rounded-extent alternatives
are retained and rejected. Maximum model baseline residual is 0.114929 pt.

## Supported extension and boundaries

The two distinct actual font resources have identical normalized Windows ascent
share and Windows height. Only those source metric values establish equivalence;
font family names and aliases do not. The new admission requires:

- Shape context, explicit point spacing, compatible spacing omitted/true, zero reduction.
- Actual nonnil resolved registry keys for both distinct faces.
- Existing finalized scalar/paint eligibility, positive metric sizes and real Windows data.
- Exact equality of both normalized Windows metrics across participating faces.
- Valid stored or explicit scale inputs for this new mixed-face path.

The existing maximum calibrated height, exact pitch/ascent and unrounded extent
rules then apply. Same-face behavior is unchanged. Unequal metrics, mixed-face
percentage spacing, table contexts, compatibility false, nonzero reduction and
rejected scalar/paint profiles keep their existing fallback and diagnostic policy.
A missing Windows metric retains its prior uncalibrated behavior; this change does
not claim new diagnostics for every old missing-metric path. No general mixed-font
rule or universal PDF glyph-origin bound is asserted.

## Reproduction and verification

Fonts reuse `../NativeListMarkers/fonts` and its license; source decks embed the
exact licensed Sans/Serif bytes. There are no system-font skips or runtime dependencies.
Generators use python-pptx and explicit OOXML, independently of Rostrum. Extractors
match source/subset outlines and raw PDF matrices, retaining raw streams, origins,
paint and geometric ink. MuPDF converted outline deltas remain separate.

```
python3 Tests/RostrumTests/Fixtures/NativeMixedFaceSpacing/audit.py
python3 Tests/RostrumTests/Fixtures/NativeMixedFaceSpacing/base/capture.py
python3 Tests/RostrumTests/Fixtures/NativeMixedFaceSpacing/anchors/capture.py
python3 Tests/RostrumTests/Fixtures/NativeMixedFaceSpacing/math-proof.py
swift test --jobs 2 --filter 'NativeMixedFaceSpacingTests|NativeLineSpacingTests|NativeBodyAlignmentTests'
```

Python tools require python-pptx, lxml, fontTools, PyMuPDF and pypdf. Retained
`baseline-layout.json` files are pre-change observations, never expected native
values. The new tests first failed with 37 issues. Tests retain complete visible
scalar consumption, exact actual font resources, unchanged native bounds (line
start0.025 pt; finite scalar origin0.06 pt; baseline0.121 pt; paint/ink0.002 pt),
serialization purity and deterministic SVG. Real OS/2 field replacement tests
isolate both metric signature axes without changing glyph coverage. Aliases,
live replacement, missing/invalid metrics, incompatible contexts and public fitting
are covered. Both fit APIs now compute 100%/0% for the captured mixed body in a
40 pt frame, using its native-constrained 37.334899 pt extent; no native fit-choice
parity claim is made. Full command receipts belong in `verification.json`.
