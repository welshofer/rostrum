# Lilac

**ID:** `lilac`  
**Category:** consumer  
**Theme:** light  
**Vibe:** Minimal

## Color palette

- `#7b68ee`
- `#514b81`
- `#292d34`
- `#646464`
- `#838383`
- `#e8e8e8`
- `#ffffff`
- `#202020`
- `#f0f0f0`
- `#000000`

## Typography

Families: "'Inter', ui-sans-serif, system-ui, -apple-system, sans-serif", "'Plus Jakarta Sans', ui-sans-serif, system-ui, -apple-system, sans-serif", "'Sometype Mono', ui-monospace, SFMono-Regular, Menlo, Monaco, monospace". Weights: 400, 500, 650, 700.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Qatalog

Design token description: A near-monochrome productivity canvas defined by a pure white (ffffff) background and dark slate ink (292d34). The system uses a restrained two-violet accent system (7b68ee and 514b81) for small, functional punctuation like links and interactive borders, rather than broad color washes. Typography is compact and confident, using Plus Jakarta Sans for headlines with tight negative tracking, and Inter for UI and body copy. Surfaces are flat and architectural, with depth created by dark filled cards (202020) and consistent 9px/18px radii, not drop shadows. A single rainbow gradient provides a rare chromatic release on the final dark CTA section.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- No dominant source-domain vocabulary was detected, but still avoid copying example subject matter from the design brief.
- Avoid brand logos, product shots, mascot imagery, packaging, buildings, people, or industry-specific objects unless requested by the slide content.

Overall visual personality: This is a near-monochrome productivity canvas built on a foundation of pure white ({colors.canvas-light} — ffffff) and dark slate ink ({colors.ink} — 292d34). The system is intentionally quiet and architectural, using a restrained two-violet accent system for functional punctuation. The primary accent, Iris ({colors.primary} — 7b68ee), appears only on interactive elements like links and feature labels. Surfaces are flat; depth is created by the high contrast of dark filled cards ({colors.surface-dark} — 202020) against the white canvas, framed by consistent {rounded.sm} (9px) and {rounded.md} (18px) radii. Typography is compact and confident. Plus Jakarta Sans carries display and heading roles with tight negative letter-spacing, giving headlines a dense, engineered quality. Inter handles all UI chrome, body copy, and navigation at smaller sizes, maintaining a tight, considered feel. The single moment of chromatic release is a rainbow gradient that accents the final dark CTA section, acting as the only multi-hue element in an otherwise quiet layout. Key Characteristics: - Flat design: No drop shadows are used. Depth is communicated entirely through surface color contrast. - Monochr...

Color tokens:
- primary: #7b68ee
- primary-deep: #514b81
- ink: #292d34
- body: #292d34
- muted: #646464
- disabled-text: #838383
- hairline: #e8e8e8
- canvas-light: #ffffff
- on-dark: #ffffff
- surface-dark: #202020
- surface-dark-strong: #292d34
- surface-soft-light: #f0f0f0
- border-accent: #7b68ee
- border-muted: #646464

Typography tokens:
- hero-display: family 'Plus Jakarta Sans', ui-sans-serif, system-ui, -apple-system, sans-serif, size 60px, weight 700, line 1.1, tracking -2.82px
- display-lg: family 'Plus Jakarta Sans', ui-sans-serif, system-ui, -apple-system, sans-serif, size 48px, weight 700, line 1.15, tracking -1.92px
- display-md: family 'Plus Jakarta Sans', ui-sans-serif, system-ui, -apple-system, sans-serif, size 40px, weight 700, line 1.15, tracking -1.4px
- display-sm: family 'Plus Jakarta Sans', ui-sans-serif, system-ui, -apple-system, sans-serif, size 34px, weight 650, line 1.2, tracking -1.19px
- title-md: family 'Inter', ui-sans-serif, system-ui, -apple-system, sans-serif, size 18px, weight 650, line 1.38, tracking -0.36px
- body-md: family 'Inter', ui-sans-serif, system-ui, -apple-system, sans-serif, size 16px, weight 400, line 1.5, tracking -0.288px
- body-sm: family 'Inter', ui-sans-serif, system-ui, -apple-system, sans-serif, size 14px, weight 400, line 1.43, tracking -0.196px
- caption: family 'Inter', ui-sans-serif, system-ui, -apple-system, sans-serif, size 12px, weight 650, line 1.14, tracking -0.132px
- eyebrow: family 'Sometype Mono', ui-monospace, SFMono-Regular, Menlo, Monaco, monospace, size 14px, weight 500, line 1.25
- button: family 'Inter', ui-sans-serif, system-ui, -apple-system, sans-serif, size 16px, weight 650, line 1, tracking -0.288px
- nav-link: family 'Inter', ui-sans-serif, system-ui, -apple-system, sans-serif, size 16px, weight 500, line 1.5, tracking -0.288px

Spacing tokens:
- xxs: 4px
- xs: 8px
- sm: 12px
- md: 16px
- lg: 20px
- xl: 40px
- xxl: 48px
- section: 80px

Radius and shape tokens:
- sm: 9px
- md: 18px
- lg: 30px
- pill: 9999px
- full: 9999px

Component tokens:
- button-primary-dark: backgroundColor: {colors.surface-dark}, textColor: {colors.on-dark}, typography: {typography.button}, rounded: {rounded.sm}, padding: 9px 20px
- text-link: backgroundColor: transparent, textColor: {colors.primary}, typography: {typography.body-md}
- top-nav: backgroundColor: {colors.canvas-light}, textColor: {colors.muted}, typography: {typography.nav-link}, padding: 12px 20px
- hero-card-dark: backgroundColor: {colors.surface-dark}, textColor: {colors.on-dark}, rounded: {rounded.md}, padding: 32px
- feature-card: backgroundColor: transparent, textColor: {colors.muted}, typography: {typography.body-sm}
- eyebrow-label: backgroundColor: transparent, textColor: {colors.primary}, typography: {typography.eyebrow}
- cta-panel-gradient: backgroundColor: {colors.surface-dark}, textColor: {colors.on-dark}, rounded: {rounded.md}, padding: 48px
- footer: backgroundColor: {colors.canvas-light}, textColor: {colors.muted}, typography: {typography.body-sm}, padding: 64px 0

Color rationale: Brand & Accent - Iris ({colors.primary} — 7b68ee): The primary accent. A vivid violet used for link text, interactive borders, feature labels, and eyebrow text. It's a signal color, used to draw attention to interactive elements. - Aubergine ({colors.primary-deep} — 514b81): A secondary, deeper violet used for section dividers and alternate accent borders. It is always paired with Iris. - Gradient Hues ({colors.accent-cyan}, {colors.accent-magenta}, {colors.accent-magenta-deep}): A set of bright cyan, magenta, and deep magenta hues that form the signature rainbow gradient. These are used exclusively in the {component.cta-panel-gradient} and nowhere else. Surface - Canvas Light ({colors.canvas-light} — ffffff): The default page background. The dominant surface. - Surface Soft Light ({colors.surface-soft-light} — f0f0f0): A subtle off-white tint used for ghost button backgrounds or hovered navigation wells. - Surface Dark ({colors.surface-dark} — 202020): Dark charcoal for primary button backgrounds and elevated dark cards, like the hero product preview and final CTA panel. - Surface Dark Strong ({colors.surface-dark-strong} — 292d34): The same as {colors.ink}, used for secondary da...

Typography rationale: Font Family The system uses a three-part font stack for clear role separation: - Plus Jakarta Sans: The display and heading face. Used for all large headlines with aggressive negative tracking for a dense, engineered aesthetic. - Inter: The UI and body face. Used for all body copy, navigation, button labels, and captions. Its slightly negative default tracking maintains the system's compact feel. - Sometype Mono: The eyebrow and badge accent face. Used for uppercase mono labels that add a technical, editorial counterpoint to the sans-serif system. Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.hero-display} | 60px | 700 | 1.1 | -2.82px | Main page hero headline | | {typography.display-lg} | 48px | 700 | 1.15 | -1.92px | Large section headings | | {typography.display-md} | 40px | 700 | 1.15 | -1.4px | Standard section headings | | {typography.display-sm} | 34px | 650 | 1.2 | -1.19px | Sub-section headings | | {typography.title-md} | 18px | 650 | 1.38 | -0.36px | Card titles, highlighted subheadings | | {typography.body-md} | 16px | 400 | 1.5 | -0.288px | Default running text | | {typography.body-sm} | 14px | 400 | 1....

Layout system: Spacing System - Base unit: 4px. - Tokens: {spacing.xxs} 4px · {spacing.xs} 8px · {spacing.sm} 12px · {spacing.md} 16px · {spacing.lg} 20px · {spacing.xl} 40px · {spacing.xxl} 48px · {spacing.section} 80px. - Section padding (vertical): {spacing.section} (80px) or greater. The system uses generous whitespace between major content blocks to let the typography breathe. - Card internal padding: {spacing.xl} (40px) to {spacing.xxl} (48px) for large dark-surface cards. - Gutters: {spacing.md} (16px) to {spacing.lg} (20px) for internal element gaps. The system is compact inside components, but airy between them. Grid & Container - Max content width: ~1200px, centered. - Editorial body: Typically single-column or two-column grids for feature sections. - Footer: A dense 5-column link list at desktop. Whitespace Philosophy The system's philosophy is "airy between, compact within." Large sections are separated by generous {spacing.section} gaps, creating a calm, focused rhythm. Inside components and typographic blocks, however, spacing is tight to reinforce the dense, engineered feel.

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | Flat | No shadow, no border | Body sections, text, footer | | Soft Tint | {colors.surface-soft-light} background | Hovered nav wells, ghost button backgrounds | | Accent Border | 1px {colors.border-accent} | Highlighted feature cards and interactive surfaces | | Dark Surface | {colors.surface-dark} background on white canvas, no shadow | The primary elevation model. Used for hero cards, CTA panels, and primary buttons. | The system is intentionally shadowless. Depth is communicated exclusively through surface color contrast—specifically, a dark ({colors.surface-dark}) card placed on the white ({colors.canvas-light}) canvas. This creates a stark, print-like sense of layering without relying on gradients or shadows.

Shape language: Border Radius Scale | Token | Value | Use | |---|---|---| | {rounded.sm} | 9px | Standard buttons, inputs, nav pills, inline link highlights | | {rounded.md} | 18px | Elevated cards, large containers, image areas | | {rounded.lg} | 30px | Used sparingly for large, decorative image containers | | {rounded.pill} | 9999px | Dropdown triggers and other pill-shaped affordances | The shape language is defined by a strict and tight radius scale. The vast majority of elements use either 9px or 18px, creating a consistent and predictable visual rhythm. Photography & Iconography Visual content is abstract and product-focused, not photographic. Imagery consists of UI mockups, decorative icon clusters, and abstract gradients. Icons are typically simple, filled glyphs. When images of product UI are shown, they are cropped with {rounded.md} or {rounded.lg} corners.

Component language: Buttons & Links button-primary-dark — The main call-to-action. A dark filled button with {colors.surface-dark} background and {colors.on-dark} text. It has {rounded.sm} corners and uses {typography.button}. Its depth comes from the stark contrast against the white page canvas. text-link — Inline text links are styled in {colors.primary} with no underline by default. On hover, they may gain a pill-shaped background or a simple underline. Navigation top-nav — A standard top navigation bar with a {colors.canvas-light} background. Inactive links use {colors.muted}, while active or hovered links use {colors.ink}. Dropdown triggers are often styled as pills with {rounded.pill}. Cards & Containers hero-card-dark — A large, elevated panel with a {colors.surface-dark} background and {rounded.md} corners. It serves as a "dark island" on the white canvas, typically used to showcase a representation of the product UI. feature-card — A minimal card, often with no background or border. Hierarchy is created purely with typography: a {colors.primary} title followed by {colors.muted}...
```
