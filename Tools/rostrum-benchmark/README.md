# Rostrum performance and preservation baseline

Build once in Release, then run one input per process. Supply a new output
folder each time; the tool refuses to overwrite an existing folder or the input.

```sh
swift build -c release --product rostrum-benchmark
/usr/bin/time -l .build/release/rostrum-benchmark input.pptx /tmp/rostrum-benchmark-run-1 3
```

`/usr/bin/time -l` reports peak resident memory on macOS. On Linux, use
`/usr/bin/time -v`. The tool itself uses only Foundation and Rostrum.

Each sample measures opening in-memory PPTX bytes, serialization to bytes, a
first SVG pass over all slides at 640 pixels wide, and a repeat pass on the same
presentation. JSON includes individual samples and medians. Reading the input,
writing output, and fidelity checks are outside the timed sections. The first
sample is a first-use measurement within this process, not a cold disk-cache
measurement. A repeat SVG pass is not a cached bitmap lookup.

Before emitting results, the tool requires:

- Identical part names and decoded payload bytes before and after the round trip.
- Deterministic save bytes across samples and after read-only rendering.
- Identical slide count and SVG strings after reopening the saved file.

It exits nonzero if a check fails. A changed payload needs investigation; byte
inequality alone does not diagnose its semantic effect. The new folder contains
`timings.json`, `roundtrip.pptx`, and one SVG per slide for further inspection.
Open the round-trip deck in PowerPoint and compare representative slides there;
these mechanical checks cannot establish visual equivalence with PowerPoint.

Use a small deck, a large deck, and an image-heavy deck from the same corpus for
comparisons. Record hardware, Swift version, build configuration, slide and byte
counts, and any concurrent load. Peak RSS covers the entire process, including
held SVGs and the independent ZIP/fidelity checks; it is not the peak allocation
of an isolated library operation. Compare repeated runs on the same machine and
inputs before setting regression budgets or claiming a speedup.

For Lectern's native preview geometry and bitmap-cache checks:

```sh
Lectern/scripts/test-app.sh -quiet -only-testing:LecternAppTests/PreviewGeometryTests
```

To also capture the actual contact-sheet/filmstrip layouts and timings, create
an output directory and pass it through the Xcode test runner:

```sh
mkdir -p /tmp/lectern-preview-check
TEST_RUNNER_LECTERN_AUDIT_OUTPUT=/tmp/lectern-preview-check \
  Lectern/scripts/test-app.sh -quiet -only-testing:LecternAppTests/PreviewGeometryTests
```

These app tests use small synthetic SVGs in Debug. They cover 16:9, 4:3 and
portrait sizes, all four corner markers, and separate cached resolutions. Their
first-render and cached-request timings are diagnostic observations, not timing
assertions or a scrolling benchmark. The first render includes creation of the
shared WebKit host. Use production-sized images and a Release profile when
investigating real UI latency.
