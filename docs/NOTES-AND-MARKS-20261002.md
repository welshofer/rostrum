# Notes previews, mark positioning and layout performance — 2026-10-02

This continuation adds a bounded notes-page renderer, on-demand Lectern notes
previews, OpenType mark attachment and a measured table-layout optimization.
It does not close the complete-fidelity program. The existing disposition remains
13 local contracts, four partial items (PERF-1, FUNC-1, FUNC-3, REL-5), and the
open REL-1 acceptance gate. Animation remains excluded.

## Implementation and review

- `ab216e7`: ASCII fallback layout fast path. Profiled, implemented and measured
  in an isolated worktree with requested model gpt-6.1-sol; independently
  reviewed and approved by gpt-6-astra. The
  [paired benchmark and output proof](LAYOUT-PERFORMANCE-20261002.md) establish
  a 3.33% median improvement for 10,000 cells and 3.01% for 2,000 cells. All 574
  comparison slide renders, ordered diagnostics and saved bytes match. This
  evidence isolates the layout change, not the later shaping feature changes.
  There is no memory-reduction or general typography speed claim.
- `d39f814`, `d5c4beb`: GPOS mark-to-base and mark-to-mark attachment, with extension
  lookups, GDEF filtering and bounded parsing/execution. The
  [HarfBuzz evidence](../Tools/typography/MARK-POSITIONING.md) checks glyph IDs,
  clusters, advances and offsets independently, including scaling and repeatability.
  Owned fonts and existing redistributable DejaVu data are committed; local
  Arial/Calibri comparisons do not copy proprietary font bytes.
- `d06b2cb`, `7a43b15`: notes rendering resolves the actual notes size,
  relationship-selected master/theme, type-based placeholder ancestry, inherited
  properties and master artwork on detached copies. Slide image documents
  isolate fonts and SVG identifiers from the notes page. Strict mode refuses
  known gaps. `pptx-tool render --notes` writes `notes-NN.svg` for existing pages.
  No notes parts are created by reading or rendering.
- `c88aea4`: Lectern reopens and renders one notes page only when requested,
  retaining its fidelity diagnostics. A detached task owns security-scoped file
  access until rendering completes; cancellation and request generations reject
  stale results. Notes-only fonts are scanned only for notes preview requests.
  Empty notes pages with artwork remain discoverable. The native SVG wrappers
  constrain only the outer viewport so nested SVG sizes survive.

Notes and mark implementation delegations requested gpt-6-astra and their
independent review requested gpt-6.1-sol. Review caught thumbnail suppression
and repeated alpha painting in notes, and an unsupported Latin composition
case in mark shaping. Corrections have cause-specific regression fixtures.
The root Lectern implementation received an independent gpt-6-astra source
review with no remaining finding. Model labels describe requested delegations;
they are not independent runtime attestations.

## End-to-end app evidence

The notes fixture is an unmodified copy of the owned library geometry source,
SHA-256 `f984bd9e651541626e835e029b3f310513aee150957a91b62bf1f2ffc310fe3b`.
Core tests follow the saved file through inspection, notes rendering, diagnostics
and another read, verifying unchanged source bytes. They also exercise missing
and empty notes, invalid slide positions, decompression limits, cancellation and
notes/master font discovery. Controlled app tests cover stale successes and
failures, direct task cancellation, replacement, recovery and dismissal.

At `c88aea4`, a normal rebuilt Lectern process was launched through native UI
control. The fixture opened through Inspect Deck, its notes button opened the
portrait page with pale background, slide thumbnail and wrapped Arial text,
Done returned to inspection, and reopening succeeded. The source hash remained
unchanged. No settings, credentials or user decks were edited. This exercises
the actual sheet beyond the hosted test harness.

Native WebKit tests additionally verify the complete notes page, embedded slide
image, portrait/4:3 lower edges and a nested SVG viewport. Headless runs skip
the three native WebKit tests explicitly; hosted runs execute them.

## Final combined verification

The [verification receipt](benchmarks/2026-10-02-notes-marks-verification.json)
pins 42 changed implementation/test/tool inputs, logs, reports and executable
hashes. Compiled implementation is `d5c4beb`; `94ab8bf` adds the reproducible
oracle and documentation without changing compiled sources.

| Check | Result |
| --- | --- |
| Rostrum full suite | 993 tests / 134 suites passed, 28.269 s |
| LecternCore full suite | 198 tests / 20 suites passed, 14.582 s |
| Headless AppTests | 65 reported / 16 suites passed, three native WebKit tests skipped |
| Hosted AppTests | 65 tests / 16 suites passed, zero skipped/failed, 23.660 s |
| iOS simulator build | arm64 and x86_64 passed, architectures verified |
| Release build | Passed, 49.42 s |
| Semantic conformance preflight | Passed; explicitly not release certification |
| Pinned notes import preservation | Four semantic and four exact native PDF page pairs passed |
| Absolute notes render comparison | Seven native pixel gates failed at unchanged limits |

The final release executable independently reproduced the
[notes-render report](benchmarks/2026-10-02-notes-rendering.json): ten source
decks, thirteen notes candidates, python-pptx placeholder geometry agreement,
and four byte-identical source/import SVG pairs. Absolute native differences are
0.8356944% for geometry source/imported page 2, 1.0406203% for target/imported
page 1, 4.7888495% for conformance original/v2 and 1.0428740% for conformance v3.
Every case exceeds 0.5%; the checker correctly exits 1 and retains the evidence.
See the [notes contract and reproduction command](NOTES-RENDERING-20261002.md).

## Remaining accuracy and platform gates

Notes print-image comparisons still fail the fixed channel-16 / 0.5% differing
pixel threshold. The notes-size API and Office's Letter print profile are
reported separately; adapting to the recorded print area is a diagnostic
comparison, not a production print-layout implementation or altered reference.
Header/footer visibility, auxiliary placeholders and other unsupported notes
semantics remain diagnosed. Broad notes-master/theme/page-size reconciliation
remains outside the supported import contract.

Whole-slide table equivalence and existing typography/double-border PNG failures
remain open. This pass does not replace their references or loosen tolerances.
Complete complex-script layout, language features, Unicode bidi and additional
mark/ligature/cursive behavior remain unsupported or partial. Numeric HarfBuzz
agreement is not an Office PNG-equivalence claim.

Docker's daemon remains unavailable on this host. A fresh status check still
reported it stopped, and the recent error-log query produced no entries. Linux
execution and Linux/iOS performance baselines remain unverified. Prior Docker
startup timeouts are not represented as a successful Linux check.

No push, PR, merge, release or deployment was performed.
