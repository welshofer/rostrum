# Indigo

**ID:** `indigo`  
**Category:** consumer  
**Theme:** dark  
**Vibe:** Editorial

## Color palette

- `#cdcbff`
- `#bdbbff`
- `#3a25f5`
- `#001d21`
- `#e0fee6`
- `#68706f`
- `#e1e3e3`
- `#ccd5d6`
- `#1d2a29`
- `#002b31`

## Typography

Families: "'angellist', 'Inter', 'GT America', 'Söhne', sans-serif", "'angellistDisplay', 'GT Sectra', 'Tiempos Headline', 'DM Serif Display', serif". Weights: 400, 500, 600.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: AngelList

Design token description: A dark-first interface system anchored on a near-black teal canvas (001d21), where mint-green serif display type (e0fee6) glows and a single lavender accent (cdcbff) carries all primary actions. Typography is the central feature a custom serif face renders headlines and numerical statements at extreme sizes with tight negative tracking, while a neutral sans-serif handles all UI and body copy. The system is intentionally flat, avoiding drop shadows and using subtle tonal shifts in the dark teal palette for elevation. Pill-shaped radii define all interactive elements, contrasting with sharp 4px corners on content cards, creating a nocturnal, high-contrast aesthetic.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- No dominant source-domain vocabulary was detected, but still avoid copying example subject matter from the design brief.
- Avoid brand logos, product shots, mascot imagery, packaging, buildings, people, or industry-specific objects unless requested by the slide content.

Overall visual personality: The system is a "midnight greenhouse": a dark-first interface anchored on a near-black teal canvas ({colors.canvas-dark} — 001d21). On this void, bioluminescent mint-green serif display type ({colors.body} — e0fee6) glows, and a single, soft lavender ({colors.primary} — cdcbff) blooms as the only point of warm light, reserved for primary CTAs. This creates a nocturnal, private, and confident atmosphere. Typography is the hero. A custom serif display face renders headlines and large numerical statements at extreme sizes (up to 216px) with tight negative tracking, creating a sculptural, editorial quality. A neutral, hardworking sans-serif handles all UI chrome, body copy, and navigation. The system is intentionally flat. There are no drop shadows. Depth is communicated exclusively through subtle tonal shifts in the dark teal palette, with {colors.surface-card-dark} (002b31) sitting just above the {colors.canvas-dark} floor. Full-bleed bands in organic tones like mint ({colors.surface-accent-mint}) and olive ({colors.surface-accent-olive}) interrupt the dark canvas for visual pacing. Shapes are binary: sharp 4px radii for content cards, and soft 9999px pills for all interactive eleme...

Color tokens:
- primary: #cdcbff
- primary-hover: #bdbbff
- accent: #3a25f5
- ink: #001d21
- body: #e0fee6
- body-on-light: #68706f
- muted: #e1e3e3
- muted-on-light: #68706f
- hairline: #ccd5d6
- border-subtle-dark: #1d2a29
- canvas-dark: #001d21
- surface-card-dark: #002b31
- canvas-light: #f1f3f2
- surface-light: #ffffff

Typography tokens:
- hero-display: family 'angellistDisplay', 'GT Sectra', 'Tiempos Headline', 'DM Serif Display', serif, size 216px, weight 400, line 0.9, tracking -10.8px
- display-lg: family 'angellistDisplay', 'GT Sectra', 'Tiempos Headline', 'DM Serif Display', serif, size 112px, weight 400, line 1.0, tracking -4.5px
- display-md: family 'angellistDisplay', 'GT Sectra', 'Tiempos Headline', 'DM Serif Display', serif, size 90px, weight 400, line 1.1, tracking -4.5px
- display-sm: family 'angellistDisplay', 'GT Sectra', 'Tiempos Headline', 'DM Serif Display', serif, size 60px, weight 400, line 1.1, tracking -2.4px
- title-lg: family 'angellistDisplay', 'GT Sectra', 'Tiempos Headline', 'DM Serif Display', serif, size 38px, weight 400, line 1.2, tracking -1.5px
- title-md: family 'angellistDisplay', 'GT Sectra', 'Tiempos Headline', 'DM Serif Display', serif, size 28px, weight 400, line 1.25, tracking -1.1px
- title-sm: family 'angellist', 'Inter', 'GT America', 'Söhne', sans-serif, size 18px, weight 600, line 1.4, tracking -0.01px
- number-display: family 'angellistDisplay', 'GT Sectra', 'Tiempos Headline', 'DM Serif Display', serif, size 216px, weight 400, line 0.9, tracking -10.8px
- body-md: family 'angellist', 'Inter', 'GT America', 'Söhne', sans-serif, size 14px, weight 400, line 1.5, tracking -0.04px
- body-sm: family 'angellist', 'Inter', 'GT America', 'Söhne', sans-serif, size 13px, weight 400, line 1.5, tracking 0
- caption: family 'angellist', 'Inter', 'GT America', 'Söhne', sans-serif, size 11px, weight 400, line 1.5, tracking 0.08px
- button: family 'angellist', 'Inter', 'GT America', 'Söhne', sans-serif, size 14px, weight 500, line 1, tracking 0

Spacing tokens:
- xxs: 4px
- xs: 8px
- sm: 12px
- md: 16px
- lg: 24px
- xl: 32px
- xxl: 48px
- section: 80px

Radius and shape tokens:
- sm: 4px
- pill: 9999px
- full: 9999px

Component tokens:
- button-primary: backgroundColor: {colors.primary}, textColor: {colors.on-primary}, typography: {typography.button}, rounded: {rounded.pill}, padding: 10px 18px
- button-primary-hover: backgroundColor: {colors.primary-hover}
- button-secondary-on-dark: backgroundColor: transparent, textColor: {colors.body}, typography: {typography.button}, rounded: {rounded.pill}, padding: 10px 18px
- button-secondary-on-light: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.button}, rounded: {rounded.pill}
- text-link: backgroundColor: transparent, textColor: {colors.primary}, typography: {typography.body-md}
- top-nav-dark: backgroundColor: {colors.canvas-dark}, textColor: {colors.on-dark}, typography: {typography.nav-link}
- hero-band-dark: backgroundColor: {colors.canvas-dark}, textColor: {colors.on-dark}, typography: {typography.display-md}, padding: 80px 0
- stat-display-band: backgroundColor: {colors.surface-accent-olive}, textColor: {colors.on-accent-olive}, typography: {typography.number-display}, padding: 80px 0

Color rationale: Brand & Accent - Lavender Dawn ({colors.primary} — cdcbff): The single primary action color. Used for filled CTA backgrounds. Its softness provides a warm focal point in the cool, dark interface. - Pale Periwinkle ({colors.primary-hover} — bdbbff): The hover/active state for the primary lavender. - Vivid Iris ({colors.accent} — 3a25f5): A high-saturation violet for sharp accents, like outlined link borders or active-state text. Used very sparingly. Surface Dark mode (default): - Abyssal Teal ({colors.canvas-dark} — 001d21): The base page canvas. The near-black teal void that defines the system's atmosphere. - Deep Reef ({colors.surface-card-dark} — 002b31): The primary elevated surface for cards, secondary buttons, and chips. A subtle step up from the canvas. Break-band surfaces: - Fog Veil ({colors.canvas-light} — f1f3f2): A neutral light gray used for the navigation pill background. - Paper White ({colors.surface-light} — ffffff): The background for content areas within image cards, when text needs to sit on a light ground. - Mint Whisper ({colors.surface-accent-mint} — cdeed3): A light mint wash for full-bleed content bands that break up the dark canvas. - Olive Grove ({colors....

Typography rationale: Font Family The system uses a distinct two-font model to separate editorial voice from UI utility: - Display Serif ('angellistDisplay', 'GT Sectra'): Reserved for hero headlines, section titles, and large numerical statements. Its single weight and extreme negative tracking give it a compressed, sculptural quality. - UI Sans ('angellist', 'Inter'): The primary sans-serif for all UI elements, body copy, navigation, buttons, and micro-copy. It uses tabular figures (tnum, lnum) for financial data alignment. Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.hero-display} | 216px | 400 | 0.9 | -10.8px | Monumental numerical statements on stat bands | | {typography.display-lg} | 112px | 400 | 1.0 | -4.5px | Major display headlines | | {typography.display-md} | 90px | 400 | 1.1 | -4.5px | Hero headlines | | {typography.display-sm} | 60px | 400 | 1.1 | -2.4px | Large section titles | | {typography.title-lg} | 38px | 400 | 1.2 | -1.5px | Section titles | | {typography.title-md} | 28px | 400 | 1.25 | -1.1px | Sub-section titles | | {typography.title-sm} | 18px | 600 | 1.4 | -0.01px | Card titles, small headings (sans-serif) | |...

Layout system: Spacing System - Base unit: 4px. - Tokens: {spacing.xxs} 4px · {spacing.xs} 8px · {spacing.sm} 12px · {spacing.md} 16px · {spacing.lg} 24px · {spacing.xl} 32px · {spacing.xxl} 48px · {spacing.section} 80px. - Section padding (vertical): {spacing.section} (80px) provides a consistent, confident rhythm between all major content blocks. - Card internal padding: {spacing.lg} (24px). - Gutters: {spacing.md} (16px) between elements in a dense list; larger gutters between grid cards. Grid & Container - Max content width: 1280px, centered. - Structure: Content is organized into full-bleed horizontal bands. Within these bands, content typically sits in a centered container, often using 2-column or 4-column grids for feature lists. - Hero: The hero is often purely typographic, with a left-aligned text block on the dark canvas and no backing image. Whitespace Philosophy The system uses generous vertical whitespace ({spacing.section}) to separate its distinct, full-bleed sections. This allows each band (dark hero, dark card grid, light break-band, olive stat-band) to feel like a self-contained chapter. Within components, spacing is comfortable but not extravagant, balancing the need for clari...

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | Flat | No shadow, no border | Body sections, hero bands, full-bleed break bands, footer | | Soft hairline | 1px {colors.hairline} | Section dividers | | Card surface | {colors.surface-card-dark} background on dark canvas | Elevated cards, announcement chips, secondary buttons | The elevation philosophy is strictly flat surfaces with tonal separation. The system actively forbids drop shadows. Depth is communicated solely by the lightness difference between the {colors.canvas-dark} floor and the {colors.surface-card-dark} layer.

Shape language: Border Radius Scale | Token | Value | Use | |---|---|---| | {rounded.sm} | 4px | Content cards, image containers | | {rounded.pill} | 9999px | All interactive elements: buttons, pills, navigation containers, chips | | {rounded.full} | 9999px / 50% | Avatars | The system employs a strict binary radius model. There are no intermediate values like 8px or 12px. This creates a strong contrast between the sharp, architectural feel of content cards and the soft, approachable feel of interactive UI. Photography & Iconography - Imagery is contained within cards with {rounded.sm} corners. - Avatars are cropped into circles using {rounded.full}. - Iconography is minimal and line-based, typically using a color like {colors.body}.

Component language: Buttons button-primary — The primary CTA. A soft lavender ({colors.primary}) pill with dark teal text ({colors.on-primary}). Used sparingly for the most important action in a view. Its warmth makes it a focal point. button-secondary-on-dark — The default CTA on dark surfaces. A transparent pill with a {colors.on-dark-strong} 1px border and {colors.body} (mint) text. button-secondary-on-light — The equivalent CTA for light break-bands. A transparent pill with a {colors.ink} 1px border and {colors.ink} text. announcement-chip — A small pill used for navigational teasers, often above a hero headline. Background {colors.surface-card-dark}, text {colors.on-dark}, with tight padding. Navigation top-nav-dark — A floating, centered navigation pill, not a full-width bar. The container has a {colors.canvas-light} background and {rounded.pill} shape. Links use {typography.nav-link} in {colors.on-dark}. Cards & Containers hero-band-dark — A full-bleed dark band, often with no image. The typography itself is the hero element, using {typography.display-md} set in th...
```
