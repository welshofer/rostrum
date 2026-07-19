# Terracotta

**ID:** `terracotta`  
**Category:** consumer  
**Theme:** light  
**Vibe:** Bold

## Color palette

- `#ff1a00`
- `#e7a196`
- `#0a0a0a`

## Typography

Families: "GT Pressura, ui-sans-serif, system-ui, sans-serif", "Monument Grotesk, ui-sans-serif, system-ui, sans-serif". Weights: 400.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Signal Flare

Design token description: A brutalist broadcast interface anchored on a sun-baked clay canvas (e7a196), where a single, urgent red-orange (ff1a00) carries every interactive element, text block, icon, and border. Type is the primary interface, running a monolithic neo-grotesque stack at a single weight (400), with hierarchy established entirely through a dramatic scale from 12px to 245px. Display sizes use extreme negative letter-spacing, compressing characters until they almost touch. The system is entirely flat, with no cards, shadows, gradients, or rounded corners — layout relies on corner-pinned navigation and large whitespace gaps between full-bleed media sections.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- Detected source-domain vocabulary: search/productivity software. Translate it into reusable visual behavior, not literal imagery.
- Avoid literal source imagery unless the exact slide text or visual direction explicitly requests it: search bars, search result pages, browser chrome, or app screenshots; product logos, app icons, map pins, or play-button branding.

Overall visual personality: The system is a brutalist broadcast — a single chromatic signal fired across a sun-warmed clay canvas, with almost no UI surface treatment. The interface is a vertical scroll of oversized, uppercase type, corner-pinned navigation labels, and full-bleed media. The aesthetic borrows from emergency signage and typesetter's proof approachable modular product geometry: everything is uppercase, aggressively tracked-negative at display sizes, and stripped of decoration. There are no cards, no shadows, no gradients, no rounded corners. The entire interface reads like a single printed broadside where one color ({colors.primary} — ff1a00) does all the work against one canvas color ({colors.canvas} — e7a196). Whitespace and type scale establish hierarchy, not containers or elevation. Key Characteristics: - Single accent color: {colors.primary} (ff1a00) is the only chromatic color. It is used for all navigation, body text, headings, icons, and borders. It functions as both brand accent and foreground text color simultaneously. - Single canvas color: {colors.canvas} (e7a196) is the default page background for all UI. - Monolithic typography: A neo-grotesque typeface (GT Pressura) is the workho...

Color tokens:
- primary: #ff1a00
- canvas: #e7a196
- surface-media: #0a0a0a
- body: #ff1a00
- on-canvas: #ff1a00

Typography tokens:
- hero-display: family GT Pressura, ui-sans-serif, system-ui, sans-serif, size 245px, weight 400, line 0.8, tracking -12.25px
- display-xl: family GT Pressura, ui-sans-serif, system-ui, sans-serif, size 190px, weight 400, line 0.8, tracking -8.17px
- display-lg: family GT Pressura, ui-sans-serif, system-ui, sans-serif, size 128px, weight 400, line 0.82, tracking -5.12px
- display-md: family GT Pressura, ui-sans-serif, system-ui, sans-serif, size 95px, weight 400, line 0.82, tracking -3.52px
- display-sm: family GT Pressura, ui-sans-serif, system-ui, sans-serif, size 48px, weight 400, line 1, tracking -1.44px
- statement-headline: family Monument Grotesk, ui-sans-serif, system-ui, sans-serif, size 48px, weight 400, line 1, tracking -1.92px
- title-sm: family GT Pressura, ui-sans-serif, system-ui, sans-serif, size 20px, weight 400, line 1.2, tracking -0.5px
- title-xs: family GT Pressura, ui-sans-serif, system-ui, sans-serif, size 18px, weight 400, line 1.2, tracking -0.09px
- body-md: family GT Pressura, ui-sans-serif, system-ui, sans-serif, size 16px, weight 400, line 1.2, tracking -0.08px
- body-sm: family GT Pressura, ui-sans-serif, system-ui, sans-serif, size 14px, weight 400, line 1.2, tracking -0.07px
- caption: family GT Pressura, ui-sans-serif, system-ui, sans-serif, size 12px, weight 400, line 1.2, tracking -0.06px

Spacing tokens:
- xxs: 6px
- xs: 12px
- sm: 24px
- md: 30px
- lg: 60px
- xl: 120px
- xxl: 150px
- section: 150px

Radius and shape tokens:
- xs: 0px
- sm: 0px
- md: 0px
- lg: 0px
- xl: 0px
- pill: 0px
- full: 9999px

Component tokens:
- corner-nav: backgroundColor: transparent, textColor: {colors.primary}, typography: {typography.caption}
- corner-badge: backgroundColor: transparent, textColor: {colors.primary}, typography: {typography.caption}
- statement-headline: backgroundColor: transparent, textColor: {colors.primary}, typography: {typography.statement-headline}
- display-block-hero: backgroundColor: transparent, textColor: {colors.primary}, typography: {typography.hero-display}
- display-block-xl: backgroundColor: transparent, textColor: {colors.primary}, typography: {typography.display-xl}
- media-frame: backgroundColor: {colors.surface-media}, rounded: {rounded.xs}
- media-play-control: backgroundColor: transparent, borderColor: {colors.primary}, borderWidth: 1.5px, rounded: {rounded.full}, height: 64px, width: 64px
- footer-bar: backgroundColor: transparent, textColor: {colors.primary}, typography: {typography.caption}

Color rationale: Brand & Accent - Signal Flare ({colors.primary} — ff1a00): The single, defining chromatic color. It is used for all text, headings, navigation links, icons, and borders. Its role is absolute; there are no secondary or tertiary accent colors. Surface - Sun-Baked Canvas ({colors.canvas} — e7a196): The primary page floor. A warm, muted clay-peach that serves as the background for all UI and text content. - Midnight Frame ({colors.surface-media} — 0a0a0a): Reserved exclusively for full-bleed video and photography sections. It appears as the dark frame holding embedded media, never as a UI surface or text color. Text - Body ({colors.body} — ff1a00): All text in the system uses the primary signal color. There is no separate black or gray for running text. The high contrast of red-orange on warm peach is the system's only text/background pairing.

Typography rationale: Font Family The system uses two neo-grotesque typefaces: - GT Pressura: The single workhorse typeface, carrying everything from 12px footer labels to 245px display headlines. - Monument Grotesk: Reserved for one purpose: the primary {typography.statement-headline} at 48px. Its wider proportions contrast the main typeface's mechanical quality. Hierarchy All typography is set at a single weight (400) and in uppercase. Hierarchy is achieved solely through a dramatic scale in font size and a corresponding tightening of letter spacing. The system's signature is the extreme negative tracking on display sizes, which compresses letters until they almost touch. | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.hero-display} | 245px | 400 | 0.8 | -12.25px | Maximal display type, often for textural alphanumeric strings | | {typography.display-xl} | 190px | 400 | 0.8 | -8.17px | Large, impactful section titles | | {typography.display-lg} | 128px | 400 | 0.82 | -5.12px | Major section markers | | {typography.display-md} | 95px | 400 | 0.82 | -3.52px | Sub-section display heads | | {typography.display-sm} | 48px | 400 | 1 | -1.44px | Standard...

Layout system: Spacing System - Base unit: 6px. - Tokens: {spacing.xxs} 6px · {spacing.xs} 12px · {spacing.sm} 24px · {spacing.md} 30px · {spacing.lg} 60px · {spacing.xl} 120px · {spacing.section} 150px. - Section gap: Very large, using {spacing.xl} (120px) to {spacing.section} (150px) between major content blocks. - Element gap: {spacing.md} (30px) or less. Gutters between grid items are often 0px. - Card padding: Not applicable, as the system does not use cards. Grid & Container - Max content width: ~1440px for text blocks, which are typically centered. - Media: Full-bleed, edge-to-edge, ignoring the max content width. - Layout Rhythm: The page is a vertical scroll of alternating spacious text sections on the warm canvas and full-bleed dark media frames. The rhythm is: empty canvas - dark media - warm text block - dark media. - Corner-Pinned UI: Navigation and metadata are pinned to the corners of the viewport (top-left, top-right, bottom-left, bottom-right) rather than being contained in a traditional header or footer band.

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | Flat | No shadow, no border, no elevation | The entire UI. All elements exist on a single plane. | The system has no elevation model. Hierarchy is built entirely through type scale, color contrast, and whitespace. Elements sit flat on the {colors.canvas} like print on paper. The page behaves as a single surface that scrolls vertically, not a stack of cards or layers.

Shape language: Border Radius Scale | Token | Value | Use | |---|---|---| | {rounded.xs} | 0px | Default for all elements (media, inputs, buttons) | | {rounded.full} | 9999px | Reserved for circular icons, like the media play control and corner badge | The shape language is strictly rectilinear. All components and media frames have sharp, 0px corners. The only exception is for specific, functional icons which may be circular. Iconography Iconography is extremely minimal and functional, limited to three types: - Navigation affordance: A hamburger-style icon for mobile menus. - Play control: A circular outline with an inset triangle glyph. - Scroll affordance: A downward-pointing arrow glyph. All icons are stroke-only outlines in {colors.primary}, consistent with the system's print-like aesthetic.

Component language: Navigation & Metadata corner-nav — Primary site navigation, rendered as a vertical stack of uppercase text links. Pinned to the top-left of the viewport, it uses {typography.caption} in {colors.primary} and sits directly on the canvas with no background. corner-badge — A location or establishment marker in the top-right corner. Composed of two lines of {typography.caption} text and a 40px circular outline icon, all in {colors.primary}. footer-bar — A metadata strip at the bottom of the initial viewport. A three-column layout (left label, center scroll prompt, right copyright notice) using {typography.caption} in {colors.primary}. It has no background or borders. scroll-prompt — A wayfinding cue, typically text with a downward arrow glyph. Uses {typography.caption} in {colors.primary}. Headlines & Text Blocks statement-headline — The primary hero message. Uses the unique {typography.statement-headline} token (48px Monument Grotesk) in {colors.primary}. It's typically centered. display-block-hero / display-block-xl — Oversized text blocks used for section markers or as visual texture. They use the largest typography roles ({typography.hero-display}, etc.) with extreme negative lette...

Guardrails: Do - Use the primary neo-grotesque typeface at weight 400 for all UI text. Hierarchy comes from size alone. - Apply {colors.primary} as the single chromatic color for every text, border, and icon element. - Push display headlines to 128px or larger with letter-spacing between -5px and -12px. The near-contact tracking is the signature. - Pin navigation and metadata to the corners of the viewport rather than building a traditional header bar. - Use full-bleed, edge-to-edge media with no rounding and no overlay the source brand. - Maintain a very tight line-height (0.8–0.82) for display sizes. - Keep all text uppercase. Don't - Do not introduce shadows, gradients, or any container-based elevation. The page is flat print, not stacked surfaces. - Do not use a fill color for buttons. The system has no filled buttons, only text links and outlined controls. - Do not add secondary or tertiary text colors. {colors.primary} against {colors.canvas} is the only contrast pair. - Do not use card padding, gutters between grid items, or rou...
```
