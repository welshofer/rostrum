# Amber

**ID:** `amber`  
**Category:** consumer  
**Theme:** light  
**Vibe:** Technical

## Color palette

- `#ff5900`
- `#ffffff`
- `#000710`
- `#15191e`
- `#f3f3f7`
- `#000000`
- `#60646c`
- `#6f737b`
- `#8b8d98`
- `#b9bbc6`

## Typography

Families: "Flecha, Söhne Breit, sans-serif", "Inter, -apple-system, BlinkMacSystemFont, sans-serif", "Inter, sans-serif". Weights: 400, 500, 600.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Brex

Design token description: A clinical, high-contrast financial interface built on a pure white canvas (ffffff). A single, vivid orange accent (ff5900) carries every primary action, link, and active state, creating a focused system where one color spark does all the talking. Type is set in a compressed, engineered sans-serif stack with aggressive negative tracking for a dense, precise feel. Dark, near-black surfaces (000710, 15191e) are used exclusively for framing elements like footers and announcement bars, bookending the bright canvas. Components are flat with a consistent 12px radius, minimal hairline borders, and generous whitespace, reinforcing the mood of a precision instrument.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- Detected source-domain vocabulary: consumer technology. Translate it into reusable visual behavior, not literal imagery.
- Avoid literal source imagery unless the exact slide text or visual direction explicitly requests it: phones, laptops, tablets, device mockups, or hardware product renders; app screenshots, operating-system chrome, or product launch hero shots.

Overall visual personality: This is a clinical financial interface built on a near-pure white canvas ({colors.canvas-light} — ffffff). The system's character comes from a strict minimalist-maximalist tension: the layout is flat, clean, and spacious, but it's punctuated by a single, vivid orange accent ({colors.primary} — ff5900) that carries every primary action and active state indicator. There is no other chromatic voice. This makes the primary CTA an unmissable focal point on every clean interface-like information plane. Dark surfaces ({colors.canvas-dark}, {colors.surface-dark-chrome}) are used only as framing tactile material surface for the header and footer, creating hard bookends for the bright content area. Typography is a key personality driver. The system uses a workhorse sans-serif (Inter) for all UI and body copy, and a distinct wide display face (Flecha) for major headlines. Both are set with aggressive negative letter-spacing ({typography.hero-display} at -2.2px), giving all text a compressed, engineered, and precise feel. The system avoids decorative flourishes, relying instead on typographic tension, the single color pop, and generous whitespace to build its identity. Key Characteristics: -...

Color tokens:
- primary: #ff5900
- canvas-light: #ffffff
- canvas-dark: #000710
- surface-dark-chrome: #15191e
- surface-soft-light: #f3f3f7
- ink: #000000
- body: #000000
- body-on-dark: #ffffff
- muted: #60646c
- muted-strong: #6f737b
- placeholder: #8b8d98
- hairline: #b9bbc6
- on-primary: #ffffff

Typography tokens:
- hero-display: family Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 72px, weight 600, line 1, tracking -2.2px
- display-lg: family Inter, sans-serif, size 48px, weight 600, line 1.2, tracking -1.2px
- display-md: family Flecha, Söhne Breit, sans-serif, size 36px, weight 500, line 1.11, tracking -0.7px
- title-lg: family Inter, sans-serif, size 36px, weight 600, line 1.21, tracking -0.7px
- title-md: family Inter, sans-serif, size 24px, weight 600, line 1.33, tracking -0.2px
- title-sm: family Inter, sans-serif, size 20px, weight 600, line 1.4, tracking -0.2px
- body-md: family Inter, sans-serif, size 16px, weight 400, line 1.5, tracking -0.2px
- body-sm: family Inter, sans-serif, size 14px, weight 400, line 1.43, tracking -0.1px
- caption: family Inter, sans-serif, size 12px, weight 500, line 1.5, tracking -0.1px
- button: family Inter, sans-serif, size 14px, weight 600, line 1, tracking -0.1px
- nav-link: family Inter, sans-serif, size 14px, weight 500, line 1.43, tracking -0.1px

Spacing tokens:
- xxs: 8px
- xs: 16px
- sm: 24px
- md: 32px
- lg: 48px
- xl: 72px
- xxl: 80px
- section: 80px
- section-lg: 160px

Radius and shape tokens:
- sm: 6px
- md: 12px
- lg: 12px
- xl: 12px
- pill: 9999px
- full: 9999px

Component tokens:
- button-primary: backgroundColor: {colors.primary}, textColor: {colors.on-primary}, typography: {typography.button}, rounded: {rounded.md}, padding: 8px 16px
- button-ghost: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.nav-link}
- button-outlined: backgroundColor: transparent, textColor: {colors.ink}, borderColor: {colors.hairline}, borderWidth: 1px, typography: {typography.button}, rounded: {rounded.md}, padding: 8px 16px
- text-link-primary: backgroundColor: transparent, textColor: {colors.primary}, typography: {typography.caption}
- top-announcement-bar: backgroundColor: {colors.surface-dark-chrome}, textColor: {colors.body-on-dark}, typography: {typography.caption}, padding: 1px 0
- top-nav: backgroundColor: {colors.canvas-light}, textColor: {colors.ink}, typography: {typography.nav-link}, height: 64px
- text-input: backgroundColor: {colors.canvas-light}, textColor: {colors.ink}, borderColor: {colors.hairline}, borderWidth: 1px, typography: {typography.body-md}, rounded: {rounded.md}, padding: 12px 16px
- feature-card: backgroundColor: {colors.canvas-light}, textColor: {colors.ink}, typography: {typography.title-md}, rounded: {rounded.md}, padding: 32px

Color rationale: Brand & Accent - Primary ({colors.primary} — ff5900): A vivid orange, used exclusively for primary action buttons, active tab indicators, and critical links. It's the only saturated color in the palette. - On Primary ({colors.on-primary} — ffffff): Pure white text used on primary action buttons for maximum contrast. the source brand - Canvas Light ({colors.canvas-light} — ffffff): The default page background and primary card the source brand. The system is overwhelmingly white. - the source brand Soft Light ({colors.surface-soft-light} — f3f3f7): A subtle off-white used for alternating background sections (e.g., logo grids) to create gentle separation without borders. - Canvas Dark ({colors.canvas-dark} — 000710): A near-black with a slight blue cast, used only for the site-wide footer. - the source brand Dark Chrome ({colors.surface-dark-chrome} — 15191e): A slightly softer black for the top announcement bar, distinguishing it from the deeper footer. Hairlines & Borders - Hairline ({colors.hairline} — b9bbc6): A light gray used for 1px borders on inputs, outlined buttons, and subtle dividers. Text - Ink ({colors.ink} — 000000): Pure black for primary headings and important body t...

Typography rationale: Font Family The system employs a dual-typeface strategy to balance utility with personality. - Inter: The universal workhorse for all UI elements: body copy, navigation, buttons, inputs, and labels. Its defining characteristic in this system is aggressive negative letter-spacing at all sizes. - Flecha: A distinctive wide display face used selectively for major hero-level headlines to inject brand character. It is never used for sub-headings or body copy. Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.hero-display} | 72px | 600 | 1.0 | -2.2px | Main hero H1 (Inter) | | {typography.display-lg} | 48px | 600 | 1.2 | -1.2px | Large section titles (Inter) | | {typography.display-md} | 36px | 500 | 1.11 | -0.7px | Brand headlines (Flecha) | | {typography.title-lg} | 36px | 600 | 1.21 | -0.7px | Section titles (Inter) | | {typography.title-md} | 24px | 600 | 1.33 | -0.2px | Card titles | | {typography.title-sm} | 20px | 600 | 1.4 | -0.2px | Sub-card titles, small headings | | {typography.body-md} | 16px | 400 | 1.5 | -0.2px | Default running text | | {typography.body-sm} | 14px | 400 | 1.43 | -0.1px | Footer text, small des...

Layout system: Spacing System - Base unit: 8px. - Tokens: {spacing.xxs} 8px · {spacing.xs} 16px · {spacing.sm} 24px · {spacing.md} 32px · {spacing.lg} 48px · {spacing.xl} 72px · {spacing.xxl} 80px · {spacing.section} 80px. - Section padding (vertical): A generous {spacing.lg} (48px) to {spacing.xxl} (80px) is used between major content bands, giving the dense typography significant room to breathe. - Card internal padding: {spacing.sm} (24px) to {spacing.md} (32px) is standard for content cards. - Gutters: {spacing.xs} (16px) between elements in a row, and {spacing.xxs} (8px) for tightly-coupled items like an input field and its button. Grid & Container - Max content width: 1200px centered. - Layout strategy: A full-bleed vertical stack of content bands. The hero often uses an asymmetric split (e.g., 45/55 text/image). Feature sections use centered headlines over horizontal card strips or multi-column grids. Whitespace Philosophy The system uses whitespace as a primary tool for creating structure and focus. Content is never crowded. The generous spacing contrasts with the compressed typography, creating a balanced but precise rhythm.

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | 0 (Canvas) | Flat {colors.canvas-light} or {colors.surface-soft-light} | Default page and section backgrounds. | | 1 (Defined) | 1px {colors.hairline} border | Input fields, outlined buttons, dividers. | | 2 (Card) | {colors.canvas-light} background on {colors.surface-soft-light} | All content cards. Elevation is achieved by background contrast, not shadow. | | 3 (Floating) | Subtle drop shadow | Reserved only for transient UI that floats above the page, like the cookie consent dialog. | | 4 (Dark Chrome) | {colors.surface-dark-chrome} or {colors.canvas-dark} fill | Top announcement bar and site footer. | The elevation model is deliberately flat. The system avoids drop shadows for all in-page components. Depth is communicated through color contrast (ffffff on f3f3f7) and hairline borders, reinforcing the clean, architectural aesthetic.

Shape language: Border Radius Scale | Token | Value | Use | |---|---|---| | {rounded.sm} | 6px | Small inline tags or chips. | | {rounded.md} | 12px | The universal radius for all buttons, inputs, and cards. | | {rounded.pill} | 9999px | Circular elements like carousel navigation buttons. | The shape language is simple and consistent. A single {rounded.md} value defines the corners of almost every interactive element, creating a unified and predictable feel. Iconography Icons are minimalist and line-based, typically rendered in {colors.placeholder} or {colors.ink}. The primary accent color, {colors.primary}, may be used for an icon that accompanies a secondary action link to draw slight attention.

Component language: Buttons - button-primary: The single, high-visibility CTA. Background {colors.primary}, text {colors.on-primary}, rounded {rounded.md}. It is the system's most important component. - button-ghost: A text-only button with no background or border, used for secondary actions like "Sign In" or "See a demo". - button-outlined: A tertiary action button with a transparent background and a 1px {colors.hairline} border. Navigation & Chrome - top-announcement-bar: A slim, full-bleed bar in {colors.surface-dark-chrome} at the very top of the page for time-sensitive messages. - top-nav: The main navigation bar on a {colors.canvas-light} background. Contains navigation links and a right-aligned primary CTA. - footer-dark: A full-bleed footer with a {colors.canvas-dark} background, containing multi-column links in {colors.body-on-dark} text. Cards & Content - feature-card: A simple {colors.canvas-light} card with {rounded.md} corners and generous internal padding ({spacing.md}). Used to showcase product features in a grid. - article-card: Similar to the feature card, but typically contains a full-bleed image at the top and text content below. - logo-grid-band: A full-width section with a {color...

Guardrails: Do - Reserve {colors.prim...
```
