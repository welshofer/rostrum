# Authored rich-text fitting — October 11, 2026

`AuthoredLayoutEngine` previously flattened each paragraph into a single string
and measured it with the first run's style. A 24 pt run followed by 48 pt text
could be accepted even though the rendered body overflowed. Fields, explicit
breaks and no-wrap width checks also had gaps. Authored fitting now measures the
complete body with `RichTextLayout`, including its inheritance and registered
faces. Template planning remains a separate measurement path.

Accepted fits save normal autofit and retain original run sizes, styles, fields
and text. Explicit percentage line spacing and point paragraph gaps may be
compacted; exact line spacing and inherited styles remain intact. Failed bodies
are unchanged. The read-only layout and renderer algorithms do not change.

Fifteen focused regressions cover mixed sizes, inherited sizes, breaks, fields,
no-wrap overflow, exact spacing, retained run facades, unknown markup, selection,
host measurements, slide-number field substitution, unsupported vertical/column
text and operation-local reuse.
The initial seven tests reproduced six failed expectations against the old code.
The Fonts and Fitting Library Lab includes an original/fitted mixed-size page,
with reopened geometry, formatting and normal preview/extraction checks.

## Performance and limits

The [raw record](benchmarks/2026-10-11-authored-fitting.json) retains paired
samples, CPU/elapsed time, process peak RSS, font/source/binary hashes and output
checks. Swift 6.1.3 Release executables ran on the same Linux host with two
warmup pairs and fifteen alternating AB/BA pairs per scenario. Builds and tests
were idle during timing. Each successful operation fits 100 shapes. Geometry
verification, serialization and font loading are outside the measured section.

The legacy comparator contains the original fitting algorithm from `783d1fe`,
renamed to coexist with the current module, with its unchanged request value type
and callback alias copied into the harness for access. Both executables link the
same Release Rostrum objects. A complete pre-change Release executable was also
retained and measured before implementation.

| 100-shape workload | Legacy → shared fitting, median CPU ms | Shared geometry accepted after fitting |
| --- | ---: | --- |
| Repeated plain text, fallback | 1.454 → 1.060 | 100 → 100 |
| Repeated plain text, registered DejaVu | 1.676 → 1.064 | 100 → 100 |
| Repeated mixed-size text | 1.740 → 1.534 | 0 → 100 |
| Repeated paragraphs requiring shrinking | 15.988 → 2.287 | 100 → 100 |
| Distinct plain text, fallback | 1.489 → 2.605 | 100 → 100 |
| Distinct plain text, registered DejaVu | 1.624 → 3.774 | 100 → 100 |
| Distinct mixed-size text | 4.644 → 42.586 | 0 → 100 |

The repeated cases benefit from bounded per-operation fit reuse. The first
uncached implementation measured about 34 ms for repeated mixed-size text and
130 ms for repeated shrinking; reuse reduces this duplicated work without
changing saved bytes. Cache retention is limited to 64 entries and 256 KiB of
serialized keys, not a claim about total heap allocation.

Distinct text remains slower. Plain registered text adds about 2.2 ms per 100
shapes; mixed-size fitting does substantially more work to produce correct
geometry. This is a correctness/performance tradeoff, not a general speedup.
The distinct shrinking control fails at the first unfit body in both versions;
its timings are retained separately and are not a 100-shape throughput result.

Median whole-process peak RSS stays near 17.5–19.9 MiB across these cases. That
includes the document, fonts and post-timing verification; no lower-memory claim
is made. Elapsed tails vary on this shared host: the distinct mixed-size case
has an observed nearest-rank p95 of 48.6 ms. These samples do not establish a
regression budget or cross-platform performance.

## Preservation and reproduction

All four repeated scenarios produce byte-identical PPTX output with and without
fit reuse. The two already-fitting plain-text scenarios also match legacy
output bytes. All twelve proof decks pass ZIP CRC checks and reopen with
python-pptx with all 100 shapes. Mixed-size and shrinking output intentionally
differs from the legacy fitter: the selected fit is stored as normal autofit,
and authored run sizes remain intact.

The [driver](benchmarks/2026-10-11-authored-fitting-driver.swift) runs from the
repository root after `swift build -c release --target RostrumLayout`. Compile
it with `swiftc -O -I .build/release/Modules`, the driver path, all object files
in `.build/release/Rostrum.build/` and `.build/release/RostrumLayout.build/`, and
`-o /tmp/authored-fit`. Run `/tmp/authored-fit SCENARIO [OUTPUT.pptx]` using the
scenario names in the JSON record. `-unique` varies the text in each shape.
The optional `LEGACY` compilation flag selects the separately retained legacy
class for paired comparisons; it is not part of the library.

Native PowerPoint open-without-repair, visual comparison and native autofit
selection remain unverified for these new computed specimens. Existing native
references remain independent gates. Matching shared geometry is necessary for
consistent composition and previews, but does not establish universal Office
equivalence or complete typography support.
