# Amaranth

**ID:** `amaranth`  
**Category:** media  
**Theme:** dark  
**Vibe:** Bold

## Color palette

- `#231318`
- `#2e1a21`
- `#3a222b`
- `#160b0f`
- `#e11d74`
- `#ff5c9d`
- `#f7e9ee`
- `#d8bfc9`
- `#96808a`
- `#fdf7fa`

## Typography

Families: Rockwell, Arial. Weights: 400, 600, 700.

**PowerPoint-safe fonts:**

- heading: Rockwell
- body: Arial

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Amaranth

Design token description: Amaranth is a printing press running hot after midnight: charcoal-wine darkness, slab-serif conviction, magenta ink that refuses to dry quietly. The primary background is charcoal wine #231318, rising through barrel surfaces #2e1a21 and #3a222b, dropping to #160b0f for blackout beats. Text is rose-white — #f7e9ee for headlines and body, #d8bfc9 secondary, #96808a for bylines and metadata — warm against the wine dark, with #fdf7fa saved for the single hottest line per deck. The accent is magenta #e11d74, stamped in heavy slabs, thick underscores, and numbered blocks; its flare #ff5c9d handles small accent text, tick marks, and chart highlights where more luminance is needed. Headlines are Rockwell 700 — mechanical slab serifs that hit like a headline stamp — set big, tight, often stacked flush-left; Rockwell 400 handles standfirsts. Body is Arial 400 with Arial 700 for lead-ins, workmanlike and invisible. Everything is flat and square: no rounds, no shadows, no gradients. Magenta may slab, underscore, and number; it never carries paragraphs, and body text never sits on #e11d74. Personality: front-page urgent, inky, unapologetically loud.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- Detected source-domain vocabulary: none (original system). Translate style into reusable visual behavior, not literal imagery.
- Avoid literal source imagery unless the exact slide text or visual direction explicitly requests it.

Overall visual personality: Slab-serif front page in the dark: rose-white Rockwell stamped over charcoal wine with wet magenta ink.

Reusable visual grammar extracted from DESIGN.md:
- Stacked flush-left Rockwell headlines with tight leading (0.95) — a headline block that reads as one stamped unit.
- Thick magenta #e11d74 underscores (8-12px) beneath the key phrase; the system’s signature stamp.
- Numbered slab blocks: #e11d74 squares holding Rockwell 700 numerals in #f7e9ee organize sequences and agendas.
- Panels rise by tone (#2e1a21, #3a222b), square-cornered, flat; column rules are 1px #3a222b like newsprint dividers.
- Hard modular grid — 6 columns, visible discipline — with one element allowed to break a column boundary per slide.
- Kickers in Arial 700, uppercase, +12% tracking, #ff5c9d, always above the headline like a section tag.
- Blackout pull-quotes: full #160b0f field, one #fdf7fa Rockwell line, magenta underscore.

Chart and infographic grammar:
- Series order: magenta #e11d74, flare #ff5c9d, rose #d8bfc9; remaining series in #96808a — flat square bars, no rounding.
- Gridlines #3a222b; axis and value labels Arial 400 in #d8bfc9 or brighter on the dark ground — #96808a only above 14pt.
- Hero datapoint treatment: Rockwell 700 numeral in #ff5c9d at display size with a magenta underscore.
- Prefer bold horizontal bars and big-number stats; avoid delicate line charts and all decorative 3D.

Image and illustration grammar:
- Subjects come from the slide JSON; photography is grainy, high-contrast, pushed toward the wine-dark shadows.
- Default treatment is a magenta-duotone press-ink wash; full color only when slide direction explicitly asks.
- Images run full-bleed or flush to two edges, cropped tight and cinematic — never floating thumbnails.

Slide graphic system:
- Dividers: full-bleed #e11d74 field, Rockwell 700 section word reversed in #231318, edition-style folio in #f7e9ee.
- Icons are heavy filled glyphs in #ff5c9d on #3a222b squares, matching the slab weight.
- Footers mimic a masthead rule: 1px #3a222b line, Arial 400 #96808a metadata, magenta tick.
```
