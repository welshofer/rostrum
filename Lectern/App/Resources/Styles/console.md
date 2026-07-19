# Console

**ID:** `console`  
**Category:** consumer  
**Theme:** light  
**Vibe:** Technical

## Color palette

- `#303055`
- `#403f53`
- `#767682`
- `#a8a8b0`
- `#111111`
- `#e8e8f2`
- `#ffffff`
- `#8844ae`
- `#3b61b0`
- `#096e72`

## Typography

Families: "'IBM Plex Mono', ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace", "'Rubik Variable', ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, sans-serif". Weights: 400, 500, 600.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: SST

Design token description: A developer-terminal aesthetic wrapped in a polished product interface. The design is anchored on a two-family type system: a monospaced font for all code and technical surfaces, and a variable sans-serif for prose and UI. The palette is austere, built on a dark indigo-violet (303055) for text and headings over a pure white canvas. A soft, barely-tinted lavender-gray (e8e8f2) is the only surface accent, used for code blocks and muted UI elements. Code syntax highlighting uses a distinct, muted quartet of accent colors reserved exclusively for that context. Components are minimal and flat, favoring text-based actions and hairline borders over filled buttons and shadows.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- No dominant source-domain vocabulary was detected, but still avoid copying example subject matter from the design brief.
- Avoid brand logos, product shots, mascot imagery, packaging, buildings, people, or industry-specific objects unless requested by the slide content.

Overall visual personality: This is a design system for developers, where the configuration file becomes the art. It has a strict, clean, and text-first aesthetic built on a white canvas. The visual identity is defined by a two-family type system: Rubik Variable for all prose and UI chrome, and IBM Plex Mono for every code block, technical label, and command-line element. This typographic split is non-negotiable and defines the system's character. The color palette is austere and cool-toned. Instead of near-black, a dark indigo-violet ({colors.ink} — 303055) is used for all headings, body copy, and links, giving the interface a consistent, serious tone. The only surface color is a subtle lavender-gray ({colors.surface-soft} — e8e8f2) used for code block backgrounds and muted inputs. A quartet of muted syntax highlighting colors ({colors.code-plum}, {colors.code-cobalt}, etc.) are reserved exclusively for code and never appear in the main UI. Components are flat and minimal. There are no filled primary call-to-action buttons; instead, actions are presented as strong text links, often followed by a chevron. Elevation is used exactly once: a subtle shadow lifts the code block off the page, signifying it as the...

Color tokens:
- ink: #303055
- body: #403f53
- muted: #767682
- muted-soft: #a8a8b0
- ink-strong: #111111
- hairline: #e8e8f2
- canvas: #ffffff
- surface-soft: #e8e8f2
- code-plum: #8844ae
- code-cobalt: #3b61b0
- code-teal: #096e72
- code-rust: #984e4d

Typography tokens:
- hero-display: family 'Rubik Variable', ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, sans-serif, size 48px, weight 500, line 1.1, tracking -1.01px
- hero-display-code: family 'IBM Plex Mono', ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace, size 48px, weight 600, line 1.1, tracking -0.021em
- title-lg: family 'Rubik Variable', ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, sans-serif, size 20px, weight 600, line 1.5, tracking 0
- title-md: family 'Rubik Variable', ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, sans-serif, size 18px, weight 600, line 1.5, tracking 0
- body-md: family 'Rubik Variable', ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, sans-serif, size 14px, weight 400, line 1.8, tracking 0
- body-md-strong: family 'Rubik Variable', ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, sans-serif, size 14px, weight 500, line 1.8, tracking 0
- caption: family 'Rubik Variable', ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, sans-serif, size 12px, weight 400, line 1.5, tracking 0
- eyebrow: family 'Rubik Variable', ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, sans-serif, size 12px, weight 600, line 1.2, tracking 0.056em
- nav-link: family 'Rubik Variable', ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, sans-serif, size 14px, weight 500, line 1, tracking 0
- code-md: family 'IBM Plex Mono', ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace, size 14px, weight 400, line 1.8, tracking -0.021em
- code-md-strong: family 'IBM Plex Mono', ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace, size 14px, weight 600, line 1.8, tracking -0.021em

Spacing tokens:
- xxs: 4px
- xs: 8px
- sm: 12px
- md: 16px
- lg: 24px
- xl: 32px
- xxl: 48px
- section: 64px

Radius and shape tokens:
- xs: 2px
- sm: 4px
- md: 8px
- lg: 12px
- xl: 16px
- pill: 9999px
- full: 9999px

Component tokens:
- code-block: backgroundColor: {colors.surface-soft}, textColor: {colors.ink}, typography: {typography.code-md}, rounded: {rounded.md}, padding: 16px, borderColor: {colors.hairline}, borderWidth: 1px
- nav-button-ghost: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.nav-link}
- nav-button-ghost-muted: backgroundColor: transparent, textColor: {colors.muted}, typography: {typography.nav-link}
- text-link: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.body-md-strong}
- badge-new: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.eyebrow}, rounded: {rounded.sm}, padding: 4px 8px, borderColor: {colors.hairline}, borderWidth: 1px
- search-input: backgroundColor: {colors.surface-soft}, textColor: {colors.muted}, typography: {typography.caption}, rounded: {rounded.pill}, padding: 8px 16px
- button-secondary-pill: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.nav-link}, rounded: {rounded.pill}, padding: 6px 16px, borderColor: {colors.hairline}, borderWidth: 1px
- hero-prose-band: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.hero-display}, padding: 80px 0

Color rationale: Text & Ink - Ink ({colors.ink} — 303055): The primary text color for headings, links, and strong labels. A dark indigo-violet that replaces traditional near-black. - Body ({colors.body} — 403f53): A slightly lighter shade for running prose and paragraph copy, providing a subtle hierarchy against headings. - Muted ({colors.muted} — 767682): For helper text, secondary navigation items, and UI chrome that should recede. - Muted Soft ({colors.muted-soft} — a8a8b0): The lightest text tone, used for disabled states, subtle hints (like keyboard shortcuts), and eyebrow headings. - Ink Strong ({colors.ink-strong} — 111111): A pure black reserved for rare cases requiring maximum contrast. Surface - Canvas ({colors.canvas} — ffffff): The primary page background and surface for all content cards. - Surface Soft ({colors.surface-soft} — e8e8f2): A soft lavender-gray tint used for code block backgrounds, search inputs, and tag fills. It is the only non-white surface color. Hairlines & Borders - Hairline ({colors.hairline} — e8e8f2): The 1px border tone, identical to {colors.surface-soft}. Borders feel like subtle surface insets, not ink lines. Code Syntax This is a special-purpose palette reser...

Typography rationale: Font Family The system is built on a strict two-family hierarchy. Mixing these roles is a violation of the design language. - Rubik Variable: Used for all prose and user interface text, including headings, paragraphs, navigation, and button labels. It provides a clean, neutral voice for the product frame. - IBM Plex Mono: Used for all code, terminal commands, API identifiers, and technical labels. It provides the authentic, dense, and readable voice of a developer tool. Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.hero-display} | 48px | 500 | 1.1 | -1.01px | Primary prose headline (Rubik) | | {typography.hero-display-code} | 48px | 600 | 1.1 | -0.021em | Hero-scale code / command line (IBM Plex Mono) | | {typography.title-lg} | 20px | 600 | 1.5 | 0 | Section headings (Rubik) | | {typography.title-md} | 18px | 600 | 1.5 | 0 | Sub-section headings (Rubik) | | {typography.body-md} | 14px | 400 | 1.8 | 0 | Default running text, paragraphs (Rubik) | | {typography.body-md-strong} | 14px | 500 | 1.8 | 0 | Emphasized text, inline text links (Rubik) | | {typography.caption} | 12px | 400 | 1.5 | 0 | Helper text, footer copy...

Layout system: Spacing System - Base unit: 4px. - Tokens: {spacing.xxs} 4px · {spacing.xs} 8px · {spacing.sm} 12px · {spacing.md} 16px · {spacing.lg} 24px · {spacing.xl} 32px · {spacing.xxl} 48px · {spacing.section} 64px. - Section padding (vertical): {spacing.section} (64px) creates a clear rhythm between content bands. - Card internal padding: {spacing.md} (16px) is standard for all components with internal space, like code blocks. - Gutters: {spacing.md} (16px) between elements in a dense layout; {spacing.lg} (24px) or {spacing.xl} (32px) between unrelated horizontal elements. Grid & Container - Max content width: 1200px, center-aligned. - Hero layout: Two-column, with a code block on one side and a prose block on the other, vertically centered. - Content layout: Below the hero, content flows in single-column, max-width bands, creating a document-like reading experience. Whitespace Philosophy Whitespace is generous and used to create a calm, focused reading environment. The system avoids dense, multi-column layouts below the hero, preferring to let each section breathe. The lack of colored surfaces means that whitespace and typography are the primary tools for creating structure and hierarchy.

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | Flat | No shadow, 1px {colors.hairline} border or no border | Body sections, navigation, inputs, text links, cards | | Elevated | Faint shadow: 0 0 0 1px rgba(0,0,0,0.04), 0 4px 12px rgba(0,0,0,0.04) | Reserved exclusively for {component.code-block} | The elevation model is deliberately minimal. Depth is used only to signal that the code block is the central, tangible "product" being featured. All other UI elements are part of the flat, supportive "frame" and do not cast shadows.

Shape language: Border Radius Scale | Token | Value | Use | |---|---|---| | {rounded.sm} | 4px | Buttons, tags, inputs | | {rounded.md} | 8px | Cards, code blocks | | {rounded.pill} | 9999px | Pill-shaped controls like search bars or utility buttons | The system uses a tight radius scale to maintain a crisp, technical feel. Large, friendly radii are avoided. Imagery & Iconography The system is fundamentally imageless. The primary visual is the {component.code-block}. Any iconography is minimal, functional, and rendered in a single solid color (typically {colors.muted} or {colors.ink}). There are no photographs, illustrations, or decorative graphics.

Component language: Code & Text code-block — The centerpiece of the design. A container with a {colors.surface-soft} background, {rounded.md} corners, and a subtle drop shadow. It uses {typography.code-md} for its contents, with syntax highlighting applied via the dedicated code color palette. text-link — The system's primary action component. It is an inline text element using {typography.body-md-strong} and {colors.ink}. It does not have an underline by default and is often accompanied by a trailing chevron. hero-prose-band — The main text block in the hero section. Uses {typography.hero-display} for the headline and {typography.body-md} (with {colors.body} text) for the descriptive subtext. It has no background or border. eyebrow-heading — A small, uppercase label set in {typography.eyebrow}. Used for secondary titles or to provide context for a section, often in {colors.muted-soft}. Navigation & Buttons nav-button-ghost — The standard navigation link in the header. It is a text-only component with no background...
```
