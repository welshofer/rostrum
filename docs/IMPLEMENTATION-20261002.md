# Integrated performance and accuracy follow-up — 2026-10-02

The later [Lectern integration pass](LECTERN-INTEGRATION-20261002.md) adds native
inspection/export verification and passing app-hosted tests. This checkpoint's
results and Office fidelity qualifications remain preserved below.

All changes described here are committed locally on `codex/burndown/20261001`.
The tested code revision is `00a32311b4037441105cc1c86a2cd335f2d95825`;
subsequent record updates do not change executable source. The requested pull
was already current at `a35e7b1`; a final fetch found the remote main unchanged.
No push, PR, merge or deployment occurred. Animation remains excluded.

The 18-item program now has **13 local implementations within documented
contracts, four partial items and one open acceptance gate**. Complete table or
PowerPoint fidelity is not established. This record supersedes the current-status
summaries in the preserved [October 1 checkpoint](IMPLEMENTATION-FOLLOWUP-20261001.md)
and isolated October 2 reports, without replacing their evidence.

## What changed in this follow-up

- **Tables:** solid, flat, centered double borders render as two one-third-width
  strokes with a transparent gap. Office PDF geometry establishes diagonal
  offsets and qualified terminal extensions. Native style-region boundary edges
  propagate before direct logical-donor formatting, including RTL. Unsupported
  double-border crossings, caps, dashes and compound variants remain diagnosed.
  New typed `LineCompound` and `LineDash` settings support authoring, inspection
  and table editing; unspecified settings preserve existing opaque formatting.
  See [line API contracts](LINE-STYLES.md) and the
  [double-border corpus](../Tests/RostrumTests/Fixtures/DoubleTableBorders/README.md).
- **Typography:** shared DrawingML layout now uses validated Windows ascent /
  descent proportions, natural 1.2-em line boxes and accumulated baseline
  rounding. Public generic `FontMetrics` values retain their existing contract.
  On 30 independent Arial/Calibri cases, maximum baseline error falls from
  2.25480 to 0.12002 points. The checker verifies 268 embedded PDF glyph outlines
  against four pinned local font files before comparing all 46 lines.
  [Scope and residuals](../Tools/typography/OFFICE-BASELINES.md) remain explicit.
- **Images and crops:** twelve independently authored mapping cases pass the
  existing Office PNG comparison gate, including source/destination crops,
  transforms, clipping and mirrored tile fills. The original shadow-bearing
  fixture remains failing. Active theme effects now produce located diagnostics;
  unsupported format-scheme overrides report unresolved inheritance. Explicit
  empty overrides and namespace aliases are handled without false effect reports.
  See [the image evidence](IMAGE-OFFICE-20261002.md).
- **Performance:** bounded operation-local style, paragraph, geometry and media
  caches remove repeated work. Sectionless slide construction skips unnecessary
  section-context scans. The final 10,000-cell render median is 169.529 ms,
  compared with 217.752 ms at the October 1 integrated checkpoint. Same saved
  synthetic PPTX bytes do not imply identical rendered output; the richer
  renderer still costs more than the older baseline. Memory does not improve.
- **Lectern:** preview issues remain visible through the inspection/raster paths.
  Cancelled and superseded inspections cannot publish stale progress/results.
  Dependency injection isolates app tests from real defaults, Documents, Trash
  and keychain access. The headless harness compiles actual app/view sources
  and all AppTests, excluding only the app entry point.

Speaker-note printing/import, comment editing and dependency transfer, and
namespace-aware section lifecycle work from the preceding wave remain integrated.
Their existing regression and Office evidence is included in this final tree;
this follow-up does not claim new Office lifecycle qualification for every one
of those operations.

## Final combined verification

The [verification receipt](benchmarks/2026-10-02-final-verification.json) records
the tested revision, source-input hashes, executable/driver hashes, log hashes,
exit codes and oracle reports. The final AppTests check was rerun with console
output separate from the harness-owned log after review caught a redirect
collision; the final receipt and log hashes agree. Checks ran on macOS 27.0.1 with Apple Swift 6.4.
The local library corpus includes four existing tracked foreign-producer fixtures.

| Check | Result |
| --- | --- |
| `swift test --jobs 2` at repository root | 953 tests / 129 suites pass, 38.340 seconds |
| `swift test --jobs 2` in Lectern | 168 tests / 15 suites pass, 6.992 seconds |
| Headless harness, `--all-app-tests` | 42 tests / 11 suites pass, 0.357 seconds; [exact-input receipt](benchmarks/2026-10-02-final-app-headless.json) |
| macOS `xcodebuild ... build-for-testing`, signing disabled | App and hosted test bundle compile |
| iOS simulator `xcodebuild ... build`, signing disabled | Both arm64 and x86_64 compile |
| `swift build -c release --jobs 2` | Pass |
| `ReadmeSnippets` | Pass |
| `release_gate.py --semantic-only` | All three independent table fixtures pass python-pptx 1.0.2 |
| Python conformance-tool unit tests | Seven pass |
| Fresh-process release benchmark | All 12 scenarios complete; one warmup and five samples each; every output independently reopens; all five saved hashes agree per scenario |

The macOS build is not an app-hosted runtime pass. The earlier hosted run failed
before runner connection after about 353 seconds; the process sample showed
startup filesystem enumeration. It was not repeated. Headless tests do not
exercise the live startup window, migration, real keychain or end-to-end GUI.
Linux execution remains unavailable: Docker's daemon is stopped and no Swift
cross-compilation SDK is installed. Remote CI was not run. No runtime dependencies
were added to the library.

## Office comparisons and failures

Root reran the comparisons using the final integrated executable. Immutable
Office references and thresholds remain unchanged. Double/style/image reports
are byte-identical to their committed corpus reports; the receipt verifies this.

| Oracle | Final result and scope |
| --- | --- |
| Native table fills | 1,480 / 1,480 probes across 74 styles pass |
| Shared border ownership | 737 / 737 probes across 42 cases pass |
| Double-border PDF | 29 / 29 geometry cases pass; maximum error 0.000116943 pt at a 0.001-pt gate |
| Style-boundary LTR/RTL PNG probes | 216 / 216 pass, maximum one-channel difference |
| Double-border whole PNGs | 26 / 29 pass; three fail |
| Style-boundary whole PNGs | 24 / 36 pass in each LTR and RTL corpus; remaining cases fail |
| Image mapping whole PNGs | 12 / 12 v2 cases pass; worst 0.1130% differing pixels |
| Typography PDF | All 46 baselines pass, maximum 0.12002 pt at the 0.121-pt gate |
| Typography whole PNGs | Four of six still fail; integrated SVG hashes match the measured font change |
| Independent v3 table whole PNG | **Fails: 17,314 / 840,000 pixels, 2.06119%, versus a 0.5% limit** |

The typography vector tolerance accounts for the Office PDF export's separate
position grid. It does not loosen the PNG gate. All whole-PNG comparisons use
channel tolerance 16 and maximum differing fraction 0.005. Geometry and stable
interior probes cannot establish whole-image equivalence. The double-border
native-style PDF cases check component union bounds/band boundaries, while the
24 direct cases check all eight vertices; they are distinct evidence scopes.

The generic release gate also fails preflight: the original table fixture still
has no required notes reference, and this invocation has no complete candidate
slide/notes render directory. It therefore does not launch scripted Office.
Separate normal-UI Office captures opened without repair; these do not turn a
failed release invocation into a pass. References with known producer defects
remain preserved rather than silently replaced.

## Item disposition

These are local implementation states, not shipping or universal-conformance
labels. The original detailed proof and earlier commits remain in the
[initial record](IMPLEMENTATION-20261001.md) and [follow-up](IMPLEMENTATION-FOLLOWUP-20261001.md).

| Item | Current state | Evidence / remaining work |
| --- | --- | --- |
| PERF-1 benchmarks | Partial | Final 12-scenario report; Linux/iOS measurements and variance-derived limits remain open |
| PERF-2 traversal | Implemented locally | Operation-local table/slide scans; `20649ee` sectionless construction fast path |
| PERF-3 media index | Implemented locally | Collision-checked media identity and `a199aa2` bounded render lookup |
| PERF-4 bounded archive access | Implemented locally | Lazy inspection/cache/budget regressions pass; Linux runtime gate remains |
| PERF-5 streaming save | Implemented locally | Atomicity/preservation tests and deterministic benchmark outputs pass |
| FUNC-1 tables | Partial | `0793783`, `a83d727`, `00a3231`; patterns/effects, advanced vertical text, other compound/junction previews and whole-image equivalence remain |
| FUNC-2 rich layout | Implemented locally | Shared fit/render layout plus `67b292c` DrawingML baseline metrics; independent baseline evidence has bounded scope |
| FUNC-3 shaping | Partial | Existing bounded Latin/Arabic/GDEF/Calibri support; full Arabic/Indic, marks/cursive attachment, bidi and line breaking remain |
| FUNC-4 images/crops | Implemented locally | `0db1be8`, 12 native v2 mapping cases; alternate/layered/linked replacement remains an explicit atomic refusal |
| FUNC-5 comments | Implemented locally | Modern/legacy edit/read/reply/anchor tests; broader native lifecycle acceptance remains under REL-1 |
| STAB-1 atomic fills | Implemented locally | Rejected fills leave XML and dirty state unchanged |
| STAB-2 shared colors | Implemented locally | Native fills and preserved shared theme/color transform tests pass |
| REL-1 independent conformance | Acceptance open | Failed PNG and release gates above; broader Office lifecycle and platform coverage remain |
| REL-2 annotation independence | Implemented locally | Duplicate/edit/remove tests preserve independent notes and comments |
| REL-3 authors/anchors | Implemented locally | Bounded dependency transfer and standard customXML Office example; unsupported semantic/context conflicts refuse atomically |
| REL-4 sections | Implemented locally | Namespace/compatibility context and membership lifecycle regressions pass; broader foreign-producer Office acceptance remains |
| REL-5 notes appearance | Partial | Authored pages and one exact imported-page reference; conflicting master/page-size reconciliation remains unsupported |
| USE-1 fidelity status | Implemented locally | Located theme-effect and border-crossing diagnostics, strict refusal, and Lectern issue presentation |

## Review provenance

Three continuing workers used their separate table, font and metadata worktrees;
root integrated commits sequentially. Their earlier recorded model assignments
remain in the October 1 record; resumed outputs did not provide a fresh model
identity, so no new cross-model claim is made here. Fonts independently approved
the table/Line changes and exact integrated revision `00a3231`; metadata reviewed
the font metrics and root image evidence. Fonts and metadata independently
reviewed root's inherited-effect diagnostics. Review found and corrected an
interior double-border crossing omission, namespace-only empty effect false
positives, theme-override attribution and initializer compatibility.

Root reran the combined checks above after integration. The current summaries
were separately audited for stale feature, benchmark and validation claims.
Known pixel failures, platform gaps and unsupported operations are retained as
open work, with no threshold relaxation or claim that everything is perfect.
