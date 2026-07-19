# Foundry

**ID:** `foundry`  
**Category:** consumer  
**Theme:** light  
**Vibe:** Technical

## Color palette

- `#000000`
- `#ffffff`
- `#616161`
- `#cacaca`
- `#404040`
- `#f1f1f1`
- `#ffdd00`
- `#1a1b1e`

## Typography

Families: "AkkStdRg, ui-sans-serif, system-ui, sans-serif", "FRg, ui-sans-serif, system-ui, sans-serif". Weights: 400.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Freitag

Design token description: An industrial, catalog-like design system built on a stark monochrome foundation of black (000000), white (ffffff), and concrete gray (cacaca). The UI acts as a neutral, structural grid for content, with no brand color in the interface itself. Typography is the primary expressive tool, using a single weight of a Swiss neo-grotesque font with unconventionally tight line-heights on display sizes and wide tracking on labels to create a machine-stamped aesthetic. Interactive elements are universally rendered as horizontal pills with hard-edged 1px outlines, reinforcing the system's mechanical, utilitarian feel. The overall impression is that of a technical specification sheet, not a conventional storefront.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- No dominant source-domain vocabulary was detected, but still avoid copying example subject matter from the design brief.
- Avoid brand logos, product shots, mascot imagery, packaging, buildings, people, or industry-specific objects unless requested by the slide content.

Overall visual personality: This is an industrial, catalog-like design system built on a stark monochrome foundation of black ({colors.primary} — 000000), white ({colors.canvas} — ffffff), and concrete gray ({colors.hairline} — cacaca). The UI acts as a neutral, structural grid for content, with no brand color in the interface itself; color is reserved for content like product photography. Typography is the primary expressive tool, using a single weight (400) of a Swiss neo-grotesque font (Akkurat Standard) with unconventionally tight line-heights on display sizes ({typography.display-lg} at 0.97) and wide tracking on labels ({typography.caption} at +0.5px) to create a machine-stamped aesthetic. Interactive elements are universally rendered as horizontal pills ({rounded.pill}), with hard-edged 1px outlines in {colors.primary}. The system avoids shadows and depth, preferring a flat, printed-matter feel where separation is achieved through thin hairlines. Layout follows a strict modular grid — full-bleed 50/50 hero, then 3-column blocks, then 6-column product matrices. The overall impression is that of a technical specification sheet or shipping manifest, not a conventional storefront. Key Characteristics: - A...

Color tokens:
- primary: #000000
- on-primary: #ffffff
- canvas: #ffffff
- ink: #000000
- body: #000000
- muted: #616161
- hairline: #cacaca
- border-strong: #404040
- surface-inactive: #f1f1f1
- accent-yellow: #ffdd00
- surface-dark-fill: #1a1b1e

Typography tokens:
- display-lg: family AkkStdRg, ui-sans-serif, system-ui, sans-serif, size 48px, weight 400, line 0.97, tracking -0.48px
- display-md: family AkkStdRg, ui-sans-serif, system-ui, sans-serif, size 32px, weight 400, line 0.97, tracking -0.16px
- title-lg: family AkkStdRg, ui-sans-serif, system-ui, sans-serif, size 24px, weight 400, line 1.28, tracking 0
- body-md: family AkkStdRg, ui-sans-serif, system-ui, sans-serif, size 16px, weight 400, line 1.5, tracking 0.32px
- body-sm: family AkkStdRg, ui-sans-serif, system-ui, sans-serif, size 11px, weight 400, line 1.15, tracking 0.44px
- caption: family AkkStdRg, ui-sans-serif, system-ui, sans-serif, size 10px, weight 400, line 1.1, tracking 0.5px
- eyebrow: family AkkStdRg, ui-sans-serif, system-ui, sans-serif, size 8px, weight 400, line 1.1, tracking 0.4px
- product-code: family FRg, ui-sans-serif, system-ui, sans-serif, size 10px, weight 400, line 0.74, tracking 0.5px
- button: family AkkStdRg, ui-sans-serif, system-ui, sans-serif, size 11px, weight 400, line 1.15, tracking 0.5px
- nav-link: family AkkStdRg, ui-sans-serif, system-ui, sans-serif, size 10px, weight 400, line 1.1, tracking 0.5px

Spacing tokens:
- xxs: 4px
- xs: 8px
- sm: 12px
- md: 16px
- lg: 24px
- xl: 32px
- xxl: 48px
- section: 80px

Radius and shape tokens:
- xs: 4px
- md: 12px
- lg: 16px
- pill: 9999px
- full: 9999px

Component tokens:
- button-primary: backgroundColor: {colors.primary}, textColor: {colors.on-primary}, typography: {typography.button}, rounded: {rounded.pill}, padding: 12px 22px
- button-ghost: backgroundColor: {colors.canvas}, textColor: {colors.primary}, typography: {typography.button}, rounded: {rounded.pill}, padding: 12px 22px
- category-card: backgroundColor: transparent, textColor: {colors.on-primary}, typography: {typography.display-lg}
- product-cell: backgroundColor: {colors.canvas}, textColor: {colors.ink}, typography: {typography.body-sm}
- status-badge: backgroundColor: {colors.canvas}, textColor: {colors.ink}, typography: {typography.eyebrow}, rounded: {rounded.pill}
- top-nav: backgroundColor: {colors.canvas}, textColor: {colors.ink}, typography: {typography.nav-link}, height: 64px
- nav-logo-plate: backgroundColor: {colors.primary}, textColor: {colors.on-primary}, rounded: {rounded.lg}
- hero-split: backgroundColor: transparent, textColor: {colors.on-primary}, typography: {typography.display-lg}

Color rationale: Core Palette The system is fundamentally achromatic, relying on the contrast between black, white, and a few grays. - Primary / Ink ({colors.primary} / {colors.ink} — 000000): The dominant color. Used for all text, primary button fills, hairline borders, and icon strokes. - Canvas ({colors.canvas} — ffffff): The page floor, card surfaces, and text color on dark fills ({colors.on-primary}). - Hairline ({colors.hairline} — cacaca): A concrete gray used for the 1px borders that form the catalog grid and divide thumbnails. - Muted ({colors.muted} — 616161): Ash gray for secondary text, helper copy, and tertiary labels. - Surface Dark Fill ({colors.surface-dark-fill} — 1a1b1e): A rare near-black with a touch of warmth, used for alternate solid button fills. Supporting Grays - Border Strong ({colors.border-strong} — 404040): An iron gray for heavier border treatments and section breaks. - Surface Inactive ({colors.surface-inactive} — f1f1f1): A misty gray for inactive button states or subtle background washes. Accent - Accent Yellow ({colors.accent-yellow} — ffdd00): A single, highly-restrained accent used for highlight dots on "NEW" status badges. It is never used for backgrounds, text...

Typography rationale: Font Family The system uses a primary Swiss neo-grotesque, AkkStdRg (Akkurat Standard), for nearly all type roles, from display headlines to small captions. A secondary condensed font, FRg, is reserved for product model codes to give them a distinct, stamped-part-number feel. - AkkStdRg → All display, body, button, and label text. - FRg → Product model codes only (e.g., F141, F531). If the primary fonts are unavailable, Inter is a suitable open-source substitute for AkkStdRg. Hierarchy The entire system operates at a single font weight: 400. There is no bold. Hierarchy is created through size, case, line-height, and letter-spacing. | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.display-lg} | 48px | 400 | 0.97 | -0.48px | Hero headlines, major editorial statements | | {typography.display-md} | 32px | 400 | 0.97 | -0.16px | Section headings | | {typography.title-lg} | 24px | 400 | 1.28 | 0 | Sub-section titles | | {typography.body-md} | 16px | 400 | 1.5 | +0.32px | Main body copy | | {typography.body-sm} | 11px | 400 | 1.15 | +0.44px | Product cell prices, secondary labels | | {typography.button} | 11px | 400 | 1.15 | +0.5px |...

Layout system: Spacing System - Base unit: 4px. - Tokens: {spacing.xxs} 4px · {spacing.xs} 8px · {spacing.sm} 12px · {spacing.md} 16px · {spacing.lg} 24px · {spacing.xl} 32px · {spacing.xxl} 48px · {spacing.section} 80px. - Section padding (vertical): {spacing.section} (80px), consistent between all major content bands. - Card internal padding: {spacing.sm} (12px) for product cells. - Gutters: Gutters are non-existent in the main product grid. Separation is achieved with 1px {colors.hairline} borders that touch, creating a continuous lattice. Grid & Container - Max content width: 1440px, centered for content bands. Hero sections are often full-bleed. - Hero: A strict 50/50 vertical split of two full-bleed image panels. - Category Grid: 3-column grid of square aspect-ratio cards. - Product Grid: 6-column grid of equal-width product cells, forming a continuous ruled matrix. Whitespace Philosophy The system is dense and grid-driven. Whitespace is used to separate major sections ({spacing.section}), but within product grids, space is compressed. The design trusts the hard {colors.hairline} rules to create structure, not generous negative space. The aesthetic is that of a packed shipping manifest or...

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | Flat | No shadow, 1px {colors.hairline} border | The default for all page structure, cards, and product cells. | | Subtle Shadow | rgba(0, 0, 0, 0.12) 2px 2px 10px 0px | Reserved exclusively for the primary floating pill button ({component.button-primary}). | | Subtle Border | rgb(64, 64, 64) 0px -1px 0px 0px | A slightly stronger border ({colors.border-strong}) used for section dividers. | The elevation model is fundamentally flat. The system actively avoids drop shadows, gradients, and other techniques for creating depth. The visual hierarchy is built on typography, scale, and the stark contrast of the monochrome palette. The single, subtle shadow on the primary button is a deliberate exception to make the main CTA float slightly above the flat grid.

Shape language: Border Radius Scale The system uses a minimal and highly opinionated radius scale. The pill shape is dominant. | Token | Value | Use | |---|---|---| | {rounded.xs} | 4px | Inline link highlights | | {rounded.md} | 12px | Product image corners inside cells | | {rounded.lg} | 16px | Navigation elements, utility switchers | | {rounded.pill} | 9999px | All buttons and status badges. This is the signature interactive shape. | Component Shapes - Interactive Elements: All buttons, badges, and utility switchers are pills ({rounded.pill}). There are no rectangular buttons. - Containers: Product cells and category cards are hard-edged squares or rectangles. The container itself is sharp-cornered, while the image content within it may have a {rounded.md} corner. - Icons: Icons are sparse, line-only, and single-weight, confined mostly to navigation (cart, account).

Component language: Buttons button-primary — The highest-priority CTA. A solid {colors.primary} fill with {colors.on-primary} text. Uses {typography.button} (11px, uppercase, wide tracking) and is always shaped as a {rounded.pill}. This is the only component with a subtle drop shadow. button-ghost — The secondary action button. Transparent fill ({colors.canvas}), with a 1px {colors.primary} border and {colors.primary} text. It shares the exact same pill shape and typography as the primary button. Used over images where a solid black fill would be too heavy. Cards & Containers category-card — A square, 3-column card used for top-level navigation. It consists of a full-bleed image with no padding. A {typography.display-lg} headline in {colors.on-primary} is overlaid on the bottom-left, with a {component.button-ghost} directly below it. product-cell — A single item in the 6-column catalog grid. It has a {colors.canvas} background and a 1px {colors.hairline} border on all sides. An image with {rounded.md} corners sits at the top, followed by a {typography.product-code} model number and a price in {typography.body-sm}. status-badge — A small pill-shaped badge ({rounded.pill}) that floats on the bottom-rig...

Guardrails: Do - Use the specified neo-grotesque font for all text. No...
```
