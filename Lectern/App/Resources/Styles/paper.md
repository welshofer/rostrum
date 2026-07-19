# Paper

**ID:** `paper`  
**Category:** consumer  
**Theme:** light  
**Vibe:** Minimal

## Color palette

- `#000000`
- `#161637`
- `#666666`
- `#0085e4`
- `#dadce0`
- `#fafafc`
- `#f0f0f2`
- `#ffffff`

## Typography

Families: "Inter, -apple-system, BlinkMacSystemFont, sans-serif". Weights: 400, 500, 600, 700.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Overflow

Design token description: A quiet, designer-tool interface built on a paper-cream canvas (fafafc), where a deep midnight-navy (161637) serves as the primary ink for typography and a solid black (000000) carries the single, high-contrast primary CTA. Type is set entirely in Inter, using tight negative tracking on display sizes to create dense, confident blocks. A single sky-blue accent (0085e4) provides sparse decorative highlights. The system feels spacious and atmospheric, favoring generous section gaps, large radii (12-24px), and extremely subtle low-opacity shadows. UI is often presented within a framed container floating over a soft indigo-to-sky gradient wash.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- No dominant source-domain vocabulary was detected, but still avoid copying example subject matter from the design brief.
- Avoid brand logos, product shots, mascot imagery, packaging, buildings, people, or industry-specific objects unless requested by the slide content.

Overall visual personality: The system presents a quiet, minimalist aesthetic tailored for a designer-centric audience. The foundation is a warm, paper-cream canvas ({colors.canvas-light} — fafafc) that avoids the harshness of pure white. Typography is the primary design element, with a deep midnight-navy ink ({colors.ink} — 161637) used for headlines and a solid black ({colors.primary} — 000000) for body copy. The single primary call-to-action is also solid black, creating a moment of maximum contrast. The entire typographic system is built on the Inter typeface, characterized by its tight negative letter-spacing in display sizes ({typography.display-lg} has -1.4px tracking), which forms dense, confident blocks of text. The layout is defined by generous whitespace, with major sections separated by {spacing.section} (96px). Shapes are soft and rounded, with buttons at {rounded.lg} (12px) and cards at a distinctive {rounded.xl} (24px). Elevation is extremely subtle, using faint, low-opacity shadows that barely register. A single sky-blue ({colors.accent-info} — 0085e4) provides sparse highlights, while a soft indigo-to-sky gradient is used as an atmospheric backdrop for hero sections, creating a feeling of de...

Color tokens:
- primary: #000000
- ink: #161637
- body: #000000
- muted: #666666
- accent-info: #0085e4
- hairline-on-light: #dadce0
- canvas-light: #fafafc
- surface-soft-light: #f0f0f2
- on-primary: #fafafc
- on-dark: #fafafc

Typography tokens:
- display-lg: family Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 56px, weight 700, line 1.07, tracking -1.4px
- display-md: family Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 48px, weight 700, line 1.14, tracking -1px
- title-lg: family Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 32px, weight 600, line 1.25, tracking -0.6px
- title-md: family Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 24px, weight 600, line 1.33, tracking -0.4px
- title-sm: family Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 20px, weight 500, line 1.42, tracking -0.24px
- body-md: family Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 14px, weight 400, line 1.57, tracking -0.08px
- caption: family Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 12px, weight 400, line 1.5, tracking 0.07px
- button: family Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 15px, weight 600, line 1.4, tracking -0.12px
- nav-link: family Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 15px, weight 500, line 1.4, tracking -0.12px

Spacing tokens:
- xxs: 4px
- xs: 8px
- sm: 12px
- md: 16px
- lg: 24px
- xl: 32px
- xxl: 64px
- section: 96px

Radius and shape tokens:
- xs: 2px
- sm: 4px
- md: 8px
- lg: 12px
- xl: 24px
- pill: 9999px
- full: 9999px

Component tokens:
- button-primary: backgroundColor: {colors.primary}, textColor: {colors.on-primary}, typography: {typography.button}, rounded: {rounded.lg}, padding: 16px 24px
- button-secondary-outline: backgroundColor: {colors.canvas-light}, textColor: {colors.primary}, typography: {typography.button}, rounded: {rounded.lg}, padding: 10px 18px
- top-nav: backgroundColor: {colors.canvas-light}, textColor: {colors.muted}, typography: {typography.nav-link}, height: 64px
- hero-gradient-band: backgroundColor: transparent, textColor: {colors.on-dark}, typography: {typography.display-lg}, padding: 96px 24px
- media-frame-card: backgroundColor: {colors.canvas-light}, rounded: {rounded.xl}
- feature-card: backgroundColor: {colors.canvas-light}, textColor: {colors.body}, typography: {typography.title-md}, rounded: {rounded.xl}, padding: 32px
- accent-gradient-card: backgroundColor: transparent, textColor: {colors.on-dark}, typography: {typography.title-md}, rounded: {rounded.xl}, padding: 32px
- text-input: backgroundColor: {colors.surface-soft-light}, textColor: {colors.body}, typography: {typography.button}, rounded: {rounded.md}, padding: 12px 16px

Color rationale: Brand & Accent - Primary ({colors.primary} — 000000): Solid black. Used for the primary CTA background ({component.button-primary}) and primary body text. - Ink ({colors.ink} — 161637): A desaturated midnight navy. Serves as the ink for all major headlines, providing a softer alternative to pure black. - Accent Info ({colors.accent-info} — 0085e4): A clear sky blue. Reserved for small decorative accents, like progress rings or tertiary links, never for primary actions. Surface - Canvas Light ({colors.canvas-light} — fafafc): The default page background. A warm, off-white that creates a soft, paper-like feel. Also used for card surfaces. - Surface Soft Light ({colors.surface-soft-light} — f0f0f2): A slightly cooler gray. Used for alternate section backgrounds and the default state of text inputs. Text - Body ({colors.body} — 000000): Same as the primary black, used for all running body copy. - Muted ({colors.muted} — 666666): A medium gray for secondary text, metadata, and placeholder copy. - On Primary ({colors.on-primary} — fafafc): The warm off-white text color used on the solid black primary button. - On Dark ({colors.on-dark} — fafafc): Text color for content placed over dark...

Typography rationale: Font Family The system exclusively uses Inter. Its clean, neutral geometry fits the minimalist aesthetic, and its variable font characteristics allow for precise control over weight and tracking. The most notable feature is the use of tight negative letter-spacing for all display and heading styles, which is a core part of the system's voice. Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.display-lg} | 56px | 700 | 1.07 | -1.4px | Primary hero headlines | | {typography.display-md} | 48px | 700 | 1.14 | -1px | Large section headings | | {typography.title-lg} | 32px | 600 | 1.25 | -0.6px | Standard section headings | | {typography.title-md} | 24px | 600 | 1.33 | -0.4px | Card titles, sub-section headings | | {typography.title-sm} | 20px | 500 | 1.42 | -0.24px | Subheadings, descriptive titles | | {typography.body-md} | 14px | 400 | 1.57 | -0.08px | Main body copy, descriptive text in cards | | {typography.caption} | 12px | 400 | 1.5 | 0.07px | Small metadata, labels | | {typography.button} | 15px | 600 | 1.4 | -0.12px | All button labels | | {typography.nav-link} | 15px | 500 | 1.4 | -0.12px | Top navigation links | P...

Layout system: Spacing System - Base unit: 4px. - Tokens: {spacing.xxs} 4px · {spacing.xs} 8px · {spacing.sm} 12px · {spacing.md} 16px · {spacing.lg} 24px · {spacing.xl} 32px · {spacing.xxl} 64px · {spacing.section} 96px. - Section padding (vertical): {spacing.section} (96px) is the standard gap between major content blocks, creating a spacious, breathable rhythm. - Card internal padding: {spacing.xl} (32px) is standard for all feature cards. - Gutters: {spacing.lg} (24px) between cards in multi-column grids. Grid & Container - Max content width: 1200px, centered. Full-bleed sections are used for atmospheric elements like the hero gradient. - Editorial body: Content is organized into single-column or 3-column grids. Section headings are typically flush-left, not centered. - Layouts are symmetrical: The system avoids sidebars or complex asymmetrical layouts, preferring centered stacks and uniform grids. Whitespace Philosophy The design relies heavily on whitespace to create structure and focus. The generous {spacing.section} gaps act as chapter breaks, allowing each feature or message to stand alone. This prevents the page from feeling dense, even when displaying detailed information.

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | Flat | No shadow, no border | Body sections, top navigation, text blocks | | Soft hairline | 1px {colors.hairline-on-light} | Secondary buttons, some feature cards for subtle definition | | Card surface | Faint drop shadow (rgba(0,0,0,0.08) 0px 4px 16px -8px) | Default state for {component.feature-card} | | Elevated card | Deeper faint drop shadow (rgba(0,0,0,0.08) 0px 8px 20px -7px) | Used for {component.media-frame-card} to lift it off the page | The elevation model is deliberately understated. Shadows are low-opacity and have a significant blur, making them feel like a soft lift rather than a hard layer. The goal is to create a subtle sense of depth without resorting to strong borders or heavy shadows that would disrupt the minimalist aesthetic. Decorative Depth The primary source of decorative depth is the indigo-to-sky gradient used as a full-bleed backdrop in the hero section. This creates an atmospheric, non-literal space where other elements can float.

Shape language: Border Radius Scale | Token | Value | Use | |---|---|---| | {rounded.md} | 8px | Text input fields | | {rounded.lg} | 12px | All buttons, top navigation bar CTA | | {rounded.xl} | 24px | All cards, including {component.feature-card} and {component.media-frame-card} | | {rounded.pill} | 9999px | Small status indicators or tags (rarely used) | | {rounded.full} | 9999px / 50% | Avatars, circular progress dials | The system's shape language is defined by its consistent and generous radii. The {rounded.xl} (24px) on all cards is a key signature, giving containers a soft, friendly appearance. The {rounded.lg} (12px) on buttons is similarly consistent.

Component language: Top Navigation top-nav — A 64px tall bar with a {colors.canvas-light} background. It sits flush on the canvas with no shadow or border. Contains a left-aligned text element, a centered link group in {colors.muted}, and a right-aligned {component.button-primary}. Buttons button-primary — The main call-to-action. A solid {colors.primary} (000000) background with {colors.on-primary} (fafafc) text. It has a {rounded.lg} (12px) radius and generous padding (16px 24px). Its high contrast makes it the visual anchor for user action. button-secondary-outline — A lower-emphasis button. It has a transparent background, a 1px {colors.hairline-on-light} border, and {colors.primary} text. Uses the same {rounded.lg} and {typography.button} as the primary button but with slightly tighter padding. Cards & Containers hero-gradient-band — The first-viewport container. It features a full-bleed linear gradient (indigo to sky blue) background. Content is centered and consists of a headline in {typography.display-lg}, a sub-headline in {typography.title-sm}, and a {component.button-primary}. Text is always {colors.on-dark}. media-frame-card — A container used to display media like images or videos. It ha...

Guardrails: Do - Use the {rounded.xl} (24px) radius for all m...
```
