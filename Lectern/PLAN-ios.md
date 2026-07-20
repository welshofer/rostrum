# M6 — Lectern on iOS / iPadOS

Goal: the existing demo app, running natively on iPad and iPhone, generating
the same PowerPoint-clean `.pptx` from the same LecternCore pipeline. Rostrum
and LecternCore require **zero changes** — AppKit is confined to two app-shell
files (`LecternApp.swift`, `ContentView.swift`; verified by grep 2026-07-19).
This milestone is entirely app-shell work.

## Decisions needed before starting (owner)

| # | Decision | Recommendation |
|---|---|---|
| D1 | iPad-first or universal from day one? | iPad-first: the 780-pt compose column is nearly iPad-ready; iPhone is most of the UI cost (Phase 5b) and can trail. |
| D2 | iOS 17 minimum OK? | Yes — `AppState` uses `@Observable` (iOS 17+); dropping lower would force an `ObservableObject` rewrite. SwiftData history (M4) also wants 17+. |
| D3 | Backgrounding mid-generation: accept the ~30 s grace window with a clean failure, or rework to a background `URLSession`? | Grace window + clean failure. A background session means restructuring the streaming `GenerationEvent` pipeline — not worth it for a demo app. Revisit only if real users lose money to suspensions. |

## Phase 1 — Target & build plumbing (~½ day)

- `project.yml`: add a `Lectern-iOS` target — platform iOS, deployment target
  17.0, same `App/` sources, `Assets.xcassets`, and `Resources/Styles/`.
  LecternCore comes in through the same local SPM dependency.
- Per-target source exclusions for the mac-only shell pieces (see Phase 2).
- `scripts/build-ios.sh`: simulator build
  (`-destination 'generic/platform=iOS Simulator'`) as the CI compile oracle.
- Signing: simulator needs none; device installs use the personal team
  (extends OQ-5, still an owner decision for anything beyond local devices).

**Done when:** the iOS target compiles and boots to the compose form in the
simulator.

## Phase 2 — Platform-split the app shell (~½–1 day)

- `LecternApp.swift`: `#if os(macOS)` around `AppDelegate`, `LaunchFrameView`,
  and the defaults scrub — window frames and quit events don't exist on iOS.
  iOS gets a plain `WindowGroup`; scene-phase protection replaces the quit
  guard (Phase 3).
- `ContentView.swift`: the two `NSWorkspace` calls (Open / Reveal) become
  `ShareLink` + `.quickLookPreview` on iOS (QuickLook renders `.pptx`
  natively). Everything else is already SwiftUI.
- `Settings` scene → a sheet off the compose view on iOS (no ⌘, there).
- PDF input: unify both platforms on `.fileImporter`; keep `.dropDestination`
  (drag-in works on iPadOS as-is, and stays for macOS).
- `KeychainStore`: no change — the generic-password/login-keychain code is
  exactly the (only) keychain iOS has, with none of the macOS signing ACL
  drama.

**Done when:** compose → mock/no-key path → result card all work in the
simulator; macOS behavior unchanged.

## Phase 3 — Generation-lifecycle protection (~½ day)

The macOS threat was a careless quit; the iOS threat is the OS suspending a
backgrounded app and killing the in-flight (paid) API call. Same invariant,
new enforcement point:

- `UIApplication.isIdleTimerDisabled = true` while `phase == .generating`
  (restore on exit from that phase, all paths).
- Take a `beginBackgroundTask` assertion for the duration of the generation
  task, so a brief app switch survives the ~30 s grace window.
- Observe `scenePhase`: if the assertion expires mid-generation, fail *loudly
  and cleanly* into `phase = .failed` with a message that says the OS
  suspended the app — never a silent hang or a spinner lying about progress.

**Done when:** backgrounding briefly during generation completes normally;
exceeding the grace window surfaces the clean failure on return.

## Phase 4 — Output & Files-app integration (~½ day)

- Write decks to `Documents/`; Info.plist gains `UIFileSharingEnabled` and
  `LSSupportsOpeningDocumentsInPlace` so decks are visible in the Files app
  and openable in place.
- Result card: `ShareLink` (hand off to PowerPoint / Keynote / AirDrop) and
  QuickLook preview.

**Done when:** a generated deck appears in Files and opens clean (no repair
prompt) in Keynote and PowerPoint on device — the repo's standing oracle rule
applies unchanged.

## Phase 5 — Layout adaptation

- **5a. iPad (~½ day):** current card column centered in a `ScrollView`;
  verify regular/compact size classes and 1/3-width split view. No fixed
  window sizes anywhere — that concept stays behind `#if os(macOS)`.
- **5b. iPhone (~1 day, deferrable per D1):** stacked compact layout, style
  picker becomes a navigation push, Generate moves to a bottom bar; usable at
  iPhone SE width.

**Done when:** every control is reachable and legible in each supported size
class; no horizontal clipping.

## Phase 6 — Verification

- `swift test` (LecternCore + Rostrum) — must stay green, untouched.
- CI: add the Phase 1 simulator compile to the existing build checks.
- Device smoke test with a real key (owner — needs provisioning): full
  prompt → PDF grounding → generate → share-to-Keynote loop.

## Explicitly out of scope

- Liquid Glass polish (§3) — separate milestone, tracks macOS 26 / iOS 26.
- History (SwiftData, M4) and PriceTable (M5) — unchanged by this work; M4's
  iOS 17 floor is compatible.
- Background `URLSession` rework (see D3).

## Effort summary

| Phase | Effort |
|---|---|
| 1 Target & plumbing | ½ day |
| 2 Platform split | ½–1 day |
| 3 Lifecycle protection | ½ day |
| 4 Output & Files | ½ day |
| 5a iPad layout | ½ day |
| 5b iPhone layout | 1 day (deferrable) |
| **Total** | **~2½ days iPad-first; ~3½ universal** |
