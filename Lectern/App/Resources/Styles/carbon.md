# Carbon

**ID:** `carbon`  
**Category:** developer  
**Theme:** light  
**Vibe:** Technical

## Color palette

- `#171717`
- `#ffffff`
- `#4d4d4d`
- `#888888`
- `#ebebeb`
- `#a1a1a1`
- `#fafafa`
- `#f5f5f5`
- `#0070f3`
- `#0761d1`

## Typography

Families: Geist Mono, ui-monospace, SFMono-Regular, Menlo, Monaco, monospace, Geist, Inter, system-ui, -apple-system, sans-serif. Weights: 400, 500, 600.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Vercel

Design token description: a developer-platform brand whose surface is a stark black-and-ink duet on near-white canvas, broken at hero scale by a multi-color mesh gradient (cyan / blue / magenta / amber) that acts as the entire decorative system, paired with a custom geometric sans for headlines and a monospaced caption face for technical labels.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- No dominant source-domain vocabulary was detected, but still avoid copying example subject matter from the design brief.
- Avoid brand logos, product shots, mascot imagery, packaging, buildings, people, or industry-specific objects unless requested by the slide content.

Overall visual personality: Vercel is a developer-platform brand — the page is a deployment dashboard's marketing surface, written for engineers who already know the syntax. It earns that posture with one of the cleanest stark systems on the web: near-white {colors.canvas-soft} body background, ink-near-black {colors.ink} text, a 200-step gray scale that gives every divider, border, and disabled state its own deliberate step. The only place the brand introduces colour at marketing scale is the multi-stop mesh gradient ({colors.gradient-develop-start} → {colors.gradient-preview-end} → {colors.gradient-ship-start} → cyan / magenta / amber) that floats in atmospheric backdrops, never miniaturised to a swatch. That gradient is the entire decoration system. Type is the second decisive voice. The brand's own custom geometric sans (Geist) carries display, body, button — everything narrative — at weight 600 for display, 500 for buttons, 400 for body. A matching monospaced face (Geist Mono) carries technical labels: terminal mockups, code blocks, sometimes filename captions. Headlines are sentence-case with aggressive negative letter-spacing (-2.4px at 48 px hero) — the brand never letter-spaces positively, never goe...

Color tokens:
- primary: #171717
- on-primary: #ffffff
- ink: #171717
- body: #4d4d4d
- mute: #888888
- hairline: #ebebeb
- hairline-strong: #a1a1a1
- canvas: #ffffff
- canvas-soft: #fafafa
- canvas-soft-2: #f5f5f5
- link: #0070f3
- link-deep: #0761d1
- link-bg-soft: #d3e5ff
- success: #0070f3

Typography tokens:
- display-xl: family Geist, Inter, system-ui, -apple-system, sans-serif, size 48px, weight 600, line 48px, tracking -2.4px
- display-lg: family Geist, Inter, system-ui, -apple-system, sans-serif, size 32px, weight 600, line 40px, tracking -1.28px
- display-md: family Geist, Inter, system-ui, -apple-system, sans-serif, size 24px, weight 600, line 32px, tracking -0.96px
- display-sm: family Geist, Inter, system-ui, -apple-system, sans-serif, size 20px, weight 600, line 28px, tracking -0.6px
- body-lg: family Geist, Inter, system-ui, -apple-system, sans-serif, size 18px, weight 400, line 28px, tracking 0px
- body-md: family Geist, Inter, system-ui, -apple-system, sans-serif, size 16px, weight 400, line 24px
- body-md-strong: family Geist, Inter, system-ui, -apple-system, sans-serif, size 16px, weight 500, line 24px
- body-sm: family Geist, Inter, system-ui, -apple-system, sans-serif, size 14px, weight 400, line 20px, tracking -0.28px
- body-sm-strong: family Geist, Inter, system-ui, -apple-system, sans-serif, size 14px, weight 500, line 20px, tracking -0.28px
- caption: family Geist, Inter, system-ui, -apple-system, sans-serif, size 12px, weight 400, line 16px
- caption-mono: family Geist Mono, ui-monospace, SFMono-Regular, Menlo, Monaco, monospace, size 12px, weight 400, line 16px
- code: family Geist Mono, ui-monospace, SFMono-Regular, Menlo, Monaco, monospace, size 13px, weight 400, line 20px

Spacing tokens:
- xxs: 4px
- xs: 8px
- sm: 12px
- md: 16px
- lg: 24px
- xl: 32px
- 2xl: 40px
- 3xl: 48px
- 4xl: 64px
- 5xl: 96px

Radius and shape tokens:
- none: 0px
- xs: 4px
- sm: 6px
- md: 8px
- lg: 12px
- xl: 16px
- pill-sm: 64px
- pill: 100px
- full: 9999px

Component tokens:
- nav-bar: backgroundColor: {colors.canvas}, textColor: {colors.ink}, typography: {typography.body-sm}, height: 64px, padding: {spacing.sm} {spacing.lg}
- nav-link: textColor: {colors.body}, typography: {typography.body-sm}, rounded: {rounded.full}, padding: {spacing.xs} {spacing.sm}
- nav-cta-signup: backgroundColor: {colors.primary}, textColor: {colors.on-primary}, typography: {typography.body-sm-strong}, rounded: {rounded.sm}, padding: 0px {spacing.xs}, height: 28px
- nav-cta-login: backgroundColor: {colors.canvas}, textColor: {colors.ink}, typography: {typography.body-sm-strong}, rounded: {rounded.sm}, padding: 0px {spacing.xs}, height: 28px
- nav-cta-ask-ai: backgroundColor: {colors.canvas}, textColor: {colors.ink}, borderColor: {colors.hairline}, typography: {typography.body-sm-strong}, rounded: {rounded.sm}, padding: 0px {spacing.xs}, height: 28px
- button-primary: backgroundColor: {colors.primary}, textColor: {colors.on-primary}, typography: {typography.button-lg}, rounded: {rounded.pill}, padding: 0px {spacing.sm}
- button-secondary: backgroundColor: {colors.canvas}, textColor: {colors.ink}, typography: {typography.button-lg}, rounded: {rounded.pill}, padding: 0px {spacing.sm}
- button-primary-sm: backgroundColor: {colors.primary}, textColor: {colors.on-primary}, typography: {typography.button-md}, rounded: {rounded.pill}, padding: 0px {spacing.xs}

Color rationale: Brand & Accent - Ink ({colors.primary} — 171717): The single primary CTA color. Black-near-pure ink that carries every Sign Up pill, every footer CTA, the dark-band polarity-flip. Used as text color throughout the page on light surfaces. (Resolved from --ds-gray-1000.) - Cyan ({colors.cyan} — 50e3c2): A signature mint-cyan used in the brand gradient and inside Geist-system spotlight tokens. Visible inside the hero gradient stops. - Highlight Pink ({colors.highlight-pink} — ff0080): The brand's highlight magenta, used as the high-saturation stop in the preview-gradient pair. - Violet ({colors.violet} — 7928ca): The deep purple used as the start of the preview-gradient and inside developer-console highlights. - Link Blue ({colors.link} — 0070f3): The brand's primary link color and the legacy --geist-success semantic. Surface - Canvas ({colors.canvas} — ffffff): The pure-white card / dialog / modal surface. - Canvas Soft ({colors.canvas-soft} — fafafa): The default page background — 98 % white. Almost every section sits on this tone. - Canvas Soft 2 ({colors.canvas-soft-2} — f5f5f5): A slightly deeper inset surface for "code editor inner background", template-card hover states, and d...

Typography rationale: Font Family Two custom faces carry the entire system: 1. A custom geometric sans (extracted as Geist) for every display, body, button, link, and label. Weights 400 / 500 / 600 are the working set; the face never appears in 700 or heavier. Display sizes are tracked aggressively negative (-2.4 px at 48 px hero, -1.28 px at 32 px section); body stays at neutral or slightly-negative tracking. 2. A custom monospaced face (extracted as Geist Mono) for terminal mockups, code blocks, and small mono-caption labels — anything that wants to signal "technical." Weight 400 only at 12 – 13 px. Tracking neutral. A condensed display sans (Space Grotesk) is loaded as a third face for occasional editorial moments but does not render as the primary face anywhere in the captured surfaces. Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.display-xl} | 48px | 600 | 48px | -2.4px | Hero headline ("Build and deploy on the AI Cloud."). | | {typography.display-lg} | 32px | 600 | 40px | -1.28px | Section headlines ("Your frontend, delivered.", "A compute model for all workloads."). | | {typography.display-md} | 24px | 600 | 32px | -0.96px | Car...

Layout system: Spacing System - Base unit: 4 px. The brand's --geist-space token is exactly 4 px and every captured value is a multiple of 4. - Tokens: {spacing.xxs} 4 px · {spacing.xs} 8 px · {spacing.sm} 12 px · {spacing.md} 16 px · {spacing.lg} 24 px · {spacing.xl} 32 px · {spacing.2xl} 40 px · {spacing.3xl} 48 px · {spacing.4xl} 64 px · {spacing.5xl} 96 px · {spacing.6xl} 128 px · {spacing.section} 192 px. - Section padding: marketing bands use {spacing.4xl} to {spacing.5xl} top/bottom. Hero bands stretch to {spacing.section} to give the mesh gradient room to breathe. - Card interior padding: marketing cards sit at {spacing.lg} to {spacing.xl}; template-grid cards stay tighter at {spacing.md} because they sit in a denser grid. - Inline gap: button rows, nav rows, and chip rows use {spacing.sm} to {spacing.md} between siblings. The brand's --geist-gap is exactly 24 px. Grid & Container - Max width: ~1400 px (--ds-page-width); the legacy --geist-page-width is 1200 px and still appears on some marketing surfaces. Content centres with horizontal gutters of {spacing.lg} 24 px on desktop, {spacing.md} 16 px on mobile. - Column patterns: - Three-feature row: 3-up at desktop, 1-up at mobile (rows li...

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | Level 0 — Flat | No shadow, no border. | Full-bleed hero bands and the polarity-flipped dark sections. | | Level 1 — Inset Hairline | 0 0 0 1px 00000014 inset 1 px border. | Default card chrome — the brand's universal "you can see this card" cue. | | Level 2 — Subtle Drop | 0px 1px 1px 00000005, 0px 2px 2px 0000000a plus inset hairline. | Slightly elevated cards (template-grid, marketing-card). | | Level 3 — Soft Stack | 0px 2px 2px 0000000a, 0px 8px 8px -8px 0000000a plus inset hairline. | The "medium" elevation — feature-grid cards. | | Level 4 — Float Stack | 0px 2px 2px 0000000a, 0px 8px 16px -4px 0000000a plus inset hairline. | "Large" elevation — pricing cards, callout panels. | | Level 5 — Modal | 0px 1px 1px 00000005, 0px 8px 16px -4px 0000000a, 0px 24px 32px -8px 0000000f plus inset hairline. | Modal / dialog surfaces and dropdown menus. | The brand uses STACKED shadows — multiple small offsets layered to fake natural light — never a single 8-px-blur generic drop. Inset hairline rings are always added so the card edge stays crisp. Decorative Depth - Mesh gradient as atmospheric depth: the hero's multi-stop gradient is the brand'...

Shape language: Border Radius Scale | Token | Value | Use | |---|---|---| | {rounded.none} | 0px | Full-bleed hero / footer bands. | | {rounded.xs} | 4px | Tightest inline pill — the nav-cta-signup 6-px-radius button (mapped to xs/sm). | | {rounded.sm} | 6px | The brand's --geist-radius token — base UI radius for in-app buttons, form inputs, dropdown menus. | | {rounded.md} | 8px | The brand's --geist-marketing-radius token — feature cards, template cards. | | {rounded.lg} | 12px | Slightly larger card chrome (pricing-card variants). | | {rounded.xl} | 16px | Largest card chrome — when a card hosts a hero image cap. | | {rounded.pill-sm} | 64px | Tab-ghost pills inside the "AI Apps / Web Apps / Ecommerce / Marketing / Platforms" row. | | {rounded.pill} | 100px | The marketing CTA pill — button-primary, button-secondary, "Start Deploying" pill. | | {rounded.full} | 9999px | Icon-button circular containers, nav-link ghost pills. | Photography Geometry - Mesh gradient: full-bleed 2-D atmospheric backdrop, never cropped to a frame; treated as the page's wallpaper. - Customer logos: monochrome SVG, consistent 24 px height in a flex row. - Code editor mockup: 16:10 dark rectangle, {rounded.md} corners....

Component language: Buttons button-primary — the canonical 100-px-radius black pill, marketing scale. - Background {colors.primary}, text {colors.on-primary}, label set in {typography.button-lg}, padding 0px...
```
