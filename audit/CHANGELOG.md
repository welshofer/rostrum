# Approved audit implementation

Updated 2026-10-01. The owner approved all recommended R-items after the report,
then reaffirmed high performance, high fidelity, and inclusion of Lectern.
The initial [REPORT](REPORT.md) remains the historical read-only audit; its
approval boundary and original test exclusions describe that earlier phase.
During implementation, no commits, publishing, paid model/image calls, global
instruction edits, remote Actions settings or changes to the two disputed macOS
CI jobs were made. On 2026-10-02 the owner explicitly requested staging, committing
and pushing these changes; the repository publication is authorized separately.
Generated scratch is excluded as described in [README.md](README.md).

## Changes and evidence

| Item | Implemented change | Verification | Exact incremental diff |
| --- | --- | --- | --- |
| R1 | Distinguish portable Rostrum, LecternCore and native app scope; document the full gate and stable signing | Commands traced to scripts; final package/build/app checks below | [R1](diffs/R1.patch) |
| R2 | Correct stale architecture, history, pricing, cancellation and signing descriptions; distinguish structural lint from PowerPoint acceptance | 36 focused tests; current API/flow review; malformed-part counterexample retained | [R2](diffs/R2.patch) |
| R3 | Generate runnable README blocks from the executable examples; check drift in Linux CI and the local gate | Good examples compile/run and pass PowerPoint opening; isolated bad-label fixture rejected | [R3](diffs/R3.patch) |
| R4 | Share original topic/audience/goal/count/notes/source through draft, repair and editor; fence source, draft and errors as data | Both providers' outbound requests captured offline; notes modes and hostile-looking source markers covered; full core suite passed | [R4](diffs/R4.patch) |
| R5 | PowerPoint helper checks an owned copy by exact path, preserves unrelated work and returns meaningful exit codes | Offline result/ownership checks; live good, rejected-middle and missing input checks; saved sentinel preserved | [R5](diffs/R5.patch), [dialog follow-up](diffs/R5-followup.patch) |
| R6 | Regenerate XcodeGen project from project.yml through one shared prerequisite in all wrappers | Isolated fresh/existing/changed project tests; signing arguments and missing-tool diagnostic checked; both app builds and app tests passed | [R6](diffs/R6.patch) |
| R7 | Preserve original preview slots, slide numbers and accessibility labels; show failure placeholders | Malformed-middle core and app-state regressions; actual contact-sheet capture visually inspected | [R7](diffs/R7.patch) |
| R8 | Carry slide dimensions into preview geometry, tile layout, snapshot viewport and cache key | Real WebKit snapshots at 320/640 wide for three ratios; all corner colors and dimensions checked; contact sheet/filmstrip inspected at 720/1000 wide; three PowerPoint fixtures accepted | [R8](diffs/R8.patch) |
| R9 | Shared goal-aware editorial guidance; consistent bullet and count targets; preserve layout/image/factual guidance | Inform/persuade/entertain/inspire, 3/24 slides, notes modes and grounding checked; fixed-fixture QA/repair/normalizer tests passed | [R9](diffs/R9.patch) |
| R10 | Replace missing scratch-helper instructions with supplied PNG filenames, frame proportions, suggested sizes and honest cost/provenance guidance | Clean-checkout example generated 30 slides; all 13 PNGs preserved exactly; ZIP/structural/native-open checks passed. Final manual PowerPoint visual review pending unlocked Mac | [R10](diffs/R10.patch) |
| Performance | Add Release open/serialize/SVG benchmark with strict part-payload, deterministic-save and reopened-SVG checks | Three fixture classes passed; invalid input, iteration bounds and overwrite refusal checked; macOS peak RSS captured | [Performance](diffs/Performance.patch) |
| Learnings | Record prompt/preview/performance contracts; link reproducible checks in Lectern and contributor docs; add workflow regressions to the gate and clarify --fast | Shell syntax, README sync and four workflow tests passed; final checks below | [Learnings](diffs/Learnings.patch) |

## Final checks

- Rostrum: 700 tests in 85 suites passed in the final gate attempt. Its corpus
  includes locally supplied foreign-authored presentations. This is a local
  result, not a clean-clone corpus or Linux CI result.
- LecternCore: 168 tests in 16 suites passed after the prompt/preview changes.
- macOS app build and iOS simulator build passed using the stable-signing wrappers.
- Lectern app-hosted tests: 32 passed, 0 failed, 0 skipped; see the
  [final summary](implementation-logs/final-app-summary.json).
- Four offline acceptance/build-wrapper tests passed; README blocks match their
  source and the examples compile/run. Shell syntax and whitespace checks passed.
- [Performance baseline](PERFORMANCE.md): 100-slide synthetic median open 8.54 ms,
  serialization 5.78 ms, first all-slide SVG pass 23.75 ms; image-heavy input opens
  in 33.24 ms. These establish baselines, not before/after speedup claims.

The full-gate script was edited to add workflow checks while an invocation was
running. After its successful 700-test run, the shell unintentionally repeated
the library stage because its input file had changed. Only the duplicate runner
and its parent gate shell were terminated. All remaining stages were then run
successfully from the fixed [remaining-checks script](final-remaining-checks.sh).
The combined checks cover the gate, but no uninterrupted final `verify.sh`
exit-zero is claimed. Logs: [root pass](implementation-logs/final-verify.log),
[remaining stages](implementation-logs/final-remaining.log),
[workflow tests](implementation-logs/final-workflows.log).

## Verification limits and deferred decisions

- D1 remains an owner policy decision: global Linux-only CI instructions conflict
  with existing macOS PR and documentation jobs. Asking for ramifications did not
  select a policy. Those jobs and the disputed statements were preserved; R3
  only added README drift checking to the existing Linux job. No silent policy
  exception or removal of validation/publication was made.
- The desktop became locked. Computer Use could not unlock it; the owner was
  asked to unlock it while independent work continued. Final live PowerPoint
  visual comparison and VoiceOver navigation remain unverified. Earlier actual
  Lectern view captures and successful native-open checks are separately recorded.
- The benchmark round-trip native-open follow-up timed out on the small deck,
  so the loop did not check the other two. The private copy is retained as noted
  in PERFORMANCE.md. The timeout is not classified as a format defect.
- No live provider content-quality or latency comparison was performed. Offline
  tests prove request assembly and deterministic flow, not model obedience or
  improved writing. Validator count-warning thresholds and normalization
  semantics were deliberately left unchanged.
- No hardware iOS or live Linux run was performed. iOS simulator compilation and
  the portable package tests are distinct from those checks.

## Resolved test-harness problems

The first app accessibility traversal was unreliable and was replaced with
app-state identity assertions plus production-view capture; no VoiceOver pass is
claimed. Earlier snapshot harness frame/compile issues were fixed before the
passing app runs. The first core suite's sandbox-only Trash failure passed with
normal filesystem access. PowerPoint's unrelated hidden AXDialog windows caused
false positives until detection was scoped to the exact target document URL.
The isolated wrapper fixture needed both dirname and bash on PATH. These were
harness corrections, not reasons to weaken production requirements.

No approved product change was left with a known failing regression test. No
library algorithm was changed merely to chase an unmeasured optimization.
Generated Python bytecode from these checks was removed; user work was preserved.

## 2026-10-02 — Template-aware composition implementation

Added Rostrum POTX instantiation, placeholder filling/replacement, relationship-chain
validation and design.md master/layout publishing. Added the separate RostrumLayout
product for inherited-template fitting and authored-slide fit/publishing. Lectern now
imports template snapshots, selects masters, carries template constraints through its
generation stages and uses native content regions. Header spacing, bullet indents and
photo-background text contrast were corrected for authored decks.

Used the supplied welshofer.potx in offline end-to-end generation and enrolled an
unchanged copy in the ignored local corpus. Its custom body-placeholder cover and
subtitle conventions produced two additional regression tests. See
`template-acceptance/README.md` for exact evidence and unresolved acceptance.

Native PowerPoint and live picker inspection remain blocked by the locked Mac.
No current generation was interrupted, no original deck/template was overwritten,
and no commit/push was performed. Diagram-style template fallback and missing fonts
are disclosed; this entry does not claim complete visual fidelity or full feature parity.

## 2026-10-02 — Fix the inert template picker

Reproduced the live failure: Use PowerPoint template produced no picker, while
Choose PDF opened one. ComposeView attached two fileImporter modifiers to the same
view; the later PDF presenter suppressed the template presenter. Replaced them
with one presenter and an explicit template/PDF purpose retained through completion.

Rebuilt and launched the signed macOS app. In the actual running app, clicked the
template button, selected Desktop/welshofer.potx, clicked Open, and observed
“welshofer PowerPoint template · 34 layouts”. Then opened/cancelled the PDF picker,
reopened/cancelled the template picker, and verified the selection remained intact.
Both macOS and iOS simulator builds passed. No presentation generation was started.
The app remains open with the Welshofer template selected.

The earlier check proved only button visibility, not its action. Picker acceptance
must exercise click → open dialog → select file → confirm loaded state, plus cancel
and reopening after a different picker purpose.
