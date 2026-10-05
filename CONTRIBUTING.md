# Contributing to Rostrum

Thanks for your interest. Rostrum is a zero-dependency, pure-Swift library for
reading and writing PowerPoint `.pptx` files. A few conventions keep it
coherent — most are also documented in [`CLAUDE.md`](CLAUDE.md) and
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

## Ground rules

- **Rostrum has zero dependencies.** No SwiftPM dependencies in the library. We own the zip
  container, DEFLATE, XML, and everything above. `Foundation` (plus
  `FoundationXML` on Linux) is the only import.
- **Three platforms.** macOS, iOS, and Linux. Never use an API that is absent
  on any of them — notably `XMLDocument`/`XMLNode` (iOS lacks them; use
  `Sources/Rostrum/XML`). CI builds on Linux with Swift 6.0 and 6.1, runs the
  package tests on 6.1, and checks macOS on pull requests. The local
  `./scripts/verify.sh` gate adds iOS simulator builds and app-hosted tests
  (see [Before a PR](#before-a-pr)).
- **Lossless round-trip is sacred.** Opening a file and saving it must never
  drop or corrupt XML we do not model. A part you never touch re-emits its
  original bytes.
- **Determinism.** The same input produces byte-identical output.

These library rules do not prohibit LecternCore's local Rostrum dependency or
its conditionally compiled Apple frameworks. Lectern's SwiftUI app targets
are macOS/iOS-only and are built separately from the Swift packages.

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

The helper opens a uniquely named private copy, matches its absolute path,
and closes only that copy after a clean open. It never closes unrelated work.
Exit codes are 0 for accepted, 1 for repair or a target rejection dialog, 2 for invalid input, 3 for timeout,
and 4 for automation failure or an ambiguous dialog. Failed checks retain the
copy and print its path; inspect and close that disposable presentation yourself.
PowerPoint and macOS Automation/Accessibility access must be available. An
automation failure is not evidence that the deck is valid or invalid.
Run the helper's offline checks with `python3 -m unittest discover -s scripts/tests`.

## Testing conventions

- swift-testing (`import Testing`, `@Test`, `#expect`), one suite per area.
- New format features should carry a round-trip test (build → save → reopen →
  assert) and, where practical, an external-oracle check.
- Run the local gate below before opening a PR; root `swift test` alone does
  not cover LecternCore or the SwiftUI app.

## Before a PR

```sh
./scripts/verify.sh          # everything
./scripts/verify.sh --fast   # skip both app builds AND app-hosted tests
```

CI builds with Swift 6.0 and 6.1 on Linux on every push, runs the Rostrum,
RostrumLayout and LecternCore tests on 6.1, and runs the README examples on both
toolchains. The macOS 26 pull-request gate runs the package tests and builds
the Lectern app. See [the workflow](.github/workflows/ci.yml) for the exact
commands. The local `verify.sh` gate also builds the iOS simulator target and
runs app-hosted tests, alongside the package suites and README examples.

Those app targets are not part of any SwiftPM target, so `swift test` never
compiles them. The full gate also runs the app-hosted tests. Use
`Lectern/scripts/build.sh` and `Lectern/scripts/test-app.sh` for macOS work:
both honor the same optional, gitignored signing configuration so saved
Keychain items remain readable across builds. Simulator builds use
`Lectern/scripts/build-ios.sh` and its ad-hoc entitlement shim.

Hosted tests run in the distinct `LecternTestHost` app through `LecternTests`.
The wrapper refuses to run while either Lectern app is open and never terminates
one. Test products use `.build-xcode-tests` (`LECTERN_TEST_DERIVED_DATA_PATH`);
normal builds use `.build-xcode` (`LECTERN_DERIVED_DATA_PATH`). The test host
disables all credential operations and live generation, including when opened
without the scheme environment. Do not use a test host for user work.

The gate also runs offline acceptance-helper and project-wrapper regressions.
For performance changes, use the [Release benchmark](Tools/rostrum-benchmark/README.md)
with fixed decks and compare both timing and preservation results. Inspect
representative output in Lectern and PowerPoint before claiming visual fidelity.

## Style

The two runnable README examples are generated from
`Examples/ReadmeSnippets/main.swift`. Edit that source, then run
`python3 scripts/readme-snippets.py --write`. The local and CI gates reject
drift before compiling and running the examples. Installation fragments and
illustrative cookbook fragments are not part of this executable set.

- Match the surrounding code's naming and idiom. OOXML element names stay
  qualified as in the spec (`p:sldMasterIdLst`) in string literals; Swift API
  names are Swift-native.
- Comments state constraints the code can't show, not narration.

## Submitting

1. Fork and branch from `main`.
2. Keep changes focused; one feature or fix per PR.
3. Ensure `./scripts/verify.sh` is green and CI passes.
4. Describe what changed and how you verified it (oracle output, a rendered
   screenshot for visual features, etc.).

By contributing you agree your work is licensed under the project's
[MIT License](LICENSE).
