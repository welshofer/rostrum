# Grape

**ID:** `grape`  
**Category:** developer  
**Theme:** dark  
**Vibe:** Playful

## Color palette

- `#150f23`
- `#1f1633`
- `#ffffff`
- `#c2ef4e`
- `#fa7faa`
- `#6a5fc1`
- `#422082`
- `#79628c`
- `#f0f0f0`
- `#efefef`

## Typography

Families: "Monaco, Menlo, Ubuntu Mono, monospace", "Rubik, -apple-system, system-ui, Segoe UI, Helvetica, Arial, sans-serif", "Rubik, -apple-system, system-ui, sans-serif", "Sentri Display, Rubik, system-ui, sans-serif". Weights: 400, 500, 600, 700.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Sentry

Design token description: a developer-tools brand built on a deep purple-violet midnight canvas, electric lime accents, and a slightly subversive illustrated personality. The system pairs a custom display sans (chunky, playful, near-condensed) with the open Rubik family for UI copy and Monaco for code, then leans on dark-on-light pricing surfaces, sticker-style mascots, and a single-color CTA hierarchy where black-violet buttons read as the primary action against either polarity.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- Detected source-domain vocabulary: search/productivity software, consumer technology. Translate it into reusable visual behavior, not literal imagery.
- Avoid literal source imagery unless the exact slide text or visual direction explicitly requests it: search bars, search result pages, browser chrome, or app screenshots; product logos, app icons, map pins, or play-button branding; phones, laptops, tablets, device mockups, or hardware product renders; app screenshots, operating-system chrome, or product launch hero shots.

Overall visual personality: Sentri's design language reads like a debugging console wearing a leather jacket. The home and product surfaces sit on a near-black violet midnight ({colors.surface-canvas-dark} / {colors.surface-night}), strewn with starfield textures and floating sticker-style mascots — astronauts, monsters, traffic cones — that puncture the seriousness of an observability product. Headlines run in a chunky proprietary display sans where the most important keywords are wrapped in lime-green highlight chips ({colors.accent-lime}), as if the copy itself has been marked up by a developer redlining their own console output. The palette is deliberately narrow: deep midnight as the dominant canvas, electric lime as the primary attention-grabber, hot pink ({colors.accent-pink}) as a secondary punctuation, and a violet-mid ({colors.accent-violet-mid}) for tag chips and hairline strokes. White appears in two roles — as text on dark, and as the canvas for pricing, contact, and content-heavy pages where developers need to scan dense tables. The "single primary CTA" is visually inverted depending on context: filled black-violet ({colors.primary}) with white type on light surfaces, or filled white with dark...

Color tokens:
- primary: #150f23
- ink-deep: #1f1633
- on-primary: #ffffff
- accent-lime: #c2ef4e
- accent-pink: #fa7faa
- accent-violet: #6a5fc1
- accent-violet-deep: #422082
- accent-violet-mid: #79628c
- surface-canvas-dark: #1f1633
- surface-canvas-light: #ffffff
- surface-night: #150f23
- surface-press-light: #f0f0f0
- surface-press-stronger: #efefef
- hairline-violet: #362d59

Typography tokens:
- display-hero: family Sentri Display, Rubik, system-ui, sans-serif, size 88px, weight 700, line 1.2, tracking 0
- display-large: family Sentri Display, Rubik, system-ui, sans-serif, size 60px, weight 500, line 1.1, tracking 0
- heading-xl: family Rubik, -apple-system, system-ui, Segoe UI, Helvetica, Arial, sans-serif, size 30px, weight 500, line 1.2, tracking 0
- heading-lg: family Rubik, -apple-system, system-ui, sans-serif, size 27px, weight 500, line 1.25, tracking 0
- heading-md: family Rubik, -apple-system, system-ui, sans-serif, size 24px, weight 500, line 1.25, tracking 0
- heading-sm: family Rubik, -apple-system, system-ui, sans-serif, size 20px, weight 600, line 1.25, tracking 0
- body-lg: family Rubik, -apple-system, system-ui, sans-serif, size 16px, weight 400, line 2.0, tracking 0
- body-strong: family Rubik, -apple-system, system-ui, sans-serif, size 16px, weight 600, line 1.5, tracking 0
- body-md: family Rubik, -apple-system, system-ui, sans-serif, size 16px, weight 500, line 1.5, tracking 0
- eyebrow: family Rubik, -apple-system, system-ui, sans-serif, size 15px, weight 500, line 1.4, tracking 0
- button-cap: family Rubik, -apple-system, system-ui, sans-serif, size 14px, weight 700, line 1.14, tracking 0.2px
- button-cap-light: family Rubik, -apple-system, system-ui, sans-serif, size 14px, weight 500, line 1.29, tracking 0.2px

Spacing tokens:
- xxs: 2px
- xs: 4px
- sm: 8px
- md: 12px
- lg: 16px
- xl: 24px
- xxl: 32px
- section: 96px

Radius and shape tokens:
- xs: 4px
- sm: 6px
- md: 8px
- lg: 10px
- xl: 12px
- xxl: 18px
- full: 9999px

Component tokens:
- button-primary: backgroundColor: {colors.primary}, textColor: {colors.on-primary}, typography: {typography.button-cap}, rounded: {rounded.md}, padding: 12px 16px
- button-primary-pressed: backgroundColor: {colors.surface-press-stronger}, textColor: {colors.ink-press}, typography: {typography.button-cap}, rounded: {rounded.md}, padding: 12px 16px
- button-inverted: backgroundColor: {colors.on-primary}, textColor: {colors.ink-deep}, typography: {typography.button-cap}, rounded: {rounded.md}, padding: 12px 16px
- button-inverted-pressed: backgroundColor: {colors.surface-press-light}, textColor: {colors.ink-press}, typography: {typography.button-cap}, rounded: {rounded.md}, padding: 12px 16px
- button-ghost-on-dark: backgroundColor: {colors.on-dark-faint}, textColor: {colors.on-primary}, typography: {typography.button-cap}, rounded: {rounded.xl}, padding: 8px
- button-violet-token: backgroundColor: {colors.accent-violet-mid}, textColor: {colors.on-primary}, typography: {typography.button-cap-light}, rounded: {rounded.xl}, padding: 8px 16px
- button-disabled: backgroundColor: {colors.hairline-cloud}, textColor: {colors.on-dark-muted}, typography: {typography.button-cap}, rounded: {rounded.md}, padding: 12px 16px
- pill-neutral-dark: backgroundColor: {colors.surface-night}, textColor: {colors.on-primary}, typography: {typography.caption}, rounded: {rounded.xs}, padding: 4px 8px

Color rationale: Source pages: home (/welcome/), product/error-monitoring, contact/enterprise, pricing. Brand & Accent - Midnight Violet ({colors.primary} — 150f23): The system's primary action color and the deepest the source brand tone. Used for filled primary buttons on light surfaces, code-block backgrounds, and the strongest dark cards. - Ink Violet ({colors.ink-deep} — 1f1633): Slightly lifted from primary, this is the marketing hero canvas and the default body-text color on light surfaces — a single token doing double duty as background and ink. - Electric Lime ({colors.accent-lime} — c2ef4e): The signature highlight color. Wrapped around individual headline keywords as a syntax-highlight chip ({rounded.xs} corner, no padding-y, 12px padding-x). Also used as the squiggly footer divider stroke. Never a button background. - Hot Pink ({colors.accent-pink} — fa7faa): Secondary punctuation color used for sticker outlines, chart points, and supporting accents — never on buttons, never on type at body size. - Violet Link ({colors.accent-violet} — 6a5fc1): Inline link color when emphasis is needed beyond underline. - Deep Violet ({colors.accent-violet-deep} — 422082): The select-dropdown fill on co...

Typography rationale: Font Family The display tier is a proprietary geometric sans with chunky, near-condensed proportions and a slightly subversive personality (closing apertures, optical-stress letterforms). When unavailable, fall back to Rubik at heavier weights for visual continuity. The UI tier is Rubik — an open-source Hebrew/Latin sans on the source brand Fonts — with system fallbacks (-apple-system, system-ui, Segoe UI, Helvetica, Arial). Rubik handles every body, caption, button, and eyebrow role. The code tier is Monaco with Menlo and Ubuntu Mono fallbacks — used in code blocks, install snippets, and inline tokens. Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.display-hero} | 88px | 700 | 1.2 | 0 | Marketing hero headline (single line of attention) | | {typography.display-large} | 60px | 500 | 1.1 | 0 | Section openers on dark surfaces | | {typography.heading-xl} | 30px | 500 | 1.2 | 0 | Page titles on light surfaces (e.g., "Pricing plans for dev teams of all sizes") | | {typography.heading-lg} | 27px | 500 | 1.25 | 0 | Sub-section headings, large card titles | | {typography.heading-md} | 24px | 500 | 1.25 | 0 | Card titles, i...

Layout system: Spacing System - Base unit: 8px - Tokens: {spacing.xxs} 2px · {spacing.xs} 4px · {spacing.sm} 8px · {spacing.md} 12px · {spacing.lg} 16px · {spacing.xl} 24px · {spacing.xxl} 32px · {spacing.section} 96px - Section padding: {spacing.section} 96px between major page bands on desktop, collapsing to {spacing.xxl} 32px–48px on mobile. - Card internal padding: {spacing.xxl} 32px on pricing cards and large feature cards; {spacing.lg} 16px on compact tag/badge groups. - Form field padding: {spacing.sm} 8px vertical, {spacing.md} 12px horizontal — matches the text-input token directly. Grid & Container - Marketing pages use a wide centered container with generous outer gutters; max width sits around 1152px (one of the extracted breakpoints), with content inside flexing across 12 conceptual columns. - Pricing splits into a 4-tier card row at desktop, collapsing to 2-up at mid widths and 1-up on mobile. - The contact form uses a 2-column field layout (first/last name side-by-side) inside a single light-canvas panel. - Breakpoints stair-step at 1440 → 1152 → 992 → 768 → 640 → 576 — see Responsive Behavior. Whitespace Philosophy The dark canvas absorbs whitespace differently from light. On dar...

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | 0 | Flat on canvas, no shadow | Default the source brand, dark or light | | 1 | box-shadow: rgba(0,0,0,0.08) 0 2px 8px 0 | Inverted buttons on dark canvas (light fill lifting off dark the source brand) | | 2 | box-shadow: rgba(0,0,0,0.1) 0 10px 15px -3px, rgba(0,0,0,0.1) 0 4px 6px -4px | Floating cards on light canvas, modals | | 3 | box-shadow: rgb(21,15,35) 0 0 8px 6px | Glow halo around primary CTA on dark hero — the dark color itself becomes the shadow, creating a vignette of canvas around the button | | 4 | box-shadow: rgba(0,0,0,0.18) 0 0.5rem 1.5rem | Pressed inverted button on dark canvas | Decorative Depth Sentri's depth doesn't come from drop shadows — it comes from the starfield texture on the hero canvas (subtle white-on-violet pinpricks at low opacity), the floating sticker mascots (drawn with hand-rendered outlines and saturated fills, layered above the canvas with no shadow), and the lime squiggly divider above the footer. These illustrative elements do the work that shadow stacks do in flatter design systems — they tell the eye where one section ends and another begins.

Shape language: Border Radius Scale | Token | Value | Use | |---|---|---| | {rounded.xs} | 4px | Badges, status pills, lime keyword highlight chips | | {rounded.sm} | 6px | Text inputs, search boxes | | {rounded.md} | 8px | Primary and inverted buttons, code blocks, select dropdowns | | {rounded.lg} | 10px | Generic divs, container blocks | | {rounded.xl} | 12px | Pricing cards, feature cards, navigation pill the source brand | | {rounded.xxl} | 18px | Image containers, large hero illustrations | | {rounded.full} | 9999px | Avatars, circular icon buttons | Photography Geometry The site doesn't use traditional photography — it uses illustrated stickers and product UI screenshots in roughly equivalent geometric roles. Product UI mocks sit inside {rounded.xxl} 18px containers, often tilted slightly off-axis, against the dark canvas with no border. Sticker mascots have no container at all — they are layered directly on canvas, often overlapping section boundaries to break the grid. Avatar treatments (in customer-logo strips) are simple greyscale wordmarks, not photos.

Co...
```
