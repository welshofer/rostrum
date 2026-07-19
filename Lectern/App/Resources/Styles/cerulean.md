# Cerulean

**ID:** `cerulean`  
**Category:** developer  
**Theme:** dark  
**Vibe:** Bold

## Color palette

- `#0099ff`
- `#ffffff`
- `#000000`
- `#999999`
- `#090909`
- `#141414`
- `#1c1c1c`
- `#262626`
- `#1a1a1a`
- `#d44df0`

## Typography

Families: GT Walsheim Framer Medium, GT Walsheim Medium, Inter, Inter Variable. Weights: 400, 500, 700.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Framer

Design token description: A confident dark-canvas builder marketing site that treats the page like a working artboard — pure black surfaces, white display type set in GT Walsheim Medium with aggressive negative tracking, and a single confident blue (0099ff) reserved for hyperlinks and selection states. The page rhythm is broken by oversized vibrant gradient atmosphere panels — magenta, violet, orange spotlights — that act as living showcase tiles, not decoration. Every CTA is a white pill on dark; every layered rectangular token motif is a translucent or charcoal surface; every section title pulls letter-spacing tight enough to feel like a poster.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- Detected source-domain vocabulary: search/productivity software, finance/banking. Translate it into reusable visual behavior, not literal imagery.
- Avoid literal source imagery unless the exact slide text or visual direction explicitly requests it: search bars, search result pages, browser chrome, or app screenshots; product logos, app icons, map pins, or play-button branding; credit cards, debit cards, bank apps, cash, coins, trading screens, or crypto coins; financial product mockups unless requested by slide content.

Overall visual personality: Framer's marketing canvas is a near-pure black artboard. The dominant surface is {colors.canvas} — almost pure black with a faint warmth — and on top of it sits oversized white display type set in GT Walsheim Medium with letter-spacing pulled to extreme negative values (-5.5px on the 110px display, -4.25px on the 85px hero). The page reads like a poster: one assertive statement per band, generous breathing room above and below. The single accent is {colors.accent-blue} — used scarcely, mostly for hyperlinks, selection halos, and a subtle blue-tinted shadow ring on focused inputs. The brand the source brand itself is monochrome: white pill buttons, charcoal layered rectangular token motif, gray secondary text. What makes Framer distinctive is the rhythm break — every few sections the page drops in a vibrant gradient atmosphere layered rectangular token motif: a magenta-violet spotlight, a sunset-orange wash, a coral-pink panel. These aren't section backgrounds; they're individual layered rectangular token motif arranged in a layered rectangular token motif grid, each one a small living poster that shows what Framer can produce. Body type is Inter Variable, with Framer leaning hard...

Color tokens:
- primary: #ffffff
- on-primary: #000000
- accent-blue: #0099ff
- ink: #ffffff
- ink-muted: #999999
- canvas: #090909
- surface-1: #141414
- surface-2: #1c1c1c
- hairline: #262626
- hairline-soft: #1a1a1a
- inverse-canvas: #ffffff
- inverse-ink: #000000
- gradient-magenta: #d44df0
- gradient-violet: #6a4cf5

Typography tokens:
- display-xxl: family GT Walsheim Framer Medium, size 110px, weight 500, line 0.85, tracking -5.5px
- display-xl: family GT Walsheim Medium, size 85px, weight 500, line 0.95, tracking -4.25px
- display-lg: family GT Walsheim Medium, size 62px, weight 500, line 1.00, tracking -3.1px
- display-md: family GT Walsheim Medium, size 32px, weight 500, line 1.13, tracking -1.0px
- headline: family Inter, size 22px, weight 700, line 1.20, tracking -0.8px
- subhead: family Inter Variable, size 24px, weight 400, line 1.30, tracking -0.01px
- body-lg: family Inter Variable, size 18px, weight 400, line 1.30, tracking -0.18px
- body: family Inter Variable, size 15px, weight 400, line 1.30, tracking -0.15px
- body-sm: family Inter Variable, size 14px, weight 500, line 1.40, tracking -0.14px
- caption: family Inter Variable, size 13px, weight 500, line 1.20, tracking -0.13px
- micro: family Inter Variable, size 12px, weight 400, line 1.20, tracking -0.12px
- button: family Inter Variable, size 14px, weight 500, line 1.0, tracking -0.14px

Spacing tokens:
- hair: 1px
- xxs: 4px
- xs: 8px
- sm: 12px
- md: 15px
- lg: 20px
- xl: 30px
- xxl: 40px
- section: 96px

Radius and shape tokens:
- xs: 4px
- sm: 6px
- md: 10px
- lg: 15px
- xl: 20px
- xxl: 30px
- pill: 100px
- full: 9999px

Component tokens:
- button-primary: backgroundColor: {colors.primary}, textColor: {colors.on-primary}, typography: {typography.button}, rounded: {rounded.pill}, padding: 10px 15px
- button-primary-pressed: backgroundColor: {colors.primary}, textColor: {colors.on-primary}, typography: {typography.button}, rounded: {rounded.pill}
- button-secondary: backgroundColor: {colors.surface-1}, textColor: {colors.ink}, typography: {typography.button}, rounded: {rounded.pill}, padding: 10px 15px
- button-translucent: backgroundColor: {colors.surface-2}, textColor: {colors.ink}, typography: {typography.button}, rounded: {rounded.xxl}, padding: 8px 14px
- button-icon-circular: backgroundColor: {colors.surface-1}, textColor: {colors.ink}, typography: {typography.button}, rounded: {rounded.full}, size: 40px
- pricing-tab-default: backgroundColor: {colors.canvas}, textColor: {colors.ink-muted}, typography: {typography.button}, rounded: {rounded.pill}, padding: 8px 14px
- pricing-tab-selected: backgroundColor: {colors.surface-2}, textColor: {colors.ink}, typography: {typography.button}, rounded: {rounded.pill}, padding: 8px 14px
- text-input: backgroundColor: {colors.surface-1}, textColor: {colors.ink}, typography: {typography.body}, rounded: {rounded.md}, padding: 10px 14px

Color rationale: Source pages: framer.com (home), /ai/, /startups/, /marketplace/templates/nudge/, /gallery/a16z-speedrun-×-tonik, /pricing. Brand & Accent - Pure White ({colors.primary}): The brand primary surface. Every primary CTA pill, every display headline, every body line on canvas. - Sky Blue ({colors.accent-blue}): The single chromatic accent. Hyperlinks, focused-input rings, and a few selection states. Never used for backgrounds or as a brand fill. Surface - Canvas ({colors.canvas}): Default page background — near-black with a faint warmth. Footer, pricing, hero, and FAQ all sit on it. - Surface 1 ({colors.surface-1}): One step above canvas — pricing layered rectangular token motif, secondary buttons, mockup tiles. - Surface 2 ({colors.surface-2}): Two steps above — featured pricing layered rectangular token motif, hero pill backdrop, selected pricing tab. - Hairline ({colors.hairline}): 1px borders on input groups, comparison-table dividers. - Hairline Soft ({colors.hairline-soft}): Subtler dividers — between FAQ rows and footer column rules. - Inverse Canvas ({colors.inverse-canvas}): Pure white — used as the surface of light-on-dark pill CTAs and a small set of light-mode template thu...

Typography rationale: Font Family - GT Walsheim Framer Medium / GT Walsheim Medium — Framer's display typeface. Geometric, slightly humanist, very confident at large sizes with extreme negative tracking. Fallbacks: GT Walsheim Medium Placeholder system font. - Inter Variable — System body typeface. Used with extensive OpenType character variants: cv01 (alternate "1"), cv05 (alternate "g"), cv09 (alternate "i" / "l"), cv11 (alternate "0"), ss03 / ss07 stylistic sets, dlig discretionary ligatures, and tnum for numerics in tabular contexts. The result is a body voice that feels bespoke without commissioning a custom face. - Inter — Used selectively for {typography.headline} (the 22px / 20px tier). The non-variable cut catches small tracking targets that the variable file rounds. Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.display-xxl} | 110px | 500 | 0.85 | -5.5px | Largest hero headline (home, AI page) | | {typography.display-xl} | 85px | 500 | 0.95 | -4.25px | Section opener headlines | | {typography.display-lg} | 62px | 500 | 1.00 | -3.1px | Sub-section openers | | {typography.display-md} | 32px | 500 | 1.13 | -1.0px | layered rectang...

Layout system: Spacing System - Base unit: 5px (Framer uses non-standard 5/10/15/20/30 increments rather than the more common 4/8/16/24). - Tokens (front matter): {spacing.hair} 1px · {spacing.xxs} 4px · {spacing.xs} 8px · {spacing.sm} 12px · {spacing.md} 15px · {spacing.lg} 20px · {spacing.xl} 30px · {spacing.xxl} 40px · {spacing.section} 96px. - layered rectangular token motif interior padding: {spacing.lg} 20px on pricing layered rectangular token motif; {spacing.xl} 30px on gradient spotlight layered rectangular token motif. - Pill button padding: 10px vertical · 15px horizontal — {components.button-primary}. - Section padding (vertical): roughly {spacing.section} 96px on home; tighter (~64px) on pricing comparison. Grid & Container - Max content width sits around the 1199px breakpoint, with side gutters that scale toward {spacing.xl} on desktop. - layered rectangular token motif grids on the home gallery use 2-up at desktop, collapsing to 1-up below 810px. - Pricing tier grid is 4-up across the documented breakpoints; comparison table beneath it uses fixed-width left column with horizontally scrolling tier columns at narrow widths. Whitespace Philosophy The dark canvas IS the whitespace. Wh...

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | 0 (flat) | No shadow, no border | Default for canvas-mounted display type, FAQ rows, footer | | 1 (charcoal) | {colors.surface-1} lift on canvas | Pricing layered rectangular token motif, mockup tiles, secondary buttons | | 2 (light-edge) | rgba(255,255,255,0.10) 0.5px top edge + rgba(0,0,0,0.25) 0px 10px 30px drop | Floating product layered rectangular token motif, modal layered rectangular token motif | | 3 (selected) | rgba(0,153,255,0.15) 0px 0px 0px 1px ring | Focused inputs, selected option | Four shadow signatures recur across the homepage: a 1px subtle drop, a translucent blue ring, a thick near-black 2px outline (used as the active-element marker on sub-nav), and the layered light-edge + drop-shadow used for floating layered rectangular token motif. Decorative Depth - Gradient spotlight layered rectangular token motif are the dominant depth device — color saturation against black canvas substitutes for shadow-driven elevation. - Layered product mockups (modular information frame frames containing live Framer-built sites) sit inside {colors.surface-1} layered rectangular token motif with the level-2 light-edge treatment. - Subtle...

Shape language: Border Radius Scale Framer's extracted radius set is unusually granular (1px, 4px, 5px, 6px, 8px, 10px, 12px, 15px, 20px, 30px, 40px, 100px). The named scale below picks the levels the marketing surface actually consumes. | Token | Value | Use | |---|---|---| | {rounded.xs} | 4px | Small chip / utility radius | | {rounded.sm} | 6px | Inline tag, badge | | {rounded.md} | 10px | Form input, list item | | {rounded.lg} | 15px | Template layered rectangular token motif thumbnails | | {rounded.xl} | 20px | Pricing layered rectangular token motif, mockup tiles | | {rounded.xxl} | 30px | Gradient spotlight layered rectangular token motif, oversized panels | | {rounded.pill} | 100px | All primary text CTAs | | {rounded.full} | 9999px | Circular icon buttons, avatar circles | Photography & Illustration Geometry - Embedded site mockups (browser-chromed previews of Framer-built sites) sit in {rounded.xl} 20px tiles with {spacing.md} 15px interior padding. - Gradient spotlight layered rectangular token motif use {rounded.xxl} 30px corners — softer than the 20px content layered rectangular token motif by design, to make them feel like atmospheric panels rather than tighter UI. - Icon glyphs and...

Component language: Buttons button-primary — White pill on dark canvas. The primary CTA across home, pricing, AI, and gallery pages. - Ba...
```
