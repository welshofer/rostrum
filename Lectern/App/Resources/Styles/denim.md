# Denim

**ID:** `denim`  
**Category:** enterprise  
**Theme:** light  
**Vibe:** Corporate

## Color palette

- `#0f62fe`
- `#ffffff`
- `#161616`
- `#525252`
- `#8c8c8c`
- `#f4f4f4`
- `#e0e0e0`
- `#262626`
- `#c6c6c6`
- `#0043ce`

## Typography

Families: IBM Plex Sans. Weights: 300, 400, 600.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: IBM

Design token description: An enterprise-marketing canvas faithful to Carbon Design System: white surfaces, charcoal type, IBM Blue (0f62fe) as the single confident accent, and a deliberately flat-square aesthetic where corners stay at 0–4px. Type runs IBM Plex Sans at light weight 300 for display sizes (a brand signature) and 400/600 for body and emphasis. Cards live as thin-bordered tiles with no shadow; sections separate via subtle gray rows. The the source brand is square, the typography is light, and the only color in the system is one assertive blue — the result reads as old-world enterprise gravitas reframed for the cloud era.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- Detected source-domain vocabulary: search/productivity software, automotive/performance. Translate it into reusable visual behavior, not literal imagery.
- Avoid literal source imagery unless the exact slide text or visual direction explicitly requests it: search bars, search result pages, browser chrome, or app screenshots; product logos, app icons, map pins, or play-button branding; cars or vehicle product shots; roads, racetracks, or driving scenes; wheels, tires, grilles, headlights, engines, cockpits, or drivers.

Overall visual personality: IBM's marketing system is a faithful application of Carbon Design System — IBM's open-source enterprise design system. The dominant surface is {colors.canvas} pure white with {colors.surface-1} light gray for elevation, charcoal {colors.ink} (161616) for text, and IBM Blue {colors.primary} (0f62fe) as the single brand accent. The defining choice is flat geometry: every CTA, every card, every input, every container uses square corners ({rounded.none} 0px) with thin 1px borders. There are no rounded pills, no soft shadows, no atmospheric gradients. The system is engineered, not stylized. IBM Plex Sans carries the entire type hierarchy. Display sizes (76 / 60 / 42px) run at weight 300 — IBM's signature light display treatment that makes 76px feel calmer than competing brands' 700-weight display. Body type sits at weight 400 with letter-spacing: 0.16px (a Carbon precision detail) and line-height 1.50. The voice reads as careful, technical, and trustworthy. The system reaches for color rarely — IBM Blue marks links, primary CTAs, and the rare full-bleed CTA banner. Charcoal carries every other surface that isn't white. The result is enterprise gravitas without the enterprise stiffness:...

Color tokens:
- primary: #0f62fe
- on-primary: #ffffff
- ink: #161616
- ink-muted: #525252
- ink-subtle: #8c8c8c
- canvas: #ffffff
- surface-1: #f4f4f4
- surface-2: #e0e0e0
- inverse-canvas: #161616
- inverse-surface-1: #262626
- inverse-ink: #ffffff
- inverse-ink-muted: #c6c6c6
- hairline: #e0e0e0
- hairline-strong: #161616

Typography tokens:
- display-xl: family IBM Plex Sans, size 76px, weight 300, line 1.17, tracking -0.5px
- display-lg: family IBM Plex Sans, size 60px, weight 300, line 1.17, tracking -0.4px
- display-md: family IBM Plex Sans, size 42px, weight 300, line 1.20, tracking 0
- headline: family IBM Plex Sans, size 32px, weight 400, line 1.25, tracking 0
- card-title: family IBM Plex Sans, size 24px, weight 400, line 1.33, tracking 0
- subhead: family IBM Plex Sans, size 20px, weight 400, line 1.40, tracking 0
- body-lg: family IBM Plex Sans, size 18px, weight 400, line 1.50, tracking 0
- body: family IBM Plex Sans, size 16px, weight 400, line 1.50, tracking 0.16px
- body-sm: family IBM Plex Sans, size 14px, weight 400, line 1.29, tracking 0.16px
- body-emphasis: family IBM Plex Sans, size 14px, weight 600, line 1.29, tracking 0.16px
- caption: family IBM Plex Sans, size 12px, weight 400, line 1.33, tracking 0.32px
- button: family IBM Plex Sans, size 14px, weight 400, line 1.29, tracking 0.16px

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
- none: 0px
- xs: 2px
- sm: 4px
- md: 6px
- lg: 8px
- pill: 9999px
- full: 9999px

Component tokens:
- button-primary: backgroundColor: {colors.primary}, textColor: {colors.on-primary}, typography: {typography.button}, rounded: {rounded.none}, padding: 12px 16px
- button-primary-pressed: backgroundColor: {colors.blue-80}, textColor: {colors.on-primary}, typography: {typography.button}, rounded: {rounded.none}
- button-secondary: backgroundColor: {colors.ink}, textColor: {colors.inverse-ink}, typography: {typography.button}, rounded: {rounded.none}, padding: 12px 16px
- button-tertiary: backgroundColor: {colors.canvas}, textColor: {colors.primary}, typography: {typography.button}, rounded: {rounded.none}, padding: 12px 16px
- button-ghost: backgroundColor: {colors.canvas}, textColor: {colors.primary}, typography: {typography.button}, rounded: {rounded.none}, padding: 12px 16px
- button-danger: backgroundColor: {colors.semantic-error}, textColor: {colors.on-primary}, typography: {typography.button}, rounded: {rounded.none}, padding: 12px 16px
- feature-card: backgroundColor: {colors.canvas}, textColor: {colors.ink}, typography: {typography.body}, rounded: {rounded.none}, padding: 24px
- feature-card-elevated: backgroundColor: {colors.surface-1}, textColor: {colors.ink}, typography: {typography.body}, rounded: {rounded.none}, padding: 24px

Color rationale: Source pages: ibm.com (home), /software/ai-productivity, /consulting, /products/cloud-pak-for-aiops, /products/bare-metal-servers, community.ibm.com. Brand & Accent - IBM Blue ({colors.primary}): The single brand accent. Links, primary CTAs, CTA banner backgrounds, focus rings. - Blue 60 ({colors.blue-60}): Hovered link state. - Blue 80 ({colors.blue-80}): Pressed primary button. - Blue Hover ({colors.blue-hover}): Hover state for primary buttons. Surface - Canvas ({colors.canvas}): Default page background. - Surface 1 ({colors.surface-1}): Light gray (f4f4f4) — input fields, alternate-row stripes, subtle section bands. - Surface 2 ({colors.surface-2}): Slightly darker gray (e0e0e0) — disabled fields, hairline-as-fill for separators. - Hairline ({colors.hairline}): 1px borders on cards, inputs, dividers. - Hairline Strong ({colors.hairline-strong}): 1px charcoal underline on focused inputs (Carbon's signature focus treatment). - Inverse Canvas ({colors.inverse-canvas}): Charcoal 161616 — footer surface. - Inverse Surface 1 ({colors.inverse-surface-1}): One step lighter than inverse canvas — footer column dividers, hovered footer items. Text - Ink ({colors.ink}): All headlines and...

Typography rationale: Font Family - IBM Plex Sans — IBM's open-source proprietary typeface (free for any use). Geometric, slightly humanist, designed specifically for enterprise UI. Fallback: Helvetica Neue, Arial, sans-serif. The same family carries display, body, and caption — there is no display + body pairing. Hierarchy is carried by size + weight rather than by family change. Plex Sans is also free / open-source under the SIL Open Font License — making it the easiest custom face on this list to substitute for in implementation. Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.display-xl} | 76px | 300 | 1.17 | -0.5px | Largest hero headline | | {typography.display-lg} | 60px | 300 | 1.17 | -0.4px | Section opener headlines | | {typography.display-md} | 42px | 300 | 1.20 | 0 | Sub-section headlines, hero card title | | {typography.headline} | 32px | 400 | 1.25 | 0 | Card collection heading, FAQ category | | {typography.card-title} | 24px | 400 | 1.33 | 0 | Feature card title | | {typography.subhead} | 20px | 400 | 1.40 | 0 | Lead body next to display headlines | | {typography.body-lg} | 18px | 400 | 1.50 | 0 | Hero subhead, lead paragra...

Layout system: Spacing System - Base unit: 4px (Carbon's signature 4-pixel grid). - Tokens (front matter): {spacing.xxs} 4px · {spacing.xs} 8px · {spacing.sm} 12px · {spacing.md} 16px · {spacing.lg} 24px · {spacing.xl} 32px · {spacing.xxl} 48px · {spacing.section} 96px. - Card interior padding: {spacing.lg} 24px on feature cards; {spacing.xl} 32px on product cards; {spacing.xxl} 48px on hero cards and CTA banners. - Button padding: 12px vertical · 16px horizontal — Carbon spec. - Form input padding: 11px vertical · 16px horizontal. Grid & Container - Carbon's 16-column grid at desktop, scaling to 8 / 4 columns at tablet / mobile. - Max content width sits around 1584px (Carbon's max-grid breakpoint). - Card grids are 4-up at desktop, 2-up at tablet, 1-up at mobile. - The customer logo marquee uses fixed-width tiles in a flex row, scrolling horizontally on smaller viewports. Whitespace Philosophy Carbon uses precise alignment to a 4-pixel grid as its whitespace system. Sections separate via thin gray rows ({colors.surface-1}) rather than via large vertical gaps. Content is dense by design — IBM's customers expect to see a lot on a page, not a lot of air.

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | 0 (flat) | No shadow, no border | Default for body type, hero text, footer body | | 1 (hairline) | 1px {colors.hairline} border on canvas | Feature cards, inputs, list items | | 2 (surface lift) | {colors.surface-1} background on canvas | Alternate-row banners, hovered cards | | 3 (focus ring) | 2px {colors.primary} outline + 1px {colors.hairline-strong} underline | Focused input, focused button | Carbon resists drop shadows on marketing — depth is carried by surface change and 1px hairlines. The exception is product / app surfaces (Carbon documents shadow tokens for elevated panels), but the marketing site barely uses them. Decorative Depth - Soft blue gradient backdrops appear behind some hero illustrations — a faint blue-to-white wash that warms the canvas without competing with the headline. - No atmospheric depth. No spotlight cards, no pastel section blocks, no gradient panels.

Shape language: Border Radius Scale | Token | Value | Use | |---|---|---| | {rounded.none} | 0px | Default — every button, card, input, container | | {rounded.xs} | 2px | Small badges (rare exception) | | {rounded.sm} | 4px | Avatar circles squared, dropdown menus | | {rounded.md} | 6px | (Used rarely; documented for completeness) | | {rounded.lg} | 8px | (Used rarely; documented for completeness) | | {rounded.pill} | 9999px | Status pills, badges in product UI (rare on marketing) | The brand commits to flat 0px corners. The other tokens exist for product / mobile surfaces but rarely surface on marketing. Photography & Illustration Geometry - IBM uses photography (people, hardware, sports engineered subject matter) and abstract illustration (geometric mesh, dotted patterns) interchangeably. - Image frames are flat — no rounded corners. - Customer logo tiles sit on {rounded.none} 0px tiles with thin 1px borders.

Component language: Buttons button-primary — Blue solid CTA. The default primary across all pages. - Background {colors.primary}, text {colors.on-primary}, type {typography.button}, padding 12px 16px, rounded {rounded.none}. - Pressed state lives in button-primary-pressed (background shifts to {colors.blue-80}). button-secondary — Charcoal solid button — Carbon's "secondary" treatment. - Background {colors.ink}, text {colors.inverse-ink}, type {typography.button}, padding 12px 16px, rounded {rounded.none}. button-tertiary — White button with blue 1px border + blue text. Used for tertiary CTAs. - Background {colors.canvas}, text {colors.primary}, type {typography.button}, rounded {rounded.none}, padding 12px 16px. (Border in implementation: 1px {colors.primary}.) button-ghost — Plain text + chevron, no background until hover...
```
