# Hasad ERP — Operations Runbook

Daily/weekly/monthly operational procedures for the production environment.

---

## 1. Daily Checks (Automated via Cron / Manual)

### Morning (09:00-10:00)

- [ ] **Reminder Cron Job**: Verify `pg_cron` ran `send_due_reminders()` 
  ```sql
  SELECT * FROM cron.job_run_details 
  WHERE jobid = (SELECT jobid FROM cron.job WHERE command LIKE '%send_due_reminders%')
  ORDER BY start_time DESC LIMIT 1;
  ```
  Expected: `status = 'succeeded'`, `return_message` shows sent count.

- [ ] **Reminder Log**: Check `reminder_log` for today's entries
  ```sql
  SELECT * FROM reminder_log 
  WHERE created_at >= CURRENT_DATE 
  ORDER BY created_at DESC;
  ```
  Look for: failures (status = 'failed'), zero-sent days (investigate if overdue exists).

- [ ] **n8n Executions**: Open n8n → Executions → filter by "Hasad SMS Reminder" workflow
  - Verify all executions succeeded
  - Check for any failed SMS deliveries (provider errors)

### Evening (18:00)

- [ ] **Backup Verification**: Confirm last backup file exists and is non-zero
  ```bash
  ls -lh supabase/production/backups/
  ```

---

## 2. Weekly Checks

### Monday

- [ ] **Tenant Isolation Test**: Run cross-tenant query to verify RLS
  ```sql
  -- As tenant A user
  SET ROLE authenticated;
  SET request.jwt.claims = '{"sub": "user-a-uuid", "tenant_id": "tenant-a-uuid"}'::jsonb;
  SELECT count(*) FROM customers; -- Should only show tenant A
  
  -- As tenant B user  
  SET request.jwt.claims = '{"sub": "user-b-uuid", "tenant_id": "tenant-b-uuid"}'::jsonb;
  SELECT count(*) FROM customers; -- Should only show tenant B
  ```

- [ ] **Balance Verification**: Run trial balance for each tenant
  ```sql
  SELECT * FROM get_trial_balance(CURRENT_DATE);
  ```
  Verify `balanced = true` for all tenants.

- [ ] **Commission Dues Check**: Verify no orphaned commission dues
  ```sql
  SELECT cd.*, p.name as product_name, s.name as supplier_name
  FROM commission_dues cd
  JOIN products p ON p.id = cd.product_id
  JOIN suppliers s ON s.id = p.supplier_id
  WHERE cd.status = 'pending'
    AND p.supplier_id IS NULL; -- Should return 0 rows
  ```

### Friday

- [ ] **Storage Check**: Supabase Dashboard → Storage → `pdfs` bucket size
- [ ] **Database Size**: Settings → Database → Disk usage
- [ ] **n8n Health**: Check n8n container logs for errors

---

## 3. Monthly Checks

### 1st of Month

- [ ] **Full Backup Restore Test**: Restore last month's backup to a test project
  1. Create temporary Supabase project
  2. Apply migrations (0001-0020)
  3. Restore backup
  4. Run `reports.ps1` against restored data
  5. Verify all 5 cases pass

- [ ] **Index Usage**: Check for unused indexes
  ```sql
  SELECT schemaname, tablename, indexname, idx_scan
  FROM pg_stat_user_indexes
  WHERE idx_scan = 0 AND schemaname = 'public'
  ORDER BY pg_relation_size(indexrelid) DESC;
  ```

- [ ] **Slow Queries**: Supabase Dashboard → Logs → filter by duration > 1s

- [ ] **Security Audit**: 
  - Review `pg_roles` for unexpected members
  - Verify no `SECURITY DEFINER` functions except `register_tenant`
  - Check `grants` on financial tables (should be SELECT only for authenticated)

---

## 4. Incident Response

### Reminder Cron Failed

1. Check `cron.job_run_details` for error message
2. Common causes:
   - n8n webhook URL changed → update `tenant_settings.webhook_url`
   - n8n down → restart n8n container (`docker compose restart n8n`)
   - SMS provider API limit → check provider dashboard
3. Re-run manually:
   ```sql
   SELECT send_due_reminders();
   ```

### n8n Workflow Failing

1. Open n8n → Executions → filter failed
2. Check error node (usually "Send SMS" or "Check Response")
3. Common fixes:
   - Invalid phone format → check "Validate & Normalize" function
   - SMS provider credentials expired → update n8n credentials
   - Rate limited → add delay node or upgrade provider plan

### Database Connection Errors (Flutter App)

1. Check Supabase status page
2. Verify project not paused (free tier pauses after 7 days inactivity)
3. Check JWT expiry — app should auto-refresh via `supabase_flutter`
4. If persistent: restart app, check network

### Balance Mismatch (Trial Balance Not Balanced)

1. Run `get_trial_balance` with earlier date to find when it broke
2. Check `journal_entry_lines` for unbalanced entries around that date
3. Look for failed RPC calls in Supabase logs (filter by `ERROR`)
4. If manual journal entry caused it: delete via `create_journal_entry` with reversal (new entry with opposite debits/credits)

### Tenant Data Leak (Cross-Tenant Visibility)

**CRITICAL** — immediate action:
1. Revoke affected user's access
2. Audit RLS policies on all tables
3. Check for any `SECURITY DEFINER` functions missing tenant check
4. Run full isolation test suite (Workstream 2 pgTAP tests)
5. Notify affected tenants

---

## 5. Adding a New Tenant (Business)

### Via `register_tenant` RPC (Admin Only)

```sql
SELECT register_tenant(
  'New Business Name',
  'owner@newbusiness.com',
  'TempPass123!'  -- user will reset on first login
);
```

Returns: `tenant_id`, `user_id`

### Post-Creation Steps

1. **Login** as new owner → reset password
2. **Configure Reminders** (Settings tab):
   - Webhook URL: `https://n8n.yourdomain.com/webhook/hasad-reminder`
   - Message template (use defaults or customize)
   - Days threshold: 1 (recommended)
   - Enable: ON
3. **Test Reminder**: Customers → select customer → "إرسال تذكير"
4. **Verify n8n** execution succeeded
5. **Seed Chart of Accounts**: Already done by `register_tenant` trigger
6. **Create First Admin User** (if not owner): Users → Invite

---

## 6. Upgrading / Schema Changes

### Migration Process

1. **Test on Dev**: Apply new migration to dev project, run all `.ps1` tests
2. **Backup Production**: Run `backup.ps1` (full)
3. **Apply to Production**: 
   ```powershell
   .\supabase\production\apply_migrations.ps1 -SupabaseUrl "..." -ServiceRoleKey "..."
   ```
4. **Verify**: Run `reports.ps1`, `reminders.ps1`, `party_statement.ps1` against prod
5. **Deploy Flutter**: Build with new `--dart-define` if needed, deploy web/app

### Adding a New Table

1. Create migration `00XX_new_table.sql`
2. Include: `tenant_id UUID NOT NULL DEFAULT get_my_tenant_id()`
3. Enable RLS: `ALTER TABLE new_table ENABLE ROW LEVEL SECURITY;`
4. Add policies: `CREATE POLICY ... USING (tenant_id = get_my_tenant_id())`
5. Grant: `GRANT SELECT, INSERT, UPDATE, DELETE ON new_table TO authenticated;`
6. **If financial table**: REVOKE INSERT/UPDATE/DELETE, create RPC for writes

---

## 7. Monitoring Endpoints

| Service | Health Check | Key Metrics |
|---------|--------------|-------------|
| Supabase | `https://<project>.supabase.co/health` | CPU, RAM, DB connections, Realtime |
| n8n | `https://n8n.domain.com/healthz` | Execution success rate, queue length |
| Flutter Web | `https://app.domain.com/` | Load time, JS errors (Sentry) |
| SMS Provider | Provider dashboard | Delivery rate, latency, cost |

---

## 8. Contacts & Credentials (Store Securely)

| Item | Location |
|------|----------|
| Supabase Production Project URL | Password Manager |
| Supabase Service Role Key | Password Manager (never in code) |
| Supabase DB Password | Password Manager |
| n8n Domain + Basic Auth | Password Manager |
| n8n Encryption Key | Password Manager |
| SMS Provider API Key | n8n Credentials (not in workflow JSON) |
| SMTP Credentials | Password Manager / Supabase Auth Settings |
| Backup Encryption Passphrase | Password Manager |

---

## 9. Emergency Contacts

| Role | Name | Contact |
|------|------|---------|
| Primary Admin | | |
| Secondary Admin | | |
| Supabase Support | | support@supabase.io |
| n8n Community | | https://community.n8n.io |
| SMS Provider Support | | |

---

## 10. Version History

| Date | Version | Changes |
|------|---------|---------|
| 2026-09-09 | 1.0 | Initial runbook for M9 launch |