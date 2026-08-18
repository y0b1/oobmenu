# OOB Menu

A digital menu for **OOB (Out of Boredom)**, a coffee and matcha bar in Davao. It is a Flutter
tablet app that recreates the printed menu on a 10 inch Android tablet, plus a password gated
admin panel so staff can change prices, mark drinks sold out, and cut off a tab for the day
without a developer or a backend.

## Features

### Customer view

Three tabs held in an `IndexedStack` so each keeps its scroll position.

- **Matcha.** Whisking method selector (Cold Whisk / Traditional) with the active method's
  traits below it, the powder grid (OOB Blend and Tsuki, three levels each with prices),
  Handpicked Matcha, matcha specialty drinks, Houjicha Latte, and houjicha specialty drinks.
- **Coffee.** The OOB logo, then rotated vertical tags for `WITH MILK`, `NO MILK`, and
  `SPECIALTY DRINKS`, each with its rows, and the navy add-ons block.
- **Most Ordered.** Six featured drinks in a two column card grid, curated from the admin panel.

Throughout: ambient particle layers (steam on matcha, beans on coffee) drawn on a
`CustomPainter`, sold out rows that fade and swap their price for `SOLD OUT`, a milk notice chip
when only one milk is on hand, a full screen cut-off stamp when a tab is closed for the day, and
haptics wrapped in `utils/haptics.dart` so they can be muted globally.

### Admin panel

Reached by the faint settings gear at the top right of Most Ordered, behind a password prompt.
Edits are staged in memory and only written when `SAVE CHANGES` is tapped.

- **Availability.** Cut off the matcha or coffee tab with a custom message, restrict milk to
  dairy only or oat only, and toggle individual drinks sold out (per drink or select all).
- **Most Ordered.** Long press and drag to reorder the six featured cards, or swap in any drink
  from the menu below.
- **Menu content.** Edit the name, descriptor, and price of every drink, add and remove
  specialty items, adjust both powder ladders, and edit the add-ons.
- **Password.** Change it from the app bar.

Everything persists to `SharedPreferences` as JSON. The seed menu in `lib/data/menu_data.dart`
is the fallback on first launch.

## Tech stack

| | |
|---|---|
| Framework | Flutter 3.24+, Dart 3.5+ |
| State | `flutter_riverpod` |
| Persistence | `shared_preferences` |
| Motion | `flutter_animate`, `animations` |
| Type | `google_fonts` (Manrope, Inter, Cormorant Garamond, bundled in `assets/`) |
| Platform | Android only, minSdk 24, portrait primary with landscape supported |

## Getting started

```bash
flutter pub get
flutter devices            # confirm the tablet is listed
flutter run -d <device-id>
```

Release build:

```bash
flutter build apk --release --target-platform android-arm64
```

Checks:

```bash
flutter analyze
flutter test
```

## Project structure

```
lib/
├── main.dart                  # entrypoint, orientation setup
├── app.dart                   # MaterialApp root, system UI styling
├── theme/                     # colors, typography, spacing, elevation, ThemeData
├── data/                      # models and the seed menu
├── state/                     # Riverpod providers: menu, availability, active tab,
│                              #   whisking method, selected powder, most ordered
├── screens/                   # home shell, matcha, coffee, most ordered, admin panel
├── widgets/                   # pill header, vertical tag, powder card and grid, menu row,
│   └── ambient/               #   whisking toggle, tab bar, cut-off overlay, milk notice,
│                              #   footer wordmark, and the particle layers
└── utils/                     # peso formatting, haptics
```

## Brand

Colors, type scale, spacing, and radii live in `lib/theme/` and are the single source.
The palette is cream and navy with orange accents. No dark mode.

Prices format through `lib/utils/peso.dart`: `formatPeso(210)` gives `₱ 210` and
`formatPeso(360, withDecimals: true)` gives `₱ 360.00`.

## A note on the admin password

The default is set in `lib/state/menu_state.dart` and is meant to be changed on first run from
inside the app. It gates a menu editor on a device that lives on a counter, not anything
sensitive, so treat it as a staff convenience lock rather than real access control.

## License

MIT. See [LICENSE](LICENSE).
