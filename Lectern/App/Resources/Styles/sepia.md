# Sepia

**ID:** `sepia`  
**Category:** media  
**Theme:** light  
**Vibe:** Editorial

## Color palette

- `#f3ead8`
- `#ebdfc6`
- `#e0d1b3`
- `#704214`
- `#4e2d0d`
- `#362617`
- `#61503c`
- `#93826a`
- `#d5c6a8`
- `#b9a888`

## Typography

Families: Garamond, Georgia. Weights: 400, 600, 700.

**PowerPoint-safe fonts:**

- heading: Garamond
- body: Georgia

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)
Design system name: Sepia
Design token description: Sepia is a newsroom-archive editorial system on aged paper, #f3ead8, with folio surfaces #ebdfc6 and #e0d1b3 and column rules in #d5c6a8 that organize every slide like a well-set broadsheet page. Text is dark coffee: #362617 for primary copy, #61503c for standfirsts and secondary text, #93826a for bylines, folios, and captions, with #b9a888 reserved for the faintest archival rules and watermark-weight details. The accent is sepia brown #704214, applied as drop caps, kickers, underlines beneath section labels, and the darkest series in charts; it deepens to #4e2d0d for maximum-weight marks. The accent never floods backgrounds and never tints running text. Headings are Garamond 700 with elegant old-style proportions, subheads Garamond 400 italic; body is Georgia 400 — sturdier than Garamond at text sizes — with Georgia 600 for emphasis and tabular figures. Kickers run in tracked Georgia 600 uppercase at +100. Layouts obey column discipline: two or three text columns, ranged-left, with hanging punctuation where possible. The personality is a Sunday feature section pulled from a well-kept archive: literate, column-ruled, quietly authoritative, printed in coffee on cream.
STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- Detected source-domain vocabulary: none (original system). Translate style into reusable visual behavior, not literal imagery.
- Avoid literal source imagery unless the exact slide text or visual direction explicitly requests it.
Overall visual personality: an archived broadsheet feature page, coffee ink on aged cream.
Reusable visual grammar extracted from DESIGN.md:
- Column-first composition: content flows in two or three ruled columns with #d5c6a8 vertical rules, like a typeset feature page.
- A kicker system tops every content slide: tracked Georgia 600 uppercase in #704214 above the Garamond 700 headline.
- Drop caps in Garamond 700 sepia open feature paragraphs; limit one per slide.
- Pull quotes break the column grid deliberately, set large in Garamond 400 italic with #704214 quotation marks.
- White space follows print logic: tight within columns, generous between stories.
- Hierarchy is typographic — size, weight, italic, tracked caps — with color doing almost no hierarchical work.
- Rules are everything: hairlines above captions, double rules under mastheads-style titles, no boxes or cards.
Chart and infographic grammar:
- Series order: sepia #704214, coffee #61503c, tan #93826a, faint #b9a888; charts should look like archival newsprint graphics.
- Light-mode rules: gridlines #d5c6a8, axis labels Georgia 400 #61503c, values Georgia 600 #362617, titles Garamond 400 italic.
- Prefer editorial forms — slope charts, dot plots, small multiples — over dashboard idioms; no fills brighter than the accent.
- One annotation per chart in Georgia 400 with a thin leader line, phrased like a caption, not a label.
Image and illustration grammar:
- Render slide-JSON subjects as documentary photography with a warm sepia grade: shadows toward #362617, highlights toward #f3ead8.
- Halftone or fine-grain texture is welcome at low intensity; images should feel reproduced, not glossy.
- Every image carries a Georgia 400 caption in #93826a with a hairline above, credit-line style.
Slide graphic system:
- Icons are rare and etched: 1.25px coffee strokes, no fills, drawn like engravings in a reference column.
- Section dividers are typographic: an oversized Garamond numeral in #704214 on aged paper with a double rule.
- Folios run bottom corners in tracked Georgia 600 #93826a.
```
