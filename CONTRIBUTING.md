# Contributing to Rostrum

Thanks for your interest. Rostrum is a zero-dependency, pure-Swift library for
reading and writing PowerPoint `.pptx` files. A few conventions keep it
coherent — most are also documented in [`CLAUDE.md`](CLAUDE.md) and
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

## Ground rules

- **Zero dependencies, forever.** No SwiftPM dependencies. We own the zip
  container, DEFLATE, XML, and everything above. `Foundation` (plus
  `FoundationXML` on Linux) is the only import.
- **Three platforms.** macOS, iOS, and Linux. Never use an API that is absent
  on any of them — notably `XMLDocument`/`XMLNode` (iOS lacks them; use
  `Sources/Rostrum/XML`). CI builds and tests on macOS and Linux.
- **Lossless round-trip is sacred.** Opening a file and saving it must never
  drop or corrupt XML we do not model. A part you never touch re-emits its
  original bytes.
- **Determinism.** The same input produces byte-identical output.

## Development

```sh
swift build
swift test
```

Everything runs with the standard toolchain — no setup script. A few tests
shell out to external oracles (`unzip`, `zip`, `python3`) to validate our
output against independent tools; install those to run the full suite
(`apt-get install zip unzip python3` on Debian/Ubuntu). The pure-Swift suite
passes without them.

### The acceptance oracle

`Tools/ppt-check.sh <file.pptx>` (macOS) opens a deck in Microsoft PowerPoint
via LaunchServices — the double-click path that runs PowerPoint's strict
integrity check — and reports whether it opens clean or triggers the repair
dialog. This catches format bugs that `xmllint`, python-pptx, and LibreOffice
all tolerate. If you touch the packaging or a part's XML, run it.

## Testing conventions

- swift-testing (`import Testing`, `@Test`, `#expect`), one suite per area.
- New format features should carry a round-trip test (build → save → reopen →
  assert) and, where practical, an external-oracle check.
- Run `swift test` before opening a PR.

## Style

- Match the surrounding code's naming and idiom. OOXML element names stay
  qualified as in the spec (`p:sldMasterIdLst`) in string literals; Swift API
  names are Swift-native.
- Comments state constraints the code can't show, not narration.

## Submitting

1. Fork and branch from `main`.
2. Keep changes focused; one feature or fix per PR.
3. Ensure `swift test` is green and CI passes.
4. Describe what changed and how you verified it (oracle output, a rendered
   screenshot for visual features, etc.).

By contributing you agree your work is licensed under the project's
[MIT License](LICENSE).
