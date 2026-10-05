# PowerPoint composition acceptance

Run the production renderer offline. The fixture contains editable metrics, a process,
a cycle, a pyramid, a timeline, a quadrant, bands, a native chart/table, a comparison, and an edge-labeled image-fit fixture.
It makes no model calls and includes no API keys.

```
swift run -c release --package-path Lectern CompositionRegression /tmp/composition \
  /path/to/Contoso.potx /path/to/private-template.potx Lectern/App/Resources/Styles/serif.md
```

Pass `--replay /path/to/deck.json` to replay DeckIR or a protected RenderSnapshot,
including its saved images. This is how a failed real deck joins the corpus without
checking private content, artwork, or commercial templates into Git.

Each run emits one deck per style and a JSON manifest. `renderSeconds` measures the
production renderer including package writing/previews, excluding snapshot storage.
It also excludes the subsequent exported-content check. `structuralStatus` passes
only when schema checks, dropped-content diagnostics and `contentCheck.issues` are
empty. A failure exits nonzero after writing the manifest.

`RenderContentCheck` opens the saved PPTX through Rostrum and checks visible text
within each original slide's continuation/source-note group. Text on another slide
or in speaker notes cannot hide a missing visible fragment. Speaker notes are checked
separately; native chart categories, series and values and native table cells must
match the input. Text uses ordered word matching to allow repeated headlines between
continuations; it does not prove exact formatting, duplicate counts or fragment
placement. Images and visual fit still require the native review below.

Use Release, the same machine/fonts and identical inputs when comparing performance.
Each manifest starts at `needs-powerpoint-review`; no structural test can mark it
visually accepted.

Open every deck in Microsoft PowerPoint. Inspect each slide in Slide Show, then export
JPEG/PNG slides for a durable baseline, or export a local “Best for printing” PDF
and rasterize its pages at a fixed scale. Record which export path was used. Check title wrapping, body hierarchy, label
legibility, unused columns, cropped image text, object/source separation, footer
collisions and contrast. Confirm editable native charts/tables and the selected master
in Normal/Slide Master view. Imported master/layout/theme XML must remain unchanged.

Record an acceptance entry with deck SHA-256, PowerPoint version, slide numbers,
font substitutions, reviewer, result and exported-image directory. Compare to the
previous approved export at the same dimensions; inspect any changed pixels rather
than auto-accepting by a numeric similarity threshold. A missing export or unreviewed
slide remains unreviewed. LibreOffice and Rostrum SVG are diagnostic previews only.

For recovery acceptance, open the saved snapshot through Lectern's last saved content
or finished-deck controls. Preview another layout, save a revised copy and confirm the
original deck and untouched slide XML/relationships are unchanged. Render snapshots
contain user content; app diagnostics expire after seven days. Regression output is
explicitly user-owned test material and should be kept outside version control.

`compare_exports.py` (Python + Pillow) records explicitly reviewed exports and compares
subsequent PowerPoint exports. It checks complete slide coverage, image dimensions and
baseline hashes; changed images produce difference PNGs and a nonzero exit for review.

```
python3 Lectern/Tools/CompositionRegression/compare_exports.py record deck.pptx exports baseline.json \
  --reviewer 'Reviewer name' --powerpoint-version 'Installed version' --reviewed-slides 1,2,3
python3 Lectern/Tools/CompositionRegression/compare_exports.py compare baseline.json new-exports differences
```

Keep both the baseline manifest and its referenced exports together. Pixel changes
require inspection, even when the numerical difference is small. Identical pixels mean
only that the slide matches the reviewed baseline, not that the original design is good.

## Dense authored-content acceptance

The renderer can expand dense authored text, comparison and image slides into
continuation pages. Source notes that exceed footer space follow their supporting
slide at body-text size. This intentionally permits more output slides than the
input IR; warnings explain each expansion. Template output retains its separate
template-aware composition path.

For saved-content replay, check every original fact, chart label, image and source
in the output, and check that continuation pages stay in the correct section.
Recovery must retain all pages and existing comments. Page-count reduction during
single-slide recovery is rejected to avoid deleting review work or breaking links.
Select **Rebuild the entire deck from saved content** to create a fresh copy with
a different page count. Edits and comments made after generation remain only in the
original deck. The recovery preview shows the resulting count and layout adjustments.

Passing schema checks and content comparisons does not establish visual quality.
Inspect the final exports in PowerPoint before marking a manifest reviewed.
