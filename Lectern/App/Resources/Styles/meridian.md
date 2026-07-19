# Meridian

**ID:** `meridian`  
**Category:** consumer  
**Theme:** dark  
**Vibe:** Technical

## Color palette

- `#5266eb`
- `#ffffff`
- `#ededf3`
- `#c3c3cc`
- `#70707d`
- `#171721`
- `#1e1e2a`
- `#272735`
- `#cdddff`

## Typography

Families: "arcadia, sans-serif", "arcadiaDisplay, -apple-system, BlinkMacSystemFont, sans-serif", "arcadiaDisplay, sans-serif". Weights: 360, 400, 420, 480.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Mercury

Design token description: The design feels like a command center at twilight, expansive and focused. A deep, near-black neutral palette (1e1e2a, 171721) creates an immersive, cinematic canvas where glowing off-white text (ededf3) provides crisp clarity. All energy is channeled into a single, vibrant violet-blue accent (5266eb) reserved strictly for primary calls-to-action, like indicator lights on a high-tech console. The typography is a defining feature, with custom fonts used at light weights for headlines, creating an authoritative yet approachable voice. The contrast between spacious, atmospheric hero imagery and the stark, text-driven UI below creates a journey from aspiration to action.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- Detected source-domain vocabulary: consumer technology. Translate it into reusable visual behavior, not literal imagery.
- Avoid literal source imagery unless the exact slide text or visual direction explicitly requests it: phones, laptops, tablets, device mockups, or hardware product renders; app screenshots, operating-system chrome, or product launch hero shots.

Overall visual personality: Mercury feels like a command center at twilight: expansive, focused, and cinematic. The design is built on a deep, near-black canvas ({colors.canvas-dark} — 171721 and {colors.surface-card-dark} — 1e1e2a) that creates an immersive, focused environment. Crisp, glowing off-white text ({colors.body} — ededf3) provides clarity against the dark backdrop. All user action is channeled into a single, vibrant violet-blue accent ({colors.primary} — 5266eb), reserved exclusively for primary CTAs, functioning like an indicator light on a high-tech console. A defining characteristic is the typography. The system uses a two-font stack: arcadiaDisplay for headlines and arcadia for body and UI text. Critically, display sizes use a very light weight (360), establishing a tone of authority through restraint rather than loudness. The layout is spacious, using generous section spacing ({spacing.section} — 80px) to create a calm, linear reading flow. Buttons and inputs are a signature element, always rendered as fully rounded pills ({rounded.pill} or {rounded.pill-lg}), while content cards and containers are starkly unrounded ({rounded.none}). The design contrasts an atmospheric, photographic hero wit...

Color tokens:
- primary: #5266eb
- on-primary: #ffffff
- body: #ededf3
- muted: #c3c3cc
- hairline-on-dark: #70707d
- canvas-dark: #171721
- surface-card-dark: #1e1e2a
- surface-elevated-dark: #272735
- button-secondary-bg: #cdddff

Typography tokens:
- hero-display: family arcadiaDisplay, -apple-system, BlinkMacSystemFont, sans-serif, size 65px, weight 360, line 1.1, tracking 0.65px
- display-lg: family arcadiaDisplay, sans-serif, size 49px, weight 360, line 1.15, tracking 0.5px
- display-sm: family arcadiaDisplay, sans-serif, size 32px, weight 360, line 1.2, tracking 0.3px
- title-lg: family arcadiaDisplay, sans-serif, size 28px, weight 480, line 1.3, tracking 0
- title-md: family arcadia, sans-serif, size 21px, weight 480, line 1.35, tracking 0
- title-sm: family arcadia, sans-serif, size 18px, weight 420, line 1.4, tracking 0
- body-md: family arcadia, sans-serif, size 16px, weight 400, line 1.5, tracking 0.16px
- body-sm: family arcadia, sans-serif, size 14px, weight 400, line 1.5, tracking 0.28px
- caption: family arcadia, sans-serif, size 12px, weight 400, line 1.5, tracking 0.24px
- button: family arcadia, sans-serif, size 16px, weight 480, line 1, tracking 0
- nav-link: family arcadia, sans-serif, size 16px, weight 420, line 1.4, tracking 0

Spacing tokens:
- xxs: 4px
- xs: 8px
- sm: 12px
- md: 16px
- lg: 24px
- xl: 32px
- xxl: 56px
- section: 80px

Radius and shape tokens:
- none: 0px
- sm: 4px
- pill: 32px
- pill-lg: 40px

Component tokens:
- button-primary-pill: backgroundColor: {colors.primary}, textColor: {colors.on-primary}, typography: {typography.button}, rounded: {rounded.pill}, padding: 16px 24px
- button-secondary-pill: backgroundColor: {colors.button-secondary-bg}, textColor: {colors.body}, typography: {typography.nav-link}, rounded: {rounded.pill-lg}, padding: 8px 20px
- nav-link: backgroundColor: transparent, textColor: {colors.body}, typography: {typography.nav-link}
- footer-link: backgroundColor: transparent, textColor: {colors.muted}, typography: {typography.body-sm}
- hero-email-input: backgroundColor: transparent, textColor: {colors.body}, typography: {typography.body-md}, rounded: {rounded.pill}, padding: 16px 24px
- feature-link: backgroundColor: transparent, textColor: {colors.body}, typography: {typography.title-lg}, padding: 24px 0

Color rationale: Brand & Accent - Mercury Blue ({colors.primary} — 5266eb): The single, vibrant brand color. Used exclusively for the background of primary CTA buttons. Its power comes from its scarcity. - Ghost Blue ({colors.button-secondary-bg} — cdddff): A desaturated, ethereal blue used for secondary button backgrounds, often at a low opacity (e.g., 20%) to suggest interaction without competing with the primary accent. the source brand The system is exclusively dark mode, using a layered approach to create depth. - Canvas Dark ({colors.canvas-dark} — 171721): The outermost, deepest black layer of the page background. Also referred to as 'Deep Space' or 'Abyss'. - the source brand Card Dark ({colors.surface-card-dark} — 1e1e2a): The primary the source brand for content sections and cards. A slightly lighter near-black, also called 'Midnight Slate'. - the source brand Elevated Dark ({colors.surface-elevated-dark} — 272735): A subtle step lighter, used for interactive states or nested components. Also known as 'Graphite'. Hairlines & Borders - Hairline on Dark ({colors.hairline-on-dark} — 70707d): A muted gray ('Lead') used for subtle borders and dividers, such as on the bottom of list items or a...

Typography rationale: Font Family The system relies on a custom two-font stack to create its signature voice: - arcadiaDisplay: Used for all major headlines ({typography.hero-display}, {typography.display-lg}, etc.). Its use at a very light weight (360) is a core design principle, creating a feeling of sophisticated authority. - arcadia: The workhorse font for all body copy, UI labels, navigation, and smaller headings ({typography.body-md}, {typography.button}, etc.). If the custom fonts are unavailable, Inter or Manrope are suitable open-source substitutes. Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.hero-display} | 65px | 360 | 1.1 | 0.65px | Primary H1 in the hero section. | | {typography.display-lg} | 49px | 360 | 1.15 | 0.5px | Major section headlines. | | {typography.display-sm} | 32px | 360 | 1.2 | 0.3px | Sub-section headlines. | | {typography.title-lg} | 28px | 480 | 1.3 | 0 | Feature list titles. | | {typography.title-md} | 21px | 480 | 1.35 | 0 | Smaller headings, hero sub-headline. | | {typography.title-sm} | 18px | 420 | 1.4 | 0 | Tertiary headings. | | {typography.body-md} | 16px | 400 | 1.5 | 0.16px | Default running-te...

Layout system: Spacing System - Base unit: 4px. - Tokens: {spacing.xxs} 4px · {spacing.xs} 8px · {spacing.sm} 12px · {spacing.md} 16px · {spacing.lg} 24px · {spacing.xl} 32px · {spacing.xxl} 56px · {spacing.section} 80px. - Section padding (vertical): A generous {spacing.section} (80px) or more is used between major content blocks to create a calm, focused reading experience. - Element gap: Internal spacing between elements typically ranges from {spacing.sm} (12px) to {spacing.xl} (32px). Grid & Container - Max content width: ~1200px, centered on the page. This applies to all content below the full-bleed hero section. - Grid structure: Content is primarily organized in simple, single-column stacks. This linear flow emphasizes clarity and focus. - Hero: The hero section is always full-bleed, occupying the entire viewport with a centered headline and CTA over a background image. Whitespace Philosophy Mercury is a spacious design. It prioritizes breathing room and avoids dense, cluttered layouts. Whitespace is used as an active tool to guide the user's focus and establish a serene, high-end aesthetic.

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | Level 0 | {colors.canvas-dark} background | Outermost page background layer, the "abyss". | | Level 1 | {colors.surface-card-dark} background | Main content section background, cards, containers. Sits on Level 0. | | Level 2 | {colors.surface-elevated-dark} background | Hover states or contained interactive elements. | | Focus | {colors.primary} glow or border | Interactive elements "light up" with the brand accent color on focus. | The elevation philosophy is shadowless and color-driven. Depth is not created with drop shadows but with subtle shifts between the dark the source brand colors ({colors.canvas-dark}, {colors.surface-card-dark}, {colors.surface-elevated-dark}). Interaction is signaled by elements "lighting up"—brightening in color or adopting the {colors.primary} accent—rather than lifting off the page.

Shape language: Border Radius Scale | Token | Value | Use | |---|---|---| | {rounded.none} | 0px | Content cards, section containers, feature list items. | | {rounded.sm} | 4px | Subtle rounding for small containers or decorative elements. | | {rounded.pill} | 32px | Primary buttons, email inputs. The default pill shape. | | {rounded.pill-lg}| 40px | Secondary buttons in the header, slightly larger pill. | The system's shape language is defined by a stark contrast: pill-shaped interactive elements and sharp-cornered static containers. Buttons and inputs are always fully rounded, creating a soft, approachable feel for actions. In contrast, cards and content wrappers use {rounded.none} (0px), lending a precise, geometric structure to the layout. Photography & Iconography The visual language is bifurcated. It opens with a full-bleed, atmospheric photograph (e.g., a solitary desk in a vast landscape) to establish a mood of ambition and focus. Beyond the hero, the site is starkly text-dominant, with no additional photography or illustration.

Component language: Buttons button-primary-pill — The main call-to-action. A fully rounded pill ({rounded.pill}) with a solid {colors.primary} background and {colors.on-primary} text. It's the primary focal point for user action on any clean interface-like information plane. button-secondary-pill — A secondary CTA used in the navigation bar. Also a pill ({rounded.pill-lg}), but with a translucent {colors.button-secondary-bg} background and {colors.body} text. It suggests interaction without competing with the primary CTA. Navigation Links nav-link — Standard navigation items. These appear as text-only links using {colors.body} for text and {typography.nav-link}. They have no background or border in their default state. footer-link — Links in the page footer. Similar to nav-link but uses the muted text color ({colors.muted}) to indicate lower priority. Forms hero-email-input — The primary email capture field, often found in the hero. It has a transparent background, {colors.body} text, and a thin {colors.hairline-on-dark} border for definition. It uses {rounded.pill} and is often designed to join seamlessly with a button-primary-pill. Content feature-link — Used for selectable items in a feature list....

Guardrails: Do - Use {typography.hero-display} at a light weight (360) for all major headlines to maintain an airy, sophisticated tone. - Reserve {colors.primary} exclusively for primary, action-oriented CTAs. - Employ the...
```
