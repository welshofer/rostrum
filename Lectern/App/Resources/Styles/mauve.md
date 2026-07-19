# Mauve

**ID:** `mauve`  
**Category:** consumer  
**Theme:** dark  
**Vibe:** Playful

## Color palette

- `#e57cd8`
- `#ffde91`
- `#000000`
- `#564260`
- `#412a4c`
- `#6b5a74`
- `#fefbfa`
- `#2c1338`
- `#fcf1f8`
- `#fdeae2`

## Typography

Families: "BodyFont, sans-serif", "DisplayFont, sans-serif", "DisplayFont-Italic, sans-serif". Weights: 400, 500, 700.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Toggl Track

Design token description: A theatrical duotone system built on a deep aubergine canvas (2c1338) and a warm off-white content floor (fefbfa). A single, vivid magenta-pink (e57cd8) serves as the sole accent, used for primary CTAs and a signature italicized emphasis word within each major headline. Surfaces are flat, relying on the contrast between dark and light bands for depth, not shadows. Components are chunky and generously rounded (10px for cards, 26px for buttons, 200px for pills). A geometric display font provides a friendly voice for headlines set with tight leading, while a neutral sans-serif handles all body and UI copy.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- No dominant source-domain vocabulary was detected, but still avoid copying example subject matter from the design brief.
- Avoid brand logos, product shots, mascot imagery, packaging, buildings, people, or industry-specific objects unless requested by the slide content.

Overall visual personality: This is a theatrical, duotone design system anchored on a deep aubergine-plum canvas ({colors.canvas-dark} — 2c1338) for hero and footer bands, and a warm off-white ({colors.canvas-light} — fefbfa) for primary content areas. The system's entire expressive energy comes from a single, vivid magenta-pink accent ({colors.primary} — e57cd8). This accent is strictly rationed: it appears on primary filled CTAs, selected states, and as a signature italicized emphasis word inside every major headline. The visual language is flat. Depth is achieved entirely through the stark contrast between the dark and light content bands, not through shadows, gradients, or glassmorphism. Components feel chunky and friendly, with generously rounded corners: {rounded.md} (10px) for cards and inputs, a distinctive {rounded.lg} (26px) for primary buttons, and {rounded.pill} (200px) for tags and tertiary CTAs. Typography is a two-part system: a geometric display font with soft, rounded terminals gives headlines a confident, friendly voice, while a neutral body font handles all UI text for clarity. Display sizes are set with deliberately tight line heights (1.1–1.25) to create dense, solid headline blocks. Key...

Color tokens:
- primary: #e57cd8
- accent-secondary: #ffde91
- ink: #000000
- body: #564260
- heading-on-light: #412a4c
- muted: #6b5a74
- on-dark: #fefbfa
- on-primary: #fefbfa
- canvas-dark: #2c1338
- canvas-light: #fefbfa
- surface-elevated: #fcf1f8
- surface-warm: #fdeae2
- surface-highlight: #fae5f7
- surface-soft-accent: #f7d8f3

Typography tokens:
- hero-display: family DisplayFont, sans-serif, size 69px, weight 700, line 1.1, tracking 0
- display-lg: family DisplayFont, sans-serif, size 60px, weight 700, line 1.15, tracking 0
- display-md: family DisplayFont, sans-serif, size 43px, weight 700, line 1.2, tracking 0
- display-sm: family BodyFont, sans-serif, size 32px, weight 700, line 1.25, tracking 0
- title-lg: family BodyFont, sans-serif, size 22px, weight 700, line 1.35, tracking 0
- title-md: family BodyFont, sans-serif, size 18px, weight 700, line 1.4, tracking 0
- body-md: family BodyFont, sans-serif, size 16px, weight 400, line 1.5, tracking 0
- body-sm: family BodyFont, sans-serif, size 14px, weight 400, line 1.55, tracking 0
- caption: family BodyFont, sans-serif, size 12px, weight 400, line 1.5, tracking 0
- button: family BodyFont, sans-serif, size 16px, weight 500, line 1, tracking 0
- nav-link: family BodyFont, sans-serif, size 15px, weight 500, line 1.4, tracking 0
- emphasis-word: family DisplayFont-Italic, sans-serif, size inherit, weight 400, line inherit, tracking inherit

Spacing tokens:
- xxs: 5px
- xs: 8px
- sm: 12px
- md: 15px
- lg: 25px
- xl: 30px
- xxl: 40px
- section: 75px

Radius and shape tokens:
- md: 10px
- lg: 26px
- pill: 200px
- full: 9999px

Component tokens:
- button-primary: backgroundColor: {colors.primary}, textColor: {colors.on-primary}, typography: {typography.button}, rounded: {rounded.lg}, padding: 14px 28px
- button-secondary-on-dark: backgroundColor: transparent, textColor: {colors.on-dark}, typography: {typography.button}, rounded: {rounded.lg}, padding: 14px 28px, border: 1px solid {colors.on-dark}
- button-nav-pill: backgroundColor: {colors.surface-warm}, textColor: {colors.canvas-dark}, typography: {typography.body-sm}, rounded: {rounded.pill}, padding: 8px 18px
- nav-link-on-dark: backgroundColor: transparent, textColor: {colors.on-dark}, typography: {typography.nav-link}
- feature-card: backgroundColor: {colors.canvas-light}, textColor: {colors.body}, typography: {typography.body-md}, rounded: {rounded.md}, padding: {spacing.xl}, border: 1px solid {colors.hairline}
- feature-card-highlighted: backgroundColor: {colors.surface-elevated}, textColor: {colors.body}, typography: {typography.body-md}, rounded: {rounded.md}, padding: {spacing.xl}, border: 1px solid {colors.border-soft}
- pill-tag: backgroundColor: {colors.surface-soft-accent}, textColor: {colors.heading-on-light}, typography: {typography.caption}, rounded: {rounded.pill}, padding: 6px 14px
- pill-tag-active: backgroundColor: {colors.primary}, textColor: {colors.on-dark}, rounded: {rounded.pill}

Color rationale: Brand & Accent - Primary ({colors.primary} — e57cd8): The single, vivid magenta-pink accent. Used for primary filled button backgrounds, the signature emphasis word in headlines, selected nav states, and decorative dots. It is always used sparingly. - On Primary ({colors.on-primary} — fefbfa): Text color on primary-filled components, a warm off-white. - Accent Secondary ({colors.accent-secondary} — ffde91): A secondary amber yellow used for rating indicators and occasional secondary conversion moments. Surface The system uses a strict duotone approach for page backgrounds. - Canvas Dark ({colors.canvas-dark} — 2c1338): The deep aubergine stage for headers, heroes, and footers. The system's signature dark mode. - Canvas Light ({colors.canvas-light} — fefbfa): The warm, off-white background for all main content sections and cards. - Surface Elevated ({colors.surface-elevated} — fcf1f8): A pale pink tint for elevated cards or modals that need to sit above the light canvas without a shadow. - Surface Warm ({colors.surface-warm} — fdeae2): A soft, warm blush used for icon fills and secondary pill button backgrounds. - Surface Highlight ({colors.surface-highlight} — fae5f7): A slightly...

Typography rationale: Font Family The system uses a dual-font strategy. - DisplayFont: A geometric sans-serif with rounded terminals used for all large display headlines. It has a distinct italic variant (DisplayFont-Italic) used for the signature emphasis word. - BodyFont: A neutral, workhorse sans-serif used for all body copy, UI labels, navigation, and smaller headings. Hierarchy | Token | Size | Weight | Line Height | Use | |---|---|---|---|---| | {typography.hero-display} | 69px | 700 | 1.1 | Top-level hero headlines | | {typography.display-lg} | 60px | 700 | 1.15 | Secondary hero headlines | | {typography.display-md} | 43px | 700 | 1.2 | Major section titles | | {typography.display-sm} | 32px | 700 | 1.25 | Sub-section titles | | {typography.title-lg} | 22px | 700 | 1.35 | Card titles, small headings | | {typography.title-md} | 18px | 700 | 1.4 | Sub-headings, introductory copy | | {typography.body-md} | 16px | 400 | 1.5 | Default running body text | | {typography.body-sm} | 14px | 400 | 1.55 | Smaller body copy, UI text | | {typography.caption} | 12px | 400 | 1.5 | Table headers, metadata | | {typography.button} | 16px | 500 | 1 | Primary button labels | | {typography.nav-link} | 15px | 500 | 1....

Layout system: Spacing System - Base unit: An irregular scale, with key tokens for common uses. - Tokens: {spacing.xs} 8px · {spacing.md} 15px · {spacing.lg} 25px · {spacing.xl} 30px · {spacing.section} 75px. - Section padding (vertical): {spacing.section} (75px) is used between the large dark and light content bands, creating generous breathing room. - Card internal padding: {spacing.xl} (30px) is the standard for most content cards. - Gutters: {spacing.md} (15px) or {spacing.lg} (25px) between cards in a grid. Grid & Container - Max content width: 1200px, centered. - Structure: Pages are composed of full-bleed horizontal bands. Inside these bands, content sits within the 1200px container. - Editorial body: Content often uses a centered, single-column layout for headlines, followed by 2-column or 3-column grids for feature breakdowns. Whitespace Philosophy The system uses generous whitespace between major sections ({spacing.section}) to emphasize the transition from dark to light canvas zones. Within content blocks, spacing is comfortable but not overly airy, allowing the chunky components and dense typography to define the rhythm.

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | Flat | No shadow, no border | Body sections, hero bands, footer | | Soft hairline | 1px {colors.hairline} or {colors.border-soft} | Cards, inputs, table dividers, secondary buttons | | Elevated surface | {colors.surface-elevated} background on light canvas — no shadow | Highlighted cards or modals that need to stand out from a grid of standard cards | | Diffused shadow | 0 8px 24px rgba(44,19,56,0.12) | Used only for dropdown menus and mega-nav panels to lift them off the page | The elevation philosophy is flat surfaces separated by color and hairlines. The system actively avoids drop shadows. Depth is communicated by the background color of a surface ({colors.canvas-light} vs. {colors.surface-elevated}) or by the page-level contrast of {colors.canvas-dark} against {colors.canvas-light}.

Shape language: Border Radius Scale | Token | Value | Use | |---|---|---| | {rounded.md} | 10px | Content cards, input fields, modals | | {rounded.lg} | 26px | Primary and secondary buttons | | {rounded.pill} | 200px | Filter tags, tabs, and the persistent navigation CTA button | | {rounded.full} | 9999px | Circular elements (aliases {rounded.pill}) | The shape language is defined by a bold, three-step radius scale. The {rounded.lg} value of 26px is a distinctive signature, creating buttons that are heavily rounded but not a perfect pill. This "chunky" feel is central to the brand's friendly, approachable voice.

Component language: Buttons - button-primary: The main call-to-action. A filled button with a {colors.primary} background and {colors.on-primary} text. It uses the signature {rounded.lg} (26px) radius. - button-secondary-on-dark: A "ghost" button for secondary actions on dark backgrounds. Transparent with a 1px {colors.on-dark} border. - button-nav-pill: A persistent CTA in the top navigation. It uses {colors.surface-warm} for its background and {rounded.pill} to distinguish it from in-page contextual CTAs. Cards & Containers - hero-band-dark: A full-bleed band with a {colors.canvas-dark} background, used for the page header and hero section. It contains a large headline set in {typography.hero-display}. - feature-card: The default card for content grids. It has a {colors.canvas-light} background, a {rounded.md} (10px) radius, and a 1px {colors.hairline} border. - feature-card-highlighted: A variant for featured content. It swaps the background to {colors.surface-elevated} to stand out without using a shadow. - mega-menu: The large dropdown panel for navigation. It's the only component to use a subtle, diffused drop shadow for elevation. Tags & UI Elements - pill-tag: Used for filters, tabs, and cate...

Guardrails: Do - Render every major headline with exactly one {colors.primary} emphasis word set in the italic display font. This is the system's co...
```
