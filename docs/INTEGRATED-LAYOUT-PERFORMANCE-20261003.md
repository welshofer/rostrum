# Combined layout performance checkpoint

This matched measurement compares baseline `cf1b8a0` with the combined ASCII
break scan and tab/justification engine at integration revision `7fca2ee`.
The worker candidate is `848628d`; its library source tree and benchmark driver
match the integration revision exactly. Existing isolated measurements remain
unchanged. This checkpoint finds small regressions and does not establish a net
performance improvement for the combined batch.

## Method and results

Both variants use the retained release library object and the same benchmark
source compiled with `swiftc -swift-version 6 -O`. The candidate release build
passed in 52.22 seconds. The orchestrator explicitly paused GUI/build work after
library/Lectern tests and other engine work finished. Ten alternating fresh-process
pairs followed one excluded warmup pair, using the same Mac/compiler/Arial bytes.
The [paired samples](benchmarks/2026-10-03-integrated-layout-paired-macos.json)
and [verification receipt](benchmarks/2026-10-03-integrated-layout-verification.json)
retain timings, compiler/font/binary hashes, source identity and commands.

| Scenario / phase | Baseline median | Combined median | Combined faster pairs |
| --- | ---: | ---: | ---: |
| Fallback 200 × 50 table: render | 173.871 ms | 177.794 ms | 0 / 10 |
| Registered Arial, 100 × 20 table: render | 84.103 ms | 83.474 ms | 7 / 10 |
| Registered Arial, 2,600-character text: rich fitting | 14.845 ms | 15.292 ms | 0 / 10 |
| Same text after fitting: render | 3.221 ms | 3.347 ms | 4 / 10 |
| Fallback 10-slide deck, first slide: render | 0.572 ms | 0.571 ms | 5 / 10 |

Fallback table rendering is **2.26% slower** and rich fitting is **3.01% slower**
by median, with the candidate slower in all ten matched pairs. Registered table
rendering is 0.75% faster with overlapping observed ranges; this does not reproduce
the isolated ASCII-scan improvement of 3.96%. Fitted-text rendering is 3.91% slower
by median but noisy, and the small mixed-text slide render is essentially flat.
These are combined-batch results, not an attribution to a particular engine change.

Whole-scenario median peak RSS is 199.79 → 199.70 MiB for the fallback table,
52.78 → 52.65 MiB for the registered table and 20.95 → 21.10 MiB for rich fitting.
There is no net memory or cross-platform performance claim.

## Output preservation

The [workload identity check](benchmarks/2026-10-03-integrated-layout-output-identity.json)
compares the same four workloads and all 13 of their slides, using the scenario's
registered-font mode. Saved PPTX, SVG, ordered diagnostics and inheritance flags
are byte-identical between baseline and combined code. The proof driver also
checks that rendering does not mutate the document. This narrow preservation
check does not cover the newly supported tab fixtures, whose intended changes
are validated by the engine's separate native-oracle tests.

The worker made no source edits for this checkpoint. Root integration tests remain
a separate gate. Scratch binaries, logs and identity script remain in
`.build/perf4-integrated/`; the baseline is retained in `.build/perf4/`.

```sh
ROSTRUM_BENCH_FONT=/System/Library/Fonts/Supplemental/Arial.ttf \
python3 Tools/rostrum-bench/run.py \
  --binary .build/perf4-integrated/candidate-extended-bench \
  --paired-binary .build/perf4/baseline-extended-bench \
  --paired-revision cf1b8a0cec2cf680383cb683603785aeaa0f2011 \
  --runs 10 --warmups 1 \
  --scenarios table-200x50 shaped-table-100x20 richtext-fit slides-10 \
  --output /tmp/integrated-layout-paired.json
```
