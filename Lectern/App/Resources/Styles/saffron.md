# Saffron

**ID:** `saffron`  
**Category:** consumer  
**Theme:** dark  
**Vibe:** Editorial

## Color palette

- `#fde440`
- `#433e3c`
- `#ffffff`
- `#898989`
- `#000000`
- `#f0e7e4`
- `#2b2b2b`
- `#221f1e`
- `#113619`
- `#322b66`

## Typography

Families: "'Helvetica Neue', Inter, sans-serif", "Portrait, 'DM Serif Display', serif". Weights: 400, 700.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: July Fund

Design token description: An editorial mosaic rendered in a dark, museum-like gallery space. The base is near-black (000000), and content is built from individual themed cards — each one a saturated color field acting as a chapter in a visual index. Typography is deliberately split; a high-contrast custom serif sets headlines that feel like gallery wall text, while a compact sans-serif runs labels, metadata, and body copy in a quiet, precise voice. The system reads as a printed monograph made interactive — generous padding, pill-shaped controls, and uppercase letter-spaced badges. Color is not decoration; it is categorization, with each chromatic card signaling a different content vertical.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- Detected source-domain vocabulary: consumer technology. Translate it into reusable visual behavior, not literal imagery.
- Avoid literal source imagery unless the exact slide text or visual direction explicitly requests it: phones, laptops, tablets, device mockups, or hardware product renders; app screenshots, operating-system chrome, or product launch hero shots.

Overall visual personality: The system presents an editorial, almost academic, visual language on a dark canvas. The core metaphor is a gallery or printed monograph, where content lives on distinct "cards," and color is used for categorization rather than decoration. The page floor is pure black ({colors.canvas-dark}), creating a void from which content cards emerge. The system's most defining feature is a split-personality typography. A high-contrast display serif ({typography.hero-display-serif}) renders all headlines and titles, lending a formal, published feel. In stark contrast, a neutral sans-serif ({typography.body-md-sans}) handles all body copy, UI controls, and metadata with quiet precision. This sans-serif's signature is its use of extreme letter-spacing ({typography.label-uppercase}) on small, uppercase labels, making even tiny metadata feel deliberate and designed. There are no shadows, glows, or gradients. Depth is implied exclusively through the contrast of chromatic cards against the black canvas. Each major content vertical is assigned a deep, saturated color ({colors.themed-green}, {colors.themed-violet}), and cards use these as solid background fills. This makes the layout grid itself a fo...

Color tokens:
- primary: #fde440
- ink: #433e3c
- body: #ffffff
- body-on-light: #433e3c
- muted: #898989
- hairline: #433e3c
- canvas-dark: #000000
- canvas-light: #f0e7e4
- surface-card-dark: #2b2b2b
- surface-button-dark: #221f1e
- on-dark: #ffffff
- on-light: #433e3c
- on-primary: #433e3c
- themed-green: #113619

Typography tokens:
- hero-display-serif: family Portrait, 'DM Serif Display', serif, size 96px, weight 400, line 1.05, tracking 0px
- display-lg-serif: family Portrait, 'DM Serif Display', serif, size 40px, weight 400, line 1.2, tracking 0px
- display-md-serif: family Portrait, 'DM Serif Display', serif, size 35px, weight 400, line 1.2, tracking 0px
- display-sm-serif: family Portrait, 'DM Serif Display', serif, size 30px, weight 400, line 1.2, tracking 0px
- title-serif: family Portrait, 'DM Serif Display', serif, size 18px, weight 400, line 1.3, tracking 0px
- body-lg-sans: family 'Helvetica Neue', Inter, sans-serif, size 16px, weight 400, line 1.3, tracking 0px
- body-md-sans: family 'Helvetica Neue', Inter, sans-serif, size 15px, weight 400, line 1.3, tracking 0px
- label-uppercase: family 'Helvetica Neue', Inter, sans-serif, size 10px, weight 700, line 1.2, tracking 2px
- label-uppercase-sm: family 'Helvetica Neue', Inter, sans-serif, size 8px, weight 700, line 1.15, tracking 2px

Spacing tokens:
- xxs: 4px
- xs: 12px
- sm: 16px
- md: 20px
- lg: 40px
- xl: 60px
- xxl: 80px
- section: 80px

Radius and shape tokens:
- xs: 5px
- sm: 8px
- md: 12px
- lg: 20px
- pill: 24px
- full: 9999px

Component tokens:
- themed-card-green: backgroundColor: {colors.themed-green}, textColor: {colors.on-dark}, rounded: {rounded.lg}, padding: {spacing.lg}
- themed-card-violet: backgroundColor: {colors.themed-violet}, textColor: {colors.on-dark}, rounded: {rounded.lg}, padding: {spacing.lg}
- themed-card-olive: backgroundColor: {colors.themed-olive}, textColor: {colors.on-dark}, rounded: {rounded.lg}, padding: {spacing.lg}
- themed-card-yellow: backgroundColor: {colors.primary}, textColor: {colors.on-primary}, rounded: {rounded.lg}, padding: {spacing.lg}
- monochrome-card-dark: backgroundColor: {colors.surface-card-dark}, textColor: {colors.on-dark}, rounded: {rounded.lg}, padding: {spacing.lg}
- hero-panel-light: backgroundColor: {colors.canvas-light}, textColor: {colors.ink}, rounded: {rounded.lg}, padding: {spacing.lg}
- ghost-pill-button: backgroundColor: transparent, textColor: {colors.on-dark}, typography: {typography.label-uppercase-sm}, rounded: {rounded.pill}, padding: 5px 22px
- filled-pill-button-dark: backgroundColor: {colors.surface-button-dark}, textColor: {colors.on-dark}, typography: {typography.label-uppercase-sm}, rounded: {rounded.pill}, padding: 5px 22px

Color rationale: the source brand - Canvas Dark ({colors.canvas-dark} — 000000): The pure black page floor. It creates the "void" between content cards, establishing the gallery-like atmosphere. - Canvas Light ({colors.canvas-light} — f0e7e4): A warm, creamy off-white used for the single introductory hero panel. It acts as an inverted, paper-like the source brand against the dark canvas. - the source brand Card Dark ({colors.surface-card-dark} — 2b2b2b): A dark charcoal used for monochrome content cards that do not belong to a specific chromatic category. - the source brand Button Dark ({colors.surface-button-dark} — 221f1e): A deep espresso color for filled button backgrounds, one step darker than the charcoal card it sits on. Thematic & Accent The system uses color for categorization. Each of these represents a content "chapter." - Primary Accent ({colors.primary} — fde440): A high-impact solar yellow, used as a thematic card fill for the most important content. This is the loudest color in the palette. - Themed Green ({colors.themed-green} — 113619): A deep forest green card background. - Themed Violet ({colors.themed-violet} — 322b66): A saturated twilight violet card background. - Themed Oliv...

Typography rationale: Font Family The system uses a strict two-family structure to separate editorial voice from UI function. - Portrait: A high-contrast, didone-style serif for all headlines, from the largest hero display down to card titles. It is always used at a regular weight (400); emphasis is created by size, not boldness. The closest open-source substitute is DM Serif Display. - Helvetica Neue: A neutral, functional sans-serif for all other text: body copy, captions, metadata, and all UI controls (buttons, badges). It is used at regular weight (400) for body and bold (700) for UI labels. The defining characteristic is the wide letter-spacing on small, uppercase text. The closest open-source substitute is Inter. Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.hero-display-serif} | 96px | 400 | 1.05 | 0px | The main display headline on the hero panel. | | {typography.display-lg-serif} | 40px | 400 | 1.2 | 0px | Large section titles. | | {typography.display-md-serif} | 35px | 400 | 1.2 | 0px | Primary card headlines. | | {typography.display-sm-serif} | 30px | 400 | 1.2 | 0px | Secondary card headlines. | | {typography.title-serif} |...

Layout system: Spacing System - Base unit: 4px. - Tokens: {spacing.xxs} 4px · {spacing.xs} 12px · {spacing.sm} 16px · {spacing.md} 20px · {spacing.lg} 40px · {spacing.xl} 60px · {spacing.xxl} 80px. - Section padding (vertical): {spacing.section} (80px). Major sections are separated by a large gap of the empty {colors.canvas-dark}, reinforcing the "void" between gallery sections. - Card internal padding: {spacing.lg} (40px). This generous internal whitespace is key to the un-crowded, editorial feel. - Gutters: {spacing.md} (20px) between cards in the grid layout. Grid & Container - Max content width: 1280px, centered. - Grid: The primary layout is an asymmetric, masonry-style grid of cards. Below the full-width hero panel, the layout typically breaks into a responsive 3-column grid where cards have variable heights. - Structure: The grid of cards itself functions as the primary navigation. Each card is a clickable entry point into a piece of content. Whitespace Philosophy The system uses whitespace generously, both inside and outside of components. Internal card padding ({spacing.lg}) ensures content breathes. The large {spacing.section} gap between page sections, rendered as empty black canvas,...

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | Flat | No shadow, no border | The page canvas, all cards, and all UI elements. | | Hairline | 1px {colors.hairline} | Ghost buttons, dividers between footer links. | The system is intentionally and uniformly flat. There are no box-shadows, glows, or blurs used to simulate depth. Elevation is communicated entirely through color and layout. A brightly colored card ({component.themed-card-yellow}) sitting on the black {colors.canvas-dark} feels "elevated" due to perceptual contrast, not a rendered shadow effect. This reinforces the design's connection to print media and physical gallery spaces.

Shape language: Border Radius Scale | Token | Value | Use | |---|---|---| | {rounded.xs} | 5px | Small, subtle UI controls. | | {rounded.sm} | 8px | Tag badges ({component.tag-badge-green}). | | {rounded.md} | 12px | All inset media tiles ({component.image-tile}). | | {rounded.lg} | 20px | The default radius for all primary content cards. | | {rounded.pill} | 24px | All buttons ({component.ghost-pill-button}). | The shape language is defined by soft, generous curves. The large {rounded.lg} on cards gives them a friendly, non-rigid feel, while the full {rounded.pill} for buttons makes controls feel like distinct objects. This consistent softness contrasts with the sharp, precise typography. Media & Iconography - Media is always contained within a tile with a {rounded.md} (12px) radius. It never bleeds to the edge of a card. This frames the content, treating it like a mounted photograph. - Iconography is minimal and line-based, with a stroke of ~1.5px. It is used sparingly, typically for metadata signifiers.

Component language: Content Cards The primary unit of the interface is the card. They appear in several variants, but share a common shape and padding. themed-card- — The signature component. A card with a {rounded.lg} radius and a solid background fill using one of the thematic colors (e.g., {colors.themed-green}). It contains a serif headline, sans-serif body copy, and often an inset {component.image-tile}. The color itself signals the content's category. monochrome-card-dark — The default card for content that isn't part of a chromatic theme. It uses {colors.surface-card-dark} for its background and holds white text. hero-panel-light — A special, full-width introductory card that uses the light {colors.canvas-light} background. It typically holds the largest display text on the site ({typography.hero-display-serif}) and serves as the entry point before the user scrolls into the dark grid. UI Controls ghost-pill-button — The default button style. It is transparent with a 1px {colors.hairline} border and features a widely-tracked, uppercase sans-serif label ({typography.label-uppercase-sm}). Its shape is a full {rounded.pill}. filled-pill-button-dark — A rare, higher-empha...
```
