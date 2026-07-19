# Wisteria

**ID:** `wisteria`  
**Category:** consumer  
**Theme:** light  
**Vibe:** Playful

## Color palette

- `#3c315b`
- `#e2dffe`
- `#ab9ff2`
- `#4a87f2`
- `#ffffc4`
- `#ffdadc`
- `#2ec08b`
- `#fdfcfe`
- `#f4f2f4`
- `#e9e8ea`

## Typography

Families: "'Phantom', Inter, Söhne, DM Sans, -apple-system, sans-serif". Weights: 350, 400.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Phantom

Design token description: A soft, monochromatic interface world bathed in aubergine (3c315b) and lavender. The system lives in a near-white canvas (fdfcfe) but often inverts to deep violet sections for contrast. Typography is a signature element, using a whisper-light weight (350) and aggressive negative letter-spacing for airy, sculptural headlines. The defining geometry is the soft pill shape; navigation, buttons, and tags use generous 100px radii. The palette is intentionally narrow, one primary violet underpins the structure, while pastel accents (lavender e2dffe, butter ffffc4, blush ffdadc) provide a soft, candy-store rhythm for interactive elements.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- No dominant source-domain vocabulary was detected, but still avoid copying example subject matter from the design brief.
- Avoid brand logos, product shots, mascot imagery, packaging, buildings, people, or industry-specific objects unless requested by the slide content.

Overall visual personality: This is a soft, monochromatic interface world bathed in aubergine ({colors.primary} — 3c315b) and lavender. The system lives in a near-white canvas ({colors.canvas-light} — fdfcfe) but often inverts to deep violet sections for dramatic, intimate contrast. Typography is a core signature of the system, using a whisper-light weight (350) and aggressive negative letter-spacing across all sizes for airy, sculptural headlines that feel almost architectural. The defining geometric signature is the soft pill shape. Navigation containers, buttons, and tags all dissolve into capsule forms with generous {rounded.pill} (100px) radii. The color palette is deliberately narrow and restrained: one primary violet underpins the entire structure, used for text, borders, and dark-mode surfaces. A small set of pastel accents — lavender ({colors.primary-cta-fill}), butter ({colors.accent-yellow}), and blush ({colors.accent-pink}) — provide a soft, candy-store rhythm for interactive elements, punctuating the quiet, monochromatic backdrop. Key Characteristics: - Monochromatic Core: The system is built on a single violet hue ({colors.primary}) that serves as the primary text color, dark canvas, and struct...

Color tokens:
- primary: #3c315b
- primary-cta-fill: #e2dffe
- on-primary-cta: #3c315b
- secondary: #ab9ff2
- accent-blue: #4a87f2
- accent-yellow: #ffffc4
- accent-pink: #ffdadc
- success: #2ec08b
- canvas-light: #fdfcfe
- canvas-dark: #3c315b
- surface-panel-light: #f4f2f4
- surface-soft-light: #e9e8ea
- ink: #1c1c1c
- on-dark: #fdfcfe

Typography tokens:
- hero-display: family 'Phantom', Inter, Söhne, DM Sans, -apple-system, sans-serif, size 96px, weight 350, line 1, tracking -2.4px
- display-lg: family 'Phantom', Inter, Söhne, DM Sans, -apple-system, sans-serif, size 64px, weight 350, line 1.1, tracking -1.6px
- title-lg: family 'Phantom', Inter, Söhne, DM Sans, -apple-system, sans-serif, size 30px, weight 350, line 1.21, tracking -0.75px
- title-md: family 'Phantom', Inter, Söhne, DM Sans, -apple-system, sans-serif, size 24px, weight 350, line 1.25, tracking -0.6px
- title-sm: family 'Phantom', Inter, Söhne, DM Sans, -apple-system, sans-serif, size 20px, weight 350, line 1.35, tracking -0.5px
- body-md: family 'Phantom', Inter, Söhne, DM Sans, -apple-system, sans-serif, size 16px, weight 400, line 1.4, tracking -0.4px
- body-sm: family 'Phantom', Inter, Söhne, DM Sans, -apple-system, sans-serif, size 15px, weight 400, line 1.4, tracking -0.375px
- caption: family 'Phantom', Inter, Söhne, DM Sans, -apple-system, sans-serif, size 13px, weight 350, line 1.35, tracking -0.325px
- button: family 'Phantom', Inter, Söhne, DM Sans, -apple-system, sans-serif, size 16px, weight 350, line 1, tracking -0.4px
- nav-link: family 'Phantom', Inter, Söhne, DM Sans, -apple-system, sans-serif, size 15px, weight 350, line 1.4, tracking -0.375px

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
- xs: 4px
- sm: 16px
- md: 24px
- lg: 32px
- pill: 100px
- full: 100px

Component tokens:
- top-nav: backgroundColor: {colors.canvas-light}, textColor: {colors.primary}, typography: {typography.nav-link}, rounded: {rounded.pill}, padding: 16px 24px
- button-primary: backgroundColor: {colors.primary-cta-fill}, textColor: {colors.on-primary-cta}, typography: {typography.button}, rounded: {rounded.pill}, padding: 16px 32px
- button-secondary: backgroundColor: {colors.primary-cta-fill}, textColor: {colors.on-primary-cta}, typography: {typography.body-sm}, rounded: {rounded.pill}, padding: 12px 24px
- button-accent-blue: backgroundColor: {colors.accent-blue}, textColor: {colors.ink}, typography: {typography.body-sm}, rounded: {rounded.pill}, padding: 16px 32px
- button-accent-yellow: backgroundColor: {colors.accent-yellow}, textColor: {colors.ink}, typography: {typography.body-sm}, rounded: {rounded.pill}, padding: 16px 32px
- button-accent-pink: backgroundColor: {colors.accent-pink}, textColor: {colors.ink}, typography: {typography.body-sm}, rounded: {rounded.pill}, padding: 16px 32px
- hero-band-dark: backgroundColor: {colors.canvas-dark}, textColor: {colors.on-dark}, typography: {typography.display-lg}, padding: {spacing.section}
- hero-band-light: backgroundColor: {colors.canvas-light}, textColor: {colors.primary}, typography: {typography.display-lg}, padding: {spacing.section}

Color rationale: Brand & Primary - Aubergine ({colors.primary} — 3c315b): The structural spine of the system. Used for heading text, navigation text, icon strokes, and as the background for all dark-mode sections ({colors.canvas-dark}). - Ghost Lavender ({colors.primary-cta-fill} — e2dffe): The primary action color, used for filled button backgrounds. It's a very light lavender that acts as a subtle tint on the light canvas. - Periwinkle ({colors.secondary} — ab9ff2): A brighter, more saturated lavender used for secondary actions, decorative fills, and icon accents. Accent Palette A "candy store" set of pastel tints used for button variants to create variety in multi-action contexts. - Cornflower Pop ({colors.accent-blue} — 4a87f2): A vivid blue used sparingly for a high-energy interruption. - Buttercream ({colors.accent-yellow} — ffffc4): A pale yellow for tonal variety. - Blush Mist ({colors.accent-pink} — ffdadc): A near-gray pink, the softest of the pastel set. Semantic - Mint Signal ({colors.success} — 2ec08b): A vivid green used exclusively for success badges, status indicators, and positive confirmation states. Surface - Canvas Light ({colors.canvas-light} — fdfcfe): The default page backgr...

Typography rationale: Font Family The system uses a custom typeface for all display and body copy. The fallback stack is Inter, Söhne, DM Sans, -apple-system, sans-serif. The defining characteristics are its whisper-light weight and tight letter-spacing. - Default Weight: 350 is the default for everything from large display headlines to button labels. Weight 400 is reserved only for body copy that requires slightly more presence for legibility. Heavy weights (600+) are intentionally absent. - Letter Spacing: A universal -0.025em tracking is applied to all type sizes. This is a non-negotiable rule that gives headlines their signature compressed, high-density appearance. Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.hero-display} | 96px | 350 | 1.0 | -2.4px | Top-level hero headlines | | {typography.display-lg} | 64px | 350 | 1.1 | -1.6px | Section hero headlines | | {typography.title-lg} | 30px | 350 | 1.21 | -0.75px | Major section titles | | {typography.title-md} | 24px | 350 | 1.25 | -0.6px | Card titles, sub-section heads | | {typography.title-sm} | 20px | 350 | 1.35 | -0.5px | Small subheadings | | {typography.body-md} | 16px | 400...

Layout system: Spacing System - Base unit: 4px. - Tokens: {spacing.xxs} 4px · {spacing.xs} 8px · {spacing.sm} 12px · {spacing.md} 16px · {spacing.lg} 24px · {spacing.xl} 32px · {spacing.xxl} 48px · {spacing.section} 64px. - Section padding (vertical): {spacing.section} (64px) is the standard gap between major content blocks. - Card internal padding: {spacing.xxl} (48px) — generous internal whitespace is a key feature of content cards. - Gutters: {spacing.md} (16px) is common between elements in a row; {spacing.xs} (8px) is used for tighter groupings. Grid & Container - Max content width: ~1200px, centered. - Density: The system is comfortable and spacious. It relies on generous padding and section gaps to create a calm, uncluttered feel.

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | Flat | No shadow, 1px {colors.hairline-on-light} border for separation | Default for all surfaces: body, cards, navigation. The system is fundamentally flat. | | Subtle Glow | rgb(226, 223, 254) 0px 0px 4px 0px | A soft, 4px halo in {colors.focus-ring} used exclusively on the {component.button-primary}. This is the only form of shadow in the system. | The elevation philosophy is flat surfaces separated by color and hairlines. Depth is created by alternating between light ({colors.canvas-light}) and dark ({colors.canvas-dark}) sections, not by layering with shadows.

Shape language: Border Radius Scale | Token | Value | Use | |---|---|---| | {rounded.xs} | 4px | Small, subtle corners, rare. | | {rounded.sm} | 16px | Softer corners on minor elements. | | {rounded.md} | 24px | Standard radius for content cards. | | {rounded.lg} | 32px | Larger radius for inline link containers. | | {rounded.pill} | 100px | The signature radius. Used for all buttons, navigation bars, and tags. This is the default for interactive elements. | | {rounded.full} | 100px | Alias for pill. | The system's shape language is defined by the {rounded.pill}. Sharp corners are intentionally avoided. Every container should feel soft and capsule-like.

Component language: Top Navigation top-nav — A pill-shaped container with a {rounded.pill} (100px) radius. It has a {colors.canvas-light} background and contains navigation links set in {typography.nav-link} with {colors.primary} text. The pill geometry is a defining signature. Buttons button-primary — The primary call-to-action. A pill button ({rounded.pill}) with a {colors.primary-cta-fill} background and {colors.on-primary-cta} text. This button receives the system's only shadow: a subtle 4px glow. button-secondary — An inline link styled as a smaller pill button. Uses the same lavender fill and aubergine text as the primary button but with smaller padding and font size. button-accent- — A set of pastel-colored pill buttons used for variety when multiple actions are presented together. They share the same {rounded.pill} shape and {typography.body-sm} type but use different background colors: {colors.accent-blue}, {colors.accent-yellow}, and {colors.accent-pink}. Text is always {colors.ink} for contrast. Cards & Containers hero-band-dark — A full-bleed hero section with an inverted color scheme. It uses a {colors.canvas-dark} background with {colors.on-dark} text set in {typography.display-lg}. Cre...

Guardrails: Do - Use {rounded.pill} (100px) for all navigation containers, buttons, and tags. The pill geometry is the system's defining silhouette. - Set all text at weight 350 by default. Reserve weight 400 only for body copy that needs extra legibility. - Apply -0.025em letter-spacing to every type size. The tight tracking is non-negotiable for brand fidelity. - Use {colors.primary-cta-fill} (lavender) as the primary CTA background, paired with its subtle glow shadow. - Alt...
```
