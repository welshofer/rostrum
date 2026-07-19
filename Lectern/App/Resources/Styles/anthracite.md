# Anthracite

**ID:** `anthracite`  
**Category:** enterprise  
**Theme:** dark  
**Vibe:** Corporate

## Color palette

- `#1b1d1f`
- `#232629`
- `#2c3033`
- `#e5e7eb`
- `#ffffff`
- `#f5f6f7`
- `#c3c7cc`
- `#9aa0a6`
- `#6b7178`
- `#3a3f44`

## Typography

Families: Franklin Gothic Medium, Segoe UI. Weights: 400, 600, 700.

**PowerPoint-safe fonts:**

- heading: Franklin Gothic Medium
- body: Segoe UI

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Anthracite

Design token description: Anthracite is a pure monochrome enterprise system — no chroma anywhere, only coal, smoke, and light. The ground is coal #1b1d1f, with graphite surfaces #232629 and raised panels #2c3033 stepped in barely perceptible increments. The accent is white itself: #ffffff marks the single most important element on any slide, while primary text runs in soft white #f5f6f7 (nearly 16:1 on coal) so pure white retains its authority. Supporting text uses #c3c7cc, metadata #9aa0a6, and #6b7178 is the dimmest tone allowed near words. The system's signature is the hairline: 1px rules in #e5e7eb score the canvas like machined steel, framing zones, underlining titles, and structuring tables. #3a3f44 draws the quieter internal grid. Headings are Franklin Gothic Medium — industrial, compact, all business — set with tight tracking (-1%) and often in spaced ALL CAPS for labels; body is Segoe UI 400 with 600 for emphasis and table headers, 700 reserved for numerals. No gradients, no glows, no color-coding of any kind; meaning is carried entirely by weight, scale, and luminance. The personality is executive severity: a deck cut from slate, confident enough to need no color at all.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- Detected source-domain vocabulary: none (original system). Translate style into reusable visual behavior, not literal imagery.
- Avoid literal source imagery unless the exact slide text or visual direction explicitly requests it.

Overall visual personality: Machined monochrome authority — coal ground, white light, hairline steel rules, zero chroma.

Reusable visual grammar extracted from DESIGN.md:
- Architecture of hairlines: every slide carries at least one full-width 1px #e5e7eb rule, typically under the title band.
- 12-column grid with strict flush-left alignment; ragged edges appear only on the right, never on the left.
- Titles in Franklin Gothic Medium #f5f6f7; kicker labels above them in spaced ALL CAPS Segoe UI 600 #9aa0a6.
- The one pure-white #ffffff element per slide — a number, a keyword, a bar — is the designed focal point; everything else is dimmer.
- Panels step #232629 to #2c3033 with square corners; separation by luminance and hairline, never by shadow.
- Tables are the native layout organism: hairline row rules in #3a3f44, header rule in #e5e7eb, numerals right-aligned in Segoe UI 700.
- Negative space is generous but symmetrical; compositions feel engineered.
- Emphasis inside body copy uses Segoe UI 600 in #ffffff — never italics, never underlines.

Chart and infographic grammar:
- Charts are luminance-encoded: the argued series in #ffffff, comparisons in #c3c7cc and #9aa0a6, context in #6b7178; grid #3a3f44 on #1b1d1f.
- Chart text is Segoe UI 400 #c3c7cc; values direct-labeled in #f5f6f7; legends replaced by inline labels at line ends.
- Bars are square-cornered and slim; line charts use 2px strokes with the key line at 3px pure white.
- With no hue, series must also differ in weight or texture (solid vs. dashed) — meaning never depends on shade alone.

Image and illustration grammar:
- Subject comes from the slide JSON; photography is converted to high-contrast black-and-white with blacks matched to #1b1d1f.
- Images sit behind a hairline #e5e7eb frame or bleed full-width in their own band; text never overlays imagery.
- Illustrations are white and grey line work, 1–2px, drafted like technical schematics.

Slide graphic system:
- Section dividers: coal field, one hairline crossing the full width, section title in Franklin Gothic Medium #ffffff, number in #6b7178.
- Footer: hairline #3a3f44 above Segoe UI 400 #9aa0a6 pagination and classification text, identical on every slide.
- The datum hairline plus single-white-focal rule gives the deck its machined, continuous rhythm.
```
