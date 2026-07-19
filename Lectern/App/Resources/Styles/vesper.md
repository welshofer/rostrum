# Vesper

**ID:** `vesper`  
**Category:** consumer  
**Theme:** dark  
**Vibe:** Editorial

## Color palette

- `#dbc9ff`
- `#bc994e`
- `#271a47`
- `#000000`
- `#ffffff`

## Typography

Families: "Inter, sans-serif", "Sang Bleu, Cormorant Garamond, serif". Weights: 400, 600, 700.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: EPIC Agency

Design token description: A nocturnal creative-agency interface that evokes a violet observatory with gilded instruments. The design is built on a deep aubergine canvas (271a47), where a pale, high-contrast lavender (dbc9ff) carries all primary type, interactive elements, and iconography. A secondary brushed-gold accent (bc994e) adds a warm metallic counterpoint. Type is a study in contrasts: a colossal-scale, high-contrast display serif carries editorial headlines, while a utilitarian sans-serif handles all working surfaces at compact sizes. The layout is dense and magazine-like, using flat surfaces and color contrast rather than shadows to create depth.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- No dominant source-domain vocabulary was detected, but still avoid copying example subject matter from the design brief.
- Avoid brand logos, product shots, mascot imagery, packaging, buildings, people, or industry-specific objects unless requested by the slide content.

Overall visual personality: This is a nocturnal creative-agency design language, styled as a "violet observatory with gilded instruments." The entire interface is built upon a deep aubergine canvas ({colors.canvas} — 271a47) that functions as an infinite night-sky backdrop. A single pale lavender ({colors.primary} — dbc9ff) serves as the high-contrast signal color for all typography, interactive elements, iconography, and hairlines. A secondary brushed-gold ({colors.accent} — bc994e) is used sparingly as a "jewelry" accent for secondary links and decorative details. The typography is a system of extreme contrasts. A custom high-contrast display serif (substitute: Cormorant Garamond) is used at colossal sizes ({typography.hero-display} at 120px) for editorial headlines, giving pages a magazine-cover gravitas. A utilitarian sans-serif (Inter) handles all working surfaces—body copy, navigation, buttons, and labels—at compact sizes with generous letter-spacing on uppercase labels. Layouts are dense and magazine-like, stacking content in a single editorial column. The system is deliberately flat, with no drop shadows or gradients. Depth is expressed entirely through the color contrast between the lavender text/ic...

Color tokens:
- primary: #dbc9ff
- accent: #bc994e
- canvas: #271a47
- surface-media: #000000
- body-on-dark: #dbc9ff
- on-primary-fill: #271a47
- hairline: #dbc9ff
- on-dark: #ffffff

Typography tokens:
- hero-display: family Sang Bleu, Cormorant Garamond, serif, size 120px, weight 400, line 1, tracking 0
- display-lg: family Sang Bleu, Cormorant Garamond, serif, size 80px, weight 400, line 1, tracking 0
- display-md: family Sang Bleu, Cormorant Garamond, serif, size 42px, weight 700, line 1.2, tracking 0
- title-lg: family Inter, sans-serif, size 18px, weight 400, line 1.7, tracking 0
- title-md: family Inter, sans-serif, size 16px, weight 400, line 1.7, tracking 0
- body-md: family Inter, sans-serif, size 14px, weight 400, line 1.65, tracking 0.5px
- button: family Inter, sans-serif, size 14px, weight 600, line 1, tracking 1.5px
- label: family Inter, sans-serif, size 11px, weight 600, line 1, tracking 1.2px
- tagline: family Inter, sans-serif, size 11px, weight 600, line 1, tracking 5.5px
- caption: family Inter, sans-serif, size 10px, weight 600, line 1, tracking 0.4px

Spacing tokens:
- xxs: 4px
- xs: 6px
- sm: 10px
- md: 15px
- lg: 20px
- xl: 32px
- xxl: 50px
- section: 80px

Radius and shape tokens:
- md: 10px
- pill: 30px
- full: 9999px

Component tokens:
- button-primary-ghost: backgroundColor: transparent, textColor: {colors.primary}, typography: {typography.button}, rounded: {rounded.pill}, padding: 12px 20px
- button-primary-ghost-active: backgroundColor: {colors.primary}, textColor: {colors.on-primary-fill}, rounded: {rounded.pill}, padding: 12px 20px
- pill-selector: backgroundColor: transparent, textColor: {colors.primary}, typography: {typography.label}, rounded: {rounded.pill}, padding: 4px 14px
- top-nav: backgroundColor: transparent, textColor: {colors.primary}, typography: {typography.tagline}, padding: 20px 0
- list-item-journal: backgroundColor: transparent, textColor: {colors.primary}, typography: {typography.body-md}, padding: 20px 0
- media-container: backgroundColor: {colors.surface-media}, rounded: {rounded.md}
- play-button-circular: backgroundColor: {colors.canvas}, textColor: {colors.on-dark}, typography: {typography.caption}, rounded: {rounded.full}, height: 80px

Color rationale: Brand & Primary - Primary Lavender ({colors.primary} — dbc9ff): The foundational signal color. Used for all body text, display headlines, button borders and text, icons, and hairlines. Its high contrast (13.8:1) against the dark canvas is the system's structural backbone. - Accent Gold ({colors.accent} — bc994e): A warm, metallic gold used sparingly for secondary text links and decorative icon accents. It provides a warm counterpoint to the cool violet/lavender palette. Surface - Canvas ({colors.canvas} — 271a47): The base page background. A deep, rich aubergine violet that serves as the "night sky" for all other elements. - Surface Media ({colors.surface-media} — 000000): Pure black, used exclusively for media containers (e.g., video players). These blocks are designed to create hard, rectangular voids that punch through the violet canvas. Text - Body on Dark ({colors.body-on-dark} — dbc9ff): The default running text color is the same as the primary lavender. - On Primary Fill ({colors.on-primary-fill} — 271a47): Used for text when a component's background fills with the primary color (e.g., on a hovered ghost button). The text inverts to the canvas color. - On Dark ({colors.on-d...

Typography rationale: Font Family The system uses a strict two-typeface hierarchy to create dramatic contrast: - Display Serif (e.g., Sang Bleu, substitute with Cormorant Garamond): The editorial voice. Used only for large-scale headlines ({typography.display-md} and larger) to provide a magazine-like quality. - Workhorse Sans-Serif (Inter): The utilitarian voice. Used for all other UI elements, including body text, navigation, buttons, labels, and captions. Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.hero-display} | 120px | 400 | 1 | 0 | Primary hero headline | | {typography.display-lg} | 80px | 400 | 1 | 0 | Large display headline | | {typography.display-md} | 42px | 700 | 1.2 | 0 | Section-level heading | | {typography.title-lg} | 18px | 400 | 1.7 | 0 | Large subheading | | {typography.title-md} | 16px | 400 | 1.7 | 0 | Small subheading or list item title | | {typography.body-md} | 14px | 400 | 1.65 | 0.5px | Default running text | | {typography.button} | 14px | 600 | 1 | 1.5px | Uppercase button labels | | {typography.label} | 11px | 600 | 1 | 1.2px | Uppercase section eyebrow labels | | {typography.tagline} | 11px | 600 | 1 | 5.5...

Layout system: Spacing System - Base unit: The system uses an irregular but compact scale. - Tokens: {spacing.xxs} 4px · {spacing.xs} 6px · {spacing.sm} 10px · {spacing.md} 15px · {spacing.lg} 20px · {spacing.xl} 32px · {spacing.xxl} 50px. - Section padding (vertical): {spacing.section} (80px) is used between major content blocks. - Card internal padding: {spacing.lg} (20px) is the standard for content cards. - Gutters: {spacing.sm} (10px) is used for gaps between smaller, related elements. Grid & Container - Max content width: ~1200px, centered. - Editorial body: Content stacks in a single vertical column, favoring an editorial, magazine-like flow over a multi-column grid. The hero section may use an asymmetric two-thirds/one-third split for a main visual and a sidebar. Whitespace Philosophy The system is dense and information-rich. Whitespace is used as a controlled luxury to frame key content blocks, not as a general cushion. The deep violet canvas acts as negative space, allowing the high-contrast lavender elements to feel structured even with tight vertical rhythms.

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | 0 (Canvas) | {colors.canvas} flat background | The base page floor; the "night sky" that defines the entire interface. | | 1 (Media) | {colors.surface-media} flat background | Media containers (video players) that sit directly on the canvas, creating a hard, rectangular void. | The elevation philosophy is strictly flat. Depth is conveyed through color contrast and layering, not through shadows, blurs, or gradients. Lavender elements "float" on the violet canvas due to their high value contrast. Black media containers "punch through" the canvas, creating a sense of negative space and depth.

Shape language: Border Radius Scale | Token | Value | Use | |---|---|---| | {rounded.md} | 10px | Static content containers, such as media players or image cards. | | {rounded.pill} | 30px | All interactive elements: buttons, tags, and pill-shaped selectors. | | {rounded.full} | 9999px | Circular elements, like a play button. | The shape language is binary: soft rectangles ({rounded.md}) for static containers and pronounced pills ({rounded.pill}) for anything interactive. This creates a clear visual distinction between what is content and what is an action. Iconography & Imagery - Imagery is primarily 3D-rendered, not photographic. Illustrations feature a soft, studio-lit style with a color palette that complements the main UI. These visuals sit as self-contained vignettes on the canvas. - Icons are minimal, line-style glyphs rendered in {colors.primary}.

Component language: Buttons button-primary-ghost — The primary CTA is an outlined pill button. It has a transparent background, a 1px solid border in {colors.primary}, and text in {colors.primary}. It uses {typography.button} (uppercase with wide tracking) and {rounded.pill}. On hover (button-primary-ghost-active), the background fills with {colors.primary} and the text inverts to {colors.on-primary-fill}. Navigation & Selectors top-nav — A simple, transparent bar that sits over the main canvas. It contains navigation links and a {component.pill-selector}. A 1px {colors.hairline} (often at low opacity) runs full-width below the nav as a subtle divider. pill-selector — A smaller variant of the ghost button, used for UI controls like a language switcher. It shares the same transparent background, primary-colored border, and {rounded.pill} shape, but uses the smaller {typography.label}. Lists & Containers list-item-journal — A row for a vertical list of entries. Each row has vertical padding ({spacing.lg}) and is separated by a low-opacity {colors.hairline}. Text content uses a mix of {typography.title-md} for titles and {typography.label} for metadata. media-container — A full-bleed container for video...

Guardrails: Do - Use the display serif (or its substitute) for any headline at {typography.display-md} size or larger. The serif voice is the system's editorial signature. - Set all body, nav, and label text in the specified sans-serif, applying the prescribed wide letter-spacing to all uppercase labels. - Apply {rounded.pill} (30px) to all interactive elements (buttons, pills, tags) to maintain the consistent shape language. - Use {colors.primary} as the default text and interactive color on the {colors.canvas} background. - Layer {colors.surface-media} blocks directly on the canvas to create hard rectangular voids for media. - Keep the vertical rhythm compact: {spacing.sm} between elements, {spacing.lg} for card padding, and {spacing.section} between major sections. Don't - Do not introduce drop shadows or blur for elevation. The design system is delib...
```
