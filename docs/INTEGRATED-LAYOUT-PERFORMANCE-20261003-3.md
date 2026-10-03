# Combined layout performance after native geometry calibration

The final combined source at root `301a6c27de03fdc13d4b2617724de40c861a71e9`
renders the registered-font table **4.44% faster** and fits rich text **5.92%
faster** than current baseline `5654d1b`, with all ten matched pairs faster and
nonoverlapping observed ranges. These measurements include the intentional native
advance, kerning and wrap geometry changes from fidelity commit `85f70a2`.

Against the earlier pre-tab baseline `cf1b8a0`, registered rendering is **5.94%
faster**, again with all ten pairs faster and nonoverlapping ranges. Rich fitting
has a **3.73% lower median** and nine faster pairs, but its ranges overlap, so the
combined evidence for fitting recovery is weaker than the earlier isolated pass.
**Fallback recovery remains unproven:** its median is 0.27% higher than `cf1b8a0`
with five faster and five slower pairs and substantially overlapping ranges.

These are bounded measurements on four macOS workloads. They supersede the
[output-preserving pass](LAYOUT-PERFORMANCE-20261003-3.md)'s speed figures when
describing the final combined implementation. The preserving pass's 628-slide
identity evidence remains valid for that earlier source, not for this intentionally
different fidelity output. Historical receipts are unchanged.

## Matched measurements

The candidate worker revision is `f839c8951ca2fdaf20b4ac8ada106483238011a7`.
Its library source and benchmark source exactly match root `301a6c2`; the library
Git tree is `17b721dacf82e8f7a08fbfbcb6e56bd00cc52293` in both revisions. The
same driver was compiled with `swiftc -swift-version 6 -O` against retained
release objects. Both comparisons used ten alternating fresh-process pairs,
one excluded warmup pair, the same Arial bytes and Swift 6.4 on arm64 macOS 27.0.1.
The parent explicitly held GUI/build/test work and obtained the other workers'
pause confirmation before timing. Both runs completed sequentially inside that
window, which was released immediately afterward.

[Current-baseline samples](benchmarks/2026-10-03-final-combined-layout-paired-macos.json):

| Scenario / phase | 5654d1b median | Combined median | Change | Faster pairs |
| --- | ---: | ---: | ---: | ---: |
| Fallback 200 × 50 table: render | 185.041 ms | 179.353 ms | −3.07% | 10 / 10 |
| Registered Arial 100 × 20 table: render | 83.555 ms | 79.842 ms | −4.44% | 10 / 10 |
| Registered 2,600-character text: rich fitting | 15.504 ms | 14.586 ms | −5.92% | 10 / 10 |
| Fitted text: render | 3.429 ms | 3.434 ms | +0.14% | 7 / 10 |
| Fallback 10-slide deck, first slide: render | 0.575 ms | 0.571 ms | −0.72% | 7 / 10 |

Registered-table ranges are 82.990–84.715 versus 79.133–80.461 ms; fitting ranges
are 15.349–15.881 versus 14.170–15.033 ms. Fallback ranges overlap at
180.393–189.601 versus 176.825–182.693 ms. The small fitted-text and first-slide
render ranges also overlap. Faster-pair counts compare each candidate with its
matched baseline sample; their direction need not match a ratio of medians.

[Separate recovery samples](benchmarks/2026-10-03-final-combined-layout-recovery-paired-macos.json):

| Scenario / phase | cf1b8a0 median | Combined median | Change | Faster pairs |
| --- | ---: | ---: | ---: | ---: |
| Fallback 200 × 50 table: render | 177.638 ms | 178.115 ms | +0.27% | 5 / 10 |
| Registered Arial 100 × 20 table: render | 84.904 ms | 79.857 ms | −5.94% | 10 / 10 |
| Registered 2,600-character text: rich fitting | 15.166 ms | 14.601 ms | −3.73% | 9 / 10 |
| Fitted text: render | 3.283 ms | 3.316 ms | +1.00% | 3 / 10 |
| Fallback 10-slide deck, first slide: render | 0.580 ms | 0.551 ms | −4.93% | 9 / 10 |

The registered-table ranges are 83.721–85.955 versus 78.594–81.672 ms. Rich
fitting ranges overlap at 14.526–16.178 versus 13.984–15.099 ms; fallback ranges
overlap at 171.628–182.685 versus 174.860–183.925 ms. All other recovery render
ranges overlap. These results do not establish a new consistent fallback
regression or its full recovery. Do not compare absolute medians between this
run and earlier cycles as though those candidates were paired directly.

Whole-scenario median peak RSS against the current baseline is 199.74 → 199.67
MiB for fallback tables, 52.38 → 52.60 MiB for registered tables and 21.20 → 20.76
MiB for fitting. Those process peaks do not isolate layout. No net memory,
universal speed or cross-platform performance claim is made.

## Output and correctness evidence

The [combined output proof](benchmarks/2026-10-03-final-combined-layout-output-proof.json)
records all four scenarios, covering 13 slides per candidate repetition. Two
candidate repetitions produce identical SVG, ordered diagnostics, inheritance
flags and saved PPTX. All 32 scenario/proof-saved presentations independently
reopen with python-pptx 1.0.2 and table-cell traversal. Saved PPTX bytes match
across both baselines and both candidate repetitions on all four workloads.

Cross-version rendering changes are retained explicitly:

- The registered table's SVG changes with the native geometry calibration.
- The rich fitting workload's ordered diagnostics gain an `unsupportedShaping`
  approximation for native advance rounding outside verified single-scalar
  left-to-right ASCII glyphs. Its text includes `café`; its SVG is unchanged.
- Fallback table and ten-slide output artifacts are unchanged.

The canonical unchanged `Tools/rostrum-bench/run.py` performed both authoritative
comparisons, including its original cross-version saved-PPTX hash equality check.
An output-aware scratch runner was prepared but never used for timing; it is not
part of this evidence. Rendering differences are recorded only by the separate
proof script, without altering the driver or timed calls.

The combined release build passed locally. The parent/fidelity worker reported
1,025 tests in 142 suites passing, all 175 native line-content cases and 174
horizontal calibrations passing, and all previous 60 native tab cases unchanged.
Those integration checks were not rerun by this measurement lane. Native fidelity
acceptance and its broader fixture evidence remain owned by the fidelity lane.
No source optimization was added during this final combined measurement.

## Reproduction and retained evidence

The [verification receipt](benchmarks/2026-10-03-final-combined-layout-verification.json)
pins source trees, baseline/candidate objects and executables, source/driver/runner
hashes, all three primary receipts, logs and exact commands. Evidence remains in
`.build/perf8-combined/`; earlier baselines remain in `.build/perf5/` and
`.build/perf4/`. Existing isolated receipts remain immutable.

```sh
swift build -c release --product rostrum-bench --jobs 2
swiftc -swift-version 6 -O -I .build/perf8-combined \
  Tools/rostrum-bench/main.swift .build/perf8-combined/candidate-Rostrum.o \
  -o .build/perf8-combined/candidate-extended-bench
ROSTRUM_BENCH_FONT=/System/Library/Fonts/Supplemental/Arial.ttf \
python3 Tools/rostrum-bench/run.py \
  --binary .build/perf8-combined/candidate-extended-bench \
  --paired-binary .build/perf5/baseline-extended-bench \
  --paired-revision 5654d1b09e43d26f93a195270f8832b6be3a21e4 \
  --runs 10 --warmups 1 \
  --scenarios table-200x50 shaped-table-100x20 richtext-fit slides-10 \
  --output /tmp/final-combined-layout-paired.json
python3 .build/perf8-combined/workload-proof.py
```

For the recovery comparison, substitute `.build/perf4/baseline-extended-bench`
and declared baseline `cf1b8a0cec2cf680383cb683603785aeaa0f2011`. These commands
assume the retained matching objects/modules; rebuilding future source does not
reproduce this frozen candidate automatically.
