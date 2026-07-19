# Umbra

**ID:** `umbra`  
**Category:** consumer  
**Theme:** dark  
**Vibe:** Minimal

## Color palette

- `#444345`
- `#555456`
- `#222122`
- `#000000`
- `#ffffff`
- `#b8bab9`
- `#e2e2e2`
- `#fafafa`
- `#f5f5f5`

## Typography

Families: "GT America Mono, JetBrains Mono, ui-monospace, monospace", "Roobert, Inter, -apple-system, BlinkMacSystemFont, sans-serif". Weights: 400.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: MekaVerse

Design token description: A cinematic, monochrome gallery interface built on a pure black void (000000), designed to frame full-bleed visual media without competing with it. All UI is rendered in white ink (ffffff) on matte black glass. Typography is the primary tool, featuring a custom geometric sans at extreme sizes with aggressive negative line-heights for hero titles, and a quiet monospaced face for all system chrome. Surfaces are flat — no shadows, no gradients, no chromatic accent. The only elevated the source brand is a soft charcoal (444345) for primary action buttons. Every element is featherweight, defined by hairline borders (e2e2e2) and sharp 2px corner radii.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- Detected source-domain vocabulary: consumer technology. Translate it into reusable visual behavior, not literal imagery.
- Avoid literal source imagery unless the exact slide text or visual direction explicitly requests it: phones, laptops, tablets, device mockups, or hardware product renders; app screenshots, operating-system chrome, or product launch hero shots.

Overall visual personality: This is a cinematic, monochrome system designed to function as a gallery frame for digital artifacts. The entire UI is built on a pure black void ({colors.canvas-dark} — 000000), where all interface elements are rendered in white ink ({colors.body} — ffffff). The design intentionally dissolves into the background, allowing full-bleed, full-color media to be the sole focus. Typography is the primary design tool. A geometric sans-serif (Roobert) is used for all display text, often at extreme sizes ({typography.hero-display} at 80px) with an aggressively tight line-height (0.78) to create monumental, stacked titles. All UI chrome, navigation, and micro-labels use a quiet monospaced face (GT America Mono) at small sizes, reinforcing the feeling of system instrumentation rather than editorial design. Surfaces are relentlessly flat. There are no shadows, gradients, or chromatic accents. The single step of elevation is a dark charcoal ({colors.primary} — 444345) used for primary action buttons, which reads as a matte the source brand rather than a raised element. Every interactive control is defined by featherweight hairlines ({colors.hairline-on-dark} — e2e2e2) and a sharp, consistent {...

Color tokens:
- primary: #444345
- primary-active: #555456
- primary-disabled: #222122
- ink: #000000
- body: #ffffff
- body-on-light: #000000
- muted: #b8bab9
- muted-strong: #e2e2e2
- hairline-on-light: #e2e2e2
- hairline-on-dark: #e2e2e2
- border-strong: #ffffff
- canvas-light: #ffffff
- canvas-dark: #000000
- surface-card-dark: #444345

Typography tokens:
- hero-display: family Roobert, Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 80px, weight 400, line 0.78, tracking 0
- display-sm: family Roobert, Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 30px, weight 400, line 1, tracking 0
- title-lg: family Roobert, Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 26px, weight 400, line 1.15, tracking 0
- body-md: family Roobert, Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 16px, weight 400, line 1.5, tracking 0
- nav-link: family GT America Mono, JetBrains Mono, ui-monospace, monospace, size 12px, weight 400, line 1, tracking -0.2px
- button: family GT America Mono, JetBrains Mono, ui-monospace, monospace, size 12px, weight 400, line 1, tracking -0.2px
- caption: family GT America Mono, JetBrains Mono, ui-monospace, monospace, size 10px, weight 400, line 1, tracking -0.2px

Spacing tokens:
- xxs: 4px
- xs: 8px
- sm: 12px
- md: 16px
- lg: 20px
- xl: 40px
- xxl: 60px
- section: 116px

Radius and shape tokens:
- xs: 2px
- sm: 4px
- md: 10px
- lg: 20px
- xl: 20px
- pill: 9999px
- full: 9999px

Component tokens:
- button-primary: backgroundColor: {colors.primary}, textColor: {colors.on-primary}, typography: {typography.button}, rounded: {rounded.xs}, padding: 10px 20px, border: 1px solid {colors.hairline-on-dark}
- button-primary-active: backgroundColor: {colors.primary-active}
- button-primary-disabled: backgroundColor: {colors.primary-disabled}, textColor: {colors.muted}
- text-link-nav: backgroundColor: transparent, textColor: {colors.on-dark}, typography: {typography.nav-link}
- top-nav-dark: backgroundColor: transparent, textColor: {colors.on-dark}, typography: {typography.nav-link}, height: 40px, borderBottom: 1px solid rgba(226, 226, 226, 0.1)
- hero-band-dark: backgroundColor: transparent, textColor: {colors.on-dark}, typography: {typography.hero-display}, padding: 60px
- media-full-bleed: backgroundColor: {colors.canvas-dark}, rounded: 0
- section-container: backgroundColor: transparent, padding: 20px

Color rationale: Brand & Accent The system is intentionally monochrome. There is no brand accent color. - Primary ({colors.primary} — 444345): A dark charcoal used for the background of all filled action buttons. It is the only color besides black and white used for surfaces. - On Primary ({colors.on-primary} — ffffff): White text on charcoal primary buttons. the source brand - Canvas Dark ({colors.canvas-dark} — 000000): The universal page floor. Pure black provides maximum contrast for overlaid media and white text. - the source brand Elevated Dark ({colors.surface-elevated-dark} — 444345): The one and only elevated the source brand level, used for primary buttons. Same value as {colors.primary}. - the source brand Muted ({colors.muted} — b8bab9): A light gray used for inactive or disabled UI states, providing a visible material without competing for attention. Hairlines & Borders - Hairline on Dark ({colors.hairline-on-dark} — e2e2e2): A very light gray used for all 1px borders, dividers, and the signature underline mark on display titles. - Border Strong ({colors.border-strong} — ffffff): Pure white, used for high-contrast outlines on input controls or card edges when needed. Text - Body ({col...

Typography rationale: Font Family The system uses a strict dual-font hierarchy to separate editorial voice from UI instrumentation. - Roobert (or Inter substitute): A geometric sans-serif used for all display, hero, and heading type. Its voice is defined by using a light regular weight (400) even at massive sizes. - GT America Mono (or JetBrains Mono substitute): A monospaced face used for all UI chrome, navigation links, micro-labels, and buttons. Its mechanical nature keeps the UI feeling subordinate to the main content. Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.hero-display} | 80px | 400 | 0.78 | 0 | Main hero titles, stacked with signature underline marks. | | {typography.display-sm} | 30px | 400 | 1 | 0 | Secondary headlines and section sub-titles. | | {typography.title-lg} | 26px | 400 | 1.15 | 0 | Smaller section headings. | | {typography.nav-link} | 12px | 400 | 1 | -0.2px | Top navigation links and other interactive text. | | {typography.button} | 12px | 400 | 1 | -0.2px | All button labels. | | {typography.caption} | 10px | 400 | 1 | -0.2px | Micro-labels, counters, and metadata. | Principles - Whispered Authority: Display...

Layout system: Spacing System - Base unit: 4px. - Tokens: {spacing.xxs} 4px · {spacing.md} 16px · {spacing.lg} 20px · {spacing.xl} 40px · {spacing.section} 116px. - Element Gaps: A standard {spacing.lg} (20px) is used between most elements, such as the margin between a hero title and the CTA below it. - Padding: Card-like containers use {spacing.lg} (20px) for internal padding. Navigational elements use generous horizontal padding ({spacing.xl} or more) to create breathing room. Grid & Container The system avoids traditional grids and containers. - Full-Bleed Canvas: The primary layout primitive is the viewport itself. Media assets are designed to fill the clean interface-like information plane edge-to-edge. - Absolute Positioning: UI elements like hero titles and CTAs are overlaid on top of the media, typically aligned to the left or bottom-left with generous padding from the viewport edges (e.g., 40-80px). - No Max-Width: There are no centered, max-width content columns. The layout is expansive and cinematic, reading like a continuous film strip as the user scrolls through full-screen sections.

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | 0 (Canvas) | {colors.canvas-dark} background | The universal page floor, behind all media and UI. | | 1 (the source brand) | {colors.surface-elevated-dark} background | The only elevated the source brand, used for primary action buttons. | | Hairline | 1px {colors.hairline-on-dark} border | Outlines on interactive controls, dividers, and decorative rules. | The elevation philosophy is strictly flat. No box-shadows are used anywhere in the system. Depth is communicated exclusively through the contrast between the black canvas and the single charcoal the source brand step, and through the use of 1px hairlines to define edges. Every element feels pressed onto the canvas, not floating above it.

Shape language: Border Radius Scale | Token | Value | Use | |---|---|---| | {rounded.xs} | 2px | The default for all interactive controls: buttons, navigation items. | | {rounded.md} | 10px | Used for medium-sized content cards or panels. | | {rounded.lg} | 20px | Used for large-scale containers or wrappers. | The {rounded.xs} (2px) radius is a system-defining rule for interactive elements. It keeps corners sharp and architectural, complementing the clean lines of the typography and avoiding a soft, rounded aesthetic. Signature Shapes - Underline Mark: A 1px tall {colors.hairline-on-dark} line is a signature decorative element. It is placed directly beneath each line of a stacked {typography.hero-display} title, extending from the left edge to approximately 30-50% of the line's width. It is not a functional underline.

Component language: Top Navigation top-nav-dark — A sticky, transparent header that sits over full-bleed media. It has a transparent background with a 1px {colors.hairline-on-dark} bottom border at ~10% opacity. Navigation links use {component.text-link-nav} styling, and the primary action is a {component.button-primary}. Buttons button-primary — The only major button style. It uses a {colors.primary} (charcoal) background fill with {colors.on-primary} (white) text. Styled with {typography.button} (12px monospace) and a sharp {rounded.xs} (2px) radius. A 1px {colors.hairline-on-dark} border provides a subtle edge. It is deliberately understated, reading like a system control rather than a marketing CTA. Text & Links text-link-nav — Used for navigation items. Inherits {typography.nav-link} with {colors.on-dark} text. Hover states may introduce a 1px bottom border. Containers hero-band-dark — A conceptual component representing the stacked title block overlaid on media. It is not a container with a background, but rather a text element using {typography.hero-display} with transparent background, {colors.on-dark} text, and generous padding from the viewport edge. media-full-bleed — The main content prim...

Guardrails: Do - Use {colors.canvas-dark} as the canvas for all pages and let media carry all color and light. - Set hero titles in {typography.hero-display} (80px, weight 400, line-height 0.78). The tight stacking is the signature. - Reserve {colors.body} (ffffff) for type and high-contrast borders; never use it as a fill the source brand. - Use the monospaced font for all chrome, navigation, and micro-labels to maintain the UI/content separation. - Render all primary buttons as {rounded.xs} charc...
```
