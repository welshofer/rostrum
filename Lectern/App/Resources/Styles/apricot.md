# Apricot

**ID:** `apricot`  
**Category:** developer  
**Theme:** light  
**Vibe:** Editorial

## Color palette

- `#f7f7f4`
- `#26251e`
- `#f54e00`
- `#d04200`
- `#5a5852`
- `#807d72`
- `#a09c92`
- `#e6e5e0`
- `#efeee8`
- `#cfcdc4`

## Typography

Families: "'CursorGothic', sans-serif", "'CursorGothic', system-ui, 'Helvetica Neue', Helvetica, Arial, sans-serif", "'JetBrains Mono', 'Fira Code', monospace". Weights: 400, 500, 600.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Cursor

Design token description: An AI-first code editor whose marketing site reads like a quietly-confident developer-tools brand with a warm-cream editorial canvas (f7f7f4) instead of the typical dark IDE atmosphere. Near-black warm ink (26251e) carries body and display alike — display sits at weight 400 with negative letter-spacing for a magazine feel rather than a bold tech voice. The single brand voltage is Cursor Orange (f54e00) reserved for primary CTAs and the wordmark. A signature pastel timeline palette (peach, mint, blue, lavender, gold) marks AI-action stages (Thinking / Reading / Editing / Grepping / Done) — only inside in-product timeline visualizations. Cards use minimal hairlines, no shadows, generous 80px section rhythm. CursorGothic for display/body, JetBrains Mono on every code surface (which is roughly half the page).

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- No dominant source-domain vocabulary was detected, but still avoid copying example subject matter from the design brief.
- Avoid brand logos, product shots, mascot imagery, packaging, buildings, people, or industry-specific objects unless requested by the slide content.

Overall visual personality: Cursor's marketing site reads as a quietly-confident developer brand that believes in editorial calm over IDE-darkness. The base canvas is warm cream ({colors.canvas} — f7f7f4) holding warm near-black ink ({colors.ink} — 26251e) for body and display alike. The single brand voltage is Cursor Orange ({colors.primary} — f54e00) reserved for primary CTAs and the wordmark — used scarcely. Type runs CursorGothic as the single sans family. Display sits at weight 400 with negative letter-spacing — a magazine-editorial voice rather than tech-bombastic. JetBrains Mono carries every code surface (and code surfaces are roughly half the page). The brand's strongest visual signature is the AI-timeline pill palette: five pastel pills (peach {colors.timeline-thinking}, mint {colors.timeline-grep}, blue {colors.timeline-read}, lavender {colors.timeline-edit}, gold {colors.timeline-done}) marking AI-action stages inside in-product timeline visualizations. Used only in product UI — never as system action colors. Key Characteristics: - Warm cream canvas, not white. Ink is warm (26251e), not pure black. - Single CTA color: {colors.primary} (Cursor Orange f54e00). Used scarcely. - Display weight stays...

Color tokens:
- primary: #f54e00
- primary-active: #d04200
- ink: #26251e
- body: #5a5852
- body-strong: #26251e
- muted: #807d72
- muted-soft: #a09c92
- hairline: #e6e5e0
- hairline-soft: #efeee8
- hairline-strong: #cfcdc4
- canvas: #f7f7f4
- canvas-soft: #fafaf7
- surface-card: #ffffff
- surface-strong: #e6e5e0

Typography tokens:
- display-mega: family 'CursorGothic', system-ui, 'Helvetica Neue', Helvetica, Arial, sans-serif, size 72px, weight 400, line 1.1, tracking -2.16px
- display-lg: family 'CursorGothic', sans-serif, size 36px, weight 400, line 1.2, tracking -0.72px
- display-md: family 'CursorGothic', sans-serif, size 26px, weight 400, line 1.25, tracking -0.325px
- display-sm: family 'CursorGothic', sans-serif, size 22px, weight 400, line 1.3, tracking -0.11px
- title-md: family 'CursorGothic', sans-serif, size 18px, weight 600, line 1.4, tracking 0
- title-sm: family 'CursorGothic', sans-serif, size 16px, weight 600, line 1.4, tracking 0
- body-md: family 'CursorGothic', sans-serif, size 16px, weight 400, line 1.5, tracking 0
- body-tracked: family 'CursorGothic', sans-serif, size 16px, weight 400, line 1.5, tracking 0.08px
- body-sm: family 'CursorGothic', sans-serif, size 14px, weight 400, line 1.5, tracking 0
- caption: family 'CursorGothic', sans-serif, size 13px, weight 400, line 1.4, tracking 0
- caption-uppercase: family 'CursorGothic', sans-serif, size 11px, weight 600, line 1.4, tracking 0.88px
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
- section: 80px

Radius and shape tokens:
- none: 0px
- xs: 4px
- sm: 6px
- md: 8px
- lg: 12px
- xl: 16px
- pill: 9999px
- full: 9999px

Component tokens:
- top-nav: backgroundColor: {colors.canvas}, textColor: {colors.ink}, typography: {typography.nav-link}, height: 64px
- button-primary: backgroundColor: {colors.primary}, textColor: {colors.on-primary}, typography: {typography.button}, rounded: {rounded.md}, padding: 10px 18px, height: 40px
- button-primary-active: backgroundColor: {colors.primary-active}, textColor: {colors.on-primary}, rounded: {rounded.md}
- button-secondary: backgroundColor: {colors.surface-card}, textColor: {colors.ink}, typography: {typography.button}, rounded: {rounded.md}, padding: 9px 17px, height: 40px
- button-tertiary-text: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.button}
- button-download: backgroundColor: {colors.ink}, textColor: {colors.canvas}, typography: {typography.button}, rounded: {rounded.md}, padding: 12px 20px, height: 44px
- hero-band: backgroundColor: {colors.canvas}, textColor: {colors.ink}, typography: {typography.display-mega}, padding: 80px
- ide-mockup-card: backgroundColor: {colors.surface-card}, textColor: {colors.ink}, rounded: {rounded.lg}, padding: 0

Color rationale: Brand & Accent - Cursor Orange ({colors.primary} — f54e00): Primary CTA pills, wordmark, hero accent. Used scarcely. - Cursor Orange Active ({colors.primary-active} — d04200): Press state. Surface - Canvas ({colors.canvas} — f7f7f4): Warm cream page floor. - Canvas Soft ({colors.canvas-soft} — fafaf7): IDE-pane background inside mockups. - Surface Card ({colors.surface-card} — ffffff): Pure white card surface — slight contrast against the cream canvas. - Surface Strong ({colors.surface-strong} — e6e5e0): Badges, tag pills. Hairlines - Hairline ({colors.hairline} — e6e5e0): 1px divider. - Hairline Soft ({colors.hairline-soft} — efeee8): Lighter divider. - Hairline Strong ({colors.hairline-strong} — cfcdc4): Stronger panel outline. Text - Ink ({colors.ink} — 26251e): Display, body emphasis. Warm near-black. - Body ({colors.body} — 5a5852): Default running-text. - Body Strong ({colors.body-strong} — 26251e): Same as ink. - Muted ({colors.muted} — 807d72): Sub-titles. - Muted Soft ({colors.muted-soft} — a09c92): Disabled text. - On Primary ({colors.on-primary} — ffffff): White text on Cursor Orange. Timeline (AI-action signature) - Thinking ({colors.timeline-thinking} — dfa88f): Peach...

Typography rationale: Font Family CursorGothic is the licensed display + body family. Fallback: system-ui, "Helvetica Neue", Helvetica, Arial, sans-serif. Code surfaces switch to JetBrains Mono. Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.display-mega} | 72px | 400 | 1.1 | -2.16px | Homepage hero h1 | | {typography.display-lg} | 36px | 400 | 1.2 | -0.72px | Section heads | | {typography.display-md} | 26px | 400 | 1.25 | -0.325px | Sub-section heads | | {typography.display-sm} | 22px | 400 | 1.3 | -0.11px | Card group titles | | {typography.title-md} | 18px | 600 | 1.4 | 0 | Component titles | | {typography.title-sm} | 16px | 600 | 1.4 | 0 | List labels | | {typography.body-md} | 16px | 400 | 1.5 | 0 | Default body | | {typography.body-tracked} | 16px | 400 | 1.5 | 0.08px | Tracked editorial body | | {typography.body-sm} | 14px | 400 | 1.5 | 0 | Footer body | | {typography.caption} | 13px | 400 | 1.4 | 0 | Photo captions | | {typography.caption-uppercase} | 11px | 600 | 1.4 | 0.88px | Section labels, timeline pill labels | | {typography.code} | 13px | 400 | 1.5 | 0 | Code blocks — JetBrains Mono | | {typography.button} | 14px | 500 | 1...

Layout system: Spacing System - Base unit: 4px. - Tokens: {spacing.xxs} 4px · {spacing.xs} 8px · {spacing.sm} 12px · {spacing.base} 16px · {spacing.md} 20px · {spacing.lg} 24px · {spacing.xl} 32px · {spacing.xxl} 48px · {spacing.section} 80px. - Section padding: 80px. Grid & Container - Max content width: ~1200px. - Editorial body: 12-column grid. - Feature card grids: 2-up at desktop for splits, 3-up for benefits. - Footer: 5-column at desktop. Whitespace Philosophy Generous editorial pacing — closer to a print magazine than a tech site. The cream canvas has plenty of breathing room; cards within bands sit close (16-24px gap).

Depth and hierarchy: The system uses hairline-only depth. No drop shadows, no elevation tiers. Cards float above the canvas via 1px hairlines and the slight white-on-cream contrast. | Level | Treatment | Use | |---|---|---| | Flat (canvas) | {colors.canvas} (f7f7f4) | Body bands, footer | | Card | {colors.surface-card} (ffffff) | Content cards | | Hairline border | 1px {colors.hairline} | Card outlines, dividers | | IDE pane | {colors.canvas-soft} (fafaf7) | Inside IDE mockup cards | Decorative Depth - IDE-mockup cards are the only "elevated" element. White card on cream canvas with internal pane structure mimicking the actual Cursor editor. - Timeline pastel pills add chromatic depth without surface elevation.

Shape language: Border Radius Scale | Token | Value | Use | |---|---|---| | {rounded.none} | 0px | Reserved | | {rounded.xs} | 4px | Inline tags | | {rounded.sm} | 6px | Compact rows | | {rounded.md} | 8px | CTA buttons, form inputs | | {rounded.lg} | 12px | Cards, IDE panes | | {rounded.xl} | 16px | Larger feature cards (rare) | | {rounded.pill} | 9999px | Timeline pills, badges | | {rounded.full} | 9999px | Avatars (rare) |

Component language: Top Navigation top-nav — Background {colors.canvas}, text {colors.ink}, height 64px. Layout: Cursor wordmark left, primary horizontal menu (Pricing / Features / Enterprise / Blog / Forum / Careers), Sign In + Download primary CTA right. Buttons button-primary — The signature Cursor Orange CTA. Background {colors.primary}, text {colors.on-primary}, type {typography.button} (14px / 500), padding 10px × 18px, height 40px, rounded {rounded.md} (8px). button-primary-active — Press state. Background {colors.primary-active}. button-secondary — White card pill on cream canvas. Background {colors.surface-card}, text {colors.ink}, 1px {colors.hairline-strong} border. button-tertiary-text — Inline ink text link. button-download — Larger ink-canvas CTA. Background {colors.ink}, text {colors.canvas}, padding 12px × 20px, height 44px. Used for "Download for macOS" type CTAs. Hero & IDE Mockups hero-band — Background {colors.canvas}, full-width display headline in {typography.display-mega} (72px / 400 / -2.16px), subhead in {typography.body-md}, two CTAs (button-download + button-tertiary-text), and a centered IDE-mockup card below the hero copy. ide-mockup-card — A white card containing a multi...

Guardrails: Do - Reserve {colors.primary} (Cursor Orange) for primary CTAs and brand wordmark. - Keep display weight at 400. The editorial voice depends on this. - Use the cream {colors.canvas} page floor — never pure white. - Render every code surface (inline, blocks, IDE panes) in JetBrains Mono. - Use timeline pastels only inside in-product agent visualizations — never as system action colors. Don't - Don't introduce a secondary brand action color. Cursor Orange is the only one. - Don't drop display to bold weights (700+). Magazine voice depends on 400. - Don't add drop shadows. Hairlines + ink-on-cream contrast carry the depth. - Don't use timeline pastels on non-timeline UI. They're scoped to the agent timeline only. - Don't extract a CTA color from a third-party widget (cookie consent, OneTrust). The brand's CTA is what appears on...
```
