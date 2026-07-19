# Large Print

**ID:** `largeprint`  
**Category:** accessibility  
**Theme:** light  
**Vibe:** Corporate

## Color palette

- `#fdfbf7`
- `#f5f1ea`
- `#ebe5da`
- `#0b5394`
- `#3d7ab5`
- `#083b6b`
- `#1c2733`
- `#42505f`
- `#6e7a87`
- `#d5cfc4`

## Typography

Families: Tahoma, Verdana. Weights: 400, 600, 700.

**PowerPoint-safe fonts:**

- heading: Tahoma
- body: Verdana

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Large Print

Design token description: Large Print is an oversized-type corporate system where every token is sized and paired for AAA legibility from the back row. The ground is warm white #fdfbf7 — softer on the eye than pure white — with parchment surfaces #f5f1ea and wells #ebe5da for grouping. Ink is deep slate #1c2733 (over 14:1 on the ground); #42505f carries secondary text and #6e7a87 is the minimum tone for any text, used only at large sizes. The accent is authoritative blue #0b5394, itself AAA on the warm ground, so headlines, key figures, and links can all be set in it without exception lists; #3d7ab5 fills large bars and banners, and #083b6b anchors small dense marks. #d5cfc4 draws hairlines. Type is the entire architecture: Tahoma 700 headlines at roughly twice normal deck scale, Tahoma 600 subheads, and Verdana 400 body starting where other systems put subheads — nothing below 20pt-equivalent ever appears. Tracking stays normal; Verdana's wide counters do the work. Line spacing is 1.4 minimum, paragraphs short, one idea per slide. The personality is confident institutional clarity: big, calm, and impossible to squint at.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- Detected source-domain vocabulary: none (original system). Translate style into reusable visual behavior, not literal imagery.
- Avoid literal source imagery unless the exact slide text or visual direction explicitly requests it.

Overall visual personality: Boardroom clarity at double scale — oversized humanist type, warm paper, and one trustworthy blue.

Reusable visual grammar extracted from DESIGN.md:
- Radically reduced content per slide: one headline, at most four short bullets or one figure; overflow becomes additional slides, never smaller type.
- 8-column grid with 110px margins; text blocks never exceed two-thirds of slide width to keep line lengths short.
- Headlines in Tahoma 700 #1c2733 may occupy the top third of the slide; scale is the brand.
- A 4px #0b5394 rule under the headline anchors every content slide.
- Bullets are large #0b5394 squares with a full em of clearance; list items are single sentences with air between them.
- Panels #f5f1ea group content with 8px radii and no shadows; a maximum of two panels per slide.
- Key numbers set enormous in Tahoma 700 #0b5394 with their label in Verdana 400 #42505f directly beneath.
- Nothing overlaps: text, panels, and imagery each own exclusive regions of the canvas.

Chart and infographic grammar:
- Charts favor few, thick marks: 3–5 bars maximum, series in #0b5394, #3d7ab5, #083b6b, then #6e7a87; gridlines #d5cfc4.
- All chart text is Verdana 400 #1c2733 at body scale or larger; values print directly on or beside marks, legends are eliminated.
- Line charts use 4px strokes and oversized end-point markers; axes are simplified to the two or three ticks the story needs.
- No stacked charts with more than three segments; complexity is split across slides.

Image and illustration grammar:
- Subject comes from the slide JSON; imagery is sharp, evenly lit, and shown large in its own half of the slide or not at all.
- Images take a 1px #d5cfc4 keyline on the warm ground; captions in Verdana 400 #42505f at full body size.
- Diagrams redraw as bold #0b5394 strokes with oversized labels rather than shrinking source graphics.

Slide graphic system:
- Section dividers: #0b5394 full bleed with warm-white Tahoma 700 title at maximum scale and the section number as a huge #3d7ab5 numeral.
- Footer: slide number only, Verdana 400 #42505f at readable scale, bottom-right; clutter is omitted.
- The under-headline blue rule and square bullets repeat everywhere, so navigation is legible even at a glance from distance.
```
