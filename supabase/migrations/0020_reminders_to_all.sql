-- 0020_reminders_to_all.sql
-- M8: app-callable "remind everyone overdue" for the reminders settings screen.
--
--   * send_reminders_to_all(): SECURITY INVOKER, tenant-scoped mirror of the
--     daily send_due_reminders() (migration 0013) - same overdue scan, template
--     and webhook path via _fire_reminder - but callable by the app's
--     "remind all" button. send_due_reminders() stays cron-only (revoked from
--     authenticated) and is NOT touched.
--   * Manual override semantics: reminder_enabled only gates the daily cron
--     job; a manual "remind all" fires regardless. A missing webhook still
--     fails loudly (matches send_reminder_now).
--   * Same-day dedupe is inherited from _fire_reminder/reminder_log (each
--     customer is reminded at most once per day), so re-running the button
--     on the same day is a no-op for customers already logged today.

create or replace function public.send_reminders_to_all()
returns jsonb
language plpgsql
security invoker
set search_path = public, net
as $$
declare
    v_tenant   uuid := public.get_my_tenant_id();
    v_set      record;
    v_company  text;
    v_cutoff   date;
    v_sent     integer := 0;
    v_log_id   uuid;
    c          record;
begin
    if v_tenant is null then
        raise exception 'يجب تسجيل الدخول أولاً';
    end if;

    -- Settings row is seeded per tenant; ensure it exists like send_reminder_now.
    select * into v_set
    from public.tenant_settings s
    where s.tenant_id = v_tenant;

    if v_set.tenant_id is null then
        insert into public.tenant_settings (tenant_id) values (v_tenant)
        on conflict (tenant_id) do nothing;
        select * into v_set from public.tenant_settings s where s.tenant_id = v_tenant;
    end if;

    if v_set.reminder_webhook_url is null or v_set.reminder_webhook_url = '' then
        raise exception 'لا يوجد رابط Webhook مضبوط للتنبيهات';
    end if;

    select name into v_company from public.tenants where id = v_tenant;

    v_cutoff := current_date - v_set.reminder_days_threshold;

    for c in
        select cu.id as customer_id, cu.name as customer_name, cu.phone,
               sum(i.remaining) as amount
        from public.invoices i
        join public.customers cu on cu.id = i.party_id and cu.tenant_id = i.tenant_id
        where i.tenant_id = v_tenant
        and i.type = 'sale'
        and i.ownership = 'owned'
        and i.remaining > 0
        and i.date <= v_cutoff
        and cu.phone is not null and cu.phone <> ''
        group by cu.id, cu.name, cu.phone
        having not exists (
            select 1 from public.reminder_log lg
            where lg.tenant_id = v_tenant
            and lg.customer_id = cu.id
            and lg.created_at::date = current_date
        )
    loop
        v_log_id := public._fire_reminder(
            v_tenant, c.customer_id, c.customer_name, c.phone,
            c.amount, v_set.reminder_webhook_url, v_set.reminder_message, v_company
        );
        v_sent := v_sent + 1;
    end loop;

    return jsonb_build_object('sent', v_sent);
end;
$$;

revoke all on function public.send_reminders_to_all() from public;
grant execute on function public.send_reminders_to_all() to authenticated;