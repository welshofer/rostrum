# Slate

**ID:** `slate`  
**Category:** consumer  
**Theme:** dark  
**Vibe:** Minimal

## Color palette

- `#0a0a0a`
- `#f7f7f7`
- `#ebebeb`
- `#7c7c7c`
- `#4d4d4d`
- `#585858`
- `#707070`
- `#616161`

## Typography

Families: "'Wand UI Pro', -apple-system, BlinkMacSystemFont, sans-serif". Weights: 400, 475, 550.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: International Magic

Design token description: A sparse, achromatic interface presented on a near-black (0a0a0a) canvas. The visual language is defined by what it removes — color, borders, and complex layouts — to create a quiet, focused gallery-like experience. Off-white type runs in a single custom geometric grotesk, characterized by tight negative tracking at display sizes. Layouts are strictly centered and single-column, with enormous vertical spacing between content blocks. Elevation is achieved with a single, large, diffuse shadow, and all interactive elements and containers use soft, high-radius corners (24px for containers, 9999px for buttons and badges).

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- Detected source-domain vocabulary: consumer technology. Translate it into reusable visual behavior, not literal imagery.
- Avoid literal source imagery unless the exact slide text or visual direction explicitly requests it: phones, laptops, tablets, device mockups, or hardware product renders; app screenshots, operating-system chrome, or product launch hero shots.

Overall visual personality: This system presents a minimal, achromatic interface on a near-black canvas ({colors.canvas-dark} — 0a0a0a). The entire experience is built on reduction: there are no chromatic accents, layouts are strictly single-column and centered, and navigation is reduced to a few text links. The visual hierarchy relies on scale and whitespace rather than color or depth. Type runs exclusively in a custom geometric grotesk, 'Wand UI Pro'. Its most distinct feature is its use of tracking: tight negative spacing (-1.632px) at large display sizes gives headlines a dense, block-like presence, while positive spacing at small sizes (+0.25px) gives captions an airy, deliberate feel. Weights are kept light; display roles use a whisper-thin 400 weight to feel quiet and atmospheric. Surfaces and interactive elements are soft and rounded. Containers use a generous {rounded.xl} (24px) radius, while all buttons and badges are fully-rounded pills ({rounded.pill}). The only depth comes from a single, large, diffuse shadow used to gently lift media containers off the dark canvas. Vertical rhythm is defined by an exceptionally large section gap ({spacing.section} — 120px), using empty space as the primary orga...

Color tokens:
- canvas-dark: #0a0a0a
- body: #f7f7f7
- body-strong: #ebebeb
- muted: #7c7c7c
- muted-strong: #4d4d4d
- hairline-on-dark: #f7f7f7
- surface-neutral: #585858
- on-neutral: #ebebeb
- badge-text: #707070
- badge-border: #616161

Typography tokens:
- hero-display: family 'Wand UI Pro', -apple-system, BlinkMacSystemFont, sans-serif, size 96px, weight 400, line 1, tracking -1.632px
- display-sm: family 'Wand UI Pro', -apple-system, BlinkMacSystemFont, sans-serif, size 32px, weight 400, line 1.25, tracking -0.384px
- body-md: family 'Wand UI Pro', -apple-system, BlinkMacSystemFont, sans-serif, size 16px, weight 400, line 1.6, tracking -0.16px
- button: family 'Wand UI Pro', -apple-system, BlinkMacSystemFont, sans-serif, size 15px, weight 475, line 1.4, tracking 0
- nav-link: family 'Wand UI Pro', -apple-system, BlinkMacSystemFont, sans-serif, size 11px, weight 550, line 1.4, tracking 0
- caption: family 'Wand UI Pro', -apple-system, BlinkMacSystemFont, sans-serif, size 10px, weight 475, line 1.4, tracking 0.25px

Spacing tokens:
- xxs: 4px
- xs: 8px
- sm: 12px
- md: 16px
- lg: 24px
- section: 120px

Radius and shape tokens:
- lg: 16px
- xl: 24px
- pill: 9999px
- full: 9999px

Component tokens:
- button-primary-ghost: backgroundColor: transparent, textColor: {colors.body-strong}, typography: {typography.button}, rounded: {rounded.pill}, padding: 8px 20px
- button-secondary-filled: backgroundColor: {colors.surface-neutral}, textColor: {colors.on-neutral}, typography: {typography.button}, rounded: {rounded.pill}, padding: 8px 24px
- top-nav: backgroundColor: transparent, textColor: {colors.body}, typography: {typography.nav-link}
- tag-badge-outlined: backgroundColor: transparent, textColor: {colors.badge-text}, typography: {typography.caption}, rounded: {rounded.pill}, padding: 4px 8px
- hero-band-dark: backgroundColor: {colors.canvas-dark}, textColor: {colors.body}, typography: {typography.hero-display}, padding: 80px 0
- media-container-elevated: backgroundColor: transparent, rounded: {rounded.xl}
- content-tile-circular: backgroundColor: transparent, rounded: {rounded.full}

Color rationale: The palette is fully achromatic, consisting of a black canvas, an off-white text color, and a few mid-grays for hierarchy. the source brand - Canvas Dark ({colors.canvas-dark} — 0a0a0a): The deep, near-black page background. It serves as the floor for all content. - the source brand Neutral ({colors.surface-neutral} — 585858): A dark gray used for the background of the single filled button variant. It is only marginally lighter than the canvas, creating a very subtle, low-contrast button. Text - Body ({colors.body} — f7f7f7): The primary off-white text color, used for headlines, body copy, and navigation links on the dark canvas. - Body Strong ({colors.body-strong} — ebebeb): A slightly warmer off-white used for the text and border of primary ghost buttons. - Muted ({colors.muted} — 7c7c7c): A mid-gray for secondary body text and de-emphasized labels. - Muted Strong ({colors.muted-strong} — 4d4d4d): A darker gray for low-emphasis headings and subtle borders. - On Neutral ({colors.on-neutral} — ebebeb): The text color for content on {colors.surface-neutral}. It reuses the {colors.body-strong} token. - Badge Text ({colors.badge-text} — 707070): A specific mid-gray for the text insid...

Typography rationale: Font Family The system uses a single custom typeface, 'Wand UI Pro', for all typographic roles. It is a geometric grotesk with humanist warmth and a tall x-height. If unavailable, Inter or General Sans are suitable open-source substitutes. The use of specific OpenType features ("ordn" on, "ss01" on) is integral to its voice. Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.hero-display} | 96px | 400 | 1.0 | -1.632px | Primary page titles, centered | | {typography.display-sm} | 32px | 400 | 1.25 | -0.384px | Section headings | | {typography.body-md} | 16px | 400 | 1.6 | -0.16px | Standard body copy, subtitles | | {typography.button} | 15px | 475 | 1.4 | 0 | All button labels | | {typography.nav-link} | 11px | 550 | 1.4 | 0 | Top navigation text links | | {typography.caption} | 10px | 475 | 1.4 | 0.25px | Small labels, outlined badges | Principles The typographic system is defined by its restraint and subtle details. - Whisper Weight: Display sizes use a light 400 weight. This is a deliberate choice to make headlines feel atmospheric and integrated with the dark canvas, rather than loud and demanding. - Dynamic Tracking...

Layout system: Spacing System - Base unit: 4px or 8px. - Tokens: {spacing.xxs} 4px · {spacing.xs} 8px · {spacing.sm} 12px · {spacing.md} 16px · {spacing.lg} 24px · {spacing.section} 120px. - Section padding (vertical): {spacing.section} (120px) is used between all major content blocks. This extreme amount of whitespace is the primary tool for creating rhythm and separation. - Card internal padding: {spacing.md} (16px) for content within media containers. - Gutters: Not applicable, as the layout is single-column. The gap between adjacent inline elements is {spacing.sm} (12px). Grid & Container - Max content width: ~640px, always centered. - Grid: There is no grid. All content is organized as a single, centered vertical stack. - Editorial body: A single column that holds all headlines, text, and media. Whitespace Philosophy The system treats whitespace as a primary design element. The generous {spacing.section} gap is non-negotiable and serves as an "invisible divider" between sections. The goal is to isolate each piece of content in its own space on the dark canvas, creating a focused, gallery-like viewing experience. Crowding elements or reducing this gap would break the core design principle.

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | Flat | No shadow, no border | Body sections, top nav, headlines, buttons, badges | | Ambient Shadow | 0px 64px 72px 0px rgba(0, 0, 0, 0.25) | A single, large, diffuse shadow applied to elevated media containers to gently lift them from the canvas. | The elevation model is extremely simple: most elements are flat. Only primary media containers receive a shadow. This shadow is soft and ambient, designed to create a sense of depth and focus without introducing hard edges or complex layers. There are no other shadows, glows, or depth effects in the system.

Shape language: Border Radius Scale | Token | Value | Use | |---|---|---| | {rounded.lg} | 16px | Smaller content containers | | {rounded.xl} | 24px | Primary media containers | | {rounded.pill} | 9999px | All buttons and badges | | {rounded.full} | 9999px / 50% | Circular content tiles (e.g., avatars) | The shape language is consistently soft and rounded. Sharp corners are avoided. The {rounded.xl} radius on containers and the {rounded.pill} shape for all interactive elements are key to making the stark, dark canvas feel approachable and refined rather than severe. Imagery & Media - Media is presented in containers with a {rounded.xl} corner radius. - Small informational tiles may be cropped into circles using {rounded.full}. - Iconography is absent. The system relies on text labels for all actions.

Component language: Top Navigation top-nav — A minimal header consisting of a few text links in a single, centered horizontal row. It has no background or border, appearing to float at the top of the canvas. Type is {typography.nav-link} in {colors.body}. Buttons button-primary-ghost — The primary action. A transparent-background pill button with a 1px border and text in {colors.body-strong}. The ghost style maintains the minimal aesthetic and doesn't interrupt the dark canvas with a solid fill. button-secondary-filled — An alternative action used when a button needs slightly more presence. It uses a {colors.surface-neutral} background fill, which is only subtly lighter than the canvas. The text is {colors.on-neutral}. Content & Containers hero-band-dark — The standard page-opening component. It contains a single, centered headline set in {typography.hero-display}. It has a transparent background and relies on the {spacing.section} whitespace above and below it for definition. tag-badge-outlined — A small, pill-shaped tag used for categorization. It is an outlined style with {colors.badge-text} text and a 1px {colors.badge-border}. The type is {typography.caption}, notable for its positive letter spa...

Guardrails: Do - Keep the entire interface achromatic. The absence of color is a defining feature. - Center-align all content within a single, narrow column. - Use {spacing.section} (120px) of vertical whitespace to separate all major content blocks. - Use {rounded.xl} (24px) for media containers and {rounded.pill} for all buttons and badges. - Apply the single ambient shadow only to primary media containers to create a focal point. - Set display headlines in a light weight (400) with tight negative letter spacing. Don't - Don't introduce any chromatic color, not even for links or hover states. - Don't create a filled, high-contrast primary button. Actions should remain subtle, using either the ghost or neutral-filled style. - Don't use sharp corners (0-8px) on any container or interactive element. - Don't reduce the vertical whitespace between s...
```
