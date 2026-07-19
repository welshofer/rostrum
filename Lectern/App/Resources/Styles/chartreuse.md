# Chartreuse

**ID:** `chartreuse`  
**Category:** consumer  
**Theme:** dark  
**Vibe:** Technical

## Color palette

- `#cef79e`
- `#222f30`
- `#ffffff`
- `#4d5757`
- `#c9cbbe`
- `#f7f7f5`
- `#000000`
- `#e7e8e1`
- `#eeeeee`

## Typography

Families: "'Aspekta', ui-sans-serif, system-ui, sans-serif", "'Roboto Mono', ui-monospace, monospace". Weights: 400.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Integrated Biosciences

Design token description: A spare, technical interface evocative of a darkroom laboratory, built on a near-black canvas (222f30) with cool undertones. A single bioluminescent lime accent (cef79e) activates small interactive elements like arrow buttons and status dots. The typography is a defining feature, running a single weight of its primary font for all roles; hierarchy is sculpted purely through size and aggressive negative letter-spacing. A secondary monospace font is reserved for technical labels and navigation, reinforcing the system's instrumentation-panel character. Surfaces are flat, delineated by thin hairlines, with a light mode that flips the canvas to a warm off-white (f7f7f5).

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- Detected source-domain vocabulary: consumer technology. Translate it into reusable visual behavior, not literal imagery.
- Avoid literal source imagery unless the exact slide text or visual direction explicitly requests it: phones, laptops, tablets, device mockups, or hardware product renders; app screenshots, operating-system chrome, or product launch hero shots.

Overall visual personality: The system presents a spare, technical interface with the atmosphere of a darkroom laboratory. The default theme is built on a near-black canvas ({colors.canvas-dark} — 222f30) with cool green undertones, supporting bright white text ({colors.body-on-dark}). A single, rationed bioluminescent lime accent ({colors.primary} — cef79e) activates only on small, interactive micro-surfaces like arrow buttons, active navigation states, and status dots. It is a signal, not a decorative color. The typography is the system's defining feature. A single sans-serif font, Aspekta, is used at a single weight (400) for every role from body copy to hero display. Hierarchy is sculpted purely through size and aggressive negative letter-spacing, creating an architectural, unornamented feel. A secondary monospace font, Roboto Mono, is reserved for technical labels, navigation, and metadata, reinforcing the system's instrumentation-panel character. Surfaces are deliberately flat, delineated by thin hairlines rather than shadows. A light mode flips the canvas to a warm off-white ({colors.canvas-light} — f7f7f5) with white cards ({colors.surface-light}), but the lime accent and typography rules persist, cr...

Color tokens:
- primary: #cef79e
- on-primary: #222f30
- ink: #222f30
- body-on-dark: #ffffff
- body-on-light: #222f30
- muted: #4d5757
- hairline-on-light: #c9cbbe
- hairline-on-dark: #4d5757
- canvas-light: #f7f7f5
- canvas-dark: #222f30
- canvas-footer: #000000
- surface-light: #ffffff
- surface-soft-light: #e7e8e1
- surface-neutral-light: #eeeeee

Typography tokens:
- hero-display: family 'Aspekta', ui-sans-serif, system-ui, sans-serif, size 158px, weight 400, line 1, tracking -4.74px
- display-xl: family 'Aspekta', ui-sans-serif, system-ui, sans-serif, size 111px, weight 400, line 1, tracking -2.22px
- display-lg: family 'Aspekta', ui-sans-serif, system-ui, sans-serif, size 89px, weight 400, line 1.1, tracking -1.78px
- display-md: family 'Aspekta', ui-sans-serif, system-ui, sans-serif, size 75px, weight 400, line 1.1, tracking -1.5px
- display-sm: family 'Aspekta', ui-sans-serif, system-ui, sans-serif, size 58px, weight 400, line 1.1, tracking -0.7px
- title-lg: family 'Aspekta', ui-sans-serif, system-ui, sans-serif, size 36px, weight 400, line 1.2, tracking -0.22px
- title-md: family 'Aspekta', ui-sans-serif, system-ui, sans-serif, size 24px, weight 400, line 1.2, tracking -0.14px
- body-lg: family 'Aspekta', ui-sans-serif, system-ui, sans-serif, size 22px, weight 400, line 1.3, tracking -0.13px
- body-md: family 'Aspekta', ui-sans-serif, system-ui, sans-serif, size 18px, weight 400, line 1.3, tracking -0.018px
- button: family 'Roboto Mono', ui-monospace, monospace, size 14px, weight 400, line 1.2, tracking -0.28px
- caption: family 'Roboto Mono', ui-monospace, monospace, size 13px, weight 400, line 1.23, tracking -0.26px

Spacing tokens:
- xxs: 4px
- xs: 8px
- sm: 12px
- md: 20px
- lg: 40px
- xl: 60px
- xxl: 88px
- section: 120px

Radius and shape tokens:
- sm: 8px
- md: 12px
- lg: 16px
- xl: 20px
- xxl: 40px
- pill: 9999px
- full: 9999px

Component tokens:
- button-primary-on-dark: backgroundColor: {colors.surface-light}, textColor: {colors.ink}, typography: {typography.button}, rounded: {rounded.sm}, padding: 8px 16px
- button-primary-on-light: backgroundColor: {colors.ink}, textColor: {colors.body-on-dark}, typography: {typography.button}, rounded: {rounded.sm}, padding: 8px 16px
- button-secondary-on-dark: backgroundColor: transparent, textColor: {colors.body-on-dark}, typography: {typography.button}, rounded: {rounded.sm}, border: 1px solid {colors.muted}, padding: 8px 16px
- button-secondary-on-light: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.button}, rounded: {rounded.sm}, border: 1px solid {colors.muted}, padding: 8px 16px
- button-accent-icon: backgroundColor: {colors.primary}, textColor: {colors.on-primary}, rounded: {rounded.sm}, height: 40px, width: 40px
- nav-link: backgroundColor: transparent, textColor: {colors.hairline-on-light}, typography: {typography.caption}, rounded: {rounded.md}, border: 1px solid {colors.hairline-on-light}, padding: 8px 16px
- nav-link-active: backgroundColor: {colors.primary}, textColor: {colors.on-primary}, typography: {typography.caption}, rounded: {rounded.md}, padding: 8px 16px
- article-card: backgroundColor: {colors.surface-light}, textColor: {colors.ink}, rounded: {rounded.xl}, padding: {spacing.lg}

Color rationale: Brand & Accent - Primary ({colors.primary} — cef79e): A bioluminescent lime green. Its use is strictly rationed for interactive micro-surfaces: active nav states, small icon buttons, and status dots. It functions as a signal lamp. - On Primary ({colors.on-primary} — 222f30): The dark ink color used for text or icons placed on the primary accent color, ensuring high contrast. the source brand The system operates in two primary modes: Dark mode (default): - Canvas Dark ({colors.canvas-dark} — 222f30): The primary page floor. A near-black with a distinct cool green undertone. - Canvas Footer ({colors.canvas-footer} — 000000): A pure black used only for the final footer section, creating a subtle terminal drop in tone. Light mode: - Canvas Light ({colors.canvas-light} — f7f7f5): The page floor for light-themed sections. A warm, creamy off-white. - the source brand Light ({colors.surface-light} — ffffff): The the source brand for cards and elevated containers on the light canvas. - the source brand Soft Light ({colors.surface-soft-light} — e7e8e1): A warmer, secondary card the source brand for differentiating content blocks. - the source brand Neutral Light ({colors.surface-neutral-lig...

Typography rationale: Font Family The system employs a strict two-font model to separate editorial content from technical UI elements. - Aspekta: Used for all display headlines, subheadings, and body copy. It is always rendered at fontWeight: 400. - Roboto Mono: Used for all technical and UI-related text: navigation links, button labels, metadata, captions, and section counters. It is always rendered at fontWeight: 400. This functional split is a core principle. Using the mono font for body copy or the sans-serif for button labels would violate the system's voice. Hierarchy The type hierarchy is defined by size and letter-spacing, not weight. As font size increases, letter-spacing becomes proportionally tighter (more negative) to maintain optical balance. | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.hero-display} | 158px | 400 | 1 | -4.74px | Page-level hero headlines | | {typography.display-xl} | 111px | 400 | 1 | -2.22px | Major display statements | | {typography.display-lg} | 89px | 400 | 1.1 | -1.78px | Large section titles | | {typography.display-sm} | 58px | 400 | 1.1 | -0.7px | Sub-section headlines | | {typography.title-lg} | 36px | 400...

Layout system: Spacing System - Base unit: 4px. - Tokens: {spacing.xxs} 4px · {spacing.xs} 8px · {spacing.sm} 12px · {spacing.md} 20px · {spacing.lg} 40px · {spacing.xl} 60px · {spacing.xxl} 88px · {spacing.section} 120px. - Section padding (vertical): {spacing.section} (120px) is used between major content blocks, creating significant breathing room. - Card internal padding: {spacing.lg} (40px) is standard for primary content cards, reinforcing the open, uncluttered feel. - Gutters: Gaps between elements are typically {spacing.md} (20px). Grid & Container - Max content width: 1200px, centered. Dark and light canvas colors extend to the full bleed of the viewport. - Editorial body: Content is generally single-column or a two-column split (e.g., image-left, text-right) within the 1200px container. - Asymmetry: Hero sections often employ asymmetrical layouts, with text occupying the left two-thirds and large amounts of negative space on the right. Whitespace Philosophy The system is defined by generous whitespace. It trusts negative space, rather than heavy dividers or boxes, to create separation and focus. Compression would undermine the calm, deliberate pacing of the content.

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | Flat | No shadow, no border | Body sections, hero bands, footer | | Soft hairline | 1px {colors.hairline-on-dark} or {colors.hairline-on-light} | Dividers, outlined buttons, navigation pills | | Card the source brand | {colors.surface-light} background on light canvas — no shadow | All elevated cards | The elevation model is deliberately flat. There are no box-shadows or gradients used to imply depth. The interface is treated as a series of flat ink layers on a flat the source brand. Hierarchy and separation are achieved exclusively through color contrast (e.g., {colors.surface-light} on {colors.canvas-light}) and the use of minimal, 1px hairlines.

Shape language: Border Radius Scale | Token | Value | Use | |---|---|---| | {rounded.sm} | 8px | Standard buttons, small interactive elements | | {rounded.md} | 12px | Navigation pills, contained image areas | | {rounded.lg} | 16px | Standard content cards | | {rounded.xl} | 20px | Larger content cards | | {rounded.xxl} | 40px | Feature-level large container cards | | {rounded.pill} | 9999px | Tags, section counters, and other small metadata badges | | {rounded.full} | 9999px | Circular status dots | The system uses a soft but restrained radius scale. Sharp corners are avoided, but the radii are not so large as to feel playful. The pill shape is used only for small, label-like elements. Imagery & Iconography - Imagery is typically abstract, technical, or illustrative rather than photographic. - When used, images are contained within rounded rectangles, typically with a {rounded.md} (12px) or {rounded.lg} (16px) radius. - Icons are minimal and line-based, rendered in a solid color (e.g., the arrow in {component.button-accent-icon}).

Component language: Navigation nav-link — A pill-shaped, outlined navigation item. On dark surfaces, it has a transparent background with a 1px border and text in {colors.hairline-on-light}. Type is set in {typography.caption} (monospace). nav-link-active — The active state for a nav item. The background fills with {colors.primary} and the text flips to {colors.on-primary}, providing a clear, high-contrast signal. Buttons button-primary-on-dark / button-primary-on-light — The primary action button. It is a simple filled rectangle with {rounded.sm} corners. It inverts the the s...
```
