    -- 0010_rpc_employees.sql
    -- Employee deduction/entitlement system (PROJECT_SPEC §8).
    --   Net Due = Base + Prior-month Arrears + Entitlements(in) - Deductions(out)
    --   Arrears = max(base - paid, 0) summed over PREVIOUS months (from `salaries`).
    --   "product" deductions move inventory (qty x cost) out, linked to the employee.
    --
    -- Design notes:
    --   * Movements do NOT journal at write time; wage expense is recognized once
    --     at pay_salary, keeping the ledger on the seeded chart of accounts.
    --   * pay_salary clears prior arrears via account 2030 and books the month's
    --     expense on 5030, so every entry balances by construction.
    --   * One salaries row per employee-month; paying twice in a month is rejected.
    --   * Overpayment beyond net_due is rejected (money never overpaid).

    begin;

    -- ---------------------------------------------------------------------
    -- Schema: idempotency support
    -- ---------------------------------------------------------------------
    alter table public.employee_movements add column if not exists request_id uuid;
    create unique index if not exists idx_employee_movements_request_id
        on public.employee_movements (request_id)
        where request_id is not null;

    alter table public.salaries add column if not exists request_id uuid;
    create unique index if not exists idx_salaries_request_id
        on public.salaries (request_id)
        where request_id is not null;

    -- ---------------------------------------------------------------------
    -- RLS: INSERT policies + grants for the rows these RPCs write
    -- ---------------------------------------------------------------------
    create policy tenant_isolation_insert on public.employee_movements
        for insert
        with check (tenant_id = public.get_my_tenant_id());

    create policy tenant_isolation_insert on public.salaries
        for insert
        with check (tenant_id = public.get_my_tenant_id());

    grant insert on public.employee_movements to authenticated;
    grant insert on public.salaries          to authenticated;

    -- ---------------------------------------------------------------------
    -- get_employee_entitlement: pure computation, used by pay_salary and the UI
    -- ---------------------------------------------------------------------
    create or replace function public.get_employee_entitlement(p_employee_id uuid, p_month date)
    returns jsonb
    language plpgsql
    security invoker
    set search_path = public
    as $$
    declare
        v_tenant uuid := public.get_my_tenant_id();
        v_first  date := date_trunc('month', p_month)::date;
        v_emp    record;
        v_base   bigint := 0;
        v_arrears bigint := 0;
        v_ent    bigint := 0;
        v_ded    bigint := 0;
        v_net    bigint;
    begin
        if v_tenant is null then
            raise exception 'يجب تسجيل الدخول أولاً';
        end if;

        select * into v_emp
        from public.employees e
        where e.id = p_employee_id and e.tenant_id = v_tenant;

        if v_emp.id is null then
            raise exception 'الموظف غير موجود';
        end if;

        v_base := v_emp.base_salary;

        -- Prior-month arrears: only months strictly before p_month.
        select coalesce(sum(greatest(base_salary - paid, 0)), 0) into v_arrears
        from public.salaries s
        where s.tenant_id = v_tenant
        and s.employee_id = p_employee_id
        and s.month < v_first;

        select coalesce(sum(amount), 0) into v_ent
        from public.employee_movements m
        where m.tenant_id = v_tenant
        and m.employee_id = p_employee_id
        and m.month = v_first
        and m.direction = 'in';

        select coalesce(sum(amount), 0) into v_ded
        from public.employee_movements m
        where m.tenant_id = v_tenant
        and m.employee_id = p_employee_id
        and m.month = v_first
        and m.direction = 'out';

        v_net := v_base + v_arrears + v_ent - v_ded;

        return jsonb_build_object(
            'employee_id',  p_employee_id,
            'month',        v_first,
            'base_salary',  v_base,
            'arrears',      v_arrears,
            'entitlements', v_ent,
            'deductions',   v_ded,
            'net_due',      v_net
        );
    end;
    $$;

    -- ---------------------------------------------------------------------
    -- add_employee_movement: one deduction or entitlement for a month.
    -- ---------------------------------------------------------------------
    create or replace function public.add_employee_movement(
        p_request_id   uuid,
        p_employee_id  uuid,
        p_month        date,
        p_direction    text,
        p_category     text,
    p_amount       bigint default null,
    p_description  text default null,
        p_product_id   uuid default null,
        p_qty          numeric default null,
        p_date         date default current_date
    ) returns jsonb
    language plpgsql
    security invoker
    set search_path = public
    as $$
    declare
        v_tenant  uuid := public.get_my_tenant_id();
        v_existing jsonb;
        v_emp     record;
        v_product record;
        v_value   bigint;
        v_mov_id  uuid;
    begin
        if v_tenant is null then
            raise exception 'يجب تسجيل الدخول أولاً';
        end if;

        select to_jsonb(m) into v_existing
        from public.employee_movements m
        where m.tenant_id = v_tenant and m.request_id = p_request_id;

        if v_existing is not null then
            return jsonb_build_object('duplicate', true, 'movement', v_existing);
        end if;

        select * into v_emp
        from public.employees e
        where e.id = p_employee_id and e.tenant_id = v_tenant;

        if v_emp.id is null then
            raise exception 'الموظف غير موجود';
        end if;

        -- Direction/category consistency.
        if p_direction = 'in'  and p_category not in ('bonus', 'allowance') then
            raise exception 'الإضافات تكون مكافأة أو بدل فقط';
        end if;
        if p_direction = 'out' and p_category not in ('advance', 'product', 'other') then
            raise exception 'الخصومات تكون سلفة أو منتج أو أخرى فقط';
        end if;
        if p_direction not in ('in', 'out') then
            raise exception 'اتجاه الحركة غير صحيح';
        end if;

        -- Product deduction: value = qty x cost, inventory leaves immediately.
        if p_category = 'product' then
            if p_product_id is null or p_qty is null or p_qty <= 0 then
                raise exception 'خصم المنتج يتطلب المنتج والكمية';
            end if;

            select * into v_product
            from public.products pr
            where pr.id = p_product_id and pr.tenant_id = v_tenant;

            if v_product.id is null then
                raise exception 'المنتج غير موجود';
            end if;

            if v_product.qty - p_qty < 0 then
                raise exception 'الكمية غير متوفرة في المخزون';
            end if;

            v_value := round(p_qty::numeric * v_product.purchase_price)::bigint;

            insert into public.employee_movements
                (tenant_id, employee_id, month, date, direction, category, amount, description, product_id, qty, request_id)
            values
                (v_tenant, p_employee_id, date_trunc('month', p_month)::date, p_date, p_direction,
                p_category, v_value, p_description, p_product_id, p_qty, p_request_id)
            returning id into v_mov_id;

            update public.products set qty = qty - p_qty where id = p_product_id;

            insert into public.stock_moves (tenant_id, product_id, type, qty, ref, reason, date, employee_id)
            values (v_tenant, p_product_id, 'out', p_qty, p_description, 'خصم منتج للموظف', p_date, p_employee_id);

            return jsonb_build_object('movement_id', v_mov_id, 'amount', v_value);
        end if;

-- Cash movements.
    if p_amount is null or p_amount <= 0 then
        raise exception 'المبلغ غير صحيح';
    end if;

    insert into public.employee_movements
        (tenant_id, employee_id, month, date, direction, category, amount, description, product_id, qty, request_id)
    values
        (v_tenant, p_employee_id, date_trunc('month', p_month)::date, p_date, p_direction,
         p_category, p_amount, p_description, p_product_id, p_qty, p_request_id)
        returning id into v_mov_id;

        return jsonb_build_object('movement_id', v_mov_id, 'amount', p_amount);
    end;
    $$;

    -- ---------------------------------------------------------------------
    -- pay_salary: record the actual cash paid and the month's accounting.
    --   Journal (balanced by construction):
    --     DR 2030 Salaries Payable = min(arrears, paid)     (clears prior arrears)
    --     DR 5030 Wages             = net_due - prior_cleared
    --     CR cash/bank               = paid
    --     CR 2030 Salaries Payable   = net_due - paid        (new arrears, if any)
    -- ---------------------------------------------------------------------
    create or replace function public.pay_salary(
        p_request_id  uuid,
        p_employee_id uuid,
        p_month       date,
        p_paid        bigint,
        p_method      text,
        p_date        date default current_date,
        p_note        text default null
    ) returns jsonb
    language plpgsql
    security invoker
    set search_path = public
    as $$
    declare
        v_tenant   uuid := public.get_my_tenant_id();
        v_first    date := date_trunc('month', p_month)::date;
        v_existing jsonb;
        v_emp      record;
        v_ent      jsonb;
        v_net      bigint;
        v_base     bigint;
        v_arrears  bigint;
        v_clear    bigint;
        v_carry    bigint;
        v_salary_id uuid;
        v_entry_id  uuid;
        v_entry_no  bigint;
        v_creator   uuid;
        v_debit     bigint := 0;
        v_credit    bigint := 0;
        v_acc_cash  uuid;
        v_acc_bank  uuid;
        v_acc_ap    uuid;
        v_acc_wages uuid;
    begin
        if v_tenant is null then
            raise exception 'يجب تسجيل الدخول أولاً';
        end if;

        select to_jsonb(s) into v_existing
        from public.salaries s
        where s.tenant_id = v_tenant and s.request_id = p_request_id;

        if v_existing is not null then
            return jsonb_build_object('duplicate', true, 'salary', v_existing);
        end if;

        if exists (
            select 1 from public.salaries s
            where s.tenant_id = v_tenant and s.employee_id = p_employee_id and s.month = v_first
        ) then
            raise exception 'تم صرف راتب هذا الشهر مسبقاً';
        end if;

        if p_paid < 0 then
            raise exception 'مبلغ الصرف غير صحيح';
        end if;

        if p_method is null or p_method not in ('cash', 'bank') then
            raise exception 'طريقة دفع غير صحيحة';
        end if;

        select * into v_emp
        from public.employees e
        where e.id = p_employee_id and e.tenant_id = v_tenant;

        if v_emp.id is null then
            raise exception 'الموظف غير موجود';
        end if;

        v_ent := public.get_employee_entitlement(p_employee_id, v_first);
        v_net := (v_ent ->> 'net_due')::bigint;
        v_base := (v_ent ->> 'base_salary')::bigint;
        v_arrears := (v_ent ->> 'arrears')::bigint;

        if v_net <= 0 then
            raise exception 'لا توجد مستحقات للصرف لهذا الشهر';
        end if;

        if p_paid > v_net then
            raise exception 'المبلغ المصروف أكبر من المستحقات';
        end if;

        select id into v_acc_cash  from public.accounts where tenant_id = v_tenant and code = '1010' limit 1;
        select id into v_acc_bank  from public.accounts where tenant_id = v_tenant and code = '1015' limit 1;
        select id into v_acc_ap    from public.accounts where tenant_id = v_tenant and code = '2030' limit 1;
        select id into v_acc_wages from public.accounts where tenant_id = v_tenant and code = '5030' limit 1;

        if v_acc_ap is null or v_acc_wages is null then
            raise exception 'دليل الحسابات غير مكتمل';
        end if;

        v_clear := least(v_arrears, p_paid);
        v_carry := v_net - p_paid;

        insert into public.salaries (tenant_id, employee_id, month, base_salary, paid, date, request_id)
        values (v_tenant, p_employee_id, v_first, v_base, p_paid, p_date, p_request_id)
        returning id into v_salary_id;

        v_entry_no := public.next_journal_no();
        select id into v_creator from public.users u where u.auth_user_id = auth.uid();

        insert into public.journal_entries (tenant_id, entry_no, date, memo, source_type, source_id, created_by)
        values (v_tenant, v_entry_no, p_date, coalesce(p_note, 'راتب ' || v_emp.name || ' - ' || to_char(v_first, 'YYYY-MM')),
                'auto', v_salary_id, v_creator)
        returning id into v_entry_id;

        -- DR side: prior arrears cleared + this month's net expense.
        if v_clear > 0 then
            insert into public.journal_entry_lines (entry_id, account_id, debit, credit)
            values (v_entry_id, v_acc_ap, v_clear, 0);
            v_debit := v_debit + v_clear;
        end if;

        if v_net - v_clear > 0 then
            insert into public.journal_entry_lines (entry_id, account_id, debit, credit)
            values (v_entry_id, v_acc_wages, v_net - v_clear, 0);
            v_debit := v_debit + (v_net - v_clear);
        end if;

        -- CR side: cash paid + arrears carried forward.
        if p_method = 'cash' then
            insert into public.journal_entry_lines (entry_id, account_id, debit, credit)
            values (v_entry_id, v_acc_cash, 0, p_paid);
        else
            insert into public.journal_entry_lines (entry_id, account_id, debit, credit)
            values (v_entry_id, v_acc_bank, 0, p_paid);
        end if;
        v_credit := v_credit + p_paid;

        if v_carry > 0 then
            insert into public.journal_entry_lines (entry_id, account_id, debit, credit)
            values (v_entry_id, v_acc_ap, 0, v_carry);
            v_credit := v_credit + v_carry;
        end if;

        if v_debit <> v_credit then
            raise exception 'عدم توازن القيد المحاسبي (% <> %)', v_debit, v_credit;
        end if;

        return jsonb_build_object(
            'salary_id', v_salary_id,
            'month',     v_first,
            'base_salary', v_base,
            'arrears',   v_arrears,
            'entitlements', (v_ent ->> 'entitlements')::bigint,
            'deductions',   (v_ent ->> 'deductions')::bigint,
            'net_due',   v_net,
            'paid',      p_paid,
            'arrears_carried', v_carry,
            'entry_no',  v_entry_no
        );
    end;
    $$;

    revoke all on function public.get_employee_entitlement(uuid, date)                            from public;
    revoke all on function public.add_employee_movement(uuid, uuid, date, text, text, bigint, text, uuid, numeric, date) from public;
    revoke all on function public.pay_salary(uuid, uuid, date, bigint, text, date, text)          from public;

    grant execute on function public.get_employee_entitlement(uuid, date)                            to authenticated;
    grant execute on function public.add_employee_movement(uuid, uuid, date, text, text, bigint, text, uuid, numeric, date) to authenticated;
    grant execute on function public.pay_salary(uuid, uuid, date, bigint, text, date, text)          to authenticated;

    commit;