# Blaze

**ID:** `blaze`  
**Category:** consumer  
**Theme:** dark  
**Vibe:** Bold

## Color palette

- `#ff4100`
- `#ffc700`
- `#f6e653`
- `#1573dd`
- `#292a2c`
- `#000000`
- `#fdbeba`
- `#fee3c1`

## Typography

Families: "Open Sans, sans-serif", "nimbus-sans-extended-bold, Helvetica Inserat, sans-serif", "nimbus-sans-extended-regular, Helvetica Neue Extended, sans-serif", "obviously-condensed-semibold, Bebas Neue, sans-serif". Weights: 400.

## Compiled style prompt

```
STYLE SOURCE: DESIGN.md (compiled style only; source filename and brand examples are not slide content)

Design system name: Lamanna

Design token description: A maximalist, high-energy interface defined by screaming color confidence. The system is anchored on a saturated orange-red canvas (ff4100), with sunshine-yellow (ffc700) display type and a blush-pink (fdbeba) secondary the source brand creating a vibrant three-color rhythm. Typography is a primary design element, featuring an ultra-wide, squished-black display face set at near-zero line-height, forcing headlines into massive, solid blocks. Layout is aggressively full-bleed and edge-to-edge with no containers; sections are separated by hard color changes, not whitespace. The system relies on decorative energy, expecting graphical accents like zigzags and starbursts to be layered throughout.

STYLE-CONTENT FIREWALL:
- Treat DESIGN.md as style guidance only. It defines how to render, not what subject matter to show.
- The slide JSON title, bullets, and visual direction define the subject.
- Never infer the slide subject from the source brand, product category, examples, or filename.
- Detected source-domain vocabulary: consumer technology. Translate it into reusable visual behavior, not literal imagery.
- Avoid literal source imagery unless the exact slide text or visual direction explicitly requests it: phones, laptops, tablets, device mockups, or hardware product renders; app screenshots, operating-system chrome, or product launch hero shots.

Overall visual personality: The system is a maximalist, high-energy visual language defined by screaming color confidence and aggressive typography. The entire experience is anchored on a saturated orange-red canvas ({colors.canvas-primary}), which serves as the default page floor and primary the source brand color. Display type and decorative accents run in a vibrant sunshine-yellow ({colors.accent}) for maximum contrast. A secondary blush-pink ({colors.canvas-secondary}) band appears as a softer, full-bleed section to break the orange dominance. The primary voice is an ultra-wide, squished-black display face ({typography.hero-display}) set with extreme negative leading (0.89) to create solid typographic slabs. This is not an optional treatment; it's the core of the system's character. Layout is aggressively full-bleed and edge-to-edge with no max-width containers. Sections are separated by hard chromatic transitions, not by whitespace or borders. The system is unapologetically decorative. It expects graphical accents—zigzags, pointing hands, starburst shapes—to be used as integral parts of the layout, not as subtle additions. Every component is sharp-edged, with a system-wide {rounded} scale of 0px. There...

Color tokens:
- primary: #ff4100
- accent: #ffc700
- accent-soft: #f6e653
- accent-stroke: #1573dd
- ink: #292a2c
- ink-strong: #000000
- canvas-primary: #ff4100
- canvas-secondary: #fdbeba
- surface-subtle: #fee3c1
- on-primary: #ffc700
- on-secondary: #292a2c

Typography tokens:
- hero-display: family rightgrotesk-spatialblack-webfont, Bowlby One SC, sans-serif, size 54px, weight 400, line 0.89, tracking -0.49px
- display-lg: family rightgrotesk-spatialblack-webfont, Bowlby One SC, sans-serif, size 36px, weight 400, line 0.89, tracking -0.32px
- display-md: family nimbus-sans-extended-regular, Helvetica Neue Extended, sans-serif, size 36px, weight 400, line 0.89, tracking 0
- title-lg: family rightgrotesk-spatialblack-webfont, Bowlby One SC, sans-serif, size 30px, weight 400, line 1, tracking -0.27px
- title-md: family rightgrotesk-spatialblack-webfont, Bowlby One SC, sans-serif, size 24px, weight 400, line 1, tracking -0.26px
- title-sm: family nimbus-sans-extended-regular, Helvetica Neue Extended, sans-serif, size 21px, weight 400, line 1.48, tracking 0
- body-emphasis: family nimbus-sans-extended-bold, Helvetica Inserat, sans-serif, size 23px, weight 400, line 1.13, tracking -1.17px
- body-md: family Open Sans, sans-serif, size 22px, weight 400, line 1.67, tracking 0
- body-sm: family rightgrotesk-spatialblack-webfont, Bowlby One SC, sans-serif, size 18px, weight 400, line 1, tracking -0.36px
- body-xs: family Open Sans, sans-serif, size 18px, weight 400, line 1, tracking 0
- button: family obviously-condensed-semibold, Bebas Neue, sans-serif, size 32px, weight 400, line 1.16, tracking 0

Spacing tokens:
- xxs: 6px
- xs: 10px
- sm: 15px
- md: 20px
- lg: 30px
- xl: 40px
- xxl: 60px
- section: 100px

Radius and shape tokens:
- xs: 0px
- sm: 0px
- md: 0px
- lg: 0px
- xl: 0px
- pill: 0px
- full: 0px

Component tokens:
- hero-band: backgroundColor: {colors.canvas-primary}, textColor: {colors.accent}, typography: {typography.hero-display}, padding: {spacing.section} 0
- top-nav: backgroundColor: {colors.canvas-primary}, textColor: {colors.accent}, typography: {typography.body-sm}, height: 60px
- button-outlined: backgroundColor: transparent, textColor: {colors.ink}, typography: {typography.button}, rounded: {rounded.md}, padding: 6px 15px
- section-band-secondary: backgroundColor: {colors.canvas-secondary}, textColor: {colors.on-secondary}, typography: {typography.body-md}, padding: {spacing.section} 0
- product-badge-starburst: backgroundColor: {colors.accent}, textColor: {colors.ink}, typography: {typography.title-md}
- media-tile: backgroundColor: transparent, rounded: {rounded.md}

Color rationale: Brand & Canvas - Primary / Canvas Primary ({colors.primary} — ff4100): The dominant color. Used for the main page background, hero sections, and as the fill for primary content bands. It is the canvas itself. - Canvas Secondary ({colors.canvas-secondary} — fdbeba): A blush-peach color used for full-bleed secondary sections. It provides a visual break from the primary orange. - the source brand Subtle ({colors.surface-subtle} — fee3c1): A cream tint used for small decorative fills within secondary sections. Accent - Accent ({colors.accent} — ffc700): Sunshine yellow. The primary color for all display headlines, starburst badges, and decorative graphic elements like zigzags. It almost always sits on top of the orange primary canvas. - Accent Soft ({colors.accent-soft} — f6e653): A secondary, less saturated yellow for decorative shapes where the primary accent would be too aggressive. - Accent Stroke ({colors.accent-stroke} — 1573dd): A royal blue used exclusively for outlined strokes on interactive elements like link buttons and icons. It is never used as a fill. Text - Ink ({colors.ink} — 292a2c): The primary text color. A near-black charcoal used for body copy, subheadings, and li...

Typography rationale: Font Family The system uses a mix of highly characterful typefaces, each with a specific role. - rightgrotesk-spatialblack-webfont: The signature display face. An ultra-wide, compressed black sans-serif that defines the system's voice. Used for all major headlines. - nimbus-sans-extended-bold / regular: A wider sans-serif for subheadings and emphasized body copy, providing a slightly calmer alternative to the display face. - Open Sans: A neutral, readable sans-serif for longer passages of body copy where clarity is paramount. - obviously-condensed-semibold: A very narrow, punchy condensed face used exclusively for button and CTA labels. Hierarchy | Token | Size | Weight | Line Height | Letter Spacing | Use | |---|---|---|---|---|---| | {typography.hero-display} | 54px | 400 | 0.89 | -0.49px | Main page hero headlines. Forms a solid block. | | {typography.display-lg} | 36px | 400 | 0.89 | -0.32px | Large section titles, also with compressed leading. | | {typography.display-md} | 36px | 400 | 0.89 | 0 | Section titles using the secondary display face. | | {typography.title-lg} | 30px | 400 | 1 | -0.27px | Sub-section headings. | | {typography.title-md} | 24px | 400 | 1 | -0.26px | C...

Layout system: Spacing System - Base unit: An irregular, expressive scale. Tokens are named for convenience. - Tokens: {spacing.xxs} 6px · {spacing.xs} 10px · {spacing.sm} 15px · {spacing.md} 20px · {spacing.lg} 30px · {spacing.xl} 40px · {spacing.xxl} 60px · {spacing.section} 100px. - Section padding (vertical): {spacing.section} (100px) or {spacing.xxl} (60px) between major content zones. However, the primary separator is a hard color change, not whitespace. - Element Gaps: {spacing.xs} (10px) to {spacing.md} (20px) between adjacent elements within a section. Grid & Container The system is defined by its lack of a container. All layout is full-bleed and edge-to-edge. - Max content width: None. Content bands fill the viewport. - Grid: Content is typically center-aligned within the full-bleed bands. For multi-element layouts (like a product grid), a simple 3-column grid is used without gutters, relying on the element's own shape for separation. - Stacking: The entire page is a vertical stack of full-width color bands. The rhythm is typically: orange band - pink band - orange band. Whitespace Philosophy Whitespace is not a primary tool for separation. The system uses color and decorative elements...

Depth and hierarchy: | Level | Treatment | Use | |---|---|---| | Flat | Solid color fill, no border, no shadow | All page sections, backgrounds, and components | | Outlined | Transparent fill, 2px {colors.accent-stroke} border | Interactive links and buttons | | Typographic Shadow | Solid {colors.primary} text layer offset from {colors.accent} text | Used on select display headlines to create a 3D effect with zero blur | The elevation model is entirely flat. The system actively rejects box-shadow, gradients, and any other effect that would make an element appear to float. Depth is an illusion created through two techniques: 1. Chromatic Layering: Hard-edged color blocks layered on top of each other. 2. Solid Text Shadow: A faux-3D effect on headlines is created by duplicating the text layer, coloring it {colors.primary}, and offsetting it by a few pixels down and to the right. This creates a hard, graphical shadow, not a soft, blurred one.

Shape language: Border Radius Scale The entire system uses a border-radius of 0px. All elements are sharp and rectangular. | Token | Value | Use | |---|---|---| | {rounded.xs} | 0px | All elements | | {rounded.sm} | 0px | All elements | | {rounded.md} | 0px | All elements | | {rounded.lg} | 0px | All elements | | {rounded.xl} | 0px | All elements | | {rounded.pill} | 0px | All elements | | {rounded.full} | 0px | All elements | Decorative Shapes - Starburst: A multi-pointed star or sunburst shape, rendered in {colors.accent}. Used as the frame for featured content, functioning as the system's primary "card" or "badge." - Zigzag: A hand-drawn or geometric zigzag line, rendered in {colors.accent} with a 2-3px stroke. Used as a decorative border or separator between sections. - Pointing Hand: A cartoon-style graphic element used to direct attention. These are not subtle additions; they are core components of the visual language.

Component language: Navigation top-nav — A full-bleed bar at the top of the viewport. It has a {colors.canvas-primary} background, with link text set in {colors.accent} using {typography.body-sm}. Interactive elements may have a {colors.accent-stroke} outline. Buttons button-outlined — The primary interactive button. It has no background fill. It is defined by a 2px border in {colors.accent-stroke}. The text inside uses {typography.button} in {colors.ink}. All corners are sharp ({rounded.md}). Containers & Bands hero-band — A full-width section with a {colors.canvas-primary} background. It contains a massive headline in {typography.hero-display} and {colors.accent}, and is often paired with a large, sharp-edged media element. section-band-secondary — A full-width section with a {colors.canvas-secondary} background, used to provide a visual break. Text within this band uses {colors.on-secondary}. Content product-badge-starburst — The system's "card" component. It is not a rectangle but a starburst shape with a {colors.accent} backgr...
```
