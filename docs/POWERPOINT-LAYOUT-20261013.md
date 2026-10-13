# PowerPoint layout review — 2026-10-13

The user reviewed the nine exported sample decks in PowerPoint for Mac and
reported overlapping glyphs, clipped text and tables running off slides. Their
`Rostrum-Lab-4x3.pdf` and `Planned-Tables-16x9.pdf` exports provide native
evidence. These private review files remain outside version control.

## Findings and repairs

1. **Template text was clipped.** The original template body has a 155 pt
   height, 8 pt paragraph-after spacing and three tabular lines. Its writer
   placed LF characters inside a single `a:t`. In the native PDF, consecutive
   tabular baselines are about 35.3 pt apart, versus about 28 pt in the planned
   SVG. PowerPoint treats those literal line feeds as paragraph boundaries,
   adding the paragraph spacing. The final bullet extends past the body's
   clipping edge. `TemplateLayoutEngine` and `fillPlaceholder` now write
   `a:br` for line endings within an explicit paragraph. Character styles are
   retained on each fragment and break; paragraph boundaries remain explicit.
   CR and CRLF normalize to LF in the plain-text view.

2. **The title style was implicit.** The old generated master omitted
   `p:txStyles`. PowerPoint exported the table title at approximately 44 pt,
   while the planner and SVG renderer used their generic 18 pt fallback.
   New masters declare their title/body/other styles. Missing title styles in
   legacy masters resolve the observed 44 pt fallback without changing the
   imported XML. Explicit master and layout styles retain precedence. The
   table Lab's authored template declares a 32 pt title, shared by its table,
   pagination, measured-column and horizontal-span examples on both canvases.

3. **Plain-text reads lost soft breaks and fields.** `TextFrame.text` used to
   concatenate ordinary runs, dropping `a:br` and cached `a:fld` values. It
   now uses the existing ordered `Paragraph.plainText` reader. The setter's
   single-paragraph/run behavior is unchanged; imported XML is never rewritten
   just to read text.

4. **Glyph overlap is specific to slide view in this report.** The user
   confirmed the overlap disappears on PDF export. Both supplied PDFs have
   correctly positioned glyphs. The widescreen PDF also wraps the final table
   row differently from the overlapping slide-view screenshot. This does not
   establish a defective font file or a universal PowerPoint bug. Font bytes,
   font registration and embedding are unchanged. The slide-view discrepancy
   remains unresolved and must be assessed separately from native PDF layout.

The supplied widescreen table and all text spans in the 4:3 PDF stay within
their slide canvases. The clipped template bullet is a text-frame violation,
not a slide-boundary violation. These observations do not dismiss the user's
reports about other slides or PowerPoint's interactive view.

## Verification

The regression suites check explicit saved master styles, read-only legacy
title fallback, native soft-break XML including empty/trailing lines and CRLF,
role styles on multiline text, exact saved/reopened paragraph text, field
extraction and inherited template geometry. Test fixtures replace the original
master style container rather than accidentally adding a second one. The owned
feature-pipeline fixture follows the new authoring defaults: only its two master
parts gain `p:txStyles`; all 51 other parts and the independent Office fixture
remain byte-identical. Its provenance records the exact package delta.

The Templates Library Lab also verifies the saved tabular paragraph contains
three runs and two `a:br` elements. Both canvas options run through creation,
inspection, export and reopening. The review package contains the full 13-slide
16:9 and 16-slide 4:3 decks, two focused one-slide template specimens and the
one-slide widescreen table.

Independent python-pptx/XML checks verify archive integrity and slide bounds.
Both regenerated Lab decks preserve the original ordered paragraph text and
embedded font bytes. The preview renders show the complete final bullet and
the explicit 32 pt table title. An independent fontTools outline audit covers
497 text areas and 616 spans across the 29 Lab slides; their painted glyph
bounds stay within the corresponding text or table-cell frame with a 1 pt
rounding tolerance. This bounded audit covers the owned horizontal DejaVu
specimens, not arbitrary font fallback or synthetic bold ink. These are
portable checks, not native acceptance of the regenerated revision. The user's new PowerPoint review remains pending.

Reproduce the source checks with `bash scripts/verify.sh --fast` on the portable
host and the macOS/iOS CI gates. To retain fresh Lab artifacts, use the
[Library Lab reproduction instructions](LIBRARY-LAB-20261002.md#reproduction).
No performance speedup or general PowerPoint pixel-parity claim is made.
