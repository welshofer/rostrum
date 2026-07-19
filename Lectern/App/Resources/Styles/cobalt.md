# Cobalt

**ID:** `cobalt`  
**Category:** consumer  
**Theme:** dark  
**Vibe:** Editorial

## Color palette

- `#1658b3`
- `#0d3c88`
- `#01295f`
- `#015fee`
- `#eee1d9`
- `#000000`
- `#ffffff`
- `#e5e7eb`

## Typography

Families: "Baton Turbo, Druk Wide, Tungsten, sans-serif", "Greycliff, Inter, Manrope, sans-serif". Weights: 400, 500, 700.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Swwim

Design token description: A vivid and editorial design system built on a deep cobalt blue (1658b3) canvas. The visual identity is defined by an extremely oversized, all-caps display typeface used for hero statements, which are often overlapped by un-framed media objects to create a collage effect. The palette is near-monochromatic blue, with stark white (ffffff) for text and secondary surfaces. All interactive controls, like buttons and tags, use a pill shape (9999px radius), while content containers remain sharp with 0px radius and a subtle hairline border (e5e7eb). Elevation is eschewed in favor of a flat, graphic aesthetic where typographic scale and color blocking create hierarchy.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- No dominant source-domain vocabulary was detected, but still avoid copying example subject matter from the design brief.
- Avoid brand logos, product shots, mascot imagery, packaging, buildings, people, or industry-specific objects unless requested by the slide content.

Overall visual personality: This is a vivid, editorial design system built on a deep cobalt blue ({colors.primary} — 1658b3) that serves as the primary canvas for hero and section floods. The visual identity is defined by an extremely oversized, all-caps display typeface, used for hero statements at sizes up to 151px ({typography.hero-display}). These headlines are often overlapped by un-framed media objects to create a deliberate collage effect. The palette is near-monochromatic blue, with stark white ({colors.canvas-light}) serving as the neutral for content pages, text on dark surfaces, and the fill color for primary buttons. All interactive controls, like buttons and tags, use a full pill shape ({rounded.pill} — 9999px radius). In stark contrast, all content containers like cards and inputs are sharp and un-rounded ({rounded.none} — 0px radius), outlined only by a subtle hairline border ({colors.hairline-on-light} — e5e7eb). Elevation is completely eschewed. The system is intentionally flat, using no drop shadows or glows. Hierarchy is established through dramatic typographic scale, color blocking, and whitespace, creating a bold, graphic, and confident aesthetic. Key Characteristics: - Dominant brand co...

Color tokens:
- primary: #1658b3
- primary-dark: #0d3c88
- primary-darkest: #01295f
- accent-violet: #015fee
- accent-warm: #eee1d9
- ink: #000000
- body: #000000
- body-on-dark: #ffffff
- hairline-on-light: #e5e7eb
- canvas-light: #ffffff
- canvas-dark: #1658b3
- surface-footer: #0d3c88
- on-primary: #ffffff
- button-primary-text: #1658b3

Typography tokens:
- hero-display: family Baton Turbo, Druk Wide, Tungsten, sans-serif, size 151px, weight 400, line 1, tracking 0
- display-lg: family Baton Turbo, Druk Wide, Tungsten, sans-serif, size 48px, weight 400, line 1.11, tracking 0
- display-md: family Baton Turbo, Druk Wide, Tungsten, sans-serif, size 36px, weight 400, line 1.2, tracking 0
- display-sm: family Baton Turbo, Druk Wide, Tungsten, sans-serif, size 29px, weight 400, line 1.25, tracking 0
- title-lg: family Greycliff, Inter, Manrope, sans-serif, size 30px, weight 700, line 1.25, tracking 0
- title-md: family Greycliff, Inter, Manrope, sans-serif, size 24px, weight 700, line 1.33, tracking 0
- title-sm: family Greycliff, Inter, Manrope, sans-serif, size 20px, weight 500, line 1.4, tracking 0
- body-lg: family Greycliff, Inter, Manrope, sans-serif, size 18px, weight 400, line 1.56, tracking 0
- body-md: family Greycliff, Inter, Manrope, sans-serif, size 16px, weight 400, line 1.5, tracking 0
- body-sm: family Greycliff, Inter, Manrope, sans-serif, size 14px, weight 400, line 1.43, tracking 0
- button: family Greycliff, Inter, Manrope, sans-serif, size 16px, weight 500, line 1, tracking 0
- nav-link: family Greycliff, Inter, Manrope, sans-serif, size 16px, weight 500, line 1, tracking 0

Spacing tokens:
- xxs: 4px
- xs: 8px
- sm: 16px
- md: 24px
- lg: 40px
- xl: 48px
- xxl: 64px
- section: 96px

Radius and shape tokens:
- none: 0px
- sm: 0px
- md: 0px
- lg: 0px
- xl: 0px
- pill: 9999px
- full: 9999px

Component tokens:
- button-primary: backgroundColor: {colors.canvas-light}, textColor: {colors.button-primary-text}, typography: {typography.button}, rounded: {rounded.pill}, padding: 16px 24px
- nav-link: backgroundColor: transparent, textColor: {colors.body-on-dark}, typography: {typography.nav-link}
- hero-band: backgroundColor: {colors.primary}, textColor: {colors.body-on-dark}, typography: {typography.hero-display}, padding: 64px
- marquee-band: backgroundColor: {colors.primary}, textColor: {colors.body-on-dark}, typography: {typography.display-md}, padding: 64px 0
- content-card-light: backgroundColor: {colors.canvas-light}, textColor: {colors.body}, typography: {typography.body-md}, rounded: {rounded.none}, padding: 24px, border: 1px solid {colors.hairline-on-light}
- footer-band: backgroundColor: {colors.primary-dark}, textColor: {colors.body-on-dark}, typography: {typography.body-md}, padding: 64px
- media-overlap-card: backgroundColor: transparent, rounded: {rounded.none}

Color rationale: Brand & Accent - Primary Blue ({colors.primary} — 1658b3): The core brand color. Used for hero backgrounds, full-bleed section floods, and the text color on primary buttons. It acts as the system's "dark mode" canvas. - Primary Dark ({colors.primary-dark} — 0d3c88): A deeper blue used for footer bands and gradient depth in decorative graphics. - Primary Darkest ({colors.primary-darkest} — 01295f): The deepest blue, used for gradient stops in illustrations. Never used for text or UI surfaces. - Accent Violet ({colors.accent-violet} — 015fee): A slightly more electric blue used for highlight backgrounds or decorative bands. - Accent Warm ({colors.accent-warm} — eee1d9): A warm, desaturated flesh-tone used sparingly within illustrations to add a human touch to the cool blue palette. Surface - Canvas Light ({colors.canvas-light} — ffffff): The default page background for all text-heavy content sections. Also used as the fill for primary buttons. - Canvas Dark ({colors.canvas-dark} — 1658b3): The primary blue, which functions as the dark canvas for hero sections and branded bands. - Surface Footer ({colors.surface-footer} — 0d3c88): The background color for the main page footer. Hairli...

Typography rationale: Font Family The system uses a two-family structure to create a strong editorial voice: - Baton Turbo: A bold, condensed display face used exclusively for oversized headlines (29px and up). It is always set at a regular weight (400). Its extreme scale is the system's signature. An open-source substitute would be Druk Wide or Tungsten. - Greycliff: A clean, geometric sans-serif for all UI and body copy. It is used at regular (400), medium (500), and bold (700) weights. An open-source substitute would be Inter or Manrope. Hierarchy | Token | Size | Weight | Line Height | Use | |---|---|---|---|---| | {typography.hero-display} | 151px | 400 | 1 | The main page hero headline. Baton Turbo, all-caps. | | {typography.display-lg} | 48px | 400 | 1.11 | Large section titles. Baton Turbo. | | {typography.display-md} | 36px | 400 | 1.2 | Medium section titles, marquee text. Baton Turbo. | | {typography.display-sm} | 29px | 400 | 1.25 | Smallest display headlines. Baton Turbo. | | {typography.title-lg} | 30px | 700 | 1.25 | Large headings in body content. Greycliff. | | {typography.title-md} | 24px | 700 | 1.33 | Standard headings. Greycliff. | | {typography.title-sm} | 20px | 500 | 1.4 | Subhe...

Layout system: Spacing System - Base unit: 4px. - Tokens: A standard scale from {spacing.xxs} (4px) up to {spacing.xxl} (64px). - Section padding (vertical): Large sections use {spacing.section} (96px) or {spacing.xxl} (64px) for vertical rhythm, creating generous whitespace between content blocks. - Card internal padding: {spacing.md} (24px) is the standard for all content cards. - Gutters: {spacing.sm} (16px) is a common gap between elements within a component. Grid & Container - Max content width: 1440px, centered. This provides an expansive canvas for the editorial layouts. - Hero composition: The hero is deliberately asymmetric. A large headline often occupies the left two-thirds, with body copy and media objects arranged in the remaining negative space to create a dynamic, collage-like feel. - Content sections: Below the hero, content typically lives in a standard centered column on a white background, using cards and dividers to structure information. Whitespace Philosophy The system uses generous whitespace between sections to allow the bold, full-bleed blue bands to breathe. However, within the hero section, whitespace is actively compressed by overlapping type and images. This creates...

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | Flat | No shadow, no border | The default state for all surfaces and components like hero bands, buttons, and text. | | Soft hairline | 1px {colors.hairline-on-light} | Used exclusively to define the edges of cards and inputs on light surfaces. It is a structural line, not a decorative one. | The elevation philosophy is strictly flat. The system achieves separation and hierarchy through color blocking (blue vs. white), typographic scale, and minimal hairline borders. There are no drop shadows, gradients on UI elements, or other skeuomorphic depth cues.

Shape language: Border Radius Scale The system employs a strict binary approach to corner rounding, which is a key part of its visual identity. | Token | Value | Use | |---|---|---| | {rounded.none} | 0px | All static containers: cards, inputs, image frames, section backgrounds. Corners are always sharp. | | {rounded.pill} | 9999px | All interactive elements: buttons, tags, badges. These are always fully rounded into a pill shape. | This sharp contrast between perfectly straight and perfectly round shapes is a core rule. There are no intermediate corner radii (e.g., 4px, 8px). Photography & Iconography - Media objects are presented as tightly cropped still-lifes, with no background, border, or rounding. They are intended to feel like physical objects scattered onto the page. - Iconography is minimal and line-based, rendered monochromatically in {colors.body-on-dark} or {colors.ink}.

Component language: Buttons button-primary — The signature CTA. A white pill-shaped button with blue text. Background {colors.canvas-light}, text {colors.button-primary-text}, type {typography.button}, rounded {rounded.pill}, padding 16px × 24px. It has no border or shadow and is used on both light and dark surfaces. nav-link — A text-only link used for navigation. Transparent background, white text ({colors.body-on-dark}) on the dark header, type {typography.nav-link}. Cards & Containers hero-band — A full-bleed section with a {colors.primary} background. It contains the {typography.hero-display} headline and is the primary brand expression. Padding is typically {spacing.xxl} (64px). content-card-light — The standard container for content on white pages. It has a {colors.canvas-light} background, a 1px {colors.hairline-on-light} border, and {rounded.none} corners. Internal padding is {spacing.md} (24px). marquee-band — A full-bleed blue band, often used as a transition, containing a horizontally scrolling or static line of text in {typography.display-md}. footer-band — The main page footer, using the deeper {colors.primary-dark} for its background to signal the end of the page. media-overlap-card —...

Guardrails: Do - Use the display typeface only for oversized headlines (29px and up). - Always set the hero headline in {...
```
