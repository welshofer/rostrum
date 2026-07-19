# Atelier

**ID:** `atelier`  
**Category:** consumer  
**Theme:** light  
**Vibe:** Editorial

## Color palette

- `#000000`
- `#808080`
- `#ffffff`
- `#f7f7f7`
- `#e8e8e8`
- `#dec39d`

## Typography

Families: "'Gestura Text', 'Cormorant Garamond', serif", "'Untitled Sans', 'Inter', sans-serif". Weights: 100, 200, 400.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: AATHER

Design token description: An austere, editorial interface rendered in near-total monochrome on a stark white canvas. Black ink, whisper-thin typography at weights 100–200, and generous letter-spacing create a visual language that recedes, allowing full-bleed photography to carry all emotional weight and warmth. A single sand tone (dec39d) appears as a soft surface accent, but never as a UI color. Components are elemental: text links with thin underlines replace buttons, and corners are kept to a sharp 2px radius, reinforcing a quiet, print-inspired luxury.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- No dominant source-domain vocabulary was detected, but still avoid copying example subject matter from the design brief.
- Avoid brand logos, product shots, mascot imagery, packaging, buildings, people, or industry-specific objects unless requested by the slide content.

Overall visual personality: This system renders an editorial, almost invisible interface designed to elevate photography as the primary medium. The core aesthetic is austere monochrome: a pure white canvas ({colors.canvas-light} — ffffff), black ink ({colors.ink} — 000000), and light gray hairlines ({colors.hairline-on-light} — e8e8e8). There is no chromatic UI palette; all warmth and color are delivered exclusively through full-bleed, sharp-cornered photography. The brand's signature is its use of ultra-light typography, with weights rarely exceeding 200. A light serif (Gestura Text) carries editorial copy, while a geometric sans (Untitled Sans) is used for UI labels with generous letter-spacing, giving it an engraved, typeset quality. The layout is spacious and print-inspired, with a centered navigation masthead and single-column text blocks separated by wide gaps or thin hairlines. Components are reduced to their elemental forms. Most notably, there are no filled, rectangular buttons; all calls-to-action are rendered as simple underlined text links. The entire system is flat, with a universal sharp corner radius of {rounded.sm} (2px), reinforcing a feeling of quiet, architectural luxury. Key Characteristi...

Color tokens:
- ink: #000000
- body: #000000
- muted: #808080
- canvas-light: #ffffff
- surface-soft-light: #f7f7f7
- hairline-on-light: #e8e8e8
- accent-sand: #dec39d
- on-dark: #ffffff

Typography tokens:
- display-lg: family 'Gestura Text', 'Cormorant Garamond', serif, size 35px, weight 200, line 1.2, tracking 0px
- display-md: family 'Untitled Sans', 'Inter', sans-serif, size 24px, weight 400, line 1.2, tracking 1px
- title-lg: family 'Gestura Text', 'Cormorant Garamond', serif, size 20px, weight 200, line 1.35, tracking 0px
- body-lg: family 'Untitled Sans', 'Inter', sans-serif, size 16px, weight 200, line 1.38, tracking 0.6px
- body-md: family 'Gestura Text', 'Cormorant Garamond', serif, size 14px, weight 100, line 1.22, tracking 0.36px
- button: family 'Untitled Sans', 'Inter', sans-serif, size 14px, weight 200, line 1.22, tracking 0.5px
- nav-link: family 'Untitled Sans', 'Inter', sans-serif, size 14px, weight 200, line 1.3, tracking 0.5px
- caption: family 'Untitled Sans', 'Inter', sans-serif, size 11px, weight 200, line 1.3, tracking 0.5px
- caption-sm: family 'Untitled Sans', 'Inter', sans-serif, size 9px, weight 200, line 0.8, tracking 0.5px

Spacing tokens:
- xxs: 4px
- xs: 8px
- sm: 12px
- md: 24px
- lg: 32px
- xl: 40px
- xxl: 60px
- section: 80px

Radius and shape tokens:
- xs: 2px
- sm: 2px
- md: 2px
- lg: 2px
- xl: 2px
- pill: 2px
- full: 9999px

Component tokens:
- announcement-bar: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.caption}, height: 32px
- top-nav: backgroundColor: {colors.canvas-light}, textColor: {colors.ink}, typography: {typography.nav-link}, padding: 15px 0
- hero-band: backgroundColor: transparent, textColor: {colors.on-dark}, typography: {typography.display-lg}
- text-link: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.button}
- cookie-consent-bar: backgroundColor: {colors.canvas-light}, textColor: {colors.ink}, typography: {typography.caption}, padding: 12px 24px
- image-feature-band: backgroundColor: transparent, padding: 32px 0

Color rationale: Core Palette - Ink ({colors.ink} — 000000): The primary text color for headings, body copy, links, and UI labels. - Paper ({colors.canvas-light} — ffffff): The default page background and card surface. It is a pure, un-tinted white. - On Dark ({colors.on-dark} — ffffff): White text used for captions overlaid on dark photography. Neutrals - Mist ({colors.surface-soft-light} — f7f7f7): A subtle off-white used for alternate section backgrounds to create separation without a hard line. - Ash ({colors.hairline-on-light} — e8e8e8): The lightest gray, used for faint hairline dividers, such as the border on the cookie consent bar. - Graphite ({colors.muted} — 808080): A mid-gray for secondary text and low-emphasis metadata. Accent - Warm Sand ({colors.accent-sand} — dec39d): A single warm, sand-toned color. This is an environmental color, not a UI color. It should only appear within photography or as a background for an image-led section, never as a fill for buttons, links, or text.

Typography rationale: Font Family The system employs a dual-family approach common in editorial design: - Serif (Gestura Text): Used for primary editorial content, including display headlines ({typography.display-lg}) and running body copy ({typography.body-md}). Its ultra-light weights (100-200) are a defining feature. Cormorant Garamond is a suitable open-source substitute. - Sans-serif (Untitled Sans): A geometric sans used for all UI chrome, including navigation, button-like text links, and captions. It is always set with generous letter-spacing to feel airy and typeset. Inter Light is a suitable substitute. Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.display-lg} | 35px | 200 | 1.2 | 0 | Hero overlay headlines (Serif) | | {typography.display-md} | 24px | 400 | 1.2 | 1px | Section headings (Sans-serif) | | {typography.title-lg} | 20px | 200 | 1.35 | 0 | Subheadings (Serif) | | {typography.body-lg} | 16px | 200 | 1.38 | 0.6px | Larger body copy, nav links (Sans-serif) | | {typography.body-md} | 14px | 100 | 1.22 | 0.36px | Default running text (Serif) | | {typography.button} | 14px | 200 | 1.22 | 0.5px | Underlined text-link CTAs (S...

Layout system: Spacing System - Base unit: 4px. - Tokens: {spacing.xxs} 4px · {spacing.xs} 8px · {spacing.sm} 12px · {spacing.md} 24px · {spacing.lg} 32px · {spacing.xl} 40px · {spacing.xxl} 60px · {spacing.section} 80px. - Section padding (vertical): Large gaps of {spacing.section} (80px) or more separate major content blocks, creating a slow, editorial rhythm. - Card internal padding: The system avoids traditional "cards." When content is grouped, it uses internal padding of {spacing.md} (24px). - Gutters: Gaps between elements are typically {spacing.sm} (12px) to {spacing.md} (24px). Grid & Container - Max content width: ~1200px for centered text content. - Full-bleed imagery: Hero and feature images break the container and span the full viewport width. - Grid structure: Primarily a single-column, centered layout for text. Multi-column grids are used for product listings but maintain generous whitespace. Whitespace Philosophy The system uses whitespace as a primary design tool. Layouts are sparse and uncluttered. The generous vertical spacing forces a slow reading pace, similar to a high-end magazine. Content blocks are separated by empty space or a single, faint hairline rule, never by heavy...

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | Flat | No shadow, no border | Default for all page content, text, and image blocks. | | Hairline | 1px {colors.hairline-on-light} or {colors.ink} | Used to separate distinct zones (e.g., footer, cookie bar) or to frame full-bleed images. | | Focus | (Not specified) | Assumed to be a browser-default ring or a subtle underline change. | The elevation model is completely flat. There are no drop shadows, glows, or any effects used to simulate depth. The design reads as a single, printed plane. Hierarchy is achieved through typography, scale, and whitespace, not elevation.

Shape language: Border Radius Scale | Token | Value | Use | |---|---|---| | {rounded.sm} | 2px | The single, universal radius for any element with rounded corners. | The system is defined by its sharp, architectural corners. Most elements, especially full-bleed images, use a 0px radius. Where a radius is applied, it is a minimal {rounded.sm} (2px). Introducing larger or pill-shaped radii would violate the system's core aesthetic. Photography & Iconography - Photography: The primary expressive tool. Images are always sharp-cornered and often full-bleed. The content is atmospheric, focusing on texture, light, and form. - Iconography: Extremely minimal. Limited to essential UI glyphs like a cart icon or dropdown carets, rendered as simple, 1px strokes in {colors.ink}.

Component language: Navigation & Headers announcement-bar — A thin, full-width strip at the very top of the page. It has no background color and contains a single line of centered promotional text styled with {typography.caption}. top-nav — The main site navigation. It has a transparent background and uses a three-column layout: left-aligned menu links, a centered wordmark, and right-aligned utility icons (e.g., cart). This "masthead" style is a direct reference to print editorial design. Link typography is {typography.nav-link}. Content Bands hero-band — A full-viewport-width image that serves as the site's introduction. It has no color overlay. A single headline in {typography.display-lg} with color {colors.on-dark} is typically positioned in the lower third of the image. image-feature-band — A full-bleed image used to break up text-heavy sections. It is typically framed by a 1px hairline rule in {colors.ink} above and below. Calls-to-Action text-link — The system's primary and only call-to-action component. It is not a button. It consists of a line of text styled with {typography.button} in {colors.ink}, with a persistent 1px solid bottom border of the same color. It has no background fill, no ext...

Guardrails: Do - Use typographic weights of 100 or 200 for almost all text. Reserve 400 for rare emphasis. - Apply generous letter-spacing to all sans-serif UI text to achieve the signature "typeset" feel. - Use the {component.text-link} with a 1px underline for all calls-to-action. - Maintain a strict 2px border-radius ({rounded.sm}) on the few elements that are not sharp-cornered. - Rely on photography to provide all color, warmth, and brand mood. Keep the UI strictly monochrome. - Separate content sections with ample whitespace or a single, thin hairline rule. Don't - Do not introduce filled, rectangular buttons. The underlined text link is the only CTA pattern. - Do not use bold or semibold weights (500+). This would break the delicate, airy aesthetic. - Do not add drop shadows, glows, or any other elevation effects. Surfaces must remain flat. - Do not use a border-radius larger than 2px. Avoid pill shapes entirely. - Do not apply the {colors.accent-sand} color to any UI element (text, backgrounds, borders). It is for photography only. - Do not add gradients, textures, or noise to backgrounds. The canvas must feel like flat, clean paper.

Reusable visual grammar extracted from DESIGN.md:
- disciplined grid construction with deliberate margins and stable alignment
- visible framing, crisp strokes, and structur...
```
