# Confetti

**ID:** `confetti`  
**Category:** developer  
**Theme:** light  
**Vibe:** Playful

## Color palette

- `#5645d4`
- `#4534b3`
- `#3a2a99`
- `#ffffff`
- `#0a1530`
- `#070f24`
- `#1a2a52`
- `#0075de`
- `#005bab`
- `#dd5b00`

## Typography

Families: Notion Sans. Weights: 400, 500, 600.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Notion

Design token description: Notion presents itself as the all-in-one the source brand through a confident, illustration-rich brand voice — anchored by a deep navy hero band ({colors.brand-navy}) decorated with brand-colored sticky-note dots and mesh wire illustrations, a signature purple pill primary CTA ({colors.primary}), and a rich palette of pastel-tinted feature cards that echo the colorful database properties of the live product. The system uses a Notion-Sans (Inter-based) typeface across every UI surface, anchors a 4-tier pricing comparison (Free / Plus / Business / Enterprise), and presents the live the source brand UI mockup directly inside the hero band. Coverage spans homepage, Enterprise, Product AI, Product Agents, Startups, and Pricing surfaces.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- Detected source-domain vocabulary: search/productivity software. Translate it into reusable visual behavior, not literal imagery.
- Avoid literal source imagery unless the exact slide text or visual direction explicitly requests it: search bars, search result pages, browser chrome, or app screenshots; product logos, app icons, map pins, or play-button branding.

Overall visual personality: Notion presents itself as the all-in-one the source brand through a confident, illustration-rich brand voice. The homepage opens with "Meet the night shift." rendered centered over a deep navy hero band ({colors.brand-navy}), decorated with brand-colored sticky-note dots and mesh wire illustrations scattered around the headline. The signature purple pill primary CTA ({colors.primary}) "Get Notion free" sits at the visual center, paired with an outlined "Request a demo" secondary. Below the buttons, a real Notion the source brand UI mockup card (the "Ramp HQ" kanban board) breaks out of the hero band with a deep diffuse drop shadow. Below the hero, the page cycles through a distinctive sequence of feature sections: a dense sticky-note "Keep work moving 24/7" panel with red/blue/green/purple/teal status icons; a bold yellow ({colors.card-tint-yellow-bold}) "Ask your on-demand assistants" banner card flanked by orange/rose/mint pastel feature tiles showing assistant UI mockups; and a "Bring all your work together" 3-column grid with brand-colored mockups (sky-blue tutorial card, light Notion approachable modular product geometry, brown/rust testimonial slate). The pricing page render...

Color tokens:
- primary: #5645d4
- primary-pressed: #4534b3
- primary-deep: #3a2a99
- on-primary: #ffffff
- brand-navy: #0a1530
- brand-navy-deep: #070f24
- brand-navy-mid: #1a2a52
- link-blue: #0075de
- link-blue-pressed: #005bab
- brand-orange: #dd5b00
- brand-orange-deep: #793400
- brand-pink: #ff64c8
- brand-pink-deep: #a02e6d
- brand-purple: #7b3ff2

Typography tokens:
- hero-display: family Notion Sans, size 80px, weight 600, line 1.05, tracking -2px
- display-lg: family Notion Sans, size 56px, weight 600, line 1.10, tracking -1px
- heading-1: family Notion Sans, size 48px, weight 600, line 1.15, tracking -0.5px
- heading-2: family Notion Sans, size 36px, weight 600, line 1.20, tracking -0.5px
- heading-3: family Notion Sans, size 28px, weight 600, line 1.25
- heading-4: family Notion Sans, size 22px, weight 600, line 1.30
- heading-5: family Notion Sans, size 18px, weight 600, line 1.40
- subtitle: family Notion Sans, size 18px, weight 400, line 1.50
- body-md: family Notion Sans, size 16px, weight 400, line 1.55
- body-md-medium: family Notion Sans, size 16px, weight 500, line 1.55
- body-sm: family Notion Sans, size 14px, weight 400, line 1.50
- body-sm-medium: family Notion Sans, size 14px, weight 500, line 1.50

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
- full: 9999px

Component tokens:
- button-primary: backgroundColor: {colors.primary}, textColor: {colors.on-primary}, typography: {typography.button-md}, rounded: {rounded.md}, padding: 10px 18px
- button-primary-pressed: backgroundColor: {colors.primary-pressed}, textColor: {colors.on-primary}
- button-primary-disabled: backgroundColor: {colors.hairline}, textColor: {colors.muted}
- button-dark: backgroundColor: {colors.ink-deep}, textColor: {colors.on-dark}, typography: {typography.button-md}, rounded: {rounded.md}, padding: 10px 18px
- button-secondary: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.button-md}, rounded: {rounded.md}, padding: 10px 18px, border: 1px solid {colors.hairline-strong}
- button-on-dark: backgroundColor: {colors.on-dark}, textColor: {colors.ink}, typography: {typography.button-md}, rounded: {rounded.md}, padding: 10px 18px
- button-secondary-on-dark: backgroundColor: transparent, textColor: {colors.on-dark}, typography: {typography.button-md}, rounded: {rounded.md}, padding: 10px 18px, border: 1px solid {colors.on-dark-muted}
- button-ghost: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.button-md}, rounded: {rounded.sm}, padding: 8px 12px

Color rationale: Source pages: notion.com/ (homepage), /enterprise, /product/ai, /product/agents, /startups, /pricing. Token coverage was identical across all six pages. Brand & Primary - Notion Purple ({colors.primary}): Signature primary CTA color — the unmistakable "Get Notion free" pill button. Reserved for the dominant CTA only. - Purple Pressed ({colors.primary-pressed}): Pressed-state variant - Purple Deep ({colors.primary-deep}): Deeper variant for emphasis - Brand Navy ({colors.brand-navy}): Hero band background — deep navy - Brand Navy Deep ({colors.brand-navy-deep}): Deeper navy for promo banner - Brand Navy Mid ({colors.brand-navy-mid}): Mid-spectrum navy - Link Blue ({colors.link-blue}): Inline text link blue (NOT primary CTA) - Link Blue Pressed ({colors.link-blue-pressed}): Pressed-state link blue Brand Color Spectrum (echoes live product database properties) - Brand Pink ({colors.brand-pink}): Pink accent - Brand Pink Deep ({colors.brand-pink-deep}): Deeper pink - Brand Orange ({colors.brand-orange}): Orange accent - Brand Orange Deep ({colors.brand-orange-deep}): Deeper orange-rust - Brand Purple ({colors.brand-purple}): Purple accent variant - Brand Purple 300 ({colors.brand-purp...

Typography rationale: Font Family Notion Sans (primary): Notion's custom Inter-based variable typeface. Fallbacks: Inter, -apple-system, system-ui, 'Segoe UI', Helvetica, sans-serif. Humanist-geometric character used across every UI surface. Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.hero-display} | 80px | 600 | 1.05 | -2px | Hero ("Meet the night shift") | | {typography.display-lg} | 56px | 600 | 1.10 | -1px | Section openers | | {typography.heading-1} | 48px | 600 | 1.15 | -0.5px | Page-level headlines ("Try for free") | | {typography.heading-2} | 36px | 600 | 1.20 | -0.5px | Subsection headlines ("Keep work moving 24/7") | | {typography.heading-3} | 28px | 600 | 1.25 | 0 | Card titles | | {typography.heading-4} | 22px | 600 | 1.30 | 0 | Feature tile titles | | {typography.heading-5} | 18px | 600 | 1.40 | 0 | FAQ questions | | {typography.subtitle} | 18px | 400 | 1.50 | 0 | Hero subtitle | | {typography.body-md} | 16px | 400 | 1.55 | 0 | Primary body text | | {typography.body-md-medium} | 16px | 500 | 1.55 | 0 | Body emphasis | | {typography.body-sm} | 14px | 400 | 1.50 | 0 | Secondary body | | {typography.body-sm-medium} | 14px |...

Layout system: Spacing System - Base unit: 4px (8px primary increment) - Tokens: {spacing.xxs} (4px) through {spacing.hero} (120px) - Section rhythm: Marketing pages use {spacing.section-lg} (96px); pricing tightens to {spacing.section} (64px) Grid & Container - 1280px max-width with 32px gutters - Pricing: 4-tier card row at desktop with dense comparison table - Homepage: centered hero with the source brand mockup below buttons; alternating colorful feature card sections Whitespace Philosophy Marketing surfaces use generous breathing room between feature card bands. the source brand mockup card on hero gets full-width treatment with deep drop shadow.

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | 0 (flat) | No shadow; {colors.hairline} border | Default cards, table rows | | 1 (subtle) | rgba(15, 15, 15, 0.04) 0px 1px 2px 0px | Hover-elevated tiles | | 2 (card) | rgba(15, 15, 15, 0.08) 0px 4px 12px 0px | Feature cards | | 3 (mockup) | rgba(15, 15, 15, 0.20) 0px 24px 48px -8px | Hero the source brand mockup card | | 4 (modal) | rgba(15, 15, 15, 0.16) 0px 16px 48px -8px | Modals, dropdowns | Decorative Depth - Hero the source brand mockup card uses deep diffuse drop shadow (Level 3) — significant elevation against the navy band - Pastel feature cards carry their own visual weight via tint backgrounds - Sticky-note dot illustrations and mesh wires add atmospheric decoration to navy hero

Shape language: Border Radius Scale | Token | Value | Use | |---|---|---| | {rounded.xs} | 4px | Tag chips | | {rounded.sm} | 6px | Type badges | | {rounded.md} | 8px | Buttons, inputs, search-pill | | {rounded.lg} | 12px | Cards, pricing tiers, agent tiles, the source brand mockup | | {rounded.xl} | 16px | Larger feature panels | | {rounded.xxl} | 20px | Featured product showcases | | {rounded.xxxl} | 24px | Larger feature cards | | {rounded.full} | 9999px | Status badges, pill tabs (NOT regular buttons) | Notion's geometry is sober-editorial — {rounded.md} (8px) buttons distinguish it from pill-button-everywhere brands.

Component language: Per the no-hover policy, hover states are NOT documented. Buttons button-primary — Signature purple rectangular primary CTA, the dominant action. - Background {colors.primary}, text {colors.on-primary}, typography {typography.button-md}, padding 10px 18px, rounded {rounded.md}. - Pressed state button-primary-pressed deepens to {colors.primary-pressed}. - Disabled state uses {colors.hairline} background. button-dark — Black rectangular CTA on light backgrounds. - Background {colors.ink-deep}, text {colors.on-dark}, typography {typography.button-md}, padding 10px 18px, rounded {rounded.md}. button-secondary — Outlined rectangular for secondary actions ("Request a demo"). - Background transparent, text {colors.ink}, border 1px solid {colors.hairline-strong}, typography {typography.button-md}, padding 10px 18px, rounded {rounded.md}. button-on-dark — White button on dark hero bands. - Background {colors.on-dark}, text {colors.ink}, typography {typography.button-md}, padding 10px 18px, rounded {rounded.md}. button-secondary-on-dark — Outlined button on dark. - Background transparent, text {colors.on-dark}, border 1px solid {colors.on-dark-muted}, typography {typography.button-md}, padd...

Guardrails: Do - Use {colors.primary} (purple) as the dominant CTA across all surfaces — it's the brand's recognizable signal - Pair deep navy hero bands ({colors.brand-navy}) with the purple button + decorative sticky-note dots - Use pastel feature card tints (peach, rose, mint, lavender, sky, yellow) generously - Use {colors.card-tint-yellow-bold} for high-emphasis "Ask the assistant"-style banner cards - Apply {rounded.md} (8px) to buttons consistently — Notion uses rectangles, not pills - Apply {rounded.lg} (12px) to all card families - Maintain Notion-Sans across every UI surface - Use the the source brand mockup card on hero bands to show actual product UI Don't - Don't use the purple for body text or large background...
```
