# Gazette

**ID:** `gazette`  
**Category:** media  
**Theme:** light  
**Vibe:** Editorial

## Color palette

- `#f4f1ea`
- `#ece8de`
- `#e0dbcd`
- `#191817`
- `#1a5276`
- `#123c57`
- `#3b3a36`
- `#78756c`
- `#c9c3b4`
- `#fffef9`

## Typography

Families: Bodoni MT, Georgia. Weights: 400, 600, 700.

**PowerPoint-safe fonts:**

- heading: Bodoni MT
- body: Georgia

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Gazette

Design token description: A broadsheet newspaper system built on newsprint #f4f1ea, with column surfaces at #ece8de and recessed sidebars at #e0dbcd. Primary text is press-black #191817 with secondary gray-ink #3b3a36 and caption gray #78756c. The masthead accent is printer's blue #1a5276, deepened to #123c57 for links-style underlines and kicker bars; column rules and borders are #c9c3b4, and pull-quote cards lift to bright stock #fffef9. Headlines are set in Bodoni MT at 700 with tight tracking (-1% to -2%) and dramatic size contrast against the text; decks and standfirsts take Bodoni MT 600. All running text, captions, and bylines are Georgia 400, with 600 for lead-ins, set at newspaper measure in justified or ragged columns. The blue accent is licensed for the masthead band, kickers, drop caps, section slugs, and hyperlink-style underlines; it never floods panels or backgrounds, and body copy never sets in blue. Black is the true first accent — huge Bodoni headlines carry the visual weight. The personality is authoritative daily-edition journalism: dense, columnar, hierarchical, and typographically loud only at the headline tier.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- Detected source-domain vocabulary: none (original system). Translate style into reusable visual behavior, not literal imagery.
- Avoid literal source imagery unless the exact slide text or visual direction explicitly requests it.

Overall visual personality: Front-page authority — Bodoni headlines shouting over disciplined Georgia columns.

Reusable visual grammar extracted from DESIGN.md:
- Multi-column layouts (2-4 columns) with 1px #c9c3b4 column rules; text blocks justify to a consistent baseline grid.
- Extreme type-scale contrast: Bodoni MT headlines at 4-6x body size, then an immediate drop to Georgia body — no intermediate drift sizes.
- A thin full-width masthead band in #1a5276 or a black double rule tops the slide, carrying the section slug in small caps.
- Kickers and section labels set in Georgia 600 letterspaced caps, #1a5276, above headlines.
- Pull quotes break the column grid deliberately: Bodoni MT 600 spanning two columns between heavy top/bottom rules.
- Drop caps in Bodoni MT #1a5276 open lead paragraphs on section-opening slides.
- White space is rationed like column inches — dense but never cramped; margins stay tight and even.
- Hierarchy runs headline, deck, byline rule, body — never decorate with more than rules and weight.

Chart and infographic grammar:
- Charts print like newspaper graphics: black #191817 data ink first, masthead blue #1a5276 for the highlighted series, grays #78756c for context series.
- Frame every chart in a 1px #191817 box with a Bodoni MT slug title and a Georgia caption beneath, exactly like an edition graphic.
- Hatching and dot fills may substitute for extra hues; never exceed the palette.
- Axis text in Georgia 400 #3b3a36; gridlines hairline #c9c3b4 to read as print rules on the light ground.

Image and illustration grammar:
- Slide JSON dictates the subject; treat photographs as halftone-leaning, slightly desaturated press images with 1px black borders and Georgia italic captions.
- Illustrations render as engraved line art in #191817 with restrained #1a5276 spot color.
- Images occupy whole column widths — never float mid-column or bleed behind text.

Slide graphic system:
- Infographic slugs use the kicker system: blue letterspaced caps over a black rule.
- Stat callouts set as Bodoni MT 700 numerals in #191817 with a #1a5276 underline rule and Georgia label.
- Section breaks reuse the double-rule masthead motif at reduced width.
```
