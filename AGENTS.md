# Hasad ERP (حصاد) — Project Rules

Flutter ERP application with Supabase backend and Riverpod state management. Arabic-first, RTL layout, bundled Cairo font. Every UI decision must follow `DESIGN_SYSTEM.md` exactly.

## Project Docs

Docs live at the repo root (`../../`). Read the relevant one before starting related work:

| File | When to read |
|---|---|
| `../../DESIGN_SYSTEM.md` | **Mandatory for ALL UI work** — colors, typography, spacing, radius, elevation, components, RTL, accessibility. No colors/spacing "by judgment" outside its tables. |
| `../../PROJECT_SPEC.md` | Product requirements and feature definitions |
| `../../SYSTEM_DESIGN.md` / `../../README_supabase_only.md` | Supabase schema, database design, and setup |
| `../../MILESTONES.md` | Phased roadmap + **source of truth for architecture** (M2 canonical structure, targets, SDK rules, error pattern) |

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
- ADAPT its examples to this project: it prescribes `ChangeNotifier`/`provider`/`get_it`, but Hasad uses **Riverpod** (`flutter_riverpod` + `riverpod_annotation`, codegen via `build_runner`). Follow its layering principles, but the canonical project structure is MILESTONES M2: `core/ domain/ data/ presentation/`. Implement state with Riverpod providers (`Notifier`/`AsyncNotifier`), not `ChangeNotifier`. The UI never imports the Supabase client (or drift) directly — it communicates with domain only through abstract repositories.

## Commands

Run everything from this directory (`Hasad-ERP/hasad_erp`) with the Flutter toolchain.

```bash
flutter pub get
flutter analyze   # must be clean before finishing any change
flutter test
```

Run/build/test commands that exercise the app's statement PDF **must add**
`--dart-define=use_arabic=true` (pdf's `use_arabic` is a compile-time const; without it Arabic
shapes as disconnected letters). Example: `flutter run -d chrome --web-port 5050 --dart-define=use_arabic=true`,
`flutter build web --dart-define=use_arabic=true`.

If Riverpod codegen classes are touched: `dart run build_runner build` (newer build_runner ignores the
old `--delete-conflicting-outputs` flag).

## Docs Upkeep Ritual (STANDING RULE)

After **every** finished milestone or slice, update the md docs in the same pass (before
declaring the step done). This keeps the next step fast and removes the need to re-derive
decisions. Checklist, in order:

1. `../../MILESTONES.md` — flip finished outputs to `✅`; mark the phase done in the phase map;
   add a **Handoff to next phase** note under the completed phase (what already exists the next
   phase reuses, what it must build fresh); append a row to **Appendix A — Implementation Log**
   with commit hash(es), DB objects added, test count, and any deviations.
2. This file (`AGENTS.md`) — record any behavior-changing facts discovered during the work
   (SDK API quirks, run commands, workflow rules, credentials, role splits). If only `this`
   step of the ritual has no facts, skip it.
3. `../../SYSTEM_DESIGN.md` §4 — sync the RPC/Edge Function table only when a contract changed
   (new/renamed RPC, dropped params). `security invoker` + balance assertion stays the rule.
4. `../../README_supabase_only.md` — only when the manual apply/test sequence changed (new
   migrations to paste in the SQL Editor, new `supabase/tests/*.ps1` to run).
5. `../../PROJECT_SPEC.md` — **never** edited by this ritual; it is the source of truth. Real
   divergences are logged in MILESTONES Appendix A instead.

PowerShell-only environment: no `&&` chaining — use `; if ($?) { ... }`.

## Stack & Conventions

- **Flutter** (Material 3), Dart SDK `^3.13.2`. Targets: **Android + Desktop only — no iOS/web.**
- **RTL + Arabic:** app is wrapped in `Directionality(TextDirection.rtl)` with `locale: Locale('ar')`. No screen is an exception. Numerals are always Western (0-9), never Arabic-Indic.
- **Cairo font** bundled at `assets/fonts/Cairo-Variable.ttf` (variable: 200–1000 weight). `GoogleFonts.config.allowRuntimeFetching = false` — never rely on runtime font downloads.
- **Supabase:** initialized once in `lib/main.dart` (url + publishableKey). Access via `Supabase.instance.client` — exclusively inside the `data/` layer's repositories; UI talks to abstract repositories only. `supabase_flutter` SDK only (no `dio`, no custom REST client); it attaches the session JWT automatically to `.rpc()`, `.from()`, and Edge Function calls.
  - **gotcha (supabase_flutter 2.17.2):** `.rpc()` uses named `params:` — `_client.rpc('fn', params: {...})`. A positional map fails to compile.
  - `DropdownButtonFormField` takes `initialValue:` in this Flutter version. Avoid `Iterable.firstOrNull` (needs `package:collection`).
- **Dev workflow:** native Android/Windows toolchains are broken on this machine — the verified run path is Chrome web: `flutter run -d chrome --web-port 5050` (app at `http://localhost:5050`). The `web/` directory is **local-only and never committed**. Validate final code with `flutter build web` (both with `--dart-define=use_arabic=true`).
- **DB operations:** the user applies SQL migrations manually in the Supabase **SQL Editor** (never run automatically here) and runs regression scripts manually with PowerShell from `supabase/tests/*.ps1`. So: write the migration into `supabase/migrations/`, write its `.ps1` test, then hand both to the user to apply/run.
- **Regression `.ps1` scripts must send JSON bodies as UTF-8 bytes** — Windows PowerShell 5.1 encodes a string `-Body` as ISO-8859-1, silently replacing Arabic with `?` on the wire (stored as real `0x3F` bytes). Every body call (post/patch to `.from()`, and RPC bodies) must go through a helper like `Invoke-Json` that does `[System.Text.Encoding]::UTF8.GetBytes(...)` + `-ContentType "application/json; charset=utf-8"`. The Flutter app (supabase_flutter) sends UTF-8 natively, so this only affects the scripts.
- **Never commit:** `.metadata`, `analysis_options.yaml`, `pubspec.lock`, `web/`, `build/`.
- **Dev test account:** `owner4@test.local` / `Test@1234567` (tenant owner4) on dev project `https://sxasnunzspkuwbxiddqd.supabase.co` — used by all `supabase/tests/*.ps1`.
- **Tab roles (as shipped):** Sales tab visible to all roles; Purchases, Inventory, Employees (الموظفون), and Salaries (الرواتب) tabs admin+accountant only. M7 reports tabs: dashboard (لوحة التحكم) is visible to all roles; دليل الحسابات، قيد اليومية، الأستاذ العام، ميزان المراجعة، القوائم المالية are admin+accountant only.
- **Money actions (as shipped):** payment recording, supplier settlement, and inventory adjustment are admin+accountant only (via `authStateProvider.value`); consignment invoices never show a payment button (RPC also rejects them).
- **`employees` RLS gap fixed in M6 (migration `0016`):** the M1 `employees` table shipped WITHOUT row-level security/policies/grants (unlike the 0004 master tables). Because the salary RPCs are `security invoker`, they silently fail on `select from employees` until 0016 is applied (RLS + all `authenticated` CRUD on own tenant, revoked from `anon`). The M6 employee screen and salary RPCs need this applied to work.
- **Master-table inserts stamp `tenant_id` via trigger (migration `0017`):** direct `.from('table').insert()` from the app AND the regression scripts never pass `tenant_id`, and nothing stamped it — so the RLS `with check (tenant_id = get_my_tenant_id())` saw `NULL` and PostgREST returned **403**. `0017_master_tables_set_tenant.sql` adds a `BEFORE INSERT` trigger `set_master_tenant()` (security invoker, `if new.tenant_id is null` guard — never stomps explicit values from security-definer RPCs) on employees/customers/suppliers/products/expenses. **Do not remove this trigger when writing new direct-insert tables; never assume direct inserts need a client-supplied tenant_id.**
- **Migration `0018` — consignment purchases of EXISTING products bind the supplier:** `create_sale_invoice` generates commission dues only when `product.supplier_id` points to a `deal_type='commission'` supplier, but `create_purchase_invoice` (0008) stamped `supplier_id`/`commission_rate` only on inline `new_product` items. Pre-created products therefore never earned commissions on their consignment sales. `0018_purchase_links_existing_product.sql` recreates `create_purchase_invoice` so a consignment receipt links an existing product to the purchasing supplier (`commission_rate` falls back to the supplier's); direct (owned) purchases never relink. Keep this behavior when editing the purchase or sale RPCs.
- **Test `.ps1` scripts keep a UTF-8 BOM:** Windows PowerShell 5.1 decodes a no-BOM script through a codepage-dependent path (Arabic lines can fail to parse). The Arabic regression scripts are saved UTF-8 **with BOM** — do not strip it. Related PS-only quirks already fixed: bodies must be UTF-8 bytes (above), RPC item arrays must be native hashtable arrays (never pre-serialized `ConvertTo-Json` strings), and **never wrap `Invoke-RestMethod` in `@(...)` for table GETs** — PS 5.1 already returns `Object[]` for multi-row responses, and the extra wrapper nests them to `.Count=1`, which silently breaks `Where-Object` row counting (e.g. `adjust_inventory.ps1` Case 5). GETs also don't need `Prefer: return=representation`. The same nesting hits RPC jsonb-array results: `@(Invoke-RPC -name "get_chart_of_accounts" -p @{})` reports `.Count=1` no matter how many rows — never wrap RPC array calls in `@(...)`; assign the result directly (flat `Object[]`) and read `.Count` off it. jsonb array **properties** of an envelope (e.g. `$dash.last_7_days`, `$row.lines`, `$dash.top_debtors`) parse flat with a correct `.Count` even inside `@(...)` pipelines; only the top-level `@(…)` around a command nests.
- **M6 employee statement is computed client-side (no statement RPC):** `buildEmployeeStatement` in `domain/salaries/salary_repository.dart` reads the read-only `salaries` + `employee_movements` + current `employees.base_salary`, and mirrors the 0010 arrears rule `max(base - paid, 0)` per earlier month. Since read-only tables are only queryable via the data layer, the reads live in `data/salaries/supabase_salary_repository.dart` while the pure aggregation stays in `domain/` (unit-tested).
- **`get_party_statement` RPC (migration `0015`):** `(p_party_type, p_party_id, p_from, p_to)` → one jsonb envelope `{party_type, party_id, from, to, opening, closing, lines[]}`; lines have `kind` `'invoice'|'payment'|'commission'`, `debit`, `credit` (running balance computed client-side); opening balance includes rows billed before `p_from`; commission dues are a separate `kind='commission'` line; consignment → zero debit/credit.
- **M7 report RPCs (migration `0019`, migration `0019_reports.sql`):** 9 report/write RPCs, all `security invoker`, revoked from `public`, execute granted to `authenticated` only — `get_dashboard_summary()` (KPI envelope incl. `last_7_days`, `top_debtors`, `low_stock`), `get_chart_of_accounts()`, `create_account(p_code, p_name, p_type, p_parent_code)`, `create_journal_entry(p_request_id, p_date, p_memo, p_lines jsonb)` (balanced-first + idempotent, `source_type='manual'`), `get_journal_entries(p_from, p_to)`, `get_ledger(p_account_id, p_from, p_to)` (`opening` + `lines[]` with running balance), `get_trial_balance(p_as_of_date)`, `get_income_statement(p_from, p_to)`, `get_balance_sheet(p_as_of_date)`. The chart-of-accounts/journal/report Flutter layers (`domain/{accounts,journal,reports}`, `data/{accounts,journal,reports}`, `presentation/providers/{accounts,journal,report}_providers.dart`) call these; the UI never hits `accounts`/`journal_entries` tables directly. Regression: `supabase/tests/reports.ps1`.
- **Flutter discovery: FontAwesomeIcons are `FaIconData`, not `IconData`** (font_awesome_flutter 11.0.0 / Font Awesome 7.2) — they cannot be passed to `Icon()` or `ButtonSegment.icon`, which want `IconData` (segments must drop icons or wrap in a `FaIcon`). Also `FontAwesomeIcons.arrowDownToBracket` and `arrowLeftFromBracket` DO NOT exist in this build; the debit icon is `arrowUpFromBracket` and the credit icon is `arrowRightToBracket`.
- **Flutter discovery: this project's Riverpod has NO `AsyncValue.valueOrNull`** — use `.maybeWhen(data: (v) => v ?? const [...], orElse: () => const [...])` instead of `watch(x.valueOrNull ?? [])`.
- **Flutter discovery: provider notifier class names can collide with domain model names** (e.g. `LedgerStatement`, `IncomeStatement`, `BalanceSheet` exist as BOTH a notifier in `report_providers.dart` and a model in `domain/reports/`). When a file imports both, alias the domain import (`import '.../ledger.dart' as ledger_models;`) or `hide` the notifier names on the providers import.
- **Widget-test discovery: the sidebar lazy-mounts its items.** `SideNavigation` renders via `ListView(children: ...)` but `SliverChildListDelegate` still only materializes in-viewport entries, so `find.text('أي عنصر')` returns nothing once a test scrolls the old anchor out of view (crashes `scrollUntilVisible` with "Bad state: No element"). Anchor side-nav scrolling with `find.descendant(of: find.byType(SideNavigation), matching: find.byType(Scrollable))`, not with a text anchor that itself scrolls away.
- **`pdf` 3.13 API (statement_pdf.dart):** embed a font via `pw.Font.ttf(ByteData)` + `pw.ThemeData.withFont(base:…, bold:…)`; set `pw.Page(textDirection: pw.TextDirection.rtl)` (shaping + RTL layout); render with `doc.save()` (not `build()`); there is **no** `PdfColor.opacity` — use precomputed tints; RTL table cells need explicit `pw.TextAlign.end`. Arabic shaping only runs when compiled with `use_arabic=true` and textDirection is rtl.
- **State management:** Riverpod only. Use `riverpod_annotation` codegen; delete stale `*.g.dart` via build_runner.
- **Error handling (fixed 3-catch pattern):** `PostgrestException`/RLS/constraint/RPC exceptions → `AppException`, `SocketException` → `Network`, `Exception` → `Unknown`. Never leak raw Supabase errors to the UI.
- **Roles:** admin / accountant / sales — screens hidden per role via the session.
- **Responsive nav:** fixed sidebar (>1100), collapsible sidebar (700–1100), swipeable Drawer (<700).
- **Icons:** `font_awesome_flutter` per DESIGN_SYSTEM §7 (not yet added to pubspec — add when first needed).
- **Spacing:** multiples of 4 only (`4, 8, 12, 16, 20, 24, 32, 40`). Card padding 20, form gap 12, section gap 24.
- **Dark mode:** out of scope per DESIGN_SYSTEM §13 — do not build a second ThemeData unless explicitly requested.