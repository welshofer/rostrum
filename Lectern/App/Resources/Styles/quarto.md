# Quarto

**ID:** `quarto`  
**Category:** consumer  
**Theme:** light  
**Vibe:** Editorial

## Color palette

- `#191919`
- `#000000`
- `#ffffff`
- `#808080`

## Typography

Families: "'TWK Everett Mono', ui-monospace, monospace", "'TWK Everett', -apple-system, BlinkMacSystemFont, sans-serif". Weights: 400.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: NCDA

Design token description: An architectural, monograph-like design language built on a paper-white canvas (ffffff) and a single near-black ink (191919). The system avoids chromatic color entirely, using typographic scale and vast negative space to create structure and hierarchy. Its signature is an unornamented neo-grotesque typeface used at a single weight (400) across all roles, from tiny captions with positive letter-spacing to massive, viewport-cropped display type with aggressive negative tracking. Components are minimal — hairline rules, plain text links, and full-bleed dark bands (191919) — with all corners kept sharp (0px radius). The overall effect is one of printed-matter precision, calm authority, and structural typography.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- Detected source-domain vocabulary: consumer technology. Translate it into reusable visual behavior, not literal imagery.
- Avoid literal source imagery unless the exact slide text or visual direction explicitly requests it: phones, laptops, tablets, device mockups, or hardware product renders; app screenshots, operating-system chrome, or product launch hero shots.

Overall visual personality: This is an architectural, gallery-catalogue design system that operates in negative space. The language is built on a stark monochrome palette: paper-white canvas ({colors.canvas-light} — ffffff) and a single near-black ink ({colors.ink} — 191919) for surfaces and hairlines, with a slightly deeper black ({colors.ink-strong} — 000000) for high-contrast text. There is zero chromatic color. Hierarchy is achieved through extreme typographic scale and vast, unadorned whitespace, not color or elevation. The system's typographic voice is its most defining feature. A single neo-grotesque typeface is used at one weight (400) for every role, from 11px captions to 62px display headlines. This creates a monolithic, calm-but-authoritative tone. The display type is treated as architecture: rendered at enormous scale with tight negative tracking ({typography.display}), it is intentionally cropped by the viewport edge, turning text into a structural layout element. Small captions ({typography.caption}) use positive tracking for a technical, annotated feel. Layouts alternate between vast white pages and full-bleed black bands, creating a rhythm like a printed monograph. Key Characteristics: - Mono...

Color tokens:
- ink: #191919
- ink-strong: #000000
- canvas-light: #ffffff
- surface-dark: #191919
- on-dark: #ffffff
- muted: #808080
- hairline: #808080

Typography tokens:
- display: family 'TWK Everett', -apple-system, BlinkMacSystemFont, sans-serif, size 62px, weight 400, line 0.8, tracking -3.1px
- heading: family 'TWK Everett', -apple-system, BlinkMacSystemFont, sans-serif, size 32px, weight 400, line 1.35, tracking -0.32px
- subheading: family 'TWK Everett', -apple-system, BlinkMacSystemFont, sans-serif, size 21px, weight 400, line 1.4, tracking -0.21px
- body: family 'TWK Everett', -apple-system, BlinkMacSystemFont, sans-serif, size 15px, weight 400, line 1.44, tracking -0.15px
- caption: family 'TWK Everett', -apple-system, BlinkMacSystemFont, sans-serif, size 11px, weight 400, line 1.44, tracking 0.44px
- monospace-subheading: family 'TWK Everett Mono', ui-monospace, monospace, size 21px, weight 400, line 0.8, tracking -0.21px

Spacing tokens:
- xxs: 4px
- xs: 12px
- sm: 15px
- md: 26px
- lg: 53px
- xl: 64px
- xxl: 150px
- section: 150px

Radius and shape tokens:
- xs: 0px
- sm: 0px
- md: 0px
- lg: 0px
- xl: 0px
- pill: 0px
- full: 0px

Component tokens:
- large-scale-display-type: backgroundColor: transparent, textColor: {colors.ink-strong}, typography: {typography.display}
- utility-timestamp: backgroundColor: transparent, textColor: {colors.ink-strong}, typography: {typography.caption}
- nav-trigger-text: backgroundColor: transparent, textColor: {colors.ink-strong}, typography: {typography.body}
- description-block: backgroundColor: transparent, textColor: {colors.muted}, typography: {typography.body}
- dark-section-band: backgroundColor: {colors.surface-dark}, textColor: {colors.on-dark}, padding: {spacing.xl}
- text-link-hairline: backgroundColor: transparent, textColor: {colors.ink-strong}, typography: {typography.body}
- meta-label: backgroundColor: transparent, textColor: {colors.muted}, typography: {typography.caption}

Color rationale: The color system is minimal and functional, evoking print on paper. Core Palette - Canvas Light ({colors.canvas-light} — ffffff): The primary page floor. The "paper" of the system. - Ink Strong ({colors.ink-strong} — 000000): The primary text color on light surfaces, used for maximum contrast and readability. - Ink ({colors.ink} — 191919): A slightly softer near-black used for dark surfaces and structural borders. - Muted ({colors.muted} — 808080): A concrete gray for secondary descriptive text, metadata, and non-interactive hairlines. - On Dark ({colors.on-dark} — ffffff): Text color for use on dark surfaces. Surfaces - the source brand Dark ({colors.surface-dark} — 191919): Full-bleed content bands that act as section breaks or containers for media. Borders - Hairline ({colors.hairline} — 808080): The 1px border tone used for underlines on text links.

Typography rationale: Font Family The system uses a single neo-grotesque typeface (similar to Neue Haas Grotesk or Inter) for all display and interface text. A monospaced companion is used for tabular data or technical annotations. The defining characteristic is the use of a single weight (Regular, 400) across the entire type scale. Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.display} | 62px | 400 | 0.8 | -3.1px | Architectural headlines, treated as layout elements | | {typography.heading} | 32px | 400 | 1.35 | -0.32px | Section titles | | {typography.subheading} | 21px | 400 | 1.4 | -0.21px | Body sub-sections | | {typography.monospace-subheading} | 21px | 400 | 0.8 | -0.21px | Technical annotations, tabular data | | {typography.body} | 15px | 400 | 1.44 | -0.15px | Default running text, navigation links | | {typography.caption} | 11px | 400 | 1.44 | 0.44px | Metadata, timestamps, labels | Principles - Scale over weight: Hierarchy is established exclusively through font size contrast. The lack of bold or medium weights creates a calm, consistent typographic texture. - Tracking as voice: Letter-spacing is a key design tool. The tight...

Layout system: Spacing System - Base unit: 4px. - Tokens: The spacing scale is irregular, reflecting a system built on typographic proportion rather than a strict grid. Key values include {spacing.sm} (15px), {spacing.xl} (64px), and {spacing.section} (150px). - Section padding (vertical): Gaps between major content blocks are generous, typically {spacing.xl} (64px) to {spacing.section} (150px) of negative space. - Element gutters: Gaps between smaller, related elements are tight, often {spacing.sm} (15px). Grid & Container - No container: The layout is full-bleed by default, with no maximum content width. Elements are positioned relative to the viewport edges. - Asymmetric composition: The primary layout pattern is asymmetric. Content is often left-aligned within columns, but key elements are positioned to create dynamic balance across the page (e.g., a text block in the upper-right quadrant balanced by a large type element in the lower half). - Rhythm: The page rhythm alternates between expansive white-canvas sections and immersive, full-bleed {colors.surface-dark} bands. Whitespace Philosophy Whitespace is the primary layout tool. The system uses vast, empty regions to frame content, create f...

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | 0 (Flat) | No shadow, no border | All elements. The page is a single, flat plane. | | 1 (Inversion) | Full-bleed {colors.surface-dark} | Content bands that interrupt the white canvas. | The system is intentionally and completely flat. There are no drop shadows, gradients, or any other effects that would create a sense of z-axis depth. Hierarchy and separation are achieved exclusively through typographic scale, color inversion (white on black), and the strategic use of negative space.

Shape language: Border Radius Scale | Token | Value | Use | |---|---|---| | {rounded.xs} | 0px | All elements | | {rounded.sm} | 0px | All elements | | {rounded.md} | 0px | All elements | | {rounded.lg} | 0px | All elements | | {rounded.xl} | 0px | All elements | | {rounded.pill} | 0px | Not used; concept is antithetical to the system | | {rounded.full} | 0px | Not used | All corners are sharp (0px). This is a foundational rule of the system. Rounded corners would undermine the crisp, architectural, and print-inspired aesthetic.

Component language: Content & Structure large-scale-display-type — The system's signature typographic treatment. Uses {typography.display} with its massive size and tight negative tracking. It's not just a headline; it's a structural graphic element, often sized to bleed off the edges of the viewport. dark-section-band — A full-viewport-width band with a {colors.surface-dark} background. It acts as a dramatic section break or a container for full-bleed media. The transition from the white canvas is always abrupt. description-block — A multi-line block of text set in {typography.body} and colored with {colors.muted}. Used for introductory or explanatory paragraphs. Emphasized text within the block can be elevated to {colors.ink-strong}. Navigation & Actions nav-trigger-text — The sole navigation element. A plain text label set in {typography.body}. It has no background, border, or icon, relying on placement and context for its affordance. text-link-hairline — An inline text link. The text is set in {typography.body} with {colors.ink-strong}. The link affordance is a 1px bottom border in {colors.hairline}, not a color change. Metadata utility-timestamp — A small, persistent utility element for displayi...

Guardrails: Do - Use the single-weight (400) typeface at every size. Never introduce bold or medium weights; the monolithic voice is the signature. - Apply extreme negative letter-spacing (-3.1px) to all {typography.display} text to create the architectural band effect. - Apply positive letter-spacing (+0.44px) to all {typography.caption} text to give it a technical, annotated feel. - Crop large type and imagery at the viewport edge. The bleed is structural, not an error. - Use stark, full-bleed {colors.surface-dark} bands to separate white content sections. - Keep all interactive elements as unadorned text. A {colors.hairline} underline is the only permitted link decoration. Don't - Don't introduce any chromatic color. The system is 0% colorful by design. - Don't add border-radius to any element. All corners must be sharp. - Don't use drop shadows or any elevation effects. The system is flat. - Don't use more than two or three type sizes on a single clean interface-like information plane. The system relies on extreme scale contrast. - Don't add icons, arrows, or decorative glyphs to navigation elements. Plain text is the entire affordance. - Don't center-align body text. All paragraph copy s...

Reusable visual grammar extracted from DESIGN.md:
- premium restraint, large quiet typography, and confident negative space
- minimal hero staging translated to the slide subject instead of product hardware
- soft material depth, subtle shadows, and clean interface-like information planes
- precise alignment with very low decorative noise
- disciplined grid construction with deliberate ma...
```
