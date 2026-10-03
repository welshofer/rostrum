# Layout follow-up

## Burn-down — 20261003

Scope: the user's request to improve layout fidelity and performance, with every
capability demonstrated in Lectern and completed work pushed to GitHub. This is
a bounded continuation of FUNC-2 (shared rich-text layout) and PERF-1 (measured
performance), not completion of every remaining fidelity item in the original
plan. Its shared-layout proof was stale: fitting/rendering already shared an
engine, but `just` still silently used left alignment.

The original `lift-up-plan-20261001.md` is ignored by the repository. Its dated
appendix is mirrored in this tracked report rather than force-adding the entire
historical plan. Existing plan fields and earlier outcomes are preserved.

| Item | Result | Integrated commit | Evidence |
| --- | --- | --- | --- |
| PERF-1 | ASCII normalization bypass; registered table render −12.36%, rich fitting −24.08% | `0c3d2e6` | Ten matched pairs; 576 identical slide outputs; [report](docs/LAYOUT-PERFORMANCE-20261003.md) |
| FUNC-2 | Bounded Latin word-space justification, with explicit unsupported cases | `71e80c8`, `9ec5cdd` | Native PowerPoint word-start oracle, mixed styles, hard breaks, tracking/kerning, save/reopen and SVG tests |
| Lectern integration | Configurable paragraph/table recipe and actual inspection/export tests | `0dfe5c6` | 24 recipes, 297 saved-file checks; paragraph recipe 13 checks and zero findings |
| CI compatibility | Equivalent typed numeric expressions avoid older compiler complexity failures | `62245ee`, `961fef6` | Focused tests; Linux and macOS GitHub runs at `961fef6` succeeded |

Integration uses `codex/burndown/20261001`. Fidelity, performance and Lectern
implementers used separate existing managed worktrees (`rostrum-tables`,
`rostrum-fonts`, `rostrum-metadata`). Existing untracked artifacts were preserved.
Requested executor model: `gpt-6-astra`, high; requested independent reviewer:
`gpt-6.1-sol`, high. These are tool-selected routing records, not independently
attested runtime model identities. The read-only reviewer approved performance,
layout, Lectern and both compiler compatibility changes. Its suggested
tracking/kerning coverage was added and passed; no source correction was needed.

## Integrated verification

- `swift test --jobs 2`: 1,009 tests in 138 suites passed before the final
  tests-only tracking/kerning addition. The final paragraph suite passed all
  10 tests, including four parameterized tracking/kerning cases.
- `swift test --package-path Lectern --jobs 2`: 231 tests in 25 suites passed.
- Native `Lectern/scripts/test-app.sh -parallel-testing-enabled NO`: 77 tests,
  zero failures and zero skips, including both paragraph inspector/export cases.
- `test-inspection-headless.py --all-app-tests`: 77 tests in 18 suites passed
  with a source-hash receipt.
- Release benchmark product built. iOS simulator app built for both arm64 and
  x86_64; architectures were checked on the produced debug dylib.
- Native Lectern: selected paragraph demo, enabled narrow columns, ran it
  offline, observed 13 passing checks, inspected both slides, and completed
  Export Everything. The exported Markdown contains the table text.
- PowerPoint 16.113.3 opened both independent source fixtures, the integrated
  engine's saved v2 deck, and the actual Lectern-generated deck without repair.
  The saved v2 package has identical decompressed entry payloads to its source;
  the ZIP container bytes differ. Python-pptx reopened the sources and outputs.
- `git diff --check` passed. No lint command is configured. No new runtime
  dependency, global mutable cache, source-DOM mutation or animation was added.

Local logs/receipts are `/tmp/rostrum-layout-integrated-20261003.log`,
`/tmp/rostrum-paragraph-final-20261003.log`, `/tmp/lectern-layout-core-20261003.log`,
`/tmp/lectern-layout-native-20261003.xcresult`,
`/tmp/lectern-layout-native-summary-20261003.json`,
`/tmp/lectern-layout-headless-20261003.json`, `/tmp/lectern-layout-ios-20261003.log`,
and `/tmp/rostrum-layout-external-verification-20261003.json`.
Native fixture references, raw paired measurements and identity receipts are
committed alongside their documentation. Timing was performed while other
workers and GUI verification were held idle.

## Delivery and remaining work

Delivery target: [draft PR #33](https://github.com/welshofer/rostrum/pull/33),
against `main`. Push and PR updates are authorized; merging is not part of this
pass. There is no deployed service to verify. Final-head GitHub checks are
recorded on the PR after the push.

Remaining fidelity work includes font-rounding/line-break parity, paragraph
bidi, tab-aware justification, multi-column flow, decorations and outstanding
table raster differences. Tabs, RTL/non-Latin justification and distributed/low
justification remain diagnosed limitations. No universal pixel-parity,
cross-platform speed or net-memory improvement is claimed. The
[layout follow-up](docs/LAYOUT-FIDELITY-20261003.md) records the next priorities.
