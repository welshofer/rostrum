# Static

**ID:** `static`  
**Category:** consumer  
**Theme:** dark  
**Vibe:** Technical

## Color palette

- `#12130f`
- `#e4dfda`
- `#3c3c38`
- `#f5c2c8`

## Typography

Families: "'Arbeit Contrast', 'Inter', 'Söhne', sans-serif", "'Arbeit Technik', 'JetBrains Mono', 'IBM Plex Mono', monospace", "'Inline VF', 'Departure Mono', 'VT323', monospace". Weights: 400.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Max Yinger

Design token description: A stark, minimalist dark-theme interface that reads like an engineer's terminal. The system is built on a near-black canvas (12130f) where a single warm bone-white (e4dfda) carries all text, from large blocky displays to tiny monospaced telemetry labels. The layout is brutally compact and full-bleed, pushing content to the viewport edges with minimal spacing. A whisper of pink-coral (f5c2c8) appears as an ambient glow from a central media artifact, but is never used for UI chrome. The system's personality is driven entirely by its three-font stack: a chunky display face, a high-contrast sans-serif, and a technical monospaced font.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- No dominant source-domain vocabulary was detected, but still avoid copying example subject matter from the design brief.
- Avoid brand logos, product shots, mascot imagery, packaging, buildings, people, or industry-specific objects unless requested by the slide content.

Overall visual personality: This is a brutally compact, typography-driven system designed to feel like a midnight engineer's terminal. It operates on a near-black canvas ({colors.canvas-dark} — 12130f) where a single warm bone-white ({colors.on-dark} — e4dfda) carries all textual information. There are no secondary UI colors; the system's only other chromatic element is a soft pink ({colors.accent-glow} — f5c2c8) that bleeds from a central 3D media artifact, functioning as ambient light rather than a UI accent. The layout is full-bleed and edge-to-edge, anchoring content to the viewport's corners instead of a central container. Spacing is extremely tight ({spacing.xxs} — 4px element gaps) to create a high-density, cockpit-like feel. The system's personality is derived almost entirely from its three distinct typefaces: a blocky, compressed display font for hero moments, a high-contrast sans-serif for readable prose, and a tight, monospaced face for all telemetry-style labels and annotations. Elevation is non-existent; the entire interface is a single flat plane. Key Characteristics: - Monochromatic UI: {colors.on-dark} (e4dfda) on {colors.canvas-dark} (12130f) is the entire UI palette. All text, links, and bu...

Color tokens:
- canvas-dark: #12130f
- on-dark: #e4dfda
- hairline-on-dark: #3c3c38
- accent-glow: #f5c2c8

Typography tokens:
- hero-display: family 'Inline VF', 'Departure Mono', 'VT323', monospace, size 80px, weight 400, line 0.7, tracking 0
- display-sm: family 'Arbeit Contrast', 'Inter', 'Söhne', sans-serif, size 30px, weight 400, line 1.13, tracking 0
- body-md: family 'Arbeit Contrast', 'Inter', 'Söhne', sans-serif, size 16px, weight 400, line 1.25, tracking 0
- caption: family 'Arbeit Technik', 'JetBrains Mono', 'IBM Plex Mono', monospace, size 12px, weight 400, line 1.25, tracking -0.6px

Spacing tokens:
- xxs: 4px
- xs: 8px
- sm: 12px
- section: 64px

Radius and shape tokens:
- xs: 2px
- pill: 9999px

Component tokens:
- button-pill-ghost: backgroundColor: transparent, textColor: {colors.on-dark}, typography: {typography.caption}, rounded: {rounded.pill}, padding: 12px 20px
- text-link-underlined: backgroundColor: transparent, textColor: {colors.on-dark}, typography: {typography.body-md}, rounded: {rounded.xs}
- telemetry-label: backgroundColor: transparent, textColor: {colors.on-dark}, typography: {typography.caption}
- digital-display: backgroundColor: transparent, textColor: {colors.on-dark}, typography: {typography.hero-display}
- hero-media-artifact: backgroundColor: transparent, textColor: {colors.on-dark}
- content-cluster: backgroundColor: transparent, textColor: {colors.on-dark}, typography: {typography.body-md}

Color rationale: Core Palette - Canvas Dark ({colors.canvas-dark} — 12130f): The full-bleed page background. A warm, near-black carbon tone. - On Dark ({colors.on-dark} — e4dfda): The primary and only text color. A warm, bone-white used for all typography, from hero displays to captions to button labels. - Hairline on Dark ({colors.hairline-on-dark} — 3c3c38): A subtle, warm mid-gray for dividers or subdued borders, though rarely used as the system prefers spatial gaps for separation. Accent - Accent Glow ({colors.accent-glow} — f5c2c8): A soft, rose-quartz pink. This color is used exclusively as an ambient light source or edge-light on 3D-rendered media artifacts. It never appears on UI chrome, text, or interactive elements. Its purpose is purely atmospheric.

Typography rationale: Font Family The system relies on a three-font stack, each with a specific, non-interchangeable role: - Display Face ({typography.hero-display}): A custom, ultra-condensed font used for the largest display moments. Its tight, blocky letterforms and extremely compressed line height (0.7) are a core part of the system's identity. Substitutes include Departure Mono or VT323. - Contrast Sans-Serif ({typography.body-md}, {typography.display-sm}): The workhorse typeface for all readable prose and subheadings. It has visible contrast in its strokes, giving it authority at multiple sizes. Substitutes include Inter or Söhne. - Monospaced Face ({typography.caption}): A technical, monospaced font used for all telemetry-style labels, annotations, timestamps, and metadata. Its aggressive negative letter-spacing makes it feel stamped and precise. Substitutes include JetBrains Mono or IBM Plex Mono. Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.hero-display} | 80px | 400 | 0.7 | 0 | The largest display size for hero readouts | | {typography.display-sm} | 30px | 400 | 1.13 | 0 | Section headings | | {typography.body-md} | 16px | 40...

Layout system: Spacing System - Base unit: 4px. - Tokens: {spacing.xxs} 4px · {spacing.xs} 8px · {spacing.sm} 12px · {spacing.section} 64px. - Element Gaps: {spacing.xxs} (4px) is the default gap between lines of text in a content cluster. - Internal Padding: {spacing.sm} (12px) is used for the internal padding of any contained element, though most are uncontained. - Section Gaps: {spacing.section} (64px) provides vertical separation between major content groups on the page. Grid & Container The system eschews a traditional grid or max-width container. The layout is full-bleed and corner-anchored. Content is deliberately positioned at the edges of the viewport: - Top-left: Primary identity mark. - Bottom-left: Main content cluster and large display readouts. - Bottom-right: Secondary navigation / external links. - Center: A single, large-scale media artifact. This creates a Z-pattern flow and an expansive, immersive feel where the UI frames a central visual piece.

Depth and hierarchy: The system is flat by design. There are no box-shadows, drop-shadows, or blur effects to simulate elevation. The entire UI sits on a single plane, {colors.canvas-dark}. Depth is communicated exclusively through a single, centrally-located 3D-rendered media artifact. The illusion of space is created by this object, not by layered CSS surfaces. Separation between UI elements is achieved with tight spatial gaps ({spacing.xxs}), not borders or shadows.

Shape language: Border Radius Scale | Token | Value | Use | |---|---|---| | {rounded.xs} | 2px | Used for the subtle rounding on underlined inline links. | | {rounded.pill} | 9999px | Used for all interactive ghost buttons and tags. | The shape language is binary: interactive, button-like elements are always pills, while subtle inline links are near-square. All other containers or content blocks are sharp, with a 0px border radius. Media & Iconography The system's primary visual element is a {component.hero-media-artifact} — a 3D-rendered geometric object that floats in the center of the viewport. It is rendered in {colors.on-dark} with soft {colors.accent-glow} edge-lighting. There is no photography, illustration, or use of traditional icons; navigation and links are text-only. The visual language is one of extreme restraint, focusing on a single rendered object and typography.

Component language: Buttons & Links button-pill-ghost — The primary component for external navigation. It's a transparent pill-shaped button with {colors.on-dark} text. The typography is the small, monospaced {typography.caption}, giving it a technical feel. It has no border or fill, relying on its pill shape and context for affordance. text-link-underlined — Used for all inline links within body prose. The text inherits the {colors.on-dark} color and {typography.body-md} style. Interactivity is signaled by a 2px-thick underline of the same color. The underline itself has a {rounded.xs} radius for a soft, blocky feel. Text & Display telemetry-label — A small, all-caps label using {typography.caption}. These are used for status indicators, location markers, and section labels, functioning like annotations on a HUD. The tight, negative letter-spacing is a key part of its style. digital-display — The largest text element, used for hero readouts like a live-updating clock. It uses {typography.hero-display} for a blocky, compressed, and unapologetically digital look. Containers content-cluster — A logical grouping of text elements, such as a {component.telemetry-label} followed by a paragraph in {typograp...

Guardrails: Do - Use {colors.on-dark} for all text on the {colors.canvas-dark} background. The two-color system is foundational. - Use {rounded.pill} for all interactive button-like elements. - Maintain extremely compact spacing: {spacing.xxs} (4px) between elements in a cluster. - Use the three prescribed typefaces only for their intended roles (display, prose, labels). - Push content to the viewport edges to maintain the full-bleed, corner-anchored layout. - Use extremely compressed line-heights, especially {typography.hero-display} at 0.7. Don't - Don't introduce new colors to the UI. The {colors.accent-glow} pink exists only as a lighting effect on media, never on chrome. - Don't use box-shadows or drop-shadows. The system is intentionally flat. - Don't use line-heights above 1.25. The compressed vertical rhythm is a signature trait. - Don't center content in a main column or use a max-width container. - Don't add borders to content cards or clusters. Separation comes from spatial gaps alone. - Don't introduce additional font weights. Rely on size and typeface for hierarchy.

Reusable visual grammar extracted from DESIGN.md:
- disciplined grid construction with deliberate margins and stable alignment
- visible framing, crisp strokes, and structural linework around content groups
- softened geometry and rounded containers calibrated from the radius system
- sharp-edged architectural forms with firm boundaries and assertive hierarchy
- restrained compositions with generous negative space and high typographic confidence
- technical dashboards, calibrated readouts, fine gridlines, and annotated systems diagrams
- material texture and surface treatment applied abstractly to backgrounds and panels

Chart and infographic grammar:
- Charts must inherit the DESIGN.md palette, typography scale, stroke weight, corner radius, spacing, and grid density.
- Use branded annotations, legends, callout panels, and dividers instead of default spreadsheet styling.
- On dark palettes, render charts with luminous high-contrast lines, labels, and subtle gridlines.

Image and illustration grammar:
- Image-like areas must depict the slide topic from the slide JSON; DESIGN.md controls treatment, composition, material, color, and mood only.
- When the source design uses product or industry examples, translate them into abstract composition behaviors...
```
