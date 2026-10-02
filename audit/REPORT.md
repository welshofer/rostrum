Rostrum and Lectern are slowed by conflicting instructions, stale documentation, and gaps between prompts and verification tools.<br>
Focused verification passed 42 Lectern tests and 41 Rostrum tests; several important workflow defects still reproduced.<br>
The best quick wins are a clear development entry point, accurate implementation status, and checking the actual published examples.<br>
The highest-impact fixes preserve request context through repair/editing and make the PowerPoint oracle safe and reliable.<br>
Only audit/ was changed; implementation is stopped pending approval of specific items below.

# Rostrum + Lectern project audit

**Snapshot:** f056474, 2026-09-24. Estimates are approximate implementation effort, not measured savings. Items are ordered with useful quick wins first, followed by behavior changes. CI policy requires an explicit owner decision and is listed separately.

| ID | Proposed change | Expected impact | Effort |
|---|---|---|---|
| R1 | Clarify library/app scope and route agents to the real local gate | High: avoids wrong constraints and incomplete checks | 1–2 hours |
| R2 | Correct architecture, status, signing, and validation claims | High: prevents rediscovering completed work and relying on false guarantees | 2–3 hours |
| R3 | Verify published README snippets instead of only a separate copy | Medium: prevents example drift | 1–2 hours |
| R4 | Carry the original request contract through draft, repair, and editing | High: restores grounding and user intent across paid stages | ½–1 day |
| R5 | Make the PowerPoint oracle non-destructive and fail on failures | High: protects open work and makes acceptance results actionable | ½–1 day |
| R6 | Make all app build wrappers refresh the generated project consistently | Medium/high: removes fresh-checkout and stale-project surprises | ½ day |
| R7 | Preserve original slide identity when previews fail | Medium: fixes incorrect numbering and accessibility labels | ½ day |
| R8 | Carry the deck's actual aspect ratio into previews | Medium: fixes clipped non-widescreen previews | ½–1 day |
| R9 | Consolidate contradictory editorial rules and make them goal-aware | Medium; quality benefit needs evaluation | ½ day plus evaluation |
| R10 | Document the supported illustrated-example workflow | Low: removes a dead-end helper reference | 30–60 minutes |
| D1 | Resolve the conflict between the CI cost policy and existing macOS jobs | High policy clarity; requires owner choice | Decision, then a scoped change |

## R1 — Make the root instructions usable for both projects

**Problem and evidence.** CLAUDE.md:13–17 says “No SwiftPM dependencies, ever” and “Foundation … is the only import.” Those are Rostrum rules, but a root agent also works on Lectern, whose Package.swift:17–22 intentionally depends on local Rostrum and whose renderer conditionally imports Apple frameworks. CLAUDE.md:36 says “Run `swift test` before declaring anything done”; .github/PULL_REQUEST_TEMPLATE.md:7 also emphasizes package tests. The root package does not include LecternCore or AppTests. Lectern/README.md:128–130 recommends direct xcodebuild, bypassing the stable-signing wrapper.

**Proposed change.** Add a short scope/build map to CLAUDE.md: Rostrum remains dependency-free and portable; LecternCore uses local Rostrum plus guarded platform APIs; app targets use SwiftUI. Point contributors and the PR checklist to scripts/verify.sh, clearly naming what --fast omits. Recommend Lectern/scripts/build.sh for macOS builds. Link to CONTRIBUTING for detail rather than repeat the whole gate. Preserve attribution, layer boundaries, deterministic output, payload preservation, and credential rules.

**Affects/test.** Instruction files and build documentation only. Check every documented command against the scripts; after approval run the relevant package suites and the full local gate for app work. Verify build/test wrappers retain the same signing identity behavior. No dependency or platform change is proposed.

## R2 — Make current documentation describe the current implementation

**Problem and evidence.** Confirmed examples:

- docs/ARCHITECTURE.md:35–39 describes generated typed wrappers and a “deterministic STORED writer”; :65–66 describes CT_Foo+Manual.swift and an exclusions manifest that do not exist; :89–91 describes slide-ID subscripts, but Slides.swift:31 exposes positional Int access. ZipWriter.swift:97 already calls Deflate.
- Lectern/README.md:230–232 calls history “currently a stub” and lists the price estimate as remaining work. AppState.swift:121 loads DeckLibrary and :694 uses PriceTable. The pipeline description also omits the existing QA, normalization, and illustration stages.
- ROADMAP.md:439–440 claims DeckRenderer has no tests, despite RenderedDeckTitlesTests and renderer tests in LecternCoreTests. :448–449 says there is no generation cancel affordance; ContentView.swift:564 already has one. Update those entries without discarding the rest of the recorded deferrals.
- Lectern/project.yml:110–111 says simulator builds use CODE_SIGNING_ALLOWED=NO; build-ios.sh:13–14 uses ad-hoc signing and an entitlement shim.
- README.md:100, docs/COOKBOOK.md:122 and Tools/pptx-tool/main.swift:6 describe validation as a “PowerPoint will accept this” check. A synthetic deck with its middle slide part missing returned exit 0 and “no schema issues.” The library's Validation.swift:12–15 correctly calls this a required-attribute lint, not full validation.

**Proposed change.** Correct these statements and distinguish implemented APIs, future architecture, historical observations, and remaining limitations. Describe the CLI as modeled structural lint; keep real PowerPoint acceptance as a separate gate. Do not add missing APIs merely to make old prose true. Preserve security/provenance and historical reasons for rejected approaches.

**Affects/test.** Listed docs/comments only. Cross-check each API and stage against source, run existing schema/deflate/background/title tests, and check that the validator documentation accurately explains the supplied counterexample. No new broad test suite is needed for wording changes.

## R3 — Stop the README verification copy drifting from the README

**Problem and evidence.** README.md:27 uses add(layout:), while Examples/ReadmeSnippets/main.swift:29 uses add(clonedFrom:). Typechecking the actual README snippet succeeds with a deprecation warning. The gate currently compiles the independently maintained copy, so “docs can't rot” is stronger than what it verifies. This is not a compilation failure today.

**Proposed change.** Update the published label and make the small set of runnable README examples derive from one source: extract designated runnable blocks or generate those blocks from the executable examples. Keep installation fragments and intentional pseudocode outside the executable set.

**Affects/test.** README and the existing snippet workflow. Compile/run the extracted examples into a temporary directory; deliberately introduce a bad API label in an isolated test fixture and confirm the gate fails. Check the emitted decks with the existing structural checks and the repaired PowerPoint oracle when available. Preserve the example content.

## R4 — Preserve request constraints in every model stage

**Problem and evidence.** PromptTemplates.swift:99–112 adds grounding, count and notes preferences only to the initial user prompt. OpenAIProvider.swift:48–49 and AnthropicProvider.swift:65–66 replace it with RepairPrompt on repair. The editor user prompt at :226–236 includes topic/audience/goal and draft JSON, but no original source or notes toggle. Runtime assembly confirmed source present in draft, absent from repair/editor; repair also loses the original topic. The editor asks for concrete statistics and notes without the corresponding original constraints. Quality editing is enabled by default in DeckGenerator.swift:18.

**Proposed change.** Assemble a shared request contract for draft, repair and editor: topic, audience, goal, count target, notes preference, and grounding treated as data. Keep untrusted source and draft/error text explicitly separate from instructions. In grounded mode require supported facts, not invented rounded figures. Correct claims at PromptTemplates.swift:115–129 and PromptSafetyTests.swift:29–40 that deterministic delimiters make model obedience impossible; retain the actual boundary protection.

**Affects/test.** PromptTemplates, RepairPrompt and both provider request builders. Add offline transport-capture tests for all three stages and both providers, with unique source markers, hostile-looking source text, notes on/off, and distinct count/goal values. Run the fixture generation/repair/QA flow and inspect generated notes and content. Use a small paired live sample only as an explicitly authorized evaluation, not as proof provided by this audit.

**Limits.** The renderer already honors notesEnabled=false, so this report does not claim exported notes leak when disabled. No live fabricated fact or prompt-injection exploit was demonstrated; the verified defect is missing context in outbound prompts.

## R5 — Repair the acceptance oracle before relying on it

**Problem and evidence.** Tools/ppt-check.sh:7 executes “close every presentation saving no.” That can discard unrelated open work. Lines 41–46 print OK/REPAIR/STUCK without setting failure exit codes. With osascript/open replaced by audit-only stubs, repair dialog, repaired title and timeout all returned exit 0. The script also accepts the first open presentation rather than confirming the requested file's identity.

**Proposed change.** Validate the input; identify and observe only the target presentation; never close unrelated documents; close only a target the helper opened and owns. Return documented nonzero codes for repair, timeout, automation errors and invalid input. Preserve LaunchServices opening, which is the project's intentional strict-acceptance path. Combine this with the honest structural-lint wording in R2.

**Affects/test.** Tools/ppt-check.sh and its usage docs. Exercise every result with stubs first. Then use a disposable PowerPoint session with a saved sentinel presentation open: confirm it remains open and unchanged while a separate good deck succeeds, an appropriate repair fixture fails, and a missing path fails. Do not use unsaved real work as the sentinel. Inspect the visible result, not just the exit code. The current helper was never run against real PowerPoint during this audit.

## R6 — Make project.yml reliably drive every app build

**Problem and evidence.** build.sh:15–21 generates only when Lectern.xcodeproj is absent; build-ios.sh never generates; test-app.sh generates every time. In an audit-only copy with command stubs, a fresh direct iOS build failed for a missing project, while two macOS invocations generated only once. A changed project.yml can therefore be ignored by the first two paths until the test path refreshes it. README documents a manual generation step, so the fresh iOS failure is an inconsistent wrapper contract, not a failure of that documented sequence.

**Proposed change.** Share a small project-generation prerequisite across all three wrappers, or regenerate consistently before each build/test. Give the same actionable xcodegen-missing error. Preserve macOS stable-signing configuration, iOS ad-hoc entitlements and device-signing rules.

**Affects/test.** Three Lectern scripts, optionally one shared helper. Test absent and existing project cases in isolated copies, including changing a harmless generated setting and verifying it reaches the project. Then run macOS build, simulator build and app-hosted tests; inspect a sample launch and key-presence behavior without exposing credentials.

## R7 — Keep preview identity when a slide cannot render

**Problem and evidence.** DeckInspection.swift:176–190 appends only successfully rendered slides. Titles stay aligned with those previews, but original slide numbers are lost. SlidePreview.swift:147–175 labels the compacted array with index+1 and previews.count. The audit fixture has three slides; removing slide 2's part yields previews titled First and Third. The UI logic calls Third “Slide 2 of 2.” This confirms the Aug 25 research concern against today's code.

**Proposed change.** Carry original slide number/identity in preview records, including a failed-preview placeholder or explicit failure state. Use original numbering and deck count for visible badges and accessibility. Preserve best-effort inspection of the remaining deck.

**Affects/test.** Inspection value types and contact-sheet/filmstrip consumers. Add a malformed-middle-slide regression using the synthetic fixture; assert stable numbering and a surfaced failure. Run inspection/app tests, open the fixture in Lectern after approval, and inspect visible order and VoiceOver labels. Ensure generated complete decks retain their existing numbering.

## R8 — Render previews at the deck's aspect ratio

**Problem and evidence.** SlideRasterizer.swift:140 fixes height to width×9/16; SlidePreview.swift:149 fixes contact-sheet ratio, and :190 fixes filmstrip size to 240×135. A 4:3 deck emits a 640×480 SVG, while the rasterizer allocates only 640×360. Its HTML scales width and hides overflow, so the bottom cannot fit. This also matches the Aug 25 reuse survey.

**Proposed change.** Carry numeric slide dimensions or validated SVG viewBox dimensions through the preview model, cache key, snapshot viewport and UI tile sizing. Retain intentional image fitting and do not infer all decks are 16:9.

**Affects/test.** Rasterizer, preview views and inspection metadata. Test 16:9, 4:3 and portrait fixtures with visible corner markers and labels. Verify snapshot dimensions and cache separation. Open Lectern and inspect contact sheet/filmstrip at multiple sizes; require all four corners visible without distortion. This audit confirmed the dimension mismatch, not a live UI screenshot.

## R9 — Consolidate the editorial contract without erasing design intent

**Problem and evidence.** PromptTemplates.swift:24–25 says “≤10 words each,” :70–71 says “at most 12 words each,” :102 says “exactly … (±1),” and :220–221 says “roughly.” :16–18 mandates argument for every deck, while :255 asks for neutral clarity when the goal is inform. “Fix every weakness” and “HARD CAP … about” add force without resolving those differences. Draft/editor duplicate much of the same rubric.

**Proposed change.** Separate hard output structure, readability targets, goal-specific narrative, and preferences. For example: “Aim for 10 words per bullet; maximum 12,” and “Target N slides, within one.” Share goal-aware wording between stages. Keep the existing validator's ±20% warning threshold and normalization semantics unless a separate behavior change is approved. Retain layout variety, useful assertion-title examples, image-role guidance and factual constraints. Do not delete the 150 styles: full style prose is not sent to the content model.

**Affects/test.** Prompt wording/shared constants and contract tests. Compare assembled contracts across inform/persuade/entertain/inspire, short/long decks, and notes modes. Use fixed drafts to exercise editor/normalizer behavior, then inspect paired deck outputs for goal fit, factual support, layout variety and clipping. Reduced text alone is not a success metric; no measured latency or quality gain is claimed yet.

## R10 — Remove the dead end in the illustrated-example instructions

**Problem and evidence.** Tools/gen_images.py.md:3–7 says the helper “lives in the session scratchpad (not committed)” and that cached reruns “are free.” No generator source ships in the repository. The Sunflower example supports supplied images, but its helper cannot be reproduced from a fresh checkout. Available histories do not prove how often anyone recreated it manually.

**Proposed change.** Document required filenames/sizes and the supported existing-images workflow. Mark the historical helper as unavailable rather than imply it ships. Say matching cache hits avoid calls; new calls may cost money. Recovering or creating a paid-image generator would be a separate approved item.

**Affects/test.** Tool/example docs. Run SunflowerDeck with a small local synthetic image set and inspect its deck output; verify the instructions work in a fresh checkout without missing scratch files or credentials.

## D1 — Preserve the CI cost requirement while resolving conflicting authority

**Problem and evidence.** Global ~/.claude/CLAUDE.md:33 says “Never add macOS hosted-runner CI jobs to my repos” and “Keep CI to cheap Linux jobs only.” CONTRIBUTING.md:57, scripts/verify.sh:3, scripts/hooks/pre-push:4 and Lectern/scripts/test-app.sh:13 repeat this policy. Yet .github/workflows/ci.yml:78–93 runs a macOS PR job, and docs.yml:24–33 uses macOS on main for documentation. Lectern/README.md:189–193 describes the PR exception. Existing code does not establish which policy the owner intended to supersede.

**Proposed decision.** Confirm whether those two existing jobs are approved exceptions or whether the Linux-only policy should govern them too. Until then, preserve the cost rule, do not add jobs, and do not silently remove checks or publishing. After the decision, record a short project-specific policy in one place and reconcile contradictory comments. Global instruction edits need separate explicit approval.

**Affects/test.** Only the docs/workflows specifically approved. If jobs change, validate workflow syntax and demonstrate that the intended local Apple checks and documentation publication still have a working path. A policy-only reconciliation needs a read-back of all affected instructions. No remote Actions settings were read or changed in this audit.

## Evidence, coverage, and exclusions

- [Inventory](inventory.md): 167 project Markdown documents, including 150 bundled styles; developer guidance, plans, templates, embedded prompts, executable workflows and global instruction discovery.
- [Prompt audit](prompt-audit.md): exact excerpts, locations, rationale and rewrites; [style review](style-review.md) records the full-file structural scan. Runtime consumers were traced; this was not a visual audit of 150 rendered styles.
- [Session notes](session-notes.md): no dedicated prior Rostrum/Lectern cwd conversation was found in local Claude/Codex stores or the read-only Codex index. Related Aug 25–26 downstream technical research was reviewed in batches. It cannot substantiate repeated owner corrections or frequencies of manual work.
- [Verification](verification.md): current checks, logs, limits, and disposition of candidates. The local corpus includes ignored fixture decks; results are not a clean-clone or CI claim.
- Resolved product issues were dropped: inherited-background APIs, cancellation, persisted history, and the assertion that DeckRenderer has no tests. Some stale documentation describing them remains in R2. Old CI notifications, downstream-only pricing/cache suggestions, and speculative title inference changes were excluded.

The full local gate, app-hosted UI tests, Linux/iOS execution, live provider calls and actual PowerPoint acceptance were not run. These would exceed the current read-only boundary or require interactions beyond the audit. Existing business, security, legal, provenance and privacy requirements remain intact.

## Approval boundary

Approve specific R-items to implement; D1 needs the policy choice above. All 551 tracked file hashes match the baseline. No global policy, provider behavior, build script, source file or project instruction has been changed. On approval, each item will be changed and tested separately, with its exact diff shown before the next item. A change that cannot pass its agreed checks will be reverted. Durable decisions and an audit/CHANGELOG.md will be added only after approved implementation.
