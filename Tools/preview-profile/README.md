# Lectern preview pipeline profiling

Measure the production generation and inspection paths on fixed, offline inputs.
`PipelineTrace` is opt-in, bounded and task-local. Ordinary library/app calls do
not read clocks or retain samples. Timings never enter PPTX bytes, SVGs, layout
plans or diagnostics. The trace lives in LecternCore; Rostrum stays portable and
dependency-free.

## Core baseline (macOS or Linux)

Build first, then stop other builds/tests before collecting:

```sh
swift build -c release --package-path Lectern
python3 Tools/preview-profile/run.py \
  --inspection-binary Lectern/.build/release/InspectionRegression \
  --composition-binary Lectern/.build/release/CompositionRegression \
  --workloads /absolute/workloads.json --output /absolute/new-profile \
  --runs 3 --warmups 1 --repeat 2 --build-mode release
```

Example `workloads.json` (file paths are relative to the manifest):

```json
{
  "workloads": [
    {"name": "small", "kind": "inspect", "input": "small.pptx"},
    {"name": "images", "kind": "inspect", "input": "image-heavy.pptx"},
    {"name": "dense", "kind": "compose", "arguments": ["--replay", "dense.json"]},
    {"name": "tables", "kind": "compose", "arguments": ["--tables"]},
    {"name": "template", "kind": "compose", "arguments": ["--tables", "template.potx"]}
  ]
}
```

Use small controls, dense text, native tables, image-heavy decks and templates.
Reuse [native fidelity profiles](../native-fidelity/README.md) with the intended
fonts. The normal installed/embedded font policy remains in effect: passing a
font manifest to the separate fidelity tool does not install fonts for Lectern.
Keep private inputs and licensed fonts outside Git. Record exact installed font
files/versions alongside native measurements; embedded inputs are covered by
the deck hash. Missing fonts remain diagnostics and are not an exact-font case.

For an output-preserving experiment, add `--baseline-inspection-binary` and
`--baseline-composition-binary` pointing to retained binaries built before the
optimization. Both versions must include the stage hooks and repeated-inspection
CLI: build an instrumented baseline before changing algorithms. The collector alternates baseline/candidate order for each paired round,
checks identical artifacts across both variants, and records both executable
hashes. Preserve SwiftPM resource bundles alongside relocated executables (or
retain the build directory).

Each warmup and sample starts a fresh process. Inspection performs `--repeat`
operations in that process (default two), creating a new presentation and font
registry each time. Composition runs once per supplied style. Filesystem caches
can already be warm, including from input hashing. Do not label this cold disk
or cold app startup. Warmups remain in the manifest with `warmup: true` and
should be excluded from summary statistics.

The collector records executable/input hashes, checkout revision/dirty state,
toolchain, platform and every raw sample. The build-mode argument is the caller's
assertion, not binary verification; the executable hash identifies exact bytes.
It checks source inputs remain unchanged and compares all SVGs, inspection data,
exports, deck bytes, saved-content snapshots and diagnostics across repetitions.
Composition normalization removes only output paths, random snapshot filenames,
JSON key order and timing fields. Equal PPTX bytes include identical native
column widths, row heights and page boundaries. This is output preservation,
not PowerPoint visual acceptance.

## Stage meanings

| Stage | Work included |
| --- | --- |
| `generation.prepare` | New/template presentation, design and initial master setup |
| `generation.embeddedFonts` | Register embedded generation faces |
| `generation.fontDiscovery` | Collect requested generation families |
| `generation.installedFonts` | OS lookup, file reads, validation and generation registration |
| `generation.layout` | Template preparation, table plans and authored pagination |
| `layout.templatePreparation`, `layout.tables`, `layout.authoredPagination` | Subspans of layout (do not add to the parent) |
| `layout.tablePlan`, `layout.tableSourceNotes` | Individual table/search and source-note planning calls inside `layout.tables` |
| `generation.compose` | Native shapes, images, notes, sections, furniture and final layouts |
| `generation.validateBindings`, `generation.validate` | Binding and schema checks |
| `generation.save` | Serialize and write PPTX |
| `preview.reopen` | Read and parse saved generation bytes |
| `inspect.read`, `inspect.open` | Inspection file read and package parse |
| `inspect.validate`, `inspect.extract` | Schema checks and inspector extraction |
| `preview.embeddedFonts` | Register embedded preview faces |
| `preview.fontDiscovery` | Collect slide/layout/master/theme font declarations |
| `preview.installedFonts` | OS lookup, file reads, validation and preview registration |
| `preview.svg` | One slide's production SVG render, including text layout |
| `preview.identity` | Prepare immutable SVG UTF-8 identity once per record, outside SVG rendering |
| `thumbnail.geometry` | Validate/bound bitmap dimensions within a thumbnail request |
| `thumbnail.cacheLookup` | Exact-content cache lookup and LRU promotion within a request |
| `thumbnail.cacheInsert` | Account SVG/bitmap bytes and admit or reject a rendered result |

Samples carry elapsed time, process CPU, start offset, optional original slide
number and outcome. Process CPU includes every thread; overlapping spans cannot
be summed. Failed/cancelled operations must not be interpreted as fast successes.
Trace storage defaults to 10,000 records and reports dropped records explicitly.
The inspector's existing progress events are retained unchanged.

Whole-process CPU, elapsed and peak RSS include startup, exports, evidence writes
and allocator retention. Stage timings exclude evidence serialization. Repeated
operations have individual timings but share a single process peak. First SVG
slot completion can be a failed slot: check `firstPreviewRendered`. It is not a
visible thumbnail. Small timing differences can be instrumentation/noise; profile
an observed hotspot before changing an algorithm and then compare alternating
fresh baseline/candidate processes with identical inputs and artifact hashes.

## Native Mac bitmap probe

For the post-pull check, quit Lectern and run this from the repository root with
the **same saved deck used for the earlier profile**:

```sh
git pull --ff-only
bash Lectern/scripts/test-preview.sh "/path/to/your-deck.pptx"
```

The runner requires macOS 26 or newer, full Xcode 26 or newer, XcodeGen
(`brew install xcodegen`) and Python 3, using the existing local signing
configuration. It first builds
and runs the Release native profile below, then runs the native geometry,
rasterizer, cancellation, queue and cache-trace regressions serially. Regression
tests run after measurement and cannot warm the profile's in-process bitmap
cache. It verifies that tests actually executed using the Xcode result bundle.
This is a focused preview check, not the full repository gate.

Results default to a new `.build/preview-test-<UTC timestamp>/` directory. An
optional second argument chooses a different new output directory; relative
paths and spaces are supported. The script prints a short summary and the path
to a ZIP containing exact SVG hashes/sizes, raw CPU/elapsed/cache/memory
measurements, provenance, test counts and logs. Send back that ZIP for comparison.
All full SVGs remain in `profile/` for visual review or investigating changed
hashes. Keeping their embedded images and fonts outside the ZIP avoids large
repeat uploads; the earlier 28-slide SVG set alone compressed to about 66 MiB.
The original PPTX and full `regressions.xcresult` also remain outside the archive.
On failure, logs stay in the output directory and the script
exits unsuccessfully without reporting a completed bundle. Existing results are
never overwritten, and no app is terminated or normal app build replaced.

For the profile alone:

Run locally on an idle Mac with the repository's normal Xcode/signing setup:

```sh
bash Lectern/scripts/profile-preview.sh /absolute/deck.pptx /absolute/new-native-profile
```

The script uses the isolated app test host, Release configuration with testability
enabled, a single test and serial execution. Confirm shipping-build behavior
separately in Instruments. It refuses to start while Lectern or its test host is
running and never terminates either. This is local-only, consistent with
`test-app.sh`; do not add a hosted Actions job for app-hosted tests.

The probe invokes production Inspect, then the actual `SlideRasterizer` and
`SnapshotHost` with no snapshot override. It repeats on the same bounded bitmap
cache and requires successful SVGs/bitmaps. Additional stages separate request
latency, queue wait, WebKit navigation, font readiness and snapshot capture.
Cache hits have explicit outcomes. Callback spans retain their originating trace
rather than depending on task-local inheritance through WebKit delegates.
The probe passes the record's prepared content, matching the production UI.
Schema 2 reports cache entry count, accounted bytes and byte limit after each
operation. Admission outcomes distinguish `admitted` from `overBudget`;
oversized images still return successfully. Geometry, lookup and admission are
children of `thumbnail.request`, so do not add them to the request total.

`firstBitmapAvailableSeconds` measures inspection through the first returned
bitmap. This is a sequential probe, not the lazy contact sheet's scheduling or
the first visible display frame. App CPU and lifetime peak RSS exclude WebKit
helper processes; peak RSS also includes test-host startup. Use Instruments on
the production app for total-process memory and request-to-visible-frame latency,
and retain the trace, machine/OS/build/font identities and screen recording.
Neither this probe nor Linux timings establishes a native Mac speedup or Office
visual acceptance. Native app tests and measurement are pending until run on a Mac.

## Checks

```sh
swift test --package-path Lectern --filter 'PipelineTraceTests|PreviewCacheTests'
python3 -m unittest discover -s scripts/tests
bash Lectern/scripts/test-app.sh -only-testing:LecternAppTests/PreviewPipelineTraceTests
```

The Core regressions compare traced/untraced saved deck bytes, previews and
ordered diagnostics, test task isolation and bounded traces, and retain failure
outcomes. Collector checks reject changed content, source files or executables.
The default app check exercises cache-hit accounting; the file-driven native
probe runs only when explicitly configured by `profile-preview.sh`.

## Cache-only comparison

Compile the current production identity/cache sources alongside a frozen copy
of the original cache from `e35bf24`. No SwiftPM dependencies or bitmap host are
required. Keep these private inputs and result paths outside the checkout:

```sh
swiftc -O -parse-as-library \
  Lectern/Sources/LecternCore/Inspection/PreviewContent.swift \
  Lectern/Sources/LecternCore/Inspection/CostLimitedCache.swift \
  Lectern/Sources/LecternCore/Rendering/PipelineTrace.swift \
  Tools/preview-profile/cache-probe.swift -o /tmp/lectern-cache-probe
python3 Tools/preview-profile/run-cache.py --binary /tmp/lectern-cache-probe \
  --manifest /absolute/svg-paths.json --output /absolute/new-cache-profile
```

The manifest is a JSON array of absolute SVG paths (at most 256 slides, fitting
the candidate's 256 MiB budget with 640×360 RGBA cost estimates). The collector
alternates fresh baseline/candidate processes: one warmup pair, seven measured
pairs. It retains raw CPU/elapsed samples, whole-process CPU/elapsed and lifetime
peak RSS, input/source/executable hashes, and verifies unchanged input files.
Preparation, insertion, independently regenerated lookup and reverse-order
shared-content lookup are separate stages. Include preparation when comparing
new-inspection cost; looking only at cache hits hides that work.

Values are integers, so this probe allocates no bitmaps and cannot measure
WebKit, GPU or native UI performance. Reported cache costs include hypothetical
bitmap bytes; RSS includes both decoded SVG copies and process startup. The
small SVG control can be slower by microseconds. See the
[measured decision](../../docs/THUMBNAIL-CACHE-20261015.md), then rerun the native
Mac probe on the same saved deck before claiming an app speedup.

## Font validation and registration comparison

`font-probe.swift` compiles alongside production `InstalledFonts.swift` and the
selected Release Rostrum module/objects. Build the baseline before editing the
algorithm and retain its binary; then repeat for the candidate. For Linux:

```sh
swift build -c release --target Rostrum
swiftc -O -I .build/release/Modules \
  Tools/preview-profile/font-probe.swift \
  Lectern/Sources/LecternCore/Rendering/InstalledFonts.swift \
  .build/release/Rostrum.build/*.o -o /absolute/font-probe
python3 Tools/preview-profile/run-fonts.py \
  --baseline-binary /absolute/font-probe-before --binary /absolute/font-probe \
  --workloads /absolute/font-workloads.json --output /absolute/new-font-profile
```

The manifest has `workloads` entries containing a simple unique `name`, a `paths`
array of licensed font files (relative to the manifest or absolute), and requested
`families`. Include regular-only, multiple-style, collection and missing controls.
The probe injects candidate file discovery; file reads, face validation and
registration use production code. It creates two fresh sessions/registries per
process, then saves and renders fixed mixed-style text. The collector alternates
fresh baseline/candidate processes, retains one warmup and seven measured pairs,
and requires identical PPTX/SVG/diagnostic/registration artifacts and unchanged
font/executable hashes. Private font bytes and artifacts stay outside Git.

Stage CPU/elapsed includes file reads through registration. Process CPU/elapsed
and lifetime peak RSS also include fixture generation, rendering, verification
and evidence writes. OS font discovery, CoreText, WebKit and UI are excluded;
these timings cannot establish a native Mac preview speedup. Record source
revision and hashes for both builds alongside the raw report.
