# Phosphor

**ID:** `terminalgreen`  
**Category:** developer  
**Theme:** dark  
**Vibe:** Technical

## Color palette

- `#050805`
- `#0a120a`
- `#111e12`
- `#33ff66`
- `#7dffa0`
- `#d8ffe0`
- `#22b34a`
- `#5d8a68`
- `#1a3a22`
- `#020402`

## Typography

Families: Consolas, Consolas. Weights: 400, 600, 700.

**PowerPoint-safe fonts:**

- heading: Consolas
- body: Consolas

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Phosphor

Design token description: A cathode-ray terminal system on near-black #050805, with raised console panels #0a120a and #111e12 and an absolute-black well #020402 for code insets. Every glyph on screen is phosphor: primary text renders in pale mint #d8ffe0, bright emphasis and cursors burn in CRT green #33ff66, mid-emphasis in #7dffa0, executed-command green #22b34a for secondary series, dim readout #5d8a68 for timestamps and comments, and #1a3a22 for rules and borders. There is no second hue anywhere — the entire system is a single phosphor ramp, and discipline about that ramp is the aesthetic. All type, headings included, is Consolas: headings at 700 in caps with +6% tracking rendered like banner output, subheads 600, body 400 at generous line height (1.5+) so scanline rhythm stays legible. The accent #33ff66 is licensed for prompts, cursors, key figures, selected rows, and single-line banners; large filled areas of bright green are forbidden — glow is implied by contrast, never by bloom effects. Scanline texture, if used, is a barely-there 2-3% opacity line pattern. The personality is a machine that answers tersely and is always right.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- Detected source-domain vocabulary: none (original system). Translate style into reusable visual behavior, not literal imagery.
- Avoid literal source imagery unless the exact slide text or visual direction explicitly requests it.

Overall visual personality: A patient terminal at 2 a.m. — every character phosphor-lit, nothing decorative survives.

Reusable visual grammar extracted from DESIGN.md:
- Everything aligns to a character grid: fixed column widths, indentation in exact two-space steps, no centered text anywhere.
- Slides open with a prompt motif: a #33ff66 chevron or $ glyph preceding the title, cursor block optionally closing it.
- Hierarchy is expressed by brightness along the phosphor ramp (#33ff66 > #7dffa0 > #d8ffe0 > #5d8a68), not by hue or size inflation.
- Rules and boxes draw with ASCII discipline: 1px #1a3a22 lines, square corners, box-drawing aesthetics.
- Dim #5d8a68 metadata lines (paths, timestamps, line numbers) frame content top and left like a session log.
- Generous black space is mandatory — a terminal is mostly empty screen; keep content under 60% of canvas.
- Inverse-video treatment (near-black text on a #33ff66 bar) is the single loudest device, used at most once per slide.
- Optional scanline overlay at <=3% opacity; never vignettes, never glow blurs.

Chart and infographic grammar:
- Charts plot as ASCII-inflected linework: #33ff66 featured series, #22b34a and #7dffa0 for others, #1a3a22 gridlines on #050805.
- Bars render as block-character columns or outlined rectangles filled #111e12 with bright green tops.
- All labels in Consolas 400 #5d8a68; values in 600 #d8ffe0 — everything reads as console output.
- On this near-black ground, keep bright green to strokes and small fills so the accent stays above 3:1 without flooding.

Image and illustration grammar:
- Subjects come from slide JSON; render them as green-on-black wireframe or dithered-bitmap illustrations in the phosphor ramp only.
- Photographs, when explicitly required, convert to green-channel duotone (#050805 to #7dffa0) behind a 1px #1a3a22 frame.
- No full-color imagery ever enters this system.

Slide graphic system:
- Icons are drawn from box-drawing and glyph primitives, stroke-only, #7dffa0.
- Stat callouts print as command output: dim label line, then a #33ff66 700-weight figure at large scale.
- Progress and step indicators render as [####----] block meters in the ramp.
```
