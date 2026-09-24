-- 0023_register_tenant_stamps_tenant.sql
-- M11 Slice A — the register_tenant onboarding seam.
--
-- Byte-truth defect (proven by reading 0005 + 0021 + 0022-era handoff):
--   * register_tenant (0005) inserts tenants+users but NEVER stamps
--     users.current_tenant_id (the column only appeared in 0021) and NEVER
--     writes user_tenants. On a post-0021 database a user who calls
--     register_tenant gets current_tenant_id = NULL, so:
--       - get_my_tenant_id() (now reading current_tenant_id) returns NULL
--       - the Flutter getUserTenants() direct-select 403s (user_tenants has
--         NO grants — byte-proven: zero grant/policy rows in 0021)
--       - switch_tenant(own) fails "ليس لديك صلاحية التبديل لهذه المؤسسة"
--   * => a brand new tenant canNOT be entered/used. Onboarding is broken.
--
-- Fix (0 new tables, 0 new columns — pure register_tenant body re-shape +
-- one new read RPC that replaces the forbidden direct user_tenants select):
--   1. register_tenant now ALSO:
--        - stamps users.current_tenant_id = v_tenant_id
--        - inserts the admin membership row into user_tenants
--          (user_id, tenant_id, role='admin') within the SAME SECURITY
--          DEFINER transaction (no separate grants/RLS on user_tenants —
--          membership is proven via the RPC/switch path only, never by
--          direct select, per AGENTS standing fact).
--   2. NEW get_user_tenants() RPC (security invoker, joins user_tenants ->
--      tenants for name+role of the caller's memberships) — the ONLY way the
--      app lists workspaces. It performs the join server-side so the app
--      never direct-selects user_tenants.
--
-- Deviation note for SYSTEM_DESIGN §4: new RPC get_user_tenants() added to
-- the onboarding surface = RPC contract CHANGED → SYSTEM_DESIGN RPC table
-- gets a row (see ceremony), and README_supabase_only gains the migration
-- 0023 + the register_tenant_onboard.ps1 test-row.

begin;

-- ---------------------------------------------------------------------------
-- 1. register_tenant — now completes onboarding (stamp + membership) atomically
-- ---------------------------------------------------------------------------
create or replace function public.register_tenant(p_name text, p_owner_name text default null)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
    v_uid         uuid := auth.uid();
    v_tenant_id   uuid;
    v_owner_name  text;
    v_user_id     uuid;
begin
    if v_uid is null then
        raise exception 'يجب تسجيل الدخول أولاً قبل إنشاء المؤسسة';
    end if;

    if exists (select 1 from public.users where auth_user_id = v_uid) then
        raise exception 'هذا المستخدم مسجل بالفعل في مؤسسة';
    end if;

    v_owner_name := coalesce(
        nullif(trim(p_owner_name), ''),
        (select raw_user_meta_data ->> 'full_name' from auth.users where id = v_uid)
    );
    v_owner_name := coalesce(nullif(trim(v_owner_name), ''), 'مدير');

    insert into public.tenants (name)
    values (p_name)
    returning id into v_tenant_id;

    insert into public.users (tenant_id, auth_user_id, name, role, current_tenant_id)
    values (v_tenant_id, v_uid, v_owner_name, 'admin', v_tenant_id)
    returning id into v_user_id;

    -- M11 Slice A: stamp the JOIN row so switch_tenant(own) + get_user_tenants()
    -- work the moment onboarding completes (this was the broken leg).
    insert into public.user_tenants (user_id, tenant_id, role)
    values (v_user_id, v_tenant_id, 'admin');

    perform public.seed_chart_of_accounts(v_tenant_id);

    return v_tenant_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- 2. get_user_tenants() — the ONLY workspace-list read (server-side join,
--    never a direct user_tenants select). security invoker: caller's own
--    membership only.
-- ---------------------------------------------------------------------------
create or replace function public.get_user_tenants()
returns table (
    tenant_id uuid,
    tenant_name text,
    role      text
)
language sql
stable
security invoker
set search_path = public
as $$
    select ut.tenant_id,
           t.name as tenant_name,
           ut.role
    from public.user_tenants ut
    join public.tenants t on t.id = ut.tenant_id
    where ut.user_id = (
        select u.id from public.users u where u.auth_user_id = auth.uid() limit 1
    )
    order by t.name
$$;

-- ---------------------------------------------------------------------------
-- 3. Grants (user_tenants itself stays grant-free — byte discipline).
-- ---------------------------------------------------------------------------
revoke all on function public.register_tenant(text, text)                from public;
grant  execute on function public.register_tenant(text, text)            to authenticated;

revoke all on function public.get_user_tenants()                          from public;
grant  execute on function public.get_user_tenants()                      to authenticated;

commit;
