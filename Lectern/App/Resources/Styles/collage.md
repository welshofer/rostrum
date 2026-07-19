# Collage

**ID:** `collage`  
**Category:** developer  
**Theme:** light  
**Vibe:** Playful

## Color palette

- `#000000`
- `#ffffff`
- `#e6e6e6`
- `#f1f1f1`
- `#f7f7f5`
- `#dceeb1`
- `#c5b0f4`
- `#f4ecd6`
- `#efd4d4`
- `#c8e6cd`

## Typography

Families: figmaMono, figmaSans. Weights: 320, 330, 340, 400.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Figma

Design token description: A confident black-and-white editorial frame interrupted by oversized, hand-cut pastel color blocks. The marketing canvas is rigorously monochrome — figmaSans variable type, pure white surfaces, pure black ink, pill-shaped CTAs — while each story section drops the page into a saturated lime, lavender, cream, mint, or pink panel that reads like a sticky note placed on a clean desk. The result is a design system that feels both technical and joyful — a tool for serious work, made by people who like color.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- Detected source-domain vocabulary: search/productivity software. Translate it into reusable visual behavior, not literal imagery.
- Avoid literal source imagery unless the exact slide text or visual direction explicitly requests it: search bars, search result pages, browser chrome, or app screenshots; product logos, app icons, map pins, or play-button branding.

Overall visual personality: Figma's marketing canvas is, at the system level, an editor-clean black-and-white frame. The the source brand — top nav, body type, footer, primary CTA — is monochrome. Headlines are oversized {typography.display-xl} set in figmaSans with aggressive negative tracking, body copy hovers around weight 320–340 of the same variable family, and small mono {typography.eyebrow} and {typography.caption} labels (figmaMono, all-caps, positive tracking) act as section markers. Every CTA is a pill — {rounded.pill} — and the primary action across the entire site is the same black {components.button-primary} paired with the same white {components.button-secondary}. What makes the design unique is what happens between those monochrome bookends: the page repeatedly drops into oversized pastel color-block sections — lime, lavender, cream, mint, pink, coral, and a deep navy — that span the full content width with {rounded.lg} corners and {spacing.xxl} interior padding. These blocks are where the storytelling lives. They aren't accents tucked into a card; they take over a whole viewport's worth of vertical space, like a designer arranging giant sticky notes on a clean wall. FigJam is the most pastel-...

Color tokens:
- primary: #000000
- on-primary: #ffffff
- ink: #000000
- canvas: #ffffff
- inverse-canvas: #000000
- inverse-ink: #ffffff
- on-inverse-soft: #ffffff
- hairline: #e6e6e6
- hairline-soft: #f1f1f1
- surface-soft: #f7f7f5
- block-lime: #dceeb1
- block-lilac: #c5b0f4
- block-cream: #f4ecd6
- block-pink: #efd4d4

Typography tokens:
- display-xl: family figmaSans, size 86px, weight 340, line 1.00, tracking -1.72px
- display-lg: family figmaSans, size 64px, weight 340, line 1.10, tracking -0.96px
- headline: family figmaSans, size 26px, weight 540, line 1.35, tracking -0.26px
- subhead: family figmaSans, size 26px, weight 340, line 1.35, tracking -0.26px
- card-title: family figmaSans, size 24px, weight 700, line 1.45, tracking 0
- body-lg: family figmaSans, size 20px, weight 330, line 1.40, tracking -0.14px
- body: family figmaSans, size 18px, weight 320, line 1.45, tracking -0.26px
- body-sm: family figmaSans, size 16px, weight 330, line 1.45, tracking -0.14px
- link: family figmaSans, size 20px, weight 480, line 1.40, tracking -0.10px
- button: family figmaSans, size 20px, weight 480, line 1.40, tracking -0.10px
- eyebrow: family figmaMono, size 18px, weight 400, line 1.30, tracking 0.54px
- caption: family figmaMono, size 12px, weight 400, line 1.00, tracking 0.60px

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
- xs: 2px
- sm: 6px
- md: 8px
- lg: 24px
- xl: 32px
- pill: 50px
- full: 9999px

Component tokens:
- button-primary: backgroundColor: {colors.primary}, textColor: {colors.on-primary}, typography: {typography.button}, rounded: {rounded.pill}, padding: 10px 20px
- button-primary-pressed: backgroundColor: {colors.primary}, textColor: {colors.on-primary}, typography: {typography.button}, rounded: {rounded.pill}
- button-secondary: backgroundColor: {colors.canvas}, textColor: {colors.ink}, typography: {typography.button}, rounded: {rounded.pill}, padding: 8px 18px 10px
- button-tertiary-text: backgroundColor: {colors.canvas}, textColor: {colors.ink}, typography: {typography.link}, rounded: {rounded.full}, padding: 8px 12px
- button-icon-circular: backgroundColor: {colors.surface-soft}, textColor: {colors.ink}, typography: {typography.button}, rounded: {rounded.full}, size: 40px
- button-icon-circular-inverse: backgroundColor: {colors.on-inverse-soft}, textColor: {colors.inverse-ink}, typography: {typography.button}, rounded: {rounded.full}, size: 40px
- button-magenta-promo: backgroundColor: {colors.accent-magenta}, textColor: {colors.on-primary}, typography: {typography.button}, rounded: {rounded.pill}, padding: 10px 18px
- pricing-tab-default: backgroundColor: {colors.canvas}, textColor: {colors.ink}, typography: {typography.button}, rounded: {rounded.pill}, padding: 8px 18px

Color rationale: Source pages: figma.com (home), /design/, /figjam/brainstorming-tool/, /pricing/, /contact/. Brand & Accent - Black ({colors.primary}): The system primary. Every primary CTA, every headline, every body line, the marquee strip, the inverse canvas of dark sections. - White ({colors.on-primary}): Inverse text on black surfaces; also the canvas color used as the foreground of secondary pill buttons ({components.button-secondary}). - Magenta Promo ({colors.accent-magenta}): A single saturated CTA pink reserved for promotional inline buttons — appears, for example, on the lilac "Save your spot" Release Notes banner. Use scarcely; it is not a section color. Surface - Canvas ({colors.canvas}): Default page background and the body of every white card. - Inverse Canvas ({colors.inverse-canvas}): Footer, marquee strip, and a subset of "ship products"-style story sections. - Surface Soft ({colors.surface-soft}): Off-white tile background used for icon buttons, template cards, and feature illustration tiles when they sit on the white canvas. - Hairline ({colors.hairline}): 1px borders on form inputs, pricing cards, and table dividers. - Hairline Soft ({colors.hairline-soft}): Even subtler divi...

Typography rationale: Font Family - figmaSans — Figma's proprietary variable typeface; fallback stack figmaSans Fallback, SF Pro Display, system-ui, helvetica. Variable weight axis is exercised at unusually fine increments (320, 330, 340, 450, 480, 540, 700) — the design system reads as a single voice modulating rather than a stepped weight family. - figmaMono — Proprietary monospace; fallback figmaMono Fallback, SF Mono, menlo. Used exclusively for eyebrow labels and captions, always uppercase with positive letter-spacing. OpenType kern is enabled across every role. Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.display-xl} | 86px | 340 | 1.00 | -1.72px | Hero headlines (home, FigJam) | | {typography.display-lg} | 64px | 340 | 1.10 | -0.96px | Section opener headlines | | {typography.headline} | 26px | 540 | 1.35 | -0.26px | Story-block titles inside color blocks | | {typography.subhead} | 26px | 340 | 1.35 | -0.26px | Long-form intro paragraphs that sit at near-headline scale | | {typography.card-title} | 24px | 700 | 1.45 | 0 | Pricing-tier titles, feature card titles | | {typography.body-lg} | 20px | 330 | 1.40 | -0.14px | Lead body...

Layout system: Spacing System - Base unit: 8px. - Tokens (front matter): {spacing.hair} 1px · {spacing.xxs} 4px · {spacing.xs} 8px · {spacing.sm} 12px · {spacing.md} 16px · {spacing.lg} 24px · {spacing.xl} 32px · {spacing.xxl} 48px · {spacing.section} 96px. - Section interior padding: {spacing.xxl} (48px) on color-block sections. - Card interior padding: {spacing.lg} (24px) on pricing cards and template tiles. - Form input padding: {spacing.sm} 12px vertical · 14px horizontal. - Button padding: {spacing.xs} 8px vertical · {spacing.lg} 24px horizontal for pill buttons (the asymmetric 8px 18px 10px extracted on button-secondary nudges the type optically inside the pill). - Universal rhythm constant: {spacing.section} (96px) — the vertical gap between major content sections holds across home, pricing, and FigJam pages. Grid & Container - Max content width sits around 1280px (one of the explicit breakpoints), with side gutters that scale from {spacing.xxl} on desktop down to {spacing.lg} on mobile. - Three- and four-column grids on the desktop pricing comparison and FigJam template galleries. - Color-block sections break the column grid — they span content width with full bleed inside the rounded {r...

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | 0 (flat) | No shadow, no border | Default for color-block sections, inverse-canvas footer, hero | | 1 (hairline) | 1px {colors.hairline} border on {colors.canvas} | Pricing cards, form inputs, comparison table cells | | 2 (soft elevation) | Subtle drop shadow approx 0 4px 16px rgba(0,0,0,0.06) | Floating template tiles, dropdown menus | | 3 (modal) | Stronger shadow + {colors.overlay-scrim} behind | Video / image lightbox overlays | Figma's marketing system is shadow-light by design — the color blocks substitute for traditional elevation. Where most SaaS sites use a shadowed white card to draw attention, Figma uses a saturated background panel. This makes the rare actual shadow (e.g., a floating template card hovering over a cream section) feel like an exception worth noticing. Decorative Depth - Color-block sections are the primary depth device. The change from white canvas to lime / lavender / cream is the section break. - Sticky-note style component thumbnails in FigJam — slightly off-axis pastel rectangles arranged like notes on a board — read as collage, not card-stack. - Embedded product UI mocks (Figma Design panels, FigJam canvas...

Shape language: Border Radius Scale | Token | Value | Use | |---|---|---| | {rounded.xs} | 2px | Anchor / link decoration corners | | {rounded.sm} | 6px | Small chips, sub-nav tabs | | {rounded.md} | 8px | Form inputs, list items, image frames | | {rounded.lg} | 24px | Pricing cards, color-block sections, large image containers | | {rounded.xl} | 32px | Hero feature panels, oversized callouts | | {rounded.pill} | 50px | All text CTAs (primary, secondary, tab toggles) | | {rounded.full} | 9999px | Circular icon buttons, comparison-table checkmark glyphs | Photography & Illustration Geometry - Image frames use {rounded.md} (8px) — generous enough to feel friendly, conservative enough to read as editorial. - Template thumbnails on the home grid sit in {rounded.md} tiles with {spacing.md} interior padding around the embedded preview. - FigJam pastel sticky-note component thumbnails preserve a small {rounded.sm} corner that mimics actual sticky paper. - No avatar circles appear in marketing surfaces — Figma's marketing avoids personification.

Component language: Buttons button-primary — The black "Get started for free" pill that appears in the top nav, every hero, and every closing CTA. - Background {colors.primary}, text {colors.on-primary}, type {typography.button}, padding 10px 20px, rounded {rounded.pill}. - Pressed state lives in button-primary-pressed (same surface; the live site relies on micro-scale rather than a darkened fill). button-secondary — White pill with black text. Used for tertiary navigation actions ("Contact sales") and as the visual counterpart to the primary pill. - Background {colors.canvas}, text {colors.ink}, type {typography.button}, padding 8px 18px 1...
```
