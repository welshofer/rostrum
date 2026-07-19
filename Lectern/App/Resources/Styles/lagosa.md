# Lagosa

**ID:** `lagosa`  
**Category:** consumer  
**Theme:** light  
**Vibe:** Playful

## Color palette

- `#faf6ef`
- `#f2ecdf`
- `#e8e0cf`
- `#ffffff`
- `#30d5c8`
- `#0e9488`
- `#ff6f61`
- `#0b4f49`
- `#2b6b64`
- `#7a948f`

## Typography

Families: Century Gothic, Verdana. Weights: 400, 600, 700.

**PowerPoint-safe fonts:**

- heading: Century Gothic
- body: Verdana

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Lagosa

Design token description: Lagosa is a sun-bleached beach town rendered as a design system. The primary background is sand-white #faf6ef, stepping through warm shell surfaces #f2ecdf and #e8e0cf, with pure white #ffffff reserved for floating cards. All running text is deep sea-teal #0b4f49 with secondary copy in #2b6b64 and muted labels in #7a948f — ink that reads like tide pools, never grey. The signature accent is turquoise: bright lagoon #30d5c8 for large shapes, banners, and full-bleed bands, and deepened reef #0e9488 wherever the accent must carry small text, thin strokes, or icons. Coral #ff6f61 exists only as a micro-accent — a dot, an underline tick, one highlighted word — never a surface. Headlines are set in Century Gothic 700, wide geometric rounds with +2% tracking; body copy is Verdana 400 at generous line height, with Verdana 600 for emphasis. Surfaces are flat with big 24px-radius corners and no drop shadows — depth comes from color steps, not blur. The accent may fill shapes and frame content; it may not tint body text or backgrounds behind paragraphs. Personality: sunny, rounded, unhurried, confident.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- Detected source-domain vocabulary: none (original system). Translate style into reusable visual behavior, not literal imagery.
- Avoid literal source imagery unless the exact slide text or visual direction explicitly requests it.

Overall visual personality: A sandy boardwalk of rounded turquoise shapes — playful geometry that stays legible in full sun.

Reusable visual grammar extracted from DESIGN.md:
- Rounded-everything: cards, image masks, and accent bars all share a 24px corner radius; no sharp rectangles except the canvas itself.
- Generous margins (minimum 8% of canvas) with content clustered low-left or low-right, leaving a sky of sand-white negative space above.
- Hierarchy by scale jump: Century Gothic headlines at 3x body size, no intermediate sizes competing between headline and Verdana body.
- One large turquoise #30d5c8 shape per slide — a semicircle, arch, or pill band — anchoring the composition like a lagoon on a map.
- Coral #ff6f61 appears at most twice per slide and always tiny: a bullet dot, an underline tick, a single circled numeral.
- Flat color only; no gradients, shadows, or outlines — shapes meet each other in crisp hard edges of palette colors.
- White #ffffff cards float on the sand background to group related content, padded 32px minimum on all sides.

Chart and infographic grammar:
- Charts use deep teal #0b4f49 as the default series color with turquoise #30d5c8 for the highlighted series and coral #ff6f61 for a single callout point only.
- Bars and area fills are flat with rounded 8px tops; gridlines are #e8e0cf hairlines and axis labels are Verdana 400 in #2b6b64.
- On the light sand background, keep chart ink dark: values and axis text in #0b4f49, never in turquoise below 18pt.
- Donut and pie charts get a sand-white center hole with one Century Gothic 700 stat in deep teal.

Image and illustration grammar:
- Image subjects come from the slide JSON; render them bright, high-key, and warm-lit to match the sand-white field.
- Mask photos inside rounded 24px shapes or full semicircles; never hard-cornered frames.
- Illustrations are flat two-tone cutouts in teal and turquoise on sand, with coral used for one tiny detail at most.

Slide graphic system:
- Section dividers are a full-bleed turquoise #30d5c8 field with a single Century Gothic 700 line in #0b4f49 and a coral tick.
- Iconography is rounded-stroke, 3px weight, drawn in #0e9488 on white or sand chips.
- Footers carry a thin #e8e0cf rule with page markers in Verdana 400 #7a948f.
```
