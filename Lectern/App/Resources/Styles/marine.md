# Marine

**ID:** `marine`  
**Category:** enterprise  
**Theme:** light  
**Vibe:** Corporate

## Color palette

- `#0064e0`
- `#0457cb`
- `#0091ff`
- `#ffffff`
- `#000000`
- `#1876f2`
- `#385898`
- `#a121ce`
- `#31a24c`
- `#24e400`

## Typography

Families: Optimistic VF. Weights: 300, 400, 500, 700.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Meta

Design token description: Meta's design system spans hardware commerce (Quest VR, Ray-Ban Meta AI glasses) and brand surfaces with a confident product-merchandising voice. The system pairs a stark white canvas with full-bleed photographic product layered rectangular token motif, a confident Optimistic VF wordmark/headline face, dual-CTA hero patterns (black primary + outlined secondary), and a saturated cobalt blue (0064E0) for in-product purchase actions. Pill-shaped 100px-radius buttons, generous 24-32px layered rectangular token motif rounding, and tight three-tier text hierarchy carry across homepage, product detail (PDP), buy-now configurator, and accessory subpages.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- Detected source-domain vocabulary: search/productivity software, finance/banking. Translate it into reusable visual behavior, not literal imagery.
- Avoid literal source imagery unless the exact slide text or visual direction explicitly requests it: search bars, search result pages, browser chrome, or app screenshots; product logos, app icons, map pins, or play-button branding; credit cards, debit cards, bank apps, cash, coins, trading screens, or crypto coins; financial product mockups unless requested by slide content.

Overall visual personality: Meta's commerce surfaces (homepage, Quest configurator, Ray-Ban product detail, prescription page) read as a confident hardware merchandiser. The brand voice is photography-first: large, full-bleed product imagery dominates above-the-fold real estate, with white space and tight typographic hierarchy carrying the rest. The system has a recognizable dual-CTA pattern — a black pill-shaped primary on marketing surfaces shifting to a saturated cobalt blue ({colors.primary}) inside the buy-now flows, paired with an outlined ghost button for secondary navigation. Optimistic VF — Meta's variable display face — anchors the entire system, ranging from a 64px hero display down to a 12px caption. The face's ss01 and ss02 stylistic sets are switched on across every heading role, contributing to the brand's slightly humanist, friendly geometric character. Below 768px the system collapses cleanly: hero stacks, pill nav becomes a hamburger, three-up feature grids flatten to a single column, and product configurators drop their right-rail summary into a sticky bottom bar. Key Characteristics: - Stark white canvas ({colors.canvas}) carrying full-bleed product photography with {rounded.xxxl} (32px)...

Color tokens:
- primary: #0064e0
- primary-deep: #0457cb
- primary-soft: #0091ff
- on-primary: #ffffff
- ink-button: #000000
- on-ink-button: #ffffff
- fb-blue: #1876f2
- meta-link: #385898
- oculus-purple: #a121ce
- success: #31a24c
- success-bg: #24e400
- attention: #f2a918
- warning: #f7b928
- warning-bg: #ffe200

Typography tokens:
- hero-display: family Optimistic VF, size 64px, weight 500, line 1.16
- display-lg: family Optimistic VF, size 48px, weight 500, line 1.17
- heading-lg: family Optimistic VF, size 36px, weight 500, line 1.28
- heading-md: family Optimistic VF, size 28px, weight 300, line 1.21
- heading-sm: family Optimistic VF, size 24px, weight 500, line 1.25
- subtitle-lg: family Optimistic VF, size 18px, weight 700, line 1.44
- subtitle-md: family Optimistic VF, size 18px, weight 400, line 1.44
- body-md-bold: family Optimistic VF, size 16px, weight 700, line 1.50, tracking -0.16px
- body-md: family Optimistic VF, size 16px, weight 400, line 1.50, tracking -0.16px
- body-sm-bold: family Optimistic VF, size 14px, weight 700, line 1.43, tracking -0.14px
- body-sm: family Optimistic VF, size 14px, weight 400, line 1.43, tracking -0.14px
- caption-bold: family Optimistic VF, size 12px, weight 700, line 1.33

Spacing tokens:
- xxs: 4px
- xs: 8px
- sm: 10px
- md: 12px
- base: 16px
- lg: 20px
- xl: 24px
- xxl: 32px
- xxxl: 40px
- section-sm: 48px

Radius and shape tokens:
- xs: 2px
- sm: 4px
- md: 6px
- lg: 8px
- xl: 16px
- xxl: 24px
- xxxl: 32px
- feature: 40px
- full: 100px
- circle: 9999px

Component tokens:
- button-primary: backgroundColor: {colors.ink-button}, textColor: {colors.on-ink-button}, typography: {typography.button-md}, rounded: {rounded.full}, padding: 14px 30px
- button-primary-pressed: backgroundColor: {colors.charcoal}, textColor: {colors.on-ink-button}
- button-primary-disabled: backgroundColor: {colors.disabled-text}, textColor: {colors.canvas}
- button-buy-cta: backgroundColor: {colors.primary}, textColor: {colors.on-primary}, typography: {typography.button-md}, rounded: {rounded.full}, padding: 14px 30px
- button-buy-cta-pressed: backgroundColor: {colors.primary-deep}, textColor: {colors.on-primary}
- button-secondary: backgroundColor: transparent, textColor: {colors.ink-deep}, typography: {typography.button-md}, rounded: {rounded.full}, padding: 12px 28px, border: 2px solid {colors.ink-deep}
- button-ghost: backgroundColor: transparent, textColor: {colors.ink-deep}, typography: {typography.button-md}, rounded: {rounded.full}, padding: 10px 22px, border: 2px solid rgba(10, 19, 23, 0.12)
- button-pill-tab: backgroundColor: {colors.canvas}, textColor: {colors.ink}, typography: {typography.body-sm-bold}, rounded: {rounded.full}, padding: 8px 16px, border: 1px solid {colors.hairline}

Color rationale: Source pages: meta.com/ (homepage), /ai-glasses/ray-ban-meta-skyler-gen-2/ (PDP), /quest/quest-3s/buy-now/ (configurator), /ai-glasses/prescription/ (lens upsell). Token coverage was identical across all four pages — the design system is genuinely unified. Brand & Accent - Cobalt Primary ({colors.primary}): The buy-now CTA color. Used on every "Add to cart", "Configure", "Pre-order" button inside the commerce flow and the right-rail purchase panel. - Deep Cobalt ({colors.primary-deep}): Pressed-state and dark-surface variant of the cobalt primary; also the active link color. - Soft Cobalt ({colors.primary-soft}): Translucent background tint for informational callouts ({colors.primary-soft} at 15% alpha). - Facebook Blue ({colors.fb-blue}): Selected radio/checkbox state and inline form-control activation color. - Meta Link Blue ({colors.meta-link}): Reserved for legacy navigation and footer link affordances. - Oculus Purple ({colors.oculus-purple}): VR product accent — used inside Quest-branded surfaces for category emphasis. Surface - Canvas White ({colors.canvas}): Page background and primary layered rectangular token motif surface. - Soft Cloud ({colors.surface-soft}): Subtle pr...

Typography rationale: Font Family Optimistic VF is Meta's proprietary variable display face. Fallbacks: Montserrat, Helvetica, Arial, Noto Sans. The variable axes carry from 300 (light heading-md, used for editorial intro headlines like "Look forward") through 500 (display, hero, heading-sm) up to 700 (subtitle, body emphasis, button labels). Stylistic sets ss01 and ss02 are switched on across every heading role — they soften the geometry and give the type a slightly humanist breathing. A secondary Helvetica fallback chain is used for technical microcopy (12px) inside spec approachable modular product geometry and footer fine print. Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | OpenType | Use | |---|---|---|---|---|---|---| | {typography.hero-display} | 64px | 500 | 1.16 | 0 | ss01, ss02 | Homepage hero ("Get 25% off…", category opener) | | {typography.display-lg} | 48px | 500 | 1.17 | 0 | ss01, ss02 | Section-opener display ("Made for prescriptions. Built for comfort.") | | {typography.heading-lg} | 36px | 500 | 1.28 | 0 | ss01, ss02 | Subsection headlines ("Why buy from Meta", "Tech specs") | | {typography.heading-md} | 28px | 300 | 1.21 | 0 | ss01, ss02 | Editorial subheads in l...

Layout system: Spacing System - Base unit: 4px increment with 8px as the dominant primary step. - Tokens: {spacing.xxs} (4px) · {spacing.xs} (8px) · {spacing.sm} (10px) · {spacing.md} (12px) · {spacing.base} (16px) · {spacing.lg} (20px) · {spacing.xl} (24px) · {spacing.xxl} (32px) · {spacing.xxxl} (40px) · {spacing.section-sm} (48px) · {spacing.section} (64px) · {spacing.section-lg} (80px) · {spacing.hero} (120px). - Section rhythm: Marketing sections separate at {spacing.section-lg} (80px); product detail sections compress to {spacing.section} (64px); FAQ stacks tighten further to {spacing.xxl} (32px). - layered rectangular token motif internal padding: Standard {spacing.xxl} (32px); icon-feature tiles compress to {spacing.xl} (24px); promo-strip layered rectangular token motif expand to {spacing.section} (64px) for hero presence. Grid & Container - Marketing page max-width sits around 1280px with 32–48px gutters. - The PDP layout uses a 2-column split: hero gallery (~58% width) + sticky purchase rail (~42%, with max-width: 380px on the rail). - Three-up feature grids ("Why buy from Meta") use a 24px column gap; six-up product thumbnail rows (color/SKU pickers) use a 12px gap. Whitespace Philos...

Depth and hierarchy: The system runs predominantly flat. Elevation is reserved for two interaction layers: | Level | Treatment | Use | |---|---|---| | 0 (flat) | No shadow; {rounded.xxxl} rounding + {colors.hairline-soft} border | Default product layered rectangular token motif, why-buy tiles | | 1 (subtle) | rgba(0, 0, 0, 0.2) 1px 1px 0px 0px | Pill-tab activation indicator | | 2 (sticky panel) | rgba(20, 22, 26, 0.3) 0px 1px 4px 0px | PDP right-rail purchase summary, sticky mobile checkout bar | Decorative Depth - Photography-as-depth: full-bleed product imagery on {rounded.xxxl} layered rectangular token motif creates atmospheric layering without shadows. - Translucent overlays (rgba(255, 255, 255, 0.1) to rgba(10, 19, 23, 0.12)) cover dark hero photography to lift legibility of overlaid text. - Decorative pastel tints inside accessory layered rectangular token motif — soft pink, ice-blue, mint — appear briefly behind product cutouts but are NOT formalized as system tokens (treated as photographic content).

Shape language: Border Radius Scale | Token | Value | Use | |---|---|---| | {rounded.xs} | 2px | Inline checkbox marks, fine UI corners | | {rounded.sm} | 4px | Tags, micro-controls | | {rounded.md} | 6px | Square thumbnail rounding | | {rounded.lg} | 8px | Form inputs, radio-option containers | | {rounded.xl} | 16px | Standard feature layered rectangular token motif, FAQ accordion items | | {rounded.xxl} | 24px | Warranty / accessory tiles, ghost-style action layered rectangular token motif | | {rounded.xxxl} | 32px | Photographic feature layered rectangular token motif, big promo strips | | {rounded.feature} | 40px | Accessory hero panels, "Built for prescriptions" layered rectangular token motif | | {rounded.full} | 100px | Pill buttons, tab chips, badges | | {rounded.circle} | 50% | Color swatches, circular icon buttons | Photography Geometry - Product hero photography sits in {rounded.xxxl} (32px) frames more often than rectangles. - Color/material swatches are perfect circles ({rounded.circle}, 32px diameter, 2px white border ring when selected). - Square product thumbnails (aspect-ratio: 1/1) use {rounded.xl} rounding. - Six-up "color & SKU" picker rows use 1:1 aspect tiles with {rounded.l...

Component language: Per the no-hover policy, hover states are NOT documented for any component below. Default and pressed/active states only. Buttons button-primary — Black pill primary CTA for marketing surfaces ("Shop", "Pre-order"). - Background {colors.ink-button}, text {colors.on-ink-button}, typography {typography.button-md}, padding 14px 30px, rounded {rounded.full}. - Pressed state button-primary-pressed flips background to {colors.charc...
```
