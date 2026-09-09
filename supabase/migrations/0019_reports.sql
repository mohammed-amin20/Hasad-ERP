-- 0019_reports.sql
-- M7 "Reports & Dashboard" backend: the read/write RPC surface behind the
-- dashboard, chart of accounts, journal, general ledger, trial balance, and
-- the financial statements screens.
--
-- All functions are SECURITY INVOKER and never bypass RLS: they read only the
-- caller's tenant via get_my_tenant_id() and (for writes) rely on existing
-- INSERT policies/grants. The accounts table was SELECT-only since 0004, so
-- this migration adds an INSERT policy + grant for manual account creation.
-- journal_entries gains a request_id column + partial unique index so manual
-- entries are idempotent, mirroring how the invoice RPCs guard themselves.
--
-- Money stays BIGINT agorot, jsonb envelopes mirror get_party_statement (0015).

begin;

-- ---------------------------------------------------------------------------
-- accounts: INSERT support (manual chart-of-accounts growth). 0017's
-- set_master_tenant trigger covers customers/suppliers/products/expenses but
-- NOT accounts, so create_account writes tenant_id explicitly.
-- ---------------------------------------------------------------------------
create policy tenant_isolation_insert on public.accounts
    for insert
    with check (tenant_id = public.get_my_tenant_id());

grant insert on public.accounts to authenticated;

-- journal idempotency for manual entries (mirrors idx_invoices_request_id).
alter table public.journal_entries add column if not exists request_id uuid;
create unique index if not exists idx_journal_entries_request_id
    on public.journal_entries (request_id)
    where request_id is not null;

-- ===========================================================================
-- get_dashboard_summary()
-- One envelope for all 7 stat cards + chart + the two side panels.
--   {
--     today_sales, today_purchases, customer_debts, supplier_debts,
--     month_expenses, month_salaries, net_profit_month,
--     last_7_days: [{date, sales, purchases}],
--     top_debtors: [{customer_id, name, balance}],
--     low_stock:   [{product_id, name, qty, reorder_level}]
--   }
-- "today's purchases" counts owned purchases only (consignment receipts post
-- stock without debt, so they contribute nothing to supplier balances/net).
-- ===========================================================================
create or replace function public.get_dashboard_summary()
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
    v_tenant     uuid := public.get_my_tenant_id();
    v_today_sales    bigint := 0;
    v_today_purch    bigint := 0;
    v_cust_debts     bigint := 0;
    v_supp_debts     bigint := 0;
    v_expenses       bigint := 0;
    v_salaries       bigint := 0;
    v_net            bigint := 0;
    v_last7          jsonb;
    v_top_debtors    jsonb;
    v_low_stock      jsonb;
    v_month_start    date := date_trunc('month', current_date)::date;
begin
    if v_tenant is null then
        raise exception 'يجب تسجيل الدخول أولاً';
    end if;

    -- Today's sales / owned purchases (invoice totals, agorot).
    select coalesce(sum(i.total), 0) into v_today_sales
    from public.invoices i
    where i.tenant_id = v_tenant
      and i.type = 'sale'
      and i.date = current_date;

    select coalesce(sum(i.total), 0) into v_today_purch
    from public.invoices i
    where i.tenant_id = v_tenant
      and i.type = 'purchase'
      and i.ownership = 'owned'
      and i.date = current_date;

    -- Outstanding debts mirror the get_party_statement balance logic:
    --   customer = sum(remaining) on sale invoices
    --   supplier = sum(remaining) on owned purchases + commission dues
    select coalesce(sum(i.remaining), 0) into v_cust_debts
    from public.invoices i
    where i.tenant_id = v_tenant
      and i.type = 'sale'
      and i.remaining > 0;

    select coalesce(sum(i.remaining), 0) +
           coalesce((select sum(d.remaining) from public.commission_dues d
                     where d.tenant_id = v_tenant and d.remaining > 0), 0)
      into v_supp_debts
    from public.invoices i
    where i.tenant_id = v_tenant
      and i.type = 'purchase'
      and i.ownership = 'owned'
      and i.remaining > 0;

    -- Month figures: direct expenses table + salaries actually paid.
    select coalesce(sum(e.amount), 0) into v_expenses
    from public.expenses e
    where e.tenant_id = v_tenant
      and e.date >= v_month_start;

    select coalesce(sum(s.paid), 0) into v_salaries
    from public.salaries s
    where s.tenant_id = v_tenant
      and s.date >= v_month_start;

    -- Net profit for the month straight from the ledger: revenue credits
    -- minus expense debits, so manual entries to P&L accounts count too.
    select coalesce(sum(case
            when a.type = 'revenue'  then l.credit - l.debit
            when a.type = 'expense'  then (l.credit - l.debit)
            else 0
         end), 0) into v_net
    from public.journal_entries je
    join public.journal_entry_lines l on l.entry_id = je.id
    join public.accounts a             on a.id = l.account_id and a.tenant_id = v_tenant
    where je.tenant_id = v_tenant
      and je.date >= v_month_start;

    -- Last 7 days, zero-filled so the chart always has 7 points.
    with days as (
        select generate_series(current_date - 6, current_date, '1 day')::date as dt
    ),
    sales as (
        select i.date, sum(i.total) total
        from public.invoices i
        where i.tenant_id = v_tenant and i.type = 'sale'
          and i.date between (current_date - 6) and current_date
        group by i.date
    ),
    purchases as (
        select i.date, sum(i.total) total
        from public.invoices i
        where i.tenant_id = v_tenant and i.type = 'purchase' and i.ownership = 'owned'
          and i.date between (current_date - 6) and current_date
        group by i.date
    )
    select coalesce(jsonb_agg(
        jsonb_build_object(
            'date',      to_char(d.dt, 'YYYY-MM-DD'),
            'sales',     coalesce(s.total, 0),
            'purchases', coalesce(p.total, 0)
        )
        order by d.dt
    ), '[]'::jsonb)
      into v_last7
    from days d
    left join sales s     on s.date = d.dt
    left join purchases p on p.date = d.dt;

    -- Top 5 debtors (customers with outstanding sale balances).
    select coalesce(jsonb_agg(
        jsonb_build_object(
            'customer_id', x.party_id,
            'name',        c.name,
            'balance',     x.balance
        )
        order by x.balance desc
    ), '[]'::jsonb)
      into v_top_debtors
    from (
        select i.party_id, sum(i.remaining) as balance
        from public.invoices i
        where i.tenant_id = v_tenant
          and i.type = 'sale'
          and i.remaining > 0
        group by i.party_id
        order by balance desc
        limit 5
    ) x
    join public.customers c on c.id = x.party_id and c.tenant_id = v_tenant;

    -- Low-stock alerts: qty at or below reorder level.
    select coalesce(jsonb_agg(
        jsonb_build_object(
            'product_id',    pr.id,
            'name',          pr.name,
            'qty',           pr.qty,
            'reorder_level', pr.reorder_level
        )
        order by (pr.qty / nullif(pr.reorder_level, 0)) asc nulls last
    ), '[]'::jsonb)
      into v_low_stock
    from public.products pr
    where pr.tenant_id = v_tenant
      and pr.reorder_level > 0
      and pr.qty <= pr.reorder_level;

    return jsonb_build_object(
        'today_sales',     v_today_sales,
        'today_purchases', v_today_purch,
        'customer_debts',  v_cust_debts,
        'supplier_debts',  v_supp_debts,
        'month_expenses',  v_expenses,
        'month_salaries',  v_salaries,
        'net_profit_month', v_net,
        'last_7_days',     v_last7,
        'top_debtors',     v_top_debtors,
        'low_stock',       v_low_stock
    );
end;
$$;

revoke all on function public.get_dashboard_summary() from public;
grant execute on function public.get_dashboard_summary() to authenticated;

-- ===========================================================================
-- get_chart_of_accounts()
-- All accounts of the caller's tenant with their net-to-date ledger balance
-- (debit - credit, agorot). Ordered by code.
--   [{account_id, code, name, type, parent_id, parent_code, balance}]
-- ===========================================================================
create or replace function public.get_chart_of_accounts()
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
    v_tenant uuid := public.get_my_tenant_id();
    v_rows   jsonb;
begin
    if v_tenant is null then
        raise exception 'يجب تسجيل الدخول أولاً';
    end if;

    select coalesce(jsonb_agg(
        jsonb_build_object(
            'account_id',  a.id,
            'code',        a.code,
            'name',        a.name,
            'type',        a.type,
            'parent_id',   a.parent_id,
            'parent_code', (select p.code from public.accounts p where p.id = a.parent_id),
            'balance',     coalesce((
                select sum(l.debit - l.credit)
                from public.journal_entries je
                join public.journal_entry_lines l on l.entry_id = je.id
                where l.account_id = a.id and je.tenant_id = v_tenant
            ), 0)
        )
        order by a.code
    ), '[]'::jsonb)
      into v_rows
    from public.accounts a
    where a.tenant_id = v_tenant;

    return v_rows;
end;
$$;

revoke all on function public.get_chart_of_accounts() from public;
grant execute on function public.get_chart_of_accounts() to authenticated;

-- ===========================================================================
-- create_account(p_code, p_name, p_type, p_parent_code)
-- Manual chart-of-accounts growth. Codes are 4-digit text unique per tenant.
-- p_parent_code is optional; when given it must resolve within the tenant.
--   {account_id, code, name, type, parent_id} | {duplicate: true}
-- ===========================================================================
create or replace function public.create_account(
    p_code        text,
    p_name        text,
    p_type        text,
    p_parent_code text default null
) returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
    v_tenant   uuid := public.get_my_tenant_id();
    v_exists   boolean;
    v_parent   uuid;
    v_account  uuid;
begin
    if v_tenant is null then
        raise exception 'يجب تسجيل الدخول أولاً';
    end if;

    if p_code is null or p_code = '' then
        raise exception 'كود الحساب مطلوب';
    end if;

    if p_name is null or p_name = '' then
        raise exception 'اسم الحساب مطلوب';
    end if;

    if p_type not in ('asset', 'liability', 'equity', 'revenue', 'expense') then
        raise exception 'نوع الحساب غير صالح';
    end if;

    select exists(
        select 1 from public.accounts a
        where a.tenant_id = v_tenant and a.code = p_code
    ) into v_exists;

    if v_exists then
        return jsonb_build_object('duplicate', true, 'code', p_code);
    end if;

    if p_parent_code is not null then
        select a.id into v_parent
        from public.accounts a
        where a.tenant_id = v_tenant and a.code = p_parent_code;

        if v_parent is null then
            raise exception 'الحساب الأب غير موجود';
        end if;
    end if;

    insert into public.accounts (tenant_id, code, name, type, parent_id)
    values (v_tenant, p_code, p_name, p_type, v_parent)
    returning id into v_account;

    return jsonb_build_object(
        'account_id', v_account,
        'code',       p_code,
        'name',       p_name,
        'type',       p_type,
        'parent_id',  v_parent
    );
end;
$$;

revoke all on function public.create_account(text, text, text, text) from public;
grant execute on function public.create_account(text, text, text, text) to authenticated;

-- ===========================================================================
-- create_journal_entry(p_request_id, p_date, p_memo, p_lines)
-- Manual (source_type='manual') balanced journal entry. p_lines is a jsonb
-- array of {"account_id": uuid, "debit": bigint, "credit": bigint}. One side
-- must be zero, both never > 0, Σ debit = Σ credit, >= 2 lines.
-- Idempotent via request_id (like the invoice RPCs).
--   {entry_id, entry_no, total, lines_count} | {duplicate: true, entry: {...}}
-- ===========================================================================
create or replace function public.create_journal_entry(
    p_request_id uuid,
    p_date       date,
    p_memo       text,
    p_lines      jsonb
) returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
    v_tenant   uuid := public.get_my_tenant_id();
    v_entry    uuid;
    v_no       bigint;
    v_creator  uuid;
    v_line     jsonb;
    v_acc      uuid;
    v_debit    bigint;
    v_credit   bigint;
    v_total    bigint := 0;
    v_sum_dr   bigint := 0;
    v_sum_cr   bigint := 0;
    v_count    int    := 0;
begin
    if v_tenant is null then
        raise exception 'يجب تسجيل الدخول أولاً';
    end if;

    if p_request_id is null then
        raise exception 'معرّف الطلب مطلوب';
    end if;

    select id into v_entry
    from public.journal_entries je
    where je.tenant_id = v_tenant and je.request_id = p_request_id;

    if v_entry is not null then
        return jsonb_build_object(
            'duplicate', true,
            'entry', jsonb_build_object('entry_id', v_entry, 'entry_no',
                (select entry_no from public.journal_entries where id = v_entry))
        );
    end if;

    if p_lines is null or jsonb_array_length(p_lines) < 2 then
        raise exception 'يجب إدخال قيدين على الأقل';
    end if;

    -- Validate each line and total the debits/credits first.
    for v_line in select * from jsonb_array_elements(p_lines) loop
        v_acc    := (v_line ->> 'account_id')::uuid;
        v_debit  := coalesce((v_line ->> 'debit')::bigint, 0);
        v_credit := coalesce((v_line ->> 'credit')::bigint, 0);

        if v_acc is null then
            raise exception 'حساب غير محدد في القيد';
        end if;

        if not exists (
            select 1 from public.accounts a
            where a.id = v_acc and a.tenant_id = v_tenant
        ) then
            raise exception 'الحساب غير موجود في دليل حساباتك';
        end if;

        if v_debit < 0 or v_credit < 0 then
            raise exception 'المبالغ لا يمكن أن تكون سالبة';
        end if;

        if v_debit = 0 and v_credit = 0 then
            raise exception 'كل سطر يجب أن يحوي مديناً أو دائناً';
        end if;

        if v_debit > 0 and v_credit > 0 then
            raise exception 'السطر لا يمكن أن يكون مديناً ودائناً معاً';
        end if;

        v_sum_dr := v_sum_dr + v_debit;
        v_sum_cr := v_sum_cr + v_credit;
        v_total  := v_total + v_debit + v_credit;
        v_count  := v_count + 1;
    end loop;

    if v_sum_dr = 0 or v_sum_cr = 0 then
        raise exception 'القيد غير متوازن';
    end if;

    if v_sum_dr <> v_sum_cr then
        raise exception 'القيد غير متوازن: المدين % يختلف عن الدائن %', v_sum_dr, v_sum_cr;
    end if;

    v_no := public.next_journal_no();

    select u.id into v_creator from public.users u where u.auth_user_id = auth.uid();

    insert into public.journal_entries
        (tenant_id, entry_no, date, memo, source_type, request_id, created_by)
    values
        (v_tenant, v_no, coalesce(p_date, current_date), p_memo, 'manual', p_request_id, v_creator)
    returning id into v_entry;

    for v_line in select * from jsonb_array_elements(p_lines) loop
        v_acc    := (v_line ->> 'account_id')::uuid;
        v_debit  := coalesce((v_line ->> 'debit')::bigint, 0);
        v_credit := coalesce((v_line ->> 'credit')::bigint, 0);

        insert into public.journal_entry_lines (entry_id, account_id, debit, credit)
        values (v_entry, v_acc, v_debit, v_credit);
    end loop;

    return jsonb_build_object(
        'entry_id',    v_entry,
        'entry_no',    v_no,
        'total',       v_sum_dr,
        'lines_count', v_count
    );
end;
$$;

revoke all on function public.create_journal_entry(uuid, date, text, jsonb) from public;
grant execute on function public.create_journal_entry(uuid, date, text, jsonb) to authenticated;

-- ===========================================================================
-- get_journal_entries(p_from, p_to)
-- Journal listing for the Journal screen, newest first. Each entry carries a
-- total and its lines joined to account code/name.
--   [{entry_id, entry_no, date, memo, source_type, total,
--     lines: [{account_code, account_name, debit, credit}]}]
-- ===========================================================================
create or replace function public.get_journal_entries(
    p_from date,
    p_to   date
) returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
    v_tenant uuid := public.get_my_tenant_id();
    v_rows   jsonb;
begin
    if v_tenant is null then
        raise exception 'يجب تسجيل الدخول أولاً';
    end if;

    if p_from is null or p_to is null then
        raise exception 'يجب تحديد تاريخ البداية والنهاية';
    end if;

    if p_from > p_to then
        raise exception 'تاريخ البداية بعد تاريخ النهاية';
    end if;

    select coalesce(jsonb_agg(
        jsonb_build_object(
            'entry_id',    je.id,
            'entry_no',    je.entry_no,
            'date',        to_char(je.date, 'YYYY-MM-DD'),
            'memo',        je.memo,
            'source_type', je.source_type,
            'total',       coalesce((
                select sum(case when l.debit > 0 then l.debit else l.credit end)
                from public.journal_entry_lines l
                where l.entry_id = je.id
            ), 0),
            'lines',       coalesce((
                select jsonb_agg(
                    jsonb_build_object(
                        'account_code', a.code,
                        'account_name', a.name,
                        'account_type', a.type,
                        'debit',        l.debit,
                        'credit',       l.credit
                    )
                    order by (l.debit > 0) desc
                )
                from public.journal_entry_lines l
                join public.accounts a on a.id = l.account_id
                where l.entry_id = je.id
            ), '[]'::jsonb)
        )
        order by je.entry_no desc
    ), '[]'::jsonb)
      into v_rows
    from public.journal_entries je
    where je.tenant_id = v_tenant
      and je.date between p_from and p_to;

    return v_rows;
end;
$$;

revoke all on function public.get_journal_entries(date, date) from public;
grant execute on function public.get_journal_entries(date, date) to authenticated;

-- ===========================================================================
-- get_ledger(p_account_id, p_from, p_to)
-- General ledger for one account, both dates inclusive. Opening balance is the
-- net (debit - credit) before p_from; each line carries a running balance via
-- a window over (date, entry_no). Order is by date then entry_no ascending.
--   {account_id, code, name, type, from, to, opening,
--    lines: [{date, entry_no, memo, debit, credit, balance}], closing}
-- ===========================================================================
create or replace function public.get_ledger(
    p_account_id uuid,
    p_from       date,
    p_to         date
) returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
    v_tenant  uuid := public.get_my_tenant_id();
    v_acc     record;
    v_opening bigint := 0;
    v_rows    jsonb;
    v_closing bigint;
begin
    if v_tenant is null then
        raise exception 'يجب تسجيل الدخول أولاً';
    end if;

    if p_account_id is null then
        raise exception 'يجب تحديد الحساب';
    end if;

    select a.id, a.code, a.name, a.type into v_acc
    from public.accounts a
    where a.id = p_account_id and a.tenant_id = v_tenant;

    if v_acc.id is null then
        raise exception 'الحساب غير موجود';
    end if;

    if p_from is null or p_to is null then
        raise exception 'يجب تحديد تاريخ البداية والنهاية';
    end if;

    if p_from > p_to then
        raise exception 'تاريخ البداية بعد تاريخ النهاية';
    end if;

    -- Opening = signed net (debit - credit) on this account before p_from.
    select coalesce(sum(l.debit - l.credit), 0) into v_opening
    from public.journal_entries je
    join public.journal_entry_lines l on l.entry_id = je.id
    where je.tenant_id = v_tenant
      and l.account_id = p_account_id
      and je.date < p_from;

    -- Movements + running balance (opening seeded outside the window).
    with lines as (
        select
            je.date         as dt,
            je.entry_no     as entry_no,
            je.memo         as memo,
            l.debit         as debit,
            l.credit        as credit
        from public.journal_entries je
        join public.journal_entry_lines l on l.entry_id = je.id
        where je.tenant_id = v_tenant
          and l.account_id = p_account_id
          and je.date between p_from and p_to
    ),
    running as (
        select
            dt, entry_no, memo, debit, credit,
            v_opening + sum(debit - credit) over (
                order by dt asc, entry_no asc
                rows between unbounded preceding and current row
            ) as balance
        from lines
    )
    select coalesce(jsonb_agg(
        jsonb_build_object(
            'date',     to_char(dt, 'YYYY-MM-DD'),
            'entry_no', entry_no,
            'memo',     memo,
            'debit',    debit,
            'credit',   credit,
            'balance',  balance
        )
        order by dt asc, entry_no asc
    ), '[]'::jsonb)
      into v_rows
    from running;

    select v_opening + coalesce(sum(debit - credit), 0) into v_closing
    from (
        select sum(l.debit) debit, sum(l.credit) credit
        from public.journal_entries je
        join public.journal_entry_lines l on l.entry_id = je.id
        where je.tenant_id = v_tenant
          and l.account_id = p_account_id
          and je.date between p_from and p_to
    ) t;

    return jsonb_build_object(
        'account_id', v_acc.id,
        'code',       v_acc.code,
        'name',       v_acc.name,
        'type',       v_acc.type,
        'from',       to_char(p_from, 'YYYY-MM-DD'),
        'to',         to_char(p_to, 'YYYY-MM-DD'),
        'opening',    v_opening,
        'lines',      v_rows,
        'closing',    v_closing
    );
end;
$$;

revoke all on function public.get_ledger(uuid, date, date) from public;
grant execute on function public.get_ledger(uuid, date, date) to authenticated;

-- ===========================================================================
-- get_trial_balance(p_as_of_date)
-- Per-account debit/credit totals up to (and including) p_as_of_date, plus a
-- totals row proving Σ debit = Σ credit. Exit criterion for M7.
--   {as_of, accounts: [{account_id, code, name, type, debit, credit, balance}],
--    totals: {debit, credit}}
-- ===========================================================================
create or replace function public.get_trial_balance(
    p_as_of_date date
) returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
    v_tenant uuid := public.get_my_tenant_id();
    v_rows   jsonb;
    v_dr     bigint := 0;
    v_cr     bigint := 0;
begin
    if v_tenant is null then
        raise exception 'يجب تسجيل الدخول أولاً';
    end if;

    select
        coalesce(jsonb_agg(
            jsonb_build_object(
                'account_id', a.id,
                'code',       a.code,
                'name',       a.name,
                'type',       a.type,
                'debit',      coalesce(x.debit, 0),
                'credit',     coalesce(x.credit, 0),
                'balance',    coalesce(x.debit, 0) - coalesce(x.credit, 0)
            )
            order by a.code
        ), '[]'::jsonb),
        coalesce(sum(x.debit), 0),
        coalesce(sum(x.credit), 0)
      into v_rows, v_dr, v_cr
    from public.accounts a
    left join (
        select l.account_id,
               sum(l.debit)  debit,
               sum(l.credit) credit
        from public.journal_entries je
        join public.journal_entry_lines l on l.entry_id = je.id
        where je.tenant_id = v_tenant
          and je.date <= p_as_of_date
        group by l.account_id
    ) x on x.account_id = a.id
    where a.tenant_id = v_tenant;

    return jsonb_build_object(
        'as_of',   to_char(p_as_of_date, 'YYYY-MM-DD'),
        'accounts', v_rows,
        'totals',  jsonb_build_object('debit', v_dr, 'credit', v_cr)
    );
end;
$$;

revoke all on function public.get_trial_balance(date) from public;
grant execute on function public.get_trial_balance(date) to authenticated;

-- ===========================================================================
-- get_income_statement(p_from, p_to)
-- Revenues and expenses from the ledger between the two dates (inclusive).
-- Net = Σ(revenue credit - debit) - Σ(expense debit - credit).
--   {from, to, revenues: [{account_id, code, name, amount}],
--    expenses: [...], revenue_total, expense_total, net}
-- ===========================================================================
create or replace function public.get_income_statement(
    p_from date,
    p_to   date
) returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
    v_tenant        uuid := public.get_my_tenant_id();
    v_revenues      jsonb;
    v_expenses      jsonb;
    v_rev_total     bigint := 0;
    v_exp_total     bigint := 0;
    v_net           bigint := 0;
begin
    if v_tenant is null then
        raise exception 'يجب تسجيل الدخول أولاً';
    end if;

    if p_from is null or p_to is null then
        raise exception 'يجب تحديد تاريخ البداية والنهاية';
    end if;

    if p_from > p_to then
        raise exception 'تاريخ البداية بعد تاريخ النهاية';
    end if;

    with aggregates as (
        select l.account_id,
               sum(l.debit)  debit,
               sum(l.credit) credit
        from public.journal_entries je
        join public.journal_entry_lines l on l.entry_id = je.id
        where je.tenant_id = v_tenant
          and je.date between p_from and p_to
        group by l.account_id
    )
    select
        coalesce(jsonb_agg(
            jsonb_build_object(
                'account_id', a.id,
                'code',       a.code,
                'name',       a.name,
                'amount',     x.credit - x.debit
            )
            order by a.code
        ) filter (where a.type = 'revenue'), '[]'::jsonb),
        coalesce(jsonb_agg(
            jsonb_build_object(
                'account_id', a.id,
                'code',       a.code,
                'name',       a.name,
                'amount',     x.debit - x.credit
            )
            order by a.code
        ) filter (where a.type = 'expense'), '[]'::jsonb),
        coalesce(sum(x.credit - x.debit) filter (where a.type = 'revenue'), 0),
        coalesce(sum(x.debit - x.credit) filter (where a.type = 'expense'), 0)
      into v_revenues, v_expenses, v_rev_total, v_exp_total
    from public.accounts a
    join aggregates x on x.account_id = a.id
    where a.tenant_id = v_tenant;

    v_net := v_rev_total - v_exp_total;

    return jsonb_build_object(
        'from',          to_char(p_from, 'YYYY-MM-DD'),
        'to',            to_char(p_to, 'YYYY-MM-DD'),
        'revenues',      v_revenues,
        'expenses',      v_expenses,
        'revenue_total', v_rev_total,
        'expense_total', v_exp_total,
        'net',           v_net
    );
end;
$$;

revoke all on function public.get_income_statement(date, date) from public;
grant execute on function public.get_income_statement(date, date) to authenticated;

-- ===========================================================================
-- get_balance_sheet(p_as_of_date)
-- Assets / liabilities / equity as of a date. Because P&L is not formally
-- closed into retained earnings, "period net income" is shown as its own
-- equity line so the sheet always balances: assets = liabilities + equity.
--   {as_of, assets: [{account_id, code, name, amount}], liabilities: [...],
--    equity: [{...}], assets_total, liabilities_total, equity_total,
--    net_income_ytd, check: amount}
--   check = assets_total - liabilities_total - equity_total  (should be 0)
-- ===========================================================================
create or replace function public.get_balance_sheet(
    p_as_of_date date
) returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
    v_tenant      uuid := public.get_my_tenant_id();
    v_assets      jsonb;
    v_liabilities jsonb;
    v_equity      jsonb;
    v_assets_t    bigint := 0;
    v_liab_t      bigint := 0;
    v_equity_t    bigint := 0;
    v_net_ytd     bigint := 0;
    v_check       bigint := 0;
begin
    if v_tenant is null then
        raise exception 'يجب تسجيل الدخول أولاً';
    end if;

    -- Net income from the start of time up to p_as_of_date.
    select coalesce(sum(case
            when a.type = 'revenue' then l.credit - l.debit
            when a.type = 'expense' then (l.credit - l.debit)
            else 0
         end), 0) into v_net_ytd
    from public.journal_entries je
    join public.journal_entry_lines l on l.entry_id = je.id
    join public.accounts a             on a.id = l.account_id and a.tenant_id = v_tenant
    where je.tenant_id = v_tenant
      and je.date <= p_as_of_date;

    with aggregates as (
        select l.account_id,
               sum(l.debit)  debit,
               sum(l.credit) credit
        from public.journal_entries je
        join public.journal_entry_lines l on l.entry_id = je.id
        where je.tenant_id = v_tenant
          and je.date <= p_as_of_date
        group by l.account_id
    )
    select
        coalesce(jsonb_agg(
            jsonb_build_object(
                'account_id', a.id,
                'code',       a.code,
                'name',       a.name,
                'amount',     coalesce(x.debit, 0) - coalesce(x.credit, 0)
            )
            order by a.code
        ) filter (where a.type = 'asset'), '[]'::jsonb),
        coalesce(jsonb_agg(
            jsonb_build_object(
                'account_id', a.id,
                'code',       a.code,
                'name',       a.name,
                'amount',     coalesce(x.credit, 0) - coalesce(x.debit, 0)
            )
            order by a.code
        ) filter (where a.type = 'liability'), '[]'::jsonb),
        coalesce(jsonb_agg(
            jsonb_build_object(
                'account_id', a.id,
                'code',       a.code,
                'name',       a.name,
                'amount',     coalesce(x.credit, 0) - coalesce(x.debit, 0)
            )
            order by a.code
        ) filter (where a.type = 'equity'), '[]'::jsonb),
        coalesce(sum(coalesce(x.debit, 0) - coalesce(x.credit, 0)) filter (where a.type = 'asset'), 0),
        coalesce(sum(coalesce(x.credit, 0) - coalesce(x.debit, 0)) filter (where a.type = 'liability'), 0),
        coalesce(sum(coalesce(x.credit, 0) - coalesce(x.debit, 0)) filter (where a.type = 'equity'), 0)
      into v_assets, v_liabilities, v_equity, v_assets_t, v_liab_t, v_equity_t
    from public.accounts a
    left join aggregates x on x.account_id = a.id
    where a.tenant_id = v_tenant
      and a.type in ('asset', 'liability', 'equity');

    -- Add period net income as an equity line so the equation holds.
    v_equity_t := v_equity_t + v_net_ytd;
    v_check    := v_assets_t - v_liab_t - v_equity_t;

    return jsonb_build_object(
        'as_of',             to_char(p_as_of_date, 'YYYY-MM-DD'),
        'assets',            v_assets,
        'liabilities',       v_liabilities,
        'equity',            v_equity,
        'assets_total',      v_assets_t,
        'liabilities_total', v_liab_t,
        'equity_total',      v_equity_t,
        'net_income_ytd',    v_net_ytd,
        'check',             v_check
    );
end;
$$;

revoke all on function public.get_balance_sheet(date) from public;
grant execute on function public.get_balance_sheet(date) to authenticated;

commit;