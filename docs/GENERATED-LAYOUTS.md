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
it measures complete text before writing shapes. Oversized panels refuse with a
fitting error: they do not truncate, paginate, or silently shrink. A supplied
template must offer a compatible object region. Masters, layouts and artwork
remain unchanged.

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
