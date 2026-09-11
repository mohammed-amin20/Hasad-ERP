-- ============================================================================
-- reapply_rls.sql  (REMEDIATION for the DEV database)
--
-- WHY: m9_full_suite.ps1 T1 exposed a tenant-isolation failure in DEV — tenant
-- A (owner4) and tenant B (owner2) can read each other's customers / products /
-- suppliers / invoices / tenants. RLS was enabled + policies declared in
-- migrations 0004/0006/0011/0013/0016, but in DEV the enforcement layer is not
-- active (tables are owner-bypassed or the enable+policy statements never took
-- effect). International side-effect of that old state: the app widely relies
-- on `security invoker` write-RPCs, so merely re-applying 0004 verbatim (which
-- REVOKES INSERT/UPDATE/DELETE on the financial tables from `authenticated`)
-- would break those RPCs with permission-denied.
--
-- WHAT THIS DOES (app-preserving):
--   1. enable row level security            on every tenant-scoped table
--   2. force row level security             on every tenant-scoped table
--      (RLS now applies EVEN IF a table is owned by `authenticated`, which is
--      the recommended production stance; superusers/service_role still bypass)
--   3. drop + recreate every isolation policy   (safe to re-run at any time)
-- It does NOT touch grants, so the privileges `authenticated` already has stay
-- intact — the app and the RPC regression suites keep working, but each tenant
-- now only ever sees/acts on its own rows.
--
-- Paste the whole block once into the Supabase SQL Editor (role: postgres).
-- ============================================================================
begin;

-- ---------------------------------------------------------------------------
-- 1+2. Enable and force RLS
-- ---------------------------------------------------------------------------
alter table public.tenants             enable row level security;
alter table public.users               enable row level security;
alter table public.customers           enable row level security;
alter table public.suppliers           enable row level security;
alter table public.products            enable row level security;
alter table public.expenses            enable row level security;
alter table public.invoices            enable row level security;
alter table public.invoice_items       enable row level security;
alter table public.journal_entries     enable row level security;
alter table public.journal_entry_lines enable row level security;
alter table public.payments            enable row level security;
alter table public.commission_dues     enable row level security;
alter table public.salaries            enable row level security;
alter table public.employee_movements  enable row level security;
alter table public.stock_moves         enable row level security;
alter table public.accounts            enable row level security;
alter table public.invoice_counters    enable row level security;
alter table public.employees           enable row level security;
alter table public.tenant_settings     enable row level security;
alter table public.reminder_log        enable row level security;
alter table public.processed_requests  enable row level security;

alter table public.tenants             force row level security;
alter table public.users               force row level security;
alter table public.customers           force row level security;
alter table public.suppliers           force row level security;
alter table public.products            force row level security;
alter table public.expenses            force row level security;
alter table public.invoices            force row level security;
alter table public.invoice_items       force row level security;
alter table public.journal_entries     force row level security;
alter table public.journal_entry_lines force row level security;
alter table public.payments            force row level security;
alter table public.commission_dues     force row level security;
alter table public.salaries            force row level security;
alter table public.employee_movements  force row level security;
alter table public.stock_moves         force row level security;
alter table public.accounts            force row level security;
alter table public.invoice_counters    force row level security;
alter table public.employees           force row level security;
alter table public.tenant_settings     force row level security;
alter table public.reminder_log        force row level security;
alter table public.processed_requests  force row level security;

-- ---------------------------------------------------------------------------
-- 3. Isolation policies (drop + create = idempotent)
-- ---------------------------------------------------------------------------

-- Master / aux tables: full tenant-scoped CRUD
drop policy if exists tenant_isolation on public.customers;
create policy tenant_isolation on public.customers
    for all
    using (tenant_id = public.get_my_tenant_id())
    with check (tenant_id = public.get_my_tenant_id());

drop policy if exists tenant_isolation on public.suppliers;
create policy tenant_isolation on public.suppliers
    for all
    using (tenant_id = public.get_my_tenant_id())
    with check (tenant_id = public.get_my_tenant_id());

drop policy if exists tenant_isolation on public.products;
create policy tenant_isolation on public.products
    for all
    using (tenant_id = public.get_my_tenant_id())
    with check (tenant_id = public.get_my_tenant_id());

drop policy if exists tenant_isolation on public.expenses;
create policy tenant_isolation on public.expenses
    for all
    using (tenant_id = public.get_my_tenant_id())
    with check (tenant_id = public.get_my_tenant_id());

drop policy if exists tenant_isolation on public.employees;
create policy tenant_isolation on public.employees
    for all
    using (tenant_id = public.get_my_tenant_id())
    with check (tenant_id = public.get_my_tenant_id());

drop policy if exists tenant_isolation on public.invoice_counters;
create policy tenant_isolation on public.invoice_counters
    for all
    using (tenant_id = public.get_my_tenant_id())
    with check (tenant_id = public.get_my_tenant_id());

drop policy if exists tenant_isolation on public.tenant_settings;
create policy tenant_isolation on public.tenant_settings
    for all
    using (tenant_id = public.get_my_tenant_id())
    with check (tenant_id = public.get_my_tenant_id());

-- Financial tables: tenant-scoped SELECT via RLS
drop policy if exists tenant_isolation_select on public.invoices;
create policy tenant_isolation_select on public.invoices
    for select
    using (tenant_id = public.get_my_tenant_id());

drop policy if exists tenant_isolation_select on public.invoice_items;
create policy tenant_isolation_select on public.invoice_items
    for select
    using (
        exists (
            select 1 from public.invoices i
            where i.id = invoice_id
              and i.tenant_id = public.get_my_tenant_id()
        )
    );

drop policy if exists tenant_isolation_select on public.journal_entries;
create policy tenant_isolation_select on public.journal_entries
    for select
    using (tenant_id = public.get_my_tenant_id());

drop policy if exists tenant_isolation_select on public.journal_entry_lines;
create policy tenant_isolation_select on public.journal_entry_lines
    for select
    using (
        exists (
            select 1 from public.journal_entries je
            where je.id = entry_id
              and je.tenant_id = public.get_my_tenant_id()
        )
    );

drop policy if exists tenant_isolation_select on public.payments;
create policy tenant_isolation_select on public.payments
    for select
    using (tenant_id = public.get_my_tenant_id());

drop policy if exists tenant_isolation_select on public.commission_dues;
create policy tenant_isolation_select on public.commission_dues
    for select
    using (tenant_id = public.get_my_tenant_id());

drop policy if exists tenant_isolation_select on public.salaries;
create policy tenant_isolation_select on public.salaries
    for select
    using (tenant_id = public.get_my_tenant_id());

drop policy if exists tenant_isolation_select on public.employee_movements;
create policy tenant_isolation_select on public.employee_movements
    for select
    using (tenant_id = public.get_my_tenant_id());

drop policy if exists tenant_isolation_select on public.stock_moves;
create policy tenant_isolation_select on public.stock_moves
    for select
    using (tenant_id = public.get_my_tenant_id());

drop policy if exists tenant_isolation_select on public.accounts;
create policy tenant_isolation_select on public.accounts
    for select
    using (tenant_id = public.get_my_tenant_id());

drop policy if exists tenant_isolation_select on public.reminder_log;
create policy tenant_isolation_select on public.reminder_log
    for select
    using (tenant_id = public.get_my_tenant_id());

-- Financial tables: tenant-scoped INSERT / UPDATE used by the invoker RPCs
drop policy if exists tenant_isolation_insert on public.invoices;
create policy tenant_isolation_insert on public.invoices
    for insert
    with check (tenant_id = public.get_my_tenant_id());

drop policy if exists tenant_isolation_insert on public.invoice_items;
create policy tenant_isolation_insert on public.invoice_items
    for insert
    with check (exists (
        select 1 from public.invoices i
        where i.id = invoice_id
          and i.tenant_id = public.get_my_tenant_id()
    ));

drop policy if exists tenant_isolation_insert on public.journal_entries;
create policy tenant_isolation_insert on public.journal_entries
    for insert
    with check (tenant_id = public.get_my_tenant_id());

drop policy if exists tenant_isolation_insert on public.journal_entry_lines;
create policy tenant_isolation_insert on public.journal_entry_lines
    for insert
    with check (exists (
        select 1 from public.journal_entries je
        where je.id = entry_id
          and je.tenant_id = public.get_my_tenant_id()
    ));

drop policy if exists tenant_isolation_insert on public.payments;
create policy tenant_isolation_insert on public.payments
    for insert
    with check (tenant_id = public.get_my_tenant_id());

drop policy if exists tenant_isolation_insert on public.commission_dues;
create policy tenant_isolation_insert on public.commission_dues
    for insert
    with check (tenant_id = public.get_my_tenant_id());

drop policy if exists tenant_isolation_insert on public.salaries;
create policy tenant_isolation_insert on public.salaries
    for insert
    with check (tenant_id = public.get_my_tenant_id());

drop policy if exists tenant_isolation_insert on public.employee_movements;
create policy tenant_isolation_insert on public.employee_movements
    for insert
    with check (tenant_id = public.get_my_tenant_id());

drop policy if exists tenant_isolation_insert on public.stock_moves;
create policy tenant_isolation_insert on public.stock_moves
    for insert
    with check (tenant_id = public.get_my_tenant_id());

drop policy if exists tenant_isolation_insert on public.accounts;
create policy tenant_isolation_insert on public.accounts
    for insert
    with check (tenant_id = public.get_my_tenant_id());

drop policy if exists tenant_isolation_insert on public.processed_requests;
create policy tenant_isolation_insert on public.processed_requests
    for insert
    with check (tenant_id = public.get_my_tenant_id());

drop policy if exists tenant_isolation_select on public.processed_requests;
create policy tenant_isolation_select on public.processed_requests
    for select
    using (tenant_id = public.get_my_tenant_id());

drop policy if exists tenant_isolation_update on public.invoices;
create policy tenant_isolation_update on public.invoices
    for update
    using (tenant_id = public.get_my_tenant_id())
    with check (tenant_id = public.get_my_tenant_id());

drop policy if exists tenant_isolation_update on public.commission_dues;
create policy tenant_isolation_update on public.commission_dues
    for update
    using (tenant_id = public.get_my_tenant_id())
    with check (tenant_id = public.get_my_tenant_id());

-- users: owner or same-tenant visibility
drop policy if exists own_or_same_tenant on public.users;
create policy own_or_same_tenant on public.users
    for select
    using (auth_user_id = auth.uid() or tenant_id = public.get_my_tenant_id());

-- tenants: each role only sees its own tenant row
drop policy if exists tenant_isolation_select on public.tenants;
create policy tenant_isolation_select on public.tenants
    for select
    using (id = public.get_my_tenant_id());

commit;