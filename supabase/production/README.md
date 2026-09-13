# Hasad ERP — Production Infrastructure

This folder contains all configuration and scripts needed to deploy the **production** environment (separate from the development Supabase project).

## 1. Supabase Production Project

### Create the Project

1. Go to https://supabase.com/dashboard
2. Click **New Project** → choose organization → name: `hasad-prod`
3. **Database password**: generate a strong 32-char password (save in password manager)
4. **Region**: choose closest to your users (e.g., `eu-central-1` for Europe/Middle East)
5. Wait for provisioning (~2 min)

### Enable Extensions (SQL Editor)

Run in **SQL Editor** (copy from `migrations/0001_extensions.sql`):
```sql
create extension if not exists pgcrypto;
create extension if not exists pg_cron;
create extension if not exists pg_net;
create extension if not exists "uuid-ossp";
```

### Apply Migrations (single-paste — Recommended)

The combined file `prod_schema.sql` in this folder concatenates `0001–0021` in order. Paste the entire file into **SQL Editor** once and run. Verify no errors in the output; then confirm the verification query at the end (table/function/cron counts).

**Important**: Extensions `pg_cron` and `pg_net` are allowlisted by Supabase but must be enabled; the script runs `create extension if not exists` which activates them. For `0013_reminder.sql` and `0020_reminders_to_all.sql`, cron jobs are created but **won't fire** until the n8n webhook is configured (see §3 below).

### Post-Paste Hardening (MANDATORY — S5)

After the combined paste **succeeds**, run these three scripts in the SQL Editor **in this order**, as role `postgres`:

1. `reapply_rls.sql` — `ENABLE` + **`FORCE`** row level security on all tenant tables and drop/recreate every isolation policy. Without it the DEV/prod databases behave as if RLS were off anytime a migration's `ALTER TABLE ... ENABLE ROW LEVEL SECURITY` ran before the tables' rows existed. No grant changes (preserves the invoker-RPC model).
2. `reapply_reminder_rpcs.sql` — drops **ALL** `_fire_reminder` / `send_due_reminders` / `send_reminder_now` / `send_reminders_to_all` overloads by name, then recreates them verbatim from the repo (numeric `_fire_reminder.p_amount`, grants, and the daily `send-due-reminders-daily` cron `'0 9 * * *'`). Removes the risk of stale pre-M9 function bodies (the DEV 400 `column "company_name" does not exist` failure).
3. `verify_security.sql` — the §6 security checklist as runnable SQL. Green = 0 rows returned except the two informational blocks and the 7-name `SECURITY DEFINER` allowlist.

Then verify the verification queries baked into `0019_reports.sql` (table/function/cron counts) and run `supabase/tests/m9_full_suite.ps1` (see §4 below) against the new project.

### Apply Migrations (per-file fallback)

If the combined script fails, paste each file individually in order from `../migrations/`:

```
0001_extensions.sql → 0002_schema.sql → 0003_auth_helpers.sql → 0004_rls_grants.sql
→ 0005_register_tenant.sql → 0006_invoice_counters.sql → 0007_rpc_sales.sql
→ 0008_rpc_purchases.sql → 0009_rpc_payments.sql → 0010_rpc_employees.sql
→ 0011_idempotency.sql → 0012_storage.sql → 0013_reminder.sql → 0014_stock_adjust.sql
→ 0015_get_party_statement.sql → 0016_employees_rls.sql → 0017_master_tables_set_tenant.sql
→ 0018_purchase_links_existing_product.sql → 0019_reports.sql → 0020_reminders_to_all.sql
→ 0021_user_tenants.sql
```

After each, verify no errors. `0021` creates `user_tenants`, backfills `current_tenant_id`, and adds the `switch_tenant` RPC — required for multi-business (M9 WS6) and the `_TenantSwitcher` sidebar.

### Configure Auth

1. **Authentication → Settings → Site URL**: `https://your-prod-domain.com` (or `http://localhost:5050` for local testing)
2. **Authentication → Settings → Redirect URLs**: add `https://your-prod-domain.com/**`
3. **Authentication → Providers → Email**: enable, disable "Confirm email" (for internal use)
4. **Authentication → SMTP**: configure custom SMTP (SendGrid, Mailgun, etc.) for production emails

### Storage Bucket

The `pdfs` bucket is created by `0012_storage.sql`. Verify:
- **Storage → Buckets → pdfs** exists
- **Policies** → `SELECT/INSERT/UPDATE/DELETE` for `authenticated` with `tenant_id` filter

### Get Credentials

**Settings → API**:
- `Project URL` → `NEXT_PUBLIC_SUPABASE_URL` (Flutter: `--dart-define=SUPABASE_URL=...`)
- `anon/public key` → `NEXT_PUBLIC_SUPABASE_ANON_KEY` (Flutter: `--dart-define=SUPABASE_ANON_KEY=...`)
- `service_role key` → **keep secret** (for admin scripts, Edge Functions)

---

## 2. n8n Deployment (VPS)

### Option A: Docker Compose (Recommended for VPS)

Create `docker-compose.yml` on your VPS:

```yaml
version: '3.8'

services:
  n8n:
    image: n8nio/n8n:latest
    restart: unless-stopped
    ports:
      - "5678:5678"
    environment:
      - N8N_HOST=${N8N_HOST}
      - N8N_PORT=5678
      - N8N_PROTOCOL=https
      - WEBHOOK_URL=https://${N8N_HOST}/
      - GENERIC_TIMEZONE=Asia/Gaza
      - TZ=Asia/Gaza
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=${POSTGRES_HOST}
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=${POSTGRES_DB}
      - DB_POSTGRESDB_USER=${POSTGRES_USER}
      - DB_POSTGRESDB_PASSWORD=${POSTGRES_PASSWORD}
      - N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}
    volumes:
      - n8n_data:/home/node/.n8n

  postgres:
    image: postgres:16-alpine
    restart: unless-stopped
    environment:
      - POSTGRES_DB=${POSTGRES_DB}
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"

volumes:
  n8n_data:
  postgres_data:
```

Create `.env` on VPS:
```bash
N8N_HOST=n8n.yourdomain.com
POSTGRES_DB=n8n
POSTGRES_USER=n8n
POSTGRES_PASSWORD=<strong-password>
N8N_ENCRYPTION_KEY=<32-char-random-string>
```

Run: `docker compose up -d`

### Option B: Railway (Managed)

1. Create new Railway project
2. Add **n8n** template (or Dockerfile)
3. Add **PostgreSQL** database
4. Connect n8n to PostgreSQL via Railway variables
5. Set `N8N_HOST`, `WEBHOOK_URL` to Railway-provided domain

---

## 3. n8n Workflow for SMS Reminders

### Import the Workflow

1. Open n8n at `https://n8n.yourdomain.com`
2. **Workflows → Import** → select `production/sms-reminder.json` (in this folder)
3. Configure credentials:
   - **HTTP Request** node → authentication for your SMS provider (e.g., Twilio, local provider API)
   - **Webhook** node → path: `/webhook/hasad-reminder`

### Webhook URL Format

The reminder RPCs expect a webhook URL like:
```
https://n8n.yourdomain.com/webhook/hasad-reminder
```

This URL is stored per-tenant in `tenant_settings.webhook_url`.

### Payload Sent by `send_reminder_now` / `send_reminders_to_all`

```json
{
  "customer_name": "أحمد محمد",
  "phone": "0599111222",
  "amount": 20000,
  "message": "أحمد محمد يرجى سداد 200 شيكل",
  "tenant_id": "uuid-of-tenant"
}
```

The n8n workflow should:
1. Receive webhook
2. Extract phone, message
3. Call SMS provider API
4. Return 200 OK (or error logged in `reminder_log`)

---

## 4. Regression After Setup

Run the full backend suite against the **new** project (the same script used on DEV — it is
parameterized for target URL + anon key, defaults to DEV):

```powershell
# Need two test users in prod FIRST: create owner4@test.local and owner2@test.local
# via Authentication -> Users -> Add user (password Test@1234567 / Test@654321).
.\supabase\tests\m9_full_suite.ps1 `
  -SupabaseUrl "https://YOURPROJECT.supabase.co" `
  -AnonKey "eyJ...anon-key..."
```

Expect **47/47 green** (T11 `switch_tenant` needs migration `0021`, which `prod_schema.sql` includes).

Then run the realistic full-month scenario + reconciliation (M9 output #4, also the S4
tenant-onboarding smoke test):

```powershell
.\supabase\tests\sample_month.ps1 `
  -SupabaseUrl "https://YOURPROJECT.supabase.co" `
  -AnonKey "eyJ...anon-key..."
```

It signs up a brand-new auth user, registers a fresh tenant via `register_tenant`, books one
complete past month (capital, purchases, consignment, sales, payments, expenses, salary) and
reconciles every account/stock/commission/statement to hand-computed values.

---

## 5. Flutter Production Build

### Environment Variables

Create `.env.production` (NOT committed):

```bash
SUPABASE_URL=https://your-prod-project.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

### Build Commands

```bash
# Web (for hosting on Firebase/Vercel/Netlify)
flutter build web --dart-define=use_arabic=true \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY

# Android (APK)
flutter build apk --dart-define=use_arabic=true \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY \
  --release

# Windows
flutter build windows --dart-define=use_arabic=true \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY \
  --release
```

### main.dart Configuration

The app reads `SUPABASE_URL` and `SUPABASE_ANON_KEY` from `--dart-define` at compile time. Ensure `lib/main.dart` uses:

```dart
const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

await Supabase.initialize(
  url: supabaseUrl,
  anonKey: supabaseAnonKey,
);
```

---

## 6. Backup & Restore

### Automated Backup (Supabase Built-in)

Supabase Pro+ plans include **Point-in-Time Recovery (PITR)** and daily backups. Enable in **Database → Backups**.

### Manual pg_dump (for extra safety)

```powershell
# Full backup (real .gz via backup.ps1)
.\backup.ps1 -SupabaseHost "db.xxxxx.supabase.co" -Password "xxx"

# Tenant-scoped backup (idempotent data-only inserts - safe to restore over a LIVE db)
.\backup.ps1 -SupabaseHost "db.xxxxx.supabase.co" -Password "xxx" -TenantId "uuid-here"

# Restore a full backup into a fresh project
pg_restore ... # or: psql -f hasad_prod_backup_<date>.sql.gz  (gunzip first)
```

**`backup.ps1` guarantees (fixed in the S5 pass):**
- `PGPASSWORD` is set correctly on the process (older drafts passed an empty password).
- The `.gz` file is **real gzip** (`GZipStream`), not a ZIP misnamed `.gz`.
- Tenant-scoped dumps are **data-only + `ON CONFLICT DO NOTHING`** and never pass
  `--clean`/`--if-exists` — restoring a tenant backup cannot drop or touch other
  tenants' tables or rows. Requires pg_dump ≥ 15 (the script retries without the
  flag on older clients).

### Tenant-Scoped Backup (for multi-tenant)

```bash
# Export single tenant data
pg_dump -h db.xxxxx.supabase.co -U postgres -d postgres \
  -t 'tenants' -t 'users' -t 'customers' -t 'suppliers' \
  -t 'products' -t 'invoices' -t 'invoice_items' \
  -t 'payments' -t 'journal_entries' -t 'journal_entry_lines' \
  -t 'commission_dues' -t 'employees' -t 'salaries' \
  -t 'employee_movements' -t 'stock_moves' -t 'expenses' \
  -t 'accounts' -t 'reminder_log' -t 'tenant_settings' \
  --where="tenant_id = 'TENANT_UUID'" \
  > tenant_TENANT_UUID_$(date +%F).sql
```

---

## 7. Security Checklist (Run Before Go-Live)

Run `verify_security.sql` (postgres role, SQL Editor) and review every block:

- [ ] **RLS enabled on every table** (check #1) — `SELECT * FROM pg_tables WHERE rowsecurity = false;`
- [ ] **RLS FORCED** on every tenant table (check #2, done by `reapply_rls.sql`)
- [ ] At least one RLS policy per table (check #3)
- [ ] Financial tables have **no direct INSERT/UPDATE/DELETE** for `authenticated` (check #4) — writes via RPC only
- [ ] No privileges granted to `anon` (check #5)
- [ ] `SECURITY DEFINER` functions are only the 7-name allowlist (check #6: `get_my_tenant_id`, `seed_chart_of_accounts`, `register_tenant`, `seed_tenant_settings`, `_fire_reminder`, `send_due_reminders`, `switch_tenant`)
- [ ] Business RPCs are **not** executable by `anon` (check #7)
- [ ] `pg_cron` jobs only call `SECURITY INVOKER`/internal definer functions (check #8)
- [ ] `service_role` key never exposed to client
- [ ] n8n webhook validates `tenant_id` against known tenants
- [ ] SMS provider API keys stored in n8n credentials (not in workflow JSON)

---

## 8. Go-Live Checklist

- [ ] Production Supabase project created, migrations applied
- [ ] n8n deployed, SMS workflow tested with real provider
- [ ] `tenant_settings` for production tenant configured with real webhook URL
- [ ] Flutter production build compiled with `--dart-define=use_arabic=true`
- [ ] App hosted (Firebase Hosting / Vercel / Netlify / self-hosted)
- [ ] Custom domain configured with SSL
- [ ] Test accounts created (admin, accountant, sales) + the two suite users (`owner4@test.local`/`owner2@test.local`)
- [ ] Full regression: `m9_full_suite.ps1` **47/47** against prod (§4)
- [ ] `sample_month.ps1` full-month reconciliation green against prod (§4)
- [ ] `verify_security.sql` audit green (§7)
- [ ] Backup script scheduled (cron/GitHub Actions)
- [ ] Monitoring: Supabase logs, n8n execution logs, `reminder_log` table
- [ ] Runbook documented (this file + `OPERATIONS.md`)

---

## 9. Files in This Folder

| File | Purpose |
|------|---------|
| `README.md` | This file |
| `docker-compose.yml` | n8n + PostgreSQL for VPS |
| `.env.example` | Template for n8n environment |
| `prod_schema.sql` | Combined 0001–0021 migration script (single SQL Editor paste) |
| `reapply_rls.sql` | **Post-paste hardening:** ENABLE+FORCE RLS + recreate isolation policies (no grant changes) |
| `reapply_reminder_rpcs.sql` | **Post-paste hardening:** drop-all + recreate reminder RPCs (numeric `_fire_reminder`), grants, daily cron |
| `verify_security.sql` | Runnable §7 security audit (postgres role) |
| `apply_migrations.ps1` | PowerShell script to apply all migrations to production (note: `exec_sql` RPC may 404 — SQL Editor paste is the verified path) |
| `sms-reminder.json` | n8n workflow template (SMS credential = placeholder, wire provider when decided) |
| `backup.ps1` | pg_dump backup script (real gzip; tenant dumps safe to restore over live DB) |
| `OPERATIONS.md` | Runbook for daily operations |