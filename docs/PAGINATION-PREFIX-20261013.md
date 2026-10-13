# Bound repeated prefix work during measured pagination

`MeasuredPaginator.pages` previously copied and tested the entire remaining
suffix before each page, then binary-searched across that suffix. A long input
with short pages repeatedly visited most of the same items. This affected the
general paginator used by authored text, agenda, comparison and image-slide
continuations; native table pagination already has its own linear partitioner.

The paginator now keeps its one-call path when the complete input fits. After a
failure, it finds the first boundary with the original binary search. Subsequent
pages start with the preceding page's item count, grow probes if needed and
binary-refine the bounded interval around their fit boundary. A previous page's
size is only a starting probe: smaller and larger capacities are measured anew.
It avoids repeatedly copying and testing long remaining suffixes. The first
failed whole-input result serves as the first page's upper bound. No geometry
or fitting result is cached.

The predicate must still be deterministic and monotonic with prefix length.
Every accepted nonempty page was measured; pages retain maximal fitting prefixes,
source order and exact text. Oversized items and predicate errors still throw.
The number and order of predicate calls can change. The consumer still owns
continuation slides, notes, sections and image associations.

Both array pagination and text splitting check cancellation before and after
each fit callback. Previously,
cancellation during a successful whole-input callback could return pages. The
new regression fails on the baseline and verifies that this now throws before
accepting the result. Callback errors propagate unchanged.

## Profile and method

The baseline is `a71153ab96aa9d1877421ed1405b2e88d56b86a0`, including the preceding
table-fragment optimization. The [Release driver](benchmarks/2026-10-13-pagination-prefix.swift)
records callback counts, total item visits for array predicates, monotonic elapsed
time and process CPU. A simple count predicate isolates array/search overhead;
paragraph and continuous-text cases use the actual shared rich-text measurement
with registered DejaVu Sans at 18 pt and a 520-point-wide frame.

The [initial profile](benchmarks/2026-10-13-pagination-profile.json) of 10,000 items
on eight-item pages made 16,326 fit calls covering 12,529,601 item visits. A first
attempt that grew every page from one item removed most repeated work but
increased small continuous-text probing. Its
[paired record](benchmarks/2026-10-13-pagination-prefix-attempt.json) shows a
26.35% CPU regression for the two-page text control. The final implementation
retains the first binary search and uses the preceding page's count thereafter.
The rejected attempt remains recorded separately; its numbers do not describe
the final implementation. Call count alone does not measure fitting cost.

The [collector](benchmarks/2026-10-13-pagination-prefix.py) alternates five
baseline/candidate process pairs per workload. Each process performs five trials;
trial zero is excluded. Both binaries use Swift 6.1.3 Release on the same Linux
AMD EPYC 9V74 host. Font registration, saved decks and SVG rendering are outside
phase timers. Whole-process peak RSS includes fonts, all trials and returned page
arrays. Streamed source/binary hashes and the collector's own peak RSS make
identity and possible inherited memory floors visible. Final timings run without
concurrent builds or tests. These are fixed-input measurements, not universal
speed or device guarantees.

## Results

The [final paired record](benchmarks/2026-10-13-pagination-prefix.json) retains
100 processes and 500 trials. Times below are milliseconds; arrows are baseline
→ candidate medians. Percentages are medians of within-pair CPU changes, not
ratios of the displayed medians. Negative changes are faster. RSS is whole-process MiB.

| Predicate / input count / limit | CPU | Paired CPU change | Elapsed | Peak RSS |
| --- | ---: | ---: | ---: | ---: |
| count / 1000 / 8 | 1.696 → 0.226 | -86.81% | 1.696 → 0.226 | 21.473 → 21.359 |
| count / 10000 / 8 | 132.546 → 2.455 | -98.15% | 132.661 → 2.455 | 23.992 → 24.141 |
| count / 10000 / 10000 | 0.0013 → 0.0010 | — (timer floor) | 0.0012 → 0.0009 | 24.016 → 24.016 |
| paragraphs / 4 / 180 | 0.197 → 0.216 | +10.21% | 0.197 → 0.216 | 21.621 → 21.633 |
| paragraphs / 24 / 180 | 11.197 → 8.142 | -19.50% | 11.197 → 8.143 | 21.609 → 21.641 |
| paragraphs / 120 / 180 | 175.325 → 43.829 | -74.00% | 175.323 → 43.829 | 23.105 → 22.754 |
| paragraphs / 480 / 180 | 1835.207 → 176.609 | -90.31% | 1835.212 → 176.612 | 28.254 → 28.199 |
| text / 30 / 180 | 5.310 → 5.372 | +3.68% | 5.320 → 5.372 | 21.785 → 21.867 |
| text / 300 / 180 | 190.466 → 101.462 | -47.45% | 190.624 → 101.464 | 22.145 → 22.059 |
| text / 1200 / 180 | 1788.647 → 379.510 | -78.55% | 1788.659 → 379.605 | 23.758 → 23.715 |

`count` uses a maximum item count; the other limits are frame heights in points.
Each continuous-text input unit contains a unique word identifier, composed and
decomposed accented words, and whitespace; its count is not a word count.

All five pairs improve for the long measured cases. Planning 120 paragraphs
uses 74.00% less paired CPU (range 73.05–76.27%); 480 paragraphs use 90.31%
less (89.86–90.70%). Continuous-text splitting uses 47.45% less for 300 input
units (40.81–50.26%) and 78.55% less for 1,200 units (78.25–79.32%).
These measure pagination plus actual text-height callbacks, not complete deck export.

The count-only 10,000-item case isolates array/search overhead: 98.15% lower
paired CPU, 16,326 → 6,256 callbacks and 12,529,601 → 88,661 visited items.
It retains the same 1,250 pages. This is not a 98% whole-renderer speedup.

Small controls remain noisy and include observed slowdowns. Four already-fitting
paragraphs still use one callback, with +10.21% paired CPU (range −19.12% to
+62.51%). The two-page text control retains the baseline’s nine callbacks:
+3.68% paired CPU (−2.18% to +39.25%), versus the rejected attempt’s extra
probes and consistent +26.35% slowdown. This removes that extra probing; it does
not establish a zero-regression guarantee. The 24-paragraph case has a −19.50%
median with one slower pair (+7.44%). The count-only one-call case is near the
clock/dispatch floor and is not evidence of a useful speed change.

Peak RSS does not establish a general memory reduction. The 120-paragraph case
has a small reduction in every pair, while several controls increase. The
collector peaks at 13.25–13.50 MiB before spawning; every child peaks above that
(21.32–28.34 MiB). All samples, including adverse controls, remain in the record.

## Verification

An independent greedy partition checks maximal prefixes with changing per-page
capacities. Tests also cover empty/already-fitting inputs, an input-size bound on
repeated measurement work, callback errors, cancellation before and during fitting,
oversized items, whitespace, Unicode and exact UTF-8 preservation. The paginator
suite is included in the optimized local and Linux/macOS CI checks.

Six saved-output cases compare 172 artifacts, including six PPTX files and 80
SVGs: page content, decks, SVGs and
ordered diagnostics match the baseline. Independent python-pptx reopening checks
every page's exact text, native geometry and speaker notes; ZIP CRC checks pass.
The [authored continuation driver](benchmarks/2026-10-13-pagination-authored.swift)
also exercises Lectern's production renderer with dense agendas, bullets,
comparisons and illustrated text, retaining notes and sections.
All 15 export artifacts match, including the 11-slide deck, its 11 previews and
ordered diagnostics. The [independent checker](benchmarks/2026-10-13-pagination-authored-check.py)
verifies every source sentence exactly once in its original slide group, every
page's notes, original image bytes (including PNG checksum validation) and complete section membership. The extra
PPTX file in this artifact count is a second copy of the same exported deck.

The complete `scripts/verify.sh --fast` gate passes 1,333 root tests, 63 Release
tests, 309 LecternCore tests and all 36 saved PowerPoint reference comparisons,
plus oracle preflight, offline workflow checks and README execution. The
[verification record](benchmarks/2026-10-13-pagination-verification.json) retains
source/binary identity and saved-output counts. Apple builds remain a separate
PR CI check; app-hosted tests cannot run on this Linux host.

This changes neither shaping nor native rendering support. Saved-output identity
does not establish new PowerPoint visual acceptance. The downloadable specimens
remain available for that separate review.

## Reproduction

Preserve a baseline executable before changing sources, then build the candidate
with the same command and output name `candidate`:

```sh
mkdir -p /tmp/pagination-prefix
swift build -c release --target RostrumLayout
swiftc -O -I .build/release/Modules \
  docs/benchmarks/2026-10-13-pagination-prefix.swift \
  .build/release/Rostrum.build/*.o .build/release/RostrumLayout.build/*.o \
  -o /tmp/pagination-prefix/baseline
python3 docs/benchmarks/2026-10-13-pagination-prefix.py preserve \
  /tmp/pagination-prefix /tmp/pagination-preservation.json
python3 docs/benchmarks/2026-10-13-pagination-prefix.py collect \
  /tmp/pagination-prefix /tmp/pagination-timing.json
```

The preservation mode requires the pinned python-pptx oracle environment and a
fresh artifact directory. To reproduce production authored exports, build
LecternCore, then compile the authored driver with `-parse-as-library` against
`Lectern/.build/debug/Modules` and the `LecternCore`, `Rostrum` and `RostrumLayout`
Debug objects. Run each executable with its own output directory.
