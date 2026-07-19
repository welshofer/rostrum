# Voltage

**ID:** `voltage`  
**Category:** consumer  
**Theme:** light  
**Vibe:** Technical

## Color palette

- `#e3fc03`
- `#000000`
- `#323232`
- `#1a1a1a`
- `#ffffff`
- `#e6e6e6`

## Typography

Families: "Whyte Book, -apple-system, BlinkMacSystemFont, sans-serif", "Whyte Inktrap, -apple-system, BlinkMacSystemFont, sans-serif", "Whyte, -apple-system, BlinkMacSystemFont, sans-serif". Weights: 400.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: TWOTWO

Design token description: A starkly monochrome system built on a white canvas, where a single, high-voltage lime accent (e3fc03) provides the only chromatic moment. The design reads like an industrial design catalog: generous white space, a Swiss-grotesque typeface used at a single light weight, and a disciplined geometric structure. There are no decorative gradients, shadows, or secondary hues. Black hairlines define surfaces, and a strict two-radius system (16px for static cards, 50px for interactive pills) signals function through shape alone. All chromatic variety comes from embedded media, with every UI surface remaining black, white, or lime.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- No dominant source-domain vocabulary was detected, but still avoid copying example subject matter from the design brief.
- Avoid brand logos, product shots, mascot imagery, packaging, buildings, people, or industry-specific objects unless requested by the slide content.

Overall visual personality: A starkly monochrome system built on a white canvas, where a single, high-voltage lime accent ({colors.primary} — e3fc03) provides the only chromatic moment. The design reads like an industrial design catalog: generous white space, a Swiss-grotesque typeface used at a single light weight, and a disciplined geometric structure. There are no decorative gradients, shadows, or secondary hues. Black hairlines ({colors.hairline-on-light}) define surfaces, and a strict two-radius system ({rounded.lg} at 16px for static cards, {rounded.pill} at 50px for interactive elements) signals function through shape alone. Type does the heavy lifting, with a single 400-weight grotesque used across a wide size scale, from 72px display headlines to 13px navigation links. All chromatic variety comes from embedded product media; every UI surface remains black, white, or lime. The mood is confident, geometric, and editorially disciplined. Key Characteristics: - Single accent color: {colors.primary} is the only chromatic hue, reserved for primary CTAs, active states, and hero headlines. - Flat, hairline-defined surfaces: Elevation is achieved with 1px {colors.hairline-on-light} borders, not shadows or gra...

Color tokens:
- primary: #e3fc03
- ink: #000000
- body: #323232
- muted: #1a1a1a
- hairline-on-light: #000000
- canvas-light: #ffffff
- canvas-dark: #000000
- surface-soft-light: #e6e6e6
- on-primary: #000000
- on-dark: #ffffff

Typography tokens:
- hero-display: family Whyte, -apple-system, BlinkMacSystemFont, sans-serif, size 72px, weight 400, line 1.1, tracking -1.44px
- display-md: family Whyte Book, -apple-system, BlinkMacSystemFont, sans-serif, size 38px, weight 400, line 1.3, tracking -0.38px
- display-sm: family Whyte, -apple-system, BlinkMacSystemFont, sans-serif, size 32px, weight 400, line 1.15, tracking -0.64px
- title-lg: family Whyte Book, -apple-system, BlinkMacSystemFont, sans-serif, size 26px, weight 400, line 1.3, tracking -0.26px
- title-md: family Whyte Book, -apple-system, BlinkMacSystemFont, sans-serif, size 22px, weight 400, line 1.4, tracking 0
- body-lg: family Whyte Book, -apple-system, BlinkMacSystemFont, sans-serif, size 18px, weight 400, line 1.5, tracking 0
- body-md: family Whyte Book, -apple-system, BlinkMacSystemFont, sans-serif, size 16px, weight 400, line 1.6, tracking 0
- caption: family Whyte Book, -apple-system, BlinkMacSystemFont, sans-serif, size 13px, weight 400, line 1.6, tracking 0
- detail: family Whyte Inktrap, -apple-system, BlinkMacSystemFont, sans-serif, size 16px, weight 400, line 1.6, tracking 0
- button: family Whyte Book, -apple-system, BlinkMacSystemFont, sans-serif, size 16px, weight 400, line 1, tracking 0
- nav-link: family Whyte Book, -apple-system, BlinkMacSystemFont, sans-serif, size 13px, weight 400, line 1.2, tracking 0.5px

Spacing tokens:
- xxs: 4px
- xs: 8px
- sm: 12px
- md: 16px
- lg: 20px
- xl: 32px
- xxl: 40px
- section: 64px

Radius and shape tokens:
- xs: 4px
- sm: 8px
- md: 12px
- lg: 16px
- xl: 24px
- pill: 50px
- full: 50px

Component tokens:
- button-primary: backgroundColor: {colors.primary}, textColor: {colors.on-primary}, typography: {typography.button}, rounded: {rounded.pill}, padding: 16px 32px, height: 50px
- text-input-pill: backgroundColor: {colors.canvas-light}, textColor: {colors.ink}, typography: {typography.body-md}, rounded: {rounded.pill}, padding: 12px 20px, height: 44px, border: 1px solid {colors.hairline-on-light}
- top-nav-light: backgroundColor: {colors.canvas-light}, textColor: {colors.ink}, typography: {typography.nav-link}, height: 80px
- hero-band: backgroundColor: transparent, textColor: {colors.primary}, typography: {typography.hero-display}, padding: 80px 0
- product-card-light: backgroundColor: {colors.canvas-light}, textColor: {colors.ink}, typography: {typography.caption}, rounded: {rounded.lg}, padding: 20px, border: 1px solid {colors.hairline-on-light}
- section-header: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.display-md}, padding: 40px 0
- icon-button: backgroundColor: transparent, strokeColor: {colors.ink}, strokeWidth: 1.5px
- footer-dark: backgroundColor: {colors.canvas-dark}, textColor: {colors.on-dark}, typography: {typography.caption}, padding: 64px

Color rationale: Brand & Accent - Primary ({colors.primary} — e3fc03): The single "voltage lime" accent. Used for primary CTA backgrounds, hero headlines, and tiny indicator tags. Its high contrast against black makes it a functional signal for interactivity. Text - Ink ({colors.ink} — 000000): Pure black used for primary text, headlines, and icons on light surfaces. - Body ({colors.body} — 323232): A secondary "graphite" gray for running body copy and sub-headlines, providing a subtle step-down from pure black. - Muted ({colors.muted} — 1a1a1a): A third-tier dark tone for fine details and low-priority UI marks that should recede visually. - On Primary ({colors.on-primary} — 000000): Black text used on lime primary CTA buttons for maximum contrast. - On Dark ({colors.on-dark} — ffffff): White text used on the inverted dark footer surface. Surface - Canvas Light ({colors.canvas-light} — ffffff): The primary page floor and card background. The default surface for all content. - Surface Soft Light ({colors.surface-soft-light} — e6e6e6): A "concrete" gray used for quiet section backgrounds when a subtle tonal break is needed. - Canvas Dark ({colors.canvas-dark} — 000000): The inverted canvas used excl...

Typography rationale: Font Family The system uses a single extended grotesque typeface family with variants for different roles: - Whyte: Used for large-scale display text like the {typography.hero-display}. - Whyte Book: The universal workhorse for body copy, subheadings, navigation, and buttons. - Whyte Inktrap: A variant with ink traps used for fine UI labels and metadata, providing clarity at small sizes. The most defining characteristic is the universal use of a 400 weight. Hierarchy is built with size and spacing, not boldness. Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.hero-display} | 72px | 400 | 1.1 | -1.44px | Main page hero headlines | | {typography.display-md} | 38px | 400 | 1.3 | -0.38px | Product card titles, large section heads | | {typography.display-sm} | 32px | 400 | 1.15 | -0.64px | Section titles | | {typography.title-lg} | 26px | 400 | 1.3 | -0.26px | Sub-section titles | | {typography.title-md} | 22px | 400 | 1.4 | 0 | Emphasized body-level headings | | {typography.body-lg} | 18px | 400 | 1.5 | 0 | Larger lead-in body paragraphs | | {typography.body-md} | 16px | 400 | 1.6 | 0 | Default running text, input placeh...

Layout system: Spacing System - Base unit: 4px. - Tokens: {spacing.xxs} 4px · {spacing.xs} 8px · {spacing.sm} 12px · {spacing.md} 16px · {spacing.lg} 20px · {spacing.xl} 32px · {spacing.xxl} 40px · {spacing.section} 64px. - Section gap: {spacing.section} (64px) provides generous vertical rhythm between major content blocks. - Card internal padding: {spacing.lg} (20px) for product cards. - Component gutters: {spacing.md} (16px) is the default gap between elements within a component or between cards in a grid. Grid & Container - Max content width: 1280px centered. Hero elements are an exception, often spanning full-bleed. - Grid structure: Below the hero, layouts resolve to a single-column stack of sections, typically containing a centered header followed by a 3-column content grid. Whitespace Philosophy The system feels both dense and airy. Components themselves are compact (tight line heights, modest padding), but they are placed on the canvas with generous separating whitespace. This contrast creates a strong focal rhythm, guiding the eye from one contained block to the next.

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | Flat | No shadow, no border | Page canvas, hero image areas, section header blocks | | Hairline Border | 1px solid {colors.hairline-on-light} | All cards, inputs, and structural dividers. This is the primary elevation signal. | | Inverted Surface | {colors.canvas-dark} background | The footer band, creating a final, strong layer at the bottom of the page. | | Focus State | 2px solid {colors.hairline-on-light} border | The focus state for inputs thickens the border rather than adding a colored ring or glow. | The system is intentionally flat. Depth is not simulated with shadows or gradients. Instead, separation is achieved through sharp, 1px black hairlines and the stark contrast between the white canvas and the black footer.

Shape language: Border Radius Scale A strict, binary radius system is a core principle. It geometrically separates interactive elements from static containers. | Token | Value | Use | |---|---|---| | {rounded.lg} | 16px | Static containers: cards, images. | | {rounded.pill} | 50px | Interactive elements: buttons, inputs, tags. | | {rounded.full} | 50px | Same as pill; used for fully circular elements. | The system does not use smaller micro-radii (4px, 8px). The large, confident radii are fundamental to the geometric character. Iconography Icons are utilitarian and minimalist: 20-24px line icons with a 1.5px {colors.ink} stroke, no fill, and no background. They are used for common UI actions (search, cart) and are not expressive or illustrative.

Component language: Top Navigation top-nav-light — A full-width, 80px tall bar on a {colors.canvas-light} background. Contains uppercase navigation links in {typography.nav-link} and right-aligned utility icons. It has no bottom border, appearing to float on the white canvas. Buttons button-primary — The signature pill CTA. {colors.primary} background with {colors.on-primary} text. Uses {rounded.pill} (50px) and generous padding for a confident, tappable shape. This is the only component that carries the system's accent color. icon-button — A transparent button holding a simple line icon. The icon uses a 1.5px {colors.ink} stroke. The touch target is padded to a sufficient size (e.g., 40x40px). Cards & Containers hero-band — A full-bleed image area, typically with a centered overlay headline. The headline uses {typography.hero-display} and is often rendered in {colors.primary} for maximum impact. product-card-light — The standard container for grid items. A {colors.canvas-light} surface with {rounded.lg} (16px) corners and a defining 1px {colors.hairline-on-light} border. Contains an image area and text content. footer-dark — A full-width band with a {colors.canvas-dark} background and {colors.on-dar...

Guardrails: Do - Use {colors...
```
