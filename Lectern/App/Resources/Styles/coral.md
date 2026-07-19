# Coral

**ID:** `coral`  
**Category:** consumer  
**Theme:** light  
**Vibe:** Bold

## Color palette

- `#fa3556`
- `#1ebfbf`
- `#ffc200`
- `#16191c`
- `#000000`
- `#ffffff`
- `#5b6065`
- `#dadadd`
- `#bfbfc0`
- `#393e41`

## Typography

Families: "Inter, -apple-system, BlinkMacSystemFont, sans-serif". Weights: 400, 600, 700.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Surfshark

Design token description: A confident light-mode consumer SaaS design anchored by a vivid teal accent (1ebfbf) and a warm coral primary action color (fa3556). Dark charcoal hero cards and feature panels provide high-contrast resting places between airy white sections, creating a rhythm of dark→light→dark. Typography runs exclusively on a single sans-serif typeface with a wide size range and slight negative tracking on display sizes for tight, modern headlines. Components are soft and approachable, with highly-rounded cards (48px) and buttons (12px). A three-color accent system—teal for identity, coral for conversion, and yellow for promotional urgency—creates a high-impact but minimal chromatic footprint against a deep neutral scale.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- No dominant source-domain vocabulary was detected, but still avoid copying example subject matter from the design brief.
- Avoid brand logos, product shots, mascot imagery, packaging, buildings, people, or industry-specific objects unless requested by the slide content.

Overall visual personality: This is a confident light-mode consumer SaaS design language that creates a clean, approachable, and modern feel. The base canvas is airy white ({colors.canvas-light} or {colors.canvas-soft}), punctuated by full-width dark charcoal ({colors.canvas-dark}) hero and feature panels. This creates a distinct visual rhythm down the page, alternating between light and dark sections to frame content. The system relies on a three-part accent palette: a warm, energetic coral ({colors.primary}) for all primary CTAs, a vivid teal ({colors.accent-teal}) for brand identity and inline highlights, and a punchy gold ({colors.accent-promo}) strictly for promotional banners. This minimal chromatic footprint ensures that when color appears, it has maximum impact. Typography is handled exclusively by a single sans-serif typeface, used across a wide range of weights (400, 600, 700) and sizes. Display headlines are set with tight negative letter-spacing for a refined, modern character. Shapes are soft and friendly, defined by a prominent {rounded.lg} (48px) radius on cards and a {rounded.sm} (12px) on buttons. The system avoids drop shadows, relying entirely on background color contrast to create depth a...

Color tokens:
- primary: #fa3556
- accent-teal: #1ebfbf
- accent-promo: #ffc200
- ink: #16191c
- ink-strong: #000000
- on-primary: #ffffff
- on-dark: #ffffff
- body: #16191c
- muted: #5b6065
- hairline: #dadadd
- hairline-strong: #bfbfc0
- border-strong: #393e41
- canvas-light: #ffffff
- canvas-soft: #f9f9f9

Typography tokens:
- display-lg: family Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 60px, weight 700, line 1.07, tracking -1.5px
- display-md: family Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 40px, weight 700, line 1.21, tracking 0
- display-sm: family Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 32px, weight 700, line 1.3, tracking 0
- title-lg: family Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 24px, weight 700, line 1.33, tracking 0
- title-md: family Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 18px, weight 600, line 1.67, tracking 0
- body-md: family Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 16px, weight 400, line 1.75, tracking 0
- body-sm: family Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 14px, weight 400, line 1.71, tracking 0.24px
- caption: family Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 12px, weight 400, line 1.5, tracking 0.17px
- button: family Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 16px, weight 600, line 1, tracking 0
- nav-link: family Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 16px, weight 600, line 1.5, tracking 0

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
- xs: 8px
- sm: 12px
- lg: 48px
- xl: 64px
- pill: 96px
- full: 9999px

Component tokens:
- button-primary: backgroundColor: {colors.primary}, textColor: {colors.on-primary}, typography: {typography.button}, rounded: {rounded.sm}, padding: 16px 24px
- button-secondary-dark: backgroundColor: {colors.canvas-dark}, textColor: {colors.on-dark}, typography: {typography.button}, rounded: {rounded.sm}, padding: 16px 24px
- button-pill-dark: backgroundColor: {colors.canvas-dark}, textColor: {colors.on-dark}, typography: {typography.button}, rounded: {rounded.pill}, padding: 12px 24px
- text-link: backgroundColor: transparent, textColor: {colors.body}, typography: {typography.body-md}
- text-link-accent: backgroundColor: transparent, textColor: {colors.accent-teal}, typography: {typography.body-md}
- promo-banner: backgroundColor: {colors.accent-promo}, textColor: {colors.ink}, typography: {typography.body-sm}, height: 40px
- top-nav: backgroundColor: {colors.canvas-light}, textColor: {colors.ink}, typography: {typography.nav-link}, height: 64px
- hero-card-dark: backgroundColor: {colors.canvas-dark}, textColor: {colors.on-dark}, typography: {typography.display-lg}, rounded: {rounded.xl}, padding: 48px

Color rationale: Brand & Accent - Primary Coral ({colors.primary} — fa3556): The primary action color. Used exclusively for filled CTA button backgrounds to drive conversion. - Accent Teal ({colors.accent-teal} — 1ebfbf): The brand identity color. Used for accent highlights, inline link emphasis, and decorative icons. Never used for a button fill. - Accent Promo Gold ({colors.accent-promo} — ffc200): Reserved for time-sensitive promotional banners. Its sole purpose is to signal urgency. Surface The system alternates between light and dark surfaces to create a rhythmic page structure. - Canvas Light ({colors.canvas-light} — ffffff): The primary surface for light-mode cards and content panels. - Canvas Soft ({colors.canvas-soft} — f9f9f9): The default page canvas; a slightly off-white base that helps white cards pop. - Surface Tinted ({colors.surface-tinted} — e8f7f8): A faint teal-tinted background wash used for subtle differentiation in feature blocks. - Canvas Dark ({colors.canvas-dark} — 16191c): The background for hero cards, dark feature panels, and the footer. - Surface Dark Alt ({colors.surface-dark-alt} — 1e2327): A slightly bluer dark tone for layered depth within dark sections. Text - Ink...

Typography rationale: Font Family The system uses a single sans-serif typeface, Inter, across all UI and marketing surfaces. Its tall x-height ensures legibility at small sizes, while its clean geometry holds authority at large display sizes. The fallback stack is -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif. Hierarchy The typographic scale is wide, using weight and negative letter-spacing to create clear hierarchy without needing a separate display font. - Weight 400: Used for all body copy ({typography.body-md}, {typography.body-sm}) and captions. - Weight 600: Used for emphasis, navigation links ({typography.nav-link}), subheadings ({typography.title-md}), and button labels ({typography.button}). - Weight 700: Reserved for all display and heading sizes ({typography.display-lg} through {typography.title-lg}). | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.display-lg} | 60px | 700 | 1.07 | -1.5px | Primary hero headlines | | {typography.display-md} | 40px | 700 | 1.21 | 0 | Large section titles, testimonial quotes | | {typography.display-sm} | 32px | 700 | 1.3 | 0 | Standard section headings | | {typography.title-lg} | 24px |...

Layout system: Spacing System - Base unit: 4px. - Tokens: {spacing.xxs} 4px · {spacing.xs} 8px · {spacing.sm} 12px · {spacing.md} 16px · {spacing.lg} 24px · {spacing.xl} 32px · {spacing.xxl} 48px · {spacing.section} 64px. - Section padding (vertical): {spacing.section} (64px) is used consistently between all major page sections, creating a comfortable, airy rhythm. - Card internal padding: {spacing.xl} (32px) for most content cards; {spacing.xxl} (48px) for larger hero panels. - Gutters: {spacing.xs} (8px) is the standard gap between small, adjacent elements like items in a bulleted list. Grid & Container - Max content width: 1200px, centered. - Editorial body: The layout is primarily a single, centered column that alternates between full-width dark panels and contained light sections. Feature sections often use a 2-column split (text + image). - Page Rhythm: The structure is linear and predictable: promo banner → navigation → dark hero → light section → dark section → light section → dark footer. Whitespace Philosophy The system uses generous whitespace to feel clean and uncluttered. The consistent {spacing.section} gap between alternating light and dark panels is the defining feature of the la...

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | Flat | No shadow, no border | Body sections, top nav, footer | | Soft hairline | 1px {colors.hairline} or {colors.hairline-strong} | Subtle dividers, some card borders on light surfaces | | Card surface | {colors.canvas-light} background on {colors.canvas-soft}, or {colors.canvas-dark} on a light canvas | All elevated cards ({component.hero-card-dark}, {component.feature-card-light}) | The elevation philosophy is strictly flat, using color-block contrast. The system entirely avoids drop shadows. Depth is communicated by placing a surface of one color on top of a canvas of a contrasting color (e.g., a white {component.feature-card-light} on a {colors.canvas-soft} background). The high-contrast shift from a light section to a dark {component.hero-card-dark} provides all the necessary visual separation.

Shape language: Border Radius Scale The shape language is defined by soft, rounded corners, especially at larger scales. | Token | Value | Use | |---|---|---| | {rounded.xs} | 8px | Small inline tags or links | | {rounded.sm} | 12px | Standard CTA buttons ({component.button-primary}) | | {rounded.lg} | 48px | Primary radius for all content cards ({component.feature-card-light}) | | {rounded.xl} | 64px | Hero cards ({component.hero-card-dark}) | | {rounded.pill} | 96px | Pill-shaped buttons ({component.button-pill-dark}) and decorative tags | | {rounded.full} | 9999px | Avatars, circular icons | Photography & Iconography - Media areas inside cards crop to the card's radius. - Avatars are always circular, using {rounded.full}. - Icons are flat, single-stroke, and typically use {colors.accent-teal} on light backgrounds or {colors.on-dark} on dark backgrounds.

Component language: Banners & Navigation promo-banner — A full-width, 40px tall bar with a {colors.accent-promo} background. It sits at the very top of the page, above the navigation, and is reserved for time-sensitive offers. top-nav — A sticky 64px tall navigation bar with a {colors.canvas-light} background. Buttons button-primary — The main conversion CTA. A {colors.primary} coral background with {colors.on-primary} white text. It uses {typography.button} and a {rounded.sm} (12px) radius. This is the only component that uses the coral color fill. button-secondary-dark — The standard secondary action, used on light backgrounds. It has a {colors.canvas-dark} background with {colors.on-dark} white text and the same shape as the primary button. button-pill-dark — A compact, pill-shaped variant of the secondary button using {rounded.pill}. Often used in mid-page sections like testimonials. text-link-accent — Inline text links that use {colors.accent-teal} for emphasis within paragraphs of body copy. Cards & Containers...
```
