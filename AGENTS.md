# Hasad ERP (حصاد) — Project Rules

Flutter ERP application with Supabase backend and Riverpod state management. Arabic-first, RTL layout, bundled Cairo font. Every UI decision must follow `DESIGN_SYSTEM.md` exactly.

## Project Docs

Docs live at the repo root (`../../`). Read the relevant one before starting related work:

| File | When to read |
|---|---|
| `../../DESIGN_SYSTEM.md` | **Mandatory for ALL UI work** — colors, typography, spacing, radius, elevation, components, RTL, accessibility. No colors/spacing "by judgment" outside its tables. |
| `../../PROJECT_SPEC.md` | Product requirements and feature definitions |
| `../../SYSTEM_DESIGN.md` / `../../README_supabase_only.md` | Supabase schema, database design, and setup |
| `../../MILESTONES.md` | Phased roadmap and priorities |

## Skills

Load the following skills via the skill tool when their domain applies. Do not skip them for matching work.

### ui-ux-pro-max
Use for designing, building, reviewing, or fixing any interface — pages, components, design system, accessibility, interaction, responsive layout, typography, color, charts, and Flutter UI implementation.

- Actual skill location: `C:\Users\khatib\.agents\skills\ui-ux-pro-max` (this is the source of truth).
- NOTE: the skill's own docs hardcode a `.claude/skills/...` path for its search script. Use the real one:
  `C:\Users\khatib\.agents\skills\ui-ux-pro-max\scripts\search.py`
- Run its Pre-Delivery Checklist (`references/pro-rules.md`) before delivering any app UI.

### flutter-apply-architecture-best-practices
Use when structuring the project, scaffolding a new feature, or refactoring for scalability.

- Skill location: `C:\Users\khatib\.claude\skills\flutter-apply-architecture-best-practices`
- ADAPT its examples to this project: it prescribes `ChangeNotifier`/`provider`/`get_it`, but Hasad uses **Riverpod** (`flutter_riverpod` + `riverpod_annotation`, codegen via `build_runner`). Follow its UI/Logic/Data layering and feature-first `lib/ui/features/*` structure; implement state with Riverpod providers (`Notifier`/`AsyncNotifier`), not `ChangeNotifier`.

## Commands

Run everything from this directory (`Hasad-ERP/hasad_erp`) with the Flutter toolchain.

```bash
flutter pub get
flutter analyze   # must be clean before finishing any change
flutter test
```

If Riverpod codegen classes are touched: `dart run build_runner build --delete-conflicting-outputs`.

## Stack & Conventions

- **Flutter** (M3, Material 3 disabled-defaults off-base), Dart SDK `^3.13.2`.
- **RTL + Arabic:** app is wrapped in `Directionality(TextDirection.rtl)` with `locale: Locale('ar')`. No screen is an exception. Numerals are always Western (0-9), never Arabic-Indic.
- **Cairo font** bundled at `assets/fonts/Cairo-Variable.ttf` (variable: 200–1000 weight). `GoogleFonts.config.allowRuntimeFetching = false` — never rely on runtime font downloads.
- **Supabase:** initialized once in `lib/main.dart` (url + publishableKey). Access via `Supabase.instance.client`. Never re-initialize in tests or per-widget.
- **State management:** Riverpod only. Use `riverpod_annotation` codegen; delete stale `*.g.dart` via build_runner.
- **Icons:** `font_awesome_flutter` per DESIGN_SYSTEM §7 (not yet added to pubspec — add when first needed).
- **Spacing:** multiples of 4 only (`4, 8, 12, 16, 20, 24, 32, 40`). Card padding 20, form gap 12, section gap 24.
- **Dark mode:** out of scope per DESIGN_SYSTEM §13 — do not build a second ThemeData unless explicitly requested.