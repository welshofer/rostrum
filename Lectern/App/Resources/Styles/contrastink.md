# Contrast Ink

**ID:** `contrastink`  
**Category:** accessibility  
**Theme:** light  
**Vibe:** Minimal

## Color palette

- `#ffffff`
- `#f5f5f5`
- `#e8e8e8`
- `#005a9c`
- `#000000`
- `#1a1a1a`
- `#333333`
- `#767676`
- `#b3b3b3`
- `#d9d9d9`

## Typography

Families: Arial, Georgia. Weights: 400, 600, 700.

**PowerPoint-safe fonts:**

- heading: Arial
- body: Georgia

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Contrast Ink

Design token description: Contrast Ink is a maximum-legibility system engineered around one uncompromising pair: pure black ink (#000000) on pure white paper (#ffffff), a 21:1 ratio that survives any projector, any lighting, any vision profile. Near-black #1a1a1a and #333333 serve long-form body text where full black would feel harsh at size; #767676 is the floor for any text-bearing grey and appears only at 18pt or larger. Surfaces are restrained: #f5f5f5 panels and #e8e8e8 wells separate zones without borders, and #d9d9d9 draws hairline rules. Exactly one chromatic voice exists — the deep accessible blue #005a9c (7:1 on white, AAA at any size) — used for links, key numbers, the title underline rule, and nothing decorative. Light grey #b3b3b3 is strictly non-text: tick marks, disabled states, faint grid. Headings are Arial 700 with tight, confident tracking (0 to -1%); subheads Arial 600; body is Georgia 400 at generous sizes with 1.4 line spacing, chosen because its sturdy serifs aid word-shape recognition. Nothing blinks, nothing gradients, nothing overlaps text. The personality is quiet authority: the design disappears so the words carry everything.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- Detected source-domain vocabulary: none (original system). Translate style into reusable visual behavior, not literal imagery.
- Avoid literal source imagery unless the exact slide text or visual direction explicitly requests it.

Overall visual personality: Ruthlessly legible black-on-white minimalism with a single disciplined blue — typography as the entire design.

Reusable visual grammar extracted from DESIGN.md:
- Single-column reading measure by default (55–70 characters); two columns only when content is genuinely parallel.
- 100px minimum margins on all sides; white space is the primary grouping device, panels the secondary one.
- Every title is followed by a 3px #005a9c rule spanning the text column — the one place color is guaranteed.
- Hierarchy uses exactly three text sizes per slide, never more; size and weight do all differentiation, color never does.
- Bullets are solid black squares, indented one level maximum; nested complexity is redesigned into separate slides.
- Hairline #d9d9d9 rules separate list groups; boxes and borders around text are forbidden.
- Key figures may be set very large in Arial 700 #005a9c, one per slide, with the sentence around them in black.
- No element may ever sit behind text: no watermarks, no background images, no texture.

Chart and infographic grammar:
- Charts are monochrome-first: data in #000000 and greys (#333333, #767676, #b3b3b3 for non-critical marks), with #005a9c reserved for the single series or point being argued.
- All chart text meets AAA: labels Arial 400 #1a1a1a at 18pt-equivalent minimum, direct-labeled — legends are avoided.
- Gridlines #e8e8e8, axis lines #767676; patterns (hatching, dots) supplement color so no meaning depends on hue alone.
- No pie charts with more than four slices; prefer bars with values printed at bar ends.

Image and illustration grammar:
- Subject comes from the slide JSON; imagery is documentary, high-contrast, and sharply focused, placed beside text, never beneath it.
- Images get a 1px #b3b3b3 keyline and sit on white; captions in Georgia 400 #333333 directly below.
- Decorative stock imagery is omitted entirely when it adds no information.

Slide graphic system:
- Section dividers: white field, oversized Arial 700 black title, #005a9c rule, section number in Arial 400 #767676.
- Footer: page number and deck title in Arial 400 #767676 at the AAA-safe large-text size, bottom-left, consistent on every slide.
- The blue rule and square bullets are the only repeating marks — the system's entire identity in two gestures.
```
