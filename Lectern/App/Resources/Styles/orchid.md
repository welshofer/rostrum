# Orchid

**ID:** `orchid`  
**Category:** consumer  
**Theme:** light  
**Vibe:** Bold

## Color palette

- `#fb00c2`
- `#f4ede9`
- `#000000`
- `#ffffff`
- `#767676`
- `#340068`
- `#d9d9d9`
- `#ff1e00`

## Typography

Families: "Walsheim, -apple-system, BlinkMacSystemFont, sans-serif". Weights: 400, 700, 800, 900.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Transform

Design token description: A theatrical broadside language built on a warm blush cream canvas (f4ede9). Oversized geometric headlines shout in heavy weights, while a limited palette of spotlight magenta (fb00c2), festival violet (340068), and stage orange (ff1e00) are deployed like a punk poster's ink set. The system is intentionally flat and unshadowed; depth comes from full-bleed color blocking, not elevation, making sections read like clipped broadsheets stacked on warm paper. Components are weighty and rectangular (0px radius), with a pill-shaped radius (50px) reserved exclusively for links and interactive chips to signal interactivity.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- Detected source-domain vocabulary: finance/banking. Translate it into reusable visual behavior, not literal imagery.
- Avoid literal source imagery unless the exact slide text or visual direction explicitly requests it: credit cards, debit cards, bank apps, cash, coins, trading screens, or crypto coins; financial product mockups unless requested by slide content.

Overall visual personality: The system uses a theatrical broadside language: a warm blush cream canvas ({colors.canvas} — f4ede9) carries the entire interface. Oversized geometric headlines shout in very heavy weights (700–900). The palette is intentionally limited to three loud accents — spotlight magenta ({colors.primary}), festival violet ({colors.surface-dark}), and stage orange ({colors.accent-orange}) — deployed like a poster printer's ink set, each one earning its place on a flat, unshadowed surface. Depth comes from full-bleed color blocking, not elevation; sections read like clipped broadsheets stacked on warm paper. Components are weighty and strictly rectangular; only links and a few interactive chips receive the {rounded.pill} radius, making them feel like stickers pressed onto the page. Typography does the emotional work: weight 700–900 at 56–80px carries theatrical volume, while tight letter-spacing (-0.02em) keeps the heavy forms from sprawling. The entire mood is confident, typographic, and unapologetically flat. Key Characteristics: - Flat design: No shadows, no gradients, no glows. Depth is created by stacking flat, full-bleed color bands. - Bichromatic radius: A strict {rounded.none} (0px)...

Color tokens:
- primary: #fb00c2
- canvas: #f4ede9
- ink: #000000
- body: #000000
- on-primary: #ffffff
- on-dark: #ffffff
- muted: #767676
- hairline: #767676
- surface-dark: #340068
- surface-card: #ffffff
- surface-card-alt: #d9d9d9
- accent-orange: #ff1e00

Typography tokens:
- hero-display: family Walsheim, -apple-system, BlinkMacSystemFont, sans-serif, size 80px, weight 900, line 1, tracking -1.6px
- display-lg: family Walsheim, -apple-system, BlinkMacSystemFont, sans-serif, size 56px, weight 900, line 1.1, tracking -1.12px
- display-md: family Walsheim, -apple-system, BlinkMacSystemFont, sans-serif, size 40px, weight 800, line 1.2, tracking -0.8px
- title-lg: family Walsheim, -apple-system, BlinkMacSystemFont, sans-serif, size 24px, weight 700, line 1.38, tracking -0.48px
- title-md: family Walsheim, -apple-system, BlinkMacSystemFont, sans-serif, size 22px, weight 700, line 1.38, tracking -0.44px
- body-md: family Walsheim, -apple-system, BlinkMacSystemFont, sans-serif, size 18px, weight 400, line 1.45, tracking -0.36px
- body-sm: family Walsheim, -apple-system, BlinkMacSystemFont, sans-serif, size 16px, weight 400, line 1.45, tracking -0.32px
- button: family Walsheim, -apple-system, BlinkMacSystemFont, sans-serif, size 16px, weight 700, line 1, tracking -0.32px
- nav-link: family Walsheim, -apple-system, BlinkMacSystemFont, sans-serif, size 18px, weight 700, line 1.45, tracking -0.36px

Spacing tokens:
- xs: 8px
- sm: 16px
- md: 24px
- lg: 32px
- xl: 48px
- xxl: 56px
- section: 80px
- section-lg: 120px

Radius and shape tokens:
- none: 0px
- pill: 50px
- full: 50px

Component tokens:
- button-primary: backgroundColor: {colors.primary}, textColor: {colors.on-primary}, typography: {typography.button}, rounded: {rounded.none}, padding: 8px 16px
- button-secondary: backgroundColor: {colors.surface-dark}, textColor: {colors.on-dark}, typography: {typography.button}, rounded: {rounded.none}, padding: 8px 16px
- nav-link: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.nav-link}
- tag-pill: backgroundColor: {colors.canvas}, textColor: {colors.ink}, typography: {typography.button}, rounded: {rounded.pill}, padding: 8px 16px
- top-nav: backgroundColor: {colors.canvas}, textColor: {colors.ink}, typography: {typography.nav-link}, padding: 16px 0
- hero-panel: backgroundColor: transparent, textColor: {colors.on-dark}, typography: {typography.display-lg}
- pull-quote-band: backgroundColor: {colors.surface-dark}, textColor: {colors.primary}, typography: {typography.display-lg}, padding: {spacing.section}
- media-card: backgroundColor: {colors.surface-card}, textColor: {colors.ink}, typography: {typography.title-md}, rounded: {rounded.none}, padding: {spacing.sm}

Color rationale: Brand & Accent - Spotlight Magenta ({colors.primary} — fb00c2): The primary accent. Used for primary CTA backgrounds, pull-quote text, and interactive emphasis. The loudest ink, reserved for moments that demand attention. - Festival Violet ({colors.surface-dark} — 340068): A deep, immersive violet used for full-bleed section bands (e.g., {component.pull-quote-band}, {component.footer}), and secondary filled CTAs. - Curtain Orange ({colors.accent-orange} — ff1e00): A warm tertiary accent used for decorative moments like pull-quote attributions. Never used for interactive elements. Surface - Canvas ({colors.canvas} — f4ede9): The dominant page background. A warm, off-white that feels like paper dynamic transaction/data-flow pattern. - Surface layered rectangular token motif ({colors.surface-card} — ffffff): The primary surface for content layered rectangular token motif, giving a clean contrast against the warm canvas. - Surface layered rectangular token motif Alt ({colors.surface-card-alt} — d9d9d9): An alternate gray layered rectangular token motif surface used when a quieter neutral block is needed. Text - Ink ({colors.ink} — 000000): Primary text color for all content on light s...

Typography rationale: Font Family The system relies exclusively on a single geometric sans-serif font family, Walsheim. Its broad weight range (400–900) carries the entire tonal system. The fallback stack is -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif. If Walsheim is unavailable, Plus Jakarta Sans or Inter are suitable open-source substitutes. Hierarchy Headlines are always heavyweight (700-900) and tightly tracked. Body copy runs at a standard weight (400) with a generous line-height for readability. | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.hero-display} | 80px | 900 | 1 | -1.6px | Top-level hero headlines | | {typography.display-lg} | 56px | 900 | 1.1 | -1.12px | Major section heads, pull-quotes | | {typography.display-md} | 40px | 800 | 1.2 | -0.8px | Sub-section display heads | | {typography.title-lg} | 24px | 700 | 1.38 | -0.48px | layered rectangular token motif titles, smaller headings | | {typography.title-md} | 22px | 700 | 1.38 | -0.44px | Subheadings, meta-labels | | {typography.body-md} | 18px | 400 | 1.45 | -0.36px | Default running text | | {typography.body-sm} | 16px | 400 | 1.45 | -0.32px | Input fields,...

Layout system: Spacing System - Base unit: 8px. - Tokens: {spacing.xs} 8px · {spacing.sm} 16px · {spacing.md} 24px · {spacing.lg} 32px · {spacing.xl} 48px · {spacing.xxl} 56px · {spacing.section} 80px · {spacing.section-lg} 120px. - Section padding (vertical): {spacing.section} (80px) provides generous breathing room between major content bands. - layered rectangular token motif internal padding: {spacing.sm} (16px). - Gutters: {spacing.sm} (16px) between layered rectangular token motif in grid layouts. Grid & Container - Max content width: 1200px, centered. - Layout model: Full-bleed sections stack vertically. Within each section, a centered container holds the content. - Grids: Editorial content grids typically use 4 columns on desktop, wrapping to 2 on tablet and 1 on mobile. Whitespace Philosophy The system uses generous whitespace between sections to let the heavy typography and bold color blocks breathe. The {colors.canvas} acts as the primary whitespace, making the page feel open despite the density of the typographic elements.

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | Flat | No shadow, no border | The default for all elements: body sections, layered rectangular token motif, buttons, nav | | Color Band | Full-bleed {colors.surface-dark} or accent color background | Used to create "depth" by stacking flat colored surfaces (e.g., hero, footer) | | Hairline | 1px {colors.hairline} border | Input fields, decorative dividers | | Focus | 2px {colors.ink} border | Input field focus state | The elevation philosophy is strictly flat. There are no shadows, glows, or blurs. Depth is achieved entirely through the layering of flat, colored surfaces, like pieces of paper on a desk.

Shape language: Border Radius Scale The system uses a strict binary approach to corner rounding. This is a core design rule. | Token | Value | Use | |---|---|---| | {rounded.none} | 0px | Default for all container elements: layered rectangular token motif, buttons, inputs, images | | {rounded.pill} | 50px | Exclusively for interactive chips, tags, and some inline links | | {rounded.full} | 50px | Alias for {rounded.pill} | The contrast between sharp rectangles and soft pills is intentional. Rectangles are for static content containers; pills are for interactive, filter-like elements. Iconography - Icons are minimal and stroke-based. - Outlined glyphs with a 1.5–2px stroke in {colors.ink} on light surfaces or {colors.on-dark} on dark surfaces. - No fill color is used.

Component language: Top Navigation top-nav — A full-bleed bar using the {colors.canvas} background. It sits flat at the top of the page with no shadow or border. Contains primary navigation links on the left/center, with a {component.button-primary} and outlined social icons on the right. Buttons button-primary — The main call-to-action. A solid, rectangular button with a {colors.primary} background and {colors.on-primary} text. Uses {typography.button} (often uppercased) and has {rounded.none}. button-secondary — A lower-priority filled button. Same shape and typography as the primary button, but uses a {colors.surface-dark} background with {colors.on-dark} text. tag-pill — An interactive chip used for tags, categories, or filters. It is the only component to use {rounded.pill}. It typically has a {colors.canvas} background with a 1px {colors.ink} border. layered rectangular token motif & Containers hero-panel — The above-the-fold introduction. Typically a full-bleed media background with a dark overlay, carrying a {typography.hero-display} or {typography.display-lg} headline in {colors.on-dark}. pull-quote-band — A full-bleed editorial band with a {colors.surface-dark} background. It features a lar...

Guardrails: Do - Use heavy weights (700–900) for all headings. The system's voice is bold and typographic. - Adhere to the strict radius dichotomy: {rounded.none} for containers, {rounded.pill} for interactive chips. - Use negative letter-spacing on all type to maintain a dense, blocky feel. - Build layouts from full-bleed color bands to create depth. - Reserve {colors.primary} (magenta) for prim...
```
