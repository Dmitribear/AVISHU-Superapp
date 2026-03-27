# High-End Editorial Design System Document

## 1. Overview & Creative North Star
**Creative North Star: The Industrial Monolith**
This design system rejects the "friendly" softness of modern SaaS in favor of an authoritative, high-fashion editorial experience. It is inspired by the stark layouts of *Vogue* and the brutalist architectural purity of fashion houses like *Celine* or *COS*. 

We move beyond standard UI by treating the screen as a printed page. By utilizing intentional asymmetry, high-contrast typography, and extreme negative space, we create an environment that feels curated, not "templated." The goal is visual tension—where the silence of the white space is just as loud as the heavy black blocks.

---

## 2. Colors
The palette is restricted to a high-contrast grayscale to ensure the product (imagery) remains the sole focus. 

### Tonal Hierarchy
- **Primary (`#000000`)**: Used for text dominance, primary CTAs, and structural borders.
- **Surface (`#f9f9f9`)**: The base of our canvas. It provides a slightly softer white to reduce eye strain while maintaining a clean, premium feel.
- **Grayscale Tiers**: Use `surface-container-low` (#f3f3f4) and `surface-container-highest` (#e2e2e2) to distinguish different functional zones.

### The "No-Line" Rule & Tonal Layering
While the prompt allows for 1px borders, as a signature rule, **avoid using lines to define containers.** Boundaries must be defined through background color shifts. For example, a `surface-container-low` section sitting on a `surface` background creates a natural, "industrial" separation without the clutter of a stroke.

### Signature Textures
To prevent the UI from feeling "flat," we utilize the **Matte Overlay**. Use solid `primary` (#000000) blocks for CTAs with `on-primary` (#e2e2e2) text. This provides a "heavy" visual weight that feels expensive and deliberate.

---

## 3. Typography
Typography is the backbone of this system. It isn’t just for reading; it is the primary decorative element.

- **Typeface**: Inter (Clean Grotesk).
- **Headings (Display, Headline, Title)**: 
    - **CASE**: ALL UPPERCASE.
    - **Letter Spacing**: +5% (High tracking is mandatory for the "luxury" look).
    - **Weight**: Bold or Semi-bold to create "typographic blocks."
- **Body & Labels**: 
    - **CASE**: Sentence case for readability.
    - **Letter Spacing**: Normal to +2%.
    - **Usage**: Use `body-md` for standard descriptions. Pair with `label-sm` for metadata (e.g., "SIZE: L" or "ORDER #2031").

---

## 4. Elevation & Depth
In a system that forbids shadows and glossy effects, depth is achieved through **Tonal Stacking**.

- **The Layering Principle**: Depth is a vertical hierarchy of grayscale values. Place a `surface-container-lowest` (#ffffff) card on a `surface-container-low` (#f3f3f4) background to create a "lift" effect. 
- **The "Ghost Border"**: When a border is necessary for structural integrity (like in the provided task list), use the `outline-variant` (#c6c6c6) at 1px. Do not use 100% black for internal dividers; it creates too much visual noise.
- **Strict Corner Radius**: Every corner is `0px` by default. A maximum of `4px` is allowed only for interactive components like small tags or chips to differentiate them from structural layout blocks.

---

## 5. Components

### Buttons
- **Primary**: Solid Black (`primary`) block, no rounding, `on-primary` text. Padding: `16px 32px`.
- **Secondary**: 1px Black border, transparent background, black text.
- **Tertiary**: Text-only, All-Caps, Underlined (1px).

### Input Fields
- **Style**: A single 1px bottom border (`outline`) or a fully enclosed box with 1px `outline-variant`.
- **States**: On focus, the border-weight increases to 2px `primary`. No glows or soft transitions.

### Cards & Lists
- **The No-Divider Rule**: Forbid the use of divider lines inside cards. Instead, use a minimum of `24px` vertical white space (Spacing `6`) to separate content units.
- **Layout**: Utilize the "Editorial Grid." Images should take up significant real estate (e.g., a 1:1 or 4:5 aspect ratio) with text placed in high-contrast blocks beneath or overlapping the edge of the image.

### Navigation / Tabs
- **Style**: Simple text links in `label-md`. The active state is indicated by a 2px black underline or a solid black block background with white text.

---

## 6. Do's and Don'ts

### Do:
- **Use Extreme Padding**: If you think there is enough whitespace, add 20% more. Padding should range from `20px` to `40px` (Spacing `8` to `12`).
- **Embrace Asymmetry**: Align text to the left but allow images to break the grid or sit off-center to mimic a magazine layout.
- **Focus on the Grid**: Use the 1px `outline-variant` to create a "blueprint" feel for the app's structure.

### Don't:
- **No Gradients/Shadows**: If a component feels "flat," adjust the background color or typography size rather than adding a shadow.
- **No Rounded Corners**: Never use "pills" or high-radius buttons. We value sharp, industrial edges.
- **No Color**: Do not introduce accent colors. Red (`error`) is only permitted for critical system failures.
- **No Standard Icons**: Use ultra-thin, stroke-based icons (1px weight) to match the "Industrial" aesthetic. Avoid filled or "bubbly" icon sets.

---

## 7. Spacing Scale Reference
- **Micro (0.5 - 2)**: For internal component spacing (text to icon).
- **Standard (3 - 5)**: For grouping related items within a card.
- **Macro (8 - 20)**: For section margins and screen-edge padding. This is where the "Editorial" feel lives.