# PowerPoint composition acceptance

Run the production renderer offline. The fixture contains editable metrics, a process,
a cycle, a pyramid, a timeline, a quadrant, bands, a native chart/table, a comparison, and an edge-labeled image-fit fixture.
It makes no model calls and includes no API keys.

```
swift run -c release --package-path Lectern CompositionRegression /tmp/composition \
  /path/to/Contoso.potx /path/to/welshofer.potx Lectern/App/Resources/Styles/serif.md
```

Pass `--replay /path/to/deck.json` to replay DeckIR or a protected RenderSnapshot,
including its saved images. This is how a failed real deck joins the corpus without
checking private content, artwork, or commercial templates into Git.

Each run emits one deck per style and a JSON manifest. `renderSeconds` measures the
production renderer including package writing/previews, excluding snapshot storage.
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

## Current acceptance limits

The October 2026 pass exercised the supplied templates and a generated serif theme,
including live Lectern import, preview and revised-copy saving. PowerPoint review
identified and drove fixes to cycle routing, table row heights and headline hierarchy.
Final canvas-scale refinements still require PowerPoint review; the review machine
locked before that pass could finish. Generated manifests remain unreviewed.

Dense authored text-and-image slides can still exceed the readable fitting limit.
They fail explicitly instead of dropping text; measured continuation-slide pagination
is the next work item. The climate replay succeeds with both supplied templates, but
its serif-theme version still exposes this limit. Missing fonts are reported separately.
