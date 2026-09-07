        -- 0013_reminder.sql — customer payment reminder automation (PROJECT_SPEC §10).
        --   * tenant_settings   : per-tenant webhook URL + message template + threshold.
        --   * reminder_log      : display-only log of sent messages (UI reads, never sends).
        --   * send_due_reminders: pg_cron daily job; SECURITY DEFINER, NOT exposed to
        --                         authenticated callers (internal only).
        --   * send_reminder_now : tenant-scoped "remind now" button for one customer.
        --   * Seeding: AFTER INSERT trigger on tenants creates default settings so new
        --     tenants are covered without touching the already-applied register_tenant.
        --
        -- Sending model: Postgres posts to the tenant's n8n webhook via pg_net; n8n
        -- delivers the SMS. A reminder_log row with status 'sent' means "queued to the
        -- webhook" — delivery is out of the database's hands by design.

        begin;

        -- ---------------------------------------------------------------------
        -- tenant_settings
        -- ---------------------------------------------------------------------
        create table public.tenant_settings (
            tenant_id              uuid primary key references public.tenants(id) on delete cascade,
            reminder_webhook_url   text,
            reminder_message       text not null default '{customer_name}، يرجى سداد مبلغ {amount} شيكل لمؤسسة {company_name}. للاستفسار: {phone}',
            reminder_days_threshold int not null default 3 check (reminder_days_threshold >= 0),
            reminder_enabled       boolean not null default true,
            reminder_last_run      date,
            updated_at             timestamptz not null default now()
        );

        alter table public.tenant_settings enable row level security;
        create policy tenant_isolation on public.tenant_settings
            for all
            using (tenant_id = public.get_my_tenant_id())
            with check (tenant_id = public.get_my_tenant_id());

        grant select, insert, update on public.tenant_settings to authenticated;
        revoke all on public.tenant_settings from anon;

        -- Seed defaults whenever a new tenant appears.
        create or replace function public.seed_tenant_settings()
        returns trigger
        language plpgsql
        security definer
        set search_path = public
        as $$
        begin
            insert into public.tenant_settings (tenant_id)
            values (new.id)
            on conflict (tenant_id) do nothing;
            return new;
        end;
        $$;

        create trigger trg_seed_tenant_settings
            after insert on public.tenants
            for each row
            execute function public.seed_tenant_settings();

        -- ---------------------------------------------------------------------
        -- reminder_log (UI display only)
        -- ---------------------------------------------------------------------
        create table public.reminder_log (
            id          uuid primary key default gen_random_uuid(),
            tenant_id   uuid not null references public.tenants(id) on delete cascade,
            customer_id uuid references public.customers(id) on delete set null,
            amount      bigint,
            phone       text,
            message     text,
            status      text not null default 'sent' check (status in ('queued', 'sent', 'failed')),
            error       text,
            created_at  timestamptz not null default now()
        );

        alter table public.reminder_log enable row level security;
        create policy tenant_isolation_select on public.reminder_log
            for select
            using (tenant_id = public.get_my_tenant_id());

        grant select on public.reminder_log to authenticated;
        revoke all on public.reminder_log from anon;

        -- ---------------------------------------------------------------------
        -- Internal fire-and-log helper (owner/cron only).
        -- ---------------------------------------------------------------------
        create or replace function public._fire_reminder(
            p_tenant_id    uuid,
            p_customer_id  uuid,
            p_customer_name text,
            p_phone        text,
            p_amount       bigint,
            p_webhook      text,
            p_template     text,
            p_company_name text
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
            values (p_tenant_id, p_customer_id, p_amount, p_phone, v_msg, 'sent')
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

        -- ---------------------------------------------------------------------
        -- Daily scheduled job (cron). Not exposed to the app.
        -- ---------------------------------------------------------------------
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
        revoke all on function public._fire_reminder(uuid, uuid, text, text, bigint, text, text, text) from public;

        -- ---------------------------------------------------------------------
        -- On-demand single reminder (the app's "remind now" button).
        -- ---------------------------------------------------------------------
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

    -- ---------------------------------------------------------------------
    -- Schedule the daily job (idempotent). cron.job is extension-owned, so
    -- remove any existing job via cron.unschedule (a function) — never
    -- `delete from cron.job` (42501 from the editor).
    -- ---------------------------------------------------------------------
    select cron.unschedule(jobid)
    from cron.job
    where jobname = 'send-due-reminders-daily';

    select cron.schedule('send-due-reminders-daily', '0 9 * * *', 'select public.send_due_reminders();');

        commit;