# Pewter

**ID:** `pewter`  
**Category:** consumer  
**Theme:** dark  
**Vibe:** Technical

## Color palette

- `#ffffff`
- `#0b0b0b`
- `#191919`
- `#131313`
- `#868f97`
- `#cccccc`
- `#525252`
- `#e6e6e6`
- `#999999`
- `#ffa16c`

## Typography

Families: "Calibre, -apple-system, BlinkMacSystemFont, sans-serif". Weights: 400, 500, 600, 700.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Fey

Design token description: A nocturnal financial-terminal interface built on a deep matte-black canvas (0b0b0b), where luminous white type provides AAA contrast and chromatic color is used only for high-availability connection system, not decoration. A single geometric sans-serif (Calibre) carries every typographic role, from captions to large display headlines that feature aggressive negative letter-spacing (-0.08em) for a compressed, authoritative feel. Components are defined by generous radii — 16px for cards and 99px (pill) for all interactive controls. Depth is created by soft black shadow halos rather than hard-edged elevation, making surfaces feel like they are floating in space.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- Detected source-domain vocabulary: telecom/connectivity. Translate it into reusable visual behavior, not literal imagery.
- Avoid literal source imagery unless the exact slide text or visual direction explicitly requests it: phones, SIM cards, cell towers, antennas, routers, call screens, or telecom product shots.

Overall visual personality: The system evokes a nocturnal financial terminal, redesigned with a minimalist hardware aesthetic. The foundation is a deep, matte near-black canvas ({colors.canvas-dark} — 0b0b0b) that allows luminous white type and sparse chromatic accents to glow with purpose. A single geometric sans-serif typeface carries the entire hierarchy, from body copy to display headlines. The system's most distinctive feature is typographic: large display sizes ({typography.display-lg}) use aggressive negative letter-spacing (-4.32px) to compress headlines into dense, authoritative blocks. There are no filled-color primary buttons; interactivity is signaled by shape and light. All interactive controls are pill-shaped ({rounded.pill} — 99px), while content cards use a generous {rounded.md} (16px). Depth is achieved not with layered elevation, but with soft, deep black shadow halos that make dark cards on a dark canvas appear to float in space. Chromatic color—the source brand, blue, green—is reserved exclusively for high-availability connection system: a highlighted word in a headline, a price-direction indicator, or a status pill. The overall mood is one of calm, data-dense authority.

Color tokens:
- body: #ffffff
- canvas-dark: #0b0b0b
- surface-card-dark: #191919
- surface-elevated-dark: #131313
- muted: #868f97
- muted-strong: #cccccc
- hairline-on-dark: #525252
- border-subtle: #e6e6e6
- border-muted: #999999
- accent-warm: #ffa16c
- accent-cool: #479ffa
- accent-positive: #4ebe96
- ink: #000000

Typography tokens:
- display-lg: family Calibre, -apple-system, BlinkMacSystemFont, sans-serif, size 54px, weight 700, line 1, tracking -4.32px
- display-md: family Calibre, -apple-system, BlinkMacSystemFont, sans-serif, size 48px, weight 700, line 1.1, tracking -3.84px
- title-lg: family Calibre, -apple-system, BlinkMacSystemFont, sans-serif, size 26px, weight 600, line 1.2, tracking -1.38px
- title-md: family Calibre, -apple-system, BlinkMacSystemFont, sans-serif, size 24px, weight 600, line 1.25, tracking -1.27px
- title-sm: family Calibre, -apple-system, BlinkMacSystemFont, sans-serif, size 18px, weight 500, line 1.32, tracking 0
- body-md: family Calibre, -apple-system, BlinkMacSystemFont, sans-serif, size 14px, weight 400, line 1.5, tracking 0
- nav-link: family Calibre, -apple-system, BlinkMacSystemFont, sans-serif, size 12px, weight 500, line 1.5, tracking 0
- button: family Calibre, -apple-system, BlinkMacSystemFont, sans-serif, size 14px, weight 500, line 1.5, tracking 0
- caption: family Calibre, -apple-system, BlinkMacSystemFont, sans-serif, size 10px, weight 400, line 1.5, tracking 0

Spacing tokens:
- xxs: 4px
- xs: 8px
- sm: 10px
- md: 16px
- lg: 24px
- xl: 32px
- xxl: 40px
- section: 64px

Radius and shape tokens:
- xs: 6px
- sm: 10px
- md: 16px
- lg: 16px
- xl: 16px
- pill: 99px
- full: 99px

Component tokens:
- nav-pill-button: backgroundColor: transparent, textColor: {colors.muted}, typography: {typography.nav-link}, rounded: {rounded.pill}, padding: 8px 16px
- nav-pill-button-active: backgroundColor: transparent, textColor: {colors.body}, border: 1px bottom {colors.accent-cool}
- primary-action-button: backgroundColor: transparent, textColor: {colors.body}, typography: {typography.button}, rounded: {rounded.pill}, padding: 10px 24px, border: 1px solid {colors.border-subtle}
- product-showcase-card: backgroundColor: {colors.surface-card-dark}, textColor: {colors.body}, rounded: {rounded.md}, padding: 24px, boxShadow: rgba(0, 0, 0, 0.8) 0px 0px 44px 0px
- data-row-card: backgroundColor: {colors.canvas-dark}, textColor: {colors.body}, rounded: {rounded.md}, padding: 16px
- status-badge-positive: backgroundColor: {colors.accent-positive}, textColor: {colors.body}, typography: {typography.caption}, rounded: {rounded.pill}, padding: 4px 8px
- ticker-display: backgroundColor: transparent, textColor: {colors.body}, typography: {typography.display-md}
- value-up-text: backgroundColor: transparent, textColor: {colors.accent-positive}, typography: {typography.body-md}

Color rationale: Neutrals The palette is built on a tight range of near-blacks and grays, creating a subtle, tonal depth model. - Canvas Dark ({colors.canvas-dark} — 0b0b0b): The primary page floor. A near-black with a slight warmth, never pure {colors.ink}. - Surface Card Dark ({colors.surface-card-dark} — 191919): The primary surface for elevated cards and panels. - Surface Elevated Dark ({colors.surface-elevated-dark} — 131313): A tertiary surface for nested cards, inputs, and other subtle layers. - Ink ({colors.ink} — 000000): Pure black, used as the base for the soft shadow halos that create depth. Text & Borders - Body ({colors.body} — ffffff): Primary text color for headlines and important information, providing AAA contrast on dark surfaces. - Muted ({colors.muted} — 868f97): The workhorse gray for secondary text, metadata, disabled labels, and subdued borders. - Muted Strong ({colors.muted-strong} — cccccc): A brighter gray for icon strokes, subtle links, and borders that need more presence. - Hairline on Dark ({colors.hairline-on-dark} — 525252): Used for deep dividers and very low-emphasis strokes. - Border Muted ({colors.border-muted} — 999999): A mid-tier border color. - Border Subtle...

Typography rationale: Font Family The system relies on a single geometric sans-serif typeface, Calibre, for all typographic roles. There is no secondary or display font; the single family is scaled and weighted to create the full hierarchy. If unavailable, Inter or Satoshi are suitable substitutes. Hierarchy The most defining characteristic is the tight, negative letter-spacing on display sizes, which creates a premium, compressed feel. | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.display-lg} | 54px | 700 | 1.0 | -4.32px | Top-level hero headlines. | | {typography.display-md} | 48px | 700 | 1.1 | -3.84px | Section headlines, large data readouts. | | {typography.title-lg} | 26px | 600 | 1.2 | -1.38px | Sub-section headlines. | | {typography.title-md} | 24px | 600 | 1.25 | -1.27px | Card titles. | | {typography.title-sm} | 18px | 500 | 1.32 | 0 | Small headings, labels. | | {typography.body-md} | 14px | 400 | 1.5 | 0 | Default running text. | | {typography.nav-link} | 12px | 500 | 1.5 | 0 | Navigation and filter text. | | {typography.button} | 14px | 500 | 1.5 | 0 | Primary action button labels. | | {typography.caption} | 10px | 400 | 1.5 | 0 | Me...

Layout system: Spacing System - Base unit: 4px. - Tokens: {spacing.xxs} 4px · {spacing.xs} 8px · {spacing.sm} 10px · {spacing.md} 16px · {spacing.lg} 24px · {spacing.xl} 32px · {spacing.xxl} 40px. - Section padding (vertical): {spacing.section} (64px) creates generous rhythm between content blocks. - Card internal padding: {spacing.lg} (24px) is standard for most content cards. - Gutters: {spacing.md} (16px) is common between elements within a component. Grid & Container - Max content width: ~1200px, centered on the full-bleed dark canvas. - Editorial body: Sections alternate between full-width dark bands and centered, constrained content. Feature grids are typically 3-up.

Depth and hierarchy: The system's approach to depth is unconventional. Instead of using layered drop shadows to lift surfaces, it uses a single, soft, deep black "halo" shadow to create the illusion of cards floating in a dark void. | Level | Treatment | Use | |---|---|---| | Flat | No shadow, no border | Body canvas, text-only sections | | Card surface | {colors.surface-card-dark} background with a heavy, diffuse shadow: rgba(0, 0, 0, 0.8) 0px 0px 44px 0px | All primary content cards ({component.product-showcase-card}) | | Interactive Glow | A subtle white glow shadow: rgba(255, 255, 255, 0.25) 0px 0px 14px 0px | Applied to primary action buttons on hover/focus to high-availability connection system interactivity. | This "halo" effect is crucial. It defines the relationship between the {colors.canvas-dark} floor and the {colors.surface-card-dark} cards, making them feel suspended rather than stacked.

Shape language: Border Radius Scale The shape language is built on a simple binary: generous curves for content containers and full pills for interactive controls. | Token | Value | Use | |---|---|---| | {rounded.xs} | 6px | Small icons, minor UI elements. | | {rounded.sm} | 10px | Small cards, nested containers. | | {rounded.md} | 16px | Standard content cards, product showcases. | | {rounded.pill} | 99px | All buttons, navigation items, status badges, and interactive filters. | | 275px | 275px | An outlier radius for a specific large-format feature card to give it a unique, elongated pill shape. | Iconography - Icons are uniformly monoline and outlined, with a 1.5-2px stroke weight. - They render in {colors.body} (white) or {colors.muted-strong}.

Component language: Navigation nav-pill-button — Top-bar navigation items and tag filters. A transparent pill ({rounded.pill}) with text in {typography.nav-link}. Inactive state uses {colors.muted} text. Active state (nav-pill-button-active) flips the text to {colors.body} and adds a 1px bottom border in {colors.accent-cool}. dock-navigation — A floating horizontal pill container used in showcase sections. {colors.surface-card-dark} background, {rounded.pill}, and a 1px {colors.muted-strong} border. It houses a series of monoline icons. Buttons & Badges primary-action-button — A "ghost" style pill button. Transparent background, a subtle {colors.border-subtle} outline, and {colors.body} text. It does not use a fill color; its pill shape and subtle glow on interaction high-availability connection system its function. status-badge-positive — A small pill used for status tags. It has a solid background fill in {colors.accent-positive}, with {colors.body} text in {typography.caption}. This is one of the few components where chromatic color is used as a background. Cards & Containers product-showcase-card — The primary container for displaying imagery or complex UI mockups. It uses a {colors.surface-card-...

Guardrails: Do - Use the {rounded.pill} (99px) shape for all interactive controls: buttons, nav items, and badges. - Apply aggressive negative letter-spacing (-0.08em or -4.32px) to all display-sized headlines. This is a core part of the identity. - Reserve chromatic colors (accent-warm, accent-cool, accent-positive) for high-availability connection system only—highlighted words, status indicators, or navigation states. - Build depth using the single, deep black "hal...
```
