# Flint

**ID:** `flint`  
**Category:** enterprise  
**Theme:** light  
**Vibe:** Corporate

## Color palette

- `#f6f8f9`
- `#eef1f3`
- `#e2e7ea`
- `#546e7a`
- `#3d525c`
- `#272e33`
- `#4d585f`
- `#8a969d`
- `#cfd7db`
- `#a9bcc6`

## Typography

Families: Segoe UI Semibold, Segoe UI. Weights: 400, 600, 700.

**PowerPoint-safe fonts:**

- heading: Segoe UI Semibold
- body: Segoe UI

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)
Design system name: Flint
Design token description: Flint is a cool, systematic enterprise design language on near-white, #f6f8f9, with stepped panel surfaces #eef1f3 and #e2e7ea and 1px #cfd7db keylines instead of shadows; elevation is expressed by tone, not blur. Text is gunmetal: #272e33 primary, #4d585f secondary, #8a969d for metadata and helper text. The accent is flint blue-grey #546e7a for interactive markers, key metrics, header rules, and the primary chart series, deepening to #3d525c for dense small marks and darkening states; #a9bcc6 is the quiet tint for selected rows, timeline tracks, and background emphasis zones. The accent stays desaturated by design — authority without noise — and never appears as long-text color. All type is one family at two voices: Segoe UI Semibold for headings and any figure that must carry weight, Segoe UI 400 for body with 600 for labels and column heads; tracking stays neutral, sizes step on a strict 1.25 modular scale. Layouts are calm, dense-capable, and grid-locked, built for roadmaps, org systems, and quarterly reviews. The personality is a well-run platform team's documentation: neutral, legible, ruthlessly consistent.
STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- Detected source-domain vocabulary: none (original system). Translate style into reusable visual behavior, not literal imagery.
- Avoid literal source imagery unless the exact slide text or visual direction explicitly requests it.
Overall visual personality: cool flint-grey enterprise clarity, keyed by tone instead of ornament.
Reusable visual grammar extracted from DESIGN.md:
- A 12-column grid with fixed gutters governs everything; panels span whole columns and never sit at arbitrary widths.
- Elevation by tone: #f6f8f9 base, #eef1f3 panel, #e2e7ea inset — three steps only, always keylined in #cfd7db.
- Slide titles in Segoe UI Semibold sit on a consistent baseline with a 2px #546e7a rule of fixed width beneath.
- Density is welcome but ordered: tables, timelines, and swimlanes align to shared row heights across the deck.
- Emphasis budget: one #546e7a element and one Semibold figure per zone; everything else stays gunmetal.
- Whitespace is standardized — padding steps of 8/16/24/32 — so calm comes from rhythm, not emptiness.
- Square corners on structure; 4px radius allowed only on small status chips.
Chart and infographic grammar:
- Series order: flint #546e7a, deep flint #3d525c, mist #a9bcc6, slate #8a969d; categorical palettes never exceed four before grouping.
- Light-mode rules: gridlines #cfd7db, axis labels Segoe UI 400 #4d585f, values Segoe UI 600 #272e33; plot areas unfilled.
- Status semantics stay tonal: on-track in flint, at-risk in deep flint with a pattern, done in mist — no imported traffic-light hues.
- KPI tiles pair a Segoe UI Semibold figure with a 400-weight label and a hairline, all on an #eef1f3 panel.
Image and illustration grammar:
- Render slide-JSON subjects as clean, evenly lit imagery with a cool neutral grade; nothing warmer than the paper tone.
- Prefer abstract system imagery — grids, nodes, layered planes — rendered in palette tones when the slide asks for atmosphere.
- Images sit inside keylined panels at grid widths; no full-bleed except cover slides.
Slide graphic system:
- Icons are 1.5px gunmetal strokes on the shared grid, with #546e7a for exactly one active or highlighted element.
- Dividers use an #e2e7ea field, an oversized Segoe UI Semibold numeral in #546e7a, and the standard title rule.
- Timelines and process bars run on #a9bcc6 tracks with flint markers and gunmetal labels.
```
