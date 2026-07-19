# Aurora

**ID:** `aurora`  
**Category:** finance  
**Theme:** light  
**Vibe:** Technical

## Color palette

- `#533afd`
- `#4434d4`
- `#2e2b8c`
- `#665efd`
- `#b9b9f9`
- `#1c1e54`
- `#0d253d`
- `#273951`
- `#64748d`
- `#61718a`

## Typography

Families: "sohne-var, 'SF Pro Display', system-ui, -apple-system, sans-serif". Weights: 300, 400.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Stripe

Design token description: a financial-infrastructure brand built on a deep navy ink, an electric indigo primary, and a recurring atmospheric gradient mesh that occupies the upper third of nearly every marketing page. The system pairs the proprietary Sohne family at thin (300) weights with negative letter-spacing for editorial-density display headlines, and uses tabular-figure body type where trusted value-flow system and numerics matter. Buttons are tight-radius pills, layered rectangular token motif live on near-white surfaces, and the dashboard track flips polarity to a familiar dark-app shell.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- Detected source-domain vocabulary: finance/banking, search/productivity software, telecom/connectivity. Translate it into reusable visual behavior, not literal imagery.
- Avoid literal source imagery unless the exact slide text or visual direction explicitly requests it: credit cards, debit cards, bank apps, cash, coins, trading screens, or crypto coins; financial product mockups unless requested by slide content; search bars, search result pages, browser chrome, or app screenshots; product logos, app icons, map pins, or play-button branding; phones, SIM cards, cell towers, antennas, routers, call screens, or telecom product shots.

Overall visual personality: Stripi's design language opens with the gradient mesh. A wide horizontal band of pastel cream, sherbet the source brand, lavender, electric indigo, and ruby pink occupies the upper third of nearly every marketing page — the brand's instantly-recognizable atmospheric backdrop. Type and product UI mockups float above it on {colors.canvas} (white), with the gradient acting as both decoration and visual anchor. The lower portion of the page returns to white, with feature explanations on {colors.canvas-soft} (a barely-tinted cool off-white) and dashboard product mockups composited as faux IDE/console panels in deep navy. The color system has two primary roles. Indigo ({colors.primary} — 533afd) is the brand's signature CTA color, used sparingly: one filled pill per band. Deep navy ({colors.ink} — 0d253d) is the universal body text color and the fill of dashboard mockups, the featured pricing tier, and the dark-app surfaces on the dashboard track. Ruby ({colors.ruby}) and magenta ({colors.magenta}) appear inside the gradient mesh and as accent dots in product UI mockups; they are not used as button colors. Typography is built around Sohne at weight 300 with negative letter-spacing — the...

Color tokens:
- primary: #533afd
- primary-deep: #4434d4
- primary-press: #2e2b8c
- primary-soft: #665efd
- primary-bg-subdued-hover: #b9b9f9
- brand-dark-900: #1c1e54
- ink: #0d253d
- ink-secondary: #273951
- ink-mute: #64748d
- ink-mute-2: #61718a
- on-primary: #ffffff
- canvas: #ffffff
- canvas-soft: #f6f9fc
- canvas-cream: #f5e9d4

Typography tokens:
- display-xxl: family sohne-var, 'SF Pro Display', system-ui, -apple-system, sans-serif, size 56px, weight 300, line 1.03, tracking -1.4px
- display-xl: family sohne-var, 'SF Pro Display', system-ui, -apple-system, sans-serif, size 48px, weight 300, line 1.15, tracking -0.96px
- display-lg: family sohne-var, 'SF Pro Display', system-ui, -apple-system, sans-serif, size 32px, weight 300, line 1.1, tracking -0.64px
- display-md: family sohne-var, 'SF Pro Display', system-ui, -apple-system, sans-serif, size 26px, weight 300, line 1.12, tracking -0.26px
- heading-lg: family sohne-var, 'SF Pro Display', system-ui, -apple-system, sans-serif, size 22px, weight 300, line 1.1, tracking -0.22px
- heading-md: family sohne-var, 'SF Pro Display', system-ui, -apple-system, sans-serif, size 20px, weight 300, line 1.4, tracking -0.2px
- heading-sm: family sohne-var, 'SF Pro Display', system-ui, -apple-system, sans-serif, size 18px, weight 300, line 1.4, tracking 0
- body-lg: family sohne-var, 'SF Pro Display', system-ui, -apple-system, sans-serif, size 16px, weight 300, line 1.4, tracking 0
- body-md: family sohne-var, 'SF Pro Display', system-ui, -apple-system, sans-serif, size 15px, weight 300, line 1.4, tracking 0
- body-tabular: family sohne-var, 'SF Pro Display', system-ui, -apple-system, sans-serif, size 14px, weight 300, line 1.4, tracking -0.42px
- button-md: family sohne-var, 'SF Pro Display', system-ui, -apple-system, sans-serif, size 16px, weight 400, line 1.0, tracking 0
- button-sm: family sohne-var, 'SF Pro Display', system-ui, -apple-system, sans-serif, size 14px, weight 400, line 1.0, tracking 0

Spacing tokens:
- xxs: 2px
- xs: 4px
- sm: 8px
- md: 12px
- lg: 16px
- xl: 24px
- xxl: 32px
- huge: 64px

Radius and shape tokens:
- xs: 4px
- sm: 6px
- md: 8px
- lg: 12px
- xl: 16px
- pill: 9999px

Component tokens:
- button-primary-pill: backgroundColor: {colors.primary}, textColor: {colors.on-primary}, typography: {typography.button-md}, rounded: {rounded.pill}, padding: 8px 16px
- button-primary-pill-pressed: backgroundColor: {colors.primary-press}, textColor: {colors.on-primary}, typography: {typography.button-md}, rounded: {rounded.pill}, padding: 8px 16px
- button-secondary: backgroundColor: {colors.canvas}, textColor: {colors.primary}, typography: {typography.button-md}, rounded: {rounded.pill}, padding: 8px 16px
- button-on-dark: backgroundColor: {colors.brand-dark-900}, textColor: {colors.on-primary}, typography: {typography.button-md}, rounded: {rounded.pill}, padding: 8px 16px
- text-input: backgroundColor: {colors.canvas}, textColor: {colors.ink}, typography: {typography.body-md}, rounded: {rounded.sm}, padding: 8px 12px
- text-input-focused: backgroundColor: {colors.canvas}, textColor: {colors.ink}, typography: {typography.body-md}, rounded: {rounded.sm}, padding: 8px 12px
- card-feature-light: backgroundColor: {colors.canvas}, textColor: {colors.ink}, typography: {typography.body-md}, rounded: {rounded.lg}, padding: 32px
- card-pricing: backgroundColor: {colors.canvas}, textColor: {colors.ink}, typography: {typography.body-md}, rounded: {rounded.lg}, padding: 32px

Color rationale: Source pages: home (/), /dynamic transaction/data-flow pattern, /pricing, dashboard.the source brand.com/register/dynamic transaction/data-flow pattern. Brand & Accent - Indigo ({colors.primary} — 533afd): The brand's signature CTA color. Filled-pill button, link emphasis, gradient anchor. - Indigo Deep ({colors.primary-deep} — 4434d4): A deeper indigo used in gradient mid-stops and as the press-state warmer alternative. - Indigo Press ({colors.primary-press} — 2e2b8c): Pressed-state lift of the primary. - Indigo Soft ({colors.primary-soft} — 665efd): A lighter indigo used in product-UI accents and chart highlights. - Indigo Subdued ({colors.primary-bg-subdued-hover} — b9b9f9): Pale indigo fill used as soft tag background. - Brand Dark 900 ({colors.brand-dark-900} — 1c1e54): The deep navy used on the featured pricing tier and dashboard the source brand. - Ruby ({colors.ruby} — ea2261): Gradient accent and chart highlight; never a button. - Magenta ({colors.magenta} — f96bee): Brighter pink stop in gradient meshes. - Lemon ({colors.lemon} — 9b6829): Warm sherbet stop in gradient backdrops. Surface - Canvas ({colors.canvas} — ffffff): Default page background. - Canvas Soft ({colors....

Typography rationale: Font Family The display and UI tier is Sohne (proprietary, licensed from Klim Type Foundry) at weights 300 (thin) and 400 (regular). The variable font (sohne-var) is loaded with font-feature-settings: "ss01" enabled globally — the stylistic set substitutes a single-story a and other character variants that are part of the brand's typographic signature. When Sohne is unavailable, fall back to SF Pro Display at thin weights, then system-ui. For maximum brand fidelity, Inter (open-source) at weight 300 with font-feature-settings: "ss01" and letter-spacing: -1.4px on display sizes approximates the rhythm closely. Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.display-xxl} | 56px | 300 | 1.03 | -1.4px | Hero headline | | {typography.display-xl} | 48px | 300 | 1.15 | -0.96px | Section opener | | {typography.display-lg} | 32px | 300 | 1.1 | -0.64px | layered rectangular token motif title / sub-section | | {typography.display-md} | 26px | 300 | 1.12 | -0.26px | Compact layered rectangular token motif title | | {typography.heading-lg} | 22px | 300 | 1.1 | -0.22px | Pricing tier name | | {typography.heading-md} | 20px | 300 |...

Layout system: Spacing System - Base unit: 8px (with 2 / 4 / 12 sub-tokens for fine work). - Tokens: {spacing.xxs} 2px · {spacing.xs} 4px · {spacing.sm} 8px · {spacing.md} 12px · {spacing.lg} 16px · {spacing.xl} 24px · {spacing.xxl} 32px · {spacing.huge} 64px. - Section padding: 64–96px on marketing surfaces; 32–48px on dashboard / product surfaces. - layered rectangular token motif internal padding: 32px on feature layered rectangular token motif; 24px on dashboard mockups. Grid & Container - Marketing pages center in a ~1200px container with the gradient mesh extending edge-to-edge above. - Pricing collapses 4-up → 2-up → 1-up at 1024 / 768 breakpoints. - Dashboard product mockups use their own internal grids (12-col tables, 3-col layered rectangular token motif grids) rendered as static composites. Whitespace Philosophy The gradient mesh occupies the upper third of the page; the white canvas below is generously padded. Section gaps tend toward 96px, with content tightening to 32px on dashboard / pricing pages where users compare and act.

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | 0 | Flat | Default surface | | 1 | box-shadow: rgba(0,55,112,0.08) 0 1px 3px | layered rectangular token motif lift on white | | 2 | box-shadow: rgba(0,55,112,0.08) 0 8px 24px, rgba(0,55,112,0.04) 0 2px 6px | Floating panels, dashboard mockup the source brand | | 3 | Gradient mesh backdrop | The brand's primary depth medium — atmospheric color rather than literal shadow | Decorative Depth The gradient mesh IS the depth system. Implemented as a layered SVG or large background image rather than CSS gradients (the actual mesh has organic blob shapes that aren't CSS-renderable). The mesh provides the brand's signature lift; literal shadows are reserved for product-UI mockups and stay subtle.

Shape language: Border Radius Scale | Token | Value | Use | |---|---|---| | {rounded.xs} | 4px | Hairline tags, table the source brand | | {rounded.sm} | 6px | Form inputs | | {rounded.md} | 8px | Compact layered rectangular token motif, alerts | | {rounded.lg} | 12px | Pricing layered rectangular token motif, feature layered rectangular token motif | | {rounded.xl} | 16px | Dashboard product mockup the source brand | | {rounded.pill} | 9999px | All buttons, tag pills | Photography Geometry The brand uses product UI mockups more than photography. Dashboard composites render as faux IDE/terminal/dashboard the source brand inside {rounded.lg} 12px containers with a subtle box-shadow. Real photography appears in customer logo strips and the rare case-study layered rectangular token motif; treated as inset 4:3 with no shadow.

Component language: Buttons button-primary-pill — the dominant CTA system-wide. - Background {colors.primary}, text {colors.on-primary}, type {typography.button-md}, padding {spacing.sm} {spacing.lg} (8px 16px), rounded {rounded.pill} 9999px. - Pressed state button-primary-pill-pressed shifts background to {colors.primary-press}. button-secondary — outline-style alternative. - Background {colors.canvas}, text {colors.primary}, 1px solid {colors.primary} border, same pill geometry. button-on-dark...
```
