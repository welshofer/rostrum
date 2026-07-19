# Clover

**ID:** `clover`  
**Category:** consumer  
**Theme:** light  
**Vibe:** Bold

## Color palette

- `#25d366`
- `#0373e9`
- `#ffffff`
- `#111b21`
- `#1c1e21`
- `#5e5e5e`
- `#fcf5eb`
- `#d9fdd3`
- `#f0f4f9`
- `#000000`

## Typography

Families: "WhatsApp Sans Var, Inter, -apple-system, BlinkMacSystemFont, sans-serif". Weights: 400, 700.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: WhatsApp

Design token description: A warm, human interface built on a soft cream canvas (fcf5eb), where a single vivid green (25d366) carries every primary action. The type system is deliberately dramatic, with a custom display face scaling to large, confident headlines, balanced by quiet body copy. Components are generous and soft: pill-shaped buttons, generously rounded image cards, and minimal use of borders or shadows. The color palette is ruthlessly restrained, making every green CTA feel like a deliberate act of invitation. The overall feel is less 'SaaS product' and more 'sunlit conversation' — warm tones, organic shapes, and nothing chrome-like or angular.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- No dominant source-domain vocabulary was detected, but still avoid copying example subject matter from the design brief.
- Avoid brand logos, product shots, mascot imagery, packaging, buildings, people, or industry-specific objects unless requested by the slide content.

Overall visual personality: This is a warm, human-centric design system built on a soft cream canvas ({colors.canvas-light} — fcf5eb). The entire interface feels approachable and organic, letting large-scale typography and photography do the talking. A single, vivid brand green ({colors.primary} — 25d366) punctuates every primary action, used with extreme restraint to give each call-to-action deliberate weight. There is no complex color hierarchy; the system relies on the green for action, a near-black for text, and the cream/white surface distinction for structure. The type system is deliberately dramatic. A custom sans-serif typeface scales to exceptionally large display sizes ({typography.hero-display} at 80px), creating a magazine-like confidence. This is balanced by quiet, readable body copy at modest sizes and a regular weight. Weights are binary: 700 for headlines, 400 for everything else. This simplicity keeps the focus on the message and the large-format visuals. Components are generous and soft. Buttons and inputs use a full pill radius ({rounded.pill} — 50px), and media cards use a generously soft {rounded.lg} (25px). The system actively avoids sharp corners, heavy borders, and drop shadows, prefe...

Color tokens:
- primary: #25d366
- accent-link: #0373e9
- on-primary: #ffffff
- ink: #111b21
- ink-secondary: #1c1e21
- body-on-light: #111b21
- muted: #5e5e5e
- canvas-light: #fcf5eb
- surface-card: #ffffff
- surface-outgoing-message: #d9fdd3
- hairline: #f0f4f9

Typography tokens:
- hero-display: family WhatsApp Sans Var, Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 80px, weight 700, line 1, tracking 0
- display-lg: family WhatsApp Sans Var, Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 60px, weight 700, line 1.1, tracking 0
- display-md: family WhatsApp Sans Var, Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 48px, weight 700, line 1.2, tracking 0
- body-lg: family WhatsApp Sans Var, Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 18px, weight 400, line 1.39, tracking 0
- body-md: family WhatsApp Sans Var, Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 16px, weight 400, line 1.34, tracking 0
- caption: family WhatsApp Sans Var, Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 12px, weight 400, line 1.38, tracking 0
- button: family WhatsApp Sans Var, Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 16px, weight 700, line 1, tracking 0
- nav-link: family WhatsApp Sans Var, Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 16px, weight 400, line 1.34, tracking 0

Spacing tokens:
- xxs: 4px
- xs: 8px
- sm: 12px
- md: 16px
- lg: 24px
- xl: 32px
- xxl: 56px
- section: 120px

Radius and shape tokens:
- sm: 8px
- md: 16px
- lg: 25px
- pill: 50px
- full: 50px

Component tokens:
- button-primary-pill: backgroundColor: {colors.primary}, textColor: {colors.on-primary}, typography: {typography.button}, rounded: {rounded.pill}, padding: 16px 28px
- button-secondary-outline: backgroundColor: transparent, textColor: {colors.ink-secondary}, typography: {typography.nav-link}, rounded: {rounded.pill}, padding: 14px 28px
- text-link: backgroundColor: transparent, textColor: {colors.accent-link}, typography: {typography.body-lg}
- top-nav: backgroundColor: {colors.surface-card}, textColor: {colors.ink}, typography: {typography.nav-link}, height: 80px
- hero-band: backgroundColor: {colors.canvas-light}, textColor: {colors.ink}, typography: {typography.hero-display}, padding: 88px 0
- media-card: backgroundColor: transparent, rounded: {rounded.lg}
- chat-bubble-incoming: backgroundColor: {colors.surface-card}, textColor: {colors.ink-secondary}, typography: {typography.caption}, rounded: {rounded.sm}, padding: 8px 12px
- chat-bubble-outgoing: backgroundColor: {colors.surface-outgoing-message}, textColor: {colors.ink-secondary}, typography: {typography.caption}, rounded: {rounded.sm}, padding: 8px 12px

Color rationale: Brand & Accent - Primary Green ({colors.primary} — 25d366): The single brand color. Reserved exclusively for the background of primary, solid CTA buttons. Its role is purely for action. - Accent Link Blue ({colors.accent-link} — 0373e9): A secondary accent used only for the text color of inline links. It never appears as a background or in a primary button. Surface - Canvas Light ({colors.canvas-light} — fcf5eb): The base page background for all sections. A warm, cream off-white that defines the system's approachable atmosphere. - Surface Card ({colors.surface-card} — ffffff): The elevated surface layer for cards, the top navigation bar, and decorative UI elements that need to float above the cream canvas. - Surface Outgoing Message ({colors.surface-outgoing-message} — d9fdd3): A specific light-green surface used only for decorative outgoing message bubbles, providing a subtle chromatic hint. Text - Ink ({colors.ink} — 111b21): The primary, deepest text color for headlines and body copy. It is a near-black, not pure 000. - Ink Secondary ({colors.ink-secondary} — 1c1e21): A slightly lighter near-black used for secondary text and thin borders on outline buttons. - Body on Light ({co...

Typography rationale: Font Family The system uses a single custom sans-serif font, WhatsApp Sans Var, for all typographic roles. The fallback stack is Inter, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif. The system's typographic expression comes from dramatic size contrast and a binary weight system, not from mixing typefaces. - Weight: Only two weights are used. 700 (bold) for all headlines and button labels. 400 (regular) for all body copy, navigation links, and captions. Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.hero-display} | 80px | 700 | 1.0 | 0 | Primary hero headlines | | {typography.display-lg} | 60px | 700 | 1.1 | 0 | Section headlines | | {typography.display-md} | 48px | 700 | 1.2 | 0 | Sub-section headlines | | {typography.body-lg} | 18px | 400 | 1.39 | 0 | Large body copy, sub-headlines | | {typography.body-md} | 16px | 400 | 1.34 | 0 | Default running text | | {typography.caption} | 12px | 400 | 1.38 | 0 | Small meta-text, UI labels | | {typography.button} | 16px | 700 | 1.0 | 0 | All primary and secondary button labels | | {typography.nav-link} | 16px | 400 | 1.34 | 0 | Top navigation menu items |...

Layout system: Spacing System - Base unit: 4px. - Tokens: {spacing.xxs} 4px · {spacing.xs} 8px · {spacing.sm} 12px · {spacing.md} 16px · {spacing.lg} 24px · {spacing.xl} 32px · {spacing.xxl} 56px · {spacing.section} 120px. - Section padding (vertical): A very generous {spacing.section} (120px) is used between major content blocks, creating a calm, unhurried rhythm. - Card internal padding: {spacing.xl} (32px) for content cards. - Gutters: {spacing.md} (16px) to {spacing.lg} (24px) between elements within a section. Grid & Container - Max content width: ~1200px, centered. - Layout structure: Primarily single-column, with alternating full-bleed media sections and centered text blocks. Two-column layouts (image + text) are used for feature breakdowns. The layout is simple and open, avoiding complex grid systems. Whitespace Philosophy Whitespace is a core component of the design. The system uses generous vertical gaps ({spacing.section}) between content areas to let each message breathe and to ensure the warm {colors.canvas-light} is a visible, felt presence. The density is comfortable and relaxed, prioritizing clarity and focus over information density.

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | 1 (Canvas) | {colors.canvas-light} background | The base page floor, which reads as the most recessed layer. | | 2 (Surface) | {colors.surface-card} background, no shadow | Elevated cards, top navigation, and UI elements floating on the cream canvas. | | 3 (Media) | Full-bleed media content with no border or shadow | Sits at the highest visual layer, often overlapping the canvas and surface layers. | The system intentionally and completely avoids drop shadows. Depth is communicated exclusively through surface color contrast. The warm, cream {colors.canvas-light} establishes the ground plane, and the pure white {colors.surface-card} reads as a distinct layer floating above it. This flat, layered approach contributes to the clean, organic, and uncluttered feel.

Shape language: Border Radius Scale | Token | Value | Use | |---|---|---| | {rounded.sm} | 8px | Small UI elements, decorative chat bubbles | | {rounded.md} | 16px | Content cards that require a less-soft corner | | {rounded.lg} | 25px | All primary media cards and image containers | | {rounded.pill} | 50px | All buttons, inputs, and small badges | | {rounded.full} | 50px | Avatars, interactive pill-shaped elements | The shape language is defined by softness. A {rounded.pill} (50px) radius is the default for all interactive controls, giving them a friendly, capsule-like form. Media is framed with a very generous {rounded.lg} (25px), avoiding any sharp corners. This consistent use of high-radius curves is fundamental to the system's approachable and human character.

Component language: Buttons & Links button-primary-pill — The single, definitive primary action. A pill-shaped button with a {colors.primary} green background and {colors.on-primary} white text. Uses {typography.button} (16px/700) and generous padding to feel substantial and inviting. button-secondary-outline — A ghost-style pill button used for secondary actions, like in the navigation bar. It has a transparent background with a thin 1px border in {colors.ink-secondary}, with text matching the border color. text-link — A standard inline link for "learn more" affordances. It uses {colors.accent-link} blue text, is underlined, and appears within running body copy. It is never styled as a standalone button. Navigation & Hero top-nav — The main site header. It sits on a {colors.surface-card} white background to elevate it from the cream canvas. Contains navigation links in {typography.nav-link} and a combination of secondary and primary buttons on the right. hero-band — A full-bleed section, often with a large media background, containing the main headline. The headline uses the largest type style, {typography.hero-display}, in {colors.ink}. Cards & Decorative Elements media-card — A container for photo...

Guardrails: Do - Use {colors.primary} green exclusively for the primary call-to-action in a given view. Its power comes from its scarcity. - Set display headlines at their intended large sizes (48-80px). Undersized headli...
```
