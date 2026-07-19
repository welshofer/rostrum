# Void

**ID:** `void`  
**Category:** consumer  
**Theme:** dark  
**Vibe:** Minimal

## Color palette

- `#000000`
- `#ffffff`
- `#5a5a5a`

## Typography

Families: "PolySans, -apple-system, BlinkMacSystemFont, sans-serif". Weights: 400.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Minimal Collective

Design token description: A pitch-black editorial canvas (000000) where every element earns its presence through restraint rather than decoration. A single geometric sans-serif at weight 400 — never heavier — carries all hierarchy; even 77px display headlines use compressed letter-spacing (-4.31px) to pull letters into sculptural, almost overlapping forms. The interface is colorlessly austere — true black as the void, hairline white (ffffff) borders as the only structural language, and bordered category pills that function as ghost labels. Content arrives as an overlapping photographic mosaic layered against the black field without shadows, gradients, or card elevation.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- No dominant source-domain vocabulary was detected, but still avoid copying example subject matter from the design brief.
- Avoid brand logos, product shots, mascot imagery, packaging, buildings, people, or industry-specific objects unless requested by the slide content.

Overall visual personality: The system operates as a pitch-black editorial canvas ({colors.canvas} — 000000) where every element earns its presence through restraint. A single geometric sans-serif, PolySans, at weight 400 — never heavier — carries all hierarchy. Scale is the only tool for emphasis; even 77px display headlines ({typography.hero-display}) whisper instead of shout, with letter-spacing compressed to create sculptural, almost overlapping forms. The interface is colorlessly austere: true black as the void, hairline white ({colors.hairline} — ffffff) borders as the only structural language, and bordered category pills that function as ghost labels rather than UI affordances. Content arrives as an overlapping photographic mosaic — images are layered against the black field without shadows, gradients, or card elevation to separate them from the canvas. The aesthetic is closer to a contemporary art publication or gallery wall than a typical product UI. Key Characteristics: - Monochromatic palette: Black canvas ({colors.canvas}), white text ({colors.body}), and a single gray for muted details ({colors.muted}). There are no accent colors. - Single-weight typography: All text uses PolySans at fontWeight:...

Color tokens:
- canvas: #000000
- body: #ffffff
- muted: #5a5a5a
- hairline: #ffffff
- on-dark: #ffffff

Typography tokens:
- hero-display: family PolySans, -apple-system, BlinkMacSystemFont, sans-serif, size 77px, weight 400, line 0.9, tracking -4.31px
- display-lg: family PolySans, -apple-system, BlinkMacSystemFont, sans-serif, size 50px, weight 400, line 1, tracking -2.2px
- display-sm: family PolySans, -apple-system, BlinkMacSystemFont, sans-serif, size 32px, weight 400, line 1, tracking -1.18px
- title-lg: family PolySans, -apple-system, BlinkMacSystemFont, sans-serif, size 27px, weight 400, line 1.2, tracking -0.86px
- title-md: family PolySans, -apple-system, BlinkMacSystemFont, sans-serif, size 23px, weight 400, line 1.2, tracking -0.67px
- title-sm: family PolySans, -apple-system, BlinkMacSystemFont, sans-serif, size 18px, weight 400, line 1.2, tracking -0.36px
- body-md: family PolySans, -apple-system, BlinkMacSystemFont, sans-serif, size 16px, weight 400, line 1.43, tracking 0
- caption: family PolySans, -apple-system, BlinkMacSystemFont, sans-serif, size 14px, weight 400, line 1.43, tracking 0

Spacing tokens:
- xxs: 5px
- xs: 9px
- sm: 14px
- md: 18px
- lg: 45px
- xl: 54px
- xxl: 144px
- section: 173px

Radius and shape tokens:
- xs: 0px
- sm: 4.5px

Component tokens:
- top-nav: backgroundColor: {colors.canvas}, textColor: {colors.body}, typography: {typography.caption}, height: 46px, padding: 14px 0
- hero-band: backgroundColor: {colors.canvas}, textColor: {colors.on-dark}, typography: {typography.hero-display}
- category-badge: backgroundColor: transparent, textColor: {colors.body}, typography: {typography.caption}, rounded: {rounded.sm}, padding: 5px 6px
- image-card: backgroundColor: {colors.canvas}, rounded: {rounded.xs}
- article-card: backgroundColor: {colors.canvas}, textColor: {colors.body}, typography: {typography.body-md}
- hairline-divider: backgroundColor: {colors.hairline}, height: 1px

Color rationale: The palette is strictly monochromatic, consisting of only three values to create a high-contrast, text-and-image-focused environment. Surface - Canvas ({colors.canvas} — 000000): The universal page background. All components, text, and images are placed directly on this true-black field. Text & Hairlines - Body ({colors.body} — ffffff): The primary text color for all content, from display headlines to body copy. It is also used for hairline borders and outlines. Same token as {colors.on-dark} and {colors.hairline}. - Muted ({colors.muted} — 5a5a5a): A mid-tone gray used for secondary structural elements, subtle input borders, and decorative linework.

Typography rationale: Font Family The system relies exclusively on PolySans (or a substitute like Inter or Satoshi) for all text. The defining characteristic is its single-weight discipline: every text element uses fontWeight: 400. Hierarchy is a function of scale and tracking, never weight. Hierarchy Display sizes use tight line heights (0.9–1.0) and aggressive negative letter-spacing to create a unique visual texture. Body copy relaxes to a more legible lineHeight: 1.43. | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.hero-display} | 77px | 400 | 0.9 | -4.31px | Primary hero headlines, often overlaid on imagery | | {typography.display-lg} | 50px | 400 | 1.0 | -2.2px | Secondary display headlines | | {typography.display-sm} | 32px | 400 | 1.0 | -1.18px | Large article titles, section heads | | {typography.title-lg} | 27px | 400 | 1.2 | -0.86px | Standard article titles | | {typography.title-md} | 23px | 400 | 1.2 | -0.67px | Small titles overlaid on images | | {typography.title-sm} | 18px | 400 | 1.2 | -0.36px | Subheadings, editorial metadata | | {typography.body-md} | 16px | 400 | 1.43 | 0 | Default running-text for articles and descriptions | |...

Layout system: Spacing System - Base unit: Irregular, favoring editorial rhythm over a strict mathematical grid. - Tokens: {spacing.xxs} 5px · {spacing.xs} 9px · {spacing.sm} 14px · {spacing.md} 18px · {spacing.lg} 45px · {spacing.xl} 54px · {spacing.xxl} 144px · {spacing.section} 173px. - Section padding (vertical): Very generous, using {spacing.xxl} (144px) or {spacing.section} (173px) to create clear separation between content blocks. - Card internal padding: {spacing.md} (18px) for content cards where they exist. - Gutters: {spacing.sm} (14px) between adjacent elements within a component. Grid & Container - Max content width: None. The layout is full-bleed, extending to the viewport edges. - Grid: The system avoids a rigid column grid, opting for an asymmetric, layered mosaic of image cards. Where structure appears (e.g., article layouts), it is often a simple two-column split. - Overlap: Image cards frequently overlap by 10–30px to create a sense of collage and depth without using shadows. Whitespace Philosophy The system treats whitespace as a primary design element. The generous {spacing.section} gaps between editorial blocks are as important as the typography. This "less is more" approac...

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | Flat | No shadow, no border, {colors.canvas} background | The entire interface: page canvas, all text, all cards | | Overlap | One flat card positioned partially over another | The sole method for creating a Z-axis relationship | | Hairline | 1px {colors.hairline} stroke | Used on "ghost" components like category badges to define their shape | Elevation is entirely absent by design. Spatial relationships emerge from photographic overlap and positional offset — never from shadow, glow, or surface tint. The {colors.canvas} is treated as a single infinite plane; cards, images, and text all sit on it directly. This preserves the "gallery wall" metaphor: works are pinned to a black plane, not stacked in a UI.

Shape language: Border Radius Scale | Token | Value | Use | |---|---|---| | {rounded.xs} | 0px | All image cards, content blocks, and major containers. | | {rounded.sm} | 4.5px | Small interactive elements: category badges and buttons. | The shape language is defined by a strict dichotomy: sharp, 0px corners for all content containers to maintain an editorial, print-like tension, and a subtle 4.5px radius exclusively for small, interactive "UI" elements to soften their touch points.

Component language: Navigation top-nav — A persistent, full-width header bar with a {colors.canvas} background. It is minimal, containing only essential navigation links. Vertical padding is {spacing.sm} (14px). Hero hero-band — A full-viewport {colors.canvas} block with a single, large headline set in {typography.hero-display}. The text often overlaps a large background image, creating a layered, atmospheric introduction. Faint decorative linework in {colors.muted} may radiate in the background. Badges & Cards category-badge — A "ghost pill" used for taxonomy labels. It has a transparent background, a 1px {colors.hairline} border, and text set in uppercase {typography.caption}. Padding is tight (5px 6px) and corners are softened with {rounded.sm}. image-card — The primary content container. It is a full-bleed photograph with {rounded.xs} (0px) corners, no border, and no shadow. These cards are layered in a mosaic, often overlapping each other to build a collage. article-card — A layout pattern, not a contained component. It combines a large {component.image-card} with a metadata row (date, category badges) and a large title set in {typography.display-sm} or {typography.title-lg}. All elements sit di...

Guardrails: Do - Use {colors.canvas} as the sole page background; never introduce a surface tint or gradient. - Set every text element to fontWeight: 400. Create hierarchy only through size and letter-spacing. - Apply negative letter-spacing that is proportional to font size, especially for display styles. - Keep all image cards and content blocks at {rounded.xs} (0px). - Layer photographs directly on the canvas with no drop shadow. Let overlap create spatial relationships. - Build category labels as "ghost pills" with a 1px {colors.hairline} border and transparent fill. - Maintain generous section gaps ({spacing.xxl} or {spacing.section}) between content blocks. Don't - Don't introduce any chromatic color. The palette is strictly black, gray, and white. - Don't use bold or semibold font weights. - Don't add box-shadows, glows, or any other elevation effects. - Don't round image cards or photographs. {rounded.sm} is reserved for small badges only. - Don't center or justify body text. Left-align all editorial copy. - Don't fill buttons or badges with a solid color. They must remain outlined. - Don't add decorative icons to components. Typography is the only interface element.

Reusable visual grammar extracted from DESIGN.md:
- disciplined grid construction with deliberate margins and stable alignment
- visible framing, crisp strokes, and structural linework around content groups
- softened geometry and rounded containers calibrated from the radius system
- sharp-edged architectural forms with firm boundaries and assertive hierarchy
- restrained compositions with generous negative space and high typographic confidence
- editorial pacing with strong headline moments, image fields, and magazine-like hierarchy
- material texture and surface treatment applied abstractly to background...
```
