# Gesso

**ID:** `gesso`  
**Category:** consumer  
**Theme:** light  
**Vibe:** Minimal

## Color palette

- `#0c0c0d`
- `#ffffff`
- `#808080`
- `#e9e9ec`
- `#242629`
- `#1d1d1e`
- `#fbf0ed`
- `#dc94d5`

## Typography

Families: "'Gamma Sans Display', 'Inter', -apple-system, BlinkMacSystemFont, sans-serif". Weights: 300, 400, 600.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Gamma

Design token description: A minimalist, gallery-frame interface built on a pure white canvas (ffffff), where near-black text (0c0c0d) and cool gray hairlines (e9e9ec) create a silent frame for content. The design language is defined by contrast; extreme pill-shaped interactive elements (9999px radius) are juxtaposed with sharp, 4px-radius media containers. Type runs a single neo-grotesque family at very light weights for display (300 weight) and modest weights for body (400) and CTAs (600), reinforcing the quiet, architectural feel. The system is intentionally flat, with no shadows or elevation — separation is achieved through whitespace and hairlines alone, ensuring the UI remains subordinate to the content it presents.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- No dominant source-domain vocabulary was detected, but still avoid copying example subject matter from the design brief.
- Avoid brand logos, product shots, mascot imagery, packaging, buildings, people, or industry-specific objects unless requested by the slide content.

Overall visual personality: The system employs a minimalist, gallery-frame design language. The interface is nearly invisible, built on a pure white canvas ({colors.canvas-light} — ffffff) with near-black text ({colors.body} — 0c0c0d) and cool gray hairlines ({colors.hairline-on-light} — e9e9ec). This achromatic foundation ensures the UI acts as a silent frame, allowing the content to be the sole source of color and visual focus. The core aesthetic is driven by a stark contrast in shape: interactive elements like buttons and inputs are rendered as extreme pills ({rounded.pill}), while all media containers are sharp, 4px-radius rectangles ({rounded.sm}). This juxtaposition creates a clear visual distinction between what is interactive and what is content. A single custom neo-grotesque font, "Gamma Sans Display," is used for all typography. Display sizes use an exceptionally light weight (300) to create a whisper-thin, almost watermark effect, while body copy and metadata use a standard 400 weight. The heaviest weight (600) is reserved exclusively for the primary call-to-action button, giving it unique visual prominence. The system is intentionally flat, with no shadows or layered elevation; separation is achi...

Color tokens:
- primary: #0c0c0d
- on-primary: #ffffff
- canvas-light: #ffffff
- body: #0c0c0d
- muted: #808080
- hairline-on-light: #e9e9ec
- border-strong: #242629
- surface-dark: #1d1d1e
- on-dark: #ffffff
- surface-hover: #e9e9ec
- accent-gradient-start: #fbf0ed
- accent-gradient-end: #dc94d5

Typography tokens:
- hero-display: family 'Gamma Sans Display', 'Inter', -apple-system, BlinkMacSystemFont, sans-serif, size 72px, weight 300, line 1.15, tracking -0.05px
- display-lg: family 'Gamma Sans Display', 'Inter', -apple-system, BlinkMacSystemFont, sans-serif, size 48px, weight 300, line 1.15, tracking -0.02px
- display-md: family 'Gamma Sans Display', 'Inter', -apple-system, BlinkMacSystemFont, sans-serif, size 40px, weight 300, line 1.17, tracking -0.02px
- display-sm: family 'Gamma Sans Display', 'Inter', -apple-system, BlinkMacSystemFont, sans-serif, size 32px, weight 400, line 1.2, tracking -0.01px
- title-lg: family 'Gamma Sans Display', 'Inter', -apple-system, BlinkMacSystemFont, sans-serif, size 24px, weight 600, line 1.25, tracking -0.01px
- title-md: family 'Gamma Sans Display', 'Inter', -apple-system, BlinkMacSystemFont, sans-serif, size 20px, weight 400, line 1.33, tracking -0.005px
- title-sm: family 'Gamma Sans Display', 'Inter', -apple-system, BlinkMacSystemFont, sans-serif, size 18px, weight 400, line 1.33, tracking 0
- body-md: family 'Gamma Sans Display', 'Inter', -apple-system, BlinkMacSystemFont, sans-serif, size 16px, weight 400, line 1.5, tracking 0
- body-sm: family 'Gamma Sans Display', 'Inter', -apple-system, BlinkMacSystemFont, sans-serif, size 14px, weight 400, line 1.43, tracking 0.01px
- caption: family 'Gamma Sans Display', 'Inter', -apple-system, BlinkMacSystemFont, sans-serif, size 12px, weight 400, line 1.43, tracking 0.02px
- button: family 'Gamma Sans Display', 'Inter', -apple-system, BlinkMacSystemFont, sans-serif, size 14px, weight 600, line 1, tracking 0
- nav-link: family 'Gamma Sans Display', 'Inter', -apple-system, BlinkMacSystemFont, sans-serif, size 14px, weight 400, line 1.4, tracking 0

Spacing tokens:
- xxs: 4px
- xs: 8px
- sm: 12px
- md: 16px
- lg: 24px
- xl: 32px
- xxl: 40px
- section: 88px

Radius and shape tokens:
- xs: 2px
- sm: 4px
- md: 8px
- lg: 12px
- xl: 20px
- pill: 9999px
- full: 9999px

Component tokens:
- button-primary: backgroundColor: {colors.primary}, textColor: {colors.on-primary}, typography: {typography.button}, rounded: {rounded.pill}, padding: 9px 20px
- button-secondary: backgroundColor: transparent, textColor: {colors.primary}, typography: {typography.button}, rounded: {rounded.pill}, padding: 8px 16px, border: 1px solid {colors.primary}
- search-input-pill: backgroundColor: {colors.canvas-light}, textColor: {colors.muted}, typography: {typography.body-sm}, rounded: {rounded.pill}, height: 40px, padding: 8px 16px, border: 1px solid {colors.hairline-on-light}
- top-nav: backgroundColor: {colors.canvas-light}, textColor: {colors.body}, typography: {typography.nav-link}, height: 72px, borderBottom: 1px solid {colors.hairline-on-light}
- hero-feature-banner: backgroundColor: transparent, textColor: {colors.body}, typography: {typography.hero-display}, rounded: {rounded.sm}
- media-card-grid: backgroundColor: {colors.canvas-light}, textColor: {colors.body}, typography: {typography.title-sm}, rounded: {rounded.sm}
- numbered-list-item: backgroundColor: transparent, textColor: {colors.body}, typography: {typography.title-sm}
- progress-bar: backgroundColor: {colors.hairline-on-light}, height: 3px

Color rationale: Neutrals The palette is intentionally minimalist and achromatic to serve as a neutral frame. - Primary / Ink Black ({colors.primary} — 0c0c0d): The darkest neutral. Used for primary button backgrounds, high-contrast text, and progress bar fills. - Canvas Light ({colors.canvas-light} — ffffff): The page canvas, card surfaces, and input backgrounds. The gallery wall. - Hairline on Light ({colors.hairline-on-light} — e9e9ec): Hairline borders, subtle dividers, and hover surfaces. - Muted ({colors.muted} — 808080): Muted body text, metadata, inactive icons, and placeholder text. - Border Strong ({colors.border-strong} — 242629): Icon strokes and secondary button borders. - Surface Dark ({colors.surface-dark} — 1d1d1e): A rare dark surface used sparingly for a single featured panel, creating a dark anchor in an otherwise all-white page. - On Primary / On Dark ({colors.on-primary} & {colors.on-dark} — ffffff): Text on dark fills. Accent There is no chromatic accent color. The system's only color is a decorative gradient used as a non-interactive backdrop. - Accent Gradient ({colors.accent-gradient-start} to {colors.accent-gradient-end}): A soft pink-to-magenta gradient wash used exclusi...

Typography rationale: Font Family The system uses a single custom neo-grotesque family, "Gamma Sans Display," for all text, from micro-labels to 72px hero displays. This creates a unified and consistent typographic voice. - Fallback: Inter is the recommended open-source substitute. Hierarchy The typographic scale is wide, ranging from 12px to 72px. Hierarchy is controlled more by size and weight than by color. | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.hero-display} | 72px | 300 | 1.15 | -0.05px | Oversized hero titles, often overlaid directly on media | | {typography.display-lg} | 48px | 300 | 1.15 | -0.02px | Large display headlines | | {typography.display-md} | 40px | 300 | 1.17 | -0.02px | Secondary display headlines | | {typography.display-sm} | 32px | 400 | 1.2 | -0.01px | Section headings | | {typography.title-lg} | 24px | 600 | 1.25 | -0.01px | Emphasized section headers | | {typography.title-md} | 20px | 400 | 1.33 | -0.005px | Card titles, subheadings | | {typography.title-sm} | 18px | 400 | 1.33 | 0 | Smaller card titles | | {typography.body-md} | 16px | 400 | 1.5 | 0 | Body copy in descriptions | | {typography.body-sm} | 14px | 400...

Layout system: Spacing System - Base unit: 4px. - Tokens: {spacing.xxs} 4px · {spacing.xs} 8px · {spacing.sm} 12px · {spacing.md} 16px · {spacing.lg} 24px · {spacing.xl} 32px · {spacing.xxl} 40px · {spacing.section} 88px. - Section padding (vertical): {spacing.section} (88px) is used between major content blocks, creating a generous, unhurried rhythm. - Card internal padding: {spacing.lg} (24px) for the text portion of content cards. - Gutters: {spacing.xl} (32px) between cards in 2-up grids. Grid & Container - Max content width: ~1200px centered, with generous outer gutters. - Page structure: Pages follow a simple stacked structure: a full-bleed hero, followed by a 2-column grid of large cards, which then transitions to a compact single-column list. - No sidebars: The layout is single-column, with no persistent side navigation or utility rails. Whitespace Philosophy The system is built on a "gallery wall" philosophy, where generous whitespace is the primary tool for separation and pacing. The large {spacing.section} value ensures that individual content pieces are framed by negative space, preventing visual clutter and allowing each item to be considered independently.

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | 0 (Canvas) | {colors.canvas-light} background | Page floor, card surfaces | | 1 (Hairline) | 1px {colors.hairline-on-light} border | Top nav separator, list item dividers, input borders | | 2 (Dark Surface) | {colors.surface-dark} background | Rare inverted card surface for a single featured component | | 3 (Primary Action) | {colors.primary} background | The single primary CTA button, the highest-contrast element | The elevation model is deliberately flat. There are no drop shadows, glows, or blurs. Depth is communicated exclusively through 1px hairline borders and the very rare use of an inverted dark surface. This ensures that UI elements feel flush with the canvas, like prints hung on a wall, rather than objects floating in space.

Shape language: Border Radius Scale The shape language is defined by a stark dichotomy between sharp rectangles and soft pills. | Token | Value | Use | |---|---|---| | {rounded.sm} | 4px | All media containers (images, video thumbnails) | | {rounded.md} | 8px | Text-only cards (when they have a visible border or background) | | {rounded.pill} | 9999px | All interactive elements: buttons, inputs, tags | This strict separation is a core principle: content is framed in sharp rectangles, while the controls to interact with it are soft pills. Mixing these is a system violation (e.g., rounding media corners to {rounded.pill}). Iconography Iconography is monochrome line art, rendered with a ~1.5px stroke in {colors.primary} or {colors.border-strong} with no fill. Icons are simple, geometric, and purely functional.

Component language: Top Navigation top-nav — A sticky, full-width bar, 72px tall, with a {colors.canvas-light} background and a 1px {colors.hairline-on-light} bottom border. Contains a pill-shaped {component.search-input-pill} on the left, centered {component.nav-link} text links, and a solid black {component.button-primary} on the right. Buttons button-primary — The single primary action on any given screen. A solid pill with {colors.primary} background and {colors.on-primary} text. Its 600 weight and solid fill make it the most v...
```
