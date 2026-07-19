# Spearmint

**ID:** `spearmint`  
**Category:** developer  
**Theme:** light  
**Vibe:** Technical

## Color palette

- `#0a0a0a`
- `#ffffff`
- `#00d4a4`
- `#00b48a`
- `#7cebcb`
- `#3772cf`
- `#c37d0d`
- `#1ba673`
- `#d45656`
- `#888888`

## Typography

Families: Geist Mono, Inter. Weights: 400, 500, 600.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Mintlify

Design token description: Mintlify presents documentation infrastructure with a dual-mode aesthetic — atmospheric sky-gradient marketing heroes (cloud illustration backdrops, soft cream-to-blue washes) paired with dense developer-grade documentation surfaces. The system uses Inter for UI prose, Geist Mono for code, and a signature Mintlify green ({colors.brand-green}) reserved for accent CTAs and active states. Black-pill primary buttons dominate marketing, white-on-dark inversions appear on dark hero bands, and a 3-column documentation layout (sidebar / prose / TOC) anchors the developer experience. Coverage spans homepage, startups program, pricing comparison, and the live tabs documentation page.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- Detected source-domain vocabulary: finance/banking, AI/infrastructure, search/productivity software. Translate it into reusable visual behavior, not literal imagery.
- Avoid literal source imagery unless the exact slide text or visual direction explicitly requests it: credit cards, debit cards, bank apps, cash, coins, trading screens, or crypto coins; financial product mockups unless requested by slide content; GPU cards, chips, circuit-board hero shots, server-rack product shots, robots, or chatbot mascots; company logos or AI assistant portraits unless requested by the slide content; search bars, search result pages, browser chrome, or app screenshots; product logos, app icons, map pins, or play-button branding.

Overall visual personality: Mintlify positions itself at the intersection of polished marketing presentation and developer-grade documentation density. The home and startups pages open with cinematic atmospheric heroes — soft sky-gradient backdrops with cloud illustrations on the homepage, dark teal-to-mint gradients with a rocket launch on the startups page — that feel more like a SaaS landing aesthetic than a developer tool. Then the deeper surfaces (pricing comparison, live documentation pages) collapse into dense, high-information layouts where Inter body type carries 14–16px copy across long-form prose, syntax-highlighted code blocks, and 3-column documentation grids. The brand's signature mint green ({colors.brand-green}) appears sparingly but decisively — on the hero "Get started" pill button, the green checkmark icons inside feature lists, the "Featured" pricing tier border, and active state indicators inside approachable modular product geometry UI. Black-pill primary buttons dominate the marketing flow; white-on-dark inversions appear on dark hero bands. The signature pairing of Inter (body, headings) with Geist Mono (code blocks, inline references, type signatures) reinforces the developer-tool DN...

Color tokens:
- primary: #0a0a0a
- on-primary: #ffffff
- brand-green: #00d4a4
- brand-green-deep: #00b48a
- brand-green-soft: #7cebcb
- brand-tag: #3772cf
- brand-warn: #c37d0d
- brand-annotate: #1ba673
- brand-error: #d45656
- brand-cursor: #888888
- hero-sky-from: #87a8c8
- hero-sky-to: #f5e9d8
- hero-dark-from: #1a3d4a
- hero-dark-to: #2d5a4f

Typography tokens:
- hero-display: family Inter, size 72px, weight 600, line 1.05, tracking -2px
- display-lg: family Inter, size 56px, weight 600, line 1.10, tracking -1.5px
- heading-1: family Inter, size 48px, weight 600, line 1.10, tracking -1px
- heading-2: family Inter, size 36px, weight 600, line 1.20, tracking -0.5px
- heading-3: family Inter, size 28px, weight 600, line 1.25
- heading-4: family Inter, size 22px, weight 600, line 1.30
- heading-5: family Inter, size 18px, weight 600, line 1.40
- subtitle: family Inter, size 18px, weight 400, line 1.50
- body-md: family Inter, size 16px, weight 400, line 1.50
- body-md-medium: family Inter, size 16px, weight 500, line 1.50
- body-sm: family Inter, size 14px, weight 400, line 1.50
- body-sm-medium: family Inter, size 14px, weight 500, line 1.50

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
- xxl: 24px
- full: 9999px

Component tokens:
- button-primary: backgroundColor: {colors.primary}, textColor: {colors.on-primary}, typography: {typography.button-md}, rounded: {rounded.full}, padding: 10px 20px
- button-primary-pressed: backgroundColor: {colors.charcoal}, textColor: {colors.on-primary}
- button-primary-disabled: backgroundColor: {colors.hairline}, textColor: {colors.muted}
- button-accent-green: backgroundColor: {colors.brand-green}, textColor: {colors.primary}, typography: {typography.button-md}, rounded: {rounded.full}, padding: 10px 20px
- button-on-dark: backgroundColor: {colors.on-dark}, textColor: {colors.primary}, typography: {typography.button-md}, rounded: {rounded.full}, padding: 10px 20px
- button-secondary: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.button-md}, rounded: {rounded.full}, padding: 10px 20px, border: 1px solid {colors.hairline}
- button-ghost: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.button-md}, rounded: {rounded.md}, padding: 8px 12px
- button-link: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.body-sm-medium}, padding: 0

Color rationale: Source pages: mintlify.com/ (homepage), /startups (program page), /pricing (comparison), /approachable modular product geometry/components/tabs (live documentation). Token coverage was identical across all four pages. Brand & Accent - Mintlify Mint ({colors.brand-green}): Signature accent — used on hero "Get started" pill button, green checkmarks in feature lists, featured pricing tier border accent, sidebar active indicator dots. - Deep Mint ({colors.brand-green-deep}): Pressed/active variant of the mint accent. - Soft Mint ({colors.brand-green-soft}): Subtle background tint for success states and confirmation surfaces. - Brand Tag ({colors.brand-tag}): Documentation tag and reference color (used in <Tabs JSX-style annotations and code-tag computational precision motif). - Brand Annotate ({colors.brand-annotate}): Inline code annotation green (used in twoslash code annotation system). - Brand Warn ({colors.brand-warn}): Code warning highlight (deprecated, caution). - Brand Error ({colors.brand-error}): Red used for required-field labels and error highlight. - Testimonial Orange ({colors.testimonial-orange}): Warm coral-orange used on the "Cursor" testimonial layered rectangular t...

Typography rationale: Font Family Inter (primary): Variable typeface optimized for UI legibility. Used across every UI surface — body, headings, navigation, button labels, captions. Fallbacks: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif. Geist Mono (code): Monospace typeface used inside code blocks, inline code references, type signatures (e.g. string, number, boolean), and property names in API documentation. Fallbacks: 'SF Mono', Menlo, Consolas, 'Geist Mono Fallback', monospace. The brand uses no italic variants of either face — emphasis comes from weight (500/600), color shift, or background highlighting (in code references). Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.hero-display} | 72px | 600 | 1.05 | -2px | Marketing hero display ("The intelligent Knowledge Platform") | | {typography.display-lg} | 56px | 600 | 1.10 | -1.5px | Major section opener ("Built for the intelligence age") | | {typography.heading-1} | 48px | 600 | 1.10 | -1px | Page-level headlines ("Pricing on your terms") | | {typography.heading-2} | 36px | 600 | 1.20 | -0.5px | Section headlines ("Apply to the Mintlify startup program") | | {typography...

Layout system: Spacing System - Base unit: 4px (8px primary increment) - Tokens: {spacing.xxs} (4px) · {spacing.xs} (8px) · {spacing.sm} (12px) · {spacing.md} (16px) · {spacing.lg} (20px) · {spacing.xl} (24px) · {spacing.xxl} (32px) · {spacing.xxxl} (40px) · {spacing.section-sm} (48px) · {spacing.section} (64px) · {spacing.section-lg} (96px) · {spacing.hero} (120px) - Section rhythm: Marketing pages use {spacing.section-lg} (96px) between major bands; pricing comparison tightens to {spacing.section} (64px); documentation surfaces use {spacing.xxl} (32px) between subsections - layered rectangular token motif internal padding: Standard {spacing.xl} (24px) for compact layered rectangular token motif; {spacing.xxl} (32px) for pricing layered rectangular token motif and feature panels; testimonial layered rectangular token motif pushes to {spacing.section} (64px) for hero-card presence Grid & Container - Marketing pages use a 1280px max-width with 32px gutters - Hero and feature bands often use 2-column splits (text left, illustration/mockup right) - Pricing page renders 3 tier layered rectangular token motif in a row at desktop (FREE / Lift Off / Custom), then a comprehensive feature comparison tabl...

Depth and hierarchy: The system runs predominantly flat with strategic atmospheric depth. | Level | Treatment | Use | |---|---|---| | 0 (flat) | No shadow; {colors.hairline} border | Default layered rectangular token motif, table rows, form inputs | | 1 (subtle) | rgba(0, 0, 0, 0.04) 0px 1px 2px 0px | Hover-elevated tiles, subtle highlights | | 2 (layered rectangular token motif) | rgba(0, 0, 0, 0.08) 0px 4px 12px 0px | Standard feature layered rectangular token motif | | 3 (mockup) | rgba(0, 0, 0, 0.12) 0px 24px 48px -8px | Hero product mockup framing — the deep diffuse drop on the homepage hero approachable modular product geometry preview | | 4 (brand-tinted) | rgba(0, 212, 164, 0.08) 0px 8px 24px | Featured pricing tier glow | Decorative Depth - The homepage hero uses an atmospheric photographic backdrop (cloud illustration on sky-gradient) for depth — no shadow needed; the imagery does the work - The startups hero uses a similar treatment with a rocket-launch illustration cutting across the dark teal gradient - Code blocks carry their own internal depth via syntax-highlighting color hierarchy on the dark surface; no shadow used

Shape language: Border Radius Scale | Token | Value | Use | |---|---|---| | {rounded.xs} | 4px | Inline code computational precision motif, micro tags | | {rounded.sm} | 6px | Sidebar nav items, type badges | | {rounded.md} | 8px | Inputs, search pill, code blocks, secondary layered rectangular token motif | | {rounded.lg} | 12px | Standard layered rectangular token motif, pricing tiers, hero mockup, FAQ items | | {rounded.xl} | 16px | Larger feature panels | | {rounded.xxl} | 24px | Featured product showcase tiles | | {rounded.full} | 9999px | All buttons, pill tabs, badges | The radius scale is tightly disciplined — the brand never uses a corner softening between {rounded.md} (8px) and {rounded.lg} (12px) for the same component family. Pill buttons ({rounded.full}) are used universally; rectangular layered rectangular token motif use {rounded.lg} (12px) consistently. Photography Geometry - Hero illustrations (cloud, rocket) sit on full-bleed gradient backdrops with no internal framing - Customer logo walls use 1:1 ratio cells without rounding (logos are presented inline as wordmarks) - Testimonial photos use 1:1 aspect with {rounded.md} (8px) softening - Code editor mockup hero image uses {roun...

Component language: Per the no-hover policy, hover states are NOT documented. Default and pressed/active states only. Buttons button-primary — Black pill primary CTA, the dominant action across all surfaces. - Background {colors.primary}, text {colors.on-primary}, typography {typography.bu...
```
