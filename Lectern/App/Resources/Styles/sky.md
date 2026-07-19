# Sky

**ID:** `sky`  
**Category:** consumer  
**Theme:** light  
**Vibe:** Minimal

## Color palette

- `#1a91f0`
- `#016fd0`
- `#0f141e`
- `#1e2532`
- `#656e83`
- `#828ba2`
- `#d9deeb`
- `#e7eaf4`
- `#ffffff`
- `#f7f9fc`

## Typography

Families: "TT Commons, Inter, -apple-system, BlinkMacSystemFont, sans-serif". Weights: 400, 500, 600.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Free Resume Builder

Design token description: A confident, document-first utility anchored on a near-pure white canvas (f7f9fc), where a single vivid blue (1a91f0) carries every primary CTA and brand accent. The system is built on a restricted chromatic diet, with every other surface expressed as the faintest wash of color (e.g., f1f2ff) to separate content blocks without adding noise. Typography is geometric and tightly set, running a single custom sans-serif at modest weights with unconventionally tight line-heights on display sizes to create a poster-like feel. The lack of drop shadows or gradients keeps everything feeling like a fresh worksheet: clean paper, blue ballpoint annotations, and a clear focus on utility.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- No dominant source-domain vocabulary was detected, but still avoid copying example subject matter from the design brief.
- Avoid brand logos, product shots, mascot imagery, packaging, buildings, people, or industry-specific objects unless requested by the slide content.

Overall visual personality: This is a confident, document-first utility system. Its foundation is a near-pure white canvas ({colors.canvas}) where a single vivid blue ({colors.primary} — 1a91f0) is the only voice allowed to interrupt the page. The system is built on a restricted chromatic diet — one near-black ink for headlines ({colors.ink}), one primary blue, and one secondary violet ({colors.accent-iris}) — with every other surface expressed as the faintest wash of color ({colors.surface-accent-lavender}, {colors.surface-accent-mint}) to separate content blocks without adding noise. Typography is geometric and tightly set. A single custom sans-serif carries the entire hierarchy, from 14px helper text ({typography.caption}) to a 67px display headline ({typography.hero-display}). A signature characteristic is the unconventionally tight line-height (0.96) on display sizes, which produces a dense, poster-like headline feel. The lack of drop shadows or gradients keeps everything feeling like a productivity tool rather than a marketing site. The result reads like a fresh worksheet — clean paper, blue ballpoint annotations, and the occasional green check. Key Characteristics: - Single accent color: {colors.prima...

Color tokens:
- primary: #1a91f0
- primary-active: #016fd0
- ink: #0f141e
- body: #1e2532
- muted: #656e83
- muted-strong: #828ba2
- hairline: #d9deeb
- border-soft: #e7eaf4
- canvas: #ffffff
- surface-soft: #f7f9fc
- surface-accent-lavender: #f1f2ff
- surface-accent-mint: #e7f4ed
- surface-accent-blush: #ffebe4
- surface-accent-rose: #edd7df

Typography tokens:
- hero-display: family TT Commons, Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 67px, weight 400, line 0.96, tracking 1.4px
- display-lg: family TT Commons, Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 40px, weight 400, line 1.07, tracking 0.84px
- display-md: family TT Commons, Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 31px, weight 500, line 1.14, tracking 0.65px
- title-lg: family TT Commons, Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 24px, weight 600, line 1.17, tracking 0.5px
- title-md: family TT Commons, Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 19px, weight 500, line 1.22, tracking 0.4px
- body-md: family TT Commons, Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 16px, weight 400, line 1.25, tracking 0.34px
- body-sm: family TT Commons, Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 15px, weight 400, line 1.25, tracking 0.3px
- caption: family TT Commons, Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 14px, weight 400, line 1.43, tracking 0.29px
- button: family TT Commons, Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 16px, weight 500, line 1, tracking 0.34px
- nav-link: family TT Commons, Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 16px, weight 400, line 1, tracking 0.34px

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
- md: 12px
- lg: 16px
- xl: 20px
- xxl: 36px
- pill: 100px

Component tokens:
- button-primary: backgroundColor: {colors.primary}, textColor: {colors.on-primary}, typography: {typography.button}, rounded: {rounded.xxl}, padding: 18px 24px
- button-primary-active: backgroundColor: {colors.primary-active}, textColor: {colors.on-primary}, rounded: {rounded.xxl}
- button-ghost: backgroundColor: transparent, textColor: {colors.primary}, typography: {typography.button}, padding: 8px 4px
- top-nav: backgroundColor: {colors.canvas}, textColor: {colors.body}, typography: {typography.nav-link}, height: 64px
- hero-band: backgroundColor: {colors.surface-soft}, textColor: {colors.ink}, typography: {typography.hero-display}, padding: 80px 0
- preview-card: backgroundColor: {colors.canvas}, rounded: {rounded.lg}
- step-list-card: backgroundColor: {colors.canvas}, rounded: {rounded.lg}, padding: 24px
- feature-card-lavender: backgroundColor: {colors.surface-accent-lavender}, textColor: {colors.ink}, rounded: {rounded.xl}, padding: 24px

Color rationale: Brand & Accent - Primary Blue ({colors.primary} — 1a91f0): The single brand color. Used for primary CTA backgrounds, inline text highlights, decorative icon strokes, and large stat numbers. - Primary Blue Active ({colors.primary-active} — 016fd0): The press / hover-darker variant of the primary blue. - Accent Iris ({colors.accent-iris} — 5660e8): A secondary violet accent used for decorative icons and step indicators. It should not compete with the primary blue for attention. Surface - Canvas ({colors.canvas} — ffffff): The base page floor, card surfaces, and text color on colored fills. - Surface Soft ({colors.surface-soft} — f7f9fc): A faint off-white wash for hero sections and subtle surface elevation below cards. - Tinted Surfaces ({colors.surface-accent-lavender}, {colors.surface-accent-mint}, {colors.surface-accent-blush}): Barely-there pastel washes used for the background of feature cards to add soft differentiation. - Surface Dark ({colors.surface-dark} — 1a1c6a): A deep midnight blue used for high-contrast callouts or decorative surfaces. Text - Ink ({colors.ink} — 0f141e): Strongest text color, reserved for headlines and other high-emphasis display type. - Body ({colors...

Typography rationale: Font Family The system runs on a single geometric sans-serif family (TT Commons or a close substitute like Inter) for all typographic roles. It relies on a well-defined scale of size and weight to establish hierarchy, rather than introducing a second typeface. Weights used are primarily 400 (body), 500 (UI controls), and 600 (titles). Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.hero-display} | 67px | 400 | 0.96 | 1.4px | The main H1 in the hero section. Tight leading is critical. | | {typography.display-lg} | 40px | 400 | 1.07 | 0.84px | Large section headlines. | | {typography.display-md} | 31px | 500 | 1.14 | 0.65px | Stat counters and sub-section heads. | | {typography.title-lg} | 24px | 600 | 1.17 | 0.5px | Titles on large feature cards. | | {typography.title-md} | 19px | 500 | 1.22 | 0.4px | Subheadings and smaller titles. | | {typography.body-md} | 16px | 400 | 1.25 | 0.34px | Default running-text for paragraphs. | | {typography.body-sm} | 15px | 400 | 1.25 | 0.3px | Smaller descriptive text. | | {typography.caption} | 14px | 400 | 1.43 | 0.29px | Helper text, metadata, and fine print. | | {typography.butto...

Layout system: Spacing System - Base unit: 4px. - Tokens: A standard scale from {spacing.xxs} (4px) to {spacing.xxl} (48px). - Section padding (vertical): {spacing.section} (80px) is used to create a calm, breathable rhythm between major content blocks. - Card internal padding: {spacing.lg} (24px) is standard for most content cards and feature tiles. - Gutters: {spacing.lg} (24px) between cards in multi-column grids. Grid & Container - Max content width: 1200px, centered. - Page Structure: Pages are typically built as a vertical sequence of full-width bands, alternating between {colors.canvas} and {colors.surface-soft} backgrounds. These bands contain either a single centered component or a 2-up, 3-up, or 4-up grid of feature cards. - Hero: Often a two-column split, with text on the left and a visual element on the right, set on a {colors.surface-soft} background.

Depth and hierarchy: The system is intentionally and strictly flat. Depth is communicated exclusively through stepping background colors and adding 1px hairlines. - Level 0 (Canvas): {colors.canvas} is the base floor. - Level 1 (Soft Surface): {colors.surface-soft} provides a subtle lift for entire sections, like the hero. - Level 2 (Cards): Cards sit on either Level 0 or 1, and are delineated by a {colors.hairline} border or a tinted background fill ({colors.surface-accent-lavender}, etc.). There are no drop shadows, gradients, or other skeuomorphic depth cues. This reinforces the "clean worksheet" aesthetic.

Shape language: Border Radius Scale The system uses a generous and well-defined radius scale to create a soft, approachable feel. | Token | Value | Use | |---|---|---| | {rounded.sm} | 4px | Small UI elements like inputs and icons. | | {rounded.md} | 12px | Compact feature tiles. | | {rounded.lg} | 16px | Standard content cards. | | {rounded.xl} | 20px | Larger, more prominent feature cards. | | {rounded.xxl} | 36px | Primary CTA buttons. This aggressive radius is a key signature. | | {rounded.pill} | 100px | Tags and other small, pill-shaped elements. | Visual Elements Media containers, such as those holding product visuals, use {rounded.lg} (16px) corners and are sometimes given a slight rotation (-2° to 3°) to feel placed and dynamic rather than rigidly aligned.

Component language: Buttons - button-primary: The main call-to-action. It features a solid {colors.primary} background, {colors.on-primary} text, and a signature {rounded.xxl} (36px) radius. Its hover/active state, button-primary-active, darkens to {colors.primary-active}. - button-ghost: A secondary action styled as a text link. It has no background or border, with text in {colors.primary}. An underline appears on hover. Navigation & Page Structure - top-nav: A sticky top navigation bar with a {colors.canvas} background and a 1px {colors.hairline} bottom border. It holds the main menu links and a primary CTA on the right. - hero-band: The large, above-the-fold section. It uses a {colors.surface-soft} background, a {typography.hero-display} headline, and a primary CTA pair. Cards & Containers - feature-card-lavender (and other tints): Large cards used to highlight key features. They are defined by their tinted background ({colors.surface-accent-lavender}), large corner radius ({rounded.xl}), and generous internal padding. - feature-tile: More compact cards, often arranged in a 4-up grid. They sit on a {colors.canvas} background with a {colors.hairline} border and have a slightly smaller radius ({roun...

Guardrails: Do - Use {colors.primary} as the only chromatic accent on neutral surfaces; let the pale washes carry the secondary palette. - Set display headlines with a line-height of 0.96 to achieve the signature poster-like feel. - Apply {rounded.xxl} (36px) to all primary buttons and {rounded.lg} (16px) or more to cards. - Build section rhythm with {spacing.section} (80px) vertical gaps on alternating {colors.canvas} and {colors.surface-soft} backgrounds. - Highlight a single phrase within a head...
```
