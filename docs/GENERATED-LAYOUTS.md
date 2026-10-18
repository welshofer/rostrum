# Generated layouts and advanced tables

Available on `main` after 1.0.0. Lectern's generation schema and prompts now expose
23 layouts. The same saved content drives authored designs, supplied templates,
recovery, saved-deck Inspect and export. Rostrum and RostrumLayout remain portable,
pure Swift and dependency-free.

## Three new compositions

| Layout | Content | Arrangement |
| --- | --- | --- |
| `cards` | 2–4 `panels` | Two-column card grid with individual accent rules |
| `threeColumn` | Exactly 3 `panels` | Open columns for parallel pillars or alternatives |
| `numberedSteps` | 2–4 `panels` | Numbered rows, headings beside explanations |

All use the same semantic body:

```json
{
  "id": "priorities",
  "layout": "threeColumn",
  "title": "Three priorities guide the work",
  "body": {
    "panels": [
      {"heading": "Fidelity", "detail": "Keep native content editable."},
      {"heading": "Performance", "detail": "Measure fixed workloads."},
      {"heading": "Layout", "detail": "Give every word room."}
    ]
  }
}
```

Choose layouts for the content, not to meet a variety quota. Existing slides keep
their selected layouts. These new compositions do not accept image briefs. Their
headings and details remain native editable text, with caller-selected typefaces.
`PanelLayout` uses 22-point headings and 18-point details scaled to canvas height;
it measures complete text before writing shapes. The library's strict panel
composer reports content that cannot fit. Lectern handles that result: four
crowded cards first try two roomier card slides; otherwise panels flow into
full-width headed text, with measured continuation pages as needed. Long details
retain their headings on each page, and numbered steps keep their original
numbers. Leads and sources can flow too. No model call or summarization is involved.
Already-fitting arrangements stay unchanged. A supplied template provides the
text layouts for reflow; its masters, layouts and artwork remain unchanged.
Template continuations retain the existing body-text scale instead of applying
additional shrink-to-fit. Rejected generated slide-number fields receive explicit
single-line spacing so a design's caption spacing cannot abort a completed deck.
An impossible headline or a template with no readable text region can still
report a fitting error.

Applications can use `PanelKind`, `StructuredItem` and `PanelLayout.frames`,
`validate` and `compose` directly in `RostrumLayout`. Pass the same
`TemplateLayoutEngine` and `DeckStyle` to preflight and compose. Font registration
and the optional host measurement policy stay with the caller. Fresh composition
remeasures current text and fonts; there is no persistent fit cache.

## Advanced table fields

`IRTable` keeps its required `headers` and `rows`. Three optional fields add
structure without changing existing plain-table input:

```json
{
  "headers": ["Group", "Measures", ""],
  "additionalHeaders": [["", "Before", "After"]],
  "rows": [["Team A", "12", "18"], ["", "14", "20"]],
  "merges": [
    {"row": 0, "column": 0, "rowSpan": 2, "columnSpan": 1},
    {"row": 0, "column": 1, "rowSpan": 1, "columnSpan": 2},
    {"row": 2, "column": 0, "rowSpan": 2, "columnSpan": 1}
  ],
  "textDirections": [{"row": 0, "column": 0, "direction": "vertical270"}]
}
```

Coordinates index the **complete zero-based grid**: `headers`, then
`additionalHeaders`, then `rows`. In this example body rows start at index 2.
`IRTable.headerRowCount` and `grid` provide the combined view. Directions are
`horizontal`, `vertical` (90°), or `vertical270` (270°). Set directions only on
visible cells or merge anchors. Omitted cells remain horizontal.

Merges must be nonoverlapping rectangles within the grid. Covered cells must be
empty; the renderer never discards their words. A merge cannot cross the
header/body boundary. All header rows repeat on each page, including header
merges and directions. Connected body-row groups stay together. Oversized groups
and headers refuse rather than split or squeeze their text. Native first-row
styling still applies only to the first row; extra header rows are not automatically
restyled. Stacked/complex vertical writing and native table autofit remain outside
this generated path.

The renderer uses measured column widths and reserves caption space. It remaps
merge anchors and directions to each continuation's local row indices. Saved
snapshots retain the original source coordinates, so recovery and a whole-deck
rebuild reproduce the same structure. Existing recovery rules still protect page
identities and comments; a shorter single-slide alternative cannot delete reviewed
continuation pages.

These are additive `lectern.deck/1` fields. Existing JSON decodes without them and
omits them when re-encoded. **Consumers must adopt the new fields before rendering
advanced tables or the new layouts**; an older consumer that ignores metadata
cannot reproduce the intended structure.

## Run it after pulling

From the repository root:

```sh
Lectern/scripts/test-layouts.sh
```

This runs the focused production regressions, then creates a Release review pack
without model calls or credentials. It writes editable PPTX, saved SVG previews,
ordered diagnostics, source snapshots, timing stages and a manifest. The output
directory must be new. To use your own template or design:

```sh
Lectern/scripts/test-layouts.sh /tmp/lectern-layout-review /path/to/brand.potx
```

The `crowded-panels` subdirectory contains deliberately dense cards, columns and
steps that previously stopped the whole deck. Check continuation order, headings,
step numbers and sources along with the ordinary layout pack.

If an earlier build rejected your deck, rebuild Lectern and use **Recover Saved
Content…** to open its saved content. Recovery uses the corrected renderer without
another generation request. Keep the `render-session-*.json` when available: it
also retains the design, images and template. The `rejected-draft-*.json` retains
the text and can be rendered with a selected design or template. A command-line
replay of that raw draft is also available:

```sh
swift run -c release --package-path Lectern CompositionRegression \
  /tmp/lectern-recovered --replay /path/to/rejected-draft.json /path/to/design.md
```

The lower-level runner is `CompositionRegression OUTPUT --layouts`. The fixture
comes from `LibraryLab.generatedLayoutExample()`. In the app, Library Lab →
**Generated layouts and advanced tables** offers 16:9 and 4:3 cases, saved JSON,
reopened checks and Inspect/export. Its synthetic examples use ordinary host font
resolution; they impose no font choice on library users.

Register or install the intended faces, or use a template containing valid
embedded faces. Missing-font diagnostics are not visual acceptance. The supplied
Calibri review templates used for development stay outside Git, including their
proprietary font bytes. Portable raster previews explicitly resolve SVG embedded
face aliases to these exact fonts for resvg; they are not PowerPoint screenshots.

Tests cover malformed metadata, anchor remapping, preserved source words, native
merges/directions, both canvas ratios, deterministic saving, recovery, Inspect and
export. `RenderContentCheck` detects lost table topology/directions as well as
changed cells. PowerPoint slide-view and PDF-export acceptance of these new
compositions remains separate from the earlier accepted table packs.
