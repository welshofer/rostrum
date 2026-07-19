# Azure

**ID:** `azure`  
**Category:** finance  
**Theme:** light  
**Vibe:** Editorial

## Color palette

- `#0052ff`
- `#0a0b0d`
- `#003ecc`
- `#a8b8cc`
- `#5b616e`
- `#7c828a`
- `#a8acb3`
- `#dee1e6`
- `#eef0f3`
- `#ffffff`

## Typography

Families: "'Coinbase Display', -apple-system, system-ui, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif", "'Coinbase Display', sans-serif", "'Coinbase Mono', 'Coinbase Sans', monospace", "'Coinbase Sans', sans-serif". Weights: 400, 500, 600, 700.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Coinbase

Design token description: An institutional-grade dynamic transaction/data-flow pattern exchange whose marketing surfaces read like a quietly-confident financial-services brand. The base canvas is pure white; Coinbase Blue (0052ff) is the single brand voltage, used scarcely on primary CTAs, signature glyphs, and inline accent moments. Type runs Coinbase's licensed CoinbaseDisplay (display) and CoinbaseSans (body) at modest weights — display sits at weight 400 not 700, signaling editorial calm rather than fintech-bombastic. Page rhythm rotates between bright white sections, soft gray elevation bands, and full-bleed dark editorial heroes (0a0b0d) carrying product-ui mockup layered rectangular token motif. Iconography is geometric and minimal; depth comes from card-on-card layering, never decorative shadows.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- Detected source-domain vocabulary: finance/banking, food/hospitality. Translate it into reusable visual behavior, not literal imagery.
- Avoid literal source imagery unless the exact slide text or visual direction explicitly requests it: credit cards, debit cards, bank apps, cash, coins, trading screens, or crypto coins; financial product mockups unless requested by slide content; food photography, dishes, plates, chefs, kitchens, menus, recipes, utensils, or dining scenes.

Overall visual personality: Coinbase reads like an institutional financial brand that happens to trade dynamic transaction/data-flow pattern — the marketing surfaces are quiet, white-canvas, editorially-spaced, and almost monochromatic. The single brand voltage is Coinbase Blue ({colors.primary} — 0052ff), used scarcely: every primary CTA pill, the brand wordmark, and inline emphasis links. Beyond that one blue, the system is white canvas + ink + soft gray elevation bands + a deep near-black editorial canvas ({colors.surface-dark} — 0a0b0d) for full-bleed product-mockup heroes. Type pairs CoinbaseDisplay for hero headlines with CoinbaseSans for body, captions, and navigation. Display sits at weight 400 — not the 700+ typical of dynamic transaction/data-flow pattern platforms. The choice signals editorial calm and institutional trust rather than fintech urgency. The page rhythm rotates three modes: bright white editorial sections, soft-gray elevation bands, and full-bleed dark editorial heroes carrying layered product-UI mockup layered rectangular token motif. The dark hero with floating dashboard mockups is the single most distinctive component. Key Characteristics: - Single accent color: {colors.primary} (0...

Color tokens:
- primary: #0052ff
- primary-active: #003ecc
- primary-disabled: #a8b8cc
- ink: #0a0b0d
- body: #5b616e
- body-strong: #0a0b0d
- muted: #7c828a
- muted-soft: #a8acb3
- hairline: #dee1e6
- hairline-soft: #eef0f3
- canvas: #ffffff
- surface-soft: #f7f7f7
- surface-card: #ffffff
- surface-strong: #eef0f3

Typography tokens:
- display-mega: family 'Coinbase Display', -apple-system, system-ui, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif, size 80px, weight 400, line 1.0, tracking -2px
- display-xl: family 'Coinbase Display', sans-serif, size 64px, weight 400, line 1.0, tracking -1.6px
- display-lg: family 'Coinbase Display', sans-serif, size 52px, weight 400, line 1.0, tracking -1.3px
- display-md: family 'Coinbase Display', sans-serif, size 44px, weight 400, line 1.09, tracking -1px
- display-sm: family 'Coinbase Sans', sans-serif, size 36px, weight 400, line 1.11, tracking -0.5px
- title-lg: family 'Coinbase Sans', sans-serif, size 32px, weight 400, line 1.13, tracking -0.4px
- title-md: family 'Coinbase Sans', sans-serif, size 18px, weight 600, line 1.33, tracking 0
- title-sm: family 'Coinbase Sans', sans-serif, size 16px, weight 600, line 1.25, tracking 0
- body-md: family 'Coinbase Sans', sans-serif, size 16px, weight 400, line 1.5, tracking 0
- body-strong: family 'Coinbase Sans', sans-serif, size 16px, weight 700, line 1.5, tracking 0
- body-sm: family 'Coinbase Sans', sans-serif, size 14px, weight 400, line 1.5, tracking 0
- caption: family 'Coinbase Sans', sans-serif, size 13px, weight 400, line 1.5, tracking 0

Spacing tokens:
- xxs: 4px
- xs: 8px
- sm: 12px
- base: 16px
- md: 20px
- lg: 24px
- xl: 32px
- xxl: 48px
- section: 96px

Radius and shape tokens:
- none: 0px
- xs: 4px
- sm: 8px
- md: 12px
- lg: 16px
- xl: 24px
- pill: 100px
- full: 9999px

Component tokens:
- top-nav-light: backgroundColor: {colors.canvas}, textColor: {colors.ink}, typography: {typography.nav-link}, height: 64px
- top-nav-on-dark: backgroundColor: {colors.surface-dark}, textColor: {colors.on-dark}, typography: {typography.nav-link}, height: 64px
- button-primary: backgroundColor: {colors.primary}, textColor: {colors.on-primary}, typography: {typography.button}, rounded: {rounded.pill}, padding: 12px 20px, height: 44px
- button-primary-active: backgroundColor: {colors.primary-active}, textColor: {colors.on-primary}, rounded: {rounded.pill}
- button-primary-disabled: backgroundColor: {colors.primary-disabled}, textColor: {colors.on-primary}, rounded: {rounded.pill}
- button-secondary-light: backgroundColor: {colors.surface-strong}, textColor: {colors.ink}, typography: {typography.button}, rounded: {rounded.pill}, padding: 12px 20px, height: 44px
- button-secondary-dark: backgroundColor: {colors.surface-dark-elevated}, textColor: {colors.on-dark}, typography: {typography.button}, rounded: {rounded.pill}, padding: 12px 20px, height: 44px
- button-outline-on-dark: backgroundColor: transparent, textColor: {colors.on-dark}, typography: {typography.button}, rounded: {rounded.pill}, padding: 11px 19px, height: 44px

Color rationale: Brand & Accent - Coinbase Blue ({colors.primary} — 0052ff): The single brand color. Every primary CTA pill, the Coinbase wordmark, and inline brand links. - Coinbase Blue Active ({colors.primary-active} — 003ecc): Press-state darken on the primary pill. - Coinbase Blue Disabled ({colors.primary-disabled} — a8b8cc): Faded-blue tint for disabled CTAs. - Accent Yellow ({colors.accent-yellow} — f4b000): A small sub-brand accent used very sparingly on Bitcoin/asset glyph fills inside feature layered rectangular token motif. Illustrative-only, not an action color. Surface - Canvas ({colors.canvas} — ffffff): The default page floor. - Surface Soft ({colors.surface-soft} — f7f7f7): Subtle alternating band surface. - Surface Strong ({colors.surface-strong} — eef0f3): The light-gray fill behind secondary buttons, search pills, asset-icon rounded focal composition. - Surface Dark ({colors.surface-dark} — 0a0b0d): Deep near-black canvas for full-bleed dark heroes, CTA bands. Same hex as {colors.ink} — page-floor and text-color share the value. - Surface Dark Elevated ({colors.surface-dark-elevated} — 16181c): One step lighter, used for floating product-UI mockup layered rectangular token moti...

Typography rationale: Font Family The system runs CoinbaseDisplay (display headlines), CoinbaseSans (body, navigation, captions, buttons), CoinbaseIcons (icon font), and CoinbaseMono for tabular numerical data. Fallback stack: -apple-system, system-ui, "Segoe UI", Roboto, Helvetica, Arial, sans-serif. The display/body split is functional: CoinbaseDisplay carries hero headlines only; CoinbaseSans carries everything else. Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.display-mega} | 80px | 400 | 1.0 | -2px | Homepage hero h1 | | {typography.display-xl} | 64px | 400 | 1.0 | -1.6px | Subsidiary heroes | | {typography.display-lg} | 52px | 400 | 1.0 | -1.3px | Section heads | | {typography.display-md} | 44px | 400 | 1.09 | -1px | CTA-band headlines | | {typography.display-sm} | 36px | 400 | 1.11 | -0.5px | Sub-section heads — CoinbaseSans | | {typography.title-lg} | 32px | 400 | 1.13 | -0.4px | layered rectangular token motif group titles | | {typography.title-md} | 18px | 600 | 1.33 | 0 | Component titles, asset row primary | | {typography.title-sm} | 16px | 600 | 1.25 | 0 | List labels | | {typography.body-md} | 16px | 400 | 1.5 | 0 | Defau...

Layout system: Spacing System - Base unit: 4px. - Tokens: {spacing.xxs} 4px · {spacing.xs} 8px · {spacing.sm} 12px · {spacing.base} 16px · {spacing.md} 20px · {spacing.lg} 24px · {spacing.xl} 32px · {spacing.xxl} 48px · {spacing.section} 96px. - Section padding: {spacing.section} (96px) for every major editorial band. - layered rectangular token motif internal padding: {spacing.xl} (32px) for feature layered rectangular token motif and product-UI mockups. Grid & Container - Max content width: ~1200px centered. Hero photography full-bleed. - Editorial body: Single 12-column grid. - Feature layered rectangular token motif grids: 2-up at desktop for hero splits, 3-up for benefit grids. - Footer: 6-column link list at desktop. Whitespace Philosophy Generous editorial pacing — closer to Bloomberg or the Financial Times than to a dynamic transaction/data-flow pattern dashboard. 96px between bands; layered rectangular token motif inside bands sit 24px apart. Density lives behind login walls, not on marketing.

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | Flat | No shadow, no border | 80% of surfaces | | Hairline border | 1px {colors.hairline} | Feature layered rectangular token motif outlines on white | | Soft drop | 0 4px 12px rgba(0, 0, 0, 0.04) | Single shadow tier — hovered layered rectangular token motif | | Photographic | Full-bleed product-UI mockups | Hero depth | Decorative Depth - Layered product-UI layered rectangular token motif inside dark heroes is the most distinctive decorative pattern — a {component.product-ui-card-dark} floats above a darker base canvas, often with a second smaller layered rectangular token motif overlapping at an angle. - Geometric brand illustrations carry illustrative depth where shadows would otherwise.

Shape language: Border Radius Scale | Token | Value | Use | |---|---|---| | {rounded.none} | 0px | Reserved (essentially unused) | | {rounded.xs} | 4px | Inline tags | | {rounded.sm} | 8px | Compact rows | | {rounded.md} | 12px | Form inputs | | {rounded.lg} | 16px | Mid-size layered rectangular token motif | | {rounded.xl} | 24px | Feature layered rectangular token motif, product-UI mockups, pricing tiers | | {rounded.pill} | 100px | All CTA buttons, search pills, badges | | {rounded.full} | 9999px | Asset icon circles, avatars | Pill for interactive, card-radius (24px) for containers, full circle for icons. Sharp corners absent.

Component language: Top Navigation top-nav-light — Default top nav on white pages. Background {colors.canvas}, text {colors.ink}, height 64px. Layout: Coinbase wordmark left, primary horizontal hospitality-service structure (Cryptocurrencies / Individuals / Businesses / Institutions / Developers / Company), search-icon + globe + Sign In + Sign Up CTAs right. top-nav-on-dark — Top nav over a dark hero band. Background {colors.surface-dark}, text {colors.on-dark}. Same layout. Buttons button-primary — The signature Coinbase Blue pill. Background {colors.primary}, text {colors.on-primary}, type {typography.button} (16px / 600), padding 12px × 20px, height 44px, rounded {rounded.pill} (100px). button-primary-active — Press state. Background {colors.primary-active}, deeper blue. button-primary-disabled — Faded blue tint. Background {colors.primary-disabled}. Cursor not-allowed. button-secondary-light — Soft-gray secondary on white surfaces. Background {colors.surface-strong}, text {colors.ink}, same pill geometry. button-secondary-dark — Used on dark heroes. Background {colors.surface-dar...
```
