# Vermilion

**ID:** `vermilion`  
**Category:** automotive  
**Theme:** dark  
**Vibe:** Editorial

## Color palette

- `#181818`
- `#da291c`
- `#b01e0a`
- `#9d2211`
- `#ffffff`
- `#969696`
- `#666666`
- `#8f8f8f`
- `#303030`
- `#d2d2d2`

## Typography

Families: "'FerrariSans', -apple-system, system-ui, sans-serif", "'FerrariSans', sans-serif". Weights: 400, 500, 600, 700.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Ferrari

Design token description: A luxury-automotive brand whose marketing surfaces read as cinematic editorial. The base canvas is near-black (181818) holding pure white display type; white-canvas bands appear only inside specific editorial contexts (preowned listings, pricing tables). The single brand voltage is Rosso Corsa (da291c) — the iconic the source brand high-performance technical movement red — used scarcely on primary CTAs, the Cavallino mark, and Formula 1 race-position highlights. Type runs FerrariSans at modest weights (display 500, body 400) — never bombastic. Spacing follows an explicit 8px token ladder (xxxs 4px through super 128px); generous editorial pacing throughout. The brand's strongest visual signature is the full-bleed cinematic hero photograph that fills the viewport top with engineered subject matter photography, model details, or trackside livery — followed by a tighter editorial body layou...

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- Detected source-domain vocabulary: automotive/performance. Translate it into reusable visual behavior, not literal imagery.
- Avoid literal source imagery unless the exact slide text or visual direction explicitly requests it: cars or vehicle product shots; roads, racetracks, or driving scenes; wheels, tires, grilles, headlights, engines, cockpits, or drivers.

Overall visual personality: the source brand's marketing site reads as cinematic editorial — closer to a luxury-magazine spread than a typical car-OEM site. The base canvas is near-black ({colors.canvas} — 181818) holding pure white display type; white-canvas bands appear only inside specific editorial contexts (preowned listings, pricing tables, dealer surfaces). The single brand voltage is Rosso Corsa ({colors.primary} — da291c), the iconic the source brand high-performance technical movement red, used scarcely on primary CTAs, the Cavallino mark, and Formula 1 race-position highlights. Type runs FerrariSans as the single sans family at modest weights — display 500, body 400. CTA labels render in uppercase with generous tracking (1.1-1.4px). The brand never uses bold display copy. The brand's strongest visual signature is the full-bleed cinematic hero photograph — top-of-page imagery shows engineered subject matter photography, model details, or trackside livery without any chrome competing with it. Headlines float over the bottom of the photo or sit in a tight band beneath. Spacing follows the explicit 8px token ladder: xxxs 4 / xxs 8 / xs 16 / sm 24 / md 32 / lg 48 / xl 64 / xxl 96 / super 128. Key Chara...

Color tokens:
- primary: #da291c
- primary-active: #b01e0a
- primary-hover: #9d2211
- ink: #ffffff
- body: #969696
- body-strong: #ffffff
- body-on-light: #181818
- muted: #666666
- muted-soft: #8f8f8f
- hairline: #303030
- hairline-on-light: #d2d2d2
- hairline-soft: #ebebeb
- canvas: #181818
- canvas-elevated: #303030

Typography tokens:
- display-mega: family 'FerrariSans', -apple-system, system-ui, sans-serif, size 80px, weight 500, line 1.05, tracking -1.6px
- display-xl: family 'FerrariSans', sans-serif, size 56px, weight 500, line 1.1, tracking -1.12px
- display-lg: family 'FerrariSans', sans-serif, size 36px, weight 500, line 1.2, tracking -0.36px
- display-md: family 'FerrariSans', sans-serif, size 26px, weight 500, line 1.5, tracking 0.195px
- title-md: family 'FerrariSans', sans-serif, size 18px, weight 700, line 1.2, tracking 0
- title-sm: family 'FerrariSans', sans-serif, size 16px, weight 500, line 1.4, tracking 0.08px
- body-md: family 'FerrariSans', sans-serif, size 14px, weight 400, line 1.5, tracking 0
- body-sm: family 'FerrariSans', sans-serif, size 13px, weight 400, line 1.5, tracking 0
- caption: family 'FerrariSans', sans-serif, size 12px, weight 400, line 1.4, tracking 0
- caption-uppercase: family 'FerrariSans', sans-serif, size 11px, weight 600, line 1.4, tracking 1.1px
- button: family 'FerrariSans', sans-serif, size 14px, weight 700, line 1.0, tracking 1.4px
- nav-link: family 'FerrariSans', sans-serif, size 13px, weight 600, line 1.4, tracking 0.65px

Spacing tokens:
- xxxs: 4px
- xxs: 8px
- xs: 16px
- sm: 24px
- md: 32px
- lg: 48px
- xl: 64px
- xxl: 96px
- super: 128px

Radius and shape tokens:
- none: 0px
- xs: 2px
- sm: 4px
- md: 6px
- lg: 8px
- xl: 12px
- full: 9999px

Component tokens:
- top-nav-on-dark: backgroundColor: {colors.canvas}, textColor: {colors.ink}, typography: {typography.nav-link}, height: 64px
- top-nav-on-light: backgroundColor: {colors.canvas-light}, textColor: {colors.body-on-light}, typography: {typography.nav-link}, height: 64px
- button-primary: backgroundColor: {colors.primary}, textColor: {colors.on-primary}, typography: {typography.button}, rounded: {rounded.none}, padding: 14px 32px, height: 48px
- button-primary-active: backgroundColor: {colors.primary-active}, textColor: {colors.on-primary}, rounded: {rounded.none}
- button-outline-on-dark: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.button}, rounded: {rounded.none}, padding: 13px 31px, height: 48px
- button-outline-on-light: backgroundColor: transparent, textColor: {colors.body-on-light}, typography: {typography.button}, rounded: {rounded.none}, padding: 13px 31px, height: 48px
- button-tertiary-text: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.button}
- hero-band-cinema: backgroundColor: {colors.canvas}, textColor: {colors.ink}, typography: {typography.display-mega}, padding: 0

Color rationale: Brand & Accent - Rosso Corsa ({colors.primary} — da291c): The iconic the source brand high-performance technical movement red. Primary CTA fill, Cavallino mark, F1 driver-position highlights. Used scarcely. - Rosso Corsa Active ({colors.primary-active} — b01e0a): Press state. - Rosso Corsa Hover-darker ({colors.primary-hover} — 9d2211): Documented for completeness; per the no-hover policy this is not used in preview HTML. - Hypersail Yellow ({colors.accent-yellow-hypersail} — fff200) + Yellow ({colors.accent-yellow} — f6e500): Sub-brand accents reserved for the Hypersail sailing program and the global focus-ring color. Not part of the main high-performance technical movement palette. Surface - Canvas ({colors.canvas} — 181818): Near-black page floor — never pure black, slight warmth. - Canvas Elevated ({colors.canvas-elevated} — 303030): Cards and panels on dark canvas. - Canvas Light ({colors.canvas-light} — ffffff): White editorial bands (preowned listings, pricing). - Surface Card ({colors.surface-card} — 303030): Same as canvas-elevated — operator-control interface cards, livery photo plates. - Surface Soft Light ({colors.surface-soft-light} — f7f7f7): Light editorial alternat...

Typography rationale: Font Family FerrariSans is the licensed single sans family across every text role. Fallback: -apple-system, system-ui, sans-serif. No display/body family split. Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.display-mega} | 80px | 500 | 1.05 | -1.6px | Homepage hero h1 | | {typography.display-xl} | 56px | 500 | 1.1 | -1.12px | Subsidiary heroes | | {typography.display-lg} | 36px | 500 | 1.2 | -0.36px | Section heads, livery band | | {typography.display-md} | 26px | 500 | 1.5 | 0.195px | Sub-section heads | | {typography.title-md} | 18px | 700 | 1.2 | 0 | Component titles | | {typography.title-sm} | 16px | 500 | 1.4 | 0.08px | List labels | | {typography.body-md} | 14px | 400 | 1.5 | 0 | Default body | | {typography.body-sm} | 13px | 400 | 1.5 | 0 | Footer body | | {typography.caption} | 12px | 400 | 1.4 | 0 | Photo captions | | {typography.caption-uppercase} | 11px | 600 | 1.4 | 1.1px | Section labels, badges | | {typography.button} | 14px | 700 | 1.0 | 1.4px (uppercase) | CTA pill labels | | {typography.nav-link} | 13px | 600 | 1.4 | 0.65px (uppercase) | Top-nav menu items | | {typography.number-display} | 80px | 7...

Layout system: Spacing System - Base unit: 4px. - Tokens: {spacing.xxxs} 4px · {spacing.xxs} 8px · {spacing.xs} 16px · {spacing.sm} 24px · {spacing.md} 32px · {spacing.lg} 48px · {spacing.xl} 64px · {spacing.xxl} 96px · {spacing.super} 128px. - Section padding: {spacing.xxl} (96px) for major bands; {spacing.super} (128px) reserved for hero band depth. Grid & Container - Max content width: ~1280px on editorial bands. Hero photography goes full-bleed. - Editorial body: 12-column grid. - Feature card grids: 2-up at desktop for hero splits, 3-up for benefit grids, 4-up for preowned listing tiles. - Footer: 5-column at desktop. Whitespace Philosophy Generous editorial pacing. Cinematic hero photography occupies generous viewport real-estate; body sections sit in tighter editorial layouts beneath. The canvas-light editorial bands (preowned, pricing) carry tighter density than the dark cinema bands.

Depth and hierarchy: The system uses photographic depth + brightness-step elevation. No drop shadows except a single soft-small {shadow.small} documented in extracted tokens. | Level | Treatment | Use | |---|---|---| | Flat (canvas) | {colors.canvas} (181818) | Body bands, footer | | Card | {colors.canvas-elevated} (303030) | operator-control interface cards, livery plates | | Light band | {colors.canvas-light} (ffffff) | Preowned listings, pricing | | Hairline border | 1px {colors.hairline} or {colors.hairline-on-light} | Card outlines, dividers | | Soft drop | 0 4px 8px rgba(0,0,0,0.1) | Hovered cards (single shadow tier) | | Photographic | Full-bleed cinema imagery | Hero band, livery photographs | Decorative Depth - Full-bleed cinema photography is the brand's primary depth treatment. - Brand red gradient (linear-gradient(180deg, a00c01, da291c 64%)): The Rosso Corsa gradient used inside accent bands and CTA hover states. - Dark grey gradient (linear-gradient(180deg, 3c3c3c, 030303 64%)): Atmospheric darken used at section transitions.

Shape language: Border Radius Scale | Token | Value | Use | |---|---|---| | {rounded.none} | 0px | Every CTA, card, band — dominant radius | | {rounded.xs} | 2px | Tight badges (rare) | | {rounded.sm} | 4px | Form inputs | | {rounded.md} | 6px | Compact cards (rare) | | {rounded.lg} | 8px | Mobile-only collapse cards | | {rounded.xl} | 12px | Modal/dialog corners (rare) | | {rounded.full} | 9999px | Avatar plates, badge pills | The radius vocabulary is sharp by default. Sharp 0px corners are the brand button shape — never rounded pills. Pill geometry is reserved for badge labels only.

Component language: Top Navigation top-nav-on-dark — Default top nav on dark hero pages. Background {colors.canvas}, text {colors.ink}, height 64px. Layout: Cavallino mark left, primary horizontal menu (Models / F1 / Lifestyle / Owners / Preowned), language picker + utilities right. Menu items render uppercase with 0.65px tracking. top-nav-on-light — White-canvas variant for editorial light bands. Buttons button-primary — The signature Rosso Corsa CTA. Background {colors.primary}, text {colors.on-primary}, type {typography.button} (14px / 700 / 1.4px tracking, uppercase), padding 14px × 32px, height 48px, rounded {rounded.none} (0px — sharp corners). button-primary-active — Press state. Background {colors.primary-active}. button-outline-on-dark — Transparent with 1px white border. Background transparent, text {colors.ink}, 1px white border, same sharp 0px corners. button-outline-on-light — Transparent with 1px ink border on light bands. button-tertiary-text — Inline text link, uppercase tracking. Hero Bands hero-band-cinema — Full-bleed cinematic photograph. Background {colors.canvas} underneath, but the ph...
```
