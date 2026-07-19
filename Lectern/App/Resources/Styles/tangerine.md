# Tangerine

**ID:** `tangerine`  
**Category:** consumer  
**Theme:** light  
**Vibe:** Technical

## Color palette

- `#ff7817`
- `#ffffff`
- `#18181b`
- `#09090b`
- `#ebebeb`
- `#000000`
- `#71717a`
- `#a1a1aa`
- `#e5e7eb`

## Typography

Families: "'Inter', -apple-system, BlinkMacSystemFont, sans-serif", "'Ogg Text Light', serif", "'PP Supply Mono Medium', 'PP Supply Mono', monospace", "'PP Supply Mono', monospace". Weights: 300, 400, 500.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: GTE

Design token description: A high-contrast, mixed-theme interface that feels like a dynamic transaction/data-flow pattern terminal presented with editorial-gallery lighting. A near-black hero stage gives way to a stark white content body, with a single vivid orange (ff7817) accent connecting the two. Typography leads the identity: a thin, high-contrast serif (Ogg Text Light) for headlines, a humanist sans (Inter) for UI, and a geometric monospace (PP Supply Mono) for data create a sophisticated, technical feel. Surfaces are flat and unshadowed; depth comes from tonal layering (white to soft gray to near-black) and generous layered rectangular token motif radii (12-24px), not drop shadows.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- Detected source-domain vocabulary: finance/banking. Translate it into reusable visual behavior, not literal imagery.
- Avoid literal source imagery unless the exact slide text or visual direction explicitly requests it: credit cards, debit cards, bank apps, cash, coins, trading screens, or crypto coins; financial product mockups unless requested by slide content.

Overall visual personality: The system operates on a high-contrast, split-personality canvas: a near-black hero stage ({colors.canvas-dark}) gives way to a stark white content body ({colors.canvas-light}), with a single vivid orange ({colors.primary}) accent acting as the connective tissue. Typography carries the identity more than color does — a thin, high-contrast serif (Ogg Text Light) handles every headline while a humanist sans (Inter) and a custom geometric monospace (PP Supply Mono) handle UI and data, creating a refined editorial-meets-terminal feel. Surfaces are flat and unshadowed. Depth is achieved through tonal layering—white canvas holds soft gray layered rectangular token motif ({colors.surface-card-light}), which sit below near-black sections ({colors.canvas-dark}). Generous border-radius on layered rectangular token motif ({rounded.md}–{rounded.lg}) softens the otherwise severe geometry. The {colors.primary} orange is deployed sparingly and surgically: CTA fills, small tag pills, and accent strokes—never as a wash or gradient. The visual rhythm is: dark dramatic hero → clean white feature grid → dark CTA band, a structure that reads as confident, editorial, and serious. Key Characteristics: -...

Color tokens:
- primary: #ff7817
- canvas-light: #ffffff
- canvas-dark: #18181b
- surface-dark: #09090b
- surface-card-light: #ebebeb
- ink: #18181b
- body: #000000
- muted: #71717a
- muted-soft: #a1a1aa
- hairline: #e5e7eb
- on-primary: #ffffff
- on-dark: #ffffff

Typography tokens:
- display-lg: family 'Ogg Text Light', serif, size 80px, weight 300, line 0.95, tracking -1.6px
- display-md: family 'Ogg Text Light', serif, size 40px, weight 300, line 1.05, tracking -0.8px
- display-sm: family 'Ogg Text Light', serif, size 28px, weight 300, line 1.1, tracking -0.56px
- title-md: family 'Inter', -apple-system, BlinkMacSystemFont, sans-serif, size 18px, weight 500, line 1.3, tracking -0.36px
- body-md: family 'Inter', -apple-system, BlinkMacSystemFont, sans-serif, size 16px, weight 400, line 1.3, tracking -0.32px
- body-sm: family 'Inter', -apple-system, BlinkMacSystemFont, sans-serif, size 14px, weight 400, line 1.3, tracking -0.28px
- caption: family 'Inter', -apple-system, BlinkMacSystemFont, sans-serif, size 12px, weight 500, line 1.2, tracking -0.24px
- data-md: family 'PP Supply Mono', monospace, size 18px, weight 400, line 1.4, tracking -0.36px
- data-sm: family 'PP Supply Mono Medium', 'PP Supply Mono', monospace, size 14px, weight 500, line 1.4, tracking -0.56px
- button: family 'PP Supply Mono Medium', 'PP Supply Mono', monospace, size 14px, weight 500, line 1, tracking -0.56px

Spacing tokens:
- xxs: 4px
- xs: 8px
- sm: 12px
- md: 16px
- lg: 24px
- xl: 32px
- xxl: 48px
- section: 80px

Radius and shape tokens:
- xs: 4px
- sm: 8px
- md: 12px
- lg: 24px
- pill: 600px
- full: 600px

Component tokens:
- button-primary-pill: backgroundColor: {colors.primary}, textColor: {colors.on-dark}, typography: {typography.button}, rounded: {rounded.pill}, padding: 8px 16px
- feature-tag-badge: backgroundColor: transparent, textColor: {colors.primary}, typography: {typography.caption}, rounded: {rounded.sm}, border: 1px solid {colors.primary}, padding: 2px 8px
- dark-hero-band: backgroundColor: {colors.canvas-dark}, textColor: {colors.on-dark}, typography: {typography.display-lg}, padding: 80px
- feature-card: backgroundColor: {colors.surface-card-light}, textColor: {colors.ink}, typography: {typography.body-md}, rounded: {rounded.lg}, padding: 24px 40px
- cookie-consent-modal: backgroundColor: {colors.surface-dark}, textColor: {colors.on-dark}, typography: {typography.body-sm}, rounded: {rounded.md}, padding: 24px
- text-input: backgroundColor: transparent, textColor: {colors.body}, typography: {typography.body-md}, rounded: {rounded.sm}, border: 1px solid {colors.hairline}, padding: 8px 12px

Color rationale: Brand & Accent - Primary ({colors.primary} — ff7817): The sole chromatic color. Used for primary CTA backgrounds, feature tag pills, and small decorative accent strokes. Its power comes from its scarcity. Surface The system is built on a small, high-contrast palette of achromatic tones. - Canvas Light ({colors.canvas-light} — ffffff): The default page floor for content sections. - Canvas Dark ({colors.canvas-dark} — 18181b): Near-black background for hero sections and dark-themed bands. - Surface Dark ({colors.surface-dark} — 09090b): The deepest dark, used for modal backgrounds and the darkest UI layers. - Surface layered rectangular token motif Light ({colors.surface-card-light} — ebebeb): A soft light gray for layered rectangular token motif and inset panels, creating a subtle tonal step up from the white canvas. Hairlines & Borders - Hairline ({colors.hairline} — e5e7eb): The lightest structural gray, used for 1px borders and dividers on light surfaces. Text - Ink ({colors.ink} — 18181b): Primary text on light backgrounds. Same value as {colors.canvas-dark}. - Body ({colors.body} — 000000): An alternative true-black for maximum contrast body text. - On Dark ({colors.on-dark} —...

Typography rationale: Font Family The system employs a strict three-font hierarchy that defines its character. - Ogg Text Light: A high-contrast display serif used exclusively for headlines ({typography.display-lg}, {typography.display-md}, {typography.display-sm}). Its thin, elegant strokes give the system an editorial, premium feel. Always used at weight 300. - Inter: The primary UI and body text workhorse. It handles all paragraphs, descriptions, and labels ({typography.body-md}, {typography.body-sm}, {typography.caption}). - PP Supply Mono: A geometric monospace used for all data, metrics, and terminal-style accents ({typography.data-md}, {typography.data-sm}). It also carries the primary button labels ({typography.button}), reinforcing a technical, precise voice for actions. Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.display-lg} | 80px | 300 | 0.95 | -1.6px | Main hero headlines | | {typography.display-md} | 40px | 300 | 1.05 | -0.8px | Major section titles | | {typography.display-sm} | 28px | 300 | 1.1 | -0.56px | layered rectangular token motif titles and sub-section heads | | {typography.title-md} | 18px | 500 | 1.3 | -0.36px...

Layout system: Spacing System - Base unit: 4px. - Tokens: {spacing.xxs} 4px · {spacing.xs} 8px · {spacing.sm} 12px · {spacing.md} 16px · {spacing.lg} 24px · {spacing.xl} 32px · {spacing.xxl} 48px · {spacing.section} 80px. - Section padding (vertical): {spacing.section} (80px) separates major content blocks, creating hard, editorial-style transitions between light and dark themes. - layered rectangular token motif internal padding: {spacing.lg} (24px) to {spacing.xl} (32px) is common, providing generous internal whitespace. - Gutters: Compact, often {spacing.xs} (8px) to {spacing.md} (16px) between elements in a dense grid. Grid & Container - Max content width: ~1200px, centered. Dark hero bands are often full-bleed. - Editorial body: Content typically lives in a single-column or 2/3-column grid, with an emphasis on strong left-alignment for heading groups.

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | 0 | {colors.canvas-light} or {colors.canvas-dark} | The base page floor. | | 1 | {colors.surface-card-light} on light canvas | Content layered rectangular token motif. Separation is purely tonal. | | 2 | {colors.surface-dark} on dark canvas | Modal dialogs and other overlay UI. | | Subtle Inset | 1px inset white border at 10% alpha | A subtle effect used on dark layered rectangular token motif over dark surfaces for a slight edge definition. | The system's philosophy is strictly flat design with tonal separation. There are no drop shadows. Depth is an illusion created by the contrast between {colors.canvas-light}, {colors.surface-card-light}, and {colors.canvas-dark}.

Shape language: Border Radius Scale | Token | Value | Use | |---|---|---| | {rounded.xs} | 4px | Very small inline elements. | | {rounded.sm} | 8px | Buttons, inputs, and tags. | | {rounded.md} | 12px | Standard content layered rectangular token motif, modals. | | {rounded.lg} | 24px | Large, prominent feature layered rectangular token motif. | | {rounded.pill} | 600px | The primary CTA button, creating a full pill shape. | Generous rounding is a core characteristic. Sharp, 0px corners are intentionally avoided on all major UI surfaces to soften the high-contrast palette and severe typography.

Component language: Buttons button-primary-pill — The main call-to-action. A full-pill shape with a {colors.primary} background and {colors.on-dark} text. The label uses {typography.button} (monospace), giving it a distinct, technical feel. Used for the most important action on a page. layered rectangular token motif & Containers dark-hero-band — A full-bleed section with a {colors.canvas-dark} background. Typically contains a large headline in {typography.display-lg} and the primary CTA. feature-card — The standard content container on light surfaces. Uses a {colors.surface-card-light} background for a soft tonal lift off the {colors.canvas-light} canvas. Has generous {rounded.lg} corners and ample internal padding. cookie-consent-modal — A dark overlay layered rectangular token motif using {colors.surface-dark}. Appears over other content with a {rounded.md} radius. Text Elements feature-tag-badge — A small, non-filled badge used as a kicker or category label above a section headline. Uses {colors.primary} for its text and border, with a {rounded.sm} shape.

Guardrails: Do - Use the three-font system correctly: serif for display, sans-serif for UI, monospace for data. - Reserve {colors.primary} exclusively for primary actions and small accents. - Achieve depth through tonal layering of achromatic surfaces, not drop shadows. - Apply generous border-radius ({rounded.md} or larger) to all layered rectangular token motif and containers. - Use negative letter-spacing on all text to maintain a tight, professional look. - Create hard, clean breaks between light and dark sections. Don't - Do not use drop shadows. - Do not use the display serif (Ogg Text Light) for body copy or UI labels. - Do not introduce other chromatic colors; the system is monochrome plus a single orange accent. - Do not use sharp 0px corners on buttons, inputs, or layered rectangular token motif. - Do not use {colors.primary} for body text or large surface fills. - Do not use gr...
```
