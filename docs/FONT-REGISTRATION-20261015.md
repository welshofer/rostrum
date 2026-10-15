# Reusing validated font faces — 2026-10-15

Lectern now registers the same parsed face that it validated. Previously,
`InstalledFonts.Session` parsed candidate files to check family, style and
collection identity, then `FontLibrary.register(Data)` parsed each accepted face
again. The supplied Mac trace put the entire installed-font stage at 190 ms on
the first operation and 143 ms on the repeat; it did not isolate this duplicate
parse. A separate Release Linux probe confirmed the repeated work before editing
it: four Calibri faces took about 6.2 ms to parse and another 5.2 ms to register
through the raw-byte API, inside a 12.6 ms production registration operation.
These initial samples identified the work; the paired results below assess it.

## Implementation and freshness

The public `PreparedFont` is an immutable `Sendable` snapshot containing exact
source bytes, the selected collection index and parsed `FontMetrics`. Its
initializers always parse those bytes; callers cannot supply unrelated metrics.
`FontLibrary.register` overloads accept that snapshot without parsing again. Raw
registration delegates through the same path and retains existing semantics.
There is no new global cache, implicit font substitution or package mutation.

Lectern's bounded, operation-local candidate cache retains prepared faces. Family
and standard-style checks, resolved PostScript collection identity, alias conflict
checks and embedded-font priority are unchanged. Its existing file/byte/face/
lookup limits remain in force. Each new operation creates a fresh session and
rereads font files; a font installed or replaced between operations is observed.
A caller explicitly retaining `PreparedFont` retains its old snapshot and must
prepare a new value when freshness is required. Registry isolation remains the
caller's responsibility; `FontLibrary` itself is not made Sendable.

Collection bytes remain complete TTC data. Preparation adds neither collection
extraction nor font embedding permission. Caller-selected fonts, SVG font
resources and the existing preview fallback policy remain unchanged. The Fonts,
shaping and fitting Library Lab demonstrates prepared reuse across registries,
then checks embedding, saved-file reopening, shaping, production Inspect and
export through its ordinary pipeline.

## Paired Release evidence

Baseline: `a16e98e74abb36e964749986d3754607e317cfd1`; candidate production code:
`f95330c908662175222b430aac0a1632e064e5ac`. Swift 6.1.3, Linux x86-64, Release
Rostrum objects plus `swiftc -O` probe and production `InstalledFonts.swift`.
The baseline binary was retained before editing production code. Exact binary,
input and source hashes, every sample and all artifact hashes are in the
[raw report](benchmarks/2026-10-15-font-registration.json). Private font bytes
and generated decks/SVGs remain outside version control.

Five workloads each ran one warmup and seven alternating measured pairs, in
fresh processes: 80 processes including warmups. No builds or tests ran during
collection. Each process runs two operations with new presentations and font
sessions. Candidate file discovery is injected with fixed licensed inputs; file
reading, candidate validation and registration are production code. OS/CoreText
font lookup, WebKit and UI are excluded. Input hashing and warmups can warm file
caches; these are not cold-disk measurements. The four-face collection is an owned
synthetic TTC wrapper around the same supplied Calibri files, testing selection
and reuse rather than native collection rendering.

| Registration CPU median (ms) | First, baseline → candidate | Second fresh operation, baseline → candidate | First / second median paired reduction |
| --- | ---: | ---: | ---: |
| Four Calibri files | 13.651 → 8.173 | 10.821 → 5.859 | 39.97% / 46.79% |
| Four-face Calibri collection | 13.110 → 8.305 | 10.700 → 6.078 | 36.31% / 43.66% |
| Arial regular only | 5.644 → 3.758 | 3.512 → 1.928 | 31.91% / 44.50% |
| Bundled regular fixture | 5.215 → 3.657 | 3.815 → 1.821 | 29.53% / 46.54% |
| Missing-font control | 0.040 → 0.039 | 0.007 → 0.007 | No demonstrated benefit |

Elapsed registration medians closely follow CPU: four Calibri files take
13.626 → 8.149 ms first and 10.816 → 5.856 ms second. Full raw elapsed samples
are retained. Paired reductions are medians of individual pair ratios, not ratios
of independent medians. Microsecond control timings include clock overhead.

Whole-process values include both registration operations, fixture authoring,
SVG rendering, byte verification, evidence writes and startup:

| Workload | CPU median (ms), baseline → candidate | Elapsed median (ms), baseline → candidate | Lifetime peak RSS (MiB), baseline → candidate |
| --- | ---: | ---: | ---: |
| Four Calibri files | 64.719 → 55.302 | 69.612 → 60.738 | 33.96 → 33.23 |
| Calibri collection | 50.346 → 39.483 | 54.595 → 43.535 | 28.66 → 28.66 |
| Arial regular | 39.865 → 36.920 | 44.700 → 42.314 | 28.66 → 28.66 |
| Bundled regular | 39.731 → 35.972 | 44.707 → 41.204 | 28.66 → 28.66 |
| Missing-font control | 20.503 → 20.689 | 24.137 → 24.856 | 28.66 → 28.66 |

The missing-font control's whole-process medians regress slightly. There is no
accepted-face parsing to eliminate in that case, and the short control varies
between pairs. Peak RSS stays flat or slightly lower in this probe; allocator
high-water marks do not establish a general application memory reduction.

## Output and acceptance

All 50 artifact entries across the five workloads match byte-for-byte across
both builds and every warmup/sample: saved PPTX, SVG, ordered fidelity diagnostics
and registration receipts. Receipts retain missing faces, substitutions, selected
names and scalar advances; the probe also checks registered bytes against the
supplied files. Each operation uses a fresh session. Font inputs and measured
executables remain unchanged throughout collection.

The [broader output comparison](benchmarks/2026-10-15-font-registration-output-parity.json)
also matches all 74 artifact entries across small, embedded-table, image-heavy,
dense-text, authored-table and template-table production fixtures. Saved decks,
SVGs, normalized saved-content snapshots, exports and ordered diagnostics are
identical. Equal deck bytes include unchanged widths, heights and page boundaries.
This comparison uses retained pre-cache Release tools (already checked against
the cache change) and current Debug tools, with exact binary hashes recorded;
it is output evidence only, not a timing comparison.

Focused regressions pass for snapshot reuse, source/file replacement, independent
registries, explicit style overrides, aliases and encoded-resource invalidation,
invalid and nameless fonts, collection selection, embedded priority and budgets.
The root suite passes 1,379 tests and the native text/table pack passes nine
portable checks. Full local and Apple build results are recorded with the pull
request; `scripts/verify.sh --fast` excludes app builds and app-hosted tests.
Native Mac performance, app-hosted tests and PowerPoint visual acceptance remain
pending. This change preserves rendering output; it does
not establish improved glyph fidelity or a measured native preview speedup.
