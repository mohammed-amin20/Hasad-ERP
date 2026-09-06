# حصاد (Hasad) ERP

Flutter ERP application with a Supabase backend and Riverpod state management.

Hasad (حصاد, "harvest") is a day-to-day operational ERP tool: Arabic-first, RTL layout, and the Cairo font bundled locally. Every screen follows the project design system (DESIGN_SYSTEM.md) — blue as the functional color, gold/amber reserved for the brand gradient.

## Tech Stack

- **Framework:** Flutter (Material 3), Dart SDK `^3.13.2`
- **Backend:** Supabase (`supabase_flutter`), initialized once in `lib/main.dart`
- **State management:** Riverpod (`flutter_riverpod`, `riverpod_annotation` codegen)
- **Font:** Cairo (variable font, bundled at `assets/fonts/`, offline — no runtime downloads)
- **Icons:** Material icons (font_awesome_flutter planned per design system)

## Getting Started

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

If Riverpod codegen classes are touched:

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Conventions

- The app is RTL (`TextDirection.rtl`) with Arabic as the only locale — no screen is an exception.
- Numerals are always Western (0-9), never Arabic-Indic.
- Spacing is multiples of 4 only (`4, 8, 12, 16, 20, 24, 32, 40`).
- Dark mode is out of scope for this phase (see DESIGN_SYSTEM.md).