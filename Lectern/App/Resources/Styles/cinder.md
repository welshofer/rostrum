# Cinder

**ID:** `cinder`  
**Category:** consumer  
**Theme:** dark  
**Vibe:** Minimal

## Color palette

- `#f45500`
- `#ffffff`
- `#9e9eff`
- `#9d9d9d`
- `#000000`
- `#202020`
- `#eaeaea`

## Typography

Families: "'GT-Flexa', sans-serif", "'Times', serif", "'Tobias-light', sans-serif". Weights: 200, 400.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Electronic Materials Office

Design token description: A nocturnal, atmospheric interface built on a matte charcoal canvas (202020), where a single incandescent orange ember (f45500) serves as the primary call-to-action. Typography is the main expressive tool - display headlines float in an ultra-light weight 200 of a geometric sans-serif, creating a sense of breath and space, while body copy grounds the experience in a traditional serif. A desaturated violet (9e9eff) is used for all secondary actions and links. The system is defined by its restraint, rationing color and using a consistent, soft 20px radius for all containers and interactive elements. Depth is achieved not with shadows, but with two distinct color 'glows' reserved exclusively for the primary and secondary buttons.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- No dominant source-domain vocabulary was detected, but still avoid copying example subject matter from the design brief.
- Avoid brand logos, product shots, mascot imagery, packaging, buildings, people, or industry-specific objects unless requested by the slide content.

Overall visual personality: This system evokes a nocturnal, atmospheric gallery where typography and a single accent color do all the expressive work. The entire interface is built on a matte charcoal canvas ({colors.canvas-dark} — 202020), which is deliberately not pure black to allow for soft edge definition. Color is severely rationed: pure white ({colors.body}) for all text, a single incandescent orange ember ({colors.primary} — f45500) for the primary call-to-action, and a desaturated violet ({colors.accent} — 9e9eff) for all inline links and secondary outline buttons. The defining characteristic is its typography. A geometric sans-serif (GT-Flexa) is used for display headlines at an ultra-light weight 200. At large sizes ({typography.hero-display}), the letterforms feel ambient and atmospheric rather than declarative. A secondary architectural sans-serif (Tobias-light) with tight negative letter-spacing is used for section labels, creating a contrasting "labeled" voice. All body copy is set in a traditional serif (Times), a deliberate choice to add editorial gravity and warmth. The system is uniformly flat, with card surfaces matching the canvas color. Edges are defined by 1px hairlines, not shadows. T...

Color tokens:
- primary: #f45500
- body: #ffffff
- accent: #9e9eff
- muted: #9d9d9d
- hairline: #9d9d9d
- on-primary: #ffffff
- on-light: #000000
- canvas-dark: #202020
- surface-card-dark: #202020
- surface-light: #eaeaea

Typography tokens:
- hero-display: family 'GT-Flexa', sans-serif, size 86px, weight 200, line 1.0, tracking 0
- display-lg: family 'GT-Flexa', sans-serif, size 68px, weight 200, line 1.06, tracking 0
- display-md: family 'Tobias-light', sans-serif, size 42px, weight 400, line 1.2, tracking -2.6px
- display-sm: family 'Tobias-light', sans-serif, size 32px, weight 400, line 1.2, tracking -1.5px
- title-lg: family 'GT-Flexa', sans-serif, size 28px, weight 400, line 1.2, tracking 0
- title-md: family 'GT-Flexa', sans-serif, size 26px, weight 400, line 1.2, tracking 0
- title-sm: family 'GT-Flexa', sans-serif, size 24px, weight 400, line 1.2, tracking 0
- body-md: family 'Times', serif, size 16px, weight 400, line 1.2, tracking 0
- button: family 'GT-Flexa', sans-serif, size 16px, weight 400, line 1, tracking 0
- nav-link: family 'GT-Flexa', sans-serif, size 16px, weight 400, line 1.2, tracking 0

Spacing tokens:
- xxs: 4px
- xs: 8px
- sm: 16px
- md: 24px
- lg: 48px
- xl: 128px
- section: 128px

Radius and shape tokens:
- md: 20px
- lg: 20px
- pill: 20px

Component tokens:
- button-primary: backgroundColor: {colors.primary}, textColor: {colors.on-primary}, typography: {typography.button}, rounded: {rounded.pill}, padding: 1px 16px
- button-secondary: backgroundColor: transparent, textColor: {colors.body}, typography: {typography.button}, rounded: {rounded.pill}, padding: 1px 16px, border: 1px solid {colors.body}
- button-tertiary-outline: backgroundColor: transparent, textColor: {colors.accent}, typography: {typography.nav-link}, rounded: {rounded.pill}, padding: 8px 16px, border: 1px solid {colors.accent}
- text-link: backgroundColor: transparent, textColor: {colors.accent}, typography: {typography.nav-link}
- media-card: backgroundColor: {colors.surface-card-dark}, textColor: {colors.body}, rounded: {rounded.lg}, border: 1px solid {colors.hairline}
- feature-card: backgroundColor: {colors.surface-card-dark}, textColor: {colors.body}, typography: {typography.title-sm}, rounded: {rounded.lg}, padding: 24px, border: 1px solid {colors.hairline}
- play-button-overlay: backgroundColor: {colors.body}, textColor: {colors.on-light}, typography: {typography.button}, rounded: {rounded.pill}, padding: 8px 16px
- top-nav: backgroundColor: transparent, textColor: {colors.body}, typography: {typography.nav-link}, height: auto

Color rationale: Brand & Accent - Ember Orange ({colors.primary} — f45500): The single, incandescent brand color. Used exclusively for the background of the primary CTA ({component.button-primary}). Its power comes from its scarcity. - Lavender Accent ({colors.accent} — 9e9eff): The secondary, cool-toned accent. Used for all inline links ({component.text-link}) and outlined tertiary buttons ({component.button-tertiary-outline}). It provides a quiet, desaturated counterpoint to the warm primary orange. Surface - Canvas Dark ({colors.canvas-dark} — 202020): The floor of the entire UI. A near-black charcoal that allows for softer edge perception than pure 000000. - Surface Card Dark ({colors.surface-card-dark} — 202020): The background for all cards and containers. It is identical to the canvas color, meaning cards are defined by their borders, not by a color shift. - Surface Light ({colors.surface-light} — eaeaea): A light off-white used for rare inverted panels or modal dialogs. Hairlines & Borders - Hairline ({colors.hairline} — 9d9d9d): The default 1px border tone used on cards and media containers. - White Border ({colors.body} — ffffff): A brighter 1px border used on the secondary "ghost" butto...

Typography rationale: Font Family The system uses a deliberate three-font hierarchy to create distinct voices: - GT-Flexa: A geometric sans-serif used for display headlines and smaller UI text. Its signature is the use of weight 200 for large-scale type. - Tobias-light: An architectural sans-serif used exclusively for section-heading labels, always with tight negative letter-spacing. - Times: A classic serif used only for body copy, providing a warm, editorial feel. Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.hero-display} | 86px | 200 | 1.0 | 0 | The largest display type, for main page headlines | | {typography.display-lg} | 68px | 200 | 1.06 | 0 | Secondary large headlines | | {typography.display-md} | 42px | 400 | 1.2 | -2.6px | Section labels (Tobias-light) | | {typography.display-sm} | 32px | 400 | 1.2 | -1.5px | Sub-section labels (Tobias-light) | | {typography.title-lg} | 28px | 400 | 1.2 | 0 | Large card titles | | {typography.title-md} | 26px | 400 | 1.2 | 0 | Medium card titles | | {typography.title-sm} | 24px | 400 | 1.2 | 0 | Small card titles and captions | | {typography.body-md} | 16px | 400 | 1.2 | 0 | All running body...

Layout system: Spacing System - Base unit: 4px. - Tokens: {spacing.xxs} 4px · {spacing.xs} 8px · {spacing.sm} 16px · {spacing.md} 24px · {spacing.lg} 48px · {spacing.xl} 128px. - Section padding (vertical): {spacing.xl} (128px) is used to create generous breathing room between major content blocks. The system relies on this negative space for separation. - Card internal padding: {spacing.md} (24px) for feature cards. Media cards often have no internal padding, with imagery bleeding to the edges. - Gutters: {spacing.md} (24px) between cards in grid layouts. Grid & Container - Max content width: ~1200px, centered on the page. - Layout: Typically a single-column layout for hero content, followed by 2-up or 3-up card grids for features. There is no sidebar or complex multi-column structure. Whitespace Philosophy The system's aesthetic is defined by generous negative space. The {colors.canvas-dark} is not just a background color but an active compositional element. Large vertical gaps ({spacing.section}) between sections replace traditional dividers, forcing the user to focus on one content block at a time. This minimalist approach heightens the impact of the spare typography and single color accent.

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | Flat | No shadow, 1px {colors.hairline} border | All cards, media containers, and page sections. | | Primary Glow | 0 0 30px 0 rgba(245, 86, 0, 0.6) | The {component.button-primary} exclusively. This makes the button appear to be a light source. | | Secondary Glow | 0 0 30px 0 rgba(255, 255, 255, 0.3) | The {component.button-secondary} exclusively. A softer, monochrome echo of the primary glow. | The elevation model is intentionally flat. Depth is not communicated through layered surfaces or drop shadows. Instead, it is an optical effect reserved for the two main CTAs, which appear to glow from within. All other elements are defined by crisp, 1px hairline borders on the same charcoal plane as the canvas.

Shape language: Border Radius Scale The system uses a single, uniform radius value for all elements. | Token | Value | Use | |---|---|---| | {rounded.md} | 20px | Standard radius for all cards, containers, and media frames. | | {rounded.lg} | 20px | Alias for the standard radius. | | {rounded.pill} | 20px | The radius for all buttons, creating a "soft pill" or "stadium" shape. | This strict adherence to a single 20px radius is a core principle. It ensures a soft, cohesive, and gentle aesthetic across the entire interface. No element uses a smaller, sharper radius. Photography & Iconography - Imagery is treated as a primary visual element, often bleeding to the edges of its {rounded.lg} container with no internal padding. - The system is largely icon-free to maintain its minimalist, typographic focus. The only notable iconographic element might be a small geometric shape used as a prefix or list marker.

Component language: Buttons button-primary — The signature "ember" CTA. It has a {colors.primary} background with {colors.on-primary} text. Its shape is a low, wide pill ({rounded.pill} with 1px vertical padding) and it is always accompanied by a 30px orange glow effect, making it the focal point of any screen. Limited to one instance per view. button-secondary — A "ghost" button that acts as a monochrome echo of the primary. It uses a transparent background, a 1px {colors.body} border, and is surrounded by a subtle white glow. button-tertiary-outline — The standard action for navigation or non-critical tasks. It uses a {colors.accent} 1px border and text color, with no glow effect. text-link — Standard inline links, rendered in {colors.accent} with no underline. Cards & Containers media-card — A simple container for video or imagery. It shares the same {colors.canvas-dark} background as the page, defined by a {colors.hairline} border and {rounded.lg} corners. It often contains a {component.play-button-overlay}. feature-card — Used in grids to display distinct features. These cards have internal padding ({spacing.md}) for text content below an image area, which typically bleeds to the top edges of th...

Guardrails: Do - Use {typography.hero-display} at weight 200 for all major headlines. This atmospheric type treatment is...
```
