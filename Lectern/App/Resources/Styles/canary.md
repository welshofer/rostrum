# Canary

**ID:** `canary`  
**Category:** consumer  
**Theme:** light  
**Vibe:** Bold

## Color palette

- `#ffe845`
- `#000000`
- `#ffffff`
- `#fbfaf2`
- `#007aff`

## Typography

Families: "ABC Monument Grotesk, Inter, sans-serif", "Gooper, Bagel Fat One, Fraunces, Bowlby One, sans-serif", "Pitch Sans, Söhne, sans-serif". Weights: 400, 600, 700.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Yellowbird

Design token description: A high-contrast, two-color system built on a vibrant yellow (ffe845) canvas that recalls retro print and packaging. Black (000000) performs all structural and typographic work — defining text, borders, hairlines, and the single primary call-to-action button. The system is intentionally flat; there are no shadows or gradients. Separation is achieved through thick black strokes and color blocking, with cream (fbfaf2) cards offering the only neutral relief. A custom, ultra-chunky display face provides a strong, graphic voice for hero moments, while a single-weight grotesque handles all other UI and body text.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- No dominant source-domain vocabulary was detected, but still avoid copying example subject matter from the design brief.
- Avoid brand logos, product shots, mascot imagery, packaging, buildings, people, or industry-specific objects unless requested by the slide content.

Overall visual personality: The system is a high-volume, two-color world built for contrast. A single vivid yellow ({colors.primary} — ffe845) floods every section as the default canvas, while solid black ({colors.ink} — 000000) does all structural and typographic work. The interface reads like a hand-drawn billboard: flat surfaces, thick hairline borders instead of shadows, generous breathing room, and a custom chunky display face for hero moments. There is no gradient depth, no glassmorphism, no card-on-card layering; spatial separation comes from color swaps (yellow band → cream card → black button) and generous padding ({spacing.section} — 80px). Interactive elements are minimal and confident: product cards use a large 30px radius ({rounded.xl}) with a solid black stroke, and the one true CTA is a heavy black button ({component.button-primary}) with white text. Key Characteristics: - Two-color discipline: {colors.primary} (ffe845) as the default canvas; {colors.ink} (000000) for text, strokes, and primary CTAs. - Flat design: No shadows, blurs, or gradients. Depth is created by thick black strokes ({colors.hairline}) and color-block separation. - Custom display type: An ultra-chunky, bubbly display face...

Color tokens:
- primary: #ffe845
- ink: #000000
- body: #000000
- canvas: #ffe845
- surface-light: #ffffff
- surface-alt: #fbfaf2
- hairline: #000000
- on-ink: #ffffff
- on-canvas: #000000
- accent-utility: #007aff

Typography tokens:
- hero-display: family Gooper, Bagel Fat One, Fraunces, Bowlby One, sans-serif, size 91px, weight 700, line 1.05, tracking -2.55px
- display-lg: family ABC Monument Grotesk, Inter, sans-serif, size 61px, weight 400, line 0.9, tracking -0.67px
- display-md: family ABC Monument Grotesk, Inter, sans-serif, size 45px, weight 400, line 1.0, tracking -0.63px
- title-lg: family ABC Monument Grotesk, Inter, sans-serif, size 41px, weight 400, line 1.1, tracking -0.45px
- title-md: family ABC Monument Grotesk, Inter, sans-serif, size 30px, weight 400, line 1.0, tracking -0.42px
- title-sm: family ABC Monument Grotesk, Inter, sans-serif, size 27px, weight 400, line 1.2, tracking -0.57px
- body-md: family ABC Monument Grotesk, Inter, sans-serif, size 18px, weight 400, line 1.3, tracking -0.18px
- body-sm: family ABC Monument Grotesk, Inter, sans-serif, size 16px, weight 400, line 1.3, tracking -0.18px
- caption: family ABC Monument Grotesk, Inter, sans-serif, size 14px, weight 400, line 1.2, tracking -0.56px
- button: family ABC Monument Grotesk, Inter, sans-serif, size 18px, weight 400, line 1, tracking -0.2px
- nav-link: family ABC Monument Grotesk, Inter, sans-serif, size 18px, weight 400, line 1, tracking -0.2px
- badge: family Pitch Sans, Söhne, sans-serif, size 16px, weight 600, line 1, tracking -0.5px

Spacing tokens:
- xxs: 4px
- xs: 8px
- sm: 16px
- md: 24px
- lg: 32px
- xl: 40px
- xxl: 60px
- section: 80px

Radius and shape tokens:
- sm: 6px
- md: 10px
- lg: 14px
- xl: 30px
- xxl: 36px
- pill: 9999px
- full: 9999px

Component tokens:
- announcement-bar: backgroundColor: {colors.ink}, textColor: {colors.on-ink}, typography: {typography.caption}, height: 36px
- top-nav: backgroundColor: {colors.canvas}, textColor: {colors.on-canvas}, typography: {typography.nav-link}
- hero-band: backgroundColor: {colors.canvas}, textColor: {colors.on-canvas}, typography: {typography.hero-display}, padding: 80px
- product-card: backgroundColor: {colors.surface-light}, textColor: {colors.on-canvas}, rounded: {rounded.xl}, padding: 24px, border: 2px solid {colors.hairline}
- product-card-alt: backgroundColor: {colors.surface-alt}, textColor: {colors.on-canvas}, rounded: {rounded.xl}, padding: 24px, border: 2px solid {colors.hairline}
- category-badge: backgroundColor: {colors.canvas}, textColor: {colors.on-canvas}, typography: {typography.badge}, rounded: {rounded.sm}, padding: 15px 18px, border: 1.5px solid {colors.hairline}
- button-primary: backgroundColor: {colors.ink}, textColor: {colors.on-ink}, typography: {typography.button}, rounded: {rounded.lg}, padding: 15px 18px
- button-secondary-ghost: backgroundColor: transparent, textColor: {colors.accent-utility}, typography: {typography.button}, rounded: {rounded.md}, padding: 10px 18px, border: 1.5px solid {colors.accent-utility}

Color rationale: Brand & Canvas - Primary Yellow ({colors.primary} — ffe845): The dominant brand color, used as the full-bleed canvas for almost every section: hero, footer, announcement bar, and product grids. Also used as the fill for category tags and decorative shapes. - Ink Black ({colors.ink} — 000000): The structural color. Used for all text, all borders and hairlines, and the background of the primary CTA button. It performs all the typographic and drawing work. Surface - Surface Light ({colors.surface-light} — ffffff): The primary card background for product tiles. Always sits on the yellow canvas with a thick black stroke. - Surface Alt ({colors.surface-alt} — fbfaf2): An alternate card surface, an off-white cream used for quieter product tiles to create subtle variation in grids. Text - Body ({colors.body} — 000000): Default text color on all light surfaces (yellow canvas, white cards, cream cards). Reuses the ink token. - On Ink ({colors.on-ink} — ffffff): White text used on black surfaces, primarily for the {component.button-primary} label. Accent - Accent Utility ({colors.accent-utility} — 007aff): A standard system blue reserved exclusively for the border and text of the secondary g...

Typography rationale: Font Family The system uses three distinct font families for specific roles: - Custom Display Face ("Gooper"): A bubbly, ultra-chunky display face used exclusively for {typography.hero-display} roles. It functions as a graphic element. (Substitutes: Bagel Fat One, Fraunces 900). - Workhorse Grotesque ("ABC Monument Grotesk"): The primary text face for nav links, body copy, product names, section headings, and button text. Used at a single weight (400). (Substitutes: Inter, Söhne). - Utility Sans ("Pitch Sans"): A secondary sans-serif for badges, tags, and micro-labels. Weight 600 is used here to add contrast. (Substitutes: Söhne, Untitled Sans). Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.hero-display} | 91px | 700 | 1.05 | -2.55px | Oversized hero statements | | {typography.display-lg} | 61px | 400 | 0.9 | -0.67px | Large section subheads | | {typography.display-md} | 45px | 400 | 1.0 | -0.63px | Long-form intro text, large quotes | | {typography.title-lg} | 41px | 400 | 1.1 | -0.45px | Section headings | | {typography.title-sm} | 27px | 400 | 1.2 | -0.57px | Product names on cards | | {typography.body-md} | 18p...

Layout system: Spacing System - Base unit: 4px. - Tokens: {spacing.xxs} 4px · {spacing.xs} 8px · {spacing.sm} 16px · {spacing.md} 24px · {spacing.lg} 32px · {spacing.xl} 40px · {spacing.xxl} 60px · {spacing.section} 80px. - Section padding (vertical): {spacing.section} (80px) is used between all major content bands, creating a generous, spacious rhythm. - Card internal padding: {spacing.md} (24px) is standard for product cards. - Gutters: {spacing.md} (24px) between cards in grids. Grid & Container - Max content width: ~1280px, centered on a full-bleed yellow canvas. - Product grid: Typically a 3-column grid at desktop. - Layout philosophy: Content is organized into distinct horizontal bands, separated by color blocks (e.g., a yellow band with cream cards, followed by a solid yellow band for a quote).

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | 1. Canvas | Flat {colors.canvas} fill | Page background, hero, footer, and testimonial bands | | 2. Card | {colors.surface-light} or {colors.surface-alt} fill with a 1.5-2px solid {colors.hairline} border | Product cards, media containers | | 3. Action | {colors.ink} fill | The primary CTA button | The system is intentionally flat and avoids shadows entirely. Spatial separation and hierarchy are achieved exclusively through color contrast and thick, solid black strokes on all "elevated" elements like cards. There is no z-axis depth model; the design reads like a screen-printed poster, not a layered digital interface.

Shape language: Border Radius Scale | Token | Value | Use | |---|---|---| | {rounded.sm} | 6px | Small tags and category badges | | {rounded.md} | 10px | Secondary ghost buttons | | {rounded.lg} | 14px | Primary action buttons | | {rounded.xl} | 30px | Product cards and all image/media containers | | {rounded.xxl} | 36px | Decorative sticker and seal shapes | | {rounded.pill} | 9999px | Not used as a primary style, available for utility | The shape language is defined by a friendly, generous radius. Cards and images use a very soft 30px corner, while buttons are more moderately rounded at 14px. This contrast between soft containers and tighter actions is a key principle.

Component language: Top Navigation A simple, full-bleed horizontal bar ({component.top-nav}) floating on the {colors.canvas} background. It contains left-aligned navigation links and right-aligned utility links, all set in {typography.nav-link}. There is no background color or border; it is part of the yellow canvas. Product Card The primary commerce tile ({component.product-card}). It uses a {colors.surface-light} or {colors.surface-alt} background with a thick, 2px solid {colors.hairline} border and a {rounded.xl} radius. It contains a product image and a name set in {typography.title-sm}. No shadow is ever applied. Category Badge A small label ({component.category-badge}) overlaid on product cards. It uses the {colors.canvas} yellow as a fill, with a {rounded.sm} radius and a 1.5px black {colors.hairline} border. The text is set in {typography.badge}, which is the only place a 600 font weight is used in the system. Buttons button-primary — The single, definitive primary CTA. It is a solid black ({colors.ink}) button with white ({colors.on-ink}) text, set in {typography.button} with a {rounded.lg} radius. It sits flat on the canvas like a sticker, with no hover effect. button-secondary-ghost — An o...

Guardrails: Do - Use {colors.primary} as the full-bleed canvas for every major section. - Achieve typographic hierarchy through size and negative tracking, not font weight changes (except for badges). - Use a 30px {rounded.xl} radius on all product cards and images. - Separate sections by color-blocking (e.g., yellow band → cream card → yellow band), not with shadows or dividers. - Use the chunky display face only for top-level, expressive hero statements. - Ensure all CTA text is consistent, using {typography...
```
