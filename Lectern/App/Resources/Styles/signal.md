# Signal

**ID:** `signal`  
**Category:** data  
**Theme:** dark  
**Vibe:** Technical

## Color palette

- `#000000`
- `#ffffff`
- `#2b89ff`
- `#b2b6bd`
- `#656a76`
- `#15181e`
- `#1f232b`
- `#3b3d45`
- `#252830`
- `#7b42bc`

## Typography

Families: hashicorpSans. Weights: 500, 600, 700.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: HashiCorp

Design token description: An enterprise-infrastructure marketing canvas built around a near-black ground (000000) and a system of per-product accent colors — Terraform purple, Vault yellow, Consul pink, Waypoint cyan, Vagrant blue — that act as identity tokens rather than decorative palette. Display type is hashicorpSans set in 600/700 with tight 1.17–1.21 line-heights; body type runs the same family at 500 weight with relaxed 1.50–1.71 line-heights. layered rectangular token motif live as charcoal surfaces with 1px translucent gray borders; product showcase layered rectangular token motif lift into per-product chromatic gradients. The system reads as confident, technical, and intentionally multi-product — every section quietly signals which HashiCorp tool it represents.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- Detected source-domain vocabulary: search/productivity software, finance/banking. Translate it into reusable visual behavior, not literal imagery.
- Avoid literal source imagery unless the exact slide text or visual direction explicitly requests it: search bars, search result pages, browser chrome, or app screenshots; product logos, app icons, map pins, or play-button branding; credit cards, debit cards, bank apps, cash, coins, trading screens, or crypto coins; financial product mockups unless requested by slide content.

Overall visual personality: HashiCorp's marketing canvas is a near-black ground that serves a multi-product dynamic transaction/data-flow pattern without ever feeling generic. The dominant surface is {colors.canvas} (pure black) layered with {colors.surface-1} charcoal layered rectangular token motif and 1px translucent gray hairlines. The the source brand is monochrome — white pill-rounded buttons ({components.button-primary}), white type, gray secondary type — but the system is held together by a palette of per-product accent colors that signal which HashiCorp tool a given section belongs to: Terraform purple, Vault yellow, Consul red, Waypoint cyan, Vagrant blue, Nomad green, Boundary coral. Display type is hashicorpSans at weights 600/700 with tight line-heights (1.17–1.21); body type is the same family at 500 weight with deliberately relaxed line-heights (1.50–1.71) — the contrast feels editorial, not enterprise-templated. CTAs use small {rounded.md} 8px corners rather than pills, which keeps the system reading as developer-facing rather than consumer-y. The signature device is the product-card family — each HashiCorp product gets its own colored layered rectangular token motif variant on the home and i...

Color tokens:
- primary: #000000
- on-primary: #ffffff
- accent-blue: #2b89ff
- ink: #ffffff
- ink-muted: #b2b6bd
- ink-subtle: #656a76
- canvas: #000000
- surface-1: #15181e
- surface-2: #1f232b
- surface-3: #3b3d45
- hairline: #3b3d45
- hairline-soft: #252830
- inverse-canvas: #ffffff
- inverse-ink: #000000

Typography tokens:
- display-xl: family hashicorpSans, size 80px, weight 700, line 1.17, tracking -2.5px
- display-lg: family hashicorpSans, size 56px, weight 700, line 1.18, tracking -1.6px
- display-md: family hashicorpSans, size 40px, weight 600, line 1.19, tracking -1.0px
- headline: family hashicorpSans, size 28px, weight 600, line 1.21, tracking -0.6px
- card-title: family hashicorpSans, size 22px, weight 600, line 1.18, tracking -0.4px
- subhead: family hashicorpSans, size 20px, weight 600, line 1.35, tracking -0.2px
- body-lg: family hashicorpSans, size 18px, weight 500, line 1.69, tracking 0
- body: family hashicorpSans, size 16px, weight 500, line 1.50, tracking 0
- body-sm: family hashicorpSans, size 14px, weight 500, line 1.71, tracking 0
- caption: family hashicorpSans, size 13px, weight 500, line 1.38, tracking 0.2px
- button: family hashicorpSans, size 14px, weight 600, line 1.29, tracking 0
- eyebrow: family hashicorpSans, size 12px, weight 600, line 1.23, tracking 0.6px

Spacing tokens:
- hair: 1px
- xxs: 4px
- xs: 8px
- sm: 12px
- md: 16px
- lg: 24px
- xl: 32px
- xxl: 48px
- section: 96px

Radius and shape tokens:
- xs: 4px
- sm: 6px
- md: 8px
- lg: 12px
- xl: 16px
- xxl: 24px
- pill: 9999px
- full: 9999px

Component tokens:
- button-primary: backgroundColor: {colors.inverse-canvas}, textColor: {colors.inverse-ink}, typography: {typography.button}, rounded: {rounded.md}, padding: 10px 18px
- button-primary-pressed: backgroundColor: {colors.inverse-canvas}, textColor: {colors.inverse-ink}, typography: {typography.button}, rounded: {rounded.md}
- button-secondary: backgroundColor: {colors.surface-2}, textColor: {colors.ink}, typography: {typography.button}, rounded: {rounded.md}, padding: 10px 18px
- button-tertiary: backgroundColor: {colors.canvas}, textColor: {colors.ink}, typography: {typography.button}, rounded: {rounded.md}, padding: 10px 18px
- button-product-terraform: backgroundColor: {colors.product-terraform}, textColor: {colors.ink}, typography: {typography.button}, rounded: {rounded.md}, padding: 10px 18px
- button-product-vault: backgroundColor: {colors.product-vault}, textColor: {colors.inverse-ink}, typography: {typography.button}, rounded: {rounded.md}, padding: 10px 18px
- button-product-waypoint: backgroundColor: {colors.product-waypoint}, textColor: {colors.inverse-ink}, typography: {typography.button}, rounded: {rounded.md}, padding: 10px 18px
- product-card: backgroundColor: {colors.surface-1}, textColor: {colors.ink}, typography: {typography.body}, rounded: {rounded.lg}, padding: 24px

Color rationale: Source pages: hashicorp.com/en (home), /en/infrastructure-cloud, /en/products/terraform, /en/pricing, /en/resources?contentType=PDF. Brand & Accent - Black ({colors.primary}): The system primary surface. Canvas, footer, comparison tables, hero — all black. - White ({colors.on-primary}): Inverse text on black; canvas of button-primary. - Accent Blue ({colors.accent-blue}): Hyperlinks across the marketing surface. - Visited Purple ({colors.semantic-visited}): Visited-link state. Surface - Canvas ({colors.canvas}): Default page background. - Surface 1 ({colors.surface-1}): Charcoal one step above canvas — feature layered rectangular token motif, pricing layered rectangular token motif, resource tiles. - Surface 2 ({colors.surface-2}): Two steps above — featured pricing layered rectangular token motif, secondary buttons, hovered product the source brand. - Surface 3 ({colors.surface-3}): Three steps above — small chips, badges, sub-nav backgrounds. - Hairline ({colors.hairline}): 1px borders on layered rectangular token motif and dividers. - Hairline Soft ({colors.hairline-soft}): Subtler dividers — comparison-table rows. - Inverse Canvas ({colors.inverse-canvas}): Pure white — used a...

Typography rationale: Font Family - hashicorpSans — HashiCorp's proprietary marketing typeface. Geometric, clean, slightly humanist. Fallback stack hashicorpSansFallback96f0ca (system font), then -apple-system, BlinkMacSystemFont, Segoe UI, helvetica, arial. The same family carries display, body, button, and caption — no separate display + body pairing. Hierarchy is carried by weight (500 body / 600 emphasis / 700 display) and by a deliberate line-height contrast (tight on display, relaxed on body). Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.display-xl} | 80px | 700 | 1.17 | -2.5px | Largest hero headline | | {typography.display-lg} | 56px | 700 | 1.18 | -1.6px | Section opener headlines | | {typography.display-md} | 40px | 600 | 1.19 | -1.0px | Sub-section headlines | | {typography.headline} | 28px | 600 | 1.21 | -0.6px | Pricing tier titles, CTA banner heading | | {typography.card-title} | 22px | 600 | 1.18 | -0.4px | Feature layered rectangular token motif title | | {typography.subhead} | 20px | 600 | 1.35 | -0.2px | Long-form intro paragraphs | | {typography.body-lg} | 18px | 500 | 1.69 | 0 | Hero subhead, lead body | | {typograp...

Layout system: Spacing System - Base unit: 8px (the primary increments are 4 / 8 / 12 / 16 / 24 / 32 / 48). - Tokens (front matter): {spacing.hair} 1px · {spacing.xxs} 4px · {spacing.xs} 8px · {spacing.sm} 12px · {spacing.md} 16px · {spacing.lg} 24px · {spacing.xl} 32px · {spacing.xxl} 48px · {spacing.section} 96px. - layered rectangular token motif interior padding: {spacing.lg} 24px on product layered rectangular token motif; {spacing.xl} 32px on pricing layered rectangular token motif; {spacing.xxl} 48px on CTA banners. - Button padding: 10px vertical · 18px horizontal on {components.button-primary}. - Universal rhythm constant: {spacing.section} (96px) vertical gap between major sections. Grid & Container - Max content width sits around 1280px with side gutters scaling from {spacing.xxl} on desktop down to {spacing.lg} on mobile. - Product layered rectangular token motif grids are 3-up on desktop, 2-up at tablet, 1-up on mobile. - Pricing tier grid is 3-up across desktop; comparison table beneath uses fixed-width left column. - Resource directory (PDF library) uses 4-up dense thumbnail grid. Whitespace Philosophy The dark canvas IS the whitespace. Sections separate by surface lift (canvas →...

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | 0 (flat) | No shadow, no border | Canvas-mounted display type, hero, footer | | 1 (charcoal lift) | {colors.surface-1} background + 1px rgba(178,182,189,0.1) border | Default layered rectangular token motif, resource tiles, pricing layered rectangular token motif | | 2 (surface-2 lift) | {colors.surface-2} background + 1px {colors.hairline} border | Featured pricing layered rectangular token motif, hovered layered rectangular token motif, sub-nav | | 3 (product chromatic) | Per-product accent color background — Terraform purple, Vault yellow, Waypoint cyan | Product showcase layered rectangular token motif | The product chromatic level isn't a "modal lift" — it's an identity device. A Terraform layered rectangular token motif sits at the same z-plane as a feature-card; the difference is meaning, not depth. Decorative Depth - 3D product visuals — isometric purple cubes (Terraform), translucent yellow safes (Vault), and similar product-tinted illustrations sit in the right column of hero sections. - 1px translucent gray hairlines are the dominant edge — borders are visible without competing. - No drop shadows on dark. layered rectangular t...

Shape language: Border Radius Scale | Token | Value | Use | |---|---|---| | {rounded.xs} | 4px | Small chips / badges | | {rounded.sm} | 6px | Inline tag | | {rounded.md} | 8px | All CTA buttons, form inputs, list items | | {rounded.lg} | 12px | Feature layered rectangular token motif, product layered rectangular token motif, pricing layered rectangular token motif | | {rounded.xl} | 16px | Large illustrative tiles | | {rounded.xxl} | 24px | CTA banner panels | | {rounded.pill} | 9999px | Eyebrow-style product pills (small chips) | | {rounded.full} | 9999px | Avatar circles (rare on marketing) | Photography & Illustration Geometry - Product 3D illustrations use full-bleed within their container — no rounded inner mask. - Logo chips in the customer marquee sit on {rounded.sm} 6px tiles with 1px hairline. - Resource thumbnails use {rounded.lg} 12px corners.

Component language: Buttons button-primary — White rounded-rect CTA. Used as primary CTA on all pages. - Background {colors.inverse-canvas}, text {colors.inverse-ink}, type {typography.button}, padding 10px 18px, rounded {rounded.md}. - Pressed state lives in button-primary-pressed. button-secondary — Charcoal rounded-rect. Secondary CTA, "Read approachable modular product geome...
```
