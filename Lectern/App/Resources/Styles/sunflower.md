# Sunflower

**ID:** `sunflower`  
**Category:** enterprise  
**Theme:** light  
**Vibe:** Playful

## Color palette

- `#1c1c1e`
- `#ffffff`
- `#ffd02f`
- `#fcb900`
- `#fff4c4`
- `#746019`
- `#4262ff`
- `#5b76fe`
- `#2a41b6`
- `#ff9999`

## Typography

Families: Roobert PRO. Weights: 400, 500, 600.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Miro

Design token description: Miro presents itself as the AI-powered visual the source brand through a confident, almost playful brand voice — anchored by its signature canary yellow ({colors.brand-yellow}) wordmark over white canvas, broken open by colorful pastel feature tints (rose, teal, coral, orange, mint) that echo the actual sticky-note color palette used on the live whiteboard. Black-pill primary buttons dominate marketing, real Miro-board mockups serve as feature illustrations, and a 4-tier pricing grid leads into a dense comparison table. Roobert PRO carries display headlines; the system supports homepage, pricing, AI Workflows product page, agile vertical, and customer stories surfaces.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- Detected source-domain vocabulary: search/productivity software, finance/banking. Translate it into reusable visual behavior, not literal imagery.
- Avoid literal source imagery unless the exact slide text or visual direction explicitly requests it: search bars, search result pages, browser chrome, or app screenshots; product logos, app icons, map pins, or play-button branding; credit cards, debit cards, bank apps, cash, coins, trading screens, or crypto coins; financial product mockups unless requested by slide content.

Overall visual personality: Miro positions itself as the AI-powered visual the source brand through a confident, slightly playful brand voice. The homepage opens with a stark white canvas anchored by a small canary-yellow Miro wordmark in the top-left, a black-pill primary CTA "Get started free" and a secondary "Book a demo" outline pill — then dramatic real-Miro-board mockup imagery (sticky notes, kanban, mind maps) carries the visual weight. Across deeper surfaces, the system breaks open: pastel feature layered rectangular token motif (rose, teal, coral, yellow) echo the actual sticky-note color palette of the live whiteboard product, and customer story layered rectangular token motif reuse those tints to differentiate brand vignettes. Roobert PRO — Miro's custom display face — anchors every typographic surface, from the 80px hero display down to 11px micro labels. The face's slightly rounded, geometric character pairs naturally with the playful product photography and the friendly product positioning. Black-pill primary buttons ({rounded.full}) dominate marketing CTAs; the brand color, signature canary yellow ({colors.brand-yellow}), is reserved for the wordmark, top promo banners, and "yellow tag" featur...

Color tokens:
- primary: #1c1c1e
- on-primary: #ffffff
- brand-yellow: #ffd02f
- brand-yellow-deep: #fcb900
- yellow-light: #fff4c4
- yellow-dark: #746019
- brand-blue: #4262ff
- blue-450: #5b76fe
- blue-pressed: #2a41b6
- brand-coral: #ff9999
- coral-light: #ffc6c6
- coral-dark: #600000
- brand-rose: #ffd8f4
- rose-light: #fde0f0

Typography tokens:
- hero-display: family Roobert PRO, size 80px, weight 500, line 1.05, tracking -2px
- display-lg: family Roobert PRO, size 60px, weight 500, line 1.10, tracking -1.5px
- heading-1: family Roobert PRO, size 48px, weight 500, line 1.15, tracking -1px
- heading-2: family Roobert PRO, size 36px, weight 500, line 1.20, tracking -0.5px
- heading-3: family Roobert PRO, size 28px, weight 500, line 1.25
- heading-4: family Roobert PRO, size 22px, weight 500, line 1.30
- heading-5: family Roobert PRO, size 18px, weight 500, line 1.40
- subtitle: family Roobert PRO, size 18px, weight 400, line 1.50
- body-md: family Roobert PRO, size 16px, weight 400, line 1.50
- body-md-medium: family Roobert PRO, size 16px, weight 500, line 1.50
- body-sm: family Roobert PRO, size 14px, weight 400, line 1.50
- body-sm-medium: family Roobert PRO, size 14px, weight 500, line 1.50

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
- xxxl: 28px
- feature: 32px
- full: 9999px

Component tokens:
- button-primary: backgroundColor: {colors.primary}, textColor: {colors.on-primary}, typography: {typography.button-md}, rounded: {rounded.full}, padding: 12px 24px
- button-primary-pressed: backgroundColor: {colors.charcoal}, textColor: {colors.on-primary}
- button-primary-disabled: backgroundColor: {colors.hairline}, textColor: {colors.muted}
- button-yellow: backgroundColor: {colors.brand-yellow}, textColor: {colors.primary}, typography: {typography.button-md}, rounded: {rounded.full}, padding: 12px 24px
- button-blue: backgroundColor: {colors.brand-blue}, textColor: {colors.on-primary}, typography: {typography.button-md}, rounded: {rounded.full}, padding: 12px 24px
- button-secondary: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.button-md}, rounded: {rounded.full}, padding: 12px 24px, border: 1px solid {colors.hairline-strong}
- button-on-dark: backgroundColor: {colors.on-dark}, textColor: {colors.primary}, typography: {typography.button-md}, rounded: {rounded.full}, padding: 12px 24px
- button-ghost: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.button-md}, rounded: {rounded.md}, padding: 8px 12px

Color rationale: Source pages: miro.com/ (homepage), /pricing/ (4-tier comparison), /products/ai-workflows/ (AI product), /agile/ (vertical landing), /customers/ (story directory). Token coverage was identical across all five pages. Brand & Accent - Miro Yellow ({colors.brand-yellow}): The brand's recognizable canary yellow — wordmark color, top promo banner, "yellow tag" pills - Yellow Deep ({colors.brand-yellow-deep}): Darker variant for hover states and emphasis - Yellow Light ({colors.yellow-light}): Pale yellow background tint for tag chips - Yellow Dark ({colors.yellow-dark}): Yellow-tag text color (dark olive) for chip foreground - Brand Blue ({colors.brand-blue}): Action blue for inline links and featured-pricing-tier border - Blue Pressed ({colors.blue-pressed}): Pressed-state blue - Brand Coral ({colors.brand-coral}): Coral accent for warm callouts - Coral Light ({colors.coral-light}): Pale coral for feature layered rectangular token motif backgrounds - Coral Dark ({colors.coral-dark}): Coral-tag text color (deep wine) - Brand Rose ({colors.brand-rose}): Soft rose-pink for feature layered rectangular token motif variants - Brand Teal ({colors.brand-teal}): Brand teal - Teal Light ({color...

Typography rationale: Font Family Roobert PRO (primary): Miro's custom geometric sans-serif typeface. Used across every UI surface from oversized 80px hero displays to 11px micro labels. The face has a slightly rounded, friendly character that matches the brand's playful product positioning. Fallbacks: Noto Sans, -apple-system, BlinkMacSystemFont, sans-serif. Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.hero-display} | 80px | 500 | 1.05 | -2px | Marketing hero ("See how teams get great done with Miro") | | {typography.display-lg} | 60px | 500 | 1.10 | -1.5px | Major section openers | | {typography.heading-1} | 48px | 500 | 1.15 | -1px | Page-level headlines | | {typography.heading-2} | 36px | 500 | 1.20 | -0.5px | Subsection headlines | | {typography.heading-3} | 28px | 500 | 1.25 | 0 | layered rectangular token motif titles | | {typography.heading-4} | 22px | 500 | 1.30 | 0 | Feature tile titles | | {typography.heading-5} | 18px | 500 | 1.40 | 0 | FAQ questions, smaller layered rectangular token motif | | {typography.subtitle} | 18px | 400 | 1.50 | 0 | Hero subtitle | | {typography.body-md} | 16px | 400 | 1.50 | 0 | Primary body text...

Layout system: Spacing System - Base unit: 4px (8px primary increment) - Tokens: {spacing.xxs} (4px) · {spacing.xs} (8px) · {spacing.sm} (12px) · {spacing.md} (16px) · {spacing.lg} (20px) · {spacing.xl} (24px) · {spacing.xxl} (32px) · {spacing.xxxl} (40px) · {spacing.section-sm} (48px) · {spacing.section} (64px) · {spacing.section-lg} (96px) · {spacing.hero} (120px) - Section rhythm: Marketing pages use {spacing.section-lg} (96px); pricing comparison tightens to {spacing.section} (64px); customer story stack uses {spacing.xxl} (32px) - layered rectangular token motif internal padding: {spacing.xl} (24px) for compact layered rectangular token motif; {spacing.xxl} (32px) for feature panels Grid & Container - Marketing pages use 1280px max-width with 32px gutters - Pricing page renders 4-tier layered rectangular token motif row at desktop (Free / Starter / Business / Enterprise) - Customer stories page uses 2-column grid with filter dropdowns - AI Workflows page uses 2-column hero, then 3-up feature grid Whitespace Philosophy Marketing surfaces give content generous breathing room — {spacing.hero} (120px) hero padding gives the small wordmark room to breathe. Pricing surfaces tighten dramatically.

Depth and hierarchy: The system runs predominantly flat with strategic depth on hero mockups. | Level | Treatment | Use | |---|---|---| | 0 (flat) | No shadow; {colors.hairline-soft} border | Default layered rectangular token motif, table rows, form inputs | | 1 (subtle) | rgba(5, 0, 56, 0.04) 0px 1px 2px 0px | Subtle hover-elevated tiles | | 2 (layered rectangular token motif) | rgba(5, 0, 56, 0.06) 0px 4px 12px 0px | Standard feature layered rectangular token motif | | 3 (mockup) | rgba(5, 0, 56, 0.08) 0px 12px 32px -4px | Hero whiteboard mockup framing | | 4 (modal) | rgba(5, 0, 56, 0.12) 0px 16px 48px -8px | Modals, dropdowns | Decorative Depth - The atmospheric depth on Miro's hero comes from the live-product-board mockup illustrations — sticky notes layered at z-offsets, color-block tints behind whiteboard frames - Pastel feature layered rectangular token motif carry their own visual weight via saturated background color - Customer-story layered rectangular token motif layer dark photographic content with overlay scrims

Shape language: Border Radius Scale | Token | Value | Use | |---|---|---| | {rounded.xs} | 4px | Small chips, micro-controls | | {rounded.sm} | 6px | Discount badges | | {rounded.md} | 8px | Inputs, search-pill | | {rounded.lg} | 12px | Standard layered rectangular token motif, table containers | | {rounded.xl} | 16px | Pricing layered rectangular token motif, feature panels | | {rounded.xxl} | 20px | Larger feature layered rectangular token motif | | {rounded.xxxl} | 28px | Pastel feature layered rectangular token motif (yellow, rose, coral, teal) | | {rounded.feature} | 32px | Hero CTA banner layered rectangular token motif | | {rounded.full} | 9999px | All buttons, pill tabs, badges | Photography Geometry - Real Miro board mockups render with {rounded.xl} (16px) corners and a subtle drop shadow - Customer story layered rectangular token motif use {rounded.xxxl} (28px) corners with full-bleed photography - Template layered rectangular token motif thumbnails use {rounded.xl} (16px) with photographic content - Customer logos wall presents wordmarks inline at consistent 100px height

Component language: Per the no-hover policy, hover states are NOT documented. Default and pressed/active states only. Buttons button-primary — Black pill primary CTA, the dominant action ("Get started free"). - Background {colors.primary}, text {colors.on-primary}, typography {typography.button-md}, padding 12px 24px, rounded {rounded.full}. - Pressed state button-primary-pressed lifts to {colors.charcoal}. - Disabled state button-primary-disabled uses {colors.hairline} background and {colors.muted} text. button-yellow — Brand-yellow pill for moments of brand emphasis. - Background {colors.br...
```
