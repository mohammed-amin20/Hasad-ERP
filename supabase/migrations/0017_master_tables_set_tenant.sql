-- 0017_master_tables_set_tenant.sql
-- Fix: direct `.from('table')` inserts into the master tables (customers,
-- suppliers, products, expenses, employees) by PostgREST never carry a
-- tenant_id, and nothing stamped one — so the RLS policy
-- `with check (tenant_id = public.get_my_tenant_id())` evaluated
-- `NULL = <tenant>` → false → PostgREST 403 "new row violates row-level
-- security policy". The app and the regression scripts both omit tenant_id.
-- Fix: a BEFORE INSERT trigger stamps tenant_id from the caller's JWT
-- (via the SECURITY DEFINER helper get_my_tenant_id, 0003) BEFORE the RLS
-- with-check runs. The `if null` guard keeps security-definer RPC paths
-- (register_tenant, invoices, salary RPCs ... all pass explicit tenant_id)
-- untouched.

begin;

create or replace function public.set_master_tenant()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
    if new.tenant_id is null then
        new.tenant_id := public.get_my_tenant_id();
    end if;
    return new;
end;
$$;

drop trigger if exists trg_set_tenant on public.employees;
create trigger trg_set_tenant
    before insert on public.employees
    for each row execute function public.set_master_tenant();

drop trigger if exists trg_set_tenant on public.customers;
create trigger trg_set_tenant
    before insert on public.customers
    for each row execute function public.set_master_tenant();

drop trigger if exists trg_set_tenant on public.suppliers;
create trigger trg_set_tenant
    before insert on public.suppliers
    for each row execute function public.set_master_tenant();

drop trigger if exists trg_set_tenant on public.products;
create trigger trg_set_tenant
    before insert on public.products
    for each row execute function public.set_master_tenant();

drop trigger if exists trg_set_tenant on public.expenses;
create trigger trg_set_tenant
    before insert on public.expenses
    for each row execute function public.set_master_tenant();

commit;