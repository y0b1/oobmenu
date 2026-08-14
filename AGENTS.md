# OOB — Out of Boredom Menu (Flutter Android Tablet App)

A non-transactional, exploratory tablet menu for **OOB / Out of Boredom** (WHISK'RS line + coffee line). The app is a digital recreation of the printed menu, faithful to the original visual identity but elevated with smooth, playful motion. No cart. No checkout. Just a beautiful, browsable menu that feels alive.

---

## 1. Project Overview

**Goal:** Replicate the printed OOB menu as a tablet experience. Visual fidelity comes first, motion second, and both should feel intentional rather than decorative.

**Tone:** Elegant base, playful highlights. Think of a luxury brand showroom that occasionally winks at you.

**Target:** Android tablets, 10"+ display, portrait orientation as primary (the source menu is portrait), landscape as a graceful adaptation.

**Out of scope:**
- No ordering, cart, payment, or backend
- No user accounts or analytics
- No menu CMS (data is static, hand-coded in Dart)
- No iOS build (Android only, though Flutter makes iOS trivial later if needed)

---

## 2. Tech Stack

- **Flutter** 3.24+ (stable channel)
- **Dart** 3.5+
- **Min SDK:** 24 (Android 7.0)
- **Target SDK:** 34
- **Orientation:** Portrait primary, landscape supported
- **State management:** `flutter_riverpod` (lightweight, no overkill for static menu)

### Dependencies (pubspec.yaml)

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.5.1
  flutter_animate: ^4.5.0        # one-liner declarative animations
  animations: ^2.0.11            # OpenContainer, page transitions
  google_fonts: ^6.2.1           # Manrope, Inter, Cormorant Garamond
  lottie: ^3.1.2                 # for the whisk and steam loops
  rive: ^0.13.13                 # interactive whisking method toggle
  flutter_svg: ^2.0.10           # OOB logo, decorative marks
  smooth_page_indicator: ^1.1.0
  vector_math: ^2.1.4            # for parallax math
  haptic_feedback: ^0.5.1

dev_dependencies:
  flutter_lints: ^4.0.0
```

---

## 3. Brand & Design System

### 3.1 Color Palette

Pulled directly from the printed menu. Use these as named constants in `lib/theme/oob_colors.dart`.

| Token | Hex | Usage |
|---|---|---|
| `oobNavy` | `#1A2A52` | Primary brand, pill headers, body text |
| `oobNavyDeep` | `#142042` | Tsuki card, deepest accents |
| `oobOrange` | `#E87530` | OOB Blend card, OOB wordmark, accent lines |
| `oobOrangeDeep` | `#D6651F` | Pressed states, gradient bottoms |
| `oobCream` | `#F2EFE7` | Page background (warm off-white) |
| `oobCreamSoft` | `#EBE7DC` | Card secondary background |
| `oobInk` | `#0E1838` | Headlines on cream |
| `oobMuted` | `#5C6480` | Italic descriptor text |
| `oobWhite` | `#FFFFFF` | Text on navy/orange |

**Gradient accents (use sparingly):**
- `matchaSheen`: linear, `#1A2A52` to `#243B7A`, 135deg
- `orangeSheen`: linear, `#E87530` to `#F0894A`, 135deg

### 3.2 Typography

Use `google_fonts`. The printed menu mixes a geometric sans for display (looks like Futura/Avenir) with a humanist sans for body.

| Style | Font | Weight | Size | Tracking | Notes |
|---|---|---|---|---|---|
| Display XL | Manrope | 800 | 36-44sp | +2.5% | Pill header text, all caps |
| Display L | Manrope | 700 | 28sp | +1.5% | Section titles, all caps |
| Title | Manrope | 700 | 22sp | 0 | Menu item names |
| Body | Inter | 400 | 16sp | 0 | Descriptors |
| Italic | Inter Italic | 400 | 14sp | 0 | "Espresso and milk" style |
| Wordmark | Cormorant Garamond | 400 | 18sp | +8% | "WHISK'RS \| OUT OF BOREDOM" footer |
| Price | Manrope | 700 | 20sp | 0 | Tabular numerals, `fontFeatures: [FontFeature.tabularFigures()]` |

### 3.3 Spacing & Radii

8-point grid. Don't deviate.

- `space.xs` = 4, `sm` = 8, `md` = 16, `lg` = 24, `xl` = 32, `xxl` = 48
- `radius.pill` = 999 (the navy section headers)
- `radius.card` = 16 (powder cards, item detail sheet)
- `radius.tag` = 12 (vertical SPECIALTY DRINKS tag)

### 3.4 Elevation

Keep it flat. Use shadows only for the powder cards on hover/select and the bottom tab bar.

- `elevation.cardRest`: `BoxShadow(blur: 12, y: 4, color: navy.withOpacity(0.06))`
- `elevation.cardLift`: `BoxShadow(blur: 24, y: 8, color: navy.withOpacity(0.14))`
- `elevation.tabBar`: `BoxShadow(blur: 20, y: -2, color: navy.withOpacity(0.08))`

### 3.5 Components

Reusable widgets, all in `lib/widgets/`:

- **`PillHeader`** — Navy `radius.pill` container, white all-caps text, optional trailing price ("HANDPICKED MATCHA  ₱360.00"). Subtle breathing glow on dwell.
- **`VerticalTag`** — Rotated 90° pill ("WITH MILK", "NO MILK", "SPECIALTY DRINKS"). Orange for some, navy for others, matching the source.
- **`PowderCard`** — Big colored block (orange = OOB Blend, navy = Tsuki) with name at top and three stacked prices. Tap to flip and reveal cultivar notes on back.
- **`MenuRow`** — Item name (bold), italic descriptor, price right-aligned. Tap to expand into a detail sheet.
- **`WhiskingToggle`** — Custom segmented control: "Cold Whisk" / "Traditional" with an animated whisk icon that rotates between states.
- **`BottomTabBar`** — Three tabs (Matcha / Coffee / Most Ordered), pill indicator that slides with spring physics.
- **`AmbientLayer`** — Stack background drawing slow-floating particles (steam wisps on Matcha tab, coffee beans on Coffee tab). Decorative, behind content, never interactive.

---

## 4. Menu Data

Hard-code in `lib/data/menu_data.dart` as `const` lists of typed models. Do not fetch.

### 4.1 Models

```dart
enum WhiskMethod { coldWhisk, traditional }
enum PowderKind { oobBlend, tsuki }
enum PowderLevel { light, balanced, umami }

class PowderOption {
  final PowderKind kind;
  final PowderLevel level;
  final int pricePhp;
}

class MenuItem {
  final String name;
  final String? descriptor;     // italic line under name
  final int pricePhp;
  final String category;        // "specialty_matcha", "specialty_coffee", etc
  final String? base;           // "milk-based", "water-based", "soda-based"
}

class AddOn {
  final String name;            // "More caffeine!", "Make it big"
  final String descriptor;      // "Extra shot", "Up-size your cup"
  final int pricePhp;
}
```

### 4.2 Matcha Tab

**Whisking Method (selector, not a product):**
- Cold Whisk: "Less astringent | Creamy | Less Caffeine"
- Traditional: "Bodied | Smooth | More Caffeine"

**Matcha Latte — Pick your powder:**

| Powder | Level 1 (Light) | Level 2 (Balanced) | Level 3 (Umami) |
|---|---|---|---|
| OOB Blend | ₱210 | ₱240 | ₱270 |
| Tsuki | ₱230 | ₱260 | ₱290 |

Footnote: "For single cultivars, ask your Barista..."

**Handpicked Matcha** — ₱360.00 — "A 200 year old craft preserved in modern day"

**Specialty Drinks (Matcha):**
- Black Sesame Matcha — ₱260 — "Signature Black Sesame cream"
- Himalayan Matcha — ₱260 — "Salted Cream"
- Matcha-cho — ₱260 — "Matcha and Chocolate"
- Strawberry Matcha — ₱290 — "Signature Strawberry jam"
- Earl Grey Matcha — ₱260 — "Matcha and Earl Grey tea"

**Houjicha Latte** — ₱210.00 — "Roasted Matcha"

**Specialty Drinks (Houjicha):**
- Dirty Houjicha — ₱220 — "Espresso and Roasted Matcha"
- Himalayan Houjicha — ₱240 — "Houjicha and Salted cream"

### 4.3 Coffee Tab

**With Milk (milk-based):**
- White — ₱160 — "Espresso and milk"
- Spanish Latte — ₱170 — "Espresso and sweetened milk"
- Mocha — ₱180 — "Espresso, chocolate, and milk"
- Dirty Matcha — ₱220 — "Espresso, Matcha, and oat milk"

**No Milk (water-based):**
- Black — ₱140 — "Espresso and H₂O"
- Tonic Espresso — ₱170 — "Espresso and sparkling water"

**Specialty Drinks:**
- Eclipse (soda-based) — ₱190 — "Espresso and Mango"
- Newton (soda-based) — ₱190 — "Espresso and Apple"
- Black Sesame Latte (milk-based) — ₱190 — "Signature Black Sesame cream"
- Himalayan Latte (milk-based) — ₱190 — "Salted Cream"
- Sol (soda-based) — ₱200 — "Mango, Pomegranate, Lemon"

**Add-ons:**
- More caffeine! — +₱50 — "Extra shot"
- Make it big — +₱50 — "Up-size your cup"

### 4.4 Most Ordered Tab

Curated list (pick the 6 most visually interesting). Suggested:
1. Handpicked Matcha
2. Black Sesame Matcha
3. Strawberry Matcha
4. Spanish Latte
5. Dirty Matcha
6. Sol

Display as a floating card stack with gentle parallax on scroll.

---

## 5. App Architecture

```
lib/
├── main.dart
├── app.dart                       # MaterialApp root, theme, routing
├── theme/
│   ├── oob_colors.dart
│   ├── oob_typography.dart
│   ├── oob_spacing.dart
│   └── oob_theme.dart             # ThemeData composed from above
├── data/
│   ├── models.dart
│   └── menu_data.dart             # static const lists
├── state/
│   ├── whisking_method.dart       # Riverpod NotifierProvider
│   ├── selected_powder.dart
│   └── active_tab.dart
├── screens/
│   ├── home_shell.dart            # holds bottom tab bar + IndexedStack
│   ├── matcha_screen.dart
│   ├── coffee_screen.dart
│   └── most_ordered_screen.dart
├── widgets/
│   ├── pill_header.dart
│   ├── vertical_tag.dart
│   ├── powder_card.dart
│   ├── powder_grid.dart           # OOB Blend + Tsuki side-by-side
│   ├── menu_row.dart
│   ├── whisking_toggle.dart
│   ├── bottom_tab_bar.dart
│   ├── animated_tab_indicator.dart
│   ├── item_detail_sheet.dart
│   ├── footer_wordmark.dart
│   └── ambient/
│       ├── ambient_layer.dart
│       ├── steam_particle.dart
│       └── bean_particle.dart
└── utils/
    ├── peso.dart                  # formats `₱210.00`
    └── haptics.dart               # wrapper around haptic_feedback
```

`home_shell.dart` uses an `IndexedStack` so tabs preserve scroll position. Tab switch is animated by fading the IndexedStack child and sliding the section pills.

---

## 6. Screens

### 6.1 MatchaScreen

Portrait scrollable single column:

1. **Whisking Method** block (top, sticky-ish)
   - Pill header "WHISKING METHOD: Select your preferred method"
   - `WhiskingToggle` with two segments
   - Below the toggle, the active method's traits appear in italics ("Bodied | Smooth | More Caffeine") with a fade swap on change.

2. **Matcha Latte (Pick your powder)**
   - Title "MATCHA LATTE: Pick your powder" (Manrope 700, navy)
   - `PowderGrid`: two cards side-by-side (OOB Blend orange, Tsuki navy). Each card shows the three levels stacked with prices.
   - Tap a level row inside a card to highlight it (subtle scale + glow). Selection is purely visual, not stored beyond the screen.
   - Footer line: "For single cultivars, ask your Barista..."

3. **Handpicked Matcha** pill header with price on the right.

4. **Specialty Drinks** label (small caps) + list of `MenuRow`s.

5. **Houjicha Latte** pill header with price.

6. **Specialty Drinks** (Houjicha) list.

7. Footer wordmark: "WHISK'RS | OUT OF BOREDOM"

### 6.2 CoffeeScreen

1. **OOB logo** at the top (the arch + "OOB" wordmark in orange from the source).
2. **WITH MILK** section: vertical orange tag on the left, list of items on the right.
3. **NO MILK** section: vertical navy tag on the left, list on the right.
4. **SPECIALTY DRINKS** section: vertical orange tag, list. Each item shows its base in parens after the name (`soda-based`, `milk-based`).
5. **Add-ons pill** (navy, full-width) with two rows: More caffeine!, Make it big.
6. Footer wordmark.

### 6.3 MostOrderedScreen

Looser layout, more curated feel. Six floating cards in a vertical scroll, alternating left/right alignment, with slow parallax. Each card opens the same `ItemDetailSheet` as the other screens.

### 6.4 ItemDetailSheet

Modal bottom sheet that takes 80% of screen height. Header has a soft gradient (matchaSheen for matcha items, orangeSheen for coffee), large item name, italic descriptor, big price. Body lists nothing else (we have no real data), but should feel intentional: a "How it's made" placeholder section with a small Lottie of a whisk or coffee pour, and a "Pairs well with" row of three other items as small chips.

---

## 7. Animation & Interaction Specifications

The whole point. Tracy asked for "elegant base + playful highlights." Read this section carefully.

### 7.1 First-Run Entry

Triggered once per cold start.

1. Cream background fades in (200ms, easeOut)
2. Top pill header slides down from y=-20 with spring (damping 0.8, mass 1) and settles
3. Powder cards (OOB Blend, Tsuki) fade-up with **80ms stagger**, scale from 0.92 to 1.0
4. Each price inside the cards **counts up** from 0 to its real value (600ms, easeOutCubic). Use `flutter_animate`'s `Animate(...).custom(...)`.
5. Section pills below fade-up with 60ms stagger
6. Menu rows reveal with a slight rightward slide (12px) + fade, 40ms stagger
7. Bottom tab bar slides up from below with spring

Total entry choreography: roughly 1.6 seconds. Never block taps during entry — interactions should interrupt cleanly.

### 7.2 Tab Switch (Matcha ↔ Coffee ↔ Most Ordered)

- Old tab content cross-fades (180ms) + slides horizontally 24px in the direction of the new tab
- New tab content cross-fades in + slides from 24px in the opposite direction
- Tab indicator pill in the bottom bar slides between positions with spring physics (`SpringDescription(mass: 1, stiffness: 320, damping: 22)`)
- Ambient particle layer fades between steam (Matcha) and beans (Coffee) over 400ms
- Light haptic impact on tab change

### 7.3 Powder Card Flip

The signature interaction. Tap a powder card to flip it 3D and reveal cultivar notes.

- Use `Transform` with `Matrix4.rotationY(angle)` and `..setEntry(3, 2, 0.0015)` for perspective
- 600ms duration, `Curves.easeInOutCubic`
- At 50% (when the card is edge-on), swap front/back children
- The non-selected card dims to 60% opacity and scales to 0.96
- Medium haptic impact on flip
- Tap the flipped card to flip back

Back of card content (placeholder, since the source menu doesn't specify):
- OOB Blend: "House blend. Three estates, one cup. Best with oat or whole milk."
- Tsuki: "Single-region, ceremonial grade. Earthy, with a long finish."

### 7.4 Whisking Method Toggle

Custom segmented control, not a stock Material widget.

- Background: pill-shaped cream container
- Selected segment: navy fill, white text
- Unselected: transparent, navy text
- The selected pill **slides** between the two positions (250ms, easeOutQuart) instead of fading
- A tiny whisk icon sits inside the selected pill and rotates 180° on each toggle (using `RotationTransition`)
- The trait line below ("Less astringent | Creamy | Less Caffeine") cross-fades to the new method's traits (200ms)
- Light haptic on toggle

If you want to splurge, build this in **Rive** with a real whisk that actually whisks. Optional, but the prompt asked for fun.

### 7.5 Menu Row Tap

Tap any menu row to open `ItemDetailSheet`.

- Use `OpenContainer` from the `animations` package
- Closed: the menu row itself
- Open: the modal bottom sheet
- Transition: 400ms, `ContainerTransitionType.fadeThrough`
- The row's price and name should appear to physically expand into the sheet header (hero animation)
- Medium haptic on tap

### 7.6 Price Tabular Animation

Prices anywhere on screen (powder cards, pill headers, menu rows) use tabular figures and animate with `AnimatedFlipCounter` or a custom `TweenAnimationBuilder<int>`. On first reveal: count up from 0. On data change (there isn't any, but for safety): flip-digit transition.

### 7.7 Section Pill Breathing

Navy pill headers ("HANDPICKED MATCHA", "HOUJICHA LATTE") have a slow, almost-imperceptible glow cycle:

- Inner shadow opacity oscillates between 0.0 and 0.08 over 8 seconds
- Driven by an `AnimationController` with `repeat(reverse: true)`
- Disable when the user is actively scrolling (to avoid distraction)

### 7.8 Ambient Particle Layer

Behind all content, drawn on a `CustomPainter`.

**Matcha tab:** 5 to 8 steam wisps. Each wisp is a soft white blurred ellipse that drifts upward and fades. Spawn rate: 1 every 1.5 seconds. Max alpha: 0.12. Performance: cull off-screen, max 12 active.

**Coffee tab:** 4 to 6 coffee beans gently rotating and falling top-to-bottom on slow paths. Dark navy silhouettes at 0.08 opacity.

**Most Ordered tab:** mix of both, sparser.

Important: these are decorative. If frame time on the test tablet ever exceeds 14ms, halve the particle count.

### 7.9 Scroll Behavior

- `BouncingScrollPhysics` (iOS-style overscroll) for that satisfying rubber band
- Section pills get a subtle parallax: as you scroll, they translate by `0.1 * scrollOffset` to feel anchored
- Bottom tab bar gets a soft elevation increase when scroll offset > 0

### 7.10 Footer Wordmark Reveal

When the user scrolls to the bottom of any tab, the "WHISK'RS | OUT OF BOREDOM" wordmark does a slow letter-by-letter reveal (30ms per character, fade + 8px slide up). Only triggers once per session per tab.

### 7.11 Haptics Summary

| Event | Haptic |
|---|---|
| Tab change | Light impact |
| Powder card flip | Medium impact |
| Menu row tap | Selection |
| Whisking toggle | Light impact |
| Detail sheet dismiss | Light impact |

Wrap all calls in `utils/haptics.dart` so they can be globally muted.

---

## 8. Tablet Layout Guidelines

### 8.1 Breakpoints

Use `MediaQuery.sizeOf(context)` and split on the short side:

- `< 600dp` short side: phone fallback, single column, smaller fonts
- `600 – 840dp`: standard tablet, current spec
- `> 840dp`: large tablet, increase max content width to 720dp and center

### 8.2 Portrait (primary)

- Page horizontal padding: 32dp
- Max content width: 600dp (center if wider)
- Powder cards: side by side, equal width, aspect ratio 3:4
- Menu rows: full width

### 8.3 Landscape

- Two-column layout on Matcha and Coffee screens
- Left column (60% width): whisking method + powder grid + handpicked pill
- Right column (40% width): specialty drinks list, houjicha section
- Bottom tab bar stays full width

### 8.4 Safe areas

- Top: respect status bar
- Bottom: respect gesture nav (`SafeArea` around tab bar)
- Sides: 16dp minimum even after content padding

### 8.5 Performance Targets

- 60fps sustained while scrolling on a mid-range tablet (Snapdragon 7-class or equivalent)
- Cold start to interactive: under 1.2 seconds
- Tab switch: under 16ms per frame
- App size: under 25MB release APK (no large Lottie/Rive files)

---

## 9. Build & Run

```bash
# Create the project
flutter create --org dev.luminatech --project-name oob_menu --platforms=android .

# Install deps
flutter pub get

# Run on connected tablet
flutter devices                    # confirm tablet is listed
flutter run -d <device-id>

# Release build
flutter build apk --release --target-platform android-arm64
```

### Android-specific config (`android/app/build.gradle`):

```gradle
defaultConfig {
    applicationId "dev.luminatech.oob_menu"
    minSdkVersion 24
    targetSdkVersion 34
    versionCode 1
    versionName "1.0.0"
}
```

### Manifest (`android/app/src/main/AndroidManifest.xml`):

- `android:screenOrientation="unspecified"` (allow rotation)
- `android:resizeableActivity="false"` (no split-screen, this is a focused menu)

---

## 10. Acceptance Criteria

Build is "done" when:

- [ ] Three tabs (Matcha, Coffee, Most Ordered) all render and switch smoothly
- [ ] All menu items from section 4 are present with correct prices
- [ ] Powder card flip animation works on both cards
- [ ] Whisking method toggle visually swaps the trait line
- [ ] Menu row tap opens the detail sheet with hero animation
- [ ] Ambient particles render on each tab without dropping below 50fps
- [ ] Visual fidelity: side-by-side with the source photos, colors and pill headers and vertical tags all match
- [ ] Runs on a 10" Android tablet in portrait and landscape
- [ ] No console errors, no overflow warnings, no missing fonts
- [ ] Haptics fire correctly on all listed events

---

## 11. Development Order (Suggested)

Build in this sequence so you have something working at every step:

1. **Theme + tokens.** Get colors, typography, spacing into `theme/`. Build a quick test screen showing all of them.
2. **Static MatchaScreen.** No animations, no state, just the menu rendered correctly. Pixel-match the source photo.
3. **Static CoffeeScreen.** Same.
4. **Static MostOrderedScreen.** Same.
5. **BottomTabBar + HomeShell.** Wire up tab switching with `IndexedStack`. Static, no animation yet.
6. **WhiskingToggle.** First real interaction. Build it custom.
7. **PowderCard flip.** The hero interaction. Get this right before moving on.
8. **ItemDetailSheet + OpenContainer hero.** 
9. **Tab switch transitions.** Cross-fade + slide + indicator spring.
10. **Entry choreography.** Stagger reveal on first paint.
11. **AmbientLayer.** Particles.
12. **Polish:** breathing pills, parallax, footer reveal, haptics.
13. **Tablet landscape layout.**
14. **Performance pass.** Profile on real device, cut particles or animations if needed.

---

## 12. Notes & Constraints

- **No em dashes in UI copy.** Use commas, colons, or parentheses. (This is a personal preference of the project owner.)
- **Currency:** Always `₱` (U+20B1) followed by a thin space, then the amount with two decimals where the source shows them (`₱360.00`) and without where it doesn't (`₱210`). Match the source per item.
- **Don't invent menu items.** If something isn't in section 4, it doesn't exist.
- **The "OOB" logo** in the Coffee tab is the arch mark + "OOB" wordmark in orange. Recreate as SVG or accept a placeholder that matches the proportions; do not pull from the web.
- **Fonts must be bundled** via `google_fonts` runtime fetch on first launch is fine for dev, but for release switch to bundled `.ttf` files in `assets/fonts/` to keep the app offline-capable.
- **No localization** for v1. English only.
- **No dark mode** for v1. The cream-and-navy palette is the identity.

---

## 13. Project Identity

This app is shipping as a single deliverable. Name it `OOB Menu` in the launcher. Use the orange OOB arch as the launcher icon (generate via `flutter_launcher_icons`).

Built by Lumina Tech.

<!-- chiton:roles:start -->
## Chiton agent roles

### architect — claude-agent-acp — opus

Architecture and design only. Never edit source files — the engineer implements.

- Produce the design before the code: the interfaces, the data shapes, the order
  tasks must land in, and what "done" means for each one.
- Name the tradeoff you took and the option you rejected. A paragraph, not an essay.
- When a request is underspecified, say what is missing and pick a default
  explicitly. Never guess silently.
- You may write and edit design documents, specs and task lists. You may read
  anything.
- Hand work off as discrete tasks, one at a time, each small enough to review in one
  sitting.
- When an implementation diverges from the design, say whether the divergence is
  acceptable and why, rather than restating the original plan.

### engineer — codex-acp — default

Implementation only. Build the current task and stop.

- Follow the architect's design. If it is wrong or impossible, say so and stop —
  do not quietly substitute your own.
- Make the smallest change that satisfies the task. No unrequested refactors,
  renames, dependencies or reformatting; they bury the real diff.
- Match the surrounding code: its naming, its error handling, its comment density.
- Run the project's own checks before reporting done, and paste the output if they
  fail.
- Say what you did not finish and why. "Done" means done and verified.
<!-- chiton:roles:end -->
