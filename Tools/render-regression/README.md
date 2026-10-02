# Paired renderer checks

Compile the same `main.swift` against separately built baseline and candidate
release libraries. The driver renders identical synthetic 10,000-cell tables
and 250-image slides, recording SVG, ordered fidelity issues, inheritance flags
and timings. Text uses the same deterministic unregistered-font fallback in
both binaries. This measures warm rendering, separately from the existing
fresh-process `rostrum-bench` scenarios.

On the Xcode-backed SwiftPM layout used for the October 2026 measurements:

```sh
swift build --disable-sandbox --scratch-path /path/to/build -c release -debug-info-format none --product rostrum-bench -j 2
swiftc -O -I /path/to/build/out/Products/Release Tools/render-regression/main.swift /path/to/build/out/Products/Release/Rostrum.o -o /path/to/render-driver
```

Use separate scratch and module-cache paths for separate checkouts. Retain each
compiled driver before building the next revision. Other SwiftPM build engines
may use different object/module locations.

```sh
python3 Tools/render-regression/run.py --baseline /path/to/baseline-driver --candidate /path/to/candidate-driver --baseline-revision BASE_SHA --candidate-revision CANDIDATE_SHA --output /path/to/comparison.json --work-dir /path/to/render-outputs
```

The runner alternates AB/BA invocation order, excludes each invocation's first
sample, retains all samples and binary/driver/output hashes, and fails if SVG or
diagnostics differ. It does not assert a universal timing threshold. Run without
concurrent builds or profiling; use repeated comparisons for small differences.
Output directories can be large and should remain outside version control.

The driver also accepts `file:/absolute/path/deck.pptx`. Set
`ROSTRUM_PROFILE_FONTS` to pipe-separated font paths for manual visual checks;
the paired synthetic runner is intended to run without that environment variable.
It never changes the input deck. Pixel comparison against Office remains the
separate, unchanged `Tools/conformance/check_text_rendering.py` gate.
