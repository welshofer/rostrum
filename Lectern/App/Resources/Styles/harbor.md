# Harbor

**ID:** `harbor`  
**Category:** developer  
**Theme:** light  
**Vibe:** Editorial

## Color palette

- `#171717`
- `#000000`
- `#0d74ce`
- `#1a1a1a`
- `#476cff`
- `#60646c`
- `#999999`
- `#cccccc`
- `#f0f0f3`
- `#f5f5f7`

## Typography

Families: "'Inter', -apple-system, system-ui, sans-serif", "'Inter', sans-serif", "'JetBrains Mono', 'Fira Code', monospace". Weights: 400, 500, 600.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Expo

Design token description: A React Native developer-platform whose marketing site reads like a quietly-confident infrastructure brand. The base canvas is pure white with a soft sky-blue gradient atmospheric wash behind the hero; near-black ink (171717) carries body and display alike. The single brand voltage is pure black (000000) for primary CTAs — minimal and editorial-feeling, paired with a small blue text-link accent (0d74ce) reserved for inline body links. Type pairs Inter at modest weights (display 600, body 400) with JetBrains Mono on every code the source brand. The brand's strongest visual signature is the device-mockup hero — a centered the source brand + the source brand composite showing real Expo dev surfaces — over the gradient sky wash.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- Detected source-domain vocabulary: consumer technology, food/hospitality. Translate it into reusable visual behavior, not literal imagery.
- Avoid literal source imagery unless the exact slide text or visual direction explicitly requests it: phones, laptops, tablets, device mockups, or hardware product renders; app screenshots, operating-system chrome, or product launch hero shots; food photography, dishes, plates, chefs, kitchens, menus, recipes, utensils, or dining scenes.

Overall visual personality: Expo's marketing site reads like a quietly-confident React-Native developer platform. The base canvas is pure white ({colors.canvas} — ffffff) with a soft sky-blue gradient atmospheric wash behind the hero band. Near-black ink {colors.ink} (171717) carries body and display alike. The single brand voltage is pure black ({colors.primary} — 000000) for primary CTAs — minimal and editorial-feeling. A small blue text-link accent ({colors.text-link} — 0d74ce) is reserved for inline body links, never as a CTA. Type runs Inter as the single sans family at modest weights (display 600, body 400). JetBrains Mono carries every code the source brand. No custom typeface — the brand trusts Inter's editorial neutrality. The brand's strongest visual signature is the device-mockup hero — a centered the source brand + the source brand composite showing real Expo dev surfaces (Expo Studio, EAS Build dashboard, the Expo Go simulator) — over a sky-blue gradient atmospheric wash. The composite is the page's chrome instead of an illustration. Key Characteristics: - Pure white canvas with sky-blue gradient atmospheric backdrop in hero only. - Single primary CTA: pure black pill at {rounded.md} (8px) — com...

Color tokens:
- primary: #000000
- primary-active: #1a1a1a
- text-link: #0d74ce
- text-link-secondary: #476cff
- ink: #171717
- body: #60646c
- body-strong: #171717
- muted: #999999
- muted-soft: #cccccc
- hairline: #f0f0f3
- hairline-soft: #f5f5f7
- hairline-strong: #dcdee0
- canvas: #ffffff
- canvas-soft: #fafafa

Typography tokens:
- display-mega: family 'Inter', -apple-system, system-ui, sans-serif, size 64px, weight 600, line 1.05, tracking -1.92px
- display-xl: family 'Inter', sans-serif, size 48px, weight 600, line 1.1, tracking -1.44px
- display-lg: family 'Inter', sans-serif, size 36px, weight 600, line 1.15, tracking -1.08px
- display-md: family 'Inter', sans-serif, size 28px, weight 600, line 1.2, tracking -0.84px
- display-sm: family 'Inter', sans-serif, size 22px, weight 600, line 1.25, tracking -0.5px
- title-md: family 'Inter', sans-serif, size 18px, weight 600, line 1.4, tracking 0
- title-sm: family 'Inter', sans-serif, size 16px, weight 600, line 1.4, tracking 0
- body-md: family 'Inter', sans-serif, size 16px, weight 400, line 1.5, tracking 0
- body-sm: family 'Inter', sans-serif, size 14px, weight 400, line 1.5, tracking 0
- caption: family 'Inter', sans-serif, size 13px, weight 400, line 1.4, tracking 0
- caption-uppercase: family 'Inter', sans-serif, size 11px, weight 600, line 1.4, tracking 0.88px
- code: family 'JetBrains Mono', 'Fira Code', monospace, size 13px, weight 400, line 1.5, tracking 0

Spacing tokens:
- xxs: 4px
- xs: 8px
- sm: 12px
- base: 16px
- md: 20px
- lg: 24px
- xl: 32px
- xxl: 48px
- section: 96px

Radius and shape tokens:
- none: 0px
- xs: 4px
- sm: 6px
- md: 8px
- lg: 12px
- xl: 16px
- xxl: 24px
- pill: 9999px
- full: 9999px

Component tokens:
- top-nav: backgroundColor: {colors.canvas}, textColor: {colors.ink}, typography: {typography.nav-link}, height: 64px
- button-primary: backgroundColor: {colors.primary}, textColor: {colors.on-primary}, typography: {typography.button}, rounded: {rounded.md}, padding: 10px 18px, height: 40px
- button-primary-active: backgroundColor: {colors.primary-active}, textColor: {colors.on-primary}, rounded: {rounded.md}
- button-secondary: backgroundColor: {colors.surface-card}, textColor: {colors.ink}, typography: {typography.button}, rounded: {rounded.md}, padding: 9px 17px, height: 40px
- button-tertiary-text: backgroundColor: transparent, textColor: {colors.text-link}, typography: {typography.button}
- hero-band: backgroundColor: {colors.canvas}, textColor: {colors.ink}, typography: {typography.display-mega}, padding: 96px
- device-mockup-card: backgroundColor: {colors.surface-card}, textColor: {colors.ink}, rounded: {rounded.xl}, padding: 0
- feature-card: backgroundColor: {colors.surface-card}, textColor: {colors.ink}, typography: {typography.title-md}, rounded: {rounded.lg}, padding: 24px

Color rationale: Brand & Accent - Black ({colors.primary} — 000000): Primary CTA fill. Used scarcely. - Black Active ({colors.primary-active} — 1a1a1a): Press state. - Text Link Blue ({colors.text-link} — 0d74ce): Inline body links inside long-form copy. Scoped narrowly — never on CTAs. - Legal Link Blue ({colors.text-link-secondary} — 476cff): Inline links inside legal copy footer. - Bright Cyan ({colors.accent-link-bright} — 47c2ff): Used very sparingly inside docs widget links. the source brand - Canvas ({colors.canvas} — ffffff): Pure white page floor. - Canvas Soft ({colors.canvas-soft} — fafafa): Subtle alternating band. - the source brand Card ({colors.surface-card} — ffffff): Pure white card. - the source brand Strong ({colors.surface-strong} — f0f0f3): Badges, ecosystem tiles, secondary buttons. - the source brand Dark ({colors.surface-dark} — 171717): Dark feature cards, code blocks, IDE mockups, featured pricing. - the source brand Dark Elevated ({colors.surface-dark-elevated} — 1a1a1a): One step lighter inside dark cards. Atmospheric Backdrop - Sky Light ({colors.gradient-sky-light} — cfe7ff) + Sky Mid ({colors.gradient-sky-mid} — a8c8e8): The soft sky-blue gradient wash behind the hom...

Typography rationale: Font Family Inter is the single sans family across every text role. JetBrains Mono carries every code the source brand. Fallback: -apple-system, system-ui, sans-serif. Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.display-mega} | 64px | 600 | 1.05 | -1.92px | Homepage hero h1 | | {typography.display-xl} | 48px | 600 | 1.1 | -1.44px | Subsidiary heroes | | {typography.display-lg} | 36px | 600 | 1.15 | -1.08px | Section heads | | {typography.display-md} | 28px | 600 | 1.2 | -0.84px | Sub-section heads | | {typography.display-sm} | 22px | 600 | 1.25 | -0.5px | Card group titles | | {typography.title-md} | 18px | 600 | 1.4 | 0 | Component titles | | {typography.title-sm} | 16px | 600 | 1.4 | 0 | List labels | | {typography.body-md} | 16px | 400 | 1.5 | 0 | Default body | | {typography.body-sm} | 14px | 400 | 1.5 | 0 | Footer body | | {typography.caption} | 13px | 400 | 1.4 | 0 | Photo captions | | {typography.caption-uppercase} | 11px | 600 | 1.4 | 0.88px | Section labels, badges | | {typography.code} | 13px | 400 | 1.5 | 0 | Code blocks — JetBrains Mono | | {typography.button} | 14px | 500 | 1.0 | 0 | CTA labels | | {...

Layout system: Spacing System - Base unit: 4px. - Tokens: {spacing.xxs} 4px · {spacing.xs} 8px · {spacing.sm} 12px · {spacing.base} 16px · {spacing.md} 20px · {spacing.lg} 24px · {spacing.xl} 32px · {spacing.xxl} 48px · {spacing.section} 96px. - Section padding: 96px. Grid & Container - Max content width: ~1200px. - Editorial body: 12-column grid. - Feature card grids: 2-up at desktop for hero splits, 3-up for benefit grids. - Ecosystem tile grid: 8-up at desktop. - Footer: 5-column at desktop. Whitespace Philosophy Generous editorial pacing. The white canvas does not compete with the hero's gradient sky wash; cards inside dense workflow sections sit close (16-24px gap).

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | Flat (canvas) | {colors.canvas} (ffffff) | Body bands, footer | | Card | {colors.surface-card} (ffffff) | Content cards | | Hairline border | 1px {colors.hairline} | Card outlines | | Soft drop | 0 4px 12px rgba(0, 0, 0, 0.04) | Hovered cards (single shadow tier) | | Atmospheric gradient | Sky-blue radial wash | Hero backdrop only | | Dark inversion | {colors.surface-dark} (171717) | Dark feature cards, code blocks, featured pricing | Decorative Depth - Sky-blue gradient backdrop in the hero only — atmospheric depth without claiming to be a brand color. - tactile material surface mockup composite as page chrome — the source brand + the source brand showing real Expo dev surfaces.

Shape language: Border Radius Scale | Token | Value | Use | |---|---|---| | {rounded.none} | 0px | Reserved | | {rounded.xs} | 4px | Inline tags | | {rounded.sm} | 6px | Compact rows | | {rounded.md} | 8px | CTA buttons, form inputs, ecosystem tiles | | {rounded.lg} | 12px | Feature cards, code blocks, pricing tiers | | {rounded.xl} | 16px | tactile material surface mockup cards | | {rounded.xxl} | 24px | Larger atmospheric cards (rare) | | {rounded.pill} | 9999px | Badges only | | {rounded.full} | 9999px | Avatar rounded focal composition (rare) | Compact developer-ergonomic radii — 8px CTAs, 12px cards. Pill geometry is reserved for badges, never CTAs.

Component language: Top Navigation top-nav — Background {colors.canvas}, text {colors.ink}, height 64px. Layout: Expo wordmark left, primary horizontal hospitality-service structure (Tools / Workflows / EAS / Pricing / Docs / Showcase), Sign In + Get started CTA right. Buttons button-primary — Pure black pill. Background {colors.primary}, text {colors.on-primary}, type {typography.button} (14px / 500), padding 10px × 18px, height 40px, rounded {rounded.md} (8px). button-primary-active — Press state. Background {colors.primary-active}. button-secondary — White card with 1px hairline-strong border. Background {colors.surface-card}, text {colors.ink}, 1px {colors.hairline-strong} border. button-tertiary-text — Inline blue text link. Background transparent, text {colors.text-link}. Hero & tactile material surface Mockup hero-band — Background {colors.canvas} with a soft sky-blue gradient wash behind the centered headline. Display headline in {typography.display-mega} (64px / 600 / -1.92px), subhead in {typography.body-md}, single primary CTA, then below — the tactile material surface mockup composite. device-mockup-card — A layered the source brand + the source brand composite showing real Expo dev surfa...

Guardrails: Do - Reserve {colors.primary} (black) for primary CTAs. - Use {colors.text-link} (blue) for inline body links only — never on CTAs or buttons. - Set every CTA at {rounded.md} (8px) — developer dialect. - Use Inter at weight 600 for display, 400 for body. - Render every code the source brand in JetBrains Mono. - Pair the hero with the device-mockup composite — it's the page chrome. Don't - Don't introduce a saturated brand action color. Black is the only CTA fill. - Don't use blue ({colo...
```
