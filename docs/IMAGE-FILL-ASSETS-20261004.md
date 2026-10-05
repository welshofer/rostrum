# Image-fill resource inventory

The Cell appearance recipe owned an 84-byte PNG through table-cell and custom-style fills but had no picture shapes. `outline()` returned no image assets, so `DeckExport.write` wrote no media. The new inventory includes selected image-fill resources and writes their original package bytes.

Existing picture, video and audio ordering is retained. Their filenames, and chart filenames, are allocated before newly discovered fill-only assets. Images deduplicate by their actual package part within each slide, with the existing case-insensitive filename allocator. A picture's existing alt text wins when the same part also fills a shape or cell. Fill-only assets use the first selected owner's description when available.

Selection follows direct cell overrides and active table-style regions, inline/package styles, theme fill references, table backgrounds, direct shape fills, matched placeholder inheritance, selected slide/layout/master backgrounds and active layout/master furniture. Explicit noFill blocks inheritance. Disabled style regions, fully overridden fills, unrelated placeholder templates, unused group fills and unused package media are excluded. A descendant's explicit grpFill selects its containing group's resource with that group's relationship owner. This is resource extraction, not an assertion that the current SVG preview paints every group-fill inheritance or that selected resources remain visible after occlusion.

Table inventory uses a fill-only operation-local session: bounded region signatures reuse selected nodes and owners without building effective border/text properties per cell. Direct fills remain live; valid merge continuations are skipped, and invalid topology follows the renderer's ordinary-cell fallback. Ordinary tables share source nodes; structurally aliased DrawingML tables use a detached normalized view. Namespace-aware fill and relationship selection retains ancestor bindings, including local shadowing and rejecting lookalike namespaces. All state is discarded after the outline operation.

Missing, malformed and external selected image references produce deterministic warnings including slide number, owning part and location. External references are never fetched. Ordinary malformed pictures are also diagnosed instead of exporting unrelated targets. Existing video/audio poster selection remains unchanged. Unknown extension payloads are preserved rather than searched for arbitrary image relationships. No package media scan, image transcoding, layout correction or runtime dependency is introduced.

## Evidence

The primary public-API regression uses the exact Cell appearance PNG, SHA256 `0b090deb14404ac5d5c245d2633c69c7a988867ec37de2b35a81d14ecfd51e76`. Before implementation, four inventory/export assertions failed. The corrected test reads the on-disk exported file and verifies exact source bytes, repeated outline, reopened outline and serialization purity.

Headless export was also run against both original root S20 generated files:

- Default PPTX: `b7351a492cd0b3e9d0c29f2dec5ff4d6eb1954b92e05cf343c7d77929ee4022b`.
- Alternative PPTX: `b53025b0f1de83b4febb9e4844b5a6fc12273f25acd1f1e32df28f28b7cf5834`.

Each produces `slide-01/image1.png` and `slide-02/image1.png`, one 84-byte copy per slide from the single package image. Both copies have the PNG hash above. Source PPTX bytes remain pinned; outline warnings are empty; reopening and repeating the export produces identical files. This is a post-change headless `DeckExport.write` proof, separate from the parent's earlier visible application workflow and any later application acceptance.

Focused regressions cover direct/selected/overridden/disabled/inline/theme/style fills, table backgrounds, actual owners with colliding relationship IDs, ancestor namespace bindings, valid aliases and lookalikes, explicit noFill, matched placeholders, unused groups and active furniture, merged and malformed grids, deterministic relationship warnings, picture ordering and alt text, case-insensitive filenames, repeated export and save/reopen purity. Source and evidence receipts accompany the frozen implementation; formal performance measurements and application integration remain separate gates.

Final library validation passed 1,207 tests in 176 suites plus 18 layout tests in 3 suites; focused inventory/export validation passed 30 tests in 2 suites. [The machine receipt](IMAGE-FILL-ASSETS-20261004.json) pins current source files, logs, the retained candidate object and helper, original decks, and exact exported files. The earlier failed fixture-authoring attempt is retained separately and described in that receipt.
