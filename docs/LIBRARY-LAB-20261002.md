# Lectern Library Lab — 2026-10-02

Library Lab makes Rostrum's shipped capability families runnable in Lectern
without a provider, account, network request or external document. Open the
**Library Lab** sidebar item, choose a demonstration, change its declared inputs,
and select **Run Demo** or **Run All 23 Demos**. Inspect the saved result or the
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
| Layouts and placeholders | Layout lookup, cloned placeholders, layout-bound builders, effective inherited frames and masters | [Platform document](../Lectern/Sources/LecternCore/LibraryLab/PlatformDocumentRecipes.swift) |
| 178 shape presets | Complete enum gallery; frame, rotation, naming and rounded corners | [Drawing](../Lectern/Sources/LecternCore/LibraryLab/DrawingLabRecipes.swift) |
| Fills, outlines and shadows | Solid/alpha/theme/none/linear/radial/image fills; every dash and compound line; shadow | Drawing |
| Rich text and live fields | Runs, paragraphs, list numbering/bullets, margins, alignment, spacing, tracking, superscript/subscript, links and fields | Drawing |
| Fonts, shaping and fitting | Licensed bundled font; exact face lookup, measure/wrap/shape/fit; embed and recover bytes | Platform document |
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

## Verification record

Integration verification is in progress; final receipts will be recorded here.
