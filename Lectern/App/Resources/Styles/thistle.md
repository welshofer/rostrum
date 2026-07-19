# Thistle

**ID:** `thistle`  
**Category:** education  
**Theme:** light  
**Vibe:** Editorial

## Color palette

- `#f6f1e7`
- `#efe8da`
- `#e4dbc9`
- `#ffffff`
- `#7c6699`
- `#c9b8dd`
- `#3a2a4e`
- `#5c4a70`
- `#948aa3`
- `#2a1d38`

## Typography

Families: Baskerville Old Face, Calibri. Weights: 400, 600, 700.

**PowerPoint-safe fonts:**

- heading: Baskerville Old Face
- body: Calibri

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Thistle

Design token description: Thistle reads like a well-set university quarterly: oat paper, aubergine ink, and a single dusty-violet thread of emphasis. The primary background is oat #f6f1e7 with deeper parchment surfaces #efe8da and #e4dbc9; white #ffffff appears only as inset plates for figures. Ink is aubergine — #3a2a4e for headlines and body, #5c4a70 for secondary text, #948aa3 for folios and captions, and #2a1d38 for rare full-strength moments like drop caps. The accent is dusty violet #7c6699, used the way an editor uses a colored pencil: rules, pull-quote marks, key terms, chart emphasis — plus pale bloom #c9b8dd for tinted sidebars. Headlines are Baskerville Old Face 400 at generous display sizes — its sharp serifs carry authority without bolding; where hierarchy needs weight, Calibri 600 subheads step in. Body is Calibri 400 at comfortable measure (60-72 characters). Tracking stays default; the serif does the talking. Surfaces are flat; structure comes from typographic rules and hanging indents, never from boxes. The accent may underline, flag, and annotate; it may never fill large fields behind body text. Personality: literate, considered, quietly rigorous.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- Detected source-domain vocabulary: none (original system). Translate style into reusable visual behavior, not literal imagery.
- Avoid literal source imagery unless the exact slide text or visual direction explicitly requests it.

Overall visual personality: A scholarly journal page: Baskerville authority on oat paper, annotated in dusty violet.

Reusable visual grammar extracted from DESIGN.md:
- Editorial column logic: a wide main column with a narrow margin column for captions, citations, and violet annotations.
- Baskerville Old Face headlines set sentence case at display size; never all-caps, never tightly tracked.
- Violet #7c6699 behaves like editor marks — 2px rules above kickers, oversized quotation marks, margin flags — small and deliberate.
- Sidebars sit on #c9b8dd or #efe8da tint blocks with a 3px #7c6699 left rule; no other boxes exist in the system.
- Hanging indents and a visible baseline rhythm organize lists; bullets are en-dashes in #7c6699.
- Generous top margin (12%+) with the kicker-headline-standfirst stack establishing a consistent masthead rhythm.
- One typographic moment per slide may go large — a drop cap, a pull-stat, an oversized quote — never more than one.

Chart and infographic grammar:
- Charts sit on white #ffffff plates with aubergine #3a2a4e series ink and dusty violet #7c6699 marking only the emphasized series.
- Gridlines are #e4dbc9 hairlines; axis labels Calibri 400 in #5c4a70; titles set in Baskerville Old Face like figure captions.
- On the light oat ground, numbers stay dark; violet never labels values below 18pt.
- Prefer restrained forms — line, bar, dot plots — captioned and numbered like journal figures (Fig. 1).

Image and illustration grammar:
- Subjects come from the slide JSON; render photography softly lit with a warm paper-toned cast that sits into the oat field.
- Images mount as plates: flush rectangles with a Calibri caption below and a hairline #e4dbc9 rule.
- Illustrations are fine aubergine line engravings with a single violet tint layer at most.

Slide graphic system:
- Dividers: oat field, a Baskerville Old Face numeral at display scale in #7c6699, chapter title in #3a2a4e beneath.
- Icons avoided in favor of typographic markers — numerals, daggers, en-dashes — in dusty violet.
- Folios: Calibri 400 #948aa3 page marks in the outer margin with a short #7c6699 tick.
```
