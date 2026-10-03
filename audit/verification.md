# Phase 4 — verification

Baseline: commit f056474, inspected 2026-09-24; Apple Swift 6.4 on arm64 macOS. No paid provider requests, Keychain access, deployments, hook installation, live PowerPoint automation, or project edits were performed.

## Executed checks

| Check | Result | Evidence |
|---|---|---|
| LecternCore focused tests: PromptSafetyTests, OpenAIProviderTests, DeckInspectorTests, RenderedDeckTitlesTests, DeckNormalizerTests | 42 tests in 6 suites passed | logs/lectern-tests.log |
| Rostrum focused tests: BackgroundResolverTests, DeflateTests, GeneratedSchemaTests, SlideTitleSemanticsTests, RealDeckCorpusTests | 41 tests in 6 suites passed; corpus parameterizations covered 10 locally available decks | logs/rostrum-tests.log |
| Actual prompt assembly probe | Draft includes source and notes-off contract; editor has neither; repair loses source and original topic | probe.swift, logs/probe.log |
| Damaged three-slide deck inspection | Three slides reported, two previews titled First/Third, zero modeled schema issues | probe.swift, probe-output/missing-middle.pptx, logs/probe.log |
| pptx-tool on that damaged deck | Exit 0 and “no schema issues” despite a missing slide part | logs/validator-probe.log |
| 4:3 render dimensions | Rostrum emits 640×480 SVG; app snapshot code uses 640×360 and hides overflow | logs/probe.log; SlideRasterizer.swift:140,171–177; SlidePreview.swift:149 |
| PowerPoint helper with stubbed osascript/open | OK, REPAIR-DIALOG, REPAIRED-TITLE and TIMEOUT all exit 0 | logs/oracle-stub-results.json |
| Copied build wrappers with stubbed xcodebuild/xcodegen, entirely inside audit | Fresh direct iOS build never generates project and fails; repeated macOS build generates only on first invocation | logs/build-script-probe.json |
| Extracted first README Swift snippet | Typechecks but emits deprecated add(layout:) warning; executable copy uses add(clonedFrom:) | readme-example.swift; logs/readme-typecheck.log |
| Six build/verification/hook scripts, bash -n | All passed | syntax only; no workflow invoked |

SwiftPM scratch, cache, configuration, security and module-cache paths plus TMPDIR were redirected inside audit. Commands used --disable-keychain and --disable-netrc. --disable-sandbox is the SwiftPM subprocess option, not an escalation of the task's filesystem permissions. Only focused suites were run: the full local gate would generate projects/build trees outside audit, launch app-hosted tests, and may touch app settings. The PowerPoint helper was not run against the real application because its global close command discards open work.

The standalone Swift probe links the audit-built Rostrum.o and LecternCore.o. To reproduce, build LecternCore with the paths above, then compile probe.swift with -I pointing to its Products/Debug directory and both object files. Run with an output directory inside audit. The first compilation attempted an inaccessible parts setter; the probe was corrected to the public removePart(at:) API. That was an audit harness error, not a project finding.

## Candidate disposition

| Candidate | Disposition |
|---|---|
| P1 scope ambiguity | Confirmed: root rules versus Lectern/Package.swift:17–22 and conditional Apple imports in DeckRenderer.swift:3–9. Do not loosen Rostrum itself. |
| P2 CI conflict | Confirmed, including global cost requirement at ~/.claude/CLAUDE.md:33. Requires owner choice about existing exceptions; code is evidence of behavior, not evidence the budget policy was revoked. |
| P3 incomplete completion route / signing bypass | Confirmed: root swift test excludes Lectern packages/app tests; README direct xcodebuild omits wrapper signing behavior. |
| P4 stale status | Confirmed: DeckLibrary/AppState implement history; PriceTable is used; cancel button exists. Retain actual unresolved provider features and test gaps. |
| P5 architecture drift | Confirmed: ZipWriter calls Deflate; Slides only has index access; generator emits schema tables. No CT_Foo+Manual.swift or exclusions manifest exists. |
| P6 overclaimed acceptance | Confirmed with missing-part probe. This is a limits-of-validation finding; it does not require claiming a live PowerPoint repair was observed. |
| P7 duplicated numeric prompt rules | Confirmed direct text conflict. Validator intentionally warns at >12 words and outside ±20%; do not silently tighten it as cleanup. |
| P8 request context loss | Confirmed both provider paths and runtime strings. Renderer independently honors notesEnabled=false, so final notes leakage is NOT claimed. Fabricated output was NOT measured. |
| P9 editorial contradictions/boosters | Text conflict confirmed; model-quality/latency improvements remain hypotheses requiring paired evaluation. |
| P10 missing image helper | Confirmed absent from tracked project. Historical helper may exist elsewhere; no claim of repeated manual user work. Recommend input documentation, not an unrequested paid generator. |
| P11 security assurance overstatement | Confirmed: delimiter tests only inspect strings. Preserve boundaries; no claim of a demonstrated model exploit. |
| P12 published example drift | Confirmed warning, not a compile failure. The CI copy already uses the modern API. |
| P13 stale iOS comment | Confirmed versus build-ios.sh:13–14. |
| P14 destructive/non-failing oracle | Confirmed source plus stubbed exit-code reproduction. Never exercised destructive action on real documents. |
| P15 global emphasis | Recorded as optional wording observation only; global cleanup excluded from project recommendations. Preserve all requirements. |
| S1 fixed preview ratio | Confirmed code and SVG dimension mismatch; live UI visual inspection deferred to approved implementation. |
| S2 compacted preview identity | Confirmed runtime inspection output and UI index-based labels. |
| S3 title/identity research | Preserve semantic versus inferred title distinction. No new title inference feature proposed. |
| S4 missing inherited-background API | Resolved: BackgroundResolver.swift exposes slide/layout/master APIs; selected tests pass. Dropped as a product defect. |

## Historical observations dropped

- Missing generation cancellation: current ContentView.swift:564 invokes AppState.cancel(); RunGate abandons stale runs. Only the stale ROADMAP sentence remains actionable.
- History as a stub / missing price estimate: current implementation exists; only documentation needs correction.
- DeckRenderer entirely untested: renderer tests exist and a focused rendered-title test passed. No conclusion that KeychainStore or SlideRasterizer coverage is adequate.
- Public background inheritance missing: resolved by Aug 26–27 commits and verified with current tests.
- Old CI failure notifications: not evidence of present failures; no remote CI status claimed.
- Style prose bloating every LLM request: false premise. Metadata/token extraction is active; full style prose does not reach the content model. Keep the 150 styles.
- The README snippet fails compilation: disproved; it currently compiles with a deprecation warning.

No runtime claim is made for Linux, iOS, the live app, all 150 rendered styles, or PowerPoint acceptance during this audit. Those are explicit implementation-test requirements where relevant.

## Final integrity check

All 551 tracked file hashes match the pre-audit baseline; Git status shows only audit/ as untracked. See logs/project-integrity.json. Audit-created build/cache trees and their copied fixture resources were removed after checks; logs, synthetic reproductions and source probes remain. Workflow stub reproduction is saved in reproduce-workflows.py. No project changes or global instruction edits were made.
