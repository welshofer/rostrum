# Oat

**ID:** `oat`  
**Category:** ai  
**Theme:** light  
**Vibe:** Editorial

## Color palette

- `#f5f5f5`
- `#292524`
- `#0c0a09`
- `#4e4e4e`
- `#777169`
- `#a8a29e`
- `#e7e5e4`
- `#f0efed`
- `#d6d3d1`
- `#fafafa`

## Typography

Families: "'Inter', sans-serif", "'Waldenburg', 'Times New Roman', serif", "'Waldenburg', serif". Weights: 300, 400, 500, 600.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: ElevenLabs

Design token description: A voice-AI brand whose marketing surfaces read like a quietly editorial print magazine. The base canvas is off-white (f5f5f5) holding warm near-black ink (292524); the brand voltage is photographic, not chromatic — soft pastel atmospheric gradient orbs (mint → peach → lavender → sky) drift through the page as the only "color" moments. Display runs Waldenburg Light at weight 300 — the editorial signature. Inter carries body, navigation, captions. CTAs are subtle: a near-black ink pill is the primary, a transparent outline is the secondary. The brand trusts atmospheric photography and modest type weights to do all of the brand work; there is no neon accent, no saturated CTA color, no developer-tools dark canvas.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- No dominant source-domain vocabulary was detected, but still avoid copying example subject matter from the design brief.
- Avoid brand logos, product shots, mascot imagery, packaging, buildings, people, or industry-specific objects unless requested by the slide content.

Overall visual personality: ElevenLabs reads like a quietly editorial print magazine that happens to be a voice-AI product. The base canvas is off-white {colors.canvas} (f5f5f5) holding warm near-black ink {colors.ink} (0c0a09). The brand voltage is photographic, not chromatic: soft pastel atmospheric gradient orbs (mint, peach, lavender, sky, rose) drift through the page as the only "color" moments. There is no neon accent, no saturated CTA color, no dark-canvas dev-tools atmosphere. Type pairs Waldenburg Light (custom serif at weight 300) for display with Inter for body, navigation, captions. The display weight at 300 is the editorial signature — never bold, never heavy. CTAs are subtle: a near-black ink pill ({component.button-primary}) is the primary, a transparent outline ({component.button-outline}) is the secondary. The brand trusts atmospheric photography and modest type weights to carry brand work. Key Characteristics: - Off-white canvas, warm near-black ink. No saturated CTA color. - Single primary action: ink pill at {rounded.pill}. Atmospheric gradients carry visual brand voltage. - Display runs Waldenburg Light at weight 300 — editorial magazine voice. - Body runs Inter at 400 with subtle letter...

Color tokens:
- primary: #292524
- primary-active: #0c0a09
- ink: #0c0a09
- body: #4e4e4e
- body-strong: #292524
- muted: #777169
- muted-soft: #a8a29e
- hairline: #e7e5e4
- hairline-soft: #f0efed
- hairline-strong: #d6d3d1
- canvas: #f5f5f5
- canvas-soft: #fafafa
- canvas-deep: #0c0a09
- surface-card: #ffffff

Typography tokens:
- display-mega: family 'Waldenburg', 'Times New Roman', serif, size 64px, weight 300, line 1.05, tracking -1.92px
- display-xl: family 'Waldenburg', serif, size 48px, weight 300, line 1.08, tracking -0.96px
- display-lg: family 'Waldenburg', serif, size 36px, weight 300, line 1.17, tracking -0.36px
- display-md: family 'Waldenburg', serif, size 32px, weight 300, line 1.13, tracking -0.32px
- display-sm: family 'Waldenburg', serif, size 24px, weight 300, line 1.2, tracking 0
- title-md: family 'Inter', sans-serif, size 20px, weight 500, line 1.35, tracking 0
- title-sm: family 'Inter', sans-serif, size 18px, weight 500, line 1.44, tracking 0.18px
- body-md: family 'Inter', sans-serif, size 16px, weight 400, line 1.5, tracking 0.16px
- body-strong: family 'Inter', sans-serif, size 16px, weight 500, line 1.5, tracking 0.16px
- body-sm: family 'Inter', sans-serif, size 15px, weight 400, line 1.47, tracking 0.15px
- caption: family 'Inter', sans-serif, size 14px, weight 400, line 1.5, tracking 0
- caption-uppercase: family 'Inter', sans-serif, size 12px, weight 600, line 1.4, tracking 0.96px

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
- button-primary: backgroundColor: {colors.primary}, textColor: {colors.on-primary}, typography: {typography.button}, rounded: {rounded.pill}, padding: 10px 20px, height: 40px
- button-primary-active: backgroundColor: {colors.primary-active}, textColor: {colors.on-primary}, rounded: {rounded.pill}
- button-outline: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.button}, rounded: {rounded.pill}, padding: 9px 19px, height: 40px
- button-tertiary-text: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.button}
- hero-band: backgroundColor: {colors.canvas}, textColor: {colors.ink}, typography: {typography.display-mega}, padding: 96px
- gradient-orb-card: backgroundColor: {colors.canvas-soft}, textColor: {colors.ink}, rounded: {rounded.xxl}, padding: 32px
- feature-card: backgroundColor: {colors.surface-card}, textColor: {colors.ink}, typography: {typography.title-md}, rounded: {rounded.xl}, padding: 24px

Color rationale: Brand & Accent - Ink Primary ({colors.primary} — 292524): The primary action color — warm near-black pill. Used scarcely. - Ink Primary Active ({colors.primary-active} — 0c0a09): Press state. Surface - Canvas ({colors.canvas} — f5f5f5): Off-white page floor. - Canvas Soft ({colors.canvas-soft} — fafafa): Lighter band for subtle alternating sections. - Canvas Deep ({colors.canvas-deep} — 0c0a09): Same as ink — used for the rare dark-mode hero (Agents page). - Surface Card ({colors.surface-card} — ffffff): Pure white card. - Surface Strong ({colors.surface-strong} — f0efed): Badges, voice-icon plates. - Surface Dark ({colors.surface-dark} — 0c0a09): Dark hero/CTA band canvas. - Surface Dark Elevated ({colors.surface-dark-elevated} — 1c1917): Cards on dark canvas. Hairlines - Hairline ({colors.hairline} — e7e5e4): Default 1px divider. - Hairline Soft ({colors.hairline-soft} — f0efed): Lighter divider. - Hairline Strong ({colors.hairline-strong} — d6d3d1): Stronger panel outline. Text - Ink ({colors.ink} — 0c0a09): Display, primary text. - Body ({colors.body} — 4e4e4e): Default running-text. - Body Strong ({colors.body-strong} — 292524): Same as primary — emphasis. - Muted ({colors.mu...

Typography rationale: Font Family Waldenburg Light is the licensed display serif at weight 300. Inter carries body, navigation, captions, and buttons. Fallback: 'Times New Roman', serif for Waldenburg, sans-serif for Inter. Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.display-mega} | 64px | 300 | 1.05 | -1.92px | Homepage hero h1 | | {typography.display-xl} | 48px | 300 | 1.08 | -0.96px | Subsidiary heroes | | {typography.display-lg} | 36px | 300 | 1.17 | -0.36px | Section heads | | {typography.display-md} | 32px | 300 | 1.13 | -0.32px | Sub-section heads | | {typography.display-sm} | 24px | 300 | 1.2 | 0 | Card group titles | | {typography.title-md} | 20px | 500 | 1.35 | 0 | Component titles — Inter | | {typography.title-sm} | 18px | 500 | 1.44 | 0.18px | List labels | | {typography.body-md} | 16px | 400 | 1.5 | 0.16px | Default body — Inter | | {typography.body-strong} | 16px | 500 | 1.5 | 0.16px | Emphasized body | | {typography.body-sm} | 15px | 400 | 1.47 | 0.15px | Footer body | | {typography.caption} | 14px | 400 | 1.5 | 0 | Photo captions | | {typography.caption-uppercase} | 12px | 600 | 1.4 | 0.96px | Section labels, badges |...

Layout system: Spacing System - Base unit: 4px. - Tokens: {spacing.xxs} 4px · {spacing.xs} 8px · {spacing.sm} 12px · {spacing.base} 16px · {spacing.md} 20px · {spacing.lg} 24px · {spacing.xl} 32px · {spacing.xxl} 48px · {spacing.section} 96px. - Section padding: 96px. Grid & Container - Max content width: ~1200px. - Editorial body: 12-column grid. - Feature card grids: 2-up at desktop for hero splits, 3-up for benefit grids. - Footer: 5-column at desktop. Whitespace Philosophy Generous editorial pacing — print-magazine feel. 96px between bands; cards inside bands sit close (16-24px gap). The atmospheric gradient orbs occupy generous breathing space without competing with copy.

Depth and hierarchy: The system uses hairline + soft drop. Cards float above the off-white canvas via 1px hairlines and a single subtle shadow tier. Atmospheric depth comes from gradient orbs. | Level | Treatment | Use | |---|---|---| | Flat (canvas) | {colors.canvas} (f5f5f5) | Body bands, footer | | Card | {colors.surface-card} (ffffff) | Content cards | | Hairline border | 1px {colors.hairline} | Card outlines | | Soft drop | 0 4px 16px rgba(0, 0, 0, 0.04) | Hovered cards (single shadow tier) | | Gradient orb | Radial gradient with one of {colors.gradient-} | Atmospheric depth — never a card surface | Decorative Depth - Pastel gradient orbs are the brand's strongest atmospheric pattern. Soft radial blooms in mint, peach, lavender, sky, or rose drift through hero bands and feature sections without containing any content — they are pure atmosphere.

Shape language: Border Radius Scale | Token | Value | Use | |---|---|---| | {rounded.none} | 0px | Reserved | | {rounded.xs} | 4px | Inline tags | | {rounded.sm} | 6px | Compact rows | | {rounded.md} | 8px | Form inputs | | {rounded.lg} | 12px | Compact cards | | {rounded.xl} | 16px | Feature cards, pricing tiers | | {rounded.xxl} | 24px | Gradient orb cards (extra-soft) | | {rounded.pill} | 9999px | All CTA buttons, badges | | {rounded.full} | 9999px | Voice icon circles, avatars |

Component language: Top Navigation top-nav — Background {colors.canvas}, text {colors.ink}, height 64px. Layout: ElevenLabs wordmark left, primary horizontal menu (Creative / Agents / Video / Pricing / Enterprise / Docs), Sign In + "Try free" primary CTA right. Buttons button-primary — Near-black ink pill. Background {colors.primary}, text {colors.on-primary}, type {typography.button} (15px / 500), padding 10px × 20px, height 40px, rounded {rounded.pill}. button-primary-active — Press state. Background {colors.primary-active}. button-outline — Transparent pill with 1px ink border. Background transparent, text {colors.ink}, 1px {colors.hairline-strong} border. button-tertiary-text — Inline ink text link. Hero & Atmospheric hero-band — Background {colors.canvas}, full-width display headline in {typography.display-mega} (64px / 300 / -1.92px), subhead in {typography.body-md}, two CTAs, and an atmospheric gradient orb behind the centered headline. gradient-orb-card — A large card with a soft radial-gradient orb behind centered display copy. Background {colors.canvas-soft}, rounded {rounded.xxl} (24px), padding 32px. Each variant uses one of the five gradient tokens (gradient-mint, gradient-peach, gradien...

Guardrails: Do - Reserve {colors.primary} (ink pill) for primary CTAs. - Use Waldenburg Light at weight 300 for every display headline. Never bold. - Use Inter at +0.15-0.18px tracking for body — the editorial dialect. - Use atmospheric gradient orbs (mint/peach/lavender/sky/rose) as decoration only. - Use the pill shape for every CTA and badge. Don't - Don't introduce a saturated brand action color. Ink pill is the only CTA color. - Don't bold display copy. Display sits at weight 300 — bolding shifts the brand voice from editorial to consumer-marketing. - Don't use gradient orbs as button fills, text colors, or component backgrounds. They are pure atmosphere. - Don't use sharp {rounded.none} (0px) on CTAs. Pill geometry is the brand button. - Don't drop body Inter to weight 300 to match W...
```
