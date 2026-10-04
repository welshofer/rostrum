# Empty-line typography and shaping performance — 2026-10-04

Consecutive manual breaks and trailing paragraph breaks now retain their own
font metrics. Previously, a blank line could use paragraph defaults instead of
its terminating break's size, moving subsequent text by 14–22 pt in the native
counterexamples. A trailing
empty line now resolves paragraph-end properties over its paragraph defaults;
populated lines still take their metrics from their visible content.

The independent [PowerPoint fixture](../Tests/RostrumTests/Fixtures/NativeBreakMetrics/README.md)
contains 18 cases on three slides. Its 35 native marker outlines match the
licensed DejaVu Sans source. All 16 ordinary-spacing cases now match within
0.121 pt, including table cells and centered/bottom alignment. Two exact/percentage
spacing cases retain four explicit known-issue baseline assertions. Glyph counts,
identity, horizontal positions, diagnostics and rendering purity remain strict.
This is a bounded correction, not a claim of complete typography fidelity.

## Lectern acceptance

The existing paragraph demonstration now has a fifth slide with consecutive
breaks and trailing paragraph-end formatting. The option switches empty lines
between 6 and 36 pt. Original specimens are shown beside both public fitting
APIs, with computed scales and saved/reopened properties checked explicitly.
All 40 paragraph checks pass. The catalog still has 26 demonstrations and now
passes 348 checks in the full saved-file pipeline.

PowerPoint 16.113.3 opened both owned specimens without repair. Local print PDF
exports verify all 24 marker outlines, original baselines within 0.121 pt of the
library's rounded positions, equal native positions for the two fitting paths,
and containment of the fitted glyph boxes. No native-selected autofit claim is
made. The original frames were shortened from 160 to 120 pt for the display;
top alignment and ample height preserve their marker positions.

Manual testing found two incidental preview warnings caused by middle-dot
punctuation in the explanatory captions. ASCII semicolons keep those captions
inside the demo's declared profile. The final test requires a warning-free fifth
slide before and after saving. Exact comparison proves this caption correction
changes only two separators in slide5.xml: all six specimen shape subtrees and
every other package part remain identical to the native captures.

Both final options were generated in the rebuilt app with an edited title and
four sentences. Each passed 40/40 checks with no preview findings, showed five
slide previews in the actual inspector, and exported all five slides through
Export Everything. Exported text, report files and package bytes are pinned in
the [integration receipt](benchmarks/2026-10-04-empty-lines-shaping-integration-verification.json).
The subsequent combining-category optimization preserves both native specimen
decks byte-for-byte; its broader shaping/render identity proof is separate.

## Performance acceptance

Three independently reviewed changes remove repeated work without changing the
recorded output. Each measurement uses its own fresh matched baseline; these
percentages must not be added or presented as a cumulative historical recovery.

| Change | Matched measured improvement | Evidence |
|---|---|---|
| Reuse the most recently admitted render style | Large fallback render 3.75%; registered render 2.26% | [Recent-style report](LAYOUT-PERFORMANCE-20261004-5.md) |
| Skip redundant bidi bookkeeping for LTR-only shaping | Registered render 4.91%, ten of ten pairs faster | [LTR report](LAYOUT-PERFORMANCE-20261004-6.md) |
| Skip impossible ASCII combining-category queries | Registered render 4.44%; fitting 6.85%, ten of ten pairs faster for each | [Combining report](LAYOUT-PERFORMANCE-20261004-7.md) |

The style cache keeps its existing raw UTF-8 key, admission limits and reset
semantics. The shaping guards preserve RTL behavior, normalization, source
ranges, glyph records and ordered diagnostics. Each shaping change separately
matches 100,734 full shaping records and 96 fixture/font cases covering 748
slides, plus fixed workloads and package preservation: 228 independent reopens.
Root independently rehashed 76 pins for each of the first two reports and 73
for the last. An independent reviewer recomputed paired statistics and reviewed
the source and proof scope. Substantial background load is recorded; no general,
cross-platform or lower-memory result is claimed.

## Integrated verification

At source `a98dd69`, the full `./scripts/verify.sh` gate passes:

- 1,123 Rostrum tests in 157 suites, with the four known spacing assertions above.
- 18 layout tests; 279 Lectern Core tests in 37 suites.
- 76 native app tests in 21 suites, zero native failures or skips.
- Offline workflow checks, README examples, signed macOS build and both iOS
  simulator architectures.

The earlier integrated `102922b` gate also passed. Its first attempt exposed two
stale four-slide test expectations, corrected to five; manual verification then
found the caption warnings described above. These failed checks remain recorded
in the local evidence rather than being reclassified as passing.

The known GitGuardian finding in the earlier verification receipts is a verified
source-file checksum, not a credential. Authenticated dismissal remains pending;
the scanner has not been disabled. The existing draft PR remains the delivery
vehicle. Native exact/percentage spacing, inherited styles outside the captured
profile and broader font/script fidelity remain active follow-up work.
