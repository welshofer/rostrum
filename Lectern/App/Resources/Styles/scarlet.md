# Scarlet

**ID:** `scarlet`  
**Category:** consumer  
**Theme:** dark  
**Vibe:** Bold

## Color palette

- `#000000`
- `#ffffff`
- `#fe2f2f`
- `#7333f1`
- `#d7b73b`
- `#fffe5b`
- `#ede5ff`
- `#1b5bff`
- `#a0e9ff`
- `#ffa0f0`

## Typography

Families: "'Helvetica Neue LT', 'Helvetica Neue', Helvetica, Arial, sans-serif". Weights: 400, 800.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Cards Against Humanity

Design token description: A high-contrast, game-like interface built on a pure black (000000) canvas. Primary content surfaces are bright white (ffffff) rectangles with a distinct 2px inset border, mimicking physical cards. A tight three-color accent system—signal red (fe2f2f), royal violet (7333f1), and antique gold (d7b73b)—is used exclusively for borders, never fills. Typography is uniformly heavy, running Helvetica Neue LT at an assertive 800 weight for nearly all text, creating a bold, punchline-like delivery. Interactive elements are chunky pills with thick inset borders, reinforcing a tactile, object-based feel over flat UI conventions.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- No dominant source-domain vocabulary was detected, but still avoid copying example subject matter from the design brief.
- Avoid brand logos, product shots, mascot imagery, packaging, buildings, people, or industry-specific objects unless requested by the slide content.

Overall visual personality: This system uses a high-contrast, physical-object aesthetic built on a pure black canvas ({colors.canvas-dark} — 000000). The core metaphor is a collection of cards on a table: content lives on stark white rectangular surfaces ({colors.surface-card} — ffffff) that feel like physical objects. Elevation and borders are not achieved with drop shadows or strokes, but with a consistent 2px inset shadow that gives every card and button a debossed, tactile quality. This technique is the system's most defining characteristic. Typography is intentionally aggressive, using a single heavy typeface (Helvetica Neue LT) at weight 800 for almost every role, from large display headlines ({typography.display-lg}) down to body copy ({typography.body-md}). This creates a loud, punchy, and uniform voice. Color is used sparingly; a three-color accent palette of red, violet, and gold is applied exclusively to the borders of featured cards and badges, never as background fills. The result is a bold, minimalist, and highly textural interface that prioritizes impact and character over conventional UI softness. Key Characteristics: - Bimodal Canvas: Pages are built in full-bleed sections that alternate bet...

Color tokens:
- ink: #000000
- body: #ffffff
- body-on-light: #000000
- canvas-dark: #000000
- canvas-light: #ffffff
- surface-card: #ffffff
- border-on-dark: #ffffff
- border-on-light: #000000
- accent-red: #fe2f2f
- accent-violet: #7333f1
- accent-gold: #d7b73b
- decorative-lemon: #fffe5b
- decorative-lavender: #ede5ff
- decorative-cobalt: #1b5bff

Typography tokens:
- display-lg: family 'Helvetica Neue LT', 'Helvetica Neue', Helvetica, Arial, sans-serif, size 80px, weight 800, line 0.98, tracking 0
- display-md: family 'Helvetica Neue LT', 'Helvetica Neue', Helvetica, Arial, sans-serif, size 65px, weight 800, line 1, tracking 0
- display-sm: family 'Helvetica Neue LT', 'Helvetica Neue', Helvetica, Arial, sans-serif, size 55px, weight 800, line 1.05, tracking 0
- title-lg: family 'Helvetica Neue LT', 'Helvetica Neue', Helvetica, Arial, sans-serif, size 40px, weight 800, line 1.07, tracking 0
- title-md: family 'Helvetica Neue LT', 'Helvetica Neue', Helvetica, Arial, sans-serif, size 28px, weight 800, line 1.3, tracking 0
- title-sm: family 'Helvetica Neue LT', 'Helvetica Neue', Helvetica, Arial, sans-serif, size 24px, weight 800, line 1.25, tracking 0
- body-lg: family 'Helvetica Neue LT', 'Helvetica Neue', Helvetica, Arial, sans-serif, size 20px, weight 800, line 1.29, tracking 0
- body-md: family 'Helvetica Neue LT', 'Helvetica Neue', Helvetica, Arial, sans-serif, size 16px, weight 800, line 2.38, tracking 0
- body-sm: family 'Helvetica Neue LT', 'Helvetica Neue', Helvetica, Arial, sans-serif, size 14px, weight 800, line 2.1, tracking 0
- caption: family 'Helvetica Neue LT', 'Helvetica Neue', Helvetica, Arial, sans-serif, size 12px, weight 800, line 2, tracking 0
- form-label: family 'Helvetica Neue LT', 'Helvetica Neue', Helvetica, Arial, sans-serif, size 14px, weight 400, line 1.5, tracking 0
- button: family 'Helvetica Neue LT', 'Helvetica Neue', Helvetica, Arial, sans-serif, size 16px, weight 800, line 1, tracking 0

Spacing tokens:
- xxs: 12px
- xs: 20px
- sm: 24px
- md: 32px
- lg: 40px
- xl: 60px
- xxl: 100px
- section: 160px

Radius and shape tokens:
- sm: 13px
- md: 20px
- lg: 38px
- pill: 38px
- full: 9999px

Component tokens:
- button-pill-on-dark: backgroundColor: transparent, textColor: {colors.body}, typography: {typography.button}, rounded: {rounded.pill}, padding: 12px 32px
- button-pill-on-light: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.button}, rounded: {rounded.pill}, padding: 12px 32px
- content-card: backgroundColor: {colors.surface-card}, textColor: {colors.body-on-light}, typography: {typography.body-md}, rounded: {rounded.sm}, padding: 20px
- content-card-accent-red: backgroundColor: {colors.surface-card}, textColor: {colors.body-on-light}, typography: {typography.body-md}, rounded: {rounded.sm}, padding: 20px
- content-card-accent-violet: backgroundColor: {colors.surface-card}, textColor: {colors.body-on-light}, typography: {typography.body-md}, rounded: {rounded.sm}, padding: 20px
- content-card-accent-gold: backgroundColor: {colors.surface-card}, textColor: {colors.body-on-light}, typography: {typography.body-md}, rounded: {rounded.sm}, padding: 20px
- modal-dialog: backgroundColor: {colors.canvas-dark}, textColor: {colors.body}, typography: {typography.body-sm}, rounded: {rounded.sm}, padding: 32px
- top-nav: backgroundColor: transparent, textColor: {colors.body}, typography: {typography.title-sm}, height: 64px

Color rationale: Core Palette - Ink ({colors.ink} — 000000): Pure black, used for the dark canvas, text on light surfaces, and inset borders on light cards. - Body ({colors.body} — ffffff): Pure white, used for the light canvas, card surfaces, text on dark surfaces, and inset borders on dark buttons. Surface & Canvas - Canvas Dark ({colors.canvas-dark} — 000000): The default page background. - Canvas Light ({colors.canvas-light} — ffffff): Used for full-bleed content sections to contrast with the dark canvas. - Surface Card ({colors.surface-card} — ffffff): The background for all primary content containers. Borders - Border on Dark ({colors.border-on-dark} — ffffff): The color for inset borders on elements sitting on the dark canvas. - Border on Light ({colors.border-on-light} — 000000): The color for inset borders on elements sitting on the light canvas or card surfaces. Accents The accent palette is used exclusively for the 2px inset borders on featured cards or badges. - Accent Red ({colors.accent-red} — fe2f2f): A bright signal red. - Accent Violet ({colors.accent-violet} — 7333f1): A deep royal purple. - Accent Gold ({colors.accent-gold} — d7b73b): A warm antique gold. Decorative This palette...

Typography rationale: Font Family The system relies exclusively on 'Helvetica Neue LT' and its fallbacks ('Helvetica Neue', Helvetica, Arial, sans-serif). There is no secondary or display-specific typeface. Hierarchy & Weight The typographic hierarchy is defined almost entirely by size, not weight. A bold fontWeight: 800 is the default for everything from display headlines down to body copy. This creates a powerful, uniform voice. A lighter fontWeight: 400 is reserved only for small, utilitarian text like form labels. | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.display-lg} | 80px | 800 | 0.98 | 0 | Page-level hero headlines | | {typography.display-md} | 65px | 800 | 1.0 | 0 | Major section headlines | | {typography.display-sm} | 55px | 800 | 1.05 | 0 | Secondary section headlines | | {typography.title-lg} | 40px | 800 | 1.07 | 0 | Large card titles | | {typography.title-md} | 28px | 800 | 1.3 | 0 | Standard card titles | | {typography.title-sm} | 24px | 800 | 1.25 | 0 | Small headings, nav items | | {typography.body-lg} | 20px | 800 | 1.29 | 0 | Subheadings, large lead paragraphs | | {typography.body-md} | 16px | 800 | 2.38 | 0 | Default body c...

Layout system: Spacing System - Base unit: 4px. - Tokens: {spacing.xxs} 12px · {spacing.xs} 20px · {spacing.sm} 24px · {spacing.md} 32px · {spacing.lg} 40px · {spacing.xl} 60px · {spacing.xxl} 100px · {spacing.section} 160px. - Section padding (vertical): Large gaps ({spacing.section} or {spacing.xxl}) between major full-bleed sections. - Card internal padding: {spacing.xs} (20px) is standard for content cards. - Gutters: Gaps between elements are generally small, as the visual separation is achieved through the stark black/white contrast and card borders. Grid & Container - Max content width: ~1200px, centered within full-bleed sections. - Sectioning: The primary layout structure is a series of full-bleed horizontal bands that alternate between {colors.canvas-dark} and {colors.canvas-light}. Whitespace Philosophy The system feels spacious due to the large gaps between sections and the generous line-height on body text. However, the heavy typography and dense display blocks create high visual weight, preventing the design from feeling airy or light. Whitespace is used to create dramatic pauses between stark, high-impact content blocks.

Depth and hierarchy: The system's approach to depth is unique and rejects conventional drop shadows. Elevation is conveyed through a single, consistently applied technique: a 2px inset shadow. This creates the illusion that elements like cards and buttons are physical objects pressed or debossed into the surface. | Level | Treatment | Use | |---|---|---| | Flat | No shadow, no border | Page canvas, background surfaces | | Inset Border | rgb(0, 0, 0) 0px 0px 0px 2px inset on light surfaces | The default state for all cards, buttons, and inputs on light canvas. Creates a black border. | | Inset Border (Inverted) | rgb(255, 255, 255) 0px 0px 0px 2px inset on dark surfaces | The default state for all cards, buttons, and inputs on dark canvas. Creates a white border. | | Chromatic Inset Border | [accent color] 0px 0px 0px 2px inset | Used for featured cards and badges, applying one of the three accent colors as the inset border. | There are no gradients, blurs, or traditional box-shadow properties for creating elevation. The entire depth model is built on this tactile, inset border effect.

Shape language: Border Radius Scale The system uses a minimal set of radii to define its shapes. The geometry is intentionally chunky and object-like. | Token | Value | Use | |---|---|---| | {rounded.sm} | 13px | Standard content cards | | {rounded.md} | 20px | Larger content cards, dialogs | | {rounded.lg} | 38px | The primary radius for all interactive elements (buttons, inputs, badges). Creates the pill shape. | | {rounded.pill} | 38px | Alias for {rounded.lg}, used for buttons and badges. | Decorative Shapes - Scattered Cards: A key visual motif is the use of rectangular card shapes, rotated at various angles (-15° to +20°) and scattered in the background of hero sections. This reinforces the core metaphor and adds texture.

Component language: Buttons All buttons are pill-shaped ({rounded.pill}) and derive their border from a 2px inset shadow. They have no background color. button-pill-on-dark — The primary button for use on {colors.canvas-dark}. It has a transparent background, white ({colors.body}) text, and a 2px white inset border. button-pill-on-light — The equivalent for use on {colors.canvas-light} or {colors.surface-card}. It has a transparent background, black ({colors.ink}) text, and a 2px black inset border. Ca...
```
