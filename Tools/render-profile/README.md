# Warm render profiling

`main.swift` is the exact driver retained with the 2026-10-01 follow-up samples.
It is deliberately outside the `rostrum-bench` executable target. Compile it
against a release library and pass a PPTX, iteration count, and optional output
prefix. It prints millisecond samples including the first warmup; exclude that
sample when computing the warm median. The optional first SVG/issue output is
written outside the timed interval.

```sh
swift build -c release
swiftc -O -I /path/to/release-bin Tools/render-profile/main.swift /path/to/release-bin/Rostrum.o -o /tmp/profile-render
/tmp/profile-render /path/to/fixture.pptx 8 /tmp/render-proof
```

Resolve the build path with `swift build -c release --show-bin-path`. The object
layout above is the local Xcode-backed SwiftPM layout used for the samples; other
SwiftPM build engines may require their corresponding Rostrum object files.
This helper does not register fonts and is not the fresh-process scenario driver;
use `Tools/rostrum-bench/run.py` for that. Keep exact fixture/output hashes when
comparing revisions, and compare diagnostics as well as SVG.
