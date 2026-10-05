# Table defaults and unequal border joins — 2026-10-04

This checkpoint corrects two native table behaviors: an absent applied style
uses the unstyled black grid, and admitted unequal solid borders meet at native
endpoints. Import preserves the absence of an applied style. Lectern exposes the
changes in its 30th offline demonstration, Table defaults and border joins.
The full local gate and both manual workflows pass at `4795efa`.
Fresh browser extraction, independent performance review and final integration
review pass. The
[integration manifest](benchmarks/2026-10-04-table-defaults-integration-verification.json)
records the evidence and retained verification history.

## Native behavior and bounded correction

The style-list default is an insertion choice. It does not become an applied
style when a table has no `tableStyleId`. The renderer now resolves that absence
to No Style, Table Grid. This holds even when the package's style-list default
is a custom style. Explicit applied styles, inline styles and direct cell
formatting keep their precedence. Import leaves missing `tblPr` and applied
style IDs missing, instead of stamping a source insertion default into the
destination. Explicit style dependencies and collision handling remain intact.

Two original native pages establish eight style cases: absent and explicit
built-in styles, explicit No Grid, a custom default, explicit and inline custom
styles, and direct cell overrides. The third page establishes four border cases:
unequal outer edges, a missing edge, a mixed shared grid and conflicting shared
declarations. Before correction, retained checks exposed ten style/import
failures and 29 endpoint failures. The implementation uses the actual surviving
perpendicular edges to extend or contract each endpoint by half the donor width.
At collinear continuations, the thicker stroke owns the crossing. Donor lookup
is bounded; there is no persistent DOM cache or per-glyph join work.

The new mixed-width path admits rectangular, unmerged LTR tables with positive
cell dimensions greater than the widest stroke, opaque plain solid borders and
no diagonals. Multiple cells must use one border color; the captured single-cell
case also admits differently colored corners. The established uniform-width
path is unchanged. RTL, merged, multicolor grids, alpha, dash, diagonal, ragged
and oversized-stroke profiles retain their existing behavior in this checkpoint.
Further profiles are being investigated separately.

The original native evidence contains 12 cases and 72 visible glyphs. Vector
geometry is checked at 0.001 pt and color at 0.0001 per channel. Canonicalization
joins only touching collinear intervals with identical opaque paint and width;
it does not discard coverage, distinct widths, colors or painted duplicates.
Raw native operators and paint order remain available. Glyph origins, actual
font bytes and painted sizes are checked separately. Trace bounding boxes are
not claimed to prove full glyph ink or whole-slide visual equivalence.

## Lectern and saved-file workflows

Each option imports the three reference pages while retaining all 12 specimen
nodes, frames, source master bindings and embedded font bytes. Only captions
outside the specimens use bundled DejaVu Sans. Complete page XML identity is
not claimed. A fourth page exercises public table APIs: a custom applied style
is either retained or cleared with `styleID = nil`, alongside a table with
unequal authored borders. Each option passes 63 saved-file checks with no
reported findings.

Both four-slide decks open in PowerPoint 16.113.3 without repair. Local Best for
printing PDF export is selected with online export off; original PPTX bytes
remain unchanged. Root visually reviewed all eight pages. Independent extraction
of the first three pages in both PDFs passes 24 case comparisons and 144 glyphs
against the original native references. The fourth public API page is outside
that numerical reference acceptance.

The actual app tests run the recipe, open its saved deck in the inspector and
export it through the production workflow. They compare all four saved SVGs
with the actual inspector output, and check the on-disk source again after
export. Native validation parses each page once, resolves font aliases from
actual embedded bytes, and rejects unmodelled parent or span positioning. Wrong
width, color, text offset and font-alias controls demonstrate that the independent
extractor does not merely accept its own expected fixture.

Fresh extraction of all six table WebKit PDFs passes 24 case comparisons and
144 glyphs at the unchanged vector/color and glyph bounds. Actual source/subset
font-outline identity is checked, alongside raw PDF paint sizes; trace boxes do
not substitute for glyph ink. First-glyph x is bounded by 0.025 pt, other x by
0.06 pt, baselines by 0.121 pt and painted sizes by 0.002 pt. Browser-to-saved-SVG
origins retain the 0.025 pt bound. The original three positive and four negative
extractor controls pass again.

The initial browser parser failures remain retained. Raw operators show WebKit
emitting single open axis-aligned zero-area fill paths beside strokes. MuPDF can
expose these as separate `f`/`s` drawings or a combined `fs` drawing. An additive
adapter accepts only that zero-area form and still checks the complete stroke,
including butt caps. Seven targeted parser negatives reject broader path/cap
changes. Original helpers, failed receipts, PDF bytes and numeric bounds remain
unchanged.

Fresh regression extraction also passes four mixed-face PDFs / 24 cases /
192 glyphs, eight alignment PDFs / 48 cases / 344 glyphs, eight marker PDFs /
48 cases / 554 glyphs with six explicit omissions, and three paragraph/kerning
PDFs / 14 cases / 208 glyphs. These are fresh extractions from this gate's actual
saved previews, with the existing explicit raw-library kerning control, rather
than transfer based on older PDF identities.

Root also completed both Run Demo → Inspect Result → Export Everything workflows
through the native UI. Each showed four loaded previews, 63 checks and a
four-slide export with no media or chart CSVs. All 37 source text nodes per
option survive the explicitly scoped Markdown unescaping. Manual and recipe
Markdown exports are byte-identical. Source hashes taken before inspection
remain unchanged after export and match the native capture inputs. All eight
saved previews match the app-gate previews exactly; raw-library comparison needs
only root viewport normalization. The manual receipt pins 44 files and the
tested app binary. Observed creation times of 3.75 and 3.71 seconds are UI
observations, not controlled performance measurements.

## Full verification

`scripts/verify.sh` completes successfully with 1,180 Rostrum tests / 171 suites,
18 RostrumLayout tests / three suites, 295 LecternCore tests / 44 suites, and
89 app test definitions / 26 suites covering 124 executions. Offline workflow
checks and README snippets pass. Both macOS and iOS simulator builds explicitly
report `BUILD SUCCEEDED`. The xcresult reports no failures, expected failures,
skips or runtime warnings.

The app console retains 11 clipboard-error, 228 preferences-daemon and 11
audio-component messages, as well as DisplayLink notices. Compile warnings are
retained separately; a zero xcresult runtime-warning count does not erase them.
Build gates now keep full compiler output. Unlike the previous quiet build
logs, this gate contains no contradictory failed-with-exit-code-zero messages.

All 30 catalog recipes pass 605 checks and retain 413 findings describing other
support boundaries. Two additional table pipeline reports pass another 126
checks; those are executions of the same recipe, not two more catalog entries.
External ZIP CRC, unique-member, XML and python-pptx checks reopen 72 packages,
247 slides and 2,665 XML/relationship parts. All 398 checked inputs remain
unchanged. All 32 pinned native table fixture files match the frozen engine
commit. Eleven native-input identity checks pass.

Of 58 general Lab packages shared with the prior gate, 54 are exact. Four differ
only in valid, consistently mapped comment/author UUIDs and ISO timestamps;
other content remains exact. Of 26 prior special SVGs, 24 are exact. Both
alignment slide-four SVGs intentionally change table paint through the missing
applied-style correction. That difference is retained rather than normalized away.

## Performance

The approved experiment compares the preceding production Sources tree with
only this five-file correction. It freezes 462 fresh child processes, 22 primary
comparisons and all 240 measured phases. The plan retains one excluded warmup
pair and ten alternating measured pairs per workload, raw samples, process RSS,
SVG bytes, adverse controls and host load. Original rendering precedes subsequent
edit/save phases. No adaptive reruns are permitted.

Preflight checks cover 168 cases and 862 slides in 504 fresh processes and
external reopens. Saved packages, ordered diagnostics and inheritance results
are exact. The 21 changed cases contain 51 changed SVGs with no text-tree
differences. Explicit No Style, Table Grid counterfactuals isolate missing-style
selection; residual changes on 39 slides are border endpoints and order with
unchanged non-line trees and line paint attributes. Separate merge proofs retain
missing IDs/properties, explicit and inline styles, direct formatting and unknown
XML. These preservation checks are not native visual proofs or speed claims.

The single campaign completed in 109.68 seconds. The
[performance report](TABLE-DEFAULT-JOINS-PERFORMANCE-20261004-17.md) retains all
240 phases. Custom-native rendering observes +4.852% (bootstrap interval
+3.222% to +7.633%), mixed joins at 100 × 20 observe +0.976% (+0.719% to
+2.541%), and the unchanged mixed-RTL control observes +1.466% (+0.791% to
+2.507%). All three have ten of ten slower pairs. The absent-ID scaling cases
observe −9.748%, −8.653% and −7.838%, each with ten faster pairs, while rendering
different intended paint. Registered rendering remains inconclusive.

Background backup load reaches 156.7% in the retained snapshots. The agent lanes
paused builds, tests and GUI activity, but the host was not controlled. Process
RSS changes range from −2.188 to +0.180 MiB. These observations do not establish
isolated allocation changes, causal attribution for unaffected controls, general
recovery or universal nonregression. Independent review recomputed all 240 phase
vectors and accepted the bounded observations; no rerun occurred.

## Known next gaps

Native probes confirm further border differences for RTL, axis-colored grids
and one-axis merges. Their correction remains a separate checkpoint so that
its admission rules and measured cost can be reviewed independently.

The fourth public API page also exposes a remaining partial-custom-style gap:
PowerPoint draws a thin black border when the custom style specifies a fill
without edge declarations, while the current SVG omits those edges. This is
outside the twelve original reference cases and is explicitly retained as a
follow-on native fallback investigation. The successful workflow checks do not
establish complete custom-style or whole-slide PowerPoint parity.
