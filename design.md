# OOB Menu — Visual Design Specification

This document is the source of truth for the visual design of the OOB / Out of Boredom tablet menu. If anything in `CLAUDE.md` conflicts with this file, **this file wins**.

---

## ⚠️ Color rule (read first)

**Every color in this design is a flat, solid fill.**

- No gradients anywhere. Not on the pills, not on the cards, not on the buttons, not on the backgrounds.
- No "soft" highlights, no inner shadows, no plump 3D effects.
- No background blurs, no glass morphism, no glow.
- No opacity fades on fills (text can have alpha, fills cannot).

If a UI element looks like it has a gradient, look again. It is a single solid color sitting on the cream background. Any perceived softness comes from the surrounding cream, never from the element itself.

The only drop shadows allowed are extremely subtle, used only on the bottom tab bar's active pill for affordance (`blur: 8, y: 2, color: rgba(0,0,0,0.08)`). Pills and cards on the page itself have **no shadows**.

---

## 1. Color palette

Six tokens, all solid hex values, no variants.

| Token | Hex | Usage |
|---|---|---|
| `cream` | `#F4F2EC` | Page background. Warm off-white, slightly desaturated. Never use pure white. |
| `navy` | `#1B2A56` | Primary brand. Pill fills, body text, Tsuki card, NO MILK tag. |
| `orange` | `#E87530` | OOB Blend card, WITH MILK tag border, SPECIALTY DRINKS tag fill, accent item names, accent prices, OOB logo. |
| `mutedNavy` | `#4A5573` | Italic descriptor text only. Slightly lighter than `navy`. |
| `white` | `#FFFFFF` | All text on `navy` and `orange` surfaces. |
| `divider` | `#1B2A56` at 30% alpha on text | Used only for the thin vertical bar `│` in the footer wordmark. |

Two ink colors. One paper color. That is the entire system.

---

## 2. Typography system

Three font families, used with discipline.

### Display sans (all caps, tracked)
- Recommendation: **Manrope ExtraBold (800)** or **DM Sans Bold (700)**
- Letter spacing: `+3%` to `+5%`
- Used for: pill header titles, section eyebrows
- Examples: `WHISKING METHOD:`, `HANDPICKED MATCHA`, `MATCHA LATTE:`, `SPECIALTY DRINKS`

### Body humanist sans (mixed weight)
- Recommendation: **Mulish** or **Sora**, weights 400, 600, 700
- Used for: item names (Bold 700), prices (Regular 400), subtitles inside pills (Regular 400)
- Italic variant used for all descriptors ("Signature Black Sesame cream", "Espresso and milk")
- Examples: `Black Sesame Matcha`, `OOB Blend`, `Tsuki`, `₱ 260.00`

### Serif wordmark (footer only)
- Recommendation: **Cormorant Garamond** or **Playfair Display**, italic for WHISK'RS, regular for OUT OF BOREDOM
- Wide letter spacing on `BOREDOM` (~+8%)
- Used only in the footer composition, nowhere else in the UI

### Price formatting rules
- Inside powder cards: `₱ 210` (one space, no decimals)
- In specialty drink lists and pill headers: `₱ 260.00` (one space, two decimals)
- Currency symbol is `₱` (U+20B1) followed by a regular space, then the number
- Use tabular figures (`FontFeature.tabularFigures()`)

### Letter spacing summary
- Display caps: `+3%` to `+5%`
- Body bold: `0%`
- Wordmark BOREDOM: `+8%`
- WHISK'RS: `+6%` (italic, wide)

---

## 3. The Pill component

The pill is the primary structural element of this menu. Almost every section header, every section tag, and the active tab indicator is a pill. Build this widget first.

### Geometry
- Shape: rounded rectangle with corner radius = `height / 2` (a true capsule, both ends are perfect semicircles)
- Padding: `20dp` horizontal, `14dp` vertical
- Width: never full page width. Pills always have visible cream space on at least one side, usually the right.
- No border, no shadow, no gradient. **Solid fill only.**

### Fill rules
- Section header pills: `navy` fill
- WITH MILK vertical tag: **outlined** (transparent fill, 2dp orange border)
- NO MILK vertical tag: `navy` fill
- SPECIALTY DRINKS vertical tag (coffee page): `orange` fill
- Active bottom tab indicator: `navy` fill

### Three pill variants

**Variant A: Title-only pill (compact)**
- Used for `WHISKING METHOD:` at top of matcha page
- Two text lines stacked inside:
  - Line 1: title in white display caps, tracked
  - Line 2: subtitle in white body regular, sentence case, slightly smaller
- Sized to content, roughly 38% of content width
- Left-aligned to content margin

**Variant B: Title + trailing price pill (wide)**
- Used for `HANDPICKED MATCHA` and `HOUJICHA LATTE` on matcha page
- Single row of content with two text blocks stacked inside the row:
  - Left text block: title (white display caps, tracked) on top, subtitle (white body regular) below
  - Right text block: price `₱ 360.00` in white body bold, right-aligned at the pill's right edge
- Stretches ~70% of content width, left-aligned

**Variant C: Two-row content pill (the add-ons block)**
- Used only for the More caffeine! / Make it big block at bottom of coffee page
- Two rows stacked inside the pill, no divider line between them, just vertical spacing
- Each row:
  - Left: title (white body bold, larger) with descriptor (white regular, smaller) directly below the first word
  - Right: price `₱ 50.00` in white body regular, right-aligned
- Stretches ~70% of content width

### Vertical tag pill (coffee page only)
- Same capsule shape, rotated 90 degrees so the text reads bottom-to-top
- Width (after rotation): ~36-40dp
- Height: spans the full height of its associated item list
- Three style variants (see fill rules above)
- Positioned to the LEFT of the item list with ~24dp horizontal gap

---

## 4. The Powder Cards (Matcha page only)

These are NOT pills. They are rounded rectangles. Different shape on purpose.

### Geometry
- Corner radius: ~14dp (not full pill)
- Padding: ~16dp on all sides
- Two cards sit side-by-side with a small gap between them (~12dp)
- Combined width spans roughly 50% of page content width
- Each card is roughly square or slightly taller than wide

### OOB Blend card
- Fill: solid `orange` (`#E87530`)
- Title at top: `OOB Blend` (white, body Bold, NOT all caps)
- Three price rows stacked below:
  - `₱ 210`
  - `₱ 240`
  - `₱ 270`
- All text white, left-aligned inside the card with consistent left padding
- Each price row vertically aligns with the corresponding "Level X" label outside the card

### Tsuki card
- Fill: solid `navy` (`#1B2A56`)
- Title at top: `Tsuki` (white, body Bold)
- Prices: `₱ 230`, `₱ 260`, `₱ 290`
- Same dimensions and internal layout as OOB Blend card

### No shadow, no gradient, no inner highlight
The cards are flat colored rectangles. The only thing distinguishing them from the cream is the solid fill color and rounded corners.

---

## 5. Matcha page layout (top to bottom)

### Section 1: Whisking Method
- **Pill (Variant A):** navy fill, left-aligned at content margin, ~38% width
  - Line 1: `WHISKING METHOD:` (white, display caps, tracked)
  - Line 2: `Select your preferred method` (white, body regular, smaller)
- **Below the pill, indented from the pill's left edge by ~12dp:**
  - Row 1: `Cold Whisk` (navy, body bold, **underlined**) + small bullet `•` + `Less astringent | Creamy | Less Caffeine` (navy, body regular)
  - Row 2: `Traditional` (navy, body bold, **underlined**) + `•` + `Bodied | Smooth | More Caffeine`
- Vertical bars between traits are pipe characters `|`, not custom dividers

### Section 2: Matcha Latte title
- `MATCHA LATTE:` (navy, display caps, tracked, left-aligned at content margin)
- Directly below, tucked tight: `Pick your powder` (navy, body regular, sentence case, smaller)

### Section 3: Powder selection (two-column layout)
- **Left column (~50% width):** three rows of level labels, vertically aligned with the price rows in the cards on the right
  - `Level 1 ` (body bold) + `(Light)` (body italic, regular weight)
  - `Level 2 ` + `(Balanced)`
  - `Level 3 ` + `(Umami)`
  - Vertical spacing between rows: ~28dp
- **Right column (~50% width):** the two powder cards side by side (see section 4 above)

### Section 4: Single cultivars footnote
- `For single cultivars, ask your Barista...` (navy, body italic, smaller)
- Left-aligned at content margin, sits below the powder cards

### Section 5: Handpicked Matcha
- **Pill (Variant B):** navy fill, ~70% content width, left-aligned
- Title: `HANDPICKED MATCHA` + trailing `₱ 360.00`
- Subtitle: `A 200 year old craft preserved in modern day`

### Section 6: Specialty Drinks (matcha)
- Eyebrow label: `SPECIALTY DRINKS` (navy, display caps, tracked, regular weight, smaller than pill titles)
- Five item rows. Each row:
  - **Left block:** item name in body Bold navy on top line, descriptor in body italic mutedNavy on bottom line
  - **Right block:** price in body regular navy, right-aligned
  - Vertical spacing between items: ~16-20dp
- Items in order:
  1. Black Sesame Matcha / Signature Black Sesame cream / ₱ 260.00
  2. Himalayan Matcha / Salted Cream / ₱ 260.00
  3. Matcha-cho / Matcha and Chocolate / ₱ 260.00
  4. Strawberry Matcha / Signature Strawberry jam / ₱ 290.00
  5. Earl Grey Matcha / Matcha and Earl Grey tea / ₱ 260.00

### Section 7: Houjicha Latte
- **Pill (Variant B):** navy fill, ~70% content width
- Title: `HOUJICHA LATTE` + trailing `₱ 210.00`
- Subtitle: `Roasted Matcha`

### Section 8: Specialty Drinks (houjicha)
- Same eyebrow `SPECIALTY DRINKS`
- Two item rows:
  1. Dirty Houjicha / Espresso and Roasted Matcha / ₱ 220.00
  2. Himalayan Houjicha / Houjicha and Salted cream / ₱ 240.00

### Section 9: Footer wordmark (matcha page version)
Custom composition, horizontally centered on the page:

```
                      ─ OUT OF ─
   WHISK'RS    │       BOREDOM
```

- `WHISK'RS` on the left in **serif italic** (Cormorant Garamond), tracked +6%
- A thin vertical divider `│` between the two halves (navy, 30% alpha, very subtle)
- Right side, two stacked elements:
  - Top: `OUT OF` flanked by short horizontal navy lines on both sides (pennant feel)
  - Bottom: `BOREDOM` in **serif regular**, tracked +8%, slightly larger than `OUT OF`
- All elements navy
- Entire composition centered horizontally

---

## 6. Coffee page layout (top to bottom)

### Section 1: OOB logo header
- Top of page, left-aligned at content margin
- Stylized **asymmetric arch shape** in solid `orange` (looks like `Λ` or a doorway), the arch leans slightly
- Immediately followed by `OB` in solid `orange`, body bold humanist sans, no space
- Total visual reads as `[arch]OB` where the arch is the stylized first O
- Size: ~48-56sp tall

### Section 2: WITH MILK group

**Vertical tag (left side of group):**
- **Outlined pill:** transparent fill, 2dp solid `orange` border
- Text `WITH MILK` rotated 90 degrees (reads bottom-to-top), orange display caps, tracked
- Height spans the four items below
- Width ~36-40dp
- Positioned with ~24dp gap before the item list

**Item list (right of tag):** Four rows. Each row:
- Top line: `White` (body Bold, **navy**) + ` | ` (small) + `milk-based` (body regular, smaller, navy)
- Bottom line: descriptor in body italic, mutedNavy, smaller
- Right side: price in body regular, **orange**, right-aligned

Items:
1. White / Espresso and milk / ₱ 160.00
2. Spanish Latte / Espresso and sweetened milk / ₱ 170.00
3. Mocha / Espresso, chocolate, and milk / ₱ 180.00
4. Dirty Matcha / Espresso, Matcha, and oat milk / ₱ 220.00

### Section 3: NO MILK group

**Vertical tag:**
- **Filled pill:** solid `navy` fill
- Text `NO MILK` rotated 90 degrees, **white** display caps, tracked
- Height spans the two items

**Item list:** Two rows. Color inversion here:
- Item names in **orange**, NOT navy
- `| water-based` and descriptors in navy
- Prices in **navy**, NOT orange

Items:
1. Black / Espresso and H₂O / ₱ 140.00
2. Tonic Espresso / Espresso and sparkling water / ₱ 170.00

### Section 4: SPECIALTY DRINKS group

**Vertical tag:**
- **Filled pill:** solid `orange` fill
- Text `SPECIALTY DRINKS` rotated 90 degrees, **white** display caps, tracked
- Height spans the five items below

**Item list:** Five rows. Mixed color pattern:
1. Eclipse (navy name) / Espresso and Mango / ₱ 190.00 (orange price)
2. Newton (navy name) / Espresso and Apple / ₱ 190.00 (orange)
3. Black Sesame Latte (navy name) / Signature Black Sesame cream / ₱ 190.00 (orange)
4. Himalayan Latte (navy name) / Salted Cream / ₱ 190.00 (orange)
5. Sol (**orange name**, featured) / Mango, Pomegranate, Lemon / ₱ 200.00 (orange)

### Section 5: Add-ons pill
- **Pill (Variant C):** solid navy fill, ~70% content width, left-aligned (or slightly offset)
- Row 1: `More caffeine!` (white body bold, large) with `Extra shot` (white regular, smaller) below the first word, and `₱ 50.00` right-aligned
- Row 2: `Make it big` (large) with `Up-size your cup` (smaller below), and `₱ 50.00` right-aligned
- No divider between rows, just spacing

### Section 6: Footer (coffee page version)
Same composition as matcha footer but **only the right half** is shown:

```
   ─ OUT OF ─
    BOREDOM
```

Centered horizontally. No WHISK'RS on this page.

---

## 7. Bottom tab bar (both pages)

A persistent footer on cream background, below all content.

- Three tab labels, evenly distributed horizontally: `Matcha`, `Coffee`, `Most Ordered`
- Active tab: wrapped in a **navy filled pill** (corner radius = height / 2, ~12dp vertical padding, ~28dp horizontal padding, white text)
- Inactive tabs: plain navy text, **no background, no border, no underline**
- The active pill is the only UI element in the entire design that gets a drop shadow, and even that is subtle (`blur: 8, y: 2, color: rgba(0,0,0,0.08)`)

On matcha page: `Matcha` has the pill. On coffee page: `Coffee` has the pill. On most ordered page: `Most Ordered` has the pill.

---

## 8. The orange-vs-navy item name rule

This is the most easily missed pattern in the menu. Item names switch between solid `navy` and solid `orange` based on emphasis:

- **Default:** item names are `navy`
- **Featured items get orange names:** Black, Tonic Espresso (the two NO MILK coffees) and Sol (the signature soda)
- **The price inversion follows the category, not the item:**
  - WITH MILK section: prices in `orange`
  - NO MILK section: prices in `navy`
  - SPECIALTY DRINKS section (coffee): prices in `orange`
  - Matcha specialty drinks: prices in `navy`

This is a designed inversion. It is intentional. Implement it exactly as observed in the photos, not as you might guess.

---

## 9. Spacing & rhythm

8-point grid throughout.

| Spacing token | Value | Used for |
|---|---|---|
| `xs` | 4dp | Tight (between currency symbol and price number) |
| `sm` | 8dp | Between item name and descriptor |
| `md` | 16dp | Between menu rows, internal pill padding (vertical) |
| `lg` | 24dp | Between sections, gap between vertical tag and item list |
| `xl` | 32dp | Page content horizontal padding |
| `xxl` | 48dp | Top of page before first content, between major groups |

Vertical rhythm between sections is generous. Do not crowd.

---

## 10. Page-level layout

### Content margins
- Top padding: ~48dp from screen edge to first content
- Bottom padding: ~32dp from last content to top of tab bar
- Left content margin: ~32dp (where pills, eyebrows, and item rows start)
- Right content margin: ~32dp (where prices end)

### Background
- Solid `cream` (`#F4F2EC`) across the entire screen
- No texture, no noise, no paper grain. Just flat color.
- The tab bar background is the same `cream`.

---

## 11. What this design is NOT

To prevent re-introducing the wrong style, here is what the menu must avoid:

- ❌ Gradients on any surface
- ❌ Drop shadows on pills, cards, or item rows
- ❌ Inner highlights or "plumpness" effects
- ❌ Glass morphism, blur, or translucency
- ❌ Glow or breathing animations on solid pills (motion is for interaction, the colors stay flat)
- ❌ Pure white anywhere (`#FFFFFF` is for text on dark fills only, never as a background)
- ❌ Em dashes in any UI copy (use pipes, commas, ellipses, bullets)
- ❌ Centered content on the matcha page (it is left-anchored with the powder cards offset right)
- ❌ Underlines on item names (only Cold Whisk / Traditional in the whisking method section are underlined)
- ❌ Borders around menu rows
- ❌ Decorative dividers between sections (rely on spacing)

---

## 12. Implementation checklist

When a screen is "done" visually, all of these must be true:

- [ ] Background is solid `#F4F2EC` cream
- [ ] All pills are solid color fills, no gradients
- [ ] Powder cards are solid color fills, no shadows
- [ ] Vertical tags on coffee page use the three correct styles (outlined orange, filled navy, filled orange)
- [ ] Item names follow the orange/navy emphasis rule from section 8
- [ ] Prices follow the per-section color rule from section 8
- [ ] Pill headers (Variants B and C) contain their prices INSIDE the pill, right-aligned
- [ ] Footer wordmark on matcha page has both WHISK'RS and OUT OF BOREDOM; coffee page has only OUT OF BOREDOM
- [ ] Active tab is a solid navy pill, inactive tabs are plain text
- [ ] No em dashes appear in any visible string
- [ ] Currency formatting matches the source (`₱ 210` in cards, `₱ 260.00` in lists)
- [ ] All fonts loaded: display sans for caps, humanist sans for body, serif for wordmark
- [ ] No drop shadows except the active tab pill (subtle)
