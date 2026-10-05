## Burn-down — 20261003, third layout pass

User instruction: “Fidelity and performance!” Baseline: `5654d1b09e43d26f93a195270f8832b6be3a21e4`.
This continues the existing FUNC-2/PERF-1 items; animation remains excluded.
Destination remains draft [PR #33](https://github.com/welshofer/rostrum/pull/33),
against `main`, with authorized pushes and no merge.

### Routing and isolation

The existing frontier implementation lanes retain their requested `gpt-6-astra`
with high reasoning; the independent reviewer is requested `gpt-6.1-sol` with high
reasoning. Runtime model identity is not independently attested. Four concurrent
slots include the orchestrator. Reused worktrees were branched sequentially from
the baseline; unrelated scratch remains intact.

| Lane | Worktree | Branch |
| --- | --- | --- |
| PERF-1 common layout overhead | `/path/to/user/.codex/worktrees/rostrum-fonts/rostrum` | `codex/burndown/layout-perf3-20261003` |
| FUNC-2 native line boundaries | `/path/to/user/.codex/worktrees/rostrum-tables/rostrum` | `codex/burndown/layout-rounding-20261003` |
| FUNC-2 Lectern demonstration | `/path/to/user/.codex/worktrees/rostrum-metadata/rostrum` | `codex/burndown/lectern-fidelity3-20261003` |

The performance lane initially owns library source changes. The fidelity lane
initially creates only independent fixtures and tests; engine edits serialize
after the performance change. Lectern waits for verified native behavior before
implementation. Root handles native GUI exports and integrated app verification.
Authoritative performance measurements use explicit quiet windows.

### Resolved verification

Root: `swift test --jobs 2`, `swift test --package-path Lectern --jobs 2`,
README snippets, native `Lectern/scripts/test-app.sh -parallel-testing-enabled NO`,
the source-hashed headless app harness and both iOS simulator architectures.
Release performance uses the existing benchmark product/driver and matched
fresh-process pairs. Native PowerPoint runs through the GUI; exported reference
PDFs use local Best for printing. No lint command is configured; whitespace uses
`git diff --check`. Repository rules require no new runtime dependencies,
three-platform support, unchanged unknown XML and deterministic output.

The preceding baseline's required Linux checks and hosted macOS PR job all
passed. This is baseline status, not verification of the new work.

### Initial scope

PERF-1: profile repeated common line-metric work and recover the measured
fallback/fitting slowdown without changing output. FUNC-2: establish independent
native evidence for the known narrow-boundary line-break mismatch before choosing
a correction. No new fidelity or speed claim is accepted at this checkpoint.

### Accepted isolated performance increment

Source/tests `9934471` are integrated as `36bb7e6`; evidence `f121222` is
integrated as `abdc118`. The [isolated report](docs/LAYOUT-PERFORMANCE-20261003-3.md)
records three retained measurement cycles. The accepted final source reduces
registered-font table rendering by 7.56% and fitting by 7.91% versus `5654d1b`,
with ten of ten faster pairs and nonoverlapping ranges. A separate comparison
against `cf1b8a0` measures 9.13% and 5.91% improvements on those workloads.
Fallback recovery remains unproven. These are pre-fidelity results and require
a final combined measurement before any integrated performance claim.

The independent reviewer approved the three source changes and final evidence
without findings. Root verified all 49 retained primary evidence hashes across
the three receipts. Worker verification passed 1,021 library tests / 141 suites,
all 60 existing native tab cases, and identity across 76 fixture/font combinations
and 628 slides; 152 saved outputs reopened and table-traversed. Those worker
checks do not replace the final root integration gate.

### Native evidence collected

Root opened five independently authored line-boundary decks in PowerPoint
16.113.3 without repair and exported local **Best for printing** PDFs: 30 slides
and 175 cases. `/tmp/rostrum-boundary-native-exports-20261003.json` records every
source/PDF hash and page count. The sources were not saved by PowerPoint.
The evidence distinguishes base-advance rounding, pair positioning, tracking,
effective autofit size, body capacity and paragraph coordinate conversion.
One multi-scalar ligature control remains an explicitly diagnosed boundary;
the exact calibration claim covers the other 174 cases. Numeric Arial metrics
and the bundled DejaVu face make the retained Swift assertions portable.

Independent review prompted fixes for invisible missing-font runs affecting
wrapping and inconsistent RTL grid eligibility. Regression tests cover those
boundaries. Existing native tab and paragraph expectations remain unchanged.
The new visible-width result exposes the existing advance calculation minus
trailing ordinary spaces; it does not claim glyph-ink bounds.

### Final item status and evidence

| Plan item / bounded increment | Status | Root commit | Post-change proof |
| --- | --- | --- | --- |
| PERF-1: paragraph-local styles, numeric line scans and nil-metrics guard | Implemented and independently reviewed | `36bb7e6` | `RichTextLayout.swift` retains styles per paragraph and scans numeric metrics; `LayoutAtomStyleTests.swift` checks empty runs, direct DOM edits, inheritance and previous-layout independence |
| FUNC-2: native line boundaries and visible advance width | Implemented and independently reviewed | `301a6c2` | `RichTextLayout.swift:35`, `:324`, `:630`; `LineBreakBoundaryTests.swift:6` qualifies 175 line cases and 174 bounded horizontal cases |
| FUNC-2: Lectern boundary/fit demonstration and file pipeline | Implemented and independently reviewed | `87176bd` | `PlatformParagraphBoundary.swift:57` compares independent native lines; `:129` reads saved styles/autofit; `LibraryLabTests.swift:80` exercises inspection/export |
| PERF-1: combined measurement | Complete; fallback recovery remains unproven | `67f5b89` | Final matched report and four receipts; no additional optimization attempt |

Root re-read the changed implementation and proof locations. Broader FUNC-2 and
PERF-1 remain ongoing; this closes only these bounded increments. The destination
is draft PR #33; no merge is authorized or performed.

The [combined measurement](docs/INTEGRATED-LAYOUT-PERFORMANCE-20261003-3.md)
supersedes isolated speed figures: against `5654d1b`, registered-font table
rendering is **4.44% faster** and fitting **5.92% faster**, each in ten of ten
pairs with nonoverlapping ranges. Against `cf1b8a0`, registered rendering improves
5.94%; fitting's 3.73% lower median has overlapping ranges and one slower pair.
Fallback recovery remains unproven (0.27% slower median, five faster pairs and
overlapping ranges). No net-memory, universal or cross-platform speed claim.

Combined output proof covers four workloads, 13 slides per candidate repetition,
two deterministic candidate repetitions and 32 independent PPTX reopens/table
traversals. All saved PPTX hashes match both baselines. Registered-table SVG and
the rich fitting workload's ordered diagnostics intentionally change; the latter
now diagnoses the non-ASCII calibration boundary. This is separate from the
earlier preserving-stage 628-slide identity. Both timing comparisons use the
unchanged canonical runner and its cross-version saved-PPTX identity gate.
Root verified all 19 primary and 188 output/input hashes. Independent review
recomputed the measurements and approved the final source/evidence boundaries.

### Integrated verification

Code checks describe `87176bd`; subsequent changes are evidence/documentation.
The [root receipt](docs/benchmarks/2026-10-03-boundary-integration-verification.json)
pins all commands, logs and artifacts.

- Library: **1,025 tests / 142 suites**, including all new native cases and the
  unchanged 60 native tab cases and paragraph references.
- LecternCore: **236 tests / 27 suites**; **25 Lab demos / 319 saved-file checks**.
  The expanded paragraph demo passes **22 checks with zero findings**.
- Native app: **78 tests passed, zero failures/skips**; xcresult records 106
  total executions, including 46 runs from 18 parameterized tests.
- Headless app harness: **78 reported tests / 18 suites passed**, with three
  native WebKit checks skipped and covered by the native run. All 55 copied
  inputs, 148 dependency inputs and the log hash were verified.
- iOS simulator Debug build passed for **arm64 and x86_64**, verified with lipo.
- README: both sample decks generated and reopened.
- PowerPoint opened the saved twelve-slide engine specimen without repair;
  first page visually checked and original SHA retained. It also opened both
  three-slide Lectern specimens without repair; third slides visually match
  their native boundary labels and show clean computed fits with mixed styles.
- Actual rebuilt Lectern: custom title, four sentences, both width variants,
  22 checks each, three-slide inspection and successful Export Everything.
  Exported Markdown contains the new boundary slide, narrow width and fit labels.
- No new runtime dependency; no lint command configured. `git diff --check`
  is the final whitespace gate.

Source review approved the performance, engine and Lectern increments. Evidence
review approved all paired arithmetic and native scope. Early review findings
about empty missing-face runs and RTL eligibility were fixed with direct tests.
Existing raw-font kerning expectations were corrected using independent native
factorials, including file-backed nil/zero/positive threshold coverage.

### Delivery and remaining scope

Push to the existing draft [PR #33](https://github.com/welshofer/rostrum/pull/33)
is authorized. At this evidence checkpoint, the final push and final-head
Linux/macOS CI are pending. Their resulting status will be recorded on the PR;
hosted macOS is tracked separately from local native acceptance.
There is no deployed service or App Store submission in this pass.

Remaining work includes fallback performance recovery, full native ligature and
complex-script paragraph fidelity, native-selected autofit equivalence and the
previously retained table/typography raster gaps. Numeric boundary checks do not
reclassify earlier raster failures. Animation remains excluded.
