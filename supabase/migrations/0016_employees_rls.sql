-- 0016_employees_rls.sql
-- employees existed since 0002 but was never covered by 0004_rls_grants.sql
-- (which handles customers/suppliers/products/expenses only): RLS was disabled and
-- no table grants existed, so `authenticated` could neither CRUD employees nor run
-- the salary RPCs (all `security invoker`) — those select from public.employees at
-- runtime and fail with "permission denied for table employees".
-- Fix: promote employees to the master-table pattern (full tenant-scoped CRUD via RLS).

begin;

alter table public.employees enable row level security;

create policy tenant_isolation on public.employees
    for all
    using (tenant_id = public.get_my_tenant_id())
    with check (tenant_id = public.get_my_tenant_id());

grant select, insert, update, delete on public.employees to authenticated;
revoke all on public.employees from anon;

commit;