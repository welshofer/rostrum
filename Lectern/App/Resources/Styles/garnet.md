# Garnet

**ID:** `garnet`  
**Category:** hospitality  
**Theme:** dark  
**Vibe:** Editorial

## Color palette

- `#1c0e13`
- `#2a161d`
- `#3b2029`
- `#8e2a3c`
- `#c04a5e`
- `#f2e3c6`
- `#cbb794`
- `#8a7566`
- `#4a3038`
- `#e0c284`

## Typography

Families: Georgia, Trebuchet MS. Weights: 400, 600, 700.

**PowerPoint-safe fonts:**

- heading: Georgia
- body: Trebuchet MS

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)
Design system name: Garnet
Design token description: Garnet is a candlelit editorial system built on a merlot-black ground, #1c0e13, that reads as near-black with a wine cast rather than neutral charcoal. Surfaces step up in the same key: cards sit on #2a161d and framed panels on #3b2029, separated by hairlines of #4a3038 instead of shadows. The signature color appears at two depths: deep garnet #8e2a3c for large pours, full-bleed banners, section-divider fields, and generous quote blocks, and lifted garnet #c04a5e for anything that must read at small scale such as links, rule accents, tick labels, and key numbers. Text is champagne: #f2e3c6 for primary copy, #cbb794 for secondary, #8a7566 for captions and metadata, with #e0c284 reserved for gilded numerals and pull-quote marks. Headings are set in Georgia at weight 700 with tight, classical tracking; subheads take Georgia 400 italic. Body and labels are Trebuchet MS at 400, with 600 for emphasis and small-caps-style labels tracked out to +80. Garnet may never tint body text and never appears as a background behind long paragraphs. The personality is a wine list composed by a magazine art director: warm, low-lit, unhurried, precise.
STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- Detected source-domain vocabulary: none (original system). Translate style into reusable visual behavior, not literal imagery.
- Avoid literal source imagery unless the exact slide text or visual direction explicitly requests it.
Overall visual personality: candlelit wine-dark editorial warmth with gilded champagne restraint.
Reusable visual grammar extracted from DESIGN.md:
- Asymmetric editorial grid: a dominant two-thirds column for the story, a narrow champagne-ruled margin column for annotations and folio details.
- Generous negative space at the top of every slide; headlines hang from a consistent hanging line rather than centering vertically.
- Thin #4a3038 hairline rules structure the page the way a menu is ruled; boxes are rare, rules are constant.
- Deep garnet #8e2a3c fields bleed to one edge only, never all four, keeping the merlot-black ground dominant.
- Hierarchy is built from Georgia size contrast (large 700 heads over small tracked Trebuchet MS labels), not from color variety.
- Gilded #e0c284 details are rationed to one moment per slide: an oversized numeral, a drop cap, or a quotation mark.
- Corners are square; curvature is reserved for a single circular motif such as a stamp or seal when a slide calls for one.
Chart and infographic grammar:
- Charts inherit the palette in order: lifted garnet #c04a5e for the primary series, champagne #cbb794 second, gold #e0c284 third; never more than four series.
- On the dark ground, gridlines are #4a3038 at 1px, axis text is #cbb794 in Trebuchet MS 400, and plot backgrounds stay transparent.
- Bars and areas may use deep garnet #8e2a3c as large fills because of their size; lines, points, and small labels must use #c04a5e or lighter.
- Callout values are set in Georgia 700 champagne, larger than the chart title, treated as the slide's editorial pull-number.
Image and illustration grammar:
- Subjects come only from the slide JSON; render them as low-key, warm-shadowed imagery with deep burgundy shadows and champagne-lit highlights.
- Duotone treatments map shadows to #1c0e13 and highlights to #f2e3c6, with an optional #8e2a3c midtone wash.
- Images sit full-bleed on one edge or inside a hairline-ruled frame with a caption in tracked Trebuchet MS 600.
Slide graphic system:
- Iconography is thin-stroke (1.5px) in champagne #f2e3c6 with garnet #c04a5e for a single active state; no filled icon backgrounds.
- Dividers and agenda slides use a full #8e2a3c field with an oversized Georgia numeral in #e0c284.
- Footers carry a hairline rule with page metadata in #8a7566 tracked Trebuchet MS.
```
