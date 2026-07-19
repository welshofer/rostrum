# Cypress

**ID:** `cypress`  
**Category:** consumer  
**Theme:** dark  
**Vibe:** Editorial

## Color palette

- `#143930`
- `#f8f2de`
- `#bead89`
- `#456859`

## Typography

Families: "'Old Standard TT', 'Cormorant Garamond', serif", "'altesse-std-24pt', 'Playfair Display', 'DM Serif Display', serif", "EditorialOld, 'Old Standard TT', 'Cormorant Garamond', serif", "GTA, 'Cormorant Garamond', 'EB Garamond', serif". Weights: 100, 200, 300, 400.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Haley Park

Design token description: A personal dynamic transaction/data-flow pattern system built on a dark forest-green manuscript — the page reads like a hand-illuminated codex. The entire interface lives inside a single chromatic mood, a deep pine canvas (143930), with warm parchment text (f8f2de), and a sage structural accent (456859) for line work and iconography. Typography stays in the weight-200 whisper range across a curated family of editorial serifs, with one display cut used as a single monumental name treatment. Decorative gothic architecture — rose windows, arches, intersecting plus-signs at line junctions — bleeds through the layout as full-width structural pattern rather than ornament.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- Detected source-domain vocabulary: finance/banking. Translate it into reusable visual behavior, not literal imagery.
- Avoid literal source imagery unless the exact slide text or visual direction explicitly requests it: credit cards, debit cards, bank apps, cash, coins, trading screens, or crypto coins; financial product mockups unless requested by slide content.

Overall visual personality: This is a design system that reads like a hand-illuminated codex. The entire interface lives inside a single chromatic mood: a deep pine-green canvas ({colors.canvas-dark} — 143930) holding warm parchment text ({colors.body} — f8f2de). A structural sage green ({colors.accent} — 456859) provides a third tone for decorative line work and iconography, keeping the palette strictly monochromatic and earth-toned. The system rejects conventional web elevation — there are no drop shadows, no filled layered rectangular token motif, and no gradients. Instead, depth comes from the high contrast between parchment and pine (11.3:1) and from the layering of decorative architectural line art that bleeds through the background as a watermark. Typography is exclusively editorial serif, set at ultra-light weights (100–300). The primary workhorse family is a thin-stroked serif that carries navigation, titles, and body copy at a consistent weight of 200. This keeps the type feeling quiet and integrated, like text on a manuscript page. The system allows itself a single moment of volume: a monumental 96px display cut ({typography.hero-display}) used for the primary page headline. All other text element...

Color tokens:
- canvas-dark: #143930
- body: #f8f2de
- on-dark: #f8f2de
- muted: #bead89
- accent: #456859
- hairline: #f8f2de

Typography tokens:
- hero-display: family Wispy, Italiana, Marcellus, Cormorant SC, serif, size 96px, weight 100, line 1, tracking -0.96px
- display-lg: family EditorialOld, 'Old Standard TT', 'Cormorant Garamond', serif, size 32px, weight 200, line 1.2, tracking 0.16px
- display-md: family 'altesse-std-24pt', 'Playfair Display', 'DM Serif Display', serif, size 27px, weight 300, line 1.1, tracking 0.135px
- title-lg: family EditorialOld, 'Old Standard TT', 'Cormorant Garamond', serif, size 21px, weight 200, line 1.44, tracking 0.084px
- title-md: family EditorialOld, 'Old Standard TT', 'Cormorant Garamond', serif, size 19px, weight 200, line 1.3, tracking 0.076px
- body-md: family EditorialOld, 'Old Standard TT', 'Cormorant Garamond', serif, size 16px, weight 200, line 1.5, tracking 0.064px
- body-sm: family GTA, 'Cormorant Garamond', 'EB Garamond', serif, size 15px, weight 300, line 1.6, tracking 0.06px
- caption: family 'Old Standard TT', 'Cormorant Garamond', serif, size 13px, weight 200, line 1.5, tracking 0
- button: family EditorialOld, 'Old Standard TT', 'Cormorant Garamond', serif, size 16px, weight 200, line 1.2, tracking 0.064px
- nav-link: family EditorialOld, 'Old Standard TT', 'Cormorant Garamond', serif, size 16px, weight 200, line 1.5, tracking 0.064px
- chip-label: family ui-sans-serif, Inter, 'IBM Plex Mono', sans-serif, size 16px, weight 400, line 1, tracking 0

Spacing tokens:
- xxs: 4px
- xs: 12px
- sm: 18px
- md: 26px
- lg: 32px
- xl: 64px
- xxl: 102px
- section: 51px

Radius and shape tokens:
- none: 0px
- md: 4.8px
- pill: 64px
- full: 64px

Component tokens:
- top-nav: backgroundColor: {colors.canvas-dark}, textColor: {colors.body}, typography: {typography.nav-link}, height: 48px, borderColor: {colors.hairline}, borderWidth: 1px 0
- button-outlined: backgroundColor: transparent, textColor: {colors.body}, typography: {typography.button}, rounded: {rounded.md}, padding: 11px 22px, borderColor: {colors.hairline}, borderWidth: 1px
- keyboard-chip: backgroundColor: transparent, textColor: {colors.body}, typography: {typography.chip-label}, rounded: {rounded.md}, borderColor: {colors.hairline}, borderWidth: 1px, padding: 4px 8px, height: 24px
- project-tile: backgroundColor: transparent, textColor: {colors.body}, typography: {typography.title-lg}, padding: 0
- project-tile-meta: backgroundColor: transparent, textColor: {colors.muted}, typography: {typography.caption}
- category-tag: backgroundColor: transparent, textColor: {colors.muted}, typography: {typography.caption}
- display-nameplate: backgroundColor: transparent, textColor: {colors.body}, typography: {typography.hero-display}
- text-link: backgroundColor: transparent, textColor: {colors.body}, typography: {typography.body-md}

Color rationale: Core Palette - Pine Vellum ({colors.canvas-dark} — 143930): The universal page canvas. All sections and text sit directly on this deep, dark green. - Parchment ({colors.body} — f8f2de): The primary text color. Also used for all interactive borders, hairlines, and divider rules, making it the system's "ink." - Aged Tan ({colors.muted} — bead89): Muted secondary text for metadata, such as project years and category tags. Sits tonally between the parchment and the canvas. - Cedar Stroke ({colors.accent} — 456859): A secondary sage green used exclusively for decorative, non-interactive elements like background architectural illustrations and ornamental motifs.

Typography rationale: Font Family The system relies on a curated set of editorial serifs to achieve its manuscript quality. Different font families are used for specific roles: a primary family for most editorial content (EditorialOld), a monumental cut for the hero (Wispy), and specialized faces for alternate body copy and section headers. All are set at extremely light weights to maintain a delicate, inscribed feel. A system sans-serif is used only for single-letter keyboard shortcut chips. Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.hero-display} | 96px | 100 | 1.0 | -0.96px | The single primary page headline. | | {typography.display-lg} | 32px | 200 | 1.2 | 0.16px | Large sub-section titles. | | {typography.display-md} | 27px | 300 | 1.1 | 0.135px | Mid-level section headers. | | {typography.title-lg} | 21px | 200 | 1.44 | 0.084px | Project titles in a grid. | | {typography.title-md} | 19px | 200 | 1.3 | 0.076px | Subheadings, italic descriptors. | | {typography.body-md} | 16px | 200 | 1.5 | 0.064px | Default running-text, navigation links. | | {typography.body-sm} | 15px | 300 | 1.6 | 0.06px | Secondary body copy in long-form sec...

Layout system: Spacing System - Base unit: The system uses an organic, non-4px-grid scale derived from typographic measure. - Tokens: {spacing.xxs} 4px · {spacing.xs} 12px · {spacing.sm} 18px · {spacing.md} 26px · {spacing.lg} 32px · {spacing.xl} 64px · {spacing.xxl} 102px. - Section gap (vertical): {spacing.section} (51px) between major content blocks. This consistent rhythm creates a measured, book-like pacing. - Grid gutters: {spacing.md} (26px) for both column and row gaps in project grids. - Element gap: {spacing.xs} (12px) for spacing between elements inside a component, like a button label and its accompanying icon. Grid & Container - Full-bleed: There is no max-width container. All content, including text and decorative art, bleeds to the edges of the viewport. - Centered Grids: While the page is full-bleed, content grids (like a 4-column project list) are centered within the viewport, with organic outer margins. - Layout Rhythm: The page alternates between text-only sections and sections with decorative background art, creating a visual pulse of quiet followed by ornament.

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | 0 (Canvas) | {colors.canvas-dark} flat background | The universal page floor for all content. | | 1 (Line Art) | {colors.accent} stroke at low opacity | Decorative background patterns (arches, windows) sit on the canvas. | | 2 (Text/UI) | {colors.body} and {colors.muted} text | All text and UI elements sit on top of the canvas and line art. | The system actively rejects conventional elevation models. There are no drop shadows, no gradients, and no card-like surfaces. Depth is communicated exclusively through layering: text and UI lines in high-contrast {colors.body} sit atop a low-contrast {colors.accent} layer of architectural line art, which in turn sits on the {colors.canvas-dark} base. It is a flat system that feels deep due to its careful use of contrast and layering.

Shape language: Border Radius Scale | Token | Value | Use | |---|---|---| | {rounded.none} | 0px | Default for all containers, project tiles, and layout blocks. | | {rounded.md} | 4.8px | Interactive elements: outlined buttons and keyboard shortcut chips. | | {rounded.pill} | 64px | Decorative circular ornaments and motifs. | | {rounded.full} | 64px | Synonym for {rounded.pill}. | The shape language is overwhelmingly rectilinear. The default corner radius is zero, giving the layout a sharp, engraved quality. Small, subtle rounding is permitted only on the smallest interactive controls to soften their touch targets. Iconography & Illustration All decorative elements are abstract architectural line art. SVGs of rose windows, pointed arches, and geometric patterns are rendered as 1px strokes in {colors.accent} with no fill. These drawings are not icons in containers; they are full-bleed background patterns. Iconography follows the same logic: small line-art glyphs (like the + crosshairs on dividers) are drawn with 1px {colors.body} strokes.

Component language: Top Navigation top-nav — A full-bleed horizontal bar at the top of the page, framed by 1px hairlines in {colors.hairline}. The background is the page's {colors.canvas-dark}. It contains a few primary navigation links, set in {typography.nav-link}, each paired with a {component.keyboard-chip}. The total height is minimal, around 48px. Buttons button-outlined — The only button style in the system. It is a ghost button with a transparent background and a 1px border in {colors.hairline}. The corner radius is {rounded.md} (4.8px), and the text is set in {typography.button}. There are no filled or solid buttons. keyboard-chip — A small, square-like chip indicating a keyboard shortcut. It shares the same style as button-outlined: a 1px {colors.hairline} border, {rounded.md} corners, and a transparent fill. Inside, a single uppercase letter is set in {typography.chip-label}. text-link — Inline links within paragraphs are set in the same {colors.body} color as the surrounding text. The only affordance is a 1px underline in {colors.hairline}. Content project-tile — A borderless, shadowless block used in project grids. It consists of a title set in {typography.title-lg} and, directly below i...

Guardrails: Do - Use {colors.canvas-dark} as the only page background. Do not introduce lighter or darker surface tints for layered rectangular token motif or sections. - Set almost all text in weight 100-300. Heavier weights break the delicate...
```
