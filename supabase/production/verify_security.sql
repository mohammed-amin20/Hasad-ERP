-- =====================================================================
-- verify_security.sql  —  Hasad ERP production security checklist (S3)
--
-- Run in the Supabase SQL Editor as role `postgres` AFTER pasting
-- prod_schema.sql AND reapply_rls.sql (and reapply_reminder_rpcs.sql).
-- Every block prints a label then a result. Green = 0 rows (or exactly
-- the expected allowlist). Any row returned is a finding to fix.
--
-- Mirrors README Section 6 "Security Checklist (Run Before Go-Live)".
-- =====================================================================

select '=== 1. Public tables WITHOUT row-level security (expect 0 rows) ===' as check;
select t.tablename
from pg_tables t
where t.schemaname = 'public'
  and t.tablename not in ('_prisma_migrations', 'schema_migrations')
  and not exists (
      select 1
      from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
      where c.relname = t.tablename
        and n.nspname = t.schemaname
        and c.relrowsecurity
  );

select '=== 2. Public tables without RLS FORCED (reapply_rls forces all; expect 0 rows) ===' as check;
select c.relname
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relkind = 'r'
  and c.relrowsecurity
  and not c.relforcerowsecurity;

select '=== 3. Tables with ZERO RLS policies (expect 0 rows) ===' as check;
select t.tablename,
       count(p.policyname) as policies
from pg_tables t
left join pg_policies p on p.schemaname = t.schemaname and p.tablename = t.tablename
where t.schemaname = 'public'
  and t.tablename not in ('_prisma_migrations', 'schema_migrations')
group by t.tablename
having count(p.policyname) = 0;

select '=== 4. Financial tables with direct DML granted to authenticated (expect 0 rows) ===' as check;
select table_name, privilege_type
from information_schema.role_table_grants
where grantee = 'authenticated'
  and privilege_type in ('INSERT', 'UPDATE', 'DELETE')
  and table_name in (
      'invoices', 'invoice_items', 'journal_entries', 'journal_entry_lines',
      'payments', 'commission_dues', 'salaries', 'employee_movements', 'stock_moves'
  );

select '=== 5. Any public-table privilege granted to anon (expect 0 rows) ===' as check;
select table_name, privilege_type
from information_schema.role_table_grants
where grantee = 'anon'
  and table_schema = 'public';

select '=== 6. SECURITY DEFINER functions in public (expect ONLY the allowlist: get_my_tenant_id, seed_chart_of_accounts, register_tenant, seed_tenant_settings, _fire_reminder, send_due_reminders, switch_tenant) ===' as check;
select p.oid::regprocedure::text as definer_function,
       coalesce(t.tgname, '') as trigger_name
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
left join pg_trigger t on t.tgfoid = p.oid and not t.tgisinternal
where n.nspname = 'public'
  and p.prosecdef;

select '=== 7. Business RPC execute granted to anon (write/read RPCs are authenticated-only; expect 0 rows) ===' as check;
select routine_name, privilege_type
from information_schema.role_routine_grants
where grantee = 'anon'
  and routine_schema = 'public';

select '=== 8. pg_cron jobs (expect only reminder scheduling) ===' as check;
select jobid, command, schedule
from cron.job
order by jobid;

select '=== 9. service_role DML on financial tables is INTENTIONAL (informational — service_role bypasses RLS) ===' as check;
select table_name, privilege_type
from information_schema.role_table_grants
where grantee = 'service_role'
  and privilege_type in ('INSERT', 'UPDATE', 'DELETE')
  and table_name in (
      'invoices', 'invoice_items', 'journal_entries', 'journal_entry_lines',
      'payments', 'commission_dues', 'salaries', 'employee_movements', 'stock_moves'
  );

select '=== 10. Tenants/users counts (informational) ===' as check;
select
  (select count(*) from public.tenants)            as tenants,
  (select count(*) from public.users)              as users,
  (select count(*) from public.user_tenants)       as user_tenants,
  (select count(*) from public.journal_entries)    as journal_entries;