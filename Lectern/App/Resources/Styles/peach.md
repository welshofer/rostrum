# Peach

**ID:** `peach`  
**Category:** consumer  
**Theme:** light  
**Vibe:** Playful

## Color palette

- `#f04923`
- `#ffffff`
- `#ebeadf`
- `#d5cec0`
- `#000000`
- `#b8c5e8`

## Typography

Families: "'Supreme LL TT', -apple-system, BlinkMacSystemFont, sans-serif", "'Supreme LL TT', sans-serif". Weights: 400, 700.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Bella

Design token description: A warm, domestic kitchen-counter aesthetic built on a cream-and-coral palette that feels sunlit rather than clinical. The entire interface rests on a warm off-white canvas (ebeadf) with slightly warmer beige and white cards floating above. Layers are defined by hue temperature, not stark contrast. A single saturated coral accent (f04923) provides all the energy for tags, promotional cards, and active states. Typography uses a geometric sans (Supreme LL TT) with uniformly tight negative letter-spacing at every size, giving headings a compact, modern posture. The design avoids shadows entirely, favoring color-temperature layering and soft corners, with buttons and badges rendered as full pills.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- No dominant source-domain vocabulary was detected, but still avoid copying example subject matter from the design brief.
- Avoid brand logos, product shots, mascot imagery, packaging, buildings, people, or industry-specific objects unless requested by the slide content.

Overall visual personality: The system presents a warm, domestic kitchen-counter aesthetic built on a cream-and-coral palette that feels sunlit rather than clinical. The entire interface rests on a warm off-white canvas ({colors.canvas} — ebeadf) with slightly warmer beige ({colors.surface-muted}) and pristine white ({colors.surface-card}) cards floating above. A single, saturated coral accent ({colors.primary} — f04923) provides all the brand energy: bestseller tags, promotional cards, price highlights, and active states. Typography uses a geometric sans-serif, Supreme LL TT, with uniformly tight negative letter-spacing at every size, giving headings a compact, modern posture. {typography.display-sm} uses -2px of tracking, and even body copy ({typography.body-md}) is tightened to -0.8px. This is a core typographic signature. The design avoids drop shadows entirely. Depth and hierarchy are communicated through color-temperature layering. Buttons, badges, and tags are universally pill-shaped ({rounded.pill}), while all content cards use a soft {rounded.lg} (12px) corner radius. The overall feel is approachable, appetite-driven, and minimalist, letting media and product photography provide the atmospheric weig...

Color tokens:
- primary: #f04923
- on-primary: #ffffff
- canvas: #ebeadf
- surface-card: #ffffff
- surface-muted: #d5cec0
- ink: #000000
- body: #000000
- hairline: #000000
- accent-soft-blue: #b8c5e8

Typography tokens:
- display-sm: family 'Supreme LL TT', -apple-system, BlinkMacSystemFont, sans-serif, size 40px, weight 700, line 1.1, tracking -2px
- title-md: family 'Supreme LL TT', sans-serif, size 24px, weight 700, line 1.4, tracking -1.2px
- title-sm: family 'Supreme LL TT', sans-serif, size 22px, weight 700, line 1.4, tracking -1.1px
- body-lg: family 'Supreme LL TT', sans-serif, size 18px, weight 400, line 1.4, tracking -0.9px
- body-md: family 'Supreme LL TT', sans-serif, size 16px, weight 400, line 1.5, tracking -0.8px
- body-sm: family 'Supreme LL TT', sans-serif, size 14px, weight 400, line 1.5, tracking -0.7px
- caption: family 'Supreme LL TT', sans-serif, size 13px, weight 400, line 1.5, tracking -0.65px
- button: family 'Supreme LL TT', sans-serif, size 14px, weight 700, line 1, tracking -0.7px
- nav-link: family 'Supreme LL TT', sans-serif, size 16px, weight 400, line 1.5, tracking -0.8px

Spacing tokens:
- xxs: 4px
- xs: 8px
- sm: 12px
- md: 16px
- lg: 24px
- xl: 32px
- xxl: 64px
- section: 80px

Radius and shape tokens:
- lg: 12px
- pill: 9999px
- full: 9999px

Component tokens:
- top-nav: backgroundColor: {colors.surface-card}, textColor: {colors.ink}, typography: {typography.nav-link}, rounded: {rounded.lg}, height: 64px, padding: 0 24px
- product-card: backgroundColor: {colors.surface-card}, textColor: {colors.ink}, typography: {typography.body-sm}, rounded: {rounded.lg}, padding: {spacing.lg}
- bestseller-badge: backgroundColor: {colors.primary}, textColor: {colors.on-primary}, typography: {typography.caption}, rounded: {rounded.pill}, padding: 12px 20px
- button-filled: backgroundColor: {colors.surface-card}, textColor: {colors.ink}, typography: {typography.button}, rounded: {rounded.pill}, padding: 12px 24px, border: 1px solid {colors.hairline}
- button-outlined: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.button}, rounded: {rounded.pill}, padding: 12px 24px, border: 1px solid {colors.hairline}
- featured-product-card: backgroundColor: {colors.primary}, textColor: {colors.on-primary}, typography: {typography.title-sm}, rounded: {rounded.lg}, padding: {spacing.lg}
- inspiration-card: backgroundColor: {colors.accent-soft-blue}, textColor: {colors.ink}, typography: {typography.title-md}, rounded: {rounded.lg}, padding: {spacing.lg}
- lifestyle-card-overlay: backgroundColor: {colors.surface-card}, textColor: {colors.ink}, typography: {typography.title-md}, rounded: {rounded.lg}, padding: {spacing.lg}

Color rationale: Brand & Accent - Coral Pulse ({colors.primary} — f04923): The singular, energetic brand accent. Used for bestseller badge backgrounds, promotional cards, and price callouts. - On Primary ({colors.on-primary} — ffffff): Pure white text used on coral surfaces for maximum contrast. - Accent Soft Blue ({colors.accent-soft-blue} — b8c5e8): A secondary, muted accent used for inspiration/content cards. It's a single-use color, not part of the primary brand system. Surface The system defines elevation through color temperature, not shadows. - Warm Canvas ({colors.canvas} — ebeadf): The base page background. A foundational warm off-white that gives the interface its sunlit, lived-in feel. - Surface Muted ({colors.surface-muted} — d5cec0): A sand-beige tone for secondary background panels and product grouping sections. - Surface Card ({colors.surface-card} — ffffff): The highest elevation level. Used for primary card surfaces, the navigation bar, and filled pill buttons. Text & Hairlines - Ink ({colors.ink} — 000000): The primary text color for all copy, headlines, and icons. The system relies on pure black for typographic clarity against the warm surfaces. - Body ({colors.body} — 000000):...

Typography rationale: Font Family The system runs on a single geometric sans-serif typeface, Supreme LL TT, for all UI text, from display headlines to captions. Its defining characteristic is the consistently tight negative letter-spacing applied across the entire scale. The font uses OpenType features ss01 and cv11. If the primary font is unavailable, Inter or DM Sans are suitable open-source substitutes. Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.display-sm} | 40px | 700 | 1.1 | -2px | Hero headlines | | {typography.title-md} | 24px | 700 | 1.4 | -1.2px | Section headings, card titles | | {typography.title-sm} | 22px | 700 | 1.4 | -1.1px | Smaller card headlines | | {typography.body-lg} | 18px | 400 | 1.4 | -0.9px | Subheadings and lead paragraphs | | {typography.body-md} | 16px | 400 | 1.5 | -0.8px | Default running text, nav links | | {typography.body-sm} | 14px | 400 | 1.5 | -0.7px | Price displays, secondary labels | | {typography.caption} | 13px | 400 | 1.5 | -0.65px | Smallest meta text, badge labels | | {typography.button} | 14px | 700 | 1 | -0.7px | All pill button labels | Principles - Tight tracking is mandatory: The nega...

Layout system: Spacing System - Base unit: 4px. - Tokens: {spacing.xxs} 4px · {spacing.xs} 8px · {spacing.sm} 12px · {spacing.md} 16px · {spacing.lg} 24px · {spacing.xl} 32px · {spacing.xxl} 64px · {spacing.section} 80px. - Section padding (vertical): {spacing.section} (80px) is used between major content blocks to create a comfortable, breathable pace. - Card internal padding: {spacing.lg} (24px) is the standard for all content cards. - Gutters: {spacing.lg} (24px) between items in product grids. Grid & Container - Max content width: 1200px, centered. Pages often use an outer margin of {spacing.md} (16px) to give the main container a floating-card feel on the warm canvas. - Product grid: Typically a 4-column layout on desktop. Whitespace Philosophy The system uses generous whitespace to create a calm, uncluttered, and premium feel. Space is used to separate elements and guide the eye, reinforcing the minimalist aesthetic. The consistent {spacing.section} rhythm between blocks is key to the layout's predictable and serene pacing.

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | Level 0 | {colors.canvas} background | The base page floor; the warmest tone. | | Level 1 | {colors.surface-muted} background | Secondary panels, used to group content. | | Level 2 | {colors.surface-card} background | Primary content cards, navigation, dialogs; the highest, coolest tone. | The elevation philosophy explicitly forbids drop shadows. Depth is communicated through a three-tier surface temperature system: the warm {colors.canvas} is the base, the slightly cooler {colors.surface-muted} is the mid-tier, and the pristine {colors.surface-card} is the most elevated surface. This approach keeps the interface feeling flat, warm, and domestic—like objects resting on a sunlit counter rather than floating in digital space.

Shape language: Border Radius Scale | Token | Value | Use | |---|---|---| | {rounded.lg} | 12px | The universal radius for all cards, containers, and media items. | | {rounded.pill} | 9999px | Used for all buttons, badges, and tags. This is the only other radius in the system. | The shape language is simple and soft. There are no sharp corners. Every container uses the {rounded.lg} value for consistency. Every interactive, badge-like element uses the {rounded.pill} shape to clearly signal its purpose.

Component language: Navigation top-nav — A full-width bar with a {colors.surface-card} background and {rounded.lg} corners, making it feel like a floating card near the top of the viewport. It contains navigation links styled with {component.category-link}. Cards product-card — The standard grid item for product listings. A {colors.surface-card} background with {rounded.lg} corners and generous {spacing.lg} internal padding. It contains an image area, a product title in {typography.body-md} at weight 700, and a price in {typography.body-sm}. featured-product-card — A promotional card with a full {colors.primary} background and {colors.on-primary} text. Used to draw attention to a key item, often in a hero section. inspiration-card — A content card using the soft {colors.accent-soft-blue} background to differentiate it from product-focused e-commerce surfaces. lifestyle-card-overlay — A simple {colors.surface-card} container with text, designed to be overlaid on a full-bleed background image. Buttons & Badges button-filled — A pill-shaped button with a {colors.surface-card} background, black text, and a 1px {colors.hairline} border. This is a primary text-based CTA. button-outlined — A ghost-style pil...

Guardrails: Do - Use {colors.canvas} as the page background for all non-card areas. The warm cream is the foundational canvas. - Reserve {colors.primary} exclusively for functional accents: bestseller badges, promotional cards, and active price highlights. - Apply tight negative letter-spacing (e.g., -0.05em) at every text size. This is a non-negotiable brand signature. - Use {rounded.pill} for all buttons, badges, and tags. Pill shapes are the system's interactive language. - Use {rounded.lg} (12px) for all cards and image containers. - Define elevation using the three-tier surface temperatures: {c...
```
