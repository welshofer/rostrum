# Shared-font preview preparation — 2026-10-16

The opt-in Mac font transport now skips marker-free bytes eight at a time and
hashes each exact encoded font key once per candidate. Dictionary/LRU operations
reuse that hash; collisions still require complete byte equality. Retained keys
own their bytes. Font aliases never identify a resource, and every new document
checks its current content. The existing count/byte limits, inline fallback,
active-document lifetime and nonrecycled resource URLs are unchanged.

This reduces a measured cost of the existing experiment. **Normal app loading
still uses inline fonts.** These results do not establish a WebKit, visible-frame
or PowerPoint improvement; native comparison is still required before adoption.

## Why this work

The supplied Mac trace spent 828 of 1,113 ms of first-pass thumbnail requests in
WebKit navigation, plus 169 ms waiting for fonts. The shared-font experiment
reduces repeated font payload but previously added substantial preparation CPU.
Temporary clocks around its scans, key operations, decoding and reconstruction
identified scans at roughly 50–54% of instrumented preparation and key operations
at roughly 32–33%. Decoding was about 1%; only three distinct resources decoded
across the 28-slide corpus. These are diagnostic proportions with instrumentation
overhead, not independent benchmark results.

[Diagnostic samples](benchmarks/2026-10-16-preview-preparation-profile.json) retain
both runs and source hashes. The implementation uses pure Swift word loads,
Foundation byte storage and Swift hashing; there is no new runtime dependency.
Unaligned loads remain within the supplied range, and short tails use the original
byte comparison. The zero-byte check is independent of machine byte order.

## Paired Release results

Baseline `bbde5fc`, Linux x86_64, Swift 6.1.3, `-O -whole-module-optimization`.
Each of four workloads has one warmup pair and five alternating measured pairs
of fresh processes: 48 processes total. Each process prepares the workload twice
with the same resource cache. Input reads are outside preparation timers and
inside process measurements. No builds/tests ran during collection. Filesystem
caches can be warm; first pass means a fresh resource cache, not cold app startup.

CPU and elapsed times are milliseconds; RSS is MiB. Entries are baseline →
candidate medians. Whole-process values include reading inputs and both passes.
RSS uses a small wait4 launcher that forks after exec, avoiding inheritance of
the Python collector's peak. The C launcher is benchmark infrastructure only.

| Workload | First CPU | Repeat CPU | First elapsed | Repeat elapsed | Process CPU | Process elapsed | Peak RSS |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Uploaded 28 slides | 250.044 → 112.737 | 229.889 → 101.998 | 250.061 → 112.742 | 229.898 → 101.994 | 660.047 → 413.334 | 662.277 → 416.961 | 153.125 → 153.141 |
| First uploaded slide | 28.935 → 24.031 | 14.550 → 9.744 | 28.938 → 24.032 | 14.571 → 9.742 | 74.217 → 58.149 | 76.818 → 60.915 | 37.852 → 37.867 |
| Tiny font-free control | 0.014 → 0.014 | 0.002 → 0.002 | 0.016 → 0.017 | 0.002 → 0.002 | 12.365 → 10.716 | 14.023 → 12.499 | 12.277 → 12.293 |
| 10 MB image-markup control | 11.292 → 6.735 | 7.347 → 2.823 | 11.293 → 6.744 | 7.346 → 2.821 | 44.962 → 37.975 | 47.447 → 40.536 | 31.184 → 31.199 |

On the 28-slide corpus, median paired preparation CPU falls **52.7% first pass**
and **55.6% repeat pass**; all five pairs improve. These percentages are medians
of paired ratios, not ratios of the aggregate medians above. Small controls are
noisy: one single-slide pair slows by 27%/44%, and the tiny font-free first-pass
median paired change is +7.1% at microsecond scale. All samples are retained.
There is no demonstrated memory reduction. The image control uses synthetic
base64 image markup to isolate scanning, not image decoding or native rendering.

[Raw results](benchmarks/2026-10-16-preview-preparation.json) include every sample,
input/source/binary hashes and preservation checks. Do not add these reductions
to earlier measurements with different baselines or treat them as Mac speedups.

## Preservation and verification

All 68 emitted evidence files match between optimized baseline and candidate:
prepared SVGs, resource inventories and exact font bytes. Only the random store
namespace is normalized for comparison; URL IDs and resource ordering remain.
Each prepared document reconstructs its original SVG byte for byte, including
all text, positioning, styles and image payloads. The 28-slide corpus retains
the same 4,442,287 accounted cache bytes, three decoded resources, HTML size and
font-response size. These comparisons happen outside measured operations.

Focused tests exercise all byte alignments, short/truncated marker tails,
similar large fonts with different middle bytes, alias reuse, invalid base64,
format distinctions, byte/count limits and active resources surviving eviction.
An additional optimized baseline/candidate corpus covers 544 complete/truncated
inputs across all 16 offsets, retaining [1,105 matching files](benchmarks/2026-10-16-preview-preparation-boundaries.json).
Existing standalone SVG/PPTX generation is unchanged;
the transport is only applied to temporary browser documents.

The full local gate exposed one unrelated wall-clock-dependent mocked HTTP 500
retry test. It resumed after 302.7 seconds under the full suite and exhausted its
300-second budget, while the unchanged test passed alone in 2.0 seconds. That
test now uses the provider's existing internal clock/wait interface and verifies
the two-second backoff and remaining request timeout without sleeping. Public
provider timing and production behavior are unchanged.

Local validation completed with 1,394 root tests, 75 optimized text/layout tests,
10 native-pack integration tests, portable fidelity references and all 357
LecternCore tests on the corrected rerun. The README examples saved and reopened
successfully. An initial manual README invocation used a nonexistent output
directory; creating that directory resolved it without a source change.

## Reproduction

Keep private SVGs/fonts outside Git. Create JSON arrays of absolute SVG paths.
Retain the baseline source before building the current candidate:

```sh
mkdir -p /tmp/preview-preparation
git show bbde5fc:Lectern/Sources/LecternCore/Inspection/PreviewFontResources.swift \
  > /tmp/preview-preparation/baseline.swift
swiftc -O -whole-module-optimization \
  Tools/preview-profile/font-resource-probe.swift \
  Lectern/Sources/LecternCore/Inspection/CostLimitedCache.swift \
  /tmp/preview-preparation/baseline.swift -o /tmp/preview-preparation/baseline
swiftc -O -whole-module-optimization \
  Tools/preview-profile/font-resource-probe.swift \
  Lectern/Sources/LecternCore/Inspection/CostLimitedCache.swift \
  Lectern/Sources/LecternCore/Inspection/PreviewFontResources.swift \
  -o /tmp/preview-preparation/candidate
python3 docs/benchmarks/2026-10-16-preview-preparation.py \
  --baseline /tmp/preview-preparation/baseline \
  --candidate /tmp/preview-preparation/candidate \
  --baseline-source /tmp/preview-preparation/baseline.swift \
  --workload deck=/absolute/svg-paths.json \
  --output /tmp/preview-preparation/new-results
python3 docs/benchmarks/2026-10-16-preview-preparation-boundaries.py \
  /tmp/preview-preparation/baseline /tmp/preview-preparation/candidate \
  /tmp/preview-preparation/new-boundary-results
```

For native adoption, quit Lectern and run the existing paired Mac check on the
same saved deck used for the earlier trace:

```sh
python3 Lectern/scripts/compare-preview-loading.py "/path/to/your-deck.pptx"
```

It requires unchanged standalone SVGs, exact normalized bitmap parity, successful
native regressions and complete render/cache traces. Its CPU/RSS still exclude
WebKit helpers, and first bitmap availability is not actual first visible display.
Those measurement gaps remain open; no native result is inferred from Linux.

## Caller-font PowerPoint review

The existing [native fidelity pack](../Tools/native-fidelity/README.md) now adds
24 source rows with vertical/rectangular merges and connected four-row groups,
using the caller's exact family. All four profiles (4:3/16:9, external/embedded)
retain source cells, topology and page geometry. Reopened anchors are checked
against their complete saved rectangles and captions; python-pptx verifies the
native merge grid independently. Production Lectern inspection/export retains
each source row, note, section and original slide position.

The supplied Calibri regular/bold/italic/bold-italic faces also passed two runs
per profile through the pack and production inspection/export executables.
Both 4:3 profiles produced nine slides (five plain-table and three merged-table
pages); both 16:9 profiles produced seven (three plain and three merged pages).
Decks, geometry, SVGs, diagnostics and inspection/export artifacts repeat exactly
within each profile. These were Debug validation runs, not performance samples.
The proprietary font inputs and generated review decks remain outside Git.

This extends the visual review corpus; it does not claim to fix an observed
PowerPoint typography mismatch. Slide view and PDF/image export must be reviewed
separately, with exact saved bytes and installed-font conditions recorded. Native
PowerPoint acceptance remains pending.
