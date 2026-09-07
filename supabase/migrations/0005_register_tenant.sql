-- 0005_register_tenant.sql
-- Bootstrap functions:
--   * seed_chart_of_accounts(p_tenant_id)       — the 14 default accounts (PROJECT_SPEC §3)
--   * register_tenant(p_name, p_owner_name)     — create business + link first admin user
-- Both are SECURITY DEFINER (they must act before/for a user who has no tenant yet)
-- but register_tenant re-validates auth.uid() and rejects users that already
-- belong to a tenant. Owner identity comes from the session (confirmed decision).

begin;

create or replace function public.seed_chart_of_accounts(p_tenant_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
    insert into public.accounts (tenant_id, code, name, type) values
        (p_tenant_id, '1010', 'النقدية',           'asset'),
        (p_tenant_id, '1015', 'البنك',              'asset'),
        (p_tenant_id, '1020', 'الذمم المدينة',      'asset'),
        (p_tenant_id, '1030', 'المخزون',            'asset'),
        (p_tenant_id, '1040', 'الأصول الثابتة',     'asset'),
        (p_tenant_id, '2010', 'الذمم الدائنة',      'liability'),
        (p_tenant_id, '2030', 'رواتب مستحقة',       'liability'),
        (p_tenant_id, '3010', 'رأس المال',          'equity'),
        (p_tenant_id, '3020', 'الأرباح المحتجزة',   'equity'),
        (p_tenant_id, '4010', 'إيرادات المبيعات',   'revenue'),
        (p_tenant_id, '4020', 'مردودات المبيعات',   'revenue'),
        (p_tenant_id, '5010', 'تكلفة البضاعة المباعة', 'expense'),
        (p_tenant_id, '5020', 'المصروفات التشغيلية',  'expense'),
        (p_tenant_id, '5030', 'الأجور والرواتب',      'expense');
end;
$$;

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

    insert into public.users (tenant_id, auth_user_id, name, role)
    values (v_tenant_id, v_uid, v_owner_name, 'admin');

    perform public.seed_chart_of_accounts(v_tenant_id);

    return v_tenant_id;
end;
$$;

revoke all on function public.seed_chart_of_accounts(uuid) from public;
revoke all on function public.register_tenant(text, text)  from public;

grant execute on function public.seed_chart_of_accounts(uuid) to authenticated;
grant execute on function public.register_tenant(text, text)  to authenticated;

commit;