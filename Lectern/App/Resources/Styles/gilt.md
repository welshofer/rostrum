# Gilt

**ID:** `gilt`  
**Category:** finance  
**Theme:** dark  
**Vibe:** Corporate

## Color palette

- `#fcd535`
- `#f0b90b`
- `#3a3a1f`
- `#181a20`
- `#eaecef`
- `#707a8a`
- `#929aa5`
- `#2b3139`
- `#cdd1d6`
- `#ffffff`

## Typography

Families: "BinanceNova, -apple-system, BlinkMacSystemFont, sans-serif", "BinanceNova, sans-serif", "BinancePlex, BinanceNova, sans-serif". Weights: 400, 500, 600, 700.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Binance

Design token description: A confident financial-platform interface anchored on a deep near-black canvas, where Binance's iconic yellow (FCD535) carries every primary CTA, brand accent, and value-claim moment. Type runs Binance's custom BinanceNova / BinancePlex stack at modest weights — the system trusts size and yellow voltage over bold weight. Marketing and product surfaces default to the dark theme; transactional surfaces (buy dynamic transaction/data-flow pattern, deposit, exchange) flip to a light theme that shares the same yellow CTAs and gray-blue hairlines. dynamic transaction/data-flow pattern green (up) and red (down) accents thread through both modes for price-direction signals.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- Detected source-domain vocabulary: finance/banking, search/productivity software. Translate it into reusable visual behavior, not literal imagery.
- Avoid literal source imagery unless the exact slide text or visual direction explicitly requests it: credit cards, debit cards, bank apps, cash, coins, trading screens, or crypto coins; financial product mockups unless requested by slide content; search bars, search result pages, browser chrome, or app screenshots; product logos, app icons, map pins, or play-button branding.

Overall visual personality: Binance reads like a financial dynamic transaction/data-flow pattern platform that wants to feel both authoritative and energetic. The base atmosphere is deep near-black canvas ({colors.canvas-dark} — 0b0e11) holding white type and a single, ubiquitous accent: Binance Yellow ({colors.primary} — FCD535). That yellow does almost all of the brand's heavy lifting — it carries every primary CTA, every value-claim headline ("FUNDS ARE SAFU"), every "Sign Up" pill, every featured tier indicator, and the wordmark itself. There is no secondary brand color. The system trusts the yellow voltage to do the brand work, and it carries it. Type runs Binance's custom BinanceNova (display + body) and BinancePlex (numerical / financial display) stack. BinanceNova carries display headlines, section titles, and body copy. BinancePlex appears on price tickers, large stat numbers (transaction volumes, user counts, prize pools) — anywhere a number wants to feel "tabular and reliable." Both run at modest weights — display sizes use weight 600-700 (bolder than typical marketing because dynamic transaction/data-flow pattern platforms need numbers to read at a glance), body stays at 400. The product is multi...

Color tokens:
- primary: #fcd535
- primary-active: #f0b90b
- primary-disabled: #3a3a1f
- ink: #181a20
- body: #eaecef
- body-on-light: #181a20
- muted: #707a8a
- muted-strong: #929aa5
- hairline-on-light: #eaecef
- hairline-on-dark: #2b3139
- border-strong: #cdd1d6
- canvas-light: #ffffff
- canvas-dark: #0b0e11
- surface-card-dark: #1e2329

Typography tokens:
- hero-display: family BinanceNova, -apple-system, BlinkMacSystemFont, sans-serif, size 64px, weight 700, line 1.1, tracking -1px
- display-lg: family BinanceNova, sans-serif, size 48px, weight 700, line 1.1, tracking -0.5px
- display-md: family BinanceNova, sans-serif, size 40px, weight 600, line 1.15, tracking -0.3px
- display-sm: family BinanceNova, sans-serif, size 32px, weight 600, line 1.2, tracking 0
- title-lg: family BinanceNova, sans-serif, size 24px, weight 600, line 1.3, tracking 0
- title-md: family BinanceNova, sans-serif, size 20px, weight 600, line 1.35, tracking 0
- title-sm: family BinanceNova, sans-serif, size 16px, weight 600, line 1.4, tracking 0
- number-display: family BinancePlex, BinanceNova, sans-serif, size 40px, weight 700, line 1.1, tracking -0.3px
- number-md: family BinancePlex, BinanceNova, sans-serif, size 16px, weight 500, line 1.4, tracking 0
- number-sm: family BinancePlex, BinanceNova, sans-serif, size 14px, weight 500, line 1.4, tracking 0
- body-md: family BinanceNova, sans-serif, size 14px, weight 400, line 1.5, tracking 0
- body-sm: family BinanceNova, sans-serif, size 13px, weight 400, line 1.5, tracking 0

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
- xs: 2px
- sm: 4px
- md: 6px
- lg: 8px
- xl: 12px
- pill: 9999px
- full: 9999px

Component tokens:
- button-primary: backgroundColor: {colors.primary}, textColor: {colors.on-primary}, typography: {typography.button}, rounded: {rounded.md}, padding: 12px 24px, height: 40px
- button-primary-active: backgroundColor: {colors.primary-active}, textColor: {colors.on-primary}, rounded: {rounded.md}
- button-primary-disabled: backgroundColor: {colors.primary-disabled}, textColor: {colors.muted}, rounded: {rounded.md}
- button-primary-pill: backgroundColor: {colors.primary}, textColor: {colors.on-primary}, typography: {typography.button}, rounded: {rounded.pill}, padding: 14px 32px
- button-secondary-on-dark: backgroundColor: {colors.surface-card-dark}, textColor: {colors.on-dark}, typography: {typography.button}, rounded: {rounded.md}, padding: 12px 24px
- button-secondary-on-light: backgroundColor: {colors.canvas-light}, textColor: {colors.ink}, typography: {typography.button}, rounded: {rounded.md}, padding: 12px 24px
- button-tertiary-text: backgroundColor: transparent, textColor: {colors.body}, typography: {typography.button}
- button-trading-up: backgroundColor: {colors.trading-up}, textColor: {colors.on-dark}, typography: {typography.button}, rounded: {rounded.sm}, padding: 8px 20px

Color rationale: Brand & Accent - Binance Yellow ({colors.primary} — FCD535): The single brand color. Used for primary CTA backgrounds, the wordmark, brand-claim headlines ("FUNDS ARE SAFU"), trust badges ("No.1 dynamic transaction/data-flow pattern Volume"), large stat numbers in {component.stat-callout-card}, and inline links. - Binance Yellow Active ({colors.primary-active} — f0b90b): The press / hover-darker variant. Slightly more saturated yellow. - Binance Yellow Disabled ({colors.primary-disabled} — 3a3a1f): A desaturated dark-yellow used on disabled CTAs over dark canvas. - Accent Turquoise ({colors.accent-turquoise} — 2dbdb6): A small secondary accent used very sparingly on Smart trusted value-flow system's "Check Now" CTA over dark surfaces. Treat as a single-product accent, not a system color. Surface The system has two canvas modes that map to product context: Dark mode (marketing default): - Canvas Dark ({colors.canvas-dark} — 0b0e11): The primary page floor. Near-black with a slight warm tint — never pure black. - Surface layered rectangular token motif Dark ({colors.surface-card-dark} — 1e2329): layered rectangular token motif, navigation dropdowns, secondary buttons over dark canva...

Typography rationale: Font Family The system runs BinanceNova for display and body, and BinancePlex for numerical / financial data. Both are licensed Binance custom typefaces. The fallback stack walks -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif. The split is functional, not decorative: - BinanceNova → editorial type (headlines, paragraphs, button labels, nav) - BinancePlex → tabular numerical type (prices, volumes, percentages, stat counters, prize pools) Mixing them is not optional — BinanceNova on a price ticker would lose the trading-platform character; BinancePlex on a paragraph would feel monospace-cold. Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.hero-display} | 64px | 700 | 1.1 | -1px | Homepage h1 ("316,258,026 USERS TRUST US") | | {typography.display-lg} | 48px | 700 | 1.1 | -0.5px | Brand-claim headlines ("FUNDS ARE SAFU"), prize-pool hero ("Futures Masters Arena") | | {typography.display-md} | 40px | 600 | 1.15 | -0.3px | Section heads on long-scroll pages | | {typography.display-sm} | 32px | 600 | 1.2 | 0 | CTA band headlines ("Secure, Low-Fee dynamic transaction/data-flow pattern on Binance") | | {ty...

Layout system: Spacing System - Base unit: 4px. - Tokens: {spacing.xxs} 4px · {spacing.xs} 8px · {spacing.sm} 12px · {spacing.md} 16px · {spacing.lg} 24px · {spacing.xl} 32px · {spacing.xxl} 48px · {spacing.section} 80px. - Section padding (vertical): {spacing.section} (80px) — slightly tighter than airy marketing sites (96px) because Binance pages mix marketing bands with dense product surfaces (markets tables, FAQ accordions). - layered rectangular token motif internal padding: {spacing.lg} (24px) for content layered rectangular token motif and markets tables; {spacing.xl} (32px) for QR-promo layered rectangular token motif and CTA bands; {spacing.md} (16px) for trust badges and table rows. - Gutters: {spacing.lg} (24px) between layered rectangular token motif in 3-up grids; {spacing.md} (16px) inside footer column gutters and dense FAQ lists. Grid & Container - Max content width: ~1280px centered on marketing pages; ~1440px on product surfaces (markets, smart-money tables) where horizontal density matters. - Editorial body: Single 12-column grid; product pages often use 8/4 split (main panel + side rail). - Markets table: 5-column header (Pair / Last Price / 24h Change / 24h Volume / Action),...

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | Flat | No shadow, no border | Body sections, top nav, hero bands, footer | | Soft hairline | 1px {colors.hairline-on-dark} or {colors.hairline-on-light} | Inputs, table dividers, FAQ row separators, secondary buttons | | layered rectangular token motif surface | {colors.surface-card-dark} background on dark canvas, {colors.canvas-light} on light context — no shadow | All elevated layered rectangular token motif (markets-table-card, QR-promo-card, feature-photo-card, trust-badges) | | Subtle drop shadow | Faint shadow visible only when a layered rectangular token motif sits over imagery | Used sparingly on the buy-crypto-amount-card on transactional pages | | Focus ring | 0 0 0 2px {colors.info-ring} at 50% alpha | Input + button keyboard focus state | The elevation philosophy is flat surfaces with color-block separation. Binance does not use heavy drop shadows or glassmorphism — depth comes from the contrast between {colors.canvas-dark} and {colors.surface-card-dark} (a 12-step lightness jump that reads as a clear elevation boundary). Decorative Depth - Yellow → dark vertical gradient backdrop on the Futures Arena hero: {colors.primary}...

Shape language: Border Radius Scale | Token | Value | Use | |---|---|---| | {rounded.xs} | 2px | Almost no use — reserved for very small badges | | {rounded.sm} | 4px | Small inline buttons (subscribe, trading-up / trading-down inline) | | {rounded.md} | 6px | Standard CTA buttons, primary buttons, primary input fields | | {rounded.lg} | 8px | Search input, content layered rectangular token motif, trust badges, sub-cards | | {rounded.xl} | 12px | Elevated layered rectangular token motif containers (markets-table-card, QR-promo-card, CTA bands) | | {rounded.pill} | 9999px | Prominent feature CTAs ("Sign Up" pill on dark, futures-arena "Join Now") | | {rounded.full} | 9999px / 50% | Coin icons, avatars | Binance's radius hierarchy is tighter than typical marketing systems — most surfaces sit at 6-12px. The pill radius is a deliberate exception used to signal "this is a top-of-page action." Photography & Iconography - Coin icons render as 24×24 or 32×32 rounded glyphs (often 50% radius on circular outline + the coin's brand color inside). - 3D rendered coin stacks and trophy illustrations are full-color illustrations with a slight floor shadow — not flat icons. - Photographic content (people-using-t...

Component language: Top Navig...
```
