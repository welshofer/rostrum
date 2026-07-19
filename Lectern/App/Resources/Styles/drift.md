# Drift

**ID:** `drift`  
**Category:** consumer  
**Theme:** light  
**Vibe:** Editorial

## Color palette

- `#000000`
- `#3d3d3d`
- `#9e9e9e`
- `#b5b5b5`
- `#8d8d8d`
- `#ffffff`
- `#f0eeed`
- `#142161`
- `#ba2223`

## Typography

Families: "NTNeuss, -apple-system, BlinkMacSystemFont, sans-serif", "RecklessNeue-Book, Georgia, serif". Weights: 400, 500.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Sneak In Peace

Design token description: A restrained, monochrome editorial system built around a floating, translucent vitrine. A full-bleed media backdrop runs edge-to-edge while all interactive UI is contained in a frosted glass panel on the right. The palette is almost entirely grayscale, using a workhorse charcoal (3d3d3d) for text and borders on a pure white (ffffff) canvas. Color is strictly rationed a single vivid red (ba2223) for live-status indicators and a deep navy (142161) for link borders. Typography is split between a widely-tracked grotesque (NTNeuss) for all UI labels and a sharp serif (RecklessNeue) for singular editorial headlines. The entire system is compact, flat, and uses a consistent 6px corner radius, creating a quiet, gallery-like experience where the UI whispers and the visual media speaks.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- No dominant source-domain vocabulary was detected, but still avoid copying example subject matter from the design brief.
- Avoid brand logos, product shots, mascot imagery, packaging, buildings, people, or industry-specific objects unless requested by the slide content.

Overall visual personality: The system is a restrained, monochrome editorial interface built around a floating, translucent vitrine. A full-bleed media backdrop runs edge-to-edge while all interactive UI is contained in a frosted glass panel pinned to the right. The palette is almost entirely grayscale, using a workhorse charcoal ({colors.body} — 3d3d3d) for text and borders on a pure white ({colors.canvas} — ffffff) canvas. Color is strictly rationed: a single vivid red ({colors.accent-live} — ba2223) for live-status indicators and a deep navy ({colors.accent-stroke} — 142161) for link borders. Typography is split between a widely-tracked grotesque (NTNeuss) for all UI labels and a sharp serif (RecklessNeue) for singular editorial headlines. The entire system is compact, flat, and uses a consistent {rounded.md} (6px) corner radius, creating a quiet, gallery-like experience where the UI whispers and the visual media speaks.

Color tokens:
- ink: #000000
- body: #3d3d3d
- muted: #9e9e9e
- disabled: #b5b5b5
- surface-active: #8d8d8d
- canvas: #ffffff
- surface-soft: #f0eeed
- accent-stroke: #142161
- accent-live: #ba2223
- on-accent: #ffffff

Typography tokens:
- editorial-title: family RecklessNeue-Book, Georgia, serif, size 21px, weight 400, line 1.5, tracking 0
- heading-sm: family NTNeuss, -apple-system, BlinkMacSystemFont, sans-serif, size 14px, weight 500, line 1.5, tracking 0
- body-lg: family NTNeuss, -apple-system, BlinkMacSystemFont, sans-serif, size 13px, weight 400, line 1.5, tracking 0.5px
- body-md: family NTNeuss, -apple-system, BlinkMacSystemFont, sans-serif, size 12px, weight 400, line 1.5, tracking 0.45px
- body-sm: family NTNeuss, -apple-system, BlinkMacSystemFont, sans-serif, size 11px, weight 400, line 1.5, tracking 0.4px
- caption: family NTNeuss, -apple-system, BlinkMacSystemFont, sans-serif, size 10px, weight 400, line 1.5, tracking 0.36px
- label-md: family NTNeuss, -apple-system, BlinkMacSystemFont, sans-serif, size 12px, weight 500, line 1.2, tracking 0.5px
- label-sm: family NTNeuss, -apple-system, BlinkMacSystemFont, sans-serif, size 9px, weight 500, line 1.2, tracking 0.5px
- label-xs: family NTNeuss, -apple-system, BlinkMacSystemFont, sans-serif, size 8px, weight 400, line 1.2, tracking 0.98px

Spacing tokens:
- xxs: 4px
- xs: 6px
- sm: 8px
- md: 12px
- lg: 16px
- xl: 24px
- xxl: 30px
- section: 40px

Radius and shape tokens:
- md: 6px
- full: 26px

Component tokens:
- glass-panel: backgroundColor: rgba(255, 255, 255, 0.7), textColor: {colors.body}, typography: {typography.body-md}, rounded: {rounded.md}, padding: 16px
- segmented-tab-active: backgroundColor: {colors.surface-active}, textColor: {colors.on-accent}, typography: {typography.label-md}, rounded: {rounded.md}, padding: 2px 8px
- segmented-tab-inactive: backgroundColor: transparent, textColor: {colors.body}, typography: {typography.label-md}, rounded: {rounded.md}, padding: 2px 8px
- live-badge: backgroundColor: {colors.accent-live}, textColor: {colors.on-accent}, typography: {typography.label-sm}, rounded: {rounded.md}, padding: 5px 7px
- now-playing-card: backgroundColor: {colors.canvas}, textColor: {colors.body}, typography: {typography.body-md}, rounded: {rounded.md}, padding: {spacing.lg}
- attribution-bar: backgroundColor: transparent, textColor: {colors.body}, typography: {typography.body-md}, padding: {spacing.sm} 0
- product-card: backgroundColor: {colors.canvas}, textColor: {colors.body}, typography: {typography.body-md}, rounded: {rounded.md}, padding: {spacing.lg}
- outlined-link: backgroundColor: transparent, textColor: {colors.body}, typography: {typography.body-md}

Color rationale: Grayscale Palette - Ink ({colors.ink} — 000000): The strongest text color, reserved for high-contrast headlines and icon strokes. Used sparingly. - Body ({colors.body} — 3d3d3d): The workhorse gray for default body text, dividers, and standard borders. Carries the bulk of the UI. - Muted ({colors.muted} — 9e9e9e): A lighter gray for secondary body text or less important metadata. - Disabled ({colors.disabled} — b5b5b5): The lightest functional gray, used for fills on disabled or resting-state elements. - Surface Active ({colors.surface-active} — 8d8d8d): A filled background color used exclusively to indicate the active state in segmented controls or tabs. Surfaces - Canvas ({colors.canvas} — ffffff): The base canvas, used for opaque card surfaces and as the base for the translucent glass-panel. - Surface Soft ({colors.surface-soft} — f0eeed): A warm off-white used for badge fills and subtle surface highlights, providing a paper-like feel. Accent Palette - Accent Live ({colors.accent-live} — ba2223): A vivid red used exclusively for live-status punctuation, like a "LIVE" badge. It signals urgency and active state. - Accent Stroke ({colors.accent-stroke} — 142161): A deep navy used...

Typography rationale: Font Family The system uses a strict two-font hierarchy to separate UI from editorial content. - NTNeuss: A utilitarian grotesque for all UI elements: body copy, labels, buttons, metadata. It is characterized by its wide letter-spacing at small sizes, giving it a technical, label-like quality. - RecklessNeue-Book: An editorial serif used exclusively for narrative titles. Its classic proportions signal a shift from functional UI to expressive content. Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.editorial-title} | 21px | 400 | 1.5 | 0 | The single serif headline for featured content | | {typography.heading-sm} | 14px | 500 | 1.5 | 0 | Small headlines or emphasized labels inside cards | | {typography.body-lg} | 13px | 400 | 1.5 | 0.5px | Larger body copy or descriptions | | {typography.body-md} | 12px | 400 | 1.5 | 0.45px | Default body copy, product descriptions | | {typography.body-sm} | 11px | 400 | 1.5 | 0.4px | Metadata, secondary text | | {typography.caption} | 10px | 400 | 1.5 | 0.36px | Smallest body text, eyebrow labels | | {typography.label-md} | 12px | 500 | 1.2 | 0.5px | Tab bar labels, button text | | {...

Layout system: Spacing System - Base unit: 2px. - Tokens: {spacing.xxs} 4px · {spacing.xs} 6px · {spacing.sm} 8px · {spacing.md} 12px · {spacing.lg} 16px · {spacing.xl} 24px · {spacing.xxl} 30px · {spacing.section} 40px. - Card internal padding: {spacing.lg} (16px) is the standard for all content cards. - Element Gaps: {spacing.xs} (6px) is the common gap between stacked elements inside a list or container. Grid & Container The layout is unconventional, eschewing a traditional grid. - Media Backdrop: A full-bleed video or image fills 100% of the viewport. - Glass Panel: A single, translucent container is pinned to the right edge of the viewport, occupying roughly 30-35% of the screen width. It has a max-width of ~420px. All interactive content lives inside this panel. - Scrolling: The page itself does not scroll. Instead, content lists (like product lists) scroll internally within the glass panel. Whitespace Philosophy The system is compact and dense. Whitespace is used precisely inside cards ({spacing.lg}) and between elements ({spacing.xs}), but the overall impression is one of information density contained within a small footprint, allowing the background media to dominate the experience.

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | 0 | Media Backdrop | Full-bleed media, sits at the bottom of the stack | | 1 | Glass Panel | Translucent white ({colors.canvas} at ~70% opacity) with backdrop blur and a subtle 1px drop shadow | | 2 | Opaque Cards | {colors.canvas} with the same subtle 1px drop shadow, nested inside the Glass Panel | | 3 | Active Surface | {colors.surface-active} or {colors.surface-soft} backgrounds for selected tabs or badges | The elevation model is extremely shallow. Depth is created almost entirely by a single, subtle drop shadow (rgba(0, 0, 0, 0.08) 1px 1px 6px -1px) applied to the main glass-panel and any opaque cards nested within it. The use of translucency and backdrop blur on the main panel is the primary method of separating UI from the background media.

Shape language: Border Radius Scale | Token | Value | Use | |---|---|---| | {rounded.md} | 6px | The universal radius for all cards, buttons, inputs, and badges. | | {rounded.full} | 26px | Reserved exclusively for circular avatars. | The shape language is rigid and consistent. Nearly every interactive element uses a {rounded.md} (6px) corner. This uniformity creates a cohesive, blocky aesthetic. The only exception is the larger {rounded.full} used for avatars, which clearly distinguishes them from other UI components.

Component language: Containers glass-panel — The primary container for all UI, pinned to the right edge. It's a semi-transparent white surface (rgba(255, 255, 255, 0.7)) with a backdrop blur effect to frost the media behind it. It features {rounded.md} corners and a subtle drop shadow to lift it from the background. now-playing-card — An opaque white ({colors.canvas}) tile that sits inside the glass-panel. It's used to feature primary content, with an eyebrow label ({typography.caption}), a main headline in the system's only serif ({typography.editorial-title}), and a body description. It shares the same {rounded.md} and {spacing.lg} padding as other cards. product-card — A horizontally-oriented card for list items. It has a 1px border in {colors.body}, a {rounded.md} shape, and contains a small square media thumbnail on the left and text content on the right. Navigation & Actions segmented-tab-active / segmented-tab-inactive — A pill-style tab bar. The active tab has a {colors.surface-active} background with {colors.on-accent} text. Inactive tabs are transparent with {colors.body} text. All tabs use {typography.label-md}. schedule-toggle-active / schedule-toggle-inactive — A smaller, two-segment tog...

Guardrails: Do - Use {rounded.md} for every card, button, and input. Reserve {rounded.full} exclusively for avatars. - Apply NTNeuss for all UI text and switch to RecklessNeue-Book only for narrative headlines. - Set generous letter-spacing on all small NTNeuss text (≤12px) to maintain the "label" aesthetic. - Use {colors.body} for default text and borders; reserve {colors.ink} for high-contrast headlines and icon strokes. - Treat {colors.accent-live} as a rationed accent for live-status indicators only. - Layer all UI within the floating translucent glass-panel over a full-bleed media backdrop....
```
