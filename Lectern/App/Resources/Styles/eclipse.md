# Eclipse

**ID:** `eclipse`  
**Category:** developer  
**Theme:** dark  
**Vibe:** Technical

## Color palette

- `#010102`
- `#f7f8f8`
- `#5e6ad2`
- `#0f1011`
- `#ffffff`
- `#828fff`
- `#5e69d1`
- `#d0d6e0`
- `#8a8f98`
- `#62666d`

## Typography

Families: Linear Display, Linear Mono, Linear Text. Weights: 400, 500, 600.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Linear

Design token description: A near-black product-focused marketing canvas built around 010102 (the deepest dark surface of any tool in this collection), light gray text (f7f8f8), and the signature Linear lavender-blue (5e6ad2) used as the single chromatic accent. The system reads as software-craft documentation: dense, technical, and quietly luxurious. Display type is set in the Linear custom sans (SF Pro Display fallback) at 500–700 with measured negative tracking. Cards live as charcoal panels (0f1011) with hairline borders. The accent lavender appears on the brand mark, focus rings, and a few intentional CTAs — never decoratively. Page rhythm leans on product UI screenshots framed in dark panels rather than atmospheric color.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- Detected source-domain vocabulary: search/productivity software. Translate it into reusable visual behavior, not literal imagery.
- Avoid literal source imagery unless the exact slide text or visual direction explicitly requests it: search bars, search result pages, browser chrome, or app screenshots; product logos, app icons, map pins, or play-button branding.

Overall visual personality: Linear's marketing canvas is the deepest dark surface in this collection — {colors.canvas} is 010102, essentially pure black with a faint blue tint. On top sits a four-step surface ladder ({colors.surface-1} through {colors.surface-4}) for cards, panels, and lifted tiles, with hairline borders running from {colors.hairline} (23252a) up through {colors.hairline-strong} and {colors.hairline-tertiary}. Light gray text ({colors.ink} f7f8f8) carries the body and headlines. The single chromatic accent is Linear lavender-blue {colors.primary} (5e6ad2) — used on the brand mark, focus rings, and the primary CTA button. A lighter hover state ({colors.primary-hover} 828fff) and a focus-tinted variant ({colors.primary-focus} 5e69d1) extend the same hue. Linear avoids saturated greens, oranges, reds, etc. on the marketing canvas — the only semantic color is {colors.semantic-success} (27a644) for status pills and the rare success indicator. Display type runs Linear's custom sans (with SF Pro Display fallback) at weight 500–700 with negative letter-spacing scaling from -3.0px at 80px down to 0 at body. The body family is Linear's text cut, and a Linear Mono is reserved for code snippets in produ...

Color tokens:
- primary: #5e6ad2
- on-primary: #ffffff
- primary-hover: #828fff
- primary-focus: #5e69d1
- ink: #f7f8f8
- ink-muted: #d0d6e0
- ink-subtle: #8a8f98
- ink-tertiary: #62666d
- canvas: #010102
- surface-1: #0f1011
- surface-2: #141516
- surface-3: #18191a
- surface-4: #191a1b
- hairline: #23252a

Typography tokens:
- display-xl: family Linear Display, size 80px, weight 600, line 1.05, tracking -3.0px
- display-lg: family Linear Display, size 56px, weight 600, line 1.10, tracking -1.8px
- display-md: family Linear Display, size 40px, weight 600, line 1.15, tracking -1.0px
- headline: family Linear Display, size 28px, weight 600, line 1.20, tracking -0.6px
- card-title: family Linear Display, size 22px, weight 500, line 1.25, tracking -0.4px
- subhead: family Linear Display, size 20px, weight 400, line 1.40, tracking -0.2px
- body-lg: family Linear Text, size 18px, weight 400, line 1.50, tracking -0.1px
- body: family Linear Text, size 16px, weight 400, line 1.50, tracking -0.05px
- body-sm: family Linear Text, size 14px, weight 400, line 1.50, tracking 0
- caption: family Linear Text, size 12px, weight 400, line 1.40, tracking 0
- button: family Linear Text, size 14px, weight 500, line 1.20, tracking 0
- eyebrow: family Linear Text, size 13px, weight 500, line 1.30, tracking 0.4px

Spacing tokens:
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
- button-primary: backgroundColor: {colors.primary}, textColor: {colors.on-primary}, typography: {typography.button}, rounded: {rounded.md}, padding: 8px 14px
- button-primary-pressed: backgroundColor: {colors.primary-focus}, textColor: {colors.on-primary}, typography: {typography.button}, rounded: {rounded.md}
- button-primary-hover: backgroundColor: {colors.primary-hover}, textColor: {colors.on-primary}, typography: {typography.button}, rounded: {rounded.md}
- button-secondary: backgroundColor: {colors.surface-1}, textColor: {colors.ink}, typography: {typography.button}, rounded: {rounded.md}, padding: 8px 14px
- button-tertiary: backgroundColor: {colors.canvas}, textColor: {colors.ink}, typography: {typography.button}, rounded: {rounded.md}, padding: 8px 14px
- button-inverse: backgroundColor: {colors.inverse-canvas}, textColor: {colors.inverse-ink}, typography: {typography.button}, rounded: {rounded.md}, padding: 8px 14px
- pricing-card: backgroundColor: {colors.surface-1}, textColor: {colors.ink}, typography: {typography.body}, rounded: {rounded.lg}, padding: 24px
- pricing-card-featured: backgroundColor: {colors.surface-2}, textColor: {colors.ink}, typography: {typography.body}, rounded: {rounded.lg}, padding: 24px

Color rationale: Source pages: linear.app (home), /intake, /pricing, /contact/sales, /build. Brand & Accent - Lavender-Blue ({colors.primary}): The signature Linear accent — primary CTA, brand mark, link emphasis. - Lavender Hover ({colors.primary-hover}): Lighter lavender (828fff) — hovered state of the primary CTA. - Lavender Focus ({colors.primary-focus}): Focus-ring tint (5e69d1) — focused inputs, focused buttons. - Brand Secure ({colors.brand-secure}): Muted lavender-gray (7a7fad) — used in "Linear Security" surfaces. Surface - Canvas ({colors.canvas}): Default page background — 010102, near-pure black with a faint blue tint. - Surface 1 ({colors.surface-1}): One step above canvas — feature cards, pricing cards, product screenshot panels. - Surface 2 ({colors.surface-2}): Two steps above — featured pricing card, hovered cards. - Surface 3 ({colors.surface-3}): Three steps above — line-tertiary backgrounds, sub-nav. - Surface 4 ({colors.surface-4}): Four steps above — bg-level-3, deepest lifted surface. - Hairline ({colors.hairline}): 1px borders on cards and dividers. - Hairline Strong ({colors.hairline-strong}): Stronger 1px borders — input focus rings. - Hairline Tertiary ({colors.hairline-...

Typography rationale: Font Family - Linear Display — Linear's custom display sans; fallback SF Pro Display, -apple-system, system-ui, Segoe UI, Roboto. Carries display-xl through subhead. - Linear Text — Linear's custom text sans (a slightly different cut tuned for body sizes); same fallback stack. Carries body sizes, button labels, captions. - Linear Mono — Linear's custom mono; fallback ui-monospace, SF Mono, Menlo. Used for code snippets in product screenshots and for status / ID tokens. The marketing surface treats Display and Text as one continuous voice; the family change is silent. Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.display-xl} | 80px | 600 | 1.05 | -3.0px | Largest hero headline | | {typography.display-lg} | 56px | 600 | 1.10 | -1.8px | Section opener headlines | | {typography.display-md} | 40px | 600 | 1.15 | -1.0px | Sub-section headlines | | {typography.headline} | 28px | 600 | 1.20 | -0.6px | Pricing tier titles, CTA banner heading | | {typography.card-title} | 22px | 500 | 1.25 | -0.4px | Feature card title | | {typography.subhead} | 20px | 400 | 1.40 | -0.2px | Lead body, intro paragraphs | | {typography.body-lg...

Layout system: Spacing System - Base unit: 4px. - Tokens (front matter): {spacing.xxs} 4px · {spacing.xs} 8px · {spacing.sm} 12px · {spacing.md} 16px · {spacing.lg} 24px · {spacing.xl} 32px · {spacing.xxl} 48px · {spacing.section} 96px. - Card interior padding: {spacing.lg} 24px on feature/pricing cards; {spacing.xl} 32px on testimonial cards; {spacing.xxl} 48px on CTA banners. - Pill button padding: 8px vertical · 14px horizontal — Linear's compact button spec. - Form input padding: 8px vertical · 12px horizontal. Grid & Container - Max content width sits around 1280px. - Card grids are 3-up at desktop, 2-up at tablet, 1-up at mobile. - Pricing tier grid is 3-up; comparison strip below shows checkmarks per tier. - Product screenshot panels span full content width — they're the protagonist. Whitespace Philosophy The dark canvas IS the whitespace. Sections separate by lift onto surface-1 panels, not by gaps in white. Within a panel, generous {spacing.lg} 24px gaps between content blocks; {spacing.section} 96px between sections.

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | 0 (flat) | No shadow, no border | Default for body type, hero text, footer | | 1 (charcoal lift) | {colors.surface-1} background on canvas, 1px {colors.hairline} | Default cards, product panels | | 2 (surface-2 lift) | {colors.surface-2} background, 1px {colors.hairline-strong} | Featured pricing card, hovered cards | | 3 (surface-3 lift) | {colors.surface-3} background | Sub-nav, dropdown menus | | 4 (focus ring) | 2px {colors.primary-focus} outline at 50% opacity | Focused input, focused button | Linear's depth is carried by surface ladder + hairline borders. The brand resists drop shadows on dark almost entirely. Decorative Depth - Product UI screenshots dominate as decorative depth. - No atmospheric gradients, no spotlight cards. - Subtle white edge highlight on the top edge of lifted panels — gives the dark surface a faint "pixel rendered" feel.

Shape language: Border Radius Scale | Token | Value | Use | |---|---|---| | {rounded.xs} | 4px | Small chips, status badges | | {rounded.sm} | 6px | Inline tags | | {rounded.md} | 8px | All buttons, form inputs | | {rounded.lg} | 12px | Pricing cards, feature cards, testimonial cards | | {rounded.xl} | 16px | Product screenshot panels | | {rounded.xxl} | 24px | Oversized CTA banners (rare) | | {rounded.pill} | 9999px | Pricing tab toggles, status pills | | {rounded.full} | 9999px | Avatar circles | Photography & Illustration Geometry - Product UI screenshots dominate; they sit in {rounded.xl} 16px tiles with {spacing.lg} 24px outer padding. - Customer logo tiles render at small sizes (~24px logo height) on {colors.canvas} with no border. - Avatar circles in testimonial cards use {rounded.full} at 32–40px sizes.

Component language: Buttons button-primary — Lavender CTA. The default primary CTA across all pages. - Background {colors.primary}, text {colors.on-primary}, type {typography.button}, padding 8px 14px, rounded {rounded.md}. - Pressed state lives in button-primary-pressed (background shifts to {colors.primary-focus}). - Hover state lives in button-primary-hover (background shifts to {colors.primary-hover} lighter lavender). button-secondary — Charcoal button. Used for secondary CTAs ("Sign in", "Read changelog"). - Background {colors.surface-1}, text {colors.ink}, type {typography.button}, padding 8px 14px, rounded {rounded.md}. 1px {colors.hairline} border. button-tertiary — Plain text button. - Background {colors.canvas}, text {colors.ink}, type {typography.button}, rounded {rounded.md}, padding 8px 14px. button-inverse — White-on-dark inverse CTA. - Background {colors.inverse-canvas}, text {colors.inverse-ink}, type {typography.button}, rounded {rounded.md}, padding 8px 14px. Pricing Tabs pricing-tab-default + pricing-tab-selected — Pill-toggle on /pricing. - Default: {colors.canvas} background, {colors.ink-subtle} text, rounded {rounded.pill}, padding 6px 14px. -...
```
