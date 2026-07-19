# Linen Atlas

**ID:** `atlaslinen`  
**Category:** education  
**Theme:** light  
**Vibe:** Editorial

## Color palette

- `#f3eee3`
- `#ece5d5`
- `#e3d8bf`
- `#116466`
- `#0d4b4d`
- `#33291d`
- `#5f5340`
- `#8d7f66`
- `#cabfa6`
- `#faf7ee`

## Typography

Families: Book Antiqua, Gill Sans MT. Weights: 400, 600, 700.

**PowerPoint-safe fonts:**

- heading: Book Antiqua
- body: Gill Sans MT

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Linen Atlas

Design token description: A cartographic reference-atlas system on linen #f3eee3, with parchment surfaces #ece5d5 and aged plate panels #e3d8bf. Text is sepia ink: primary #33291d, secondary #5f5340, captions and folio marks #8d7f66. The wayfinding accent is cartographic teal #116466, deepened to #0d4b4d for pressed states and plate borders; hairline graticules and frames draw in #cabfa6, and highlight cards lift to bright vellum #faf7ee. Headings are set in Book Antiqua 700 with generous +2% tracking and true small caps for plate titles; subheads at 600 may italicize for taxonomic flavor. Body copy is Gill Sans MT 400 with 600 lead-ins — the humanist sans keeps long educational passages crisp against the serif plates. Teal is licensed for route lines, plate numbers, keys and legends, underline rules, and one large map-figure per slide; it must not tint backgrounds or body text. The layout language borrows from atlas plates: framed figures, corner coordinates, legend boxes, and a steady graticule grid. The personality is patient scholarship — a beautiful reference book that expects to be studied, annotated, and kept for decades.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- Detected source-domain vocabulary: none (original system). Translate style into reusable visual behavior, not literal imagery.
- Avoid literal source imagery unless the exact slide text or visual direction explicitly requests it.

Overall visual personality: A well-thumbed atlas plate — sepia scholarship with teal wayfinding.

Reusable visual grammar extracted from DESIGN.md:
- Every slide is a plate: a 1px #cabfa6 frame inset from the canvas edge, with a small-caps Book Antiqua plate title and plate number in teal.
- A faint graticule (grid of #cabfa6 hairlines at low opacity) organizes content zones like lines of latitude.
- Figures and text share the page asymmetrically: one dominant framed figure, one measured text column — never 50/50 splits.
- Legend boxes in #ece5d5 with 1px borders explain any symbol system, set in Gill Sans MT 400 at caption size.
- Corner coordinates and folio marks in #8d7f66 give quiet page furniture.
- Route-line motifs — dotted teal paths with terminal markers — connect sequential ideas across the plate.
- Hierarchy: small-caps plate title, italic subtitle, then sans body; sizes stay bookish, never poster-loud.
- Margins are wide and even; the linen ground must breathe around every frame.

Chart and infographic grammar:
- Charts render as atlas figures: teal #116466 primary series, sepia #5f5340 secondary, #cabfa6 gridlines, all inside the standard plate frame.
- Area fills use parchment tones #e3d8bf under teal strokes rather than saturated fills.
- Labels in Gill Sans MT 400 #33291d; figure captions italic Book Antiqua beneath the frame.
- On the light linen, keep data ink at #116466 or darker so every mark clears 3:1.

Image and illustration grammar:
- Slide JSON defines subjects; render them as engraved plate illustrations or stippled drawings in sepia with teal spot accents.
- Photographic content warms toward parchment (lifted blacks, sepia cast) and sits in the plate frame with a caption rule.
- Never bleed imagery to canvas edges; the atlas frame is inviolable.

Slide graphic system:
- Icons draw as fine 1.5px sepia engravings with one teal stroke.
- Stat callouts render as legend entries: teal swatch square, Book Antiqua 700 figure, Gill Sans MT label.
- Section breaks use a compass-rose-adjacent rosette rule in #cabfa6 with a teal center tick.
```
