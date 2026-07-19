# Quartz

**ID:** `quartz`  
**Category:** consumer  
**Theme:** light  
**Vibe:** Editorial

## Color palette

- `#171717`
- `#ffffff`
- `#f3f3f3`
- `#e5e7eb`
- `#6f6f6f`
- `#5e5e5e`
- `#a0a0a0`
- `#222222`
- `#c7c7c7`
- `#ffe9bf`

## Typography

Families: "Monument Grotesk, ui-sans-serif, system-ui, sans-serif". Weights: 400.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Compound

Design token description: A quiet, editorial system built on an achromatic palette and generous whitespace. The design operates with near-total chromatic silence, using a single grotesque typeface at a single weight (400) for all roles, from captions to display headlines. Hierarchy is achieved through dramatic jumps in font size rather than color or weight. Surfaces are typically white (ffffff) or a soft off-white (f3f3f3), defined by faint hairlines (e5e7eb) and generous rounded corners (20px). A single warm cream accent (ffe9bf) is reserved for a top-of-page announcement bar, providing the only moment of color. Interactive elements are understated, primarily a near-black (171717) pill button and simple underlined text links.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- No dominant source-domain vocabulary was detected, but still avoid copying example subject matter from the design brief.
- Avoid brand logos, product shots, mascot imagery, packaging, buildings, people, or industry-specific objects unless requested by the slide content.

Overall visual personality: This is a quiet, editorial system built on near-total chromatic silence. The design relies on a single grotesque typeface at a single weight (400) for all roles, establishing hierarchy through dramatic jumps in font size rather than color or weight. The palette is strictly achromatic, anchored by {colors.ink} (171717) on a {colors.canvas-light} (ffffff) ground. Surfaces are minimal, defined by faint {colors.hairline} (e5e7eb) borders and a generous {rounded.md} (20px) corner radius on cards. The only chromatic note is a warm {colors.accent-cream} (ffe9bf) used for a top-of-page announcement bar. Interactive elements are deliberately understated: a single {component.button-primary-pill} in {colors.primary} and simple underlined {component.text-link} elements that blend with the surrounding text. Elevation is almost non-existent, with a single {component.product-preview-card} featuring a very faint, multi-layered shadow to create a sense of atmospheric depth. The overall feeling is that of an ink-on-paper journal, where content and typography are paramount. Key Characteristics: - Single typeface, single weight: One font at weight 400 does all the expressive work. - Achromatic palett...

Color tokens:
- primary: #171717
- ink: #171717
- body: #171717
- canvas-light: #ffffff
- surface-soft: #f3f3f3
- hairline: #e5e7eb
- muted: #6f6f6f
- muted-strong: #5e5e5e
- placeholder: #a0a0a0
- icon-fill: #222222
- decorative: #c7c7c7
- accent-cream: #ffe9bf
- on-primary: #ffffff

Typography tokens:
- hero-display: family Monument Grotesk, ui-sans-serif, system-ui, sans-serif, size 72px, weight 400, line 1, tracking 0
- display-lg: family Monument Grotesk, ui-sans-serif, system-ui, sans-serif, size 60px, weight 400, line 1.1, tracking 0
- display-md: family Monument Grotesk, ui-sans-serif, system-ui, sans-serif, size 48px, weight 400, line 1.11, tracking 0
- display-sm: family Monument Grotesk, ui-sans-serif, system-ui, sans-serif, size 36px, weight 400, line 1.25, tracking 0
- title-md: family Monument Grotesk, ui-sans-serif, system-ui, sans-serif, size 18px, weight 400, line 1.38, tracking 0
- body-md: family Monument Grotesk, ui-sans-serif, system-ui, sans-serif, size 16px, weight 400, line 1.5, tracking 0
- body-sm: family Monument Grotesk, ui-sans-serif, system-ui, sans-serif, size 14px, weight 400, line 1.43, tracking 0
- caption: family Monument Grotesk, ui-sans-serif, system-ui, sans-serif, size 12px, weight 400, line 1.5, tracking 0
- button: family Monument Grotesk, ui-sans-serif, system-ui, sans-serif, size 14px, weight 400, line 1, tracking 0
- nav-link: family Monument Grotesk, ui-sans-serif, system-ui, sans-serif, size 14px, weight 400, line 1.43, tracking 0

Spacing tokens:
- xxs: 8px
- xs: 16px
- sm: 24px
- md: 32px
- lg: 48px
- xl: 64px
- section: 80px

Radius and shape tokens:
- sm: 8px
- md: 20px
- lg: 24px
- xl: 28px
- pill: 9999px
- full: 9999px

Component tokens:
- button-primary-pill: backgroundColor: {colors.primary}, textColor: {colors.on-primary}, typography: {typography.button}, rounded: {rounded.pill}, padding: 8px 16px
- text-link: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.nav-link}
- announcement-bar: backgroundColor: {colors.accent-cream}, textColor: {colors.ink}, typography: {typography.body-sm}, padding: 8px
- top-nav: backgroundColor: {colors.canvas-light}, textColor: {colors.ink}, typography: {typography.nav-link}
- product-preview-card: backgroundColor: {colors.canvas-light}, textColor: {colors.ink}, rounded: {rounded.md}, border: 1px solid {colors.hairline}
- feature-card: backgroundColor: {colors.surface-soft}, textColor: {colors.ink}, rounded: {rounded.md}, padding: 24px
- logo-card: backgroundColor: {colors.surface-soft}, rounded: {rounded.md}, padding: 24px
- icon-container: backgroundColor: {colors.surface-soft}, rounded: {rounded.full}, height: 40px, width: 40px

Color rationale: Core Palette - Ink ({colors.ink} — 171717): The primary text color, used for all headlines, body copy, and the background of filled pill buttons. It's the dark anchor of the system. - Canvas Light ({colors.canvas-light} — ffffff): The default page canvas and primary card surface color. - Hairline ({colors.hairline} — e5e7eb): The color for all structural borders, dividers, and card edges. It is the most-used color by frequency. - Surface Soft ({colors.surface-soft} — f3f3f3): A very light gray for secondary surfaces, such as feature cards, logo containers, and subtle hover states. Text & Muted Tones - Muted ({colors.muted} — 6f6f6f): The primary muted text voice, used for secondary body copy, metadata, and tab labels. - Muted Strong ({colors.muted-strong} — 5e5e5e): A slightly darker gray for descriptive captions and helper text that needs more emphasis than standard muted text. - Placeholder ({colors.placeholder} — a0a0a0): The quietest readable gray, used for placeholder text in inputs and disabled states. Accent & Decorative - Accent Cream ({colors.accent-cream} — ffe9bf): The single warm accent in the system, used exclusively for the background of the top announcement bar. - O...

Typography rationale: Font Family The system uses a single geometric grotesque typeface for all text elements, from {typography.caption} to {typography.hero-display}. Crucially, it exclusively uses a single weight (400) for all roles. There is no bold or italic variant; all emphasis and hierarchy are created through changes in font size and the generous use of whitespace. Tight line-heights at display sizes (1.0–1.11) allow large headlines to form dense, impactful blocks of text. Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.hero-display} | 72px | 400 | 1 | 0 | Primary page headline | | {typography.display-lg} | 60px | 400 | 1.1 | 0 | Major section display titles | | {typography.display-md} | 48px | 400 | 1.11 | 0 | Section headings | | {typography.display-sm} | 36px | 400 | 1.25 | 0 | Sub-section headings, large stat numbers | | {typography.title-md} | 18px | 400 | 1.38 | 0 | Card titles, subheadings | | {typography.body-md} | 16px | 400 | 1.5 | 0 | Default running-text | | {typography.body-sm} | 14px | 400 | 1.43 | 0 | Secondary body text, button labels | | {typography.caption} | 12px | 400 | 1.5 | 0 | Small meta labels, helper text |...

Layout system: Spacing System - Base unit: 8px. - Tokens: {spacing.xxs} 8px · {spacing.xs} 16px · {spacing.sm} 24px · {spacing.md} 32px · {spacing.lg} 48px · {spacing.xl} 64px · {spacing.section} 80px. - Section gap (vertical): {spacing.section} (80px) is the standard distance between major content blocks. This generous spacing is critical to the system's clean, editorial feel. - Card internal padding: {spacing.sm} (24px) is the standard for most content cards. - Gutters: {spacing.xs} (16px) between cards in a grid; {spacing.xxs} (8px) for small gaps between inline elements. Grid & Container - Max content width: ~1200px, centered. - Layout structure: Primarily a single-column, vertical stack. Multi-column grids (e.g., 3-up or 4-up) are used for feature card rows but maintain a simple, symmetrical balance. There are no sidebars or complex, asymmetrical layouts. Whitespace Philosophy The system treats whitespace as a primary design tool. Hierarchy is conveyed as much by the space around elements as by the size of the elements themselves. The layout is intentionally sparse and breathable, avoiding dense clusters of information and allowing each component to stand on its own.

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | Flat | No shadow, {colors.hairline} border | Default for most cards, buttons, and surfaces. Separation is achieved with color and lines, not depth. | | Atmospheric Shadow | Very faint, multi-layered, low-opacity shadow | Used on the {component.product-preview-card}. The shadow is so subtle it registers as atmosphere rather than a distinct object layer, creating a sense of soft lift. | The system's elevation model is one of extreme restraint. Nearly every element is flat. The one exception is a signature soft, multi-layered shadow reserved for a single key component, making it feel special and distinct. This is not a system of stacked cards, but of ink on a flat plane.

Shape language: Border Radius Scale | Token | Value | Use | |---|---|---| | {rounded.sm} | 8px | Small cards or UI elements requiring a subtle corner. | | {rounded.md} | 20px | The default radius for all primary content cards. | | {rounded.lg} | 24px | Large container cards. | | {rounded.xl} | 28px | List items or nested containers. | | {rounded.pill} | 9999px | The standard radius for all buttons and icon containers, creating a soft, pill-like shape. | The shape language is defined by softness and consistency. There are two primary shapes: the gently rounded rectangle ({rounded.md}) for containers, and the full pill ({rounded.pill}) for all interactive controls. Sharp corners are never used. Iconography Icons are monochrome, rendered in {colors.icon-fill}. They are typically contained within a circular {component.icon-container} with a {colors.surface-soft} background and a {rounded.full} radius.

Component language: Buttons & Links button-primary-pill — The single primary action button. It uses a {colors.primary} background with {colors.on-primary} text, a {rounded.pill} shape, and {typography.button}. It is the only filled button style in the system. text-link — Used for all secondary and inline navigation. It is visually simple: {colors.ink} text with a 1px underline. It is designed to read as part of the text flow, not as a piece of UI chrome. Banners & Navigation announcement-bar — A full-bleed promotional strip at the top of the viewport. It has a {colors.accent-cream} background and holds a short text message in {typography.body-sm}. It is the only component that uses color. top-nav — A clean, single-row navigation bar with a {colors.canvas-light} background. It contains a left-aligned text mark, centered {component.text-link} navigation items, and a right-aligned cluster with a sign-in link and a {component.button-primary-pill}. Cards & Containers product-preview-card — The most visually distinct component. A {colors.canvas-light} card with a {rounded.md} radius and a {colors.hairline} border. It is the only component that uses the system's atmospheric, multi-layered drop shadow, givin...

Guardrails: Do - Use only the single specified grotesque typeface at weight 400. - Use {rounded.pill} for all b...
```
