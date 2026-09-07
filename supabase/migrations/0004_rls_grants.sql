-- 0004_rls_grants.sql
-- Row Level Security + grants. Primary isolation layer (PROJECT_SPEC §12).
--   * Master tables  (customers, suppliers, products, expenses): full CRUD via RLS.
--   * Financial tables: SELECT only — writes happen exclusively through RPC functions
--     (invoices, invoice_items, journal_entries, journal_entry_lines, payments,
--      commission_dues, salaries, employee_movements, stock_moves).
--   * tables with no tenant_id (invoice_items, journal_entry_lines) are scoped
--     through their parent via EXISTS subquery.
--   * processed_requests is handled in 0011_idempotency.sql.

begin;

-- =====================================================================
-- Master tables — authenticated callers manage their own tenant's rows
-- =====================================================================

alter table public.customers enable row level security;
create policy tenant_isolation on public.customers
    for all
    using (tenant_id = public.get_my_tenant_id())
    with check (tenant_id = public.get_my_tenant_id());

alter table public.suppliers enable row level security;
create policy tenant_isolation on public.suppliers
    for all
    using (tenant_id = public.get_my_tenant_id())
    with check (tenant_id = public.get_my_tenant_id());

alter table public.products enable row level security;
create policy tenant_isolation on public.products
    for all
    using (tenant_id = public.get_my_tenant_id())
    with check (tenant_id = public.get_my_tenant_id());

alter table public.expenses enable row level security;
create policy tenant_isolation on public.expenses
    for all
    using (tenant_id = public.get_my_tenant_id())
    with check (tenant_id = public.get_my_tenant_id());

-- =====================================================================
-- Financial tables — READ ONLY via RLS
-- =====================================================================

alter table public.invoices enable row level security;
create policy tenant_isolation_select on public.invoices
    for select
    using (tenant_id = public.get_my_tenant_id());

alter table public.invoice_items enable row level security;
create policy tenant_isolation_select on public.invoice_items
    for select
    using (
        exists (
            select 1 from public.invoices i
            where i.id = invoice_id
              and i.tenant_id = public.get_my_tenant_id()
        )
    );

alter table public.journal_entries enable row level security;
create policy tenant_isolation_select on public.journal_entries
    for select
    using (tenant_id = public.get_my_tenant_id());

alter table public.journal_entry_lines enable row level security;
create policy tenant_isolation_select on public.journal_entry_lines
    for select
    using (
        exists (
            select 1 from public.journal_entries je
            where je.id = entry_id
              and je.tenant_id = public.get_my_tenant_id()
        )
    );

alter table public.payments enable row level security;
create policy tenant_isolation_select on public.payments
    for select
    using (tenant_id = public.get_my_tenant_id());

alter table public.commission_dues enable row level security;
create policy tenant_isolation_select on public.commission_dues
    for select
    using (tenant_id = public.get_my_tenant_id());

alter table public.salaries enable row level security;
create policy tenant_isolation_select on public.salaries
    for select
    using (tenant_id = public.get_my_tenant_id());

alter table public.employee_movements enable row level security;
create policy tenant_isolation_select on public.employee_movements
    for select
    using (tenant_id = public.get_my_tenant_id());

alter table public.stock_moves enable row level security;
create policy tenant_isolation_select on public.stock_moves
    for select
    using (tenant_id = public.get_my_tenant_id());

-- =====================================================================
-- users / accounts / tenants
-- =====================================================================

alter table public.users enable row level security;
create policy own_or_same_tenant on public.users
    for select
    using (auth_user_id = auth.uid() or tenant_id = public.get_my_tenant_id());

alter table public.accounts enable row level security;
create policy tenant_isolation_select on public.accounts
    for select
    using (tenant_id = public.get_my_tenant_id());

alter table public.tenants enable row level security;
create policy tenant_isolation_select on public.tenants
    for select
    using (id = public.get_my_tenant_id());

-- =====================================================================
-- Grants
-- =====================================================================

-- Full CRUD on master tables for authenticated users.
grant select, insert, update, delete on public.customers to authenticated;
grant select, insert, update, delete on public.suppliers to authenticated;
grant select, insert, update, delete on public.products   to authenticated;
grant select, insert, update, delete on public.expenses   to authenticated;

-- Read-only on financial tables.
grant select on public.invoices           to authenticated;
grant select on public.invoice_items      to authenticated;
grant select on public.journal_entries    to authenticated;
grant select on public.journal_entry_lines to authenticated;
grant select on public.payments           to authenticated;
grant select on public.commission_dues    to authenticated;
grant select on public.salaries           to authenticated;
grant select on public.employee_movements to authenticated;
grant select on public.stock_moves        to authenticated;

-- Read on the auxiliary tables.
grant select on public.users    to authenticated;
grant select on public.accounts to authenticated;
grant select on public.tenants  to authenticated;

-- Explicitly no INSERT/UPDATE/DELETE for authenticated on financial tables.
revoke insert, update, delete on public.invoices           from authenticated;
revoke insert, update, delete on public.invoice_items      from authenticated;
revoke insert, update, delete on public.journal_entries    from authenticated;
revoke insert, update, delete on public.journal_entry_lines from authenticated;
revoke insert, update, delete on public.payments           from authenticated;
revoke insert, update, delete on public.commission_dues    from authenticated;
revoke insert, update, delete on public.salaries           from authenticated;
revoke insert, update, delete on public.employee_movements from authenticated;
revoke insert, update, delete on public.stock_moves        from authenticated;

-- Anonymous role gets nothing.
revoke all on public.customers from anon;
revoke all on public.suppliers from anon;
revoke all on public.products   from anon;
revoke all on public.expenses   from anon;
revoke all on public.invoices           from anon;
revoke all on public.invoice_items      from anon;
revoke all on public.journal_entries    from anon;
revoke all on public.journal_entry_lines from anon;
revoke all on public.payments           from anon;
revoke all on public.commission_dues    from anon;
revoke all on public.salaries           from anon;
revoke all on public.employee_movements from anon;
revoke all on public.stock_moves        from anon;
revoke all on public.users    from anon;
revoke all on public.accounts from anon;
revoke all on public.tenants  from anon;

commit;