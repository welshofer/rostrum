# Lagoon

**ID:** `lagoon`  
**Category:** consumer  
**Theme:** dark  
**Vibe:** Bold

## Color palette

- `#00827c`
- `#cbfffc`
- `#011d1c`
- `#bbc7c6`
- `#ffffff`
- `#edfffe`
- `#fde9ff`
- `#333333`
- `#012624`
- `#003734`

## Typography

Families: "Matter, Inter, DM Sans, Satoshi, sans-serif". Weights: 400, 500.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Auros

Design token description: A deep, near-black teal abyss (012624) that serves as a canvas for luminous data points, subtle lavender warmth (fde9ff), and a single abstract particle visual that anchors the identity. Typography carries the system's confidence — a custom geometric sans is pushed to extreme sizes, from 10px tracked-out eyebrow labels to 295px display type that crouches aggressively tight. Surfaces are whisper-thin; the layered rectangular token motif layer (011d1c) sits just one shade deeper than the canvas, creating depth through tonal difference rather than shadows. Accents are rationed — a teal-to-cyan gradient signals action, a barely-there lavender border whispers warmth against the cool field, and small mint dots prefix section labels.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- Detected source-domain vocabulary: finance/banking. Translate it into reusable visual behavior, not literal imagery.
- Avoid literal source imagery unless the exact slide text or visual direction explicitly requests it: credit cards, debit cards, bank apps, cash, coins, trading screens, or crypto coins; financial product mockups unless requested by slide content.

Overall visual personality: The system presents as a deep-ocean dynamic transaction/data-flow pattern terminal: a near-black teal abyss ({colors.canvas-dark} — 012624) punctuated by luminous data points, subtle lavender warmth, and a single abstract particle graphic that anchors the visual identity. The entire mood is one of quiet, technical confidence. Typography is a core brand pillar. A custom geometric sans-serif, Matter, is pushed to extreme sizes, from 10px tracked-out eyebrow labels ({typography.eyebrow}) to 295px display type ({typography.display-xl}) that crouches with aggressive negative letter-spacing. This dramatic contrast in scale creates a precise, architectural feel. Surfaces are whisper-thin and defined by tonal depth, not shadows. The primary layered rectangular token motif layer ({colors.surface-card-dark} — 011d1c) sits just one shade deeper than the canvas, creating a "pressed-in" effect rather than a lifted one. Accents are rationed for high impact: a teal-to-cyan gradient ({colors.primary} to {colors.primary-accent}) signals the primary action, a barely-there lavender border whispers warmth against the cool field, and small mint dots prefix section labels like navigation beacons. Key C...

Color tokens:
- primary: #00827c
- primary-accent: #cbfffc
- ink: #011d1c
- body: #bbc7c6
- on-dark: #ffffff
- accent-cool: #edfffe
- accent-warm: #fde9ff
- border-strong: #333333
- canvas-dark: #012624
- surface-card-dark: #011d1c
- surface-interactive-dark: #003734

Typography tokens:
- display-xl: family Matter, Inter, DM Sans, Satoshi, sans-serif, size 295px, weight 400, line 1, tracking -13.57px
- display: family Matter, Inter, DM Sans, Satoshi, sans-serif, size 96px, weight 400, line 1, tracking -3.84px
- hero-display: family Matter, Inter, DM Sans, Satoshi, sans-serif, size 86px, weight 400, line 1.1, tracking -1.22px
- display-lg: family Matter, Inter, DM Sans, Satoshi, sans-serif, size 61px, weight 400, line 1.1, tracking -1.22px
- display-md: family Matter, Inter, DM Sans, Satoshi, sans-serif, size 36px, weight 400, line 1.3, tracking -0.47px
- display-sm: family Matter, Inter, DM Sans, Satoshi, sans-serif, size 24px, weight 400, line 1.4, tracking -0.29px
- title-lg: family Matter, Inter, DM Sans, Satoshi, sans-serif, size 20px, weight 400, line 1.4, tracking 0
- body-lg: family Matter, Inter, DM Sans, Satoshi, sans-serif, size 16px, weight 400, line 1.5, tracking 0
- body-md: family Matter, Inter, DM Sans, Satoshi, sans-serif, size 14px, weight 400, line 1.5, tracking 0.77px
- caption: family Matter, Inter, DM Sans, Satoshi, sans-serif, size 12px, weight 500, line 1.4, tracking 1.44px
- eyebrow: family Matter, Inter, DM Sans, Satoshi, sans-serif, size 10px, weight 500, line 1.4, tracking 2.4px
- button: family Matter, Inter, DM Sans, Satoshi, sans-serif, size 12px, weight 500, line 1, tracking 1.44px

Spacing tokens:
- xxs: 12px
- xs: 16px
- sm: 20px
- md: 24px
- lg: 32px
- xl: 40px
- xxl: 64px
- section: 68px

Radius and shape tokens:
- sm: 6px
- lg: 16px
- pill: 9999px
- full: 9999px

Component tokens:
- button-primary-gradient: backgroundColor: {colors.primary}, textColor: {colors.ink}, typography: {typography.button}, rounded: {rounded.sm}, padding: 14px 28px
- button-secondary-outline: backgroundColor: transparent, textColor: {colors.on-dark}, typography: {typography.button}, rounded: {rounded.sm}, padding: 14px 24px
- top-nav: backgroundColor: transparent, textColor: {colors.on-dark}, typography: {typography.caption}, height: 64px
- section-link-card: backgroundColor: {colors.surface-card-dark}, textColor: {colors.body}, typography: {typography.body-md}, rounded: {rounded.lg}, padding: {spacing.xl}
- hero-band: backgroundColor: transparent, textColor: {colors.on-dark}, typography: {typography.hero-display}
- eyebrow-label: backgroundColor: transparent, textColor: {colors.body}, typography: {typography.eyebrow}
- inline-link-arrow: backgroundColor: transparent, textColor: {colors.accent-cool}, rounded: {rounded.sm}, height: 28px, width: 28px

Color rationale: Surface - Canvas Dark ({colors.canvas-dark} — 012624): The primary page background. A deep, abyssal teal that serves as the foundation for the entire interface. - Surface layered rectangular token motif Dark ({colors.surface-card-dark} — 011d1c): The primary layered rectangular token motif surface. One step darker than the canvas, giving layered rectangular token motif a "pressed-in" or "recessed" feel. - Surface Interactive Dark ({colors.surface-interactive-dark} — 003734): A slightly lighter teal used for interactive layered rectangular token motif backgrounds or subtle filled actions, providing a gentle lift from the canvas. Text - On Dark ({colors.on-dark} — ffffff): Pure white, used for primary headings, nav text, and high-contrast icon strokes. - Body ({colors.body} — bbc7c6): A muted, low-contrast "fog" color for running body copy and secondary labels. - Ink ({colors.ink} — 011d1c): The darkest color, used for text on the light-gradient primary CTA to ensure high contrast. Brand & Accent - Primary ({colors.primary} — 00827c): The dark teal start of the primary action gradient. Used as the base color for {component.button-primary-gradient}. - Primary Accent ({colors.primary-...

Typography rationale: Font Family The system relies exclusively on a single geometric sans-serif typeface, Matter, for all text. This creates a cohesive and disciplined typographic voice. If unavailable, Inter, DM Sans, or Satoshi are suitable open-source substitutes. Hierarchy The type scale is defined by its extreme range and its unconventional use of letter-spacing. Large display sizes are set with tight negative tracking for a dense, architectural feel, while small caption and eyebrow sizes are set with wide positive tracking for legibility and style. Weight is used sparingly; most text is fontWeight: 400, with 500 reserved for buttons and emphasized labels. | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.display-xl} | 295px | 400 | 1 | -13.57px | Maximum-impact page titles | | {typography.display} | 96px | 400 | 1 | -3.84px | Large section headers | | {typography.hero-display} | 86px | 400 | 1.1 | -1.22px | Primary hero headlines | | {typography.display-lg} | 61px | 400 | 1.1 | -1.22px | Secondary hero headlines | | {typography.display-md} | 36px | 400 | 1.3 | -0.47px | Large headings within content | | {typography.display-sm} | 24px | 400 | 1...

Layout system: Spacing System - Base unit: 4px. - Tokens: {spacing.xxs} 12px · {spacing.xs} 16px · {spacing.sm} 20px · {spacing.md} 24px · {spacing.lg} 32px · {spacing.xl} 40px · {spacing.xxl} 64px · {spacing.section} 68px. - Section padding (vertical): {spacing.section} (68px) is used consistently between major content bands, creating a spacious and deliberate rhythm. - layered rectangular token motif internal padding: {spacing.xl} (40px) is used for primary content layered rectangular token motif, reinforcing the generous whitespace philosophy. - Gutters: {spacing.sm} (20px) is used between related elements within a component. Grid & Container - Max content width: 1200px, centered within a full-bleed dark canvas. - Structure: Layouts are typically single-column, with content arranged in distinct horizontal bands. Two-column layouts are used sparingly for pairing descriptive text with a decorative graphic. There are no sidebars.

Depth and hierarchy: The system's approach to depth is its most defining characteristic. It rejects drop shadows in favor of a tonal elevation model. - Level 0 (Canvas): The {colors.canvas-dark} page background. - Level 1 (layered rectangular token motif): The {colors.surface-card-dark} surface, which is darker than the canvas. This makes layered rectangular token motif feel "pressed into" the background, not lifted above it. - Level 2 (Interactive): The {colors.surface-interactive-dark} surface, which is slightly lighter than the canvas, used for elements that need a subtle lift. This creates a low-relief, architectural topography where depth is felt through color shifts rather than simulated light and shadow.

Shape language: Border Radius Scale The radius scale is minimal and disciplined. | Token | Value | Use | |---|---|---| | {rounded.sm} | 6px | Buttons, inputs, tags, and other small interactive controls. | | {rounded.lg} | 16px | Content layered rectangular token motif and larger containers. | | {rounded.pill} | 9999px | Avatars or other circular elements. | | {rounded.full} | 9999px | Avatars or other circular elements. | Iconography & Imagery The system avoids photography and product screenshots. The visual language is built on abstract, generative graphics: - A central "particle sphere" motif, rendered with a teal/cyan bioluminescent effect. - Sparse, organic node-and-line network diagrams, rendered in {colors.on-dark}. These elements provide atmosphere and thematic context without being literal.

Component language: Navigation top-nav — A fixed, transparent top bar with a height of 64px. It has no background fill, allowing the page's dark canvas to show through. Navigation links use {typography.caption} in {colors.on-dark}. Buttons button-primary-gradient — The primary CTA. It features a linear gradient fill from {colors.primary} to {colors.primary-accent}. Text is set in {colors.ink} for maximum contrast, using {typography.button}. It has a {rounded.sm} radius. button-secondary-outline — A ghost button used for secondary actions. It has a transparent background and a 1px border that uses a multi-stop gradient (cyan-to-lavender). Text is {colors.on-dark} and uses {typography.button} with a {rounded.sm} radius. inline-link-arrow — A compact, icon-only link for use inside layered rectangular token motif. It's a 28x28px square with a {rounded.sm} radius and a 1px border in {colors.accent-cool}. layered rectangular token motif & Labels section-link-card — The primary container for navigable content. It uses the "pressed-in" {colors.surface-card-dark} background, has a generous {spacing.xl} padding and a {rounded.lg} radius. Headings are {typography.display-sm} in {colors.on-dark}, and body text i...

Guardrails: Do - Use the single geometric sans-serif for all text. - Push display type to extreme sizes and use aggressive negative letter-spacing for headlines. - Differentiate surfaces using tonal depth ({colors.canvas-dark} vs. {colors.surface...
```
