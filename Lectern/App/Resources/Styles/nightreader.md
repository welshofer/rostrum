# Night Reader

**ID:** `nightreader`  
**Category:** accessibility  
**Theme:** dark  
**Vibe:** Minimal

## Color palette

- `#101010`
- `#1a1815`
- `#242019`
- `#ffb000`
- `#ffc94d`
- `#d08c00`
- `#f2e8d5`
- `#cfc4ae`
- `#8f8778`
- `#3a352c`

## Typography

Families: Verdana, Georgia. Weights: 400, 600, 700.

**PowerPoint-safe fonts:**

- heading: Verdana
- body: Georgia

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Night Reader

Design token description: Night Reader is a low-blue-light dark reading system for late rooms and tired eyes. The ground is soft near-black #101010 — never pure black, to avoid halation around text — with warm charcoal surfaces #1a1815 and raised panels #242019 that lean brown rather than blue. Every hue in the system sits on the warm side of the wheel: primary text is candlelit parchment #f2e8d5 (over 15:1 on the ground, comfortably AAA), secondary text #cfc4ae, and tertiary metadata #8f8778, the dimmest tone permitted to carry words. The single accent is amber #ffb000 (better than 10:1 on #101010), used for emphasis words, key numbers, rules, and wayfinding; #ffc94d is its lighter tint for large fills and highlighted panels, and #d08c00 its deep shade for borders and chart secondaries. #3a352c draws hairlines and gridlines. Headings are Verdana 700 — wide, unambiguous letterforms built for screens — with normal tracking; body is Georgia 400 at generous line spacing (1.45) for long-passage comfort, 600 for inline emphasis. There are no cool greys, no blue-tinted shadows, no glows. The personality is a dim library lamp: calm, warm, effortless to read for an hour straight.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- Detected source-domain vocabulary: none (original system). Translate style into reusable visual behavior, not literal imagery.
- Avoid literal source imagery unless the exact slide text or visual direction explicitly requests it.

Overall visual personality: A warm amber lamp in a dark study — parchment text on near-black, zero blue light, zero strain.

Reusable visual grammar extracted from DESIGN.md:
- Single generous reading column, 60-character measure, vertically centered; dark slides earn extra negative space because the void is part of the calm.
- Panels #1a1815 and #242019 are flat with 8px radii; elevation is expressed by warmth of tone, never by shadows or glows.
- Titles in Verdana 700 #f2e8d5 sit above a 2px amber #ffb000 rule that spans exactly the title width.
- One amber element per zone: an emphasized word, a number, or a rule — amber is wayfinding, not decoration.
- Bullets are small amber squares; body text remains parchment, with Georgia 600 (not color) for in-sentence emphasis.
- Hairlines #3a352c separate regions; borders around text blocks are avoided in favor of spacing.
- Large statistics render in Verdana 700 #ffc94d with the supporting sentence in #cfc4ae beneath.
- Text never sits on imagery or texture; contrast is preserved absolutely everywhere.

Chart and infographic grammar:
- Dark-mode charts: plot on #101010 or #1a1815, gridlines #3a352c, axis text Georgia 400 #cfc4ae at large sizes.
- Series order: #ffb000, #ffc94d, #d08c00, then #8f8778; the argument series is always the brightest amber.
- Direct labels in #f2e8d5 replace legends; no color below #8f8778 luminance ever encodes meaning.
- Fills are solid; no gradients, no glow effects, no translucent overlays that muddy contrast.

Image and illustration grammar:
- Subject comes from the slide JSON; photography is rendered moody and warm-graded — amber highlights, deep brown shadows, no cool tones.
- Images sit in #242019 frames with 1px #3a352c keylines, sized to leave the reading column undisturbed.
- Illustrations are minimal line work in #cfc4ae with a single amber accent shape.

Slide graphic system:
- Section dividers: full #101010 field, an oversized amber numeral in Verdana 700 #d08c00 at low prominence, title in parchment.
- Footer: page number in Georgia 400 #8f8778, bottom-right, small but AAA-safe at its size against the ground.
- The amber title rule and square bullets recur on every slide, making the deck read as one long, restful document.
```
