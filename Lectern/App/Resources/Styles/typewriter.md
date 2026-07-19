# Typewriter

**ID:** `typewriter`  
**Category:** media  
**Theme:** light  
**Vibe:** Editorial

## Color palette

- `#f5f2e9`
- `#efebe0`
- `#e6e1d3`
- `#c0392b`
- `#96291d`
- `#d96a5e`
- `#1c1a17`
- `#413d36`
- `#6f6a5f`
- `#cfc9b8`

## Typography

Families: Courier New, Courier New. Weights: 400, 600, 700.

**PowerPoint-safe fonts:**

- heading: Courier New
- body: Courier New

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Typewriter

Design token description: Typewriter is a monospaced editorial system that renders every slide like a page pulled from a newsroom manual. The ground is manuscript paper #f5f2e9, aged one shade at surfaces #efebe0 and file-folder panels #e6e1d3. All type — every heading, byline, caption, and footnote — is Courier New: carbon-black #1c1a17 (over 15:1 on the paper) struck at 700 for headlines, 600 for slugs and subheads, and 400 for copy, with faded-ribbon #413d36 for secondary text and #6f6a5f for marginalia. Tracking is the machine's own; letterspacing is never adjusted, and ALL CAPS with underscores or brackets does the work italics would. The accent is stamp red #c0392b — the editor's rubber stamp and grease pencil — for APPROVED-style flags, key figures, strike-rules, and margin marks; #96291d is its dried, heavy impression and #d96a5e its faded second strike for large tinted blocks. Hairlines #cfc9b8 rule the page like ledger lines. There are no curves, no gradients, no shadows — only stamped ink, ruled lines, and paper. Alignment is strictly typewriter-flush-left with visible tab-stop columns. The personality is deadline urgency in a quiet room: mechanical, literary, and a little bit ink-stained.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- Detected source-domain vocabulary: none (original system). Translate style into reusable visual behavior, not literal imagery.
- Avoid literal source imagery unless the exact slide text or visual direction explicitly requests it.

Overall visual personality: A manuscript fresh off the platen — monospaced carbon ink on aged paper, punctuated by stamp-red editorial marks.

Reusable visual grammar extracted from DESIGN.md:
- Everything aligns to a monospaced character grid: columns land on tab stops; vertical rhythm follows fixed line increments.
- Headlines are Courier New 700 ALL CAPS in #1c1a17, preceded by a slug line ('RE:', numbered heads) in 600 #413d36.
- The stamp mark — one angled or boxed #c0392b element per slide (stamp box, margin dagger, double strike-rule) — is the signature gesture.
- Bullets are typewriter glyphs: hyphens, asterisks, or '>' characters in #413d36; nested items indent by exact character widths.
- Full-width #cfc9b8 ruled lines separate sections; boxes are simple square-cornered 1px rules.
- Emphasis uses 700 weight or [BRACKETED CAPS] in #96291d — never italics, never letterspacing changes.
- Panels #efebe0 and #e6e1d3 read as stacked sheets: square corners, hairline edges, no shadows.
- Wide margins on both sides mimic a typed page; text measure stays near 62 characters.

Chart and infographic grammar:
- Charts are drawn like wire-service graphics: #cfc9b8 grid, #413d36 axes, data in carbon #1c1a17 with the argued series stamped #c0392b.
- All chart text is Courier New 400 #413d36; values direct-labeled in 700; legends replaced by labeled leader lines.
- Bars are square-cornered, hatched or solid; lines are 2px with '+' tick markers.
- Large tinted fills use faded #d96a5e; fine strokes and small text accents always use #c0392b or #96291d.

Image and illustration grammar:
- Subject comes from the slide JSON; photography renders as grainy documentary black-and-white, like a wirephoto on newsprint.
- Images sit in hairline #cfc9b8 frames with Courier New 400 #6f6a5f captions beneath, prefixed 'FIG.' and numbered.
- Illustrations are ASCII-flavored line diagrams: 1px rules, square joints, character-grid spacing.

Slide graphic system:
- Section dividers: near-blank sheet, huge stamped #c0392b section number in a rule box, typed title beneath.
- Footer: a typed status line — page number, deck slug, date — in Courier New 400 #6f6a5f between two hairlines.
- The stamp gesture and ruled ledger lines repeat on every page, so the deck reads as one continuous typed manuscript.
```
