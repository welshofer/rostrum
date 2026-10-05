# Glyph reservation integration — 2026-10-04

The shaper now reserves its exact initial glyph capacity during the existing
normalized-scalar pass. This removes repeated array growth while preserving
source ranges, glyph order, substitutions, diagnostics and output. Normalization
can expand a scalar, so capacity follows the normalized emitting scalars; CR,
LF and zero-width spaces use the existing emission exclusions.

The separately measured registered-rendering median improves 1.59%, with all
ten matched pairs faster. Fitting remains inconclusive, long-combining results
have mixed statistical evidence, and whole-process RSS is mixed. No cumulative,
universal or lower-memory result is claimed. See the
[performance report](LAYOUT-PERFORMANCE-20261004-9.md) for the fresh profile,
paired estimates, host load, retained binaries and limitations.

Independent review accepted the source and evidence. Exact preservation covers
101,022 main and 288 supplemental shaping records, 114 fixture/font cases over
780 slides, and 273 independently reopened saved files. Three new tests cover
normalization expansion, control-only input, and missing-glyph/mark ordering.

## Integrated verification

At `051cf5b`, the full `./scripts/verify.sh` gate passes:

- 1,136 Rostrum tests in 160 suites and 18 layout tests in three suites.
- 281 Lectern Core tests in 38 suites and 76 native app tests in 21 suites,
  representing 106 executions, with zero failures, skips or known issues.
- Offline checks, README examples, the canonical signed macOS build and iOS
  simulator builds for arm64 and x86_64.
- 26 Lab recipes and 362 passing checks; 56 independent ZIP/python-pptx reopens
  covering 199 slides. All 302 external input files remained unchanged, and
  root independently rehashed them.

Both final six-slide paragraph decks are byte-identical to the preceding full
gate and the PowerPoint-accepted specimens. This preserves the existing native
PDF evidence and the prior manual GUI evidence for slides 2–6. The rebuilt app's
automated inspector/export tests ran in this gate; manual GUI and native PDF
capture were not repeated for this allocation-only change. The paragraph demo
passes 54 checks with zero findings; the full catalog retains 359 findings.

The [integration receipt](benchmarks/2026-10-04-glyph-capacity-integration-verification.json)
pins the tested source, full gate, external inspection, native identity transfer,
and prior manual evidence. [Previous native acceptance](LAYOUT-FIDELITY-20261004-6.md)
retains the exact spacing model and its limits.

Native fractional glyph painting/placement and duplicate line-break scan
research continue separately. Neither experiment is part of this checkpoint.
