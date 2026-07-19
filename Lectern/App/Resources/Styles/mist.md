# Mist

**ID:** `mist`  
**Category:** consumer  
**Theme:** light  
**Vibe:** Technical

## Color palette

- `#222222`
- `#ffffff`
- `#fff9f3`
- `#7a7876`
- `#000000`
- `#574853`
- `#c094e4`
- `#f7bbe6`
- `#ffb760`
- `#fce0ee`

## Typography

Families: "'PP Fraktion Mono', ui-monospace, monospace", "Fellix, -apple-system, BlinkMacSystemFont, sans-serif", "Fellix, sans-serif". Weights: 400, 500.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Hume AI

Design token description: A calm, scientific interface with a near-white canvas where near-black typography (222222) provides crisp legibility. Color is introduced through soft, pastel watercolor washes (rose, mint, peach) used for data visualization and surface tinting, not decoration. A single saturated violet accent (c094e4) appears in data bars and key moments. The typographic system pairs a tightly-tracked, low-contrast sans-serif for headlines and body with a clinical, wide-tracked monospace for data labels and annotations. Components are soft and flat, favoring pill shapes and generous radii (8-24px) with no shadows, separating layers with hue and whitespace.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- No dominant source-domain vocabulary was detected, but still avoid copying example subject matter from the design brief.
- Avoid brand logos, product shots, mascot imagery, packaging, buildings, people, or industry-specific objects unless requested by the slide content.

Overall visual personality: The system reads as a scientific pastel instrument panel: a calm, near-white laboratory canvas ({colors.paper}) where the only hard mark is a soft, near-black ink ({colors.ink} — 222222). Color enters as soft watercolor washes — rose ({colors.surface-blush}), peach ({colors.surface-meringue}), mint ({colors.surface-mint}) — that visualize data and tint surfaces rather than decorate them. The primary typographic signature comes from a low-contrast geometric sans-serif set with tight negative letter-spacing, giving headlines a compact, measured feel. A secondary monospace font provides a "lab-label" voice for data annotations, table headers, and tags, using wider, positive tracking for contrast. The interface is deliberately flat and soft. Components are pill-shaped ({rounded.pill}) or generously rounded ({rounded.lg}, {rounded.xl}), borders are invisible, and shadows are entirely absent. Surfaces separate by hue (e.g., a white {component.data-card} on a warm off-white {colors.bone} background) and generous whitespace ({spacing.section}), not by elevation. The only saturated accent is a violet ({colors.accent} — c094e4) and its associated gradient colors, reserved for data bars and...

Color tokens:
- ink: #222222
- paper: #ffffff
- bone: #fff9f3
- smoke: #7a7876
- carbon: #000000
- body: #574853
- accent: #c094e4
- accent-gradient-pink: #f7bbe6
- accent-gradient-amber: #ffb760
- surface-blush: #fce0ee
- surface-rose-mist: #fdebf7
- surface-meringue: #ffe9cf
- surface-mint: #daf7ee
- surface-seafoam: #cef1e1

Typography tokens:
- hero-display: family Fellix, -apple-system, BlinkMacSystemFont, sans-serif, size 48px, weight 500, line 1.11, tracking -1.2px
- display-lg: family Fellix, sans-serif, size 36px, weight 500, line 1.11, tracking -0.9px
- display-md: family Fellix, sans-serif, size 30px, weight 500, line 1.2, tracking -0.75px
- title-lg: family Fellix, sans-serif, size 24px, weight 500, line 1.25, tracking -0.6px
- title-md: family Fellix, sans-serif, size 20px, weight 500, line 1.33, tracking -0.5px
- title-sm: family Fellix, sans-serif, size 18px, weight 400, line 1.43, tracking -0.45px
- body-md: family Fellix, sans-serif, size 16px, weight 400, line 1.5, tracking -0.4px
- body-sm: family Fellix, sans-serif, size 14px, weight 400, line 1.5, tracking -0.35px
- caption: family 'PP Fraktion Mono', ui-monospace, monospace, size 10px, weight 400, line 1.5, tracking 0.25px
- label-lg: family 'PP Fraktion Mono', ui-monospace, monospace, size 24px, weight 400, line 1.3, tracking 0.6px
- label-md: family 'PP Fraktion Mono', ui-monospace, monospace, size 12px, weight 400, line 1.4, tracking 0.3px
- button: family Fellix, sans-serif, size 14px, weight 500, line 1, tracking -0.35px

Spacing tokens:
- xxs: 4px
- xs: 8px
- sm: 12px
- md: 16px
- lg: 24px
- xl: 32px
- xxl: 48px
- section: 64px

Radius and shape tokens:
- sm: 8px
- md: 12px
- lg: 16px
- xl: 24px
- pill: 9999px
- full: 9999px

Component tokens:
- button-primary: backgroundColor: {colors.ink}, textColor: {colors.on-dark}, typography: {typography.button}, rounded: {rounded.pill}, padding: 16px 24px
- button-secondary-text: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.button}
- top-nav: backgroundColor: {colors.paper}, textColor: {colors.ink}, typography: {typography.nav-link}, height: 60px
- hero-band: backgroundColor: {colors.paper}, textColor: {colors.ink}, typography: {typography.hero-display}, padding: 64px 0
- stat-block: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.label-lg}
- pastel-category-tile: backgroundColor: {colors.surface-blush}, textColor: {colors.body}, typography: {typography.body-sm}, rounded: {rounded.lg}, padding: 16px
- data-card: backgroundColor: {colors.paper}, textColor: {colors.body}, typography: {typography.body-md}, rounded: {rounded.md}, padding: 32px
- data-bar: backgroundColor: {colors.accent}, textColor: {colors.on-dark}, rounded: {rounded.pill}

Color rationale: Base & Surface - Paper ({colors.paper} — ffffff): The base page canvas. - Bone ({colors.bone} — fff9f3): A warm off-white secondary surface, used for subtle background tints behind sections containing white cards to create separation. Text - Ink ({colors.ink} — 222222): Primary text, headlines, filled buttons, icon fills. A near-black, not pure black, to soften the interface. - Body ({colors.body} — 574853): A cool, dark plum for running body text, offering a slightly softer contrast than {colors.ink}. - Smoke ({colors.smoke} — 7a7876): Muted text for helper copy, secondary labels, and disabled states. - On Dark ({colors.on-dark} — ffffff): Text color for use on dark surfaces, like the primary filled button. - Carbon ({colors.carbon} — 000000): Pure black, used sparingly for maximum-contrast icon fills where needed. Accent - Accent ({colors.accent} — c094e4): The primary chromatic accent, a saturated violet. Used for data bar fills and as the anchor of the hero's gradient-text effect. - Accent Gradient Pink ({colors.accent-gradient-pink} — f7bbe6): The midpoint color of the accent gradient. - Accent Gradient Amber ({colors.accent-gradient-amber} — ffb760): The endpoint color of th...

Typography rationale: Font Family The system employs a dual-font strategy for clear functional hierarchy: 1. Primary Sans-Serif (Fellix): A geometric grotesque with low contrast. Used for all display, heading, and body copy. Its signature is its tight negative letter-spacing (-0.025em equivalent) applied at all sizes. 2. Label Monospace (PP Fraktion Mono): A clinical monospace. Used for the "lab-label" voice: uppercase data annotations, column headers, tags, and eyebrow labels. It is always set with positive letter-spacing (+0.025em equivalent) to contrast with the primary sans. Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.hero-display} | 48px | 500 | 1.11 | -1.2px | Main hero headline | | {typography.display-lg} | 36px | 500 | 1.11 | -0.9px | Section headings | | {typography.display-md} | 30px | 500 | 1.2 | -0.75px | Large sub-headings | | {typography.title-lg} | 24px | 500 | 1.25 | -0.6px | Card titles, large stat blocks | | {typography.title-md} | 20px | 500 | 1.33 | -0.5px | Medium card titles | | {typography.title-sm} | 18px | 400 | 1.43 | -0.45px | Sub-section titles, feature block headings | | {typography.body-md} | 16px | 400 |...

Layout system: Spacing System - Base unit: 4px. - Tokens: {spacing.xxs} 4px · {spacing.xs} 8px · {spacing.sm} 12px · {spacing.md} 16px · {spacing.lg} 24px · {spacing.xl} 32px · {spacing.xxl} 48px · {spacing.section} 64px. - Section padding (vertical): {spacing.xxl} (48px) to {spacing.section} (64px) provides generous breathing room between content blocks. - Card internal padding: {spacing.lg} (24px) to {spacing.xl} (32px). - Gutters: {spacing.xl} (32px) between columns in 3-up grids; {spacing.md} (16px) between smaller elements. Grid & Container - Max content width: 1200px, centered. - Alignment: Content is predominantly center-aligned, especially for headlines and introductory text, reinforcing an editorial, single-column reading experience. - Grids: Multi-column content uses simple 2- or 3-column equal-width grids. Whitespace Philosophy The system is comfortable and spacious. It relies on generous whitespace, not dividers or shadows, to separate elements and create a clear hierarchy. The centered, editorial layout encourages focus and deliberate pacing.

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | Flat | No shadow, no border | Body sections, top nav, hero bands, feature blocks on canvas | | Surface Contrast | {colors.paper} card on {colors.bone} background | The primary method of creating depth. Used for data cards and sidebars. | | Hue Contrast | Pastel background {colors.surface-blush} on {colors.paper} canvas | Used for category tiles and illustrative card stacks. | | Stroke | 1px {colors.ink} (rare) | Can be used for hairline dividers in data tables if necessary, but is generally avoided. | The elevation philosophy is strictly flat. There are no drop shadows, blurs, or gradients used to simulate depth. All separation is achieved through color and space: a white card on an off-white background, a pastel tile on a white background, or simply a {spacing.section} gap between two content blocks on the same canvas.

Shape language: Border Radius Scale | Token | Value | Use | |---|---|---| | {rounded.sm} | 8px | Input fields | | {rounded.md} | 12px | Standard content cards | | {rounded.lg} | 16px | Larger cards, category tiles | | {rounded.xl} | 24px | Large illustrative containers | | {rounded.pill} | 9999px | All primary buttons, tags, active-state indicators | The system's shape language is defined by a contrast between soft rectangles and perfect pills. Content lives in containers with a soft {rounded.md} to {rounded.xl} radius. Actions and labels live in {rounded.pill} shapes. This clear distinction between "container" and "action" is a core principle. Iconography Icons are minimal, monochrome line art rendered in {colors.ink}. They are typically 24x24px and used sparingly to support feature blocks or label UI elements. They do not use color fills.

Component language: Buttons - button-primary: The signature action button. A pill-shaped ({rounded.pill}) button with a solid {colors.ink} background and {colors.on-dark} text. Used for all high-emphasis CTAs. - button-secondary-text: A "ghost" button with no background or border, used for secondary actions like "Log In" in the navigation. It uses {colors.ink} for the text color. Navigation - top-nav: A simple, airy top bar with a {colors.paper} background. It is approximately 60px tall and uses generous horizontal padding. Links use {typography.nav-link}. Content Blocks - hero-band: The main page-opener. A centered layout on {colors.paper} canvas. The headline uses {typography.hero-display}. A key phrase within the headline is rendered with a gradient text fill from {colors.accent} to {colors.accent-gradient-amber}. - section-heading: A reusable centered block for titling sections, combining a {typography.display-lg} headline with a {typography.title-sm} sub-headline in {colors.smoke}. - stat-block: A simple, centered column for displaying a key metric. It uses {typography.label-lg} for the number and a smaller monospace label below. Multiple stat blocks are arranged in a row with whitespace separat...

Guardrails: Do - Use the {rounded.pill} shape for every primary action, tag chip, and active-state indicator. - Apply the...
```
