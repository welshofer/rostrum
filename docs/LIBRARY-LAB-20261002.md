# Lectern Library Lab — 2026-10-02

Library Lab makes Rostrum's shipped capability families runnable in Lectern
without a provider, account, network request or external document. Open the
**Library Lab** sidebar item, choose a demonstration, change its declared inputs,
and select **Run Demo** or **Run All Demos**. Inspect the saved result or the
before document, share the deck/report, or use **All Files** to access every
source, template, SVG, notes page, extracted image, media file and chart dataset.

The app owns a background task and a fresh output directory per invocation.
Changing views or cancelling retires the task; late completion cannot replace a
newer run. Finished results survive a trip to the inspector. Runs never overwrite
existing documents. Failed runs remove only their own output directory. Reports
record effective inputs, operations, semantic checks, findings with locations,
and elapsed creation/save/reopen/render/extraction time. The time is an
observation of that run, not a comparative benchmark.

## Executable coverage

The stable [catalog IDs](../Lectern/Sources/LecternCore/LibraryLab/LibraryLabTypes.swift)
are routed exhaustively through the [runner](../Lectern/Sources/LecternCore/LibraryLab/LibraryLab.swift).
Tests require a unique recipe for every ID and run every recipe through the same
file pipeline used by the app. Each recipe's `operations` and `limitations` are
visible in Lectern and in its JSON report.

| Demo | Behavior exercised | Recipe source |
|---|---|---|
| Slide lifecycle | Add, duplicate, move, remove; independent copy edits; footer, date, slide numbers and source | [Document](../Lectern/Sources/LecternCore/LibraryLab/DocumentLabRecipes.swift) |
| Layouts and placeholders | Layout lookup, cloned placeholders, layout-bound builders, effective inherited frames and declared master order independent of relationship order | [Platform document](../Lectern/Sources/LecternCore/LibraryLab/PlatformDocumentRecipes.swift) |
| Imported artwork and text | Saved/reopened custom curves, SVG-only image extension, cached SmartArt, all-caps runs and spaced lists; checks rendering is read-only | [Imported fidelity](../Lectern/Sources/LecternCore/LibraryLab/ImportedFidelityRecipe.swift) |
| 178 shape presets | Complete enum gallery; frame, rotation, naming and rounded corners | [Drawing](../Lectern/Sources/LecternCore/LibraryLab/DrawingLabRecipes.swift) |
| Fills, outlines and shadows | Solid/alpha/theme/none/linear/radial/image fills; every dash and compound line; shadow | Drawing |
| Rich text and live fields | Runs, paragraphs, list numbering/bullets, margins, alignment, spacing, tracking, superscript/subscript, links and fields | Drawing |
| Fonts, shaping and fitting | Licensed bundled font; exact face lookup, measure/wrap/shape/fit; embed and recover bytes | Platform document |
| Paragraph spacing and justification | Side-by-side mixed-size left/justified paragraphs; adjustable sentence count and width; both fit APIs; embedded-font recovery; exact span positions after reopening; shared table-cell layout; native-captured narrow wrap boundaries and public fitting across styled runs | [Platform paragraphs](../Lectern/Sources/LecternCore/LibraryLab/PlatformParagraphRecipe.swift) |
| List markers and hanging indents | All 24 independent native marker specimens; distinct imported masters; separate character/number size and face rules; three absent inherited markers; body continuation margins; both computed fit APIs; saved font bytes and complete glyph SVG checks | [Platform markers](../Lectern/Sources/LecternCore/LibraryLab/PlatformListMarkerRecipe.swift) |
| Text alignment | 24 native center/right cases and 172 glyphs; fractional widths, wrapping, spaces, insets, actual faces, kerning and table cells; both computed fitting APIs; exact saved inspector previews and extracted text | [Platform alignment](../Lectern/Sources/LecternCore/LibraryLab/PlatformTextAlignmentRecipe.swift) |
| Mixed faces and exact spacing | 12 native cases and 96 glyphs with equivalent vertical metrics across distinct actual fonts; exact spacing and anchored/scaled controls; both computed fitting APIs in a 40 pt frame; exact saved inspector previews and extracted text | [Platform mixed spacing](../Lectern/Sources/LecternCore/LibraryLab/PlatformMixedFaceSpacingRecipe.swift) |
| Tab stops and justified fields | Four standard tab alignments with visible guides; adjustable numeric rows and stop positions; tab-aware Latin justification and a shared table cell; public tab properties and exact spans after reopening | [Platform tabs](../Lectern/Sources/LecternCore/LibraryLab/PlatformTabRecipe.swift) |
| Pictures and image fills | Image formats and metadata, crop, rotation, deduplication, independent replacement, image fills and retained geometry | Drawing |
| Edit a table grid | Merge topology, unmerge, insert/delete/move/reorder rows and columns; independent permutations and atomic refusals | Drawing |
| 74 native table styles | Complete native enum gallery, headers/footers/banding/RTL | Drawing |
| Cell appearance | Border edges/diagonals, fills, text, padding, direction, inheritance and custom styles | Drawing |
| Chart gallery | Every category kind, XY/scatter, bubbles, combo/secondary axis and native workbooks | Document |
| Chart editing | Replace/add/remove series; multi-group combo replacement; explicit invalid-operation refusals | Document |
| SmartArt | Every public layout: block list, process, cycle, experimental pyramid; layout URNs and extracted labels | Document |
| Rich speaker notes | Format, append, duplicate, import, independently edit and render notes pages | Document |
| Comments and anchors | Modern and legacy comments, replies, status, text/shape anchors, positions, editing and deletion | Document |
| Sections | Membership through slide changes; rename, reorder and remove | Document |
| Import slides | Single/all slides; dependency-preserving image, note, comment, layout and table-style import | Document |
| Theme palette and fonts | Color slots, accent, scheme resolution, major/minor fonts | Platform document |
| Templates and properties | PPTX/POTX/PPSX, canvas sizes and typed document properties | Platform document |
| Design system and slide builders | All 19 builders; parsed design, tokens, grid/split geometry, contrast and reusable components | [Platform design](../Lectern/Sources/LecternCore/LibraryLab/PlatformDesignRecipes.swift) |
| Media and foreign shapes | Owned valid audio/video, extraction, group transforms, connector targets, owned OLE spreadsheet preservation | [Platform assets](../Lectern/Sources/LecternCore/LibraryLab/PlatformAssetRecipes.swift) |
| ZIP, XML and package inspection | Bounded lazy reads/cache, promotion, parts/relationships, independent XML, unknown extensions and limit refusal | Platform assets |
| Extraction and honest previews | Markdown/assets/chart CSV, ordinary/strict slide SVG and notes SVG, expected strict refusal | Platform assets |

Detailed public-operation names and actual read-back expectations live beside the
executable recipes, rather than in a second implementation. Tests also assert
independent expectations for gallery counts, permutations, relationships, bytes
and extracted content. Low-level XML specimens are labeled as read/preservation
examples; they do not imply a high-level authoring API.

## What passing means

A completed demo checks repeated serialization of the same document, an unchanged
save/reopen, recipe-specific semantics, direct required-attribute lint and actual
file extraction. Independently constructed comments can have fresh GUIDs and
timestamps; the lab does not call those independently created files deterministic.

File checks and preview/export findings are separate. The report preserves issue
codes, part paths, shape IDs and slide numbers. It also records render failures.
An empty finding list is not proof of Office visual parity. Required-attribute
lint is not complete XSD validation. No existing visual acceptance threshold is
changed by this work; the remaining table, typography and notes image gates in
[the earlier record](NOTES-AND-MARKS-20261002.md) remain open.

Boundaries remain explicit: animation is excluded; SVG does not play media or
run PowerPoint's SmartArt layout engine; some chart types are approximations or
placeholders. Pyramid is experimental. Complex-script/font support remains
bounded. Licensed DejaVu faces are bundled or embedded in the native reference
decks; unavailable faces are reported instead of synthesized. Group, connector and OLE fixtures demonstrate
reading and preservation through public package/XML APIs, not new high-level
creation controls. `Slides.addBound` is internal; public builders demonstrate
its layout-binding behavior. Picture fit exposes stretch/fill; no contain mode
is invented.

Asset licenses, hashes and generation commands are in
[the fixture provenance](../Lectern/Sources/LecternCore/Resources/LibraryLab/PROVENANCE.md).

## Reproduction

From the repository root:

```sh
swift test --jobs 2
swift test --package-path Lectern --jobs 2
python3 Lectern/scripts/test-inspection-headless.py --all-app-tests
Lectern/scripts/test-app.sh -parallel-testing-enabled NO
```

To retain exactly the core pipeline's output for native Office review:

```sh
LECTERN_LAB_ARTIFACTS=/tmp/lectern-lab-artifacts \
  swift test --package-path Lectern --jobs 2 --filter LibraryLabTests.everyDemo
```

The optional output directory receives unique run folders. Ordinary tests use and
remove their own temporary directories. Tests do not read provider credentials or
modify the user's deck library.

## Paragraph-layout extension — 2026-10-03

The paragraph demo uses fixed English body text and the licensed regular DejaVu
font. User text becomes its title; sample size controls sentence count and the
alternative narrows both columns. Interior word spaces expand on wrapped lines;
final paragraph lines retain natural spacing. The second slide exercises a
justified table cell with explicit zero padding. Both public fit entry points,
owned-DOM `RichTextLayout` measurement, embedding, SVG and extraction are invoked.
Saved-file checks compare all spans, baselines, widths and styles after reopening.

The catalog and Run All action derive their count from the enum. RTL, non-Latin,
distributed and low justification remain visible support boundaries. The tab
profile is covered by the subsequent extension below.
Explicit hard line breaks can expand, while paragraph-final lines stay natural.
These layout checks do not establish general Office pixel parity. The historical
verification counts below belong to the original 23-demo implementation.

With the paragraph engine and ASCII-normalization optimization integrated,
`swift test --package-path Lectern --jobs 2` passed 231 tests in 25 suites.
That 24-demo pipeline passed 297 saved-file checks; the paragraph demo
passed 13 checks with no findings. Its focused tests cover both widths and
sentence-count bounds, actual expansion, natural final lines, unchanged-save
identity and exact reopened geometry. The added app test exercises
`LibraryLabModel → AppState.inspect → exportInspected`, verifies an expanded
space against registered font metrics, and checks exported title/table text and
the two-slide export summary. Native hosted execution of that new test and
interactive UI acceptance are recorded by the integrating task, not inferred
from these core results.

## Native paragraph boundaries — 2026-10-03

The existing paragraph demo now includes a third slide with two specific
counterexamples to raw-font-advance wrapping: twelve `m` characters followed
by `Z` at 18 pt, and four `m` characters at 18 pt followed by `mmmmZ` at 10 pt.
At widths 210.01 and 109.01 pt, native PowerPoint keeps twelve and eight `m`
characters respectively on the first line. The alternative selects widths
209.99 and 108.99 pt, moving one more `m` onto the second line. These exact line
strings come from independent PowerPoint PDF captures, not the current layout
implementation. The original title and sentence-count controls still change the
actual deck; the alternative also narrows the original paragraph columns.

The same slide shows each specimen fitted into shorter boxes through both
`Shape.fitText` and `TextFrame.fitText`. Captions expose the computed scale.
The checks distinguish externally observed unfitted line contents from computed
fit behavior: they require identical public-fit results, character/style
preservation, persisted autofit attributes, exact reopened spans and deterministic
SVG. They do **not** claim PowerPoint selected the same autofit step.

The bundled [reference subset](../Lectern/Sources/LecternCore/Resources/LibraryLab/ParagraphBoundaryReferences.json)
retains native case IDs, source/PDF SHA-256s, font identity and explicit scope.
The full independent source and measurements live in
[LineBreakBoundaries](../Tests/RostrumTests/Fixtures/LineBreakBoundaries/README.md).
The bounded examples use ASCII `m`/`Z`, regular DejaVu Sans, left alignment,
zero insets, zero paragraph margins and no indent. Their two kerning pairs have
identical independent shaping results with kerning enabled and disabled, so the
public authoring API can leave kerning omitted. Templates, inherited styles,
complex scripts and general Office pixel parity are not established by this
boundary demonstration.

The calibration requires one scalar per shaped glyph; it does not cover every
ASCII sequence. Existing fixed paragraph/tab wording changes `final` to `last`
and `field` to `column` to keep those specimens inside the demonstrated profile.
The strict-success extraction specimen similarly changes `AV office` to
`AV sample`. The engine's explicit unsupported `fi`/`ffi` coverage remains;
ordinary previews keep such diagnostics visible rather than silently claiming
calibration. Paragraph visible-width checks and numeric decimal-prefix checks
now use the shared layout's measured advances instead of raw font widths.

To retain the exact two alternative decks for native review:

```sh
LECTERN_PARAGRAPH_ARTIFACTS=/tmp/lectern-paragraph-boundaries \
  swift test --package-path Lectern --jobs 2 --filter ParagraphBoundaryRecipeTests
```

With the calibrated engine integrated, the final LecternCore run passed 236
tests in 27 suites. All 25 Lab pipelines passed 319 saved-file checks; the expanded
paragraph demo passed 22 checks with no findings. The inspector/export app test
covers both boundary alternatives and all three slide previews. A file-backed
kerning regression now distinguishes omitted, explicit zero and a reached
positive threshold, retaining the disabled-threshold comparison and exact saved
attributes. Native app, headless, iOS and interactive acceptance are recorded
separately by the integrating task.

## Common Latin word extension — fidelity4, 2026-10-04

The existing paragraph recipe retains its first three slides and adds one
two-row comparison: original size, `Shape.fitText`, and `TextFrame.fitText`.
The uniform `officeZ` row selects native case `office-edge-below` (49.74 pt,
`offic` / `eZ`) or `office-edge-above` (49.76 pt, `office` / `Z`) through the
existing alternative switch. The mixed `of` 18 pt + `ficeZ` 12 pt row remains
at the independently verified 39.01 pt width (`mixed-size-edge`, `office` / `Z`).
Its caption explicitly identifies the fixed width. User text still changes the
title and sample size still changes paragraph density on the first slide.

The bundled [reference record](../Lectern/Sources/LecternCore/Resources/LibraryLab/ParagraphLigatureReferences.json)
pins the corrected native source/PDF, font and independent kerning control hashes.
These native cases use separate letter glyphs rather than standard Latin ligature
substitutions. Standalone `TextShaper` behavior is a separate operation. Scope is
regular DejaVu Sans, left-to-right Latin, left alignment and zero insets; this
comparison does not establish other scripts, inherited styles, arbitrary glyph
substitutions, or general Office pixel parity.

Public authoring omits kerning after independent HarfBuzz controls confirmed
equivalent output for these exact three run strings. Unlike the native fixture's
`noAutofit`, the original specimen explicitly writes `normAutofit` at 100% through
`setAutoFit`. Both fitted copies retain the original run sizes and persist their
computed fit scale. Saved-file checks retain exact native line expectations,
run text/sizes/black color/tracking, omitted kerning, insets, fitting attributes,
all spans and deterministic SVG. Inspector/export coverage includes both
alternatives and all four slides. Fit scales are not native autofit-choice claims.

The prior wording substitutions (`final`/`field`/`office`) above document the
previous calibration boundary; this pass adds a controlled native common-word
specimen without inferring new tab/table behavior from it. The imported-fidelity
entry from main remains intact, bringing the catalog to 26 entries.

Retain native-review artifacts with:

```sh
LECTERN_LIGATURE_ARTIFACTS=/tmp/lectern-fidelity4-paragraph \
  swift test --package-path Lectern --jobs 2 --filter ParagraphLigatureRecipeTests
```

With the finalized native-policy engine integrated, the focused old/new paragraph
run passed 4 tests in 2 suites on its first cycle. The full LecternCore run passed
277 tests in 36 suites; all 26 Lab pipelines passed 337 checks. The four-slide
paragraph recipe passed 31 checks with no findings; imported fidelity remained
9 checks with no findings. The tab recipe retained its explicit hard-break
justification diagnostic (13 checks, 1 finding). Native app/platform/end-to-end
and PowerPoint acceptance are recorded separately by the integrating task.
Earlier counts above are historical receipts.

## Tab-layout extension — 2026-10-03

The 25th catalog entry authors standard left, center, right and period-decimal
stops through `Paragraph.tabStops` and `Paragraph.defaultTabInterval`. It uses
four numeric columns with visible guides, including an integer without a decimal
period. Sample size controls 2–12 rows per column; the alternative moves the
stops; accent changes guide and table-border color; user text changes the title.
All controls affect the actual saved artifact.

A second slide compares natural and justified Latin text following a left tab,
then repeats the justified content in a zero-padding table cell. Ordinary spaces
after the last tab expand on wrapped lines while the tab anchor remains fixed;
the paragraph's final line retains natural spacing. The body uses fixed English
and numeric text with the licensed regular DejaVu Sans face. RTL, non-Latin,
locale-specific decimal separators, distributed and low justification remain
outside the demonstrated profile. These checks do not establish general Office
pixel parity.

The recipe verifies each numeric alignment against its stop, shared table/text
geometry, diagnostic-free fitting, embedded-font recovery, public tab property
readback, exact reopened spans and byte-identical SVG for both slides. Focused
core tests exercise both row-count bounds and stop configurations; app tests run
both alternatives through `LibraryLabModel → AppState.inspect → exportInspected`
and check retained results, exported text and the two-slide summary. Native and
GUI acceptance are recorded by the integrating task rather than inferred from
core execution.

To retain the four exact bounded tab specimens for native review:

```sh
LECTERN_TAB_ARTIFACTS=/tmp/lectern-tab-artifacts \
  swift test --package-path Lectern --jobs 2 --filter PlatformTabRecipeTests
```

Each specimen receives a fresh directory; ordinary tests leave no output behind.

With the final tab engine integrated, `swift test --package-path Lectern --jobs 2`
passed 234 tests in 26 suites. A separate `--filter PlatformTabRecipeTests` run
passed all three focused tests, including both stop positions and row-count
bounds. The 25-demo file pipeline passed 310 saved-file checks; the tab demo
passed 13 checks with no findings. Native hosted app, headless, iOS and interactive
acceptance remain the integrating task's separate evidence.

## Verification record

The subsequent [template selection pass](TEMPLATE-SELECTION-20261002.md) adds a
Compose picker, template-based generation, corrected cover fitting, and two
additional layout demo checks for master ordering. The record below remains
pinned to its original implementation and artifacts.

Verified implementation: `85627ec` (the documentation/receipt commit follows).
The [machine-readable receipt](benchmarks/2026-10-02-library-lab-verification.json)
records commands/logs, artifact paths/hashes, native opening results and limits.

| Check | Result |
|---|---|
| Rostrum | 994 tests / 134 suites passed |
| LecternCore | 222 tests / 24 suites passed |
| Native hosted app | 69 tests / 17 suites passed; zero failures or skips |
| Headless app harness | 69 reported tests; three native WebKit checks explicitly skipped and covered by the hosted run |
| iOS simulator | Both arm64 and x86_64 build; final binary verified with `lipo` |
| Release library build | Passed |
| All 23 demo pipelines | 282 saved-file checks passed |
| External file checks | All 46 generated before/after/source PPTX files opened with python-pptx and passed `unzip -t` |
| Native PowerPoint 16.113.3 | All 23 result decks plus POTX/PPSX opened without repair |
| Normal Lectern app | Final **Run All** completed 23/23; every catalog entry displayed a passing checkmark |

Native Lectern actions also verified editable sample text and the alternative
merge option, before/after inspector navigation, retained results on return,
WebKit preview content and the complete artifact list. Hosted app tests exercise
file-backed table/notes/comment demonstrations through actual AppState inspection
and export, failure recovery, cancellation and retired-task completion. Linux
execution remains unavailable in this environment; cross-platform source/tests
are retained, but no Linux runtime result is claimed.

The native sweep found two real issues that structural lint missed. The owned
OLE specimen lacked its preview picture, and `ShapeCollection.addMedia` authored
an invalid `evt="onStopped"` end condition. Isolated native variants established
that the media timing caused repair; removing only the invented end condition
matches the existing independent PowerPoint fixture while retaining the media
start/target/transport structure. The OLE example now includes a resolvable PNG
preview. A native-oracle structural regression covers audio and video after
reopening. The exact integrated media result was regenerated and opened natively
without repair. No playback equivalence or animation support is inferred.

Native artifacts for the 22 unaffected recipes were generated at `ef665f5`; the
corrected media artifact and the template/slide-show extras at `85627ec`. The
receipt pins their exact SHA-256 values and confirms the source bytes were
unchanged by opening. All 23 pipelines and all external PPTX checks were rerun
at the final implementation commit. Native opening establishes file acceptance,
not pixel fidelity or third-party-deck compatibility.

Three isolated recipe workers were integrated sequentially. Drawing and document
executor requests used `gpt-6-astra`; the reused platform worker reports inherited
model provenance. Independent review requested `gpt-6.1-sol` and closed the
reported correctness findings after fixes: multiline wrapping, portable font
embedding, percentage-chart axes, missing background demonstrations, hidden
input validation, artifact access, direct lint, media timing and OLE preview.
Requested model names are recorded without asserting unavailable runtime identity.

The new resource bundle exposed a macOS signing configuration gap. Both canonical
build/test scripts now pass manual signing and the existing configured identity
(or the previous ad-hoc default) consistently to the app and SwiftPM resource
bundle. Hosted tests and normal app launch passed with that configuration.

No existing tests or visual thresholds were weakened. No push, pull request,
merge, release publication or deployment occurred.



## October 4 paragraph fidelity continuation

The catalog now contains 26 recipes; this pass adds a fourth slide to the
existing paragraph recipe. It compares native-measured common Latin word wraps
with both `Shape.fitText` and `TextFrame.fitText`, using a bundled regular font.
The width toggle changes the officeZ row from 49.76 to 49.74 pt while preserving
the mixed 18/12 pt row at 39.01 pt. Both computed fits retain run sizes and save
77.5% scale. Computed scales are explicitly distinguished from native choices.

At source `5860a71`, all 26 pipelines pass 337 checks and all 52 result/source
PPTX files pass ZIP integrity and independent python-pptx reopening. The paragraph
recipe passes 31 checks with zero findings; the pre-existing tab hard-break
warning remains visible. The full local gate passes, including 277 Core tests,
76 native app tests with zero skips, and macOS/iOS simulator builds. The separate
headless app run reports 76 tests with three native WebKit skips, covered by the
native gate. Both paragraph alternatives reach the actual inspector and export
path in tests and manual GUI verification with an edited title.

PowerPoint opens both embedded-font specimens without repair. Local PDF exports
and source hashes confirm the new six-box slide in each variant: the original
uniform word wraps at the expected boundary, the original mixed-size word wraps
as office / Z, and the four fitted boxes each keep officeZ on one line. This is
bounded evidence, not a claim of native-selected autofit or general raster parity.
See the [fidelity record](LAYOUT-FIDELITY-20261004-4.md) and
[integration receipt](benchmarks/2026-10-04-fidelity4-integration-verification.json).

The subsequent SVG serialization reconciliation is verified at `f8b33ee`.
All gates and 337 Lab checks pass again; 76 native tests have no skips. Both
manual variants were regenerated and visually rechecked in the rebuilt app,
with byte-identical PPTX files to the earlier exported variants. Native
PowerPoint acceptance remains valid through exact saved-file and effective
SVG-policy/geometry identity, without claiming a new native autofit oracle.

After incorporating main's font/adjacency fixes in `2953dc1`, the complete gate
passes with 1,109 library tests and unchanged Core/app counts. All 337 Lab checks
and 52 external reopens pass again. The paragraph recipe's four SVGs and both
saved width variants remain byte-identical across that merge. See the
[latest integration receipt](benchmarks/2026-10-04-fidelity4-merged-integration-verification.json).


### Explicit preview fallback (2026-10-04)

Extraction and honest previews now exercises `FontLibrary.previewFallbackFamily` with the bundled licensed DejaVu Sans face. The unavailable family remains in the PPTX and exact registry lookup stays nil. Measurement and SVG drawing use the selected registered fallback, strict rendering still refuses the missing-font issue, and reapplying the choice after reopen reproduces the same preview. This does not claim font substitution matches native PowerPoint.


At final merge `a47d94b`, the new fallback recipe raises the total to 339 checks
across the same 26 recipes. The fresh full gate passes 1,111 library, 277 Core
and 76 native app tests (zero native skips). All 52 decks reopen independently;
the four paragraph SVGs and both saved variants remain byte-identical. See the
[final receipt](benchmarks/2026-10-04-fidelity4-preview-fallback-integration-verification.json).

### Empty-line typography (2026-10-04)

The paragraph demonstration now has five slides and 40 saved-file checks. Its
new slide imports independently constructed DrawingML with consecutive manual
breaks and a trailing break whose paragraph-end style differs from its visible
text. The alternative switches blank-line typography from 6 to 36 pt. Original
markers are compared with independently captured PowerPoint baselines; both
public fitting APIs show the same text and their computed scale in shorter boxes.
The exact imported paragraphs, list defaults and autofit attributes survive
saving and reopening. This uses the public owned-DOM import path; there is no
new high-level manual-break authoring API.

The [reference subset](../Lectern/Sources/LecternCore/Resources/LibraryLab/ParagraphBreakReferences.json)
pins the [native source and PDF](../Tests/RostrumTests/Fixtures/NativeBreakMetrics/README.md).
Both PowerPoint demonstration variants open without repair. Their 24 visible
marker glyphs match the licensed font outlines; original baselines are within
0.121 pt of the rounded library layout, and both fitted copies stay inside their
boxes with equal native positions. The display frame is shorter than the source
oracle but retains top alignment and ample height. Native-selected autofit and
general pixel parity are not established. Exact and percentage spacing remain
separate, explicitly recorded fidelity gaps.

The final caption uses ASCII punctuation so the demonstration itself stays
inside its declared calibrated profile. Its saved/reopened slide preview is
required to have no diagnostics. At integrated source `a98dd69`, the complete
local gate passes 1,123 library tests (four known spacing assertions), 18 layout
tests, 279 Core tests and 76 native app tests with zero native failures or skips.
The catalog remains 26 recipes; the current evidence is recorded in the
[integration report](LAYOUT-FIDELITY-20261004-5.md).

## Explicit spacing and anchors — October 4

The paragraph demo now includes six slides. The final slide selects six of 12
independent native specimens: exact/percentage spacing and compatibility modes
by default, stored font-scale/reduction and anchors in the alternative. Both
options pass 54 checks with no preview findings, retain exact imported text-body
properties, and pass the actual inspector/export flow. The complete catalog now
passes 362 checks across 26 recipes. Native PDF geometry, both manual app runs,
56 external reopens, and all support limits are recorded in the
[explicit-spacing integration report](LAYOUT-FIDELITY-20261004-6.md).

## October 4 glyph reservation integration

At `051cf5b`, the rebuilt app retains all 362 checks across 26 Lab recipes and
passes the actual inspector/export tests. Independent validation reopens 56
files/199 slides and confirms all 302 external inputs unchanged. The paragraph
demo still passes 54 checks with zero findings; both six-slide options are
byte-identical to the preceding PowerPoint-accepted exports. Previous manual
GUI/native evidence transfers by that identity; no fresh manual capture is
claimed. See [the integration report](LAYOUT-FIDELITY-20261004-7.md).

## October 4 line-break reuse integration

At `7fbb9bc`, all 362 checks across 26 recipes and rebuilt native inspector/export
tests pass. Independent external checks reopen 56 files/199 slides and retain
all 302 input hashes. Both six-slide paragraph exports exactly match their
prior native-accepted sources; 54 paragraph checks pass without findings.
The [integration report](LAYOUT-FIDELITY-20261004-8.md) preserves the distinction
between fresh automated app tests and transferred prior manual/PDF evidence.
The seventh glyph-placement slide remains a separate, unintegrated draft.

## October 4 native glyph painting integration

The paragraph recipe now has seven slides and 74 passing checks with no preview
findings. Its 12 original/scaled regular DejaVu specimens preserve native source
bodies and frames; separate copies exercise both public fit APIs. Exact saved
inspector SVGs pass actual WebKit PDF outline/origin checks, and both paragraph
variants have fresh PowerPoint PDF evidence. Cell appearance adds a third slide
for explicit table context and live, nonmutating cell fitting; its ignored-scale
diagnostic is retained. The catalog remains 26 recipes with 387 passing checks
and 411 reported findings. All 60 external reopens / 225 slides pass.

The [integration report](LAYOUT-FIDELITY-20261004-9.md) retains the initially
failed cross-profile assertions, invalid concurrent app rerun, final passing
serial app tests and all source pins. Default table opening succeeded, but table
PDFs/alternative opening, current manual Lectern runs and a separate new bullet
capture remain pending. This checkpoint does not claim their native acceptance
or native-selected autofit.

## October 4 ordered atom integration and Unicode app coverage

The existing Fonts and fitting recipe now has an actual app-hosted test for
composed/decomposed accented text and `ffi`, at both widths. It verifies exact
UTF-8 preservation through saved-body reopen and export, embedded font bytes,
actual saved-inspector preview identity and visible non-native limitations.
The recipe/UI and 26-entry catalog are unchanged; no native Unicode parity is
claimed. The full gate passes 80 app tests / 110 executions, followed by this
separate one-test / two-case run.

All 387 Lab checks, 60 external reopens / 225 slides and 313 input hashes pass.
Fresh WebKit proof covers 14 cases / 208 glyphs. Both native table page-three
specimens now pass 30-glyph checks at unchanged tolerances, with current sources
and SVGs identical to the accepted inputs. Current manual Lectern demos and new
bullet capture remain pending. The [integration report](LAYOUT-FIDELITY-20261004-10.md)
records those boundaries, retained failures and the bounded performance result.

## October 4 live table-cell fitting integration

The existing table-appearance demo exercises the optimized live text-style
resolution without changing its public behavior, UI or catalog entry. Both
variants now also pass manual Run Demo → inspector → folder export in the exact
built app: 20 checks / three slides / seven findings each, exact exported cell
text and unchanged source bytes. Slide-three XML equals the verified gate;
manual and raw SVGs match after only their root viewport dimensions are aligned.
No raw SVG or whole-package identity is claimed for those manual artifacts.

The whole local gate now includes the Unicode fitting app test: 81 app tests /
112 executions pass, alongside 1,155 library, 18 layout and 286 Core tests.
All 387 checks across 26 Lab recipes and 60 external reopens / 225 slides pass.
Fresh WebKit proof covers 208 glyphs; prior paragraph and both table-page native
proofs transfer by exact specimen identity. Other manual workflows and the
separate new bullet correction remain pending. See the
[integration report](LAYOUT-FIDELITY-20261004-11.md) for retained diagnostics,
comment-metadata differences and bounded fitting-performance evidence.

## October 4 fidelity13 manual paragraph completion

Both paragraph options now complete the actual Run Demo → inspector → native
folder-export workflow: 74 checks, zero findings, seven loaded previews and seven
exported slides each. All 165/169 source text nodes survive narrowly specified
Markdown unescaping. Sources remain unchanged from after inspection through
export. Comparison with the gate retains four slide-one text changes and, on
slide seven, the root viewport plus 18 empty-text transforms; painting nodes and
remaining XML are exact, without a raw SVG identity claim. The
[manual addendum](LAYOUT-FIDELITY-20261004-11-MANUAL.md) pins the independently
approved evidence and completed hosted checks. Marker correction remains separate.

## October 4 List markers integration

List markers is the 27th runnable recipe: 24 native specimens occupy four
preserved slides, with a fifth slide comparing both computed fit APIs. Each
option passes 58 checks without findings. Both generated decks opened natively
without repair; independent comparison preserves all 277 glyphs and three
explicit absent markers per option. The fifth computed-fit page remains outside
numerical native/autofit-choice acceptance.

The final complete gate passes 83 app tests / 115 executions, plus 1,165 library,
18 layout and 288 Core tests. All 445 Lab checks and 64 external reopens /
243 slides pass. Fresh actual inspector WebKit PDFs verify 48 marker cases /
554 glyphs / six omissions, alongside 14 prior-profile cases / 208 glyphs.
Both manual demo → inspector → folder-export workflows pass with five loaded
previews and all 60 source text nodes retained per option. The
[integration report](LAYOUT-FIDELITY-20261004-14.md) preserves the initial viewport
assertion failure, corrected exact inspector comparisons, metadata-only comment
differences and historical app-binary observation. Marker performance is an
accepted bounded fidelity tradeoff with residual ordinary/placeholder costs;
cycle one remains withheld. The next alignment probe is separate future work.

## October 4 text alignment and performance integration

The 28th recipe, Text alignment, exposes 24 native center/right specimens with
172 visible glyphs. Both options add a fifth computed-fit comparison and pass
60 saved-file checks, retaining two expected table-scale findings. Fresh
PowerPoint and exact inspector WebKit extraction validate the original four
pages; computed fitting remains outside native autofit-choice acceptance.
Both real inspector/export workflows retain all 64 text nodes and exact saved
previews. The complete catalog passes 505 checks across 28 recipes, with 413
findings retained. See the [integration report](LAYOUT-FIDELITY-20261004-15.md)
for unchanged bounds, full macOS/iOS validation, external reopens and the next
observed table appearance gap.

The List markers recipe now parses each page once for all native checks. A
separate frozen experiment measures roughly 51% faster complete headless runs
and 67.648 MiB lower paired peak process RSS for both options, with exact
artifacts and check results. This does not establish GUI latency; see the
[performance report](LECTERN-MARKER-PERFORMANCE-20261004-15.md). A separate
[ordinary text rendering experiment](RENDER-INHERITANCE-PERFORMANCE-20261004-15.md)
records bounded improvements and preserves unresolved fallback costs.

## October 4 mixed-face exact spacing integration

The 29th recipe, Mixed faces and exact spacing, retains 12 native specimens /
96 glyphs on two pages and adds a third computed-fit comparison. Both options
pass 37 checks without findings; the alternative changes only the computed
copies from top to bottom anchoring. Distinct actual fonts must have equivalent
vertical metrics within the admitted shape/exact-spacing profile. Both public
fitting APIs compute 100% scale and zero reduction in the 40 pt frame; this is
not a claim about PowerPoint's autofit choice.

The full local gate passes 1,174 library, 18 layout, 292 Core and 87 app test
definitions / 121 executions. The catalog passes 542 checks across 29 recipes,
retaining 413 findings. Independent native extraction passes 24 cases / 192 glyphs
across both generated options at unchanged bounds; 64 external package reopens /
224 slides pass. Fresh exact-inspector WebKit extraction also passes all
24 mixed-face cases / 192 glyphs, alongside alignment, marker and paragraph
regression controls at unchanged bounds. Both real demo → inspector → folder-export
workflows show three loaded previews and retain all 73 source text nodes per
option, unchanged source bytes and exact app-gate previews. Independent performance
review accepts a bounded fidelity cost, preserving the adverse fitting and
combining-text intervals without an optimization or nonregression claim. See the
[integration report](LAYOUT-FIDELITY-20261004-16.md) for the complete evidence and
unchanged support limits. The separate table appearance gap remains unfixed.

## October 4 table defaults and unequal joins integration

The 30th recipe, Table defaults and border joins, retains 12 native specimens /
72 glyphs on three pages and adds a fourth public-API style comparison. Both
options pass 63 checks with zero findings. Import preserves absent applied
styles even when source and destination insertion defaults differ. Unequal
border joins are corrected for the captured opaque, solid, unmerged LTR scope.

The full gate passes 1,180 library, 18 layout, 295 Core and 89 app test definitions /
124 executions, including macOS and iOS simulator builds. All 30 catalog recipes
pass 605 checks and retain 413 findings. Independent external checks reopen
72 packages / 247 slides. Both generated PowerPoint references and six fresh
saved-inspector WebKit PDFs pass 24 case comparisons / 144 glyphs each, with
typography regressions also passing at unchanged bounds. Both real four-slide
inspection/export workflows preserve source bytes, exact previews and all 37
source text nodes per option.

The [integration report](LAYOUT-FIDELITY-20261004-17.md) and separate
[performance report](TABLE-DEFAULT-JOINS-PERFORMANCE-20261004-17.md) retain the
native scope, observed costs, faster absent-style cases and background-load
limitations. The public comparison also exposes a remaining partial custom-style
missing-edge fallback gap. The successful file checks do not assert full custom
style or whole-slide native parity.

## October 4 RTL, color and merge profile integration

The 31st recipe, Table join profiles, preserves eight native specimens and
112 glyphs on two pages, then demonstrates public RTL, axis-color and merge
APIs on a third. Its option changes only the public merge orientation. Both
variants pass 44 saved-file checks with no findings.

The local gate passes 1,183 library, 18 layout, 298 Core and 91 app test
definitions / 127 executions, with successful macOS and iOS simulator builds.
All 31 catalog recipes pass 649 checks and retain 413 findings; four additional
table pipeline executions pass 214 checks. External checks reopen 80 packages
and 268 slides. All 34 prior reference SVGs are byte-identical.

Both generated PowerPoint decks and fresh exact-inspector browser captures pass
16 case comparisons / 224 glyphs each at 0.025 pt x/y, with complete ordered
border coverage and crossing checks. Both manual three-slide workflows preserve
source bytes, exact app-gate previews and all 52 source text nodes per option.
The public third page remains separate from numerical native acceptance.

The [integration report](LAYOUT-FIDELITY-20261004-18.md) records the bounded
admission rules and retained parser history. The separately measured performance
intervals for all newly admitted targets include zero; speedup and universal
nonregression are not established. Independent performance and final integration review pass. Custom-style missing-edge defaults are the next
independently captured gap.
