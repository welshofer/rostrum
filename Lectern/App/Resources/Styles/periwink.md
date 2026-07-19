# Periwinkle

**ID:** `periwink`  
**Category:** education  
**Theme:** light  
**Vibe:** Playful

## Color palette

- `#fdfdf8`
- `#f4f5fc`
- `#e6e9f9`
- `#6c7fd8`
- `#8fa0e6`
- `#4b5fc4`
- `#1e2a5a`
- `#3a466e`
- `#6b7391`
- `#c7cdea`

## Typography

Families: Century Gothic, Georgia. Weights: 400, 600, 700.

**PowerPoint-safe fonts:**

- heading: Century Gothic
- body: Georgia

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Periwinkle

Design token description: Periwinkle is a light education system built on a milk-white ground (#fdfdf8) with soft paper surfaces (#f4f5fc) and pale panel tints (#e6e9f9) that keep the canvas airy and unthreatening. Navy ink (#1e2a5a) carries all reading text, with a secondary ink (#3a466e) for supporting copy and a cool grey (#6b7391) for captions and metadata. The signature accent is periwinkle #6c7fd8, deployed as chips, underlines, progress dots, and generous rounded banners; a lighter tint (#8fa0e6) fills large friendly shapes, and a deepened periwinkle (#4b5fc4) handles small emphasis marks where extra contrast helps. Hairline keylines use #c7cdea. Headings are set in Century Gothic — geometric, round, optimistic — at weights 600 and 700 with slightly open tracking (+1%); body copy is Georgia 400 for a warm, bookish reading rhythm, with 600 reserved for inline emphasis. Panels are flat with 12–16px corner radii and no drop shadows; separation comes from tint shifts, never depth effects. The accent never carries paragraph text and never sits at full strength behind navy body copy. The overall personality is a bright, kind classroom: playful geometry, patient serifs, generous breathing room.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- Detected source-domain vocabulary: none (original system). Translate style into reusable visual behavior, not literal imagery.
- Avoid literal source imagery unless the exact slide text or visual direction explicitly requests it.

Overall visual personality: A sunny, encouraging classroom voice — round geometric headings, warm serif body text, and periwinkle accents that cheer without shouting.

Reusable visual grammar extracted from DESIGN.md:
- 12-column grid with wide 96px outer margins; content clusters toward the upper-left, leaving playful negative space lower-right.
- Rounded rectangles (12–16px radius) in #f4f5fc or #e6e9f9 group related content; never more than three panels per slide.
- Periwinkle #6c7fd8 appears as a short 8px underline bar beneath the title on every content slide — the system's signature mark.
- Numbered steps render as #8fa0e6 circles with #1e2a5a numerals, connected by dotted #c7cdea leader lines.
- Hierarchy is built from size jumps (about 2x title-to-body), not color variety; at most two ink tones per text block.
- Icons are simple two-tone line glyphs: #1e2a5a strokes with a single #8fa0e6 fill shape.
- One oversized pale periwinkle circle or quarter-round may bleed off a corner, at most once per slide.
- Emphasis words in body copy use Georgia 600 in #4b5fc4, never underlines or highlights.

Chart and infographic grammar:
- Charts inherit the palette: series order #6c7fd8, #4b5fc4, #8fa0e6, then #6b7391; gridlines hairline #c7cdea on #fdfdf8.
- Axis labels and values set in Georgia 400 #3a466e; chart titles in Century Gothic 600 #1e2a5a.
- Bars and donuts get 6px rounded caps; the single most important data point may be the only saturated #4b5fc4 element.
- No 3D, no gradients, no shadowed plot areas; callout values sit in small #e6e9f9 rounded chips.

Image and illustration grammar:
- Subject comes from the slide JSON; render it as bright, softly lit photography or flat friendly illustration.
- Images sit inside rounded-corner frames matching panel radii, occasionally with a 4px #8fa0e6 offset keyline for a sticker-like feel.
- Never tint imagery fully periwinkle; the accent frames imagery, it does not flood it.

Slide graphic system:
- Section dividers: full-bleed #6c7fd8 field with milk-white Century Gothic 700 title and a single oversized outline numeral in #8fa0e6.
- Footers carry a small #6c7fd8 dot plus page number in Georgia 400 #6b7391.
- Agenda and recap slides reuse the numbered-circle system so the deck reads as one continuous lesson.
```
