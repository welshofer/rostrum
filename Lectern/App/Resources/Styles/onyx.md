# Onyx

**ID:** `onyx`  
**Category:** consumer  
**Theme:** dark  
**Vibe:** Editorial

## Color palette

- `#000000`
- `#131313`
- `#ffffff`
- `#afafaf`

## Typography

Families: "Neue Haas Grotesk TP 55 Roman, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, sans-serif". Weights: 400.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Chaiboy

Design token description: A black-box gallery aesthetic built on a pure black (000000) canvas where nearly everything is typographic and almost nothing is decorative. The interface behaves like a museum wall, framing content with hairline white (ffffff) rules and small uppercase navigation. Color is rejected; hierarchy is built entirely through type size, generous negative space, and the stark contrast of white on black. A single sans-serif typeface at a single weight (400) produces a disciplined, all-caps voice that reads more like a printed art monograph than a digital interface. Every UI element is a text fragment, with a single 4px radius as the system's only concession to softness.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- No dominant source-domain vocabulary was detected, but still avoid copying example subject matter from the design brief.
- Avoid brand logos, product shots, mascot imagery, packaging, buildings, people, or industry-specific objects unless requested by the slide content.

Overall visual personality: The system presents a black-box gallery aesthetic: a single dark canvas ({colors.canvas} — 000000) where nearly everything is typographic and almost nothing is decorative. The interface behaves like a museum wall—a large monochrome photograph or piece of content dominates the viewport, framed by hairline white ({colors.hairline} — ffffff) rules and small uppercase navigation. Color is rejected as a tool; hierarchy is built entirely through type size, generous negative space, and the stark contrast of white on black. The single typeface, Neue Haas Grotesk TP 55 Roman, is used exclusively at weight 400. This deliberate anti-hierarchy choice means scale and spacing do the work that weight normally would. The OpenType 'case' feature is enabled system-wide, giving all-caps text properly designed uppercase-sensitive forms. Every UI element—nav links, buttons, cart, footer—is a text fragment. There are no fills, no shadows, no gradients, and no rounded chrome; a single 4px radius ({rounded.md}) is the system's only concession to softness. Key Characteristics: - Strictly Monochromatic: The palette is black, white, and a single gray. There is no brand accent color. White ({colors.body}) se...

Color tokens:
- canvas: #000000
- surface-card: #131313
- body: #ffffff
- on-dark: #ffffff
- on-primary: #000000
- muted: #afafaf
- hairline: #ffffff
- primary: #ffffff

Typography tokens:
- display: family Neue Haas Grotesk TP 55 Roman, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, sans-serif, size 54px, weight 400, line 0.89, tracking 0
- subheading: family Neue Haas Grotesk TP 55 Roman, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, sans-serif, size 18px, weight 400, line 1.27, tracking 0
- body-md: family Neue Haas Grotesk TP 55 Roman, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, sans-serif, size 14px, weight 400, line 1.29, tracking 0
- caption: family Neue Haas Grotesk TP 55 Roman, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, sans-serif, size 11px, weight 400, line 1.11, tracking 0

Spacing tokens:
- xxs: 4px
- xs: 8px
- sm: 10px
- md: 16px
- lg: 42px
- xl: 60px
- xxl: 78px
- section: 60px

Radius and shape tokens:
- md: 4px

Component tokens:
- announcement-bar: backgroundColor: {colors.canvas}, textColor: {colors.body}, typography: {typography.caption}
- primary-nav: backgroundColor: {colors.canvas}, textColor: {colors.body}, typography: {typography.body-md}
- bordered-chip-button: backgroundColor: {colors.canvas}, textColor: {colors.body}, typography: {typography.caption}, rounded: {rounded.md}, padding: 6px 8px
- text-link: backgroundColor: transparent, textColor: {colors.body}, typography: {typography.body-md}
- footer-bar: backgroundColor: {colors.canvas}, textColor: {colors.body}, typography: {typography.caption}
- hero-band: backgroundColor: {colors.canvas}, textColor: {colors.body}, typography: {typography.display}

Color rationale: Brand & Accent The system is intentionally monochromatic and has no brand or accent color. {colors.primary} (ffffff) is used for all primary text and interactive elements. Surface - Canvas ({colors.canvas} — 000000): The absolute page ground. Page canvas, hero background, footer background are all pure black. - Surface Card ({colors.surface-card} — 131313): A subtle, near-black surface variation for the rare case where a lifted element is needed without breaking the monochrome aesthetic. Hairlines & Borders - Hairline ({colors.hairline} — ffffff): The 1px solid white rule used to frame media and separate all major layout regions (header, footer, announcement bar). Text - Body ({colors.body} — ffffff): Primary text, navigation links, button text, and all other forward-facing type. Also used for borders. - Muted ({colors.muted} — afafaf): Secondary text, placeholder text, and any labels that must visually recede.

Typography rationale: Font Family The system uses Neue Haas Grotesk TP 55 Roman for all interface text. There is no secondary or display typeface. The fallback stack is ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif. Hierarchy Hierarchy is built exclusively from four font sizes, all at weight 400. Bold and italic are not used. | Token | Size | Weight | Line Height | Use | |---|---|---|---|---| | {typography.display} | 54px | 400 | 0.89 | Primary page headlines | | {typography.subheading} | 18px | 400 | 1.27 | Section titles | | {typography.body-md} | 14px | 400 | 1.29 | Main navigation, body copy, text links | | {typography.caption} | 11px | 400 | 1.11 | Announcement bar, footer links, small labels | Principles - Single Weight: The exclusive use of weight 400 is a core constraint. Scale and negative space are the only tools for creating emphasis. - All Caps: All UI chrome—navigation, buttons, links, captions, footers—is set in uppercase. The OpenType font-feature-settings: 'case' on is used to ensure proper typographic forms for case-sensitive punctuation and numerals. - Tight Leading on Display: The {typography.display} style uses an extremely tight line he...

Layout system: Spacing System - Base unit: 4px. - Tokens: {spacing.xxs} 4px · {spacing.xs} 8px · {spacing.sm} 10px · {spacing.md} 16px · {spacing.lg} 42px · {spacing.xl} 60px · {spacing.xxl} 78px · {spacing.section} 60px. - Section padding (vertical): {spacing.section} (60px) separates the few major content blocks on a page. - Internal padding: {spacing.md} (16px) is a common value for internal padding within components. - Gutters: Link spacing is typically around {spacing.md} (16px). Grid & Container - Full-bleed: The page is one continuous black canvas with no max-width container. - Centered Content: A single, large content element (typically an image) is centered horizontally, occupying 60-70% of the viewport width, leaving deep black gutters on either side. - Single Column: The layout is strictly single-column. There are no multi-column grids or card layouts. Whitespace Philosophy The system is austere and uses generous negative space to create focus. The black canvas is the primary tool for separation. Regions are delineated by 1px hairlines rather than padded, colored bands, which preserves the feeling of a single, unified surface.

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | Flat | No shadow, no border | The default state for all text and UI elements | | Hairline Rule | 1px solid {colors.hairline} border | Defines the boundary of layout regions (header, footer) and frames for media | | Surface Lift | {colors.surface-card} background | A near-black background for rare cases where a surface must be distinct from the canvas | The system intentionally avoids all traditional depth cues. There are no box-shadows, glows, or layered surfaces with varying opacity. The visual hierarchy is carried entirely by typographic scale, negative space, and the 1px white hairline that separates the few defined regions.

Shape language: Border Radius Scale The system uses a single border radius. There is no graduated scale. | Token | Value | Use | |---|---|---| | {rounded.md} | 4px | Small interactive chips, tags, and inputs | All larger containers and layout regions use sharp 90-degree corners. The single 4px radius is a small, deliberate detail, not a foundational shape language. Media & Iconography - Media: Editorial imagery is presented within a simple frame, edged by a 1px {colors.hairline} border that reads as a gallery frame. Media is typically monochrome and high-contrast. - Iconography: The system avoids iconography. Navigation and actions are communicated with text labels (e.g., "CART" instead of a bag icon).

Component language: Announcement Bar announcement-bar — A full-bleed black bar at the top of the page, separated by a 1px {colors.hairline} bottom border. Contains a scrolling marquee of text set in {typography.caption}. May contain {component.bordered-chip-button} components. Primary Navigation primary-nav — Sits on the black canvas with a 1px {colors.hairline} rule above and below. All text is set in {typography.body-md}, uppercase, and colored {colors.body}. Layout is typically three-part: a text-based brand mark left, centered nav links, and a cart link right. Links & Buttons text-link — The standard interactive element for navigation and actions. It is bare uppercase text in {colors.body}. There is no underline or color change on hover; affordance is provided by context and the cursor. bordered-chip-button — The system's only "button" with defined chrome. Used for micro-CTAs inside the {component.announcement-bar}. It features a transparent background, a 1px solid {colors.hairline} border, and a {rounded.md} radius. Text is {typography.caption}. Hero & Content Frame A single large, full-bleed band that acts as the page's focal point. It contains a primary content element, typically a large monoc...

Guardrails: Do - Use {colors.canvas} (000000) as the page background everywhere. - Set all interface text in Neue Haas Grotesk TP 55 Roman at weight 400 only, with font-feature-settings: 'case' on. - Use only the four documented font sizes to build hierarchy. - Use {colors.body} (ffffff) for primary text, hairline rules, and borders. Use {colors.muted} (afafaf) only when a label must visibly recede. - Keep all border-radius at 4px. This is the system's only radius. - Let editorial media carry the visual weight; the UI chrome should be nearly invisible. - Separate major regions (header, footer) with a 1px solid {colors.hairline} rule. Don't - Do not introduce any chromatic color. The system is monochromatic by conviction. - Do not use font-weight above 400, and do not use italics. - Do not use box-shadow, gradients, or glow effects. Surfaces are flat. - Do not use a border-radius larger than 4px. Pills and fully rounded shapes are outside this system. - Do not use backgrounds or fills on navigation links or primary buttons. The bordered chip is the only component with a visible border. - Do not underline links or change their color on hover.

Reusable visual grammar extracted from DESIGN.md:
- disciplined grid construction with deliberate margins and stable alignment
- visible framing, crisp strokes, and structural linework around content groups
- softened geometry and rounded containers calibrated from the radius system
- sharp-edged architectural forms with firm boundaries and assertive hierarchy
- editorial pacing with strong headline moments, image fields, and magazine-like hierarchy

Chart and infographic grammar:
- Charts must inherit the DESIGN.m...
```
