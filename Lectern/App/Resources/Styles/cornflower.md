# Cornflower

**ID:** `cornflower`  
**Category:** consumer  
**Theme:** light  
**Vibe:** Editorial

## Color palette

- `#5551ff`
- `#a95ef8`
- `#007aff`
- `#000000`
- `#bdbdbd`
- `#d2d4d7`
- `#666666`
- `#e4e7ed`
- `#ffffff`
- `#27272b`

## Typography

Families: "'CanelaDeck', Georgia, serif", "'Poppins', -apple-system, BlinkMacSystemFont, sans-serif", "'Poppins', sans-serif". Weights: 400, 500, 600.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: WRITER

Design token description: A confident editorial interface built on a near-white canvas, where large display headlines and extremely rounded pill-shaped controls (60px+) define the interaction model. A single vivid violet (5551ff) acts as the primary accent for key CTAs, while a second violet (a95ef8) is reserved exclusively for highlighting a single word within an otherwise monochrome display headline. The typography pairs a geometric sans (Poppins) for UI and display with a custom serif (CanelaDeck) for body copy, lending an editorial feel. Sections alternate between the default light theme and inverted near-black resource blocks, creating a magazine-like rhythm. The system is intentionally flat, trusting whitespace and type scale over shadows or complex chrome.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- No dominant source-domain vocabulary was detected, but still avoid copying example subject matter from the design brief.
- Avoid brand logos, product shots, mascot imagery, packaging, buildings, people, or industry-specific objects unless requested by the slide content.

Overall visual personality: The system reads as a confident, minimalist editorial platform. The base canvas is near-white ({colors.canvas-light}), creating a bright, spacious environment for typography. The defining visual characteristic is the use of extreme pill-shaped controls — buttons at {rounded.pill} (60px) and inputs at {rounded.pill-lg} (72px) give the UI a soft, modern, and approachable feel. The color palette is starkly monochrome, punctuated by a single vivid violet ({colors.primary} — 5551ff) for primary CTAs and outlines. A second, distinct violet ({colors.accent-highlight} — a95ef8) has a single, reserved purpose: highlighting one word within a large display headline, a signature typographic gesture. The typography is a deliberate mix of sans and serif. The geometric sans Poppins handles all display, UI, and label text, from tightly-tracked 64px headlines to wide-tracked 11px eyebrow labels. For running body copy, the system switches to the custom serif CanelaDeck, adding an editorial, premium-content feel. Pages are built with a light/dark alternating rhythm, where near-black resource sections ({colors.canvas-dark}) break up the default white canvas. The design is intentionally flat, avoiding...

Color tokens:
- primary: #5551ff
- accent-highlight: #a95ef8
- accent-secondary: #007aff
- ink: #000000
- body-on-light: #000000
- muted: #bdbdbd
- muted-strong: #d2d4d7
- muted-text: #666666
- hairline: #e4e7ed
- canvas-light: #ffffff
- canvas-dark: #27272b
- surface-card-dark: #2d2d2d
- surface-accent: #e4e9ff
- on-primary: #ffffff

Typography tokens:
- hero-display: family 'Poppins', -apple-system, BlinkMacSystemFont, sans-serif, size 64px, weight 500, line 1, tracking -1.98px
- display-lg: family 'Poppins', sans-serif, size 44px, weight 500, line 1.15, tracking -0.88px
- display-md: family 'Poppins', sans-serif, size 40px, weight 500, line 1.2, tracking -0.8px
- title-lg: family 'Poppins', sans-serif, size 25px, weight 600, line 1.25, tracking -0.4px
- title-md: family 'Poppins', sans-serif, size 20px, weight 500, line 1.4, tracking -0.2px
- body-md: family 'CanelaDeck', Georgia, serif, size 16px, weight 400, line 1.5, tracking 0
- body-sans-md: family 'Poppins', sans-serif, size 16px, weight 400, line 1.5, tracking 0
- body-sm: family 'Poppins', sans-serif, size 14px, weight 400, line 1.55, tracking 0
- button: family 'Poppins', sans-serif, size 14px, weight 500, line 1, tracking 0
- caption: family 'Poppins', sans-serif, size 11px, weight 500, line 1.5, tracking 1.5px
- nav-link: family 'Poppins', sans-serif, size 14px, weight 500, line 1.4, tracking 0

Spacing tokens:
- xxs: 4px
- xs: 8px
- sm: 12px
- md: 16px
- lg: 24px
- xl: 32px
- xxl: 60px
- section: 80px

Radius and shape tokens:
- md: 12px
- pill: 60px
- pill-lg: 72px
- full: 9999px

Component tokens:
- button-primary: backgroundColor: {colors.canvas-dark}, textColor: {colors.on-dark}, typography: {typography.button}, rounded: {rounded.pill}, padding: 16px 32px
- button-accent: backgroundColor: {colors.primary}, textColor: {colors.on-primary}, typography: {typography.button}, rounded: {rounded.pill}, padding: 12px 24px
- button-secondary-outlined: backgroundColor: transparent, textColor: {colors.primary}, borderColor: {colors.primary}, borderWidth: 1.5px, typography: {typography.button}, rounded: {rounded.pill}, padding: 12px 24px
- input-pill: backgroundColor: {colors.canvas-light}, textColor: {colors.ink}, borderColor: {colors.muted}, borderWidth: 1px, typography: {typography.body-sans-md}, rounded: {rounded.pill-lg}, padding: 16px 20px
- hero-band: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.hero-display}, padding: 80px
- eyebrow-label: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.caption}
- feature-card-light: backgroundColor: {colors.canvas-light}, textColor: {colors.ink}, typography: {typography.body-sm}, rounded: {rounded.md}, padding: 24px
- section-dark: backgroundColor: {colors.canvas-dark}, textColor: {colors.on-dark}, typography: {typography.display-lg}, padding: 80px 24px

Color rationale: Brand & Accent - Primary Violet ({colors.primary} — 5551ff): The main brand color. Used for accent CTA backgrounds ({component.button-accent}), outlined button strokes, and active UI states. - Accent Highlight ({colors.accent-highlight} — a95ef8): A brighter, more saturated violet reserved exclusively for highlighting a single word within a {typography.hero-display} headline. It is never used for interactive elements. - Accent Secondary ({colors.accent-secondary} — 007aff): A blue accent used for decorative details or low-frequency emphasis. It does not carry primary functional weight. Surface - Canvas Light ({colors.canvas-light} — ffffff): The default page background. Used for all primary editorial sections, cards, and input fields. - Canvas Dark ({colors.canvas-dark} — 27272b): A warm near-black. Used for alternating full-width resource sections and the background of the primary CTA ({component.button-primary}). - Surface Card Dark ({colors.surface-card-dark} — 2d2d2d): A slightly lighter dark tone for nested dark-mode elements. - Surface Accent ({colors.surface-accent} — e4e9ff): A pale lavender wash used for subtle background emphasis, like announcement banners. Text - Ink ({...

Typography rationale: Font Family The system employs a dual-font strategy to balance UI clarity with an editorial feel. - Poppins: A geometric sans-serif used for all UI elements, display headlines, subheadings, buttons, and labels. Its clean geometry provides functional clarity. - CanelaDeck: A custom serif used for running body copy ({typography.body-md}). Its inclusion signals a shift from functional UI to premium, readable content, evoking a magazine-like quality. Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.hero-display} | 64px | 500 | 1.0 | -1.98px | Main page h1, typically with a single word highlighted in {colors.accent-highlight} | | {typography.display-lg} | 44px | 500 | 1.15 | -0.88px | Section headlines on dark backgrounds | | {typography.display-md} | 40px | 500 | 1.2 | -0.8px | Major section headlines on light backgrounds | | {typography.title-lg} | 25px | 600 | 1.25 | -0.4px | Card titles, feature headlines | | {typography.title-md} | 20px | 500 | 1.4 | -0.2px | Sub-section titles | | {typography.body-md} | 16px | 400 | 1.5 | 0 | Main body copy, set in CanelaDeck serif | | {typography.body-sans-md} | 16px | 400 | 1.5 | 0...

Layout system: Spacing System - Base unit: 4px. - Tokens: {spacing.xxs} 4px · {spacing.xs} 8px · {spacing.sm} 12px · {spacing.md} 16px · {spacing.lg} 24px · {spacing.xl} 32px · {spacing.xxl} 60px. - Section padding (vertical): {spacing.section} (80px) is the standard gap between major content blocks, creating a spacious, unhurried rhythm. - Card internal padding: {spacing.lg} (24px) is standard for content cards. - Gutters: {spacing.md} (16px) between cards in a grid. Grid & Container - Max content width: 1200px, center-aligned. - Structure: Content is typically organized in single-column stacks or 2/3-column grids for feature cards. The hero area is always a centered text stack. - Rhythm: The defining layout principle is the alternation between full-width {colors.canvas-light} and {colors.canvas-dark} sections, creating a clear visual cadence down the page. Whitespace Philosophy The system is generous with whitespace. The lack of shadows and minimal chrome means that empty space is the primary tool for separating elements and establishing hierarchy. Section gaps are large, and internal card padding is comfortable, reinforcing the open, editorial feel.

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | Flat | No shadow, no border | Body sections, hero bands, dark resource sections | | Soft hairline | 1px {colors.hairline} or {colors.muted} | Subtle dividers, some card edges, input field borders | | Card surface | {colors.canvas-light} on a {colors.canvas-light} background | Content cards are visually separated by their rounded corners and internal content, not by elevation effects | | Inverted Card | {colors.canvas-light} card on a {colors.canvas-dark} background | The clearest form of elevation, used in dark resource sections to float light content cards | The elevation model is entirely flat. The system actively avoids drop shadows, gradients (with rare exception), and any form of skeuomorphism. Depth is conveyed purely through color contrast, such as a white card placed on a dark section background. This reinforces the confident, type-driven, graphic design aesthetic.

Shape language: Border Radius Scale | Token | Value | Use | |---|---|---| | {rounded.md} | 12px | Content cards, images within cards, icons | | {rounded.pill} | 60px | All standard buttons, creating a soft, approachable pill shape | | {rounded.pill-lg} | 72px | Email/text input fields, creating an even more pronounced pill shape | | {rounded.full} | 9999px | Avatars, circular icons (if any) | The shape language is a study in contrasts. Content containers like cards and images use a modest {rounded.md} (12px). In stark contrast, all interactive controls (buttons, inputs) use extreme {rounded.pill} and {rounded.pill-lg} values. This creates a clear visual distinction: content lives in soft rectangles, while actions live in pills.

Component language: Buttons button-primary — The main dark CTA. It uses a {colors.canvas-dark} background with {colors.on-dark} text. Its {rounded.pill} shape makes it a signature component. button-accent — The secondary, brand-colored CTA. It uses a {colors.primary} background with {colors.on-primary} text. It's slightly smaller than the primary button and is used for high-visibility actions. button-secondary-outlined — A ghost-style button with a transparent background and a 1.5px border in {colors.primary}. The text also uses {colors.primary}. It offers a lower-emphasis alternative to the filled buttons while maintaining the signature pill shape. Inputs input-pill — The standard text input, defined by its extreme {rounded.pill-lg} (72px) radius. It has a {colors.canvas-light} background with a subtle 1px border in {colors.muted}. Content & Containers hero-band — A full-width, spacious section containing the main page headline. It uses {typography.hero-display} with its signature single-word color highlight in {colors.accent-highlight}. eyebrow-label — A small, all-caps text element set in {...
```
