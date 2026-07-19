# Obsidian

**ID:** `obsidian`  
**Category:** consumer  
**Theme:** dark  
**Vibe:** Editorial

## Color palette

- `#020202`
- `#000000`
- `#292a2c`
- `#ffffff`
- `#9b9b9b`

## Typography

Families: "OPX-Medium, Söhne, Inter, sans-serif", "Open Sans, Source Sans 3, sans-serif", "Untitled, Inter, Söhne, sans-serif". Weights: 400, 500.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: OPX Studio

Design token description: A dark, minimalist gallery aesthetic built on a near-black 020202 canvas. The system is aggressively monochrome, using only stark white ffffff type and charcoal 292a2c hairlines for structure. There are no brand or accent colors; all chromatic energy comes from full-bleed media. A custom display face scales from body text to monumental 111px headlines at a single light weight (400), creating authority through scale and tight leading rather than boldness. Components are flat and borderless, with interactivity signaled only by white-stroke pill buttons (45px radius). Generous 100-200px vertical spacing gives the layout a slow, editorial pace.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- Detected source-domain vocabulary: consumer technology. Translate it into reusable visual behavior, not literal imagery.
- Avoid literal source imagery unless the exact slide text or visual direction explicitly requests it: phones, laptops, tablets, device mockups, or hardware product renders; app screenshots, operating-system chrome, or product launch hero shots.

Overall visual personality: This system is a dark gallery monolith: a near-black exhibition hall where monumental white type and full-bleed photography do all the talking. The entire interface is built on a {colors.canvas} (020202) void. It is aggressively monochrome, with no brand color, accent color, or semantic hues (e.g., for success or error). All chromatic variation is provided by the media content itself. The primary brand signature is typography. A single custom display face, set at a light weight (400), scales from {typography.body-md} (18px) to monumental {typography.display-xl} (111px) statements. Display sizes use extremely tight leading (1.0–1.07), giving headlines a confident, monolithic presence that dominates through scale alone, not visual weight. Components are flat and borderless on the canvas, relying on {colors.hairline} (292a2c) dividers and white-stroke {component.button-pill-outline} buttons (rounded at {rounded.pill}) for structure, rather than shadows or fills. Generous vertical breathing room ({spacing.section} to {spacing.section-lg}) between sections reinforces a slow, editorial pace rather than a dense product feel. Key Characteristics: - Monochrome palette: The system uses only...

Color tokens:
- canvas: #020202
- the source brand: #000000
- hairline: #292a2c
- body: #ffffff
- muted: #9b9b9b
- on-dark: #ffffff

Typography tokens:
- display-xl: family OPX-Medium, Söhne, Inter, sans-serif, size 111px, weight 400, line 1, tracking 0
- display-lg: family OPX-Medium, Söhne, Inter, sans-serif, size 80px, weight 400, line 1.07, tracking 0
- display-md: family OPX-Medium, Söhne, Inter, sans-serif, size 50px, weight 400, line 1.38, tracking 0
- display-sm: family OPX-Medium, Söhne, Inter, sans-serif, size 35px, weight 400, line 1.4, tracking 0
- title-lg: family OPX-Medium, Söhne, Inter, sans-serif, size 26px, weight 400, line 1.42, tracking 0
- title-md: family OPX-Medium, Söhne, Inter, sans-serif, size 20px, weight 400, line 1.67, tracking 0
- body-md: family OPX-Medium, Söhne, Inter, sans-serif, size 18px, weight 400, line 1.67, tracking 0
- body-longform: family Open Sans, Source Sans 3, sans-serif, size 18px, weight 400, line 1.67, tracking 0
- button: family Untitled, Inter, Söhne, sans-serif, size 14px, weight 500, line 1.67, tracking 0
- caption: family Untitled, Inter, Söhne, sans-serif, size 14px, weight 500, line 1.67, tracking 0

Spacing tokens:
- xxs: 7px
- xs: 15px
- sm: 20px
- md: 30px
- lg: 50px
- xl: 80px
- xxl: 100px
- section: 150px
- section-lg: 200px

Radius and shape tokens:
- none: 0px
- pill: 45px

Component tokens:
- nav-link-display: backgroundColor: transparent, textColor: {colors.on-dark}, typography: {typography.title-lg}, padding: 50px 0
- hero-headline: backgroundColor: transparent, textColor: {colors.on-dark}, typography: {typography.display-xl}, padding: 200px 100px 0 100px
- project-card: backgroundColor: transparent, textColor: {colors.on-dark}, typography: {typography.title-md}, rounded: {rounded.none}
- button-pill-outline: backgroundColor: transparent, textColor: {colors.on-dark}, typography: {typography.button}, rounded: {rounded.pill}, padding: 7px 15px, border: 1px solid {colors.on-dark}
- section-heading: backgroundColor: transparent, textColor: {colors.on-dark}, typography: {typography.display-sm}
- footer-column-title: backgroundColor: transparent, textColor: {colors.on-dark}, typography: {typography.title-md}
- footer-column-body: backgroundColor: transparent, textColor: {colors.muted}, typography: {typography.body-md}
- text-link-muted: backgroundColor: transparent, textColor: {colors.muted}, typography: {typography.body-md}

Color rationale: the source brand & Canvas - Canvas ({colors.canvas} — 020202): The primary page floor. A near-black that serves as the universal background for the entire experience. - the source brand ({colors.the source brand} — 000000): Used for section bands and media containers. It's almost indistinguishable from the canvas, ensuring the elevation model remains flat and content-focused. Text - Body / On Dark ({colors.body} / {colors.on-dark} — ffffff): Stark white is used for all primary text, from headlines and navigation labels to running copy. It provides maximum contrast against the dark canvas. - Muted ({colors.muted} — 9b9b9b): A soft gray reserved for secondary metadata, helper text, and footer content. It recedes into the background, clearly separating primary from secondary information. Hairlines & Borders - Hairline ({colors.hairline} — 292a2c): The sole structural color. This dark charcoal is used for 1px dividers between sections and for the 1px border on the outline pill button. It's the only mid-tone in the system, providing subtle separation without adding visual noise.

Typography rationale: Font Family The system uses three primary font families, each with a distinct role: - OPX-Medium (sub: Söhne, Inter): The primary brand face. A custom neo-grotesque used at a single weight (400) across the entire typographic scale, from body copy to monumental display headlines. Its character is defined by its use at large sizes with very tight leading. - Open Sans (sub: Source Sans 3): A secondary humanist sans-serif used for longer descriptive passages where a more relaxed, readable rhythm is desired. - Untitled (sub: Inter, Söhne): A functional sans-serif used only for micro-copy, such as button labels and captions. It's the only font used at weight 500, giving small interactive elements a slightly stronger presence. Hierarchy | Token | Size | Weight | Line Height | Use | |---|---|---|---|---| | {typography.display-xl} | 111px | 400 | 1 | Main hero statement; monumental, tight, and arresting | | {typography.display-lg} | 80px | 400 | 1.07 | Secondary hero headlines | | {typography.display-md} | 50px | 400 | 1.38 | Large section titles | | {typography.display-sm} | 35px | 400 | 1.4 | Standard section headings | | {typography.title-lg} | 26px | 400 | 1.42 | Primary navigation lin...

Layout system: Spacing System - Base unit: An irregular, organic scale rather than a strict 4px or 8px grid. - Tokens: {spacing.xxs} 7px · {spacing.xs} 15px · {spacing.sm} 20px · {spacing.md} 30px · {spacing.lg} 50px · {spacing.xl} 80px · {spacing.xxl} 100px. - Section padding (vertical): Very generous, ranging from {spacing.section} (150px) to {spacing.section-lg} (200px). This creates a slow, deliberate editorial pacing. - Element Gaps: Inner-component spacing is typically {spacing.md} (30px), such as the gap between a card's image and its title. Grid & Container - Max content width: None. The dark canvas is edge-to-edge, bleeding to the viewport sides. - Content alignment: Internal text blocks maintain a generous left padding of 50–100px, but there is no fixed container. - Grid structure: Major content areas use simple structures, like a 3-column grid for project listings and a 3-column layout for the footer. Whitespace Philosophy The system's philosophy is monolithic and sparse. Huge swaths of the {colors.canvas} are left empty to frame the content. This negative space is as important as the typography and imagery, creating a feeling of a large, quiet gallery space. The system trusts this ge...

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | Flat | No shadow, no border, no fill | All content sits directly on the canvas. Titles, paragraphs, and media blocks. | | Hairline | 1px solid {colors.hairline} | The only layering tactile material surface. Used for full-width horizontal rules separating major sections. | | Outline | 1px solid {colors.on-dark} | Used exclusively for the border of the {component.button-pill-outline} to signal interactivity. | The elevation philosophy is aggressively flat. The system deliberately avoids box-shadows, gradients, or any other effect that would create a sense of Z-axis depth. All components exist on the same plane. Separation is achieved horizontally through whitespace and structurally through the use of thin {colors.hairline} dividers.

Shape language: Border Radius Scale | Token | Value | Use | |---|---|---| | {rounded.none} | 0px | All media containers and cards. Imagery is always presented with sharp, 90-degree corners. | | {rounded.pill} | 45px | Exclusively for interactive elements like the {component.button-pill-outline}. The large, fixed radius creates a soft, pill-like shape that contrasts with the hard edges of the media. | The shape language is a study in contrasts: hard-edged, rectangular containers for static content and soft, rounded shapes for interactive controls. Photography & Iconography - Media is always presented full-bleed within its container, with {rounded.none} corners. The content of the media provides all the color and texture for the system. - There are no icons. Navigation and interactive labels are purely typographic. The system trusts the clarity of the text and its context to communicate function.

Component language: Navigation & Headers nav-link-display — A primary navigation item. Set in {typography.title-lg} using {colors.on-dark} text. It has no background or underline; it is a purely typographic element, relying on its large size and placement to signify its role. hero-headline — The main opening statement. Uses {typography.display-xl} with its characteristic tight leading, rendered in {colors.on-dark}. It sits within generous padding ({spacing.section-lg} at the top) on the empty canvas. section-heading — A standard heading for a content section. Set in {typography.display-sm}. Buttons & Links button-pill-outline — The only button style in the system. It has a transparent background, a 1px solid border in {colors.on-dark}, and text in {typography.button}. Its shape is defined by its {rounded.pill} (45px) radius and tight padding. text-link-muted — An inline link, typically found in the footer. It uses {typography.body-md} and {colors.muted} text, with no underline. It may change to {colors.on-dark} on interaction. Cards & Containers project-card — A container for a single project in a grid. It has no visible background or border; it is simply a full-bleed media area at the top, followed...

Guardrails: Do - Use {typography.display-xl} at weight 400 with a line-height of 1.0 for all primary hero statements. - Use the 1px {colors.hairline} as the only divider between major sections. - Construct all CTAs as {component.button-pill-outline} with a {rounded.pill} radius. No filled buttons. - Let all media fill its container edge-to-edge with {rounded.none...
```
