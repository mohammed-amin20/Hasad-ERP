# Hasad ERP — Supabase Backend (M1)

The complete accounting backend lives in the database. All sensitive financial
writes go through **Postgres RPC functions** — there is no separate API server.

## Environments

| Environment | Purpose |
|---|---|
| `sxasnunzspkuwbxiddqd` | **Development** (the project you applied tests to) |
| production (create later) | The real business — **never** share a project with dev |

## Apply order (Dashboard → SQL Editor)

| File | Contents |
|---|---|
| `migrations/0001_extensions.sql` | pgcrypto, pg_cron, pg_net |
| `migrations/0002_schema.sql` | 17 base tables |
| `migrations/0003_auth_helpers.sql` | `get_my_tenant_id/get_my_user/get_my_role` |
| `migrations/0004_rls_grants.sql` | RLS policies + grants (isolation layer) |
| `migrations/0005_register_tenant.sql` | `register_tenant` + chart-of-accounts seed (14 accounts) |
| `migrations/0006_invoice_counters.sql` | per-tenant official number counters |
| `migrations/0007_rpc_sales.sql` | `create_sale_invoice` (canonical pattern) |
| `migrations/0008_rpc_purchases.sql` | `create_purchase_invoice` (direct/consignment + inline product) |
| `migrations/0009_rpc_payments.sql` | `record_payment`, `settle_supplier` |
| `migrations/0010_rpc_employees.sql` | `add_employee_movement`, `pay_salary`, `get_employee_entitlement` |
| `migrations/0011_idempotency.sql` | `processed_requests` (bulk RPC dedupe) |
| `migrations/0012_storage.sql` | tenant-isolated `pdfs` bucket |
| `migrations/0013_reminder.sql` | reminder automation + `reminder_log` + pg_cron |

Each file is transactional — a failure rolls the whole file back.

### Known fixes applied during verification (already in the files)

- **`0009`** — `record_payment` used to write `invoices.type` (`sale`/`purchase`) into
  `payments.type`, which only allows `customer`/`supplier` → showed up live as
  `23514 payments_type_check`. Now maps with a `case`. Safe to re-apply (`create or replace`).
- **`0012`** — dropped `ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;`
  (`42501`, storage tables are extension-owned). Only bucket-scoped policies remain.
- **`0013`** — job cleanup now uses `select cron.unschedule(jobid) from cron.job where
  jobname = ...` instead of `delete from cron.job` (`42501`, cron schema is extension-owned).

If you ever re-create the project from scratch, apply all 13 files in the table order —
these fixes are baked in.

## Connection

- URL: `https://sxasnunzspkuwbxiddqd.supabase.co`
- The anon/publishable key in `lib/main.dart` is public by design (safe in git).
- The Flutter app uses `supabase_flutter` only. UI → abstract repositories in
  `domain/` → `data/` repositories call `.rpc()` / `.from()` / `.invoke()`.

## RPC contract (what Flutter calls)

All write RPCs are `SECURITY INVOKER` (subject to RLS), take a client-generated
`request_id uuid` for idempotency, run in one transaction, and enforce a final
`sum(debit) = sum(credit)` balance ASSERT. Money is **integer Agorot**.

| Function | Params (+ defaults) | Returns |
|---|---|---|
| `register_tenant` | `p_name text, p_owner_name text DEFAULT NULL` | tenant uuid |
| `create_sale_invoice` | `p_request_id, p_customer_id, p_items jsonb, p_invoice_date DEFAULT now, p_paid DEFAULT 0, p_payment_method DEFAULT NULL, p_memo` | `{invoice_id,no,total,paid,remaining,status,entry_no}` |
| `create_purchase_invoice` | `p_request_id, p_supplier_id, p_items jsonb, p_invoice_date, p_paid, p_payment_method, p_memo` | `{...,ownership,entry_no}` (entry_no null on consignment) |
| `record_payment` | `p_request_id, p_invoice_id, p_amount, p_method, p_date, p_note` | `{payment_id,invoice_id,no,paid,remaining,status,entry_no}` |
| `settle_supplier` | `p_request_id, p_supplier_id, p_amount, p_method, p_date, p_note` | `{total,invoices_count,dues_count,entry_no,allocations}` |
| `add_employee_movement` | `p_request_id, p_employee_id, p_month, p_direction, p_category, p_amount, p_description, p_product_id, p_qty, p_date` | `{movement_id,amount}` |
| `pay_salary` | `p_request_id, p_employee_id, p_month, p_paid, p_method, p_date, p_note` | `{net_due,paid,arrears_carried,entry_no,...}` |
| `get_employee_entitlement` | `p_employee_id, p_month` | `{base_salary,arrears,entitlements,deductions,net_due}` |
| `send_reminder_now` | `p_customer_id` | reminder_log row |
| `get_my_tenant_id / get_my_user / get_my_role` | — | scalar / users row / role text |

`p_items` for sales: `[{"product_id","qty","price"}]` (price optional → `sale_price`).
`p_items` for purchases: `[{"product_id","qty","price"}]` **or** `[{"new_product":{"name","unit","unit_type","sale_price","commission_rate"},"qty","price"}]` (not both).
`p_method` is `'cash'` or `'bank'`. Duplicate `request_id` returns `{"duplicate": true, ...}`.

Simple CRUD (no RPC): `customers`, `suppliers`, `products`, `expenses`,
`employees`, and all read-only tables — plain `.from()` scoped by RLS.

## Enforcement rules (non-negotiable)

- **No direct writes** to `invoices/invoice_items/journal_entries/journal_entry_lines/payments/commission_dues/salaries/employee_movements/stock_moves` — RPC only.
- **Balanced double-entry** every write; rollback on imbalance.
- **Consignment** purchases book no debt and can never be paid.
- **Tenant isolation** via RLS on every table — never query cross-tenant.
- Staff are added/managed by the owner (register_tenant makes the admin). A
  staff-provisioning RPC can be added later if needed.

## Storage

Bucket `pdfs` (not public). Path must start with the tenant UUID:
`{tenant_id}/statements/{file}.pdf`. RLS allows each tenant to read/write only
its own folder. The `statement-pdf` Edge Function (M3) writes here.

## Reminders (internal)

- `pg_cron` runs `send_due_reminders()` daily at 09:00 (job
  `send-due-reminders-daily`). It is **not** exposed to the app.
- Per tenant: settings in `tenant_settings` (webhook URL, message template with
  `{customer_name} {amount} {company_name} {phone}`, threshold days, enabled).
- The function POSTs to the n8n webhook via `pg_net`; n8n delivers the SMS.
- Every send is logged in `reminder_log` (`status sent` = queued to webhook).
- "Remind now" = `send_reminder_now(customer_id)`.

## Testing

`tests/m1_scenarios.md` is the executable test suite. Structural checks run in
the SQL Editor; functional checks run over REST with a real user JWT (RLS/RPC
cannot be truthfully tested as `postgres`). The final section is a full
regression on a fresh tenant.

Automated PowerShell scripts (creds default to the dev test users; override via
`param()` on the command line):
- `tests/payment_final.ps1` — master inserts + sale + `record_payment` to paid.
- `tests/reminder_final_v2.ps1` — webhook + `send_reminder_now` → `reminder_log` + isolation.
- `tests/idempotency_fixed.ps1` — same `request_id` twice → second returns `{duplicate: true}`.