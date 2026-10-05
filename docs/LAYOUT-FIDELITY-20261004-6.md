# Explicit line spacing and shaping allocation — 2026-10-04

Exact and percentage line spacing now reproduce the captured PowerPoint
baselines, including compatibility modes, authored scaling, spacing reduction,
empty lines, and centered/bottom alignment. The independent native set contains
85 new cases plus 18 earlier break cases. All 103 pass the unchanged 0.121 pt
tolerance; the earlier two known cases and their four exclusions are removed.

The correction is bounded to the existing printable ASCII, left-to-right
calibrated profile, with real Windows metrics and a single resolved font
registration on each physical line. Exact spacing rounds the declared pitch and
ignores line-spacing reduction. Non-100% percentage spacing uses the captured
compatibility height and subtracts reduction in percentage points. Painted
baseline rounding stays separate from unrounded content extent and natural
descent. The final line excludes excess pitch below its content.

Additional native controls were necessary to distinguish competing extent
models: the intermediate model passed 97/103, while the corrected model passes
103/103. Those failed models remain in the
[fixture evidence](../Tests/RostrumTests/Fixtures/NativeLineSpacing/README.md).
Normal/100% spacing and unsupported profiles retain their previous arithmetic.
Mixed font registrations on a line produce an explicit diagnostic. Font ink,
horizontal advances, native-selected autofit, and general Office parity are
separate questions; this change does not claim they are solved. Two system-Arial
controls run only when the face is available; all 83 new DejaVu cases are portable.

## Lectern and native acceptance

The paragraph Lab demo now has a sixth slide with six original 290 by 160 pt
specimens. Its default option demonstrates exact/percentage spacing,
compatibility modes and vertical anchors. Its alternative demonstrates stored
font scale and spacing reduction, including centered and bottom anchors. All
12 imported text bodies retain their exact properties and native provenance.
Both public fitting paths remain exercised on the preceding slides.

Before the engine correction, the new demo tests failed 36 native-position
assertions across both options. The integrated paragraph tests now pass with no
exclusions. Each option passes 54 file checks with zero preview findings, checks
saved geometry and properties, and exercises the real app inspector and export.

PowerPoint 16.113.3 opened both six-slide decks without repair. Visual review
found no caption/frame collisions. Local print PDFs verify all 32 new marker
outlines and baselines against the library within 0.121 pt, with marker bounds
inside the original frames. The preceding empty-line slide was also rechecked:
24 marker outlines, native original baselines, and equal/contained fitted copies.
Source PPTX files remained unchanged. Final-gate files are byte-identical to the
native specimens.

Both options were then run manually in the rebuilt Lectern app with the title
“Fidelity Eight Verified” and four sentences. Both showed six inspector previews
and exported six slides through Export Everything. Independent package comparison
shows that only slide1 differs from the native specimens; slides2–6 and all other
parts are identical. Exported words, option selection and report contents were
checked and pinned.

## Performance and full verification

The separately measured singleton scalar storage change reduces registered
rendering median time by 2.53% and rich fitting by 8.95% against its own matched
baseline. Long-combining median time increased 0.44%, with an interval spanning
zero; a small cost remains unresolved. Registered whole-process RSS rose
0.21875 MiB. These are qualified workload results under background load, without
a general speed, nonregression, cumulative or memory claim. The first attempted
implementation remains unshipped with evidence retained. See the
[performance report](LAYOUT-PERFORMANCE-20261004-8.md).

At `d338c42`, the full `./scripts/verify.sh` gate passes:

- 1,133 Rostrum tests in 159 suites, with zero known issues; 18 layout tests.
- 281 Lectern Core tests in 38 suites; 76 native app tests in 21 suites,
  representing 106 executions, with zero failures or skips.
- Offline checks, README examples, the canonical signed macOS build, and iOS
  simulator builds for arm64 and x86_64.
- 26 Lab recipes and 362 passing checks; 56 independent ZIP/python-pptx reopens
  covering 199 slides. All 302 external input files remained unchanged.

The Lab retains 359 documented findings across the whole catalog. Only the
paragraph demo is described as having zero findings. Root rehashed all 302
external inputs, all nine source/PDF pairs, and 108/93 performance manifest pins
for the deferred/accepted experiments. Independent review approved the source,
native model, copied references, performance proof/statistics and external files.
The [integration receipt](benchmarks/2026-10-04-explicit-spacing-integration-verification.json)
pins the exact source, tests, native captures, GUI exports and limits.

Glyph-array reservation and native painted-size/placement research continue
separately. This checkpoint does not include those experiments.
