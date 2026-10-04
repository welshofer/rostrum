# Tab layout and line-break performance — 2026-10-03

This continuation of FUNC-2 and PERF-1 targets standard tab stops in the shared
fitting/rendering engine and removes measured line-break allocation work.
Animation remains outside the pass.

## Shared tab geometry

Left, center, right and period-decimal tab stops now participate in the same
layout used by text fitting, SVG rendering and table cells. Complete fields are
measured once, trailing spaces are excluded from their alignment, and explicit
stops are searched without repeated linear scans. Wrapped fields preserve their
native anchoring, including the centered-field right-edge rule and carrying a
tab onto the next line when its first word does not fit. Justification expands
only the interior spaces following the last tab on each line.

The independent python-pptx fixtures were opened without repair in PowerPoint
16.113.3 and exported through its local print renderer. The portable oracle
checks 60 cases, including word starts and ends, complete glyph consumption,
all four tab modes, paragraph left/center/right/justified alignment, mixed
formatting, wrapping, no-wrap, hanging bullets, collisions and inheritance.
Its tolerance is 0.25 points. Numeric font metrics keep the checks independent
of installed test-machine fonts; this is horizontal geometry evidence.

Tab metadata is stored only for tab atoms. Ordinary left-aligned paragraphs
avoid the field and script scans, and retain the earlier arithmetic order.

## Public paragraph authoring

`Paragraph.tabStops` exposes left, center, right and decimal stops through
`TextTabStop` and `TextTabAlignment`. Positions use EMU. A missing list inherits;
an explicit empty list suppresses inherited custom stops. The optional
`defaultTabInterval` controls the repeating interval. Reading these properties
does not modify XML. Setting stops preserves extension children in the list.

The native fixture distinguishes the intrinsic 72-point default from a
template's inherited 36-point interval. Missing, empty and overridden tab lists
have separate native cases, so these semantics are checked independently of
Rostrum's authoring API.

## Lectern coverage

The 25th Library Lab recipe exercises all four tab modes, a movable stop,
tab-aware justification and matching table-cell layout through the public API.
It has 13 saved-file checks. The actual macOS app passed generation, inspection
and Export Everything with twelve rows at both stop positions. App tests also
cover both variants. All 25 recipes together have 310 saved-file checks.

## Performance evidence

The [combined benchmark](INTEGRATED-LAYOUT-PERFORMANCE-20261003.md) measures
**2.26% slower fallback table rendering and 3.01% slower rich-text fitting**
against `cf1b8a0`, with both slower in all ten alternating fresh-process pairs.
Registered-font table rendering is 0.75% faster with overlapping ranges. These
regressions remain open; this batch does not establish a net speed improvement.
Four measured workloads retain identical output across 13 slides.

The earlier [isolated ASCII scan](LAYOUT-PERFORMANCE-20261003-2.md) improved
registered-font table rendering 3.96%, preserving 580 compared slide outputs.
That result does not describe the combined tab engine. Mixed Unicode retains
the general break-scan path. One [bounded follow-up experiment](INTEGRATED-LAYOUT-PERFORMANCE-20261003-ATTEMPT.md)
passed correctness checks but failed to remove the regressions; its source
change was discarded. No net memory or cross-platform speed gain is claimed.

## Verification and remaining work

The [burn-down report](../burn-down-report-20261003-2.md) records final integration
checks and native PowerPoint evidence. Profiling the common layout overhead is
the next performance target. Full bidi layout, locale-specific decimal separators,
multi-column flow, decoration geometry, narrow font-rounding boundaries and
the existing table raster discrepancies remain separate fidelity targets.
Whole-slide Office pixel equivalence is not established by numeric tab anchors.
