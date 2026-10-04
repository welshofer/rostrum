# Headless AppTests isolation — 2026-10-02

Current integrated status: [October 2 implementation and verification](IMPLEMENTATION-20261002.md).
The checkpoint details below remain historical evidence.

Base: `630ee31f6d66ffcad632b69191c3fefc0b76b3b1`. All verification ran in the
isolated metadata worktree. No app/GUI launch or project/signing changes were
performed.

AppState now retains the injected defaults instance for every preference write.
`skipKeychain` also suppresses provider/image-provider presence lookups during
switching. Library refresh and generation use an optional injected directory;
the usual Documents directory remains the production default, resolved lazily.
Deletion has an injected operation whose default remains `DeckLibrary.delete`.

Every AppState test uses a unique defaults suite and an owned temporary library.
Test deletion removes owned fixtures directly, avoiding the real Trash. Tests do
not call startup, migration, generation, network operations or keychain access.
The isolation regressions verify preference persistence through reconstruction,
unchanged standard/peer preferences, and refresh/rename/delete confined to the
injected library. Inspection's controlled cancellation/replacement cases remain
unchanged.

The existing runner keeps its inspection-only default. `--all-app-tests` runs
the complete AppTests target; `--filter` selects a focused subset. It copies
unmodified app/test Swift files, fixtures and icon assets with their original
relative layout, excluding only `LecternApp.swift` from the app's Swift sources.
SwiftPM fixture lookup is supported alongside the existing Xcode-bundle lookup.
All module/build caches are under `.build`. The receipt hashes every copied
input and all local package manifests/source inputs, checks that the source
revision did not change during the run, and hashes the resulting log.

Commands, exit code 0:

```sh
python3 Lectern/scripts/test-inspection-headless.py --output /tmp/rostrum-app-isolation-focused.json --filter 'AppStateIsolationTests|InspectionRequestTests'
python3 Lectern/scripts/test-inspection-headless.py --output /tmp/rostrum-app-isolation-all.json --all-app-tests
```

- Focused: **10 tests / 2 suites**, 0.341 seconds; build 5.60 seconds.
- All AppTests: **42 tests / 11 suites**, 0.356 seconds; build 5.92 seconds.
- Exact-copy/input/log audit: **40 copied inputs / 121 dependency inputs**, all
  hashes verified; all AppTests Swift files included; entry point absent.
- `git diff --check`: exit 0.

The complete run receipt is
[2026-10-02-app-headless.json](benchmarks/2026-10-02-app-headless.json).
Focused log SHA256: `71d3182b831ee09ec86cfc2512c0b3f41673c835aa26be87f4947badeeb52c9f`.

This verifies compiled macOS app/view source and headless app-state/helper
behavior. It does not establish an Xcode application/test-bundle build, hosted
app execution, live SwiftUI behavior, iOS compilation, migration or real
keychain integration. The earlier root hosted run failed its runner connection
after about 353 seconds; these headless results do not turn that run into a pass.
Root independently reviewed the implementation and reported no findings before
commit. No publication occurred.
