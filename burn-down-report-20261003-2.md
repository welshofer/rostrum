## Burn-down — 20261003, second layout pass

This is a bounded continuation of FUNC-2 and PERF-1 from the existing lift-up
plan, authorized by “Keep going.” The destination remains draft
[PR #33](https://github.com/welshofer/rostrum/pull/33), without merging.
Baseline: `cf1b8a0cec2cf680383cb683603785aeaa0f2011`.

### Routing and isolation

The three implementation lanes requested `gpt-6-astra` with high reasoning;
the independent reviewer requested `gpt-6.1-sol` with high reasoning. These are
dispatch selections, not independently attested runtime identities. Four
concurrent slots were available, including the orchestrator. Existing isolated
worktrees were reused and given fresh branches sequentially before dispatch:

| Lane | Worktree | Branch |
| --- | --- | --- |
| FUNC-2 engine | `/path/to/user/.codex/worktrees/rostrum-tables/rostrum` | `codex/burndown/layout-tabs-20261003` |
| FUNC-2 Lectern | `/path/to/user/.codex/worktrees/rostrum-metadata/rostrum` | `codex/burndown/lectern-tabs-20261003` |
| PERF-1 | `/path/to/user/.codex/worktrees/rostrum-fonts/rostrum` | `codex/burndown/layout-perf2-20261003` |

The Lectern lane briefly applied an engine source snapshot solely to compile
its dependent work; the final engine commit replaces that snapshot before
verification. Unrelated scratch files were preserved. The root performs
sequential integration, native GUI checks, app verification and publishing.

### Evidence

The [fidelity report](docs/LAYOUT-FIDELITY-20261003-2.md) records the public tab
API and shared geometry. Independent python-pptx decks were opened without
repair in PowerPoint 16.113.3; native PDFs use local **Best for printing**
export. A Rostrum-written/reopened five-slide v2 deck also opened without
repair. The exact-edge regression retains its original assertion after the
native comparison established the correct behavior.

The [combined performance checkpoint](docs/INTEGRATED-LAYOUT-PERFORMANCE-20261003.md)
measures **2.26% slower fallback table rendering and 3.01% slower rich-text fitting**
against the baseline, with both slower in all ten matched fresh-process pairs.
Registered table rendering is 0.75% faster with overlapping ranges. The isolated
ASCII scan's 3.96% improvement is not the combined batch's performance. Four
measured workloads preserve all 13 slide outputs against the baseline.

One bounded no-tab optimization attempt passed correctness checks but failed to
resolve these regressions. Its source was discarded; root never integrated it.
The [negative-result report](docs/INTEGRATED-LAYOUT-PERFORMANCE-20261003-ATTEMPT.md)
retains the patch and measurements. Its 628-slide identity check compares the
unshipped attempt with the retained tab engine, not the new tab feature with the
older baseline. Profiling common layout overhead remains the next PERF-1 task.
Root verified all 20 retained-file hashes across the combined/attempt receipts,
five current source/driver hashes, and the retained patch hash. The preceding
isolated experiment's 25 retained/source hashes were also verified.

Independent review approved the ASCII scan at `35dcd41`, the engine at `7fca2ee`
and Lectern at `26d98d3`. The engine review prompted correction of the diagnostic
category and consistency across the API's full 1…Int32.max EMU interval range;
both endpoints have regression coverage. Subsequent integrated source remained
unchanged during measurement/reporting. Final evidence review approved the combined report, raw arithmetic, capability
boundaries, source identity and test-count/skip distinctions with no findings.
The reviewer independently checked committed data and diffs; local log/hash
verification remains the orchestrator's attestation.

### Item status and post-change proof

| Plan item / bounded increment | Status | Integrated commit | Proof |
| --- | --- | --- | --- |
| FUNC-2: standard LTR Latin tabs and tab-aware justification | Implemented and independently reviewed; destination PR #33 | `7fca2ee` | `Sources/Rostrum/Presentation/Text.swift:143` and `:172` expose inherited tab settings; `RichTextLayout.swift:225`, `:310`, `:358` and `:476` implement field measurement, tab selection, justified spacing and wrapping; `Tests/RostrumTests/TabLayoutTests.swift:116` checks 60 native cases |
| FUNC-2: Lectern tab demonstration and export | Implemented and independently reviewed; destination PR #33 | `26d98d3` | `Lectern/Sources/LecternCore/LibraryLab/PlatformTabRecipe.swift:9` authors the recipe with public APIs; `:130` and `:152` check tab anchors and justification; the native app workflow and tests exercise inspection/export |
| PERF-1: ASCII break scanner | Implemented and independently reviewed; combined regression remains open | `35dcd41` | `Sources/Rostrum/Fonts/TextShaper.swift:297` uses an ASCII path preserving CR/LF behavior; isolated output/paired measurements pass, combined results above take precedence |
| PERF-1: attempted no-tab correction | Deferred after measured failure; attempted source not shipped | Evidence in `c32ba46` | Retained patch, source/binary hashes and unsuccessful matched run; no further implementation iteration |

The orchestrator re-read these source locations after integration. Broader
FUNC-2/PERF-1 items remain ongoing; this table closes only the bounded increments.

### Integrated verification

All code checks describe source commit `26d98d3`; later changes are evidence/docs.

- `swift test --jobs 2`: **1,019 tests in 140 suites passed**, including the
  60-case native geometry oracle.
- `swift test --package-path Lectern --jobs 2`: **234 tests in 26 suites passed**;
  all 25 Lab demos have 310 saved-file checks.
- `Lectern/scripts/test-app.sh -parallel-testing-enabled NO`: **78 native app
  tests passed, zero failures/skips**. The xcresult reports 106 parameterized
  executions, with 18 tests contributing 46 dynamic runs.
- Headless `test-inspection-headless.py --all-app-tests`: **78 reported tests
  in 18 suites passed**, with three native WebKit checks skipped and covered by
  the native app run. All 55 copied inputs and 146 dependency inputs were hashed.
- iOS simulator Debug build passed with both **arm64 and x86_64**, confirmed by
  `lipo -archs` on `Lectern.debug.dylib`.
- `swift run ReadmeSnippets /tmp/rostrum-tabs-readme-20261003` wrote and reopened
  both sample decks successfully.
- Actual Lectern: selected the new tab recipe, set twelve rows, ran default and
  moved stops (13 checks each), inspected the two-slide result, and completed
  Export Everything. `/tmp/lectern-tabs-gui-export-20261003/tabLayout/tabLayout.md`
  contains the numeric text, justification heading and natural-last-line example.
- Native PowerPoint opened the final twelve-row artifacts at both stop positions
  without repair. Both slides were visually inspected. The default artifact SHA-256
  is `9d37d9c015a279f3ab92a3e1633e029eb991dbbbee228a6214feda32337ad22a`;
  moved-stop SHA-256 is `b769621496e6d53dba93c9c7b6a4029b6136b153a6605249b5f49e844824fd72`.
  Each remained unchanged after opening. A transient moved-stop display anomaly
  in a long-lived PowerPoint session cleared after restarting PowerPoint and
  reopening the exact same bytes. Its cause is unproven; clean rendering was
  accepted only after the fresh-process check.
- No lint command is configured. No new SwiftPM runtime dependency was added.
  `git diff --check` passed as the final whitespace gate.

The [root verification receipt](docs/benchmarks/2026-10-03-tab-integration-verification.json)
pins log and artifact hashes. Native fixtures and measurement receipts are
committed; larger build products and logs remain at the recorded local paths.
The final headless check was repeated because an earlier log did not match its
receipt hash; the accepted repeat uses a separate output path and verifies the
log hash as well as every input. Earlier mismatched-log evidence is not accepted.

### Delivery

Destination: [draft PR #33](https://github.com/welshofer/rostrum/pull/33), against
`main`. Push and PR updates are authorized. Required hosted Linux checks are
verified after pushing; their final-head status is recorded on the PR. The
optional hosted macOS check is tracked separately from local native verification.
There is no deployed service or App Store submission in this pass.

### Remaining scope

FUNC-2 and PERF-1 remain broader ongoing plan items. This pass does not establish
full bidi, locale-specific decimal tabs, columns, decoration fidelity,
whole-slide Office pixel parity, universal performance gains or per-platform
latency gates. Existing table raster thresholds remain unchanged and their
remaining mismatches remain open. Animation is excluded. No deployment or
merge is authorized or performed.
