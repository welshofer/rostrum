# Isolated Lectern inspection race correction — 2026-10-02

Current integrated status: [October 2 implementation and verification](IMPLEMENTATION-20261002.md).
The checkpoint details below remain historical evidence.

This is an additive follow-up to the clean, preserved stage-four commit
`f931ae1379b7d9f5058a717601c6cf4a86b9a0e1`. Its existing reports, archives and
handoff manifest remain unchanged. The original checkout and PowerPoint session
remain untouched; integration and publication have not occurred.

## Corrected behavior

Inspection cancellation is cooperative. A final synchronous render can finish
after Cancel or a replacement request, and its result, failure or already
queued progress could previously overwrite the current screen. The same race
was reachable by choosing New Deck while inspection was running.

AppState now gives each inspection a separate RunGate identity. Success, failure
and progress check that identity on the main actor at publication. Replacement,
Cancel, Home and New Deck invalidate the previous identity. Accepted completion
retires it before publishing the final state, so delayed progress cannot change
terminal status. An obsolete completion cannot clear a newer task's handle.
Direct cancellation of the returned task also suppresses progress/results and
retires the current request, including when the operation throws CancellationError.

Inspection stays detached, with security-scoped access held through the work.
Generation's gate, the renderer, caches, diagnostics payload and slide mapping
are unchanged. An injected operation and completion handle make the actual
AppState behavior testable; an optional defaults argument isolates test settings
while preserving the application's default preferences behavior.

## Deterministic verification

Eight Swift Testing tests cover **fifteen cases** using controlled continuations
and awaited progress delivery, with no timing sleeps:

- Old success and old failure before a replacement completes, including proof
  that the replacement still receives cancellation through its retained handle.
- Replacement completion before old success/failure, retaining the replacement's
  previews, original slide numbers and fidelity diagnostics.
- Cancel without replacement followed by late progress and success/failure.
- Late progress after accepted terminal success/failure.
- Home and New Deck while work is suspended.
- The default production operation still inspecting a real deck correctly.
- Direct task cancellation followed by success, generic failure or
  CancellationError, plus cancellation raised by the current operation itself.

The headless runner copies every app Swift source unchanged except the SwiftUI
application entry point into a scratch library. Tests construct AppState with
Keychain disabled and a unique defaults suite; they never call application
startup or deck migration/pruning. The initial candidate passed six tests /
eleven cases in **0.271 seconds**. Subsequent independent review identified the
direct-task cancellation gap, which was fixed with four further cases after
the build/test approval rejection. **The final eight-test / fifteen-case source
has not been compiled or executed.** Its source hashes are distinguished from
the earlier passing candidate in the
[verification record](benchmarks/2026-10-02-stage5-verification.json).

Before the direct-cancellation addition, a negative control removed only the
three publication guards from the scratch
AppState copy. Five tests then failed with 31 recorded issues; the normal
default-operation test still passed. Restoring that candidate source
and rebuilding the harness returned the original six-test suite to passing. This demonstrates
regression sensitivity; it is not a test of the unmodified historical commit.
The timing of the production adapter's task scheduling is not itself controlled;
the tests drive delayed events at the actual publication callback boundary.

Two independent reviewers checked the final lifecycle, tests and harness and
reported no remaining actionable findings. This was static review only.

## Build limitations and ownership

The headless run compiles the real macOS app source files except its application
entry point, but it does not establish an Xcode application/test-bundle build,
hosted-app execution, UI performance or iOS compilation.

The sandboxed Xcode build-for-testing stopped during package resolution because
module-cache output and Xcode service access were unavailable. An escalation
request was rejected by automatic approval review, which cited the initial
read-only instruction prohibiting builds/tests. No retry or alternative route
was attempted after that rejection. iOS compilation was not attempted after
the rejection. Further test execution and platform checks need direct approval; prior stage-four
app-build success must not be presented as verification of this new AppState.

No unchanged renderer benchmarks or library suites were repeated. The stage-four
performance evidence remains intact, and the native visual gate remains open at
2.152619% differing pixels versus its unchanged 0.5% limit. The separate handoff
approval question is preserved, with no further messaging attempts.
