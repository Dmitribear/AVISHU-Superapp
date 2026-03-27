# Design System Strategy: Industrial Editorial

## 1. Overview & Creative North Star
The Creative North Star for this system is **"The Monolithic Archive."** 

Unlike standard e-commerce platforms that prioritize "friendliness" and "softness," this design system embraces an austere, industrial luxury. It is a digital manifestation of a high-end fashion gallery—cold, precise, and uncompromising. We break the "template" look by treating the screen as a printed broadsheet. By utilizing extreme white space (up to `8.5rem`), we force the user to focus on a single, curated piece of content at a time. The hierarchy is driven by massive scale contrasts: a `display-lg` headline sitting next to a microscopic `label-sm` technical spec.

The goal is not to be "usable" in the traditional sense of high-speed consumption, but to be "experiential," demanding the user’s full attention through a layout that feels architectural rather than fluid.

---

## 2. Colors
The palette is restricted to a high-contrast grayscale to ensure the fashion photography remains the only source of "life" in the interface.

*   **Primary (#000000):** Used for all structural elements, text, and primary CTAs. It represents the "Ink."
*   **Surface (#F9F9F9):** Our default canvas. It is a "Warm White" that prevents the eye-strain of pure #FFFFFF while maintaining an expensive, paper-like quality.
*   **The "No-Shadow" Mandate:** Shadows are strictly prohibited. Depth is an illusion we do not require. We define space through `outline` tokens and tonal shifts.

### Surface Hierarchy & Nesting
To create organization without using shadows or rounded containers, we use the "Stacked Sheet" approach:
1.  **Base Layer:** `surface` (#F9F9F9) for the overall page background.
2.  **Sectioning:** Use `surface-container-low` (#F3F3F4) for large editorial blocks to subtly shift the mood.
3.  **Active Elements:** Use `surface-container-highest` (#E2E2E2) only for interactive background states (hover/press) to maintain a tactile, industrial feel.

### The "Ghost Border" Rule
While the original request allows 1px borders, we must use them with surgical intent. Use the `outline` token (#777777) for structural dividers and the `outline-variant` (#C6C6C6) for secondary containment. Borders should never be used to "box things in" entirely; prefer open-ended lines that bleed off the edge of the screen, mimicking architectural blueprints.

---

## 3. Typography
Typography is the primary vehicle for the brand’s "Industrial Luxury" atmosphere. We use **Inter** exclusively, but we treat it as a structural material.

*   **Headings (Display/Headline):** Must be **ALL CAPS** with a letter-spacing of `+5%`. This creates an authoritative, "monumental" look. 
    *   *Example:* `ОСЕНЬ / ЗИМА 2024`
*   **Body Text:** Set in `body-md` or `body-lg`. In Russian (Cyrillic), Inter can feel dense; increase line-height to `1.6` to ensure the "Magazine" readability.
*   **Technical Labels:** Use `label-sm` in ALL CAPS for metadata (e.g., "SKU 00192", "SIZE 42"). These should be treated as "stamps" on a technical drawing.

---

## 4. Elevation & Depth
In this system, "Elevation" is a misnomer. We do not elevate; we **divide.**

*   **Tonal Layering:** Instead of a shadow, a "floating" modal is simply a `surface-container-lowest` (#FFFFFF) box with a 1px `primary` (#000000) border. It sits on top of the background, creating a sharp, flat overlap.
*   **The "Zero-Radius" Principle:** Although a 4px radius is allowed, the system defaults to **0px**. Use the 4px radius (`DEFAULT` in the scale) *only* for interactive components like small buttons or input fields to provide a micro-hint of "touchability." Everything else must be sharp.
*   **Intentional Asymmetry:** Break the grid. Place a `display-md` heading 20px from the left edge, but place the corresponding `body-md` text 80px from the left. This "editorial offset" prevents the UI from looking like a standard Bootstrap template.

---

## 5. Components

### Buttons
*   **Primary:** Solid `primary` (#000000) background, `on-primary` (#E2E2E2) text, ALL CAPS. 0px radius.
*   **Secondary:** No background. 1px `outline` (#777777) border. 
*   **Interaction:** On hover, the button should invert (e.g., Black becomes White) instantly. No slow transitions; the interaction should feel mechanical and "clicky."

### Input Fields
*   **Styling:** A single 1px bottom border using `outline`. No containing box. 
*   **Labels:** Labels float above the line in `label-sm` ALL CAPS.
*   **Error State:** Use `error` (#BA1A1A) only for the text. Do not change the border color unless necessary for accessibility; instead, use a high-contrast weight change.

### Cards & Product Grids
*   **The "No-Divider" Rule:** In product lists, do not use lines between items. Use the `spacing-20` (7rem) or `spacing-24` (8.5rem) tokens to create massive gaps. The whitespace *is* the divider.
*   **Imagery:** Photos must be sharp-edged. No rounded corners on product shots.

### Navigation (The Sidebar/Header)
*   **Layout:** Use an oversized header with `title-lg` labels. 
*   **Industrial Detail:** Include small technical details like "v.2.04" or coordinates in the corners of the screen using `label-sm` to lean into the "Industrial" vibe.

---

## 6. Do’s and Don’ts

### Do:
*   **Embrace the Cyrillic Aesthetic:** Cyrillic characters are more "square" than Latin. Lean into this by using tight leading for headers.
*   **Use Massive Whitespace:** If a section feels "crowded," double the spacing. A "Premium" feel is directly proportional to how much "empty" space you can afford to leave on the screen.
*   **Align to a Hard Grid:** Even if elements are offset, they must align to a strict underlying column system. Randomness is the enemy of brutalism.

### Don’t:
*   **No Gradients:** If you feel the need to use a gradient for "depth," you have failed the design system's core philosophy. Use a solid gray (`surface-dim`) instead.
*   **No "Soft" Language:** Buttons should say "КУПИТЬ" (BUY) or "ДОБАВИТЬ" (ADD), not "Пожалуйста, добавьте в корзину" (Please add to cart).
*   **No Standard Iconography:** Avoid "bubbly" or rounded icons. Use thin-stroke (1px), sharp-cornered icons that match the `inter` font weight.