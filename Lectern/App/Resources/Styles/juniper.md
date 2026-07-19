# Juniper

**ID:** `juniper`  
**Category:** developer  
**Theme:** dark  
**Vibe:** Technical

## Color palette

- `#0b1512`
- `#101d18`
- `#16261f`
- `#1f332a`
- `#2ecc71`
- `#7fe0a8`
- `#e6f5ec`
- `#a9c4b6`
- `#6d8579`
- `#050b09`

## Typography

Families: Consolas, Segoe UI. Weights: 400, 600, 700.

**PowerPoint-safe fonts:**

- heading: Consolas
- body: Segoe UI

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)
Design system name: Juniper
Design token description: Juniper is a terminal-bred technical system on near-black green-tinted #0b1512. Elevated surfaces step up in even increments — #101d18 panels, #16261f cards, #1f332a raised chips — so depth reads as subtle atmosphere, not shadowplay. Primary text is mint-white #e6f5ec; secondary text #a9c4b6; disabled and comment tones #6d8579. The accent is emerald #2ecc71, used for command emphasis, live-status indicators, key metrics, and primary chart series; a soft mint #7fe0a8 handles hover and secondary series. The deepest tone #050b09 is reserved for inset code wells. Headings are set in Consolas at weights 700 and 600 — monospaced, lowercase-friendly, tracking normal — so titles read like function signatures; body copy is Segoe UI 400 with 600 for labels and UI chrome. Emerald never carries paragraphs and never fills more than a status bar or a metric tile; on it, text is #0b1512. Panels take 1px #1f332a borders and 6px radii. The personality is a well-kept developer console: calm, exact, quietly alive, with a faint phosphor warmth rather than neon glare.
STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- Detected source-domain vocabulary: none (original system). Translate style into reusable visual behavior, not literal imagery.
- Avoid literal source imagery unless the exact slide text or visual direction explicitly requests it.
Overall visual personality: A pristine developer terminal — emerald signals on green-black, monospaced headlines, and everything aligned to a strict grid.
Reusable visual grammar extracted from DESIGN.md:
- Hard 12-column grid with an 8px baseline; every panel, gutter, and code well snaps to it like a tiling window manager.
- Headlines set in Consolas 700 with an emerald prompt glyph (a single > or $) preceding the title text.
- Content lives in bordered panels (#101d18 fill, 1px #1f332a stroke, 6px radius); panels tile edge-to-edge with 16px gutters rather than floating.
- Code and data excerpts sit in inset #050b09 wells with #7fe0a8 syntax highlights and #6d8579 comments.
- Negative space is structural: at most two panel rows per slide, generous 64px outer margins, no decorative fills.
- Status dots, badge chips, and keyboard-key tokens in #1f332a with emerald text form the small-parts vocabulary.
- Hierarchy comes from tone steps (mint-white, then #a9c4b6, then #6d8579) and mono/proportional contrast, never from size extremes.
Chart and infographic grammar:
- Series order: #2ecc71, #7fe0a8, #a9c4b6, #6d8579 on the #0b1512 field; gridlines are 1px #16261f, axis text #a9c4b6 Segoe UI 400.
- Dark-mode contrast rule: plot marks stay at or above the luminance of #6d8579; no dark-on-dark series.
- Metric callouts render as terminal readouts — Consolas 700 emerald value, Segoe UI #a9c4b6 label beneath.
- Sparklines and bars are flat, 2px strokes, square caps; no gradients, glows kept to a 1px emerald edge on the active element only.
Image and illustration grammar:
- Subjects come from the slide JSON; render as dark-field technical illustration or screenshots matted in #101d18 panels with 1px borders.
- Photography is graded cool and dim with a faint green cast in shadows so mint-white UI text stays dominant.
- Diagrams use 1.5px mint strokes with emerald highlights on the active path; fills stay within the surface ramp.
Slide graphic system:
- Recurring motif: the prompt line — an emerald > glyph and a blinking-cursor rectangle used on titles and dividers.
- Footers are a thin status bar: #101d18 strip with Consolas 400 #6d8579 breadcrumbs and an emerald connection dot.
- Divider slides show a single Consolas command line on the raw #0b1512 field with the cursor block in #2ecc71.
```
