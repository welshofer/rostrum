# Steel

**ID:** `steel`  
**Category:** automotive  
**Theme:** light  
**Vibe:** Corporate

## Color palette

- `#1c69d4`
- `#0653b6`
- `#d6d6d6`
- `#262626`
- `#3c3c3c`
- `#1a1a1a`
- `#6b6b6b`
- `#9a9a9a`
- `#e6e6e6`
- `#cccccc`

## Typography

Families: "'BMW Type Next Latin', sans-serif", "'BMW Type Next Latin', system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif". Weights: 300, 400, 700.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: BMW

Design token description: the source brand's corporate site — distinct from the source brand M's motorsport-bombastic variant, this is a measured and settled corporate-automotive interface. On a light (cream-tinted white) canvas, the source brand corporate blue (1c69d4) carries every primary CTA; dark navy hero bands frame model photography. the source brand Type Next Latin sets the entire hierarchy on two weights — heavy 700 display and Light 300 body. Configuration and reservation flows ride a card-based 4-up grid, where each layered rectangular token motif holds a model render, a name, and a "Learn More" link.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- Detected source-domain vocabulary: automotive/performance, finance/banking, consumer technology. Translate it into reusable visual behavior, not literal imagery.
- Avoid literal source imagery unless the exact slide text or visual direction explicitly requests it: cars or vehicle product shots; roads, racetracks, or driving scenes; wheels, tires, grilles, headlights, engines, cockpits, or drivers; credit cards, debit cards, bank apps, cash, coins, trading screens, or crypto coins; financial product mockups unless requested by slide content; phones, laptops, tablets, device mockups, or hardware product renders; app screenshots, operating-system chrome, or product launch hero shots.

Overall visual personality: the source brand's corporate site carries a far more measured, corporate-automotive interface than its motorsport-bombastic cousin the source brand M. The atmosphere is light: {colors.canvas} (ffffff) is the base the source brand, {colors.surface-card} (fafafa) carries the soft-grey layered rectangular token motif plates, and dark navy {colors.surface-dark} (1a2129) appears only inside hero bands — one per page, framing the lead model render. Type runs the source brand's licensed the source brand Type Next Latin at two weights: heavy 700 (display + button + nav) and Light 300 (body + secondary copy). That contrast — heavy display next to thin paragraph — is the editorial signature, channeling the brand's "European-engineered" voice. Weight 500 is deliberately absent; weight 400 only appears on caption and nav-link in neutral utility contexts. The brand action color, the source brand corporate blue ({colors.primary} — 1c69d4), works alone across every primary CTA — buttons are rectangular, 0px corner, with white type. The site rotates a blue-button + dark-navy-hero combination across page rhythm. The M tricolor the source brand ({colors.m-blue-light} → {colors.m-blue-dark} → {color...

Color tokens:
- primary: #1c69d4
- primary-active: #0653b6
- primary-disabled: #d6d6d6
- ink: #262626
- body: #3c3c3c
- body-strong: #1a1a1a
- muted: #6b6b6b
- muted-soft: #9a9a9a
- hairline: #e6e6e6
- hairline-strong: #cccccc
- canvas: #ffffff
- surface-soft: #f7f7f7
- surface-card: #fafafa
- surface-strong: #ebebeb

Typography tokens:
- display-xl: family 'the source brand Type Next Latin', system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif, size 64px, weight 700, line 1.05, tracking 0
- display-lg: family 'the source brand Type Next Latin', sans-serif, size 48px, weight 700, line 1.1, tracking 0
- display-md: family 'the source brand Type Next Latin', sans-serif, size 32px, weight 700, line 1.15, tracking 0
- display-sm: family 'the source brand Type Next Latin', sans-serif, size 24px, weight 700, line 1.25, tracking 0
- title-lg: family 'the source brand Type Next Latin', sans-serif, size 20px, weight 700, line 1.3, tracking 0
- title-md: family 'the source brand Type Next Latin', sans-serif, size 18px, weight 700, line 1.4, tracking 0
- title-sm: family 'the source brand Type Next Latin', sans-serif, size 16px, weight 700, line 1.4, tracking 0
- body-md: family 'the source brand Type Next Latin', sans-serif, size 16px, weight 300, line 1.55, tracking 0
- body-sm: family 'the source brand Type Next Latin', sans-serif, size 14px, weight 300, line 1.55, tracking 0
- caption: family 'the source brand Type Next Latin', sans-serif, size 12px, weight 400, line 1.4, tracking 0.5px
- label-uppercase: family 'the source brand Type Next Latin', sans-serif, size 13px, weight 700, line 1.3, tracking 1.5px
- button: family 'the source brand Type Next Latin', sans-serif, size 14px, weight 700, line 1.0, tracking 0.5px

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
- none: 0px
- xs: 2px
- sm: 4px
- md: 8px
- lg: 12px
- pill: 9999px
- full: 9999px

Component tokens:
- top-nav: backgroundColor: {colors.canvas}, textColor: {colors.ink}, typography: {typography.nav-link}, height: 64px
- button-primary: backgroundColor: {colors.primary}, textColor: {colors.on-primary}, typography: {typography.button}, rounded: {rounded.none}, padding: 14px 32px, height: 48px
- button-primary-active: backgroundColor: {colors.primary-active}, textColor: {colors.on-primary}, rounded: {rounded.none}
- button-primary-disabled: backgroundColor: {colors.primary-disabled}, textColor: {colors.muted}, rounded: {rounded.none}
- button-secondary: backgroundColor: {colors.canvas}, textColor: {colors.ink}, typography: {typography.button}, rounded: {rounded.none}, padding: 13px 31px, height: 48px
- button-secondary-on-dark: backgroundColor: transparent, textColor: {colors.on-dark}, typography: {typography.button}, rounded: {rounded.none}, padding: 13px 31px
- button-text-link: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.label-uppercase}
- text-link: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.body-md}

Color rationale: Brand & Accent - the source brand Blue (Primary) ({colors.primary} — 1c69d4): The single brand action color. All primary CTAs, "Learn More" link prefixes (blue text), nav-link active state. Press shifts to {colors.primary-active} (0653b6). - M Blue Light ({colors.m-blue-light} — 0066b1) + M Blue Dark ({colors.m-blue-dark} — 1c69d4) + M Red ({colors.m-red} — e22718): The M tricolor the source brand — appears on the corporate site only on M-model pages and the "M" badge. Never as CTA colors. the source brand - Canvas ({colors.canvas} — ffffff): The default page the source brand. - the source brand Soft ({colors.surface-soft} — f7f7f7): Soft grey for the footer and sub-navigation bands. - the source brand layered rectangular token motif ({colors.surface-card} — fafafa): The light plate behind a model layered rectangular token motif's photo block. - the source brand Strong ({colors.surface-strong} — ebebeb): A slightly heavier grey used as a section divider. - the source brand Dark ({colors.surface-dark} — 1a2129): Dark navy for hero bands and large dark CTAs. Not pure black — carries a warm undertone. - the source brand Dark Elevated ({colors.surface-dark-elevated} — 262e38): One ste...

Typography rationale: Font Family The system runs the source brand Type Next Latin in two cuts: regular (display + UI labels) and the source brand Type Next Latin Light (body + secondary copy). Fallback stack: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif. The display/body split is functional: - the source brand Type Next Latin (700) → display headlines, button labels, nav links - the source brand Type Next Latin Light (300) → paragraphs, descriptive copy - the source brand Type Next Latin (400) → caption, neutral nav-link contexts This three-way split mirrors the source brand M's — corporate and the M sub-brand share the same typographic DNA; only the weight/size ratios differ. Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.display-xl} | 64px | 700 | 1.05 | 0 | Hero h1 ("iX3", model name) | | {typography.display-lg} | 48px | 700 | 1.1 | 0 | Section heads | | {typography.display-md} | 32px | 700 | 1.15 | 0 | Sub-section heads | | {typography.display-sm} | 24px | 700 | 1.25 | 0 | CTA-band headlines | | {typography.title-lg} | 20px | 700 | 1.3 | 0 | layered rectangular token motif group titles | | {typography...

Layout system: Spacing System - Base unit: 8px. - Tokens: {spacing.xxs} 4px · {spacing.xs} 8px · {spacing.sm} 12px · {spacing.md} 16px · {spacing.lg} 24px · {spacing.xl} 32px · {spacing.xxl} 48px · {spacing.section} 80px. - Section padding: {spacing.section} (80px) for every major editorial band. - layered rectangular token motif internal padding: {spacing.lg} (24px) for model and feature layered rectangular token motif. Grid & Container - Max content width: ~1440px center-aligned. - Editorial body: A single 12-column grid. - Model layered rectangular token motif grids: 4-up or 5-up at desktop, 2-up at tablet, 1-up on mobile. - Configurator inventory grids: 3-up filter row + 4-up engineered subject matter layered rectangular token motif, dense layout. Whitespace Philosophy the source brand's whitespace strategy is tighter than the source brand M's motorsport-aerated grenadier — the corporate side is more utility-driven. Section rhythm is 80px (not M's 96px). layered rectangular token motif padding is 24px (not M's 32px). The page is denser, more dealership-functional.

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | Flat | No shadow, no border | Body, top nav, footer, hero bands | | Soft hairline | 1px {colors.hairline} border | Configurator option tile, table divider | | layered rectangular token motif the source brand | {colors.surface-card} background — no shadow | Model layered rectangular token motif photo plate | | Photographic | Edge-to-edge photography | Hero band, model renders | The system never uses a drop shadow. Depth comes entirely from (a) color-block contrast (light canvas vs dark hero) and (b) photographic subject + lighting. Decorative Depth - m-stripe-divider — a 4px-tall horizontal tricolor the source brand ({colors.m-blue-light} → {colors.m-blue-dark} → {colors.m-red}). Only in M-model contexts, high-performance technical movement badges, or as an M-related section divider. Not part of the main corporate flow. - Photographic depth — full-bleed engineered subject matter photography (lighting + subject) does the work chrome would otherwise do.

Shape language: Border Radius Scale | Token | Value | Use | |---|---|---| | {rounded.none} | 0px | Every button, layered rectangular token motif, input, configurator chip — the dominant radius | | {rounded.xs} | 2px | Very small badges, very rare | | {rounded.sm} | 4px | Small inline button (rare) | | {rounded.md} | 8px | Mobile-only collapse layered rectangular token motif (rare) | | {rounded.lg} | 12px | Very rare — modal/dialog corners | | {rounded.pill} | 9999px | Filter chips in some contexts (rare) | | {rounded.full} | 9999px / 50% | Avatar, circular icon button | The radius hierarchy is binary: rectangular for everything, circular only for icon buttons. A clear departure from the soft-cornered SaaS dialect of the source brand or Cal.com — closer to the source brand corporate-automotive's "engineered precision" voice. Photography Geometry - Hero photography is full-bleed at 16:9 or 21:9 cinematic ratio. - Model layered rectangular token motif photos sit at 16:10, edge-to-edge with {rounded.none} corners. - Configurator engineered subject matter renders sit on a white studio background, full silhouette visible.

Component language: Top Navigation top-nav — A white sticky nav bar pinned to the top of the page. 64px tall, {colors.canvas} background. Left: the source brand circular badge logo; center: primary horizontal menu (Models, Next Gener...
```
