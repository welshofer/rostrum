# Lectern marker checks: measured end-to-end savings

Parsing each rendered page once reduces the complete headless List markers run
from about 2.06 seconds to 1.01 seconds in this experiment. Both alternatives
are faster in all ten retained pairs. Generated packages, previews, exports and
all check results remain unchanged. Independent source, statistical and preservation review approved this bounded result.

The sole source change is `3e004c7`, in
`Lectern/Sources/LecternCore/LibraryLab/PlatformListMarkerRecipe.swift`.
The baseline is accepted fidelity14 source `6a3f61b`. Frozen candidate binaries
contain that same library and the one Lectern change; they exclude the separate
renderer-inheritance optimization and subsequent alignment/mixed-face work.
The candidate's precommit source hashes match the committed source exactly.

## What changed

Each source page has six native specimens and substantial embedded font data.
Previously, each specimen reparsed its entire SVG. The recipe now parses each
of four actual rendered pages once per `markerNativeChecks` invocation and
retains only the ordered text nodes needed by the existing audit. Across the
initial and reopened checks this reduces full-SVG parsing from 48 calls to eight.
Every specimen still runs every glyph, face, position, painted size, ink, omission
and body-line check. All storage belongs to that invocation. A malformed SVG
still fails its checks; the standalone audit and negative controls call the same
private implementation.

A separate attribution profile found 1,221 samples beneath these parses out of
2,041 application-main samples (59.82%; 2,182 including startup). That profile
could overlap other worker builds and is not a comparative timing or a predicted
speedup. Its raw stack report and source/binary pins are retained.

## Frozen paired experiment

Both alternatives ran in 44 fresh child processes: eleven alternating-order
baseline/candidate pairs each, with the first pair excluded as warmup. No child
was rerun. The campaign completed in 73.79819683398819 seconds including collection
and verification work. The primary timer spans precisely `LibraryLab.run`, including
creation, native checks, serialization, reopening, inspection and export. It
excludes process startup, GUI interaction and the parent's artifact hashing.

| Alternative | Baseline median | Candidate median | Median paired change [95% interval] | Faster pairs |
|---|---:|---:|---:|---:|
| 18 pt hanging-indent fit | 2.056844 s | 1.009619 s | −51.016% [−51.251, −50.505] | 10/10 |
| 6 pt hanging-indent fit | 2.061104 s | 1.013275 s | −50.881% [−51.073, −47.331] | 10/10 |

The distinct ratios of separate timing medians are −50.914% and −50.838%.
Intervals use 100,000 percentile bootstrap resamples of paired percentage changes,
seed 20261004, separately per metric. Exact two-sided sign tests excluding ties
give p=0.001953125 for each timing result. All four timing/RSS comparisons are
exploratory and unadjusted; none is selected or omitted after measurement.

Peak whole-process RSS, captured with the same `/usr/bin/time -l` wrapper for every
child, is lower in all ten pairs for both alternatives. Median paired differences
are −67.6484375 MiB in each. Median paired relative changes are −30.031% and
−30.032%, with 95% intervals [−30.456, −30.021] and [−30.645, −30.009]. RSS includes
all loading, rendering, validation, export and allocator retention. These are not
isolated allocation counts or average memory estimates.

Task builds, tests, profiling and GUI work were paused throughout this campaign.
System background load remained uncontrolled: sampled backupd CPU ranges from
6.3% to 314.8%, WindowServer from 28.9% to 37.4%, and sampled photoanalysisd is 0%.
Snapshots do not establish continuous isolation. No host settings were changed.
The separate library experiment ran first; its timings are not pooled here.

## Preservation and verification

Every child reports 58 passing checks, five slides and zero findings. All nine
non-report artifacts per run match byte for byte within their alternative,
including source/result PPTX files, all SVG previews, native references and
Markdown export. Within each alternative, all 22 report JSON files match after
removing only `elapsedSeconds`;
every check, option, finding, operation and limitation remains exact. The driver's
per-process directory and timing fields are execution metadata, not artifact
identity claims. All 440 output-file hashes are retained.

The result PPTX files also match the previously accepted native source hashes:
`35f93dacab1c562d2c9ac621b8e80232c5c9425bf6e2db2c10225140a255e05f`
and `67dbf7b5156c3903fab4470f85ba28c0158d992ea6fe68776be783241724e5e1`.
Independent ZIP CRC/unique-member checks, XML parsing and python-pptx reopening
cover 88 packages, 352 slides and 4,796 XML/relationship parts after timing.
Frozen product/source pins are checked before the campaign; products are checked
again afterward, with no changes. Focused Core tests pass both alternatives and
the strict negative controls (two test definitions, one suite). The combined
application gate belongs to the later integration checkpoint.

This measures the complete headless marker recipe on this host. It does not
establish GUI latency, faster isolated library rendering, other recipes,
cross-platform speed or cumulative savings with other optimizations. All native
comparison tolerances and rendered content remain unchanged.

Evidence: [raw paired results](benchmarks/2026-10-04-lectern-marker-checks-15/paired/raw.json), [all four statistical results](benchmarks/2026-10-04-lectern-marker-checks-15/paired/analysis.json), [frozen plan](benchmarks/2026-10-04-lectern-marker-checks-15/benchmark-plan.json), [memory addendum](benchmarks/2026-10-04-lectern-marker-checks-15/benchmark-memory-addendum.json), [original verification](benchmarks/2026-10-04-lectern-marker-checks-15/verification.json), and [accepted export manifest](benchmarks/2026-10-04-lectern-marker-checks-15/export.json). Original receipts retain their historical pre-review status; acceptance is recorded separately in the export manifest.
