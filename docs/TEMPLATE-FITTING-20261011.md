# Template rich-text fitting — October 11, 2026

`TemplateLayoutEngine` now plans and composes with the same `RichTextLayout`
geometry used by rendering and authored fitting. The previous paragraph-by-
paragraph estimator could accept overflowing right margins or tab stops, ignore
the actual bold/italic face, and reject text because it counted paragraph gaps
that the renderer suppresses at body edges. The initial nine regressions
reproduced fourteen failed expectations before implementation.

Planning constructs the exact prospective slide text and resolves its existing
layout/master inheritance without adding temporary slides. Normal autofit keeps
inherited line-spacing reduction and unknown attributes; a fitting stored scale
stays inherited. Explicit roles use the size and weight that will be written.
No master, layout or theme payload is rewritten. The renderer's layout algorithm
is unchanged; its inheritance resolver gains a package-only overload.

Composition rechecks the actual text before adding a slide. Stale content or
inherited styles that no longer fit and incompatible column counts fail without
leaving a partial slide. Later calls see newly imported layouts. Vertical text,
multiple text columns, horizontal overflow and more than 64 rendered lines are
rejected. The host callback supplements positioned spans conservatively, using
the available body width; it cannot override an overflow found by shared
geometry. The callback still lacks an italic flag and is not a full shaping API.

Fifteen focused regressions cover these cases, saved/reopened styles and
geometry, invalid host measurements, exact line spacing, inherited autofit and
styled-block measurement. The Templates and Properties Library Lab runs a
POTX → plan → compose → save/reopen example in both 16:9 and 4:3. It keeps the
source POTX and output PPTX, verifies unchanged template parts, and exercises the
inspector SVG and export paths with embedded DejaVu. Both variants pass all
thirteen saved-file checks; their font-aware rasterized previews were inspected.

## Performance and limits

The [raw record](benchmarks/2026-10-11-template-fitting.json) contains CPU and
elapsed times, whole-process peak RSS, source/font/binary hashes, selected plans
and output checks. Swift 6.1.3 Release executables ran on one Linux host with two
warmup pairs and fifteen alternating AB/BA pairs per scenario, with builds and
tests idle. Each sample runs forty `plan` or `fits` calls on the same engine.
Font loading, serialization and final composition/geometry checks are outside
the measured section. This does not measure end-to-end composition throughput.

The comparator retains the original template engine and its related value types
from `9b934937b1a79a9804c4037494e6701bbd85e3ef`, with the class renamed to
`LegacyTemplateLayoutEngine`. Both executables link the same Release Rostrum
objects. A complete pre-change Release executable was also retained and measured
before implementation.

| Forty-operation workload | Legacy → shared, median CPU ms | Faster pairs |
| --- | ---: | ---: |
| Layout selection, repeated content | 59.859 → 36.969 | 15/15 |
| Layout selection, distinct content | 59.195 → 37.980 | 15/15 |
| Shrinking, repeated content | 38.697 → 68.614 | 0/15 |
| Shrinking, distinct content | 39.301 → 79.010 | 0/15 |
| Inherited tabs and explicit breaks | 3.027 → 2.452 | 14/15 |

Inheritance and prospective-body reuse are local to an operation and retain at
most 64 contexts. Ranking reuses already accepted occupied heights instead of
laying out each body again. Layout selection is faster in these controls, while
binary-search shrinking now performs full geometry at each tested scale. That
adds roughly 0.75–0.99 ms per shrink check in these inputs. No cross-operation
geometry cache or general speedup is claimed. Prepared-run reuse across scales
remains a possible follow-up, requiring its own preservation and timing checks.

Median whole-process peak RSS stays near 22.6–22.8 MiB in all controls. This
includes fonts, document state and post-timing verification, so it does not
isolate fitting allocation. The largest observed candidate elapsed p95 is
83.172 ms for forty distinct shrink checks, using nearest-rank p95 over fifteen
samples. These measurements do not establish cross-platform budgets.

## Preservation and reproduction

Every timed sample accepts forty calls and leaves serialized source bytes
unchanged. All five proof scenarios compose two text placeholders that pass
shared geometry in both versions. Ten benchmark PPTX files pass ZIP CRC and
python-pptx reopen checks. The six Library Lab PPTX files also pass those checks;
the four POTX files pass CRC checks and the Lab's Rostrum template round trip.
python-pptx does not directly accept POTX.

The tab control is byte-identical between engines. All other output differences
are confined to the new slide XML: shrinking selects a different normal-autofit
scale, and role runs omit the old synthesized `lang="en-US" dirty="0"` attributes.
All template/master/theme parts and other package payloads match. The raw record
retains hashes and changed-part lists; it does not claim byte-identical corrected
output to the legacy algorithm.

The [driver](benchmarks/2026-10-11-template-fitting-driver.swift) runs from the
repository root after `swift build -c release --target RostrumLayout`. Compile
with `swiftc -O -package-name rostrum -I .build/release/Modules`, the driver,
all objects in `.build/release/Rostrum.build/` and
`.build/release/RostrumLayout.build/`, and `-o /tmp/template-fit`. Run
`/tmp/template-fit SCENARIO [OUTPUT.pptx]` with a scenario from the table's JSON
record. For the legacy comparator, copy the original engine source from the
baseline commit and rename its class, copy the driver to `main.swift`, then
compile both sources with `-D LEGACY` and the same objects. The optional package
access is used only by the driver's independent rendered-geometry check.

Native PowerPoint open-without-repair, visual comparison and native autofit
selection remain unverified for these new computed specimens. The existing
saved PowerPoint reference gate is independent. Consistency with the shared
renderer is necessary for reliable composition, but does not establish complete
DrawingML typography or universal Office equivalence.
