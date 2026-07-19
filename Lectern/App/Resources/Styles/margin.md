# Margin

**ID:** `margin`  
**Category:** consumer  
**Theme:** light  
**Vibe:** Minimal

## Color palette

- `#000000`
- `#a3a3a3`
- `#e5e7eb`
- `#ffffff`

## Typography

Families: "'Neue Haas Unica Pro', Inter, -apple-system, BlinkMacSystemFont, sans-serif". Weights: 400.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: DNCO

Design token description: A radically minimalist editorial design anchored on a bright white canvas. Hierarchy is built exclusively with scale, not weight — a single sans-serif typeface at a single 400-weight runs from 16px to 72px. The palette is purely achromatic: white (ffffff), black (000000), and a light gray (e5e7eb) for hairlines. All interactive elements like navigation links and filter chips are pill-shaped (9999px radius), while content containers and images are sharp-cornered (0px radius). There are no shadows or gradients; depth is conveyed solely through generous whitespace and whisper-thin hairlines. The system's only major color inversion is a full-bleed black hero surface.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- No dominant source-domain vocabulary was detected, but still avoid copying example subject matter from the design brief.
- Avoid brand logos, product shots, mascot imagery, packaging, buildings, people, or industry-specific objects unless requested by the slide content.

Overall visual personality: This is a system of radical typographic restraint. It operates on a single sans-serif typeface at a single weight (400) deployed across a dramatic scale, anchored on an entirely achromatic palette of white, off-white, and pure black. The interface reads like an editorial print spread — headlines breathe against generous whitespace, borders are whisper-thin hairlines ({colors.hairline} — e5e7eb), and the only color comes from photography, never from UI chrome or accent fills. Navigation and interactive elements are either plain text or pill-shaped ({rounded.pill}), while all content containers like image tiles are sharp-cornered ({rounded.none}). The design language is minimal, weightless, and border-driven rather than shadow-driven. There is zero elevation; depth is created exclusively by whitespace and the occasional hairline divider. The aesthetic is that of a gallery catalogue, not a feature-rich application. Key Characteristics: - Monotypographic: One font family, one weight (400). Hierarchy is built purely through size and tracking, not weight contrast. - Achromatic Palette: The UI uses only {colors.canvas-light} (white), {colors.ink} (black), {colors.hairline} (light gray),...

Color tokens:
- ink: #000000
- body: #000000
- muted: #a3a3a3
- hairline: #e5e7eb
- canvas-light: #ffffff
- canvas-dark: #000000
- surface-muted: #e5e7eb
- on-dark: #ffffff

Typography tokens:
- hero-display: family 'Neue Haas Unica Pro', Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 72px, weight 400, line 1, tracking -1.8px
- title-lg: family 'Neue Haas Unica Pro', Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 22px, weight 400, line 1.33, tracking -0.55px
- body-md: family 'Neue Haas Unica Pro', Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 18px, weight 400, line 1.56, tracking -0.45px
- body-sm: family 'Neue Haas Unica Pro', Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 16px, weight 400, line 1.5, tracking -0.4px
- nav-link: family 'Neue Haas Unica Pro', Inter, -apple-system, BlinkMacSystemFont, sans-serif, size 16px, weight 400, line 1.5, tracking -0.4px

Spacing tokens:
- xxs: 4px
- xs: 12px
- sm: 14px
- md: 16px
- lg: 24px
- xl: 48px
- xxl: 64px
- section: 64px

Radius and shape tokens:
- none: 0px
- pill: 9999px
- full: 9999px

Component tokens:
- hero-band-dark-inverted: backgroundColor: {colors.canvas-dark}, textColor: {colors.on-dark}, typography: {typography.hero-display}, padding: 0
- top-nav: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.nav-link}, height: 64px
- page-headline: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.hero-display}
- filter-text-list: backgroundColor: transparent, textColor: {colors.muted}, typography: {typography.body-sm}
- filter-text-active: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.body-sm}
- media-tile: backgroundColor: {colors.surface-muted}, rounded: {rounded.none}
- text-link: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.body-sm}
- media-grid-card: backgroundColor: transparent, padding: 0, rounded: {rounded.none}

Color rationale: The palette is strictly achromatic, containing only four neutral tones. Surface - Canvas Light ({colors.canvas-light} — ffffff): The default page background and primary surface for all content blocks. - Canvas Dark ({colors.canvas-dark} — 000000): Used for the full-bleed inverted hero band, providing a dramatic entry point before transitioning to the white canvas. - Surface Muted ({colors.surface-muted} — e5e7eb): A light gray fill used for placeholder states, such as a missing image in a grid. Hairlines & Borders - Hairline ({colors.hairline} — e5e7eb): The single tone for all 1px dividers. Used to separate major content sections where whitespace alone is insufficient. Text - Ink ({colors.ink} — 000000): The primary text color for headlines, active links, and body copy on the light canvas. - On Dark ({colors.on-dark} — ffffff): White text used exclusively over the {colors.canvas-dark} hero surface. - Muted ({colors.muted} — a3a3a3): Secondary text for captions, inactive filter labels, and helper text.

Typography rationale: Font Family The system uses a single sans-serif typeface for all UI elements: navigation, body, and headlines. The recommended font is Neue Haas Unica Pro, with Inter as a suitable open-source substitute. Hierarchy The system enforces a single weight (400) for all text. Hierarchy is achieved solely through dramatic jumps in font size and disciplined use of negative tracking. | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.hero-display} | 72px | 400 | 1.0 | -1.8px | Primary page headlines and inverted hero text | | {typography.title-lg} | 22px | 400 | 1.33 | -0.55px | Section subheadings | | {typography.body-md} | 18px | 400 | 1.56 | -0.45px | Main running-text for editorial content | | {typography.body-sm} | 16px | 400 | 1.5 | -0.4px | Captions, footer text, filter labels | | {typography.nav-link} | 16px | 400 | 1.5 | -0.4px | Top navigation items | Principles - Single Weight: Bold or light font weights are forbidden. Emphasis is created by increasing size or using whitespace, not by changing weight. - Tight Tracking: All type roles use negative letterSpacing. This is a non-negotiable characteristic that contributes to the ref...

Layout system: Spacing System - Base unit: 4px. - Tokens: {spacing.xxs} 4px · {spacing.xs} 12px · {spacing.sm} 14px · {spacing.md} 16px · {spacing.lg} 24px · {spacing.xl} 48px · {spacing.xxl} 64px · {spacing.section} 64px. - Section padding (vertical): {spacing.section} (64px) is used to separate major content blocks. - Gutters: {spacing.lg} (24px) is used for gaps between grid items and between navigation links. Grid & Container - Max content width: A generous ~1400px, centered. - Editorial body: A wide single-column or 2-column grid with flush-left alignment. Content often bleeds to the edge of the content area. - Media grids: 2- or 3-column equal-width grids for presenting imagery. Whitespace Philosophy The system is defined by its generous use of whitespace. Content is never constrained in heavy containers; instead, it floats on the white canvas, with grouping and hierarchy implied by proximity and spacing. Whitespace is the primary tool for creating structure and focus.

Depth and hierarchy: The system has zero elevation. No component uses box-shadow, drop-shadow, or blur effects. Depth is created exclusively through two mechanisms: 1. Whitespace: Generous gaps between elements create a sense of separation and layering. 2. Hairlines: A 1px {colors.hairline} divider is the only permitted graphic element for separating sections. The design philosophy is explicitly flat. Any attempt to add shadows to cards, buttons, or modals would violate the core principles of the system.

Shape language: Border Radius Scale The shape language is binary and strict. | Token | Value | Use | |---|---|---| | {rounded.none} | 0px | All content containers, image tiles, cards, inputs. | | {rounded.pill} | 9999px | Interactive text-based elements like navigation links and filter chips. | | {rounded.full} | 9999px | Reserved for purely circular elements, if any were to be introduced. | Media & Iconography - Media: Images are the only source of color. They are always presented without frames, borders, or rounded corners, bleeding directly into the layout. Placeholder images use a solid {colors.surface-muted} fill. - Iconography: The system avoids iconography. State and actions are communicated typographically, such as a small filled circle (•) to indicate an active navigation item.

Component language: Navigation & Headers hero-band-dark-inverted — A full-bleed opening section with a {colors.canvas-dark} background. It contains a single, large typographic element set in {typography.hero-display} and {colors.on-dark}. There is no padding; the text sits at the viewport edge. top-nav — A minimal, floating navigation bar on a transparent background. It consists of a horizontal row of text links styled with {typography.nav-link}. The active item is indicated by a small filled circle beneath the label, not by a color change. page-headline — A large, flush-left headline using {typography.hero-display}. It sits directly on the white canvas with no max-width constraint, creating a powerful editorial statement. Content & Grids media-tile — A raw image element with {rounded.none}. It has no border, shadow, or caption overlay. It serves as the basic unit for project grids. media-grid-card — The container for a media-tile in a grid. It has a transparent background and no padding; the image is the entire card. Spacing between cards is handled by the grid's gutter. Interactive Elements filter-text-list — A vertical list of plain text labels used for filtering. Inactive items use {colors.muted}...

Guardrails: Do - Use the single specified typeface at weight 400 exclusively. Never introduce other weights. - Set all type with tight negative letter-spacing to maintain the editorial feel. - Use only the four specified neutral colors for all UI chrome. - Build hierarchy through size jumps, not through weight or color shifts. - Separate sections with 1px {colors.hairline} dividers or generous whitespace. - Make interactive elements pills ({rounded.pill}) and containers sharp ({rounded.none}). - Let photography be the sole source of color, bleeding into the layout without frames. Don't - Do not add a second typeface family. The system is monotypographic by design. - Do not introduce any chromatic color to the UI. - Do not use box-shadows or any other elevation effects. - Do not add border-radius to cards, images, or content containers. - Do not use bold or italic styling for emphasis; increase size instead. - Do not place content inside bordered or filled panels; use whitespace to group elements. - Do not use background colors for buttons or interactive states.

Reusable visual grammar extracted from DESIGN.md:
- disciplined grid construction with deliberate margins and stable alignment
- visible framing, crisp strokes, and structural linework around content groups
- softened geometry and rounded containers calibrated from the radius system
- sharp-edged architectural forms with firm boundaries and assertive hierarchy
- restrained compositions with generous negative space and high typographic confidence
- approachable color beats, simple geometry, and lively but controlled rhyth...
```
