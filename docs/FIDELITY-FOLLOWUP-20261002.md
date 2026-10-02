# Fidelity continuation — 2026-10-02

The local integration through `0cdf66b` adds bounded table shadows, DrawingML
kerning thresholds, compatible notes-master geometry imports, and Lectern
end-to-end coverage. Animation remains excluded. No push, PR, merge or release
was performed. The program remains **13 locally implemented contracts, four
partial items (PERF-1, FUNC-1, FUNC-3, REL-5), and one open acceptance gate
(REL-1)**. These results do not establish perfect feature support.

## Changes and independent review

| Scope | Integrated commits | Execution and review |
| --- | --- | --- |
| Bounded table-background outer shadow | `62a1fc4` | gpt-6-astra in isolated table worktree; gpt-6.1-sol review approved |
| Kerning thresholds and position diagnostic | `e4ae5b9` | gpt-6-astra in isolated font worktree; gpt-6.1-sol review approved |
| Notes geometry and type-based inheritance | `868e4dd`, `ea15048` | gpt-6.1-sol in isolated metadata worktree; gpt-6-astra requested and approved a correction |
| Original v1 notes reference | `f1b7974` | Root native PowerPoint capture on an owned copy; source hash unchanged |
| Lectern file-backed feature regression | `0cdf66b` | gpt-6.1-sol implementation; gpt-6-astra review approved |

The notes reviewer caught a real inheritance defect: notes placeholders inherit
from their master by type, independently of their index. A second body with a
different index could retain destination geometry. The implementer reproduced
this with python-pptx's public geometry properties. The correction preserves
unique differing indices and rejects duplicate types atomically. New regressions
verify unchanged source and destination bytes on refusal. Existing local
position/size overrides remain authoritative.

Source pointers: `TableStyleResolver.backgroundShadow`, `SVGRenderer.renderTable`,
`RichTextLayout.Run.usesKerning`, `RenderTextAttributes`, `NotesImportGeometry`,
and `SlideCopier`'s notes-master preflight. No platform/runtime dependencies or
fixture-specific geometry corrections were introduced.

## Accuracy evidence

- [Table shadow evidence](TABLE-SHADOW-20261002.md): both style corpora improve
  from 24/36 to **36/36 passing**. Root independently reproduced both complete
  suites on the integrated release build. All 216 boundary probes remain green.
  The blur remains a located approximation and strict mode still refuses it.
- [Notes geometry evidence](benchmarks/2026-10-02-notes-geometry.json): four
  semantic pairs and four native PDF page pairs pass. Source/imported and
  target/existing pages are pixel-identical at 1224×1584. Both imported pages
  remain pixel-identical after native save/reopen. All three original decks
  opened and reopened in PowerPoint 16.113.3 without a repair prompt. Seven
  original PPTX inputs and four native PDFs are pinned in the corpus manifest.
- Kerning resolves through existing style inheritance and applies inclusively
  at the rendered point size. Disabled kerning preserves ligatures, joining,
  clusters and diagnostics. Original public shaping method references remain
  compatible. Native Office threshold/autofit behavior is not newly qualified.
- [Typography diagnostic](../Tools/typography/KERNING-AND-POSITIONS.md): root
  reproduced **46 passing baselines and four failing PNG comparisons**.
  Native PDF rasterization also fails those four native PNG comparisons;
  changing glyph positions or removing `textLength` did not establish a fix.
- Root's v3 comparison remains **17,314 / 840,000 differing pixels (2.06119%)**,
  above the unchanged 0.5% limit. The worker's double-border checks remain 26/29
  PNG and 29/29 PDF cases passing. No coordinate distortion, reference replacement
  or tolerance relaxation was used.

The general release preflight still exits 1 because slide/notes candidate renders
are missing from that invocation. Original v1 notes reference capture is now
complete; its unpositioned producer output is retained. Rostrum does not yet
provide a general notes-page candidate renderer. Native import equivalence is a
separate, bounded check.

## Integrated verification

The [receipt](benchmarks/2026-10-02-fidelity-verification.json) pins changed source,
executables, logs and reports. Tests ran on macOS 27.0.1 / Apple Swift 6.4.

| Check | Result |
| --- | --- |
| Rostrum `swift test --jobs 2` | 973 tests / 132 suites, 37.941 s, passed |
| LecternCore full suite | 193 tests / 19 suites, 7.044 s, passed |
| Lectern headless AppTests | 59 reported / 15 suites, 9.034 s; one native WebKit test skipped |
| Lectern hosted AppTests | 59 passed / 15 suites, 12.534 s; zero skipped or failed |
| Native WebKit portrait and 4:3 bottom-edge check | Passed, 0.226 s |
| iOS simulator build | Passed, arm64 and x86_64 verified with `lipo` |
| Release build | Passed |
| Notes checker, freshly regenerated inputs | Four semantic and four native page pairs passed |
| Notes checker negative control | Altered candidate refused; no success report written |

The new Lectern regression follows saved deck → inspector previews/diagnostics
→ Markdown export → reopen. It checks shadow approximation warnings, kerning
policy, readable content and unchanged input bytes. The previous native Lectern
interaction work remains documented in [its integration record](LECTERN-INTEGRATION-20261002.md).

## Performance and limits

[Twelve scenarios](benchmarks/2026-10-02-fidelity-macos.json) completed with one
warmup and five fresh-process samples each, the pinned Arial font, and no
concurrent build/test jobs. Every output independently reopened with python-pptx.
All samples in each scenario have identical saved hashes; all 12 hashes match
the earlier October 2 checkpoint. This does not establish SVG identity.

Large-table rendering measured **174.422 / 178.053 ms median / observed p95**,
compared with 169.529 / 174.626 ms earlier. Peak process RSS was **199.375 MiB**,
versus 199.578 MiB earlier. Unique-image rendering measured 3.010 / 3.047 ms.
This run establishes neither a speedup nor a meaningful memory reduction. Five
samples do not establish a population tail or universal regression threshold.

Docker Desktop failed to start within 45 seconds; its daemon remained unavailable,
and a subsequent native inspection timed out. No Linux runtime test or Linux/iOS
performance result is claimed. Advanced table typography/patterns/effects and
compound borders, broader script/bidi/line-breaking behavior, broader notes
master/theme/page-size reconciliation and the remaining Office PNG gates stay
open. Unsupported cases continue to report issues or refuse edits atomically.
