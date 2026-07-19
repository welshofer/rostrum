# Drafting

**ID:** `drafting`  
**Category:** architecture  
**Theme:** dark  
**Vibe:** Technical

## Color palette

- `#0c2340`
- `#123054`
- `#1a3d68`
- `#7dd3fc`
- `#bae6fd`
- `#f5f9ff`
- `#c7d7ea`
- `#8fa8c4`
- `#38618c`
- `#071729`

## Typography

Families: Bahnschrift, Consolas. Weights: 400, 600, 700.

**PowerPoint-safe fonts:**

- heading: Bahnschrift
- body: Consolas

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Drafting

Design token description: A working drawing system on drafting-blue #0c2340, with raised sheet surfaces #123054 and #1a3d68 for panels and title blocks. Primary text is paper-white #f5f9ff, secondary annotation #c7d7ea, and dim reference text #8fa8c4. The construction accent is blueprint cyan #7dd3fc with a pale tint #bae6fd for glow-free highlights; #38618c draws sub-grid lines and #071729 is the deepest recess for code or dimension strips. Every line on the sheet is either white linework (#f5f9ff at 1px) or cyan construction geometry — fills are rare and always translucent panel tones. Headings set in Bahnschrift 700 with +4% tracking in all caps, echoing DIN stencil lettering; subheads take Bahnschrift 600. Body, dimensions, and callouts set in Consolas 400/600 so coordinates and measurements align monospaced. Cyan #7dd3fc is licensed for dimension lines, leader arrows, key figures, active-state strokes, and the title-block rule; it never fills large areas and never colors body paragraphs. The overall character is a precise architectural sheet mid-revision: gridded, annotated, dimensioned, and calm under its own rigor.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- Detected source-domain vocabulary: none (original system). Translate style into reusable visual behavior, not literal imagery.
- Avoid literal source imagery unless the exact slide text or visual direction explicitly requests it.

Overall visual personality: A live drafting sheet — white linework and cyan dimensions over deep blueprint blue.

Reusable visual grammar extracted from DESIGN.md:
- A faint 8pt modular grid in #38618c underlies every slide, visible at low contrast like graph film; content snaps to it.
- A title block anchors the lower-right or top edge: Bahnschrift caps, thin white border, revision-style metadata in Consolas #8fa8c4.
- Objects are drawn, not filled: 1px #f5f9ff outlines with corner tick marks; cyan #7dd3fc marks the measured or highlighted element.
- Dimension-line motifs (thin cyan rules with perpendicular end ticks and centered Consolas labels) connect related items.
- Headings run in Bahnschrift 700 caps with a cyan index number (01, 02) set in Consolas to the left.
- Negative space reads as empty sheet — large, deliberate, and gridded; never crowd more than two annotated figures per slide.
- Crosshair and registration marks may punctuate corners at #8fa8c4, small and quiet.
- Layer hierarchy: white ink above cyan construction lines above dim sub-grid — never invert.

Chart and infographic grammar:
- Charts render as line-and-outline drawings: white #f5f9ff strokes for context series, cyan #7dd3fc for the featured series, #8fa8c4 for gridlines.
- Bar fills use translucent #1a3d68 with 1px cyan or white outlines so the grid shows through — no solid saturated fills on the dark ground.
- Data labels in Consolas 600 #bae6fd placed like dimension callouts with leader ticks.
- Keep luminous elements thin; on this dark sheet, bright areas larger than a rule must drop to panel tones.

Image and illustration grammar:
- Render slide-JSON subjects as isometric or orthographic white-line drawings with cyan section cuts — never photographic unless explicitly directed.
- Photographs, when requested, duotone into the blue range (#0c2340 shadows, #bae6fd highlights) with a 1px white frame.
- Every image gets a Consolas figure label (FIG A-01 style) in #8fa8c4.

Slide graphic system:
- Icons are 1px stroke glyphs in #f5f9ff with a single cyan detail stroke; no filled icons.
- Stat callouts mimic dimension tags: cyan bracket ticks flanking a Consolas 700 white figure.
- Section dividers reuse the title-block band with an incremented sheet number.
```
