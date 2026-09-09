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

### Apply Migrations (in order)

In **SQL Editor**, paste and run each migration file **in order** from `../migrations/`:
```
0001_extensions.sql
0002_schema.sql
0003_auth_helpers.sql
0004_rls_grants.sql
0005_register_tenant.sql
0006_invoice_counters.sql
0007_rpc_sales.sql
0008_rpc_purchases.sql
0009_rpc_payments.sql
0010_rpc_employees.sql
0011_idempotency.sql
0012_storage.sql
0013_reminder.sql
0014_stock_adjust.sql
0015_get_party_statement.sql
0016_employees_rls.sql
0017_master_tables_set_tenant.sql
0018_purchase_links_existing_product.sql
0019_reports.sql
0020_reminders_to_all.sql
```

**Important**: After each migration, verify no errors. For `0013_reminder.sql` and `0020_reminders_to_all.sql`, the cron job and reminders will be created but **won't fire** until n8n webhook is configured (see below).

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
2. **Workflows → Import** → select `n8n-workflows/sms-reminder.json` (create this file, see below)
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

## 4. Flutter Production Build

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

## 5. Backup & Restore

### Automated Backup (Supabase Built-in)

Supabase Pro+ plans include **Point-in-Time Recovery (PITR)** and daily backups. Enable in **Database → Backups**.

### Manual pg_dump (for extra safety)

```bash
# Full backup
pg_dump -h db.xxxxx.supabase.co -U postgres -d postgres \
  --no-owner --no-privileges --clean --if-exists \
  > hasad_prod_backup_$(date +%F).sql

# Restore
psql -h db.xxxxx.supabase.co -U postgres -d postgres \
  -f hasad_prod_backup_2026-09-09.sql
```

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

## 6. Security Checklist (Run Before Go-Live)

- [ ] RLS enabled on **every table** (verify via `SELECT * FROM pg_tables WHERE rowsecurity = false;`)
- [ ] All policies use `tenant_id = get_my_tenant_id()`
- [ ] `GRANT SELECT/INSERT/UPDATE/DELETE` only to `authenticated` on master tables
- [ ] Financial tables (`invoices`, `journal_entries`, `payments`, `commission_dues`, `salaries`, `employee_movements`, `stock_moves`) have **no direct write grants** — only via RPC
- [ ] All write RPCs are `SECURITY INVOKER`
- [ ] `register_tenant` is `SECURITY DEFINER` with ownership validation
- [ ] `service_role` key never exposed to client
- [ ] `pg_cron` jobs only call `SECURITY INVOKER` functions
- [ ] n8n webhook validates `tenant_id` against known tenants
- [ ] SMS provider API keys stored in n8n credentials (not in workflow JSON)

---

## 7. Go-Live Checklist

- [ ] Production Supabase project created, migrations applied
- [ ] n8n deployed, SMS workflow tested with real provider
- [ ] `tenant_settings` for production tenant configured with real webhook URL
- [ ] Flutter production build compiled with `--dart-define=use_arabic=true`
- [ ] App hosted (Firebase Hosting / Vercel / Netlify / self-hosted)
- [ ] Custom domain configured with SSL
- [ ] Test accounts created (admin, accountant, sales)
- [ ] Full regression: sale → payment → statement → PDF → reminder
- [ ] Backup script scheduled (cron/GitHub Actions)
- [ ] Monitoring: Supabase logs, n8n execution logs, `reminder_log` table
- [ ] Runbook documented (this file + `OPERATIONS.md`)

---

## 8. Files in This Folder

| File | Purpose |
|------|---------|
| `README.md` | This file |
| `docker-compose.yml` | n8n + PostgreSQL for VPS |
| `.env.example` | Template for n8n environment |
| `apply_migrations.ps1` | PowerShell script to apply all migrations to production |
| `n8n-workflows/sms-reminder.json` | n8n workflow template (to be created) |
| `backup.ps1` | pg_dump backup script |
| `OPERATIONS.md` | Runbook for daily operations |