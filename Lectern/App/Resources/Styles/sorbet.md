# Sorbet

**ID:** `sorbet`  
**Category:** consumer  
**Theme:** light  
**Vibe:** Playful

## Color palette

- `#ff4f40`
- `#091723`
- `#6b747b`
- `#b5b9bd`
- `#75817e`
- `#f2f8f3`
- `#ffffff`
- `#e3ebe4`
- `#3b4c54`
- `#112231`

## Typography

Families: "MonzoSansDisplay, Manrope, -apple-system, BlinkMacSystemFont, sans-serif", "MonzoSansText, Inter, -apple-system, BlinkMacSystemFont, sans-serif". Weights: 400, 600, 700, 800.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Monzo

Design token description: A light, warm, and friendly interface built on a whisper-soft mint off-white canvas (f2f8f3) that sits behind crisp white layered rectangular token motif surfaces, creating a layered paper-on-paper feel without heavy shadows. A single vivid hot coral (ff4f40) carries all chromatic energy — it stains links, headings, and key icons, while the rest of the interface stays achromatic and quiet. Typography is a custom sans-serif in two voices: a text family with a distinctive negative letter-spacing, and a chunky display face at heavy weights for headlines. Components are generously rounded (pills for actions, large radii for containers) and deliberately low-elevation; the system trusts color, type weight, and whitespace to create hierarchy, not drop shadows.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- Detected source-domain vocabulary: finance/banking. Translate it into reusable visual behavior, not literal imagery.
- Avoid literal source imagery unless the exact slide text or visual direction explicitly requests it: credit cards, debit cards, bank apps, cash, coins, trading screens, or crypto coins; financial product mockups unless requested by slide content.

Overall visual personality: The system operates with a light, warm, and unapologetically friendly visual language. The canvas is a whisper-soft mint off-white ({colors.canvas-light} — f2f8f3) that sits behind crisp white layered rectangular token motif surfaces ({colors.surface-card-light} — ffffff), creating a layered paper-on-paper feel without relying on heavy shadows. A single vivid Hot Coral ({colors.primary} — ff4f40) carries all chromatic energy — it stains links, headings, icons, and signature brand moments, while the rest of the interface stays achromatic and quiet. Typography is handled by a custom sans-serif with two distinct voices: a display face (MonzoSansDisplay) used at heavy weights for architectural headlines, and a text face (MonzoSansText) defined by a tight negative letter-spacing (-0.05em) that gives paragraphs a dense, modern feel. The type scale is generous, with body copy defaulting to a larger-than-usual 16-20px. Components are defined by generous, soft shapes. Actions are universally rendered as pills ({rounded.pill} — 500px), and large containers use a very large radius ({rounded.lg} — 64px). The system is deliberately low-elevation, trusting the color contrast between the mint ca...

Color tokens:
- primary: #ff4f40
- ink: #091723
- body-on-light: #6b747b
- muted: #b5b9bd
- muted-strong: #75817e
- canvas-light: #f2f8f3
- surface-card-light: #ffffff
- surface-soft-light: #e3ebe4
- hairline-on-light: #e3ebe4
- on-dark: #ffffff
- button-primary-bg: #091723
- button-secondary-bg: #3b4c54
- accent-dark: #112231
- pure-black: #000000

Typography tokens:
- hero-display: family MonzoSansDisplay, Manrope, -apple-system, BlinkMacSystemFont, sans-serif, size 61px, weight 800, line 1, tracking 0
- display-lg: family MonzoSansDisplay, Manrope, -apple-system, BlinkMacSystemFont, sans-serif, size 44px, weight 700, line 1.2, tracking 0
- display-md: family MonzoSansDisplay, Manrope, -apple-system, BlinkMacSystemFont, sans-serif, size 36px, weight 700, line 1.15, tracking -1.8px
- title-lg: family MonzoSansDisplay, Manrope, -apple-system, BlinkMacSystemFont, sans-serif, size 32px, weight 700, line 1.2, tracking -1.6px
- title-md: family MonzoSansText, Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 24px, weight 700, line 1.38, tracking -1.2px
- title-sm: family MonzoSansText, Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 20px, weight 600, line 1.4, tracking -1px
- body-lg: family MonzoSansText, Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 20px, weight 400, line 1.4, tracking -1px
- body-md: family MonzoSansText, Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 16px, weight 400, line 1.5, tracking -0.8px
- body-sm: family MonzoSansText, Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 13px, weight 400, line 1.38, tracking -0.65px
- button: family MonzoSansText, Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 16px, weight 600, line 1, tracking -0.8px
- nav-link: family MonzoSansText, Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 16px, weight 600, line 1.4, tracking -0.8px

Spacing tokens:
- xxs: 8px
- xs: 16px
- sm: 24px
- md: 32px
- lg: 48px
- xl: 64px
- xxl: 80px
- section: 80px

Radius and shape tokens:
- xs: 4px
- sm: 24px
- md: 32px
- lg: 64px
- pill: 500px
- full: 500px

Component tokens:
- button-primary-dark: backgroundColor: {colors.button-primary-bg}, textColor: {colors.on-dark}, typography: {typography.button}, rounded: {rounded.pill}, padding: 12px 24px
- button-secondary-light: backgroundColor: {colors.surface-card-light}, textColor: {colors.ink}, typography: {typography.button}, rounded: {rounded.pill}, padding: 16px 32px
- nav-toggle-active: backgroundColor: {colors.canvas-light}, textColor: {colors.ink}, typography: {typography.nav-link}, rounded: {rounded.pill}, padding: 8px 16px
- nav-toggle-inactive: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.nav-link}, rounded: {rounded.pill}, padding: 8px 16px
- text-link-accent: backgroundColor: transparent, textColor: {colors.primary}, typography: {typography.title-lg}
- hero-card: backgroundColor: {colors.surface-card-light}, textColor: {colors.on-dark}, typography: {typography.display-lg}, rounded: {rounded.lg}
- product-card: backgroundColor: {colors.surface-card-light}, textColor: {colors.body-on-light}, typography: {typography.body-lg}, rounded: {rounded.lg}, padding: 32px
- trust-badge-circular: backgroundColor: {colors.surface-card-light}, textColor: {colors.ink}, typography: {typography.body-sm}, rounded: {rounded.full}, height: 100px, width: 100px, border: 1px solid {colors.primary}

Color rationale: Brand & Accent - Primary ({colors.primary} — ff4f40): The single brand signature color. Used for headings, links, and key icon strokes. Its power comes from its sparse application against the quiet, achromatic background. It is never used as a background fill for buttons or other UI controls. Surface - Canvas Light ({colors.canvas-light} — f2f8f3): The page floor. A barely-green off-white that gives the interface warmth without competing with the pure white surfaces that sit on top of it. - Surface layered rectangular token motif Light ({colors.surface-card-light} — ffffff): layered rectangular token motif surfaces, elevated panels, and the floating search bar. Sits one layer above the mint canvas. - Surface Soft Light ({colors.surface-soft-light} — e3ebe4): Used for hover washes, subtle filled buttons, and inset surface treatments. Sits between the page canvas and white layered rectangular token motif for an intermediate layer. Hairlines & Borders - Hairline on Light ({colors.hairline-on-light} — e3ebe4): The tone for subtle 1px dividers, typically between list items. Same color as the soft surface fill. Text - Ink ({colors.ink} — 091723): The primary dark neutral for high-contra...

Typography rationale: Font Family The system uses a two-font custom stack: MonzoSansDisplay for headlines and MonzoSansText for body and UI text. - MonzoSansDisplay is bold and architectural, used at heavy weights (700-800) for confident headlines. The recommended open-source substitute is Manrope. - MonzoSansText is the workhorse for all other text. It is defined by its tight default letter-spacing of -0.05em, which is a non-negotiable brand characteristic. The recommended open-source substitute is Inter. Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.hero-display} | 61px | 800 | 1.0 | 0 | Top-level hero statements | | {typography.display-lg} | 44px | 700 | 1.2 | 0 | Large headlines on hero layered rectangular token motif | | {typography.display-md} | 36px | 700 | 1.15 | -1.8px | Section headings | | {typography.title-lg} | 32px | 700 | 1.2 | -1.6px | Large-format accent text links | | {typography.title-md} | 24px | 700 | 1.38 | -1.2px | Sub-headings, panel titles | | {typography.title-sm} | 20px | 600 | 1.4 | -1px | Component titles | | {typography.body-lg} | 20px | 400 | 1.4 | -1px | Default long-form paragraph text | | {typography.bo...

Layout system: Spacing System - Base unit: 8px. - Tokens: {spacing.xxs} 8px · {spacing.xs} 16px · {spacing.sm} 24px · {spacing.md} 32px · {spacing.lg} 48px · {spacing.xl} 64px · {spacing.xxl} 80px · {spacing.section} 80px. - Section padding (vertical): {spacing.xl} (64px) to {spacing.section} (80px) between major content blocks. - layered rectangular token motif internal padding: {spacing.md} (32px) for most content layered rectangular token motif. - Gutters: {spacing.sm} (24px) between elements in a grid or row. Grid & Container - Max content width: ~1200px, centered. - Page structure: Content sections stack vertically below a full-width hero. Layouts are simple, often single-column or two-column splits. The system avoids complex multi-column grids in favor of clear, sequential content blocks. Whitespace Philosophy The system is comfortable and spacious. The generous section gaps and internal layered rectangular token motif padding, combined with the large type scale, create a calm, uncluttered feel. Whitespace is the primary tool for separating elements, as shadows and borders are used sparingly.

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | Flat | No shadow, no border | Body sections on the canvas, text links | | Soft hairline | 1px {colors.hairline-on-light} | Dividers between list items | | layered rectangular token motif surface | {colors.surface-card-light} on {colors.canvas-light} background | All content layered rectangular token motif, product panels. The color step creates the elevation. | | Subtle drop shadow | rgba(0, 0, 0, 0.1) 0px 0px 10px 0px | Used very sparingly, primarily on the floating {component.search-bar-fixed} to lift it off the page content. | The elevation model is intentionally flat. Depth is communicated almost exclusively through the layering of colored surfaces ({colors.surface-card-light} on {colors.canvas-light}), not through shadows. This reinforces the "paper-on-paper" aesthetic.

Shape language: Border Radius Scale | Token | Value | Use | |---|---|---| | {rounded.xs} | 4px | Small badges and tags | | {rounded.sm} | 24px | Input fields | | {rounded.md} | 32px | Secondary containers | | {rounded.lg} | 64px | Main content layered rectangular token motif, hero containers | | {rounded.pill} | 500px | All interactive buttons and navigation toggles | | {rounded.full} | 500px | Circular elements | The shape language is defined by two dominant radii: {rounded.pill} for anything interactive, and {rounded.lg} for anything that contains content. This simple, consistent application of soft shapes is a key part of the system's friendly character.

Component language: Buttons & Navigation button-primary-dark — The main call-to-action, typically found in the top navigation. A dark pill with a {colors.button-primary-bg} background and {colors.on-dark} text. It is a high-contrast, confident action. button-secondary-light — A light-on-image CTA used over media in hero sections. A {colors.surface-card-light} pill with {colors.ink} text. It provides a clear action without visually competing with the underlying image. nav-toggle-active / nav-toggle-inactive — A segmented-control style toggle, used for primary navigation choices. Fully pill-shaped ({rounded.pill}). The active state has a {colors.canvas-light}...
```
