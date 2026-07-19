# Flare

**ID:** `flare`  
**Category:** ai  
**Theme:** light  
**Vibe:** Bold

## Color palette

- `#0a0a0a`
- `#ffffff`
- `#181e25`
- `#ff5530`
- `#ea5ec1`
- `#1456f0`
- `#3b82f6`
- `#1d4ed8`
- `#17437d`
- `#3daeff`

## Typography

Families: DM Sans. Weights: 400, 500, 600, 700.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: MiniMax

Design token description: MiniMax presents itself as a premium AI infrastructure brand through a striking duality — bold black-pill CTAs and stark white canvas for marketing, paired with vibrant gradient product cards (orange-red, magenta-pink, purple, blue) that turn each model release into a distinctive visual identity. The system uses DM Sans across all surfaces, employs an oversized 80px hero display, anchors major actions in deep near-black pills, and layers content density via a 3-column documentation grid with sidebar nav, prose body, and TOC. Coverage spans the marketing homepage, model showcase pages, developer documentation, and platform pricing surfaces.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- Detected source-domain vocabulary: search/productivity software, music/media. Translate it into reusable visual behavior, not literal imagery.
- Avoid literal source imagery unless the exact slide text or visual direction explicitly requests it: search bars, search result pages, browser chrome, or app screenshots; product logos, app icons, map pins, or play-button branding; headphones, speakers, album covers, playlist UI, music players, or streaming app screens.

Overall visual personality: MiniMax stages itself as a Chinese AI infrastructure brand with a sophisticated dual identity. Marketing surfaces and platform pages anchor in stark white canvas with deep-black typographic emphasis — the brand voice is confident, technical, almost editorial. But each model release gets its own vibrant gradient identity card: M2.7 in volcanic coral-red, sequenced media-flow rhythm 2.6 in magenta-pink, Hailuo in deep blue, Speech 2.8 in saturated orange-purple. Together these vibrant tiles read like sequenced media-flow rhythm covers laid out on the homepage — each one declaring its own product personality. DM Sans anchors every surface from oversized 80px hero displays down to 12px micro labels. The geometric, slightly humanist character of the face suits both the dense documentation surfaces (where 14px body type carries 1.5 line-height for long-form prose) and the high-impact marketing displays (where -2px letter-spacing tightens 80px headlines). Buttons are universally pill-shaped (rounded-full) with a sharp two-tier system: black-pill primary (the dominant CTA) and outline-pill secondary. Cards split into two distinct families: vibrant gradient product showcases (32px corner s...

Color tokens:
- primary: #0a0a0a
- on-primary: #ffffff
- primary-soft: #181e25
- brand-coral: #ff5530
- brand-magenta: #ea5ec1
- brand-blue: #1456f0
- brand-blue-mid: #3b82f6
- brand-blue-deep: #1d4ed8
- brand-blue-700: #17437d
- brand-cyan: #3daeff
- brand-blue-200: #bfdbfe
- brand-purple: #a855f7
- canvas: #ffffff
- surface: #f7f8fa

Typography tokens:
- hero-display: family DM Sans, size 80px, weight 600, line 1.10, tracking -2px
- display-lg: family DM Sans, size 56px, weight 600, line 1.10, tracking -1.5px
- heading-lg: family DM Sans, size 40px, weight 600, line 1.20, tracking -1px
- heading-md: family DM Sans, size 32px, weight 600, line 1.25, tracking -0.5px
- heading-sm: family DM Sans, size 24px, weight 600, line 1.30
- card-title: family DM Sans, size 20px, weight 600, line 1.40
- subtitle: family DM Sans, size 18px, weight 500, line 1.50
- body-md: family DM Sans, size 16px, weight 400, line 1.50
- body-md-bold: family DM Sans, size 16px, weight 700, line 1.50
- body-sm: family DM Sans, size 14px, weight 400, line 1.50
- body-sm-medium: family DM Sans, size 14px, weight 500, line 1.50
- caption: family DM Sans, size 13px, weight 400, line 1.70

Spacing tokens:
- xxs: 4px
- xs: 8px
- sm: 12px
- md: 16px
- lg: 20px
- xl: 24px
- xxl: 32px
- xxxl: 40px
- section-sm: 48px
- section: 64px

Radius and shape tokens:
- xs: 4px
- sm: 6px
- md: 8px
- lg: 12px
- xl: 16px
- xxl: 20px
- xxxl: 24px
- hero: 32px
- full: 9999px

Component tokens:
- button-primary: backgroundColor: {colors.primary}, textColor: {colors.on-primary}, typography: {typography.button-md}, rounded: {rounded.full}, padding: 11px 24px
- button-primary-pressed: backgroundColor: {colors.charcoal}, textColor: {colors.on-primary}
- button-primary-disabled: backgroundColor: {colors.hairline}, textColor: {colors.muted}
- button-secondary: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.button-md}, rounded: {rounded.full}, padding: 11px 24px, border: 1px solid {colors.ink}
- button-tertiary: backgroundColor: {colors.canvas}, textColor: {colors.ink}, typography: {typography.button-md}, rounded: {rounded.full}, padding: 11px 24px, border: 1px solid {colors.hairline}
- button-link: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.body-sm-medium}, padding: 8px 0
- button-icon-circular: backgroundColor: {colors.canvas}, textColor: {colors.ink}, rounded: {rounded.full}, size: 36px, border: 1px solid {colors.hairline}
- product-card-coral: backgroundColor: {colors.brand-coral}, textColor: {colors.on-dark}, rounded: {rounded.hero}, padding: {spacing.xxl}

Color rationale: Source pages: minimax.io/ (homepage), /models/text/m27 (product showcase), platform.minimax.io/approachable modular product geometry/guides/models-intro (documentation), /subscribe/token-plan (pricing). Token coverage was identical across all four pages. Brand & Accent - Brand Coral ({colors.brand-coral}): Signature high-impact accent. Used on M2.7 product card, "Token Plan" hero band, promo CTA strips, and "NEW" badges. Carries the brand's most attention-grabbing energy. - Brand Magenta ({colors.brand-magenta}): Secondary product-card identity (sequenced media-flow rhythm 2.6); used for sequenced media-flow rhythm/sequenced media-flow rhythm product encoding. - Brand Blue ({colors.brand-blue}): Hailuo video product identity; primary blue accent across the system. - Brand Blue Deep ({colors.brand-blue-deep}): Form-control activation, link emphasis. - Brand Blue 700 ({colors.brand-blue-700}): Documentation tag and reference text color. - Brand Cyan ({colors.brand-cyan}): Atmospheric blue for product gradients and decorative wash. - Brand Blue 200 ({colors.brand-blue-200}): Code badges, info-tag backgrounds. - Brand Purple ({colors.brand-purple}): Speech 2.8 and minor purple-product...

Typography rationale: Font Family DM Sans (primary): Geometric variable sans-serif. Used across every surface, every role. Fallbacks: Inter, Helvetica Neue, Helvetica, Arial. DM Sans was chosen for its dual fluency: it scales cleanly from 80px hero displays (where -2px letter-spacing creates magazine-grade tightness) down to 12px micro labels (where the slightly humanist counters maintain legibility). The face has no italic variant in the brand's deployment — emphasis comes from weight (500/600/700) instead. Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.hero-display} | 80px | 600 | 1.10 | -2px | Homepage hero ("MiniMax sequenced media-flow rhythm 2.6") | | {typography.display-lg} | 56px | 600 | 1.10 | -1.5px | Section openers, major page heroes | | {typography.heading-lg} | 40px | 600 | 1.20 | -1px | Sub-page headlines ("Token Plan", "Models Overview") | | {typography.heading-md} | 32px | 600 | 1.25 | -0.5px | Subsection headers ("Full-Stack Model Matrix") | | {typography.heading-sm} | 24px | 600 | 1.30 | 0 | Card titles, feature headers | | {typography.card-title} | 20px | 600 | 1.40 | 0 | Product-card titles, feature-tile headers | |...

Layout system: Spacing System - Base unit: 4px (8px primary increment). - Tokens: {spacing.xxs} (4px) · {spacing.xs} (8px) · {spacing.sm} (12px) · {spacing.md} (16px) · {spacing.lg} (20px) · {spacing.xl} (24px) · {spacing.xxl} (32px) · {spacing.xxxl} (40px) · {spacing.section-sm} (48px) · {spacing.section} (64px) · {spacing.section-lg} (80px) · {spacing.hero} (96px). - Section rhythm: Marketing pages separate at {spacing.hero} (96px) above-fold, then {spacing.section-lg} (80px) below; documentation tightens to {spacing.section} (64px); table rows compress to {spacing.md} (16px). - Card internal padding: Vibrant product cards use {spacing.xxl} (32px); documentation cards use {spacing.lg}–{spacing.xl} (20–24px); promo strips expand to {spacing.section} (64px). Grid & Container - Marketing pages use a 1280px max-width with 32px gutters. - Homepage product matrix renders as a 4-column row of 32px-rounded gradient cards, each ~280–320px wide. - AI Product Matrix below uses a 4-column grid with 16px-rounded white cards. - Documentation surfaces use a 3-column layout: left sidebar nav (~220px), center prose body (~720px max-width), right TOC (~180px). Sidebar persists on desktop; collapses to drawer be...

Depth and hierarchy: The system runs predominantly flat. Elevation is reserved for sticky panels, dropdowns, and the rare floating CTA. | Level | Treatment | Use | |---|---|---| | 0 (flat) | No shadow; {colors.hairline} border | Default cards, table rows, form inputs | | 1 (subtle) | rgba(0, 0, 0, 0.04) 0px 1px 2px 0px | Card-recommendation, hover-elevated tiles | | 2 (card) | rgba(0, 0, 0, 0.08) 0px 4px 6px 0px | Standard feature cards, dropdowns | | 3 (atmospheric) | rgba(0, 0, 0, 0.08) 0px 0px 22px 0px | Diffuse glow on featured product cards | | 4 (modal) | rgba(36, 36, 36, 0.08) 0px 12px 16px -4px | Modals, confirmation dialogs, sticky panels | Decorative Depth - The vibrant gradient product cards carry their own atmospheric depth via internal radial gradients and silhouette imagery — no shadow needed; the color does the work. - Brand-tinted shadows (rgba(44, 30, 116, 0.16) 0px 0px 15px) appear under purple-themed cards for subtle ambient lift. - Dotted/grain textures occasionally appear inside product cards as photographic-content decoration; these are not formalized as system tokens.

Shape language: Border Radius Scale | Token | Value | Use | |---|---|---| | {rounded.xs} | 4px | Code chips, micro-controls | | {rounded.sm} | 6px | Compact controls, table cells | | {rounded.md} | 8px | Inputs, secondary buttons, search pill | | {rounded.lg} | 12px | Documentation cards, recommendation tiles | | {rounded.xl} | 16px | Standard feature cards, AI product tiles | | {rounded.xxl} | 20px | Larger feature panels | | {rounded.xxxl} | 24px | AI product tile feature variants | | {rounded.hero} | 32px | Vibrant gradient product cards, promo CTA strip | | {rounded.full} | 9999px | All buttons, all pill tabs, badges | Photography Geometry - Vibrant product cards use 32px corner softening — distinct from the 16px used on quiet white cards. The doubled radius is the visual signature of "this is a featured product moment." - Product imagery inside cards is treated as photographic content (silhouettes, dark portrait studio lighting) without rounded internal frames. - Avatar circles (rare, in testimonials) are {rounded.full} — perfect circles.

Component language: Per the no-hover policy, hover states are NOT documented. Default and pressed/active states only. Buttons button-primary — Black pill primary CTA, the dominant action across all surfaces. - Background {colors.primary}, text {colors.on-primary}, typography {typography.button-md}, padding 11px 24px, rounded {rounded.full}. - Pressed state button-primary-pressed lifts to {colors.charcoal}. - Disabled state button-primary-disabled uses {colors.hairline} background and {colors.muted} text. button-secondary — Outlined pill secondary action, paired with primary in dual-CTA hero patterns. - Background transparent, text {colors.ink}, border 1px solid {colors.ink}, typography {typography.button-md}, padding 11px 24px, ro...
```
