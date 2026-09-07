-- 0003_auth_helpers.sql
-- Tenant/auth helpers used by every RLS policy and by the Flutter app.
-- get_my_tenant_id() is SECURITY DEFINER so policies can read the caller's
-- tenant even when the caller has no SELECT on `users`. It is STABLE + strict
-- search_path to prevent hijacking.
-- get_my_user() / get_my_role() are SECURITY INVOKER (subject to RLS).

begin;

create or replace function public.get_my_tenant_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
    select tenant_id
    from public.users
    where auth_user_id = auth.uid()
    limit 1;
$$;

create or replace function public.get_my_user()
returns public.users
language sql
stable
security invoker
set search_path = public
as $$
    select *
    from public.users
    where auth_user_id = auth.uid()
    limit 1;
$$;

create or replace function public.get_my_role()
returns text
language sql
stable
security invoker
set search_path = public
as $$
    select role
    from public.get_my_user();
$$;

-- Functions are PUBLIC-executable by default; restrict to authenticated users.
revoke all on function public.get_my_tenant_id() from public;
revoke all on function public.get_my_user()     from public;
revoke all on function public.get_my_role()     from public;

grant execute on function public.get_my_tenant_id() to authenticated;
grant execute on function public.get_my_user()     to authenticated;
grant execute on function public.get_my_role()     to authenticated;

commit;