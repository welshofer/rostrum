# Sapphire

**ID:** `sapphire`  
**Category:** consumer  
**Theme:** light  
**Vibe:** Corporate

## Color palette

- `#0067b8`
- `#ffffff`
- `#f2f2f2`
- `#000000`
- `#262626`
- `#616161`
- `#171717`

## Typography

Families: "Segoe UI, -apple-system, BlinkMacSystemFont, sans-serif". Weights: 400, 600.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Microsoft

Design token description: the source brand.com is a corporate store-and-marketing the source brand a near-white canvas (ffffff) punctuated by a single vivid corporate blue (0067b8), with product cards floating on subtle elevation and one-color hero banners. Segoe UI carries the entire system — a humanist grotesque that reads utilitarian and confident rather than editorial. The visual rhythm is grid-disciplined 4-column product rows, centered max-width bands, and hero sections that alternate between blue-tinted lifestyle photography and pure white card overlays. Components feel light, flat, and functional — minimal radii (2px), thin borders, one shadow stack, no decorative gradients — letting product photography do the visual heavy lifting while the blue accent marks every action.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- Detected source-domain vocabulary: consumer technology. Translate it into reusable visual behavior, not literal imagery.
- Avoid literal source imagery unless the exact slide text or visual direction explicitly requests it: phones, laptops, tablets, device mockups, or hardware product renders; app screenshots, operating-system chrome, or product launch hero shots.

Overall visual personality: the source brand.com is a corporate store-and-marketing the source brand: a near-white canvas ({colors.canvas-light} — ffffff) punctuated by a single vivid corporate blue ({colors.primary} — 0067b8), with product cards floating on subtle elevation and one-color hero banners. Segoe UI carries the entire system — a humanist grotesque that reads utilitarian and confident rather than editorial. The visual rhythm is grid-disciplined: 4-column product rows, centered max-width bands, and hero sections that alternate between blue-tinted lifestyle photography and pure white card overlays. Components feel light, flat, and functional — minimal radii ({rounded.sm} — 2px), thin borders, one shadow stack, no decorative gradients — letting product photography do the visual heavy lifting while the blue accent marks every action. Key Characteristics: - Single accent color: {colors.primary} (0067b8) is the sole chromatic authority, used for every filled CTA, text link, icon stroke, and navigation accent. - Utilitarian typography: Segoe UI is the only typeface. Weight 600 is used for headings and buttons; weight 400 for everything else. The type informs, it does not perform. - Flat, sharp components...

Color tokens:
- primary: #0067b8
- canvas-light: #ffffff
- surface-soft-light: #f2f2f2
- ink: #000000
- body: #262626
- muted: #616161
- ink-soft: #171717
- on-primary: #ffffff
- on-light: #000000

Typography tokens:
- display-lg: family Segoe UI, -apple-system, BlinkMacSystemFont, sans-serif, size 37px, weight 600, line 1.2, tracking 0
- display-md: family Segoe UI, -apple-system, BlinkMacSystemFont, sans-serif, size 29px, weight 600, line 1.2, tracking 0
- title-md: family Segoe UI, -apple-system, BlinkMacSystemFont, sans-serif, size 24px, weight 600, line 1.3, tracking 0
- body-md: family Segoe UI, -apple-system, BlinkMacSystemFont, sans-serif, size 15px, weight 400, line 1.5, tracking 0
- nav-link: family Segoe UI, -apple-system, BlinkMacSystemFont, sans-serif, size 15px, weight 400, line 1.33, tracking 0
- button: family Segoe UI, -apple-system, BlinkMacSystemFont, sans-serif, size 15px, weight 600, line 1, tracking 0
- caption: family Segoe UI, -apple-system, BlinkMacSystemFont, sans-serif, size 13px, weight 400, line 1.5, tracking 0
- caption-sm: family Segoe UI, -apple-system, BlinkMacSystemFont, sans-serif, size 11px, weight 400, line 1, tracking 0

Spacing tokens:
- xs: 8px
- sm: 16px
- md: 24px
- lg: 32px
- xl: 48px
- xxl: 64px
- section: 48px

Radius and shape tokens:
- none: 0px
- sm: 2px
- pill: 9999px
- full: 9999px

Component tokens:
- button-primary: backgroundColor: {colors.primary}, textColor: {colors.on-primary}, typography: {typography.button}, rounded: {rounded.sm}, padding: 12px 16px
- text-link: backgroundColor: transparent, textColor: {colors.primary}, typography: {typography.body-md}
- product-card: backgroundColor: {colors.canvas-light}, textColor: {colors.body}, typography: {typography.body-md}, rounded: {rounded.none}, padding: 24px
- hero-overlay-card: backgroundColor: {colors.canvas-light}, textColor: {colors.ink}, typography: {typography.display-md}, rounded: {rounded.none}, padding: 48px
- category-icon-link: backgroundColor: transparent, textColor: {colors.primary}, typography: {typography.nav-link}
- top-nav: backgroundColor: {colors.canvas-light}, textColor: {colors.muted}, typography: {typography.nav-link}, padding: 16px 0
- hero-banner: backgroundColor: {colors.primary}, textColor: {colors.on-primary}, typography: {typography.display-lg}, padding: 64px
- feature-band: backgroundColor: {colors.primary}, textColor: {colors.on-primary}, typography: {typography.display-md}, padding: 64px

Color rationale: Brand & Accent - the source brand Blue ({colors.primary} — 0067b8): The single brand color. It carries every primary CTA background, all text links, navigation accents, and interactive icon strokes. It is the system's chromatic authority. the source brand - Canvas Light ({colors.canvas-light} — ffffff): The primary page floor and card the source brand. This pure white creates a clean, showroom-like atmosphere. - the source brand Soft Light ({colors.surface-soft-light} — f2f2f2): A muted mist-gray used exclusively for the site-wide footer background. Text - Ink ({colors.ink} — 000000): Pure black for primary text, hero headlines, and hairline borders. Provides maximum contrast. - Body ({colors.body} — 262626): A slightly softer graphite tone for body copy on cards. - Muted ({colors.muted} — 616161): A steel gray for secondary text, navigation links, and footer copy. - Ink Soft ({colors.ink-soft} — 171717): The darkest neutral before pure black, used for dense text blocks and separators. - On Primary ({colors.on-primary} — ffffff): Pure white text used on blue {component.button-primary} backgrounds for high contrast. - On Light ({colors.on-light} — 000000): Reuses the {colors.ink} t...

Typography rationale: Font Family The system uses Segoe UI exclusively. Its humanist proportions and open apertures give the system a calm, enterprise-confident voice. Weights are strictly limited to 400 (regular) for body/nav and 600 (semibold) for headings/buttons. The fallback stack is -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif. Hierarchy | Token | Size | Weight | Line Height | Use | |---|---|---|---|---| | {typography.display-lg} | 37px | 600 | 1.2 | Main hero banner headlines | | {typography.display-md} | 29px | 600 | 1.2 | Section headings, hero overlay card titles | | {typography.title-md} | 24px | 600 | 1.3 | Product card titles, sub-section headings | | {typography.body-md} | 15px | 400 | 1.5 | Default body text, card descriptions, inline links | | {typography.nav-link} | 15px | 400 | 1.33 | Top navigation links, icon link labels | | {typography.button} | 15px | 600 | 1 | All primary CTA button labels | | {typography.caption} | 13px | 400 | 1.5 | Footer links, back-to-top button | | {typography.caption-sm} | 11px | 400 | 1 | Legal copy in footer | Principles The type system is functional, not decorative. Contrast is achieved through a disciplined use of two weights (400...

Layout system: Spacing System - Base unit: 8px. - Tokens: {spacing.xs} 8px · {spacing.sm} 16px · {spacing.md} 24px · {spacing.lg} 32px · {spacing.xl} 48px · {spacing.xxl} 64px. - Section gap (vertical): {spacing.xl} (48px) separates major content bands. - Card internal padding: {spacing.md} (24px) for product cards; {spacing.xl} (48px) for hero overlay cards. - Gutters: {spacing.sm} (16px) to {spacing.md} (24px) between cards in the 4-column grid. Grid & Container - Max content width: 1200px, centered. - Grid: A rigid 4-column grid is used for all product and content showcases. - Hero structure: Full-bleed hero sections break the container, often featuring a white {component.hero-overlay-card} on one side and a minimal hero staging on the other. Whitespace Philosophy The layout is information-dense but feels breathable due to generous vertical spacing ({spacing.section}) between sections. This prevents the rigid grid from feeling cramped. The system trusts clean alignment and consistent spacing over atmospheric whitespace.

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | Flat | No shadow, no border | Body canvas, top nav, hero banners, footer | | Hairline | 1px {colors.ink} border | {component.product-card} container, back-to-top button | | Card the source brand | {colors.canvas-light} background with drop shadow | The sole elevated component is the {component.product-card}, which uses a subtle shadow to lift off the canvas. | The elevation philosophy is minimal. The system is fundamentally flat, with a single shadow token (rgba(0,0,0,0.13) 0 3px 7px, rgba(0,0,0,0.11) 0 1px 2px) reserved exclusively for product cards in a grid. This gives them a tangible, catalog-like quality without cluttering the UI with layered depth.

Shape language: Border Radius Scale | Token | Value | Use | |---|---|---| | {rounded.none} | 0px | Product cards, hero overlay cards | | {rounded.sm} | 2px | Buttons, inputs, tags | | {rounded.pill} | 9999px | Not used in the core system | | {rounded.full} | 9999px | Avatars (in sign-in state) | Edges are kept sharp and functional. The 2px radius on buttons is just enough to soften the corners without appearing rounded. Product cards are strictly 0px, reinforcing the grid's rectilinear structure. Photography & Iconography - Photography: Product-led. Hero images are either blue-tinted studio renders or atmospheric landscapes. Product card images are tight crops on white backgrounds. - Iconography: Consistently outlined line-art (1.5–2px stroke) in neutral gray or black. Used for category navigation and UI controls (search, cart). The 4-color the source brand logo is the only multi-color mark.

Component language: Buttons & Links button-primary — The only CTA button style. A solid-fill of {colors.primary} with {colors.on-primary} text. Typography is {typography.button} (15px/600), rounded to {rounded.sm}. It's used for all primary actions like 'Shop now' or 'Learn more'. text-link — Inline links used in navigation, card copy, and the footer. No background or border. Text is colored with {colors.primary}. Underline appears on hover. Cards & Containers product-card — The core component for displaying products. A {rounded.none} white card with a 1px {colors.ink} hairline border and a subtle drop shadow. An image sits flush to the top edge, with {spacing.md} of padding around the text block below. hero-overlay-card — A white text card layered over a full-bleed photographic hero. It has a {rounded.none} shape, no border, and generous internal padding ({spacing.xl}). The headline uses {typography.display-md}. hero-banner — Full-width promotional section with a blue-tinted photo or gradient background. Overlaid text is large, white, and uses {typography.display-lg}. feature-band — Similar to a hero banner, a full-width section with a lifestyle photo background and a {component.hero-overlay-card} c...

Guardrails: Do - Use {colors.primary} as the sole chromatic color for all actions, links, and accents. - Keep border-radius at {rounded.sm} (2px) or {rounded.none} (0px). Keep edges sharp. - Apply the card drop shadow only to {component.product-card} elements in a grid. - Use Segoe UI weight 600 for headings and buttons, and 400 for all other text. - Maintain...
```
