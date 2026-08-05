# Burn-Down: Rostrum 0.4 + Lectern Deck Workbench

> Approved direction: stop arbitrary template application; release the proven
> Rostrum work, then make Lectern exercise Rostrum's read and
> structure-preserving edit surface against real decks.
>
> Integration branch: `burndown/deck-workbench-20260805`

## Preflight

- Working tree: clean `main`, synchronized with `origin/main`.
- Remote: `git@github.com:welshofer/rostrum.git`.
- Backend/deploy surface: none. This run builds native apps and a Swift
  library; deploy is not applicable.
- Orchestrator: GPT-5.6 Sol. The burn-down skill is calibrated for Fable; the
  user's explicit “Do not stop” authorized proceeding on the current model.
- `CLAUDE_CODE_SUBAGENT_MODEL`: unset.
- Worktree isolation: not exposed by the agent API. Manual git worktrees are
  used where items are disjoint; items sharing `AppState`, the workbench actor,
  or inspector views are serialized.

### Definition of Done

```text
build: Lectern/scripts/build.sh -quiet && Lectern/scripts/build-ios.sh -quiet
test:  swift test && (cd Lectern && swift test) && swift run ReadmeSnippets "$(mktemp -d)"
lint:  not configured
gate:  ./scripts/verify.sh
```

The repository defines no linter. `scripts/verify.sh` is the canonical gate and
runs both Swift test suites, the executable documentation, and both app builds.

## Scope

### REL-0 — Close the stale image-layout PR

- **Location:** GitHub PR #14.
- **Proof:** PR #14 was open, stale since 2026-07-29, and conflicting with
  `main`.
- **Do:** Close it; any useful crop behavior must return as a narrow,
  independently-proven change.
- **Status:** shipped — PR #14 closed.

### FUNC-1 — Build the deck workbench core

- **Location:** `Lectern/App/AppState.swift:17-21`,
  `Lectern/Sources/LecternCore/Rendering/DeckRenderer.swift:1-80`.
- **Proof:** `AppState.Phase` has only compose/generating/result/failed, and
  `DeckRenderer` only turns generated `DeckIR` into a new presentation. No
  production code opens an arbitrary user deck.
- **Do:** Add a `DeckWorkbench` actor and Sendable inspection snapshot that
  opens `.pptx`/`.potx`/`.ppsx`, renders contact-sheet previews, and extracts
  document properties, slide/layout/master identity, fonts, charts, notes,
  comments, sections, media, shape counts, and validation issues.
- **Lane:** fable/orchestrator — architecture-defining actor + Sendable model.
- **Effort/impact:** L/L.

### USE-1 — Build the Open Deck inspector UI

- **Location:** `Lectern/App/ContentView.swift:31-40`,
  `Lectern/App/DeckLibrarySheet.swift:22-54`,
  `Lectern/App/LecternApp.swift:116-145`.
- **Proof:** the phase switch has no inspector; the library only opens,
  reveals, and deletes generated files; File → Open Deck does not exist.
- **Do:** Add one PowerPoint file importer, menu/toolbar entry points, loading
  and failure states, a contact sheet, and deck/slide details. Keep the first
  slice read-only.
- **Lane:** fable/orchestrator — shared app state and cross-platform SwiftUI.
- **Effort/impact:** L/L.

### STAB-1 — Add a local UI smoke test

- **Location:** `Lectern/project.yml:1-81`.
- **Proof:** only application targets are declared; no UI-test target exists.
- **Do:** Add a macOS XCUITest that launches with a generated fixture and
  proves the inspector is reachable and shows the deck.
- **Lane:** opus — bounded multi-file test harness.
- **Effort/impact:** M/L.

### FUNC-2 — Add safe slide edits and save-as-copy

- **Location:** `Sources/Rostrum/Presentation/Slides.swift:68-144`,
  `Lectern/App/DeckLibrarySheet.swift:104-151`.
- **Proof:** Rostrum already has remove/move/duplicate, but Lectern exposes none
  of them and has no workbench save path.
- **Do:** Expose reorder, duplicate, delete, undo-by-reload, and deterministic
  save-as-copy from the inspector. Never overwrite the source.
- **Lane:** fable/orchestrator — mutable actor state + app flow.
- **Effort/impact:** L/L.

### FUNC-3 — Add formatting-preserving text, notes, and metadata edits

- **Location:** `Sources/Rostrum/Presentation/Notes.swift:5-36`,
  `Sources/Rostrum/Presentation/DocumentProperties.swift`,
  `Sources/Rostrum/Presentation/Text.swift`.
- **Proof:** Rostrum can edit these structures, but Lectern exposes none of
  them. Text replacement must operate on existing runs rather than rebuild
  shapes.
- **Do:** Add find/replace across existing runs, notes editing, and document
  property editing; save only to a copy.
- **Lane:** opus — well-specified edit surface after workbench core exists.
- **Effort/impact:** M/L.

### FUNC-4 — Add safe chart-data editing

- **Location:** `Sources/Rostrum/Charts/ChartReader.swift:252-289`.
- **Proof:** `replaceData` and its refusal model exist, but no app calls them.
- **Do:** Inspect categories/series, edit values without structural change,
  surface refusal reasons before mutation, and save to a copy.
- **Lane:** opus.
- **Effort/impact:** M/L.

### FUNC-5 — Add image replacement that preserves composition

- **Location:** `Sources/Rostrum/Presentation/Pictures.swift`,
  `Sources/Rostrum/Presentation/Media.swift`.
- **Proof:** picture data can be read, but there is no public operation to
  replace one picture without changing its frame/crop or mutating every shape
  that shares the original media part.
- **Do:** Add copy-on-write picture replacement in Rostrum and expose it in the
  workbench.
- **Lane:** opus — bounded OPC/media change with losslessness implications.
- **Effort/impact:** M/L.

### FUNC-6 — Add slide import

- **Location:** `Sources/Rostrum/Presentation/DeckMerge.swift:230`,
  `Lectern/App/DeckLibrarySheet.swift`.
- **Proof:** `slides.importAll(from:)` exists, but Lectern cannot combine user
  decks.
- **Do:** Import selected slides from a second deck, preserve their layouts and
  relationships, preview the result, and save to a copy.
- **Lane:** opus.
- **Effort/impact:** M/L.

### REL-1 — Build the local compatibility lab

- **Location:** `Tests/RostrumTests/RealDeckCorpusTests.swift`,
  `Lectern/Sources/LecternCore`.
- **Proof:** the repository corpus is developer-facing; Lectern cannot locally
  open, validate, round-trip, reopen, render, or export a report for a user's
  real deck.
- **Do:** Add a local-only compatibility run and exportable JSON/Markdown
  report. Never upload or automatically commit decks.
- **Lane:** opus.
- **Effort/impact:** M/L.

### REL-2 — Ship Rostrum 0.4.0

- **Location:** `CHANGELOG.md:7`, `README.md:51`, `ROADMAP.md:206`.
- **Proof:** latest release is `v0.3.1`; `main` already contains the v0.4
  Measure & Trust program and a large Unreleased changelog.
- **Do:** finalize release notes/docs, merge on green checks, tag `v0.4.0`, and
  publish the GitHub release.
- **Lane:** sonnet for docs; orchestrator for tag/release.
- **Effort/impact:** M/L.

## Out of Scope

- Applying a template or “AI beautify” to an arbitrary existing deck.
- Recreating the abandoned `feat/apply-template`, `feat/rebind-theme`, or
  `feat/lectern-rebrand` branches.
- Template-native generation. It may be reconsidered only after the workbench
  proves placeholder/layout/font behavior against a real corpus.

## Routing and Schedule

| Wave | Item(s) | Execution |
|---|---|---|
| 0 | REL-0 | completed directly |
| 1 | FUNC-1 | orchestrator, serialized |
| 2 | USE-1, REL-1 | manual worktrees if write sets remain disjoint |
| 3 | STAB-1 | manual worktree |
| 4 | FUNC-2 | orchestrator, serialized |
| 5 | FUNC-3, FUNC-4, FUNC-5, FUNC-6 | manual worktrees only where core/UI files do not collide; otherwise serialized |
| 6 | REL-2 | docs worktree, then integration release |

## Run Events

- 2026-08-05: PR #14 closed.
- 2026-08-05: integration branch created from clean `main`.
- 2026-08-05, Wave 1 — FUNC-1 implemented directly on the integration
  branch. Added `DeckWorkbench`, the Sendable inspection model, on-demand
  slide rendering, and four integration tests.
  - Build: macOS + iOS app builds passed.
  - Test: 595 Rostrum tests, 126 LecternCore tests, and both README snippets
    passed.
  - Lint: not configured.
  - Citation gate: the proof at `AppState.swift:17-21` still describes the app
    surface until USE-1, but the core proof is false:
    `Lectern/Sources/LecternCore/Workbench/DeckWorkbench.swift` now owns an
    opened `Presentation` inside an actor and returns `DeckInspection`; no
    `Presentation` crosses isolation.
  - Opus review requested changes. Addressed all three before closing the
    wave: arbitrary files now use a 1 GiB declared-output budget; an
    unresolvable slide is skipped and reported instead of aborting inspection;
    render errors are mapped to the workbench error contract; snapshot models
    are producer-owned rather than exposing an unusable public initializer.
  - Final integration gate: 595 Rostrum tests, 128 LecternCore tests, README
    snippets, macOS build, and iOS Simulator build all passed.
