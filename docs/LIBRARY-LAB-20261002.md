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
| 178 shape presets | Complete enum gallery; frame, rotation, naming and rounded corners | [Drawing](../Lectern/Sources/LecternCore/LibraryLab/DrawingLabRecipes.swift) |
| Fills, outlines and shadows | Solid/alpha/theme/none/linear/radial/image fills; every dash and compound line; shadow | Drawing |
| Rich text and live fields | Runs, paragraphs, list numbering/bullets, margins, alignment, spacing, tracking, superscript/subscript, links and fields | Drawing |
| Fonts, shaping and fitting | Licensed bundled font; exact face lookup, measure/wrap/shape/fit; embed and recover bytes | Platform document |
| Paragraph spacing and justification | Side-by-side mixed-size left/justified paragraphs; adjustable sentence count and width; both fit APIs; embedded-font recovery; exact span positions after reopening; shared table-cell layout; native-captured narrow wrap boundaries and public fitting across styled runs | [Platform paragraphs](../Lectern/Sources/LecternCore/LibraryLab/PlatformParagraphRecipe.swift) |
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
bounded. Only the licensed regular DejaVu face is bundled, with unavailable faces
reported instead of synthesized. Group, connector and OLE fixtures demonstrate
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
