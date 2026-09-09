-- 0021_user_tenants.sql
-- Multi-business support: many-to-many user ↔ tenant with current tenant pointer

begin;

-- 1. Join table for many-to-many user ↔ tenant
create table public.user_tenants (
    user_id   uuid not null references public.users(id) on delete cascade,
    tenant_id uuid not null references public.tenants(id) on delete cascade,
    role      text not null check (role in ('admin', 'accountant', 'sales')),
    primary key (user_id, tenant_id)
);

-- 2. Migrate existing single-tenant users
insert into public.user_tenants (user_id, tenant_id, role)
select id, tenant_id, role
from public.users
where tenant_id is not null;

-- 3. Current tenant pointer on users (for session/default)
alter table public.users add column current_tenant_id uuid references public.tenants(id);

-- 4. Backfill current_tenant_id from existing tenant_id
update public.users set current_tenant_id = tenant_id where tenant_id is not null;

-- 5. Update get_my_tenant_id() to read current_tenant_id
create or replace function public.get_my_tenant_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
    select current_tenant_id
    from public.users
    where auth_user_id = auth.uid()
    limit 1;
$$;

-- 6. Switch-tenant RPC (SECURITY DEFINER, validates membership)
create or replace function public.switch_tenant(p_tenant_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    v_user_id uuid := (select id from public.users where auth_user_id = auth.uid());
begin
    if not exists (
        select 1 from public.user_tenants
        where user_id = v_user_id and tenant_id = p_tenant_id
    ) then
        raise exception 'User does not have access to tenant %', p_tenant_id;
    end if;
    
    update public.users
    set current_tenant_id = p_tenant_id
    where id = v_user_id;
end;
$$;

grant execute on function public.switch_tenant(uuid) to authenticated;

commit;