-- ============================================================================
-- reapply_reminder_rpcs.sql  (REMEDIATION for the DEV database)
--
-- WHY: m9_full_suite.ps1 T9 exposed that the LIVE reminder RPCs in DEV are a
-- stale M8 draft. Calling send_reminder_now / send_reminders_to_all fails with:
--
--   {"code":"42703","message":"column \"company_name\" does not exist"}
--
-- The migrations in this repo (0013 + 0020) are already the corrected versions
-- (they read `select name into v_company from public.tenants`; `company_name`
-- exists only as a SELECT alias) — DEV's deployed bodies still reference a
-- `company_name` table column that no longer exists. Re-pasting the full 0013
-- is NOT safe (tables/policies/triggers already exist and are unguarded), so
-- this script DROPS any M8-draft overloads by name and re-creates ONLY the four
-- function definitions (idempotent: drop-then-create) plus their grants and the
-- cron schedule. Tables/policies/grants for tenant_settings + reminder_log are
-- already in place.
--
-- Paste the whole block once into the Supabase SQL Editor (role: postgres).
-- Requires pg_net (net schema) for net.http_post; pg_cron for the schedule.
-- ============================================================================
begin;

-- ---------------------------------------------------------------------------
-- Drop old M8-draft bodies by name (all overloads). `create or replace` cannot
-- change a function's return type, and the editor auto-commits per statement,
-- so an old draft with a different signature/return type can quietly survive a
-- re-paste. Dropping first guarantees the fresh definitions below take over.
-- ---------------------------------------------------------------------------
do $$
declare
    v record;
begin
    for v in
        select p.oid::regprocedure as sig
        from pg_proc p
        join pg_namespace n on n.oid = p.pronamespace
        where n.nspname = 'public'
          and p.proname in ('_fire_reminder', 'send_due_reminders',
                            'send_reminder_now', 'send_reminders_to_all')
    loop
        execute 'drop function ' || v.sig;
    end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- _fire_reminder (internal helper; owner/cron only)
-- ---------------------------------------------------------------------------
create or replace function public._fire_reminder(
    p_tenant_id     uuid,
    p_customer_id   uuid,
    p_customer_name text,
    p_phone         text,
    p_amount        numeric,
    p_webhook       text,
    p_template      text,
    p_company_name  text
) returns uuid
language plpgsql
security definer
set search_path = public, net
as $$
declare
    v_msg    text := p_template;
    v_amount_text text;
    v_log_id uuid;
begin
    v_amount_text := to_char(p_amount::numeric / 100.0, 'FM99999999990.00');

    v_msg := replace(v_msg, '{customer_name}', coalesce(p_customer_name, ''));
    v_msg := replace(v_msg, '{amount}',        v_amount_text);
    v_msg := replace(v_msg, '{company_name}',  coalesce(p_company_name, ''));
    v_msg := replace(v_msg, '{phone}',         coalesce(p_phone, ''));

    insert into public.reminder_log (tenant_id, customer_id, amount, phone, message, status)
    values (p_tenant_id, p_customer_id, p_amount::bigint, p_phone, v_msg, 'sent')
    returning id into v_log_id;

    perform net.http_post(
        p_webhook,
        '{"Content-Type": "application/json"}'::jsonb,
        jsonb_build_object(
            'customer_name', coalesce(p_customer_name, ''),
            'amount',        p_amount,
            'amount_text',   v_amount_text,
            'phone',         coalesce(p_phone, ''),
            'message',       v_msg
        )
    );

    return v_log_id;
exception
    when others then
        insert into public.reminder_log (tenant_id, customer_id, amount, phone, message, status, error)
        values (p_tenant_id, p_customer_id, p_amount, p_phone,
                v_msg, 'failed', sqlerrm);
        raise;
end;
$$;

revoke all on function public._fire_reminder(uuid, uuid, text, text, numeric, text, text, text) from public;

-- ---------------------------------------------------------------------------
-- send_due_reminders (daily cron; not exposed to authenticated)
-- ---------------------------------------------------------------------------
create or replace function public.send_due_reminders()
returns integer
language plpgsql
security definer
set search_path = public, net
as $$
declare
    v_sent   integer := 0;
    v_log_id uuid;
    r        record;
    c        record;
    v_cutoff date;
begin
    for r in
        select s.tenant_id, s.reminder_webhook_url, s.reminder_message,
            s.reminder_days_threshold, t.name as company_name
        from public.tenant_settings s
        join public.tenants t on t.id = s.tenant_id
        where s.reminder_enabled
        and s.reminder_webhook_url is not null
        and s.reminder_webhook_url <> ''
    loop
        v_cutoff := current_date - r.reminder_days_threshold;

        for c in
            select cu.id as customer_id, cu.name as customer_name, cu.phone,
                sum(i.remaining) as amount
            from public.invoices i
            join public.customers cu on cu.id = i.party_id and cu.tenant_id = i.tenant_id
            where i.tenant_id = r.tenant_id
            and i.type = 'sale'
            and i.ownership = 'owned'
            and i.remaining > 0
            and i.date <= v_cutoff
            and cu.phone is not null and cu.phone <> ''
            group by cu.id, cu.name, cu.phone
            having not exists (
                select 1 from public.reminder_log lg
                where lg.tenant_id = i.tenant_id
                and lg.customer_id = cu.id
                and lg.created_at::date = current_date
            )
        loop
            v_log_id := public._fire_reminder(
                r.tenant_id, c.customer_id, c.customer_name, c.phone,
                c.amount, r.reminder_webhook_url, r.reminder_message, r.company_name
            );
            v_sent := v_sent + 1;
        end loop;
    end loop;

    return v_sent;
end;
$$;

revoke all on function public.send_due_reminders() from public;

-- ---------------------------------------------------------------------------
-- send_reminder_now (app "remind now" button)
-- ---------------------------------------------------------------------------
create or replace function public.send_reminder_now(p_customer_id uuid)
returns jsonb
language plpgsql
security invoker
set search_path = public, net
as $$
declare
    v_tenant   uuid := public.get_my_tenant_id();
    v_cust     record;
    v_set      record;
    v_company  text;
    v_amount   bigint;
    v_log_id   uuid;
begin
    if v_tenant is null then
        raise exception 'يجب تسجيل الدخول أولاً';
    end if;

    select * into v_cust
    from public.customers cu
    where cu.id = p_customer_id and cu.tenant_id = v_tenant;

    if v_cust.id is null then
        raise exception 'العميل غير موجود';
    end if;

    if v_cust.phone is null or v_cust.phone = '' then
        raise exception 'لا يوجد رقم هاتف لهذا العميل';
    end if;

    select coalesce(sum(remaining), 0) into v_amount
    from public.invoices i
    where i.tenant_id = v_tenant
    and i.party_id = p_customer_id
    and i.type = 'sale'
    and i.ownership = 'owned'
    and i.remaining > 0;

    if v_amount <= 0 then
        raise exception 'لا توجد مستحقات لهذا العميل';
    end if;

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

    v_log_id := public._fire_reminder(
        v_tenant, v_cust.id, v_cust.name, v_cust.phone,
        v_amount, v_set.reminder_webhook_url, v_set.reminder_message, v_company
    );

    return to_jsonb(lg)
    from public.reminder_log lg
    where lg.id = v_log_id and lg.tenant_id = v_tenant;
end;
$$;

revoke all on function public.send_reminder_now(uuid) from public;
grant execute on function public.send_reminder_now(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- send_reminders_to_all (app "remind all")
-- ---------------------------------------------------------------------------
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

-- ---------------------------------------------------------------------------
-- Re-schedule the daily cron (idempotent)
-- ---------------------------------------------------------------------------
select cron.unschedule(jobid)
from cron.job
where jobname = 'send-due-reminders-daily';

select cron.schedule('send-due-reminders-daily', '0 9 * * *', 'select public.send_due_reminders();');

commit;