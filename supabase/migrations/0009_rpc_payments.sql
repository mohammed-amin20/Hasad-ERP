-- 0009_rpc_payments.sql
-- record_payment : invoice-scoped payment/collection (sale OR purchase), balanced.
-- settle_supplier: bulk, oldest-first settlement of a supplier's owned purchase
--                  invoices AND commission dues, balanced.
-- Same transaction / INVOKER / idempotency rules as the other write RPCs:
--   record_payment  -> payments.request_id (1 row per call, queryable duplicate)
--   settle_supplier -> processed_requests.result (many payments rows per call)
-- Extended to grow (deferred): invoice-less open customer credit (YAGNI).

begin;

-- ---------------------------------------------------------------------
-- Schema: idempotency support + result replay for bulk settlements
-- ---------------------------------------------------------------------
alter table public.payments add column if not exists request_id uuid;
create unique index if not exists idx_payments_request_id
    on public.payments (request_id)
    where request_id is not null;

alter table public.processed_requests add column if not exists result jsonb;

-- ---------------------------------------------------------------------
-- RLS policies (first UPDATE policies in the fleet)
-- ---------------------------------------------------------------------
create policy tenant_isolation_insert on public.payments
    for insert
    with check (tenant_id = public.get_my_tenant_id());

create policy tenant_isolation_update on public.invoices
    for update
    using (tenant_id = public.get_my_tenant_id())
    with check (tenant_id = public.get_my_tenant_id());

create policy tenant_isolation_update on public.commission_dues
    for update
    using (tenant_id = public.get_my_tenant_id())
    with check (tenant_id = public.get_my_tenant_id());

grant insert on public.payments         to authenticated;
grant update on public.invoices         to authenticated;
grant update on public.commission_dues  to authenticated;

-- ---------------------------------------------------------------------
-- record_payment: pay down one invoice (customer or supplier).
--   p_method: 'cash' -> 1010, 'bank' -> 1015
-- ---------------------------------------------------------------------
create or replace function public.record_payment(
    p_request_id uuid,
    p_invoice_id uuid,
    p_amount     bigint,
    p_method     text,
    p_date       date default current_date,
    p_note       text default null
) returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
    v_tenant    uuid := public.get_my_tenant_id();
    v_existing  jsonb;
    v_inv       record;
    v_new_rem   bigint;
    v_status    text;
    v_payment_id uuid;
    v_entry_id   uuid;
    v_entry_no   bigint;
    v_creator    uuid;
    v_acc_cash   uuid;
    v_acc_bank   uuid;
    v_acc_party  uuid;
begin
    if v_tenant is null then
        raise exception 'يجب تسجيل الدخول أولاً';
    end if;

    select to_jsonb(p) into v_existing
    from public.payments p
    where p.tenant_id = v_tenant and p.request_id = p_request_id;

    if v_existing is not null then
        return jsonb_build_object('duplicate', true, 'payment', v_existing);
    end if;

    if p_amount is null or p_amount <= 0 then
        raise exception 'مبلغ الدفع غير صحيح';
    end if;

    if p_method is null or p_method not in ('cash', 'bank') then
        raise exception 'طريقة دفع غير صحيحة';
    end if;

    select * into v_inv
    from public.invoices i
    where i.id = p_invoice_id and i.tenant_id = v_tenant;

    if v_inv.id is null then
        raise exception 'الفاتورة غير موجودة';
    end if;

    if v_inv.ownership = 'consignment' then
        raise exception 'لا يمكن سداد فاتورة بالعمولة';
    end if;

    if p_amount > v_inv.remaining then
        raise exception 'المبلغ أكبر من المتبقي على الفاتورة';
    end if;

    select id into v_acc_cash from public.accounts where tenant_id = v_tenant and code = '1010' limit 1;
    select id into v_acc_bank from public.accounts where tenant_id = v_tenant and code = '1015' limit 1;

    if v_inv.type = 'sale' then
        select id into v_acc_party from public.accounts where tenant_id = v_tenant and code = '1020' limit 1;
    else
        select id into v_acc_party from public.accounts where tenant_id = v_tenant and code = '2010' limit 1;
    end if;

    if v_acc_party is null then
        raise exception 'دليل الحسابات غير مكتمل';
    end if;

    v_new_rem := v_inv.remaining - p_amount;
    v_status  := case
        when v_new_rem = 0            then 'paid'
        when v_new_rem < v_inv.total  then 'partial'
        else 'unpaid'
    end;

    -- payments.type holds 'customer'/'supplier'; map from invoices.type ('sale'/'purchase').
    insert into public.payments (tenant_id, invoice_id, type, party_id, amount, date, method, note, request_id)
    values (v_tenant, v_inv.id,
            case when v_inv.type = 'sale' then 'customer' else 'supplier' end,
            v_inv.party_id, p_amount, p_date, p_method, p_note, p_request_id)
    returning id into v_payment_id;

    update public.invoices
       set paid = paid + p_amount, remaining = v_new_rem, status = v_status
     where id = v_inv.id;

    v_entry_no := public.next_journal_no();
    select id into v_creator from public.users u where u.auth_user_id = auth.uid();

    insert into public.journal_entries (tenant_id, entry_no, date, memo, source_type, source_id, created_by)
    values (v_tenant, v_entry_no, p_date, coalesce(p_note, 'سداد فاتورة ' || v_inv.no), 'auto', v_payment_id, v_creator)
    returning id into v_entry_id;

    if p_method = 'cash' then
        insert into public.journal_entry_lines (entry_id, account_id, debit, credit)
        values (v_entry_id, v_acc_cash, p_amount, 0);
    else
        insert into public.journal_entry_lines (entry_id, account_id, debit, credit)
        values (v_entry_id, v_acc_bank, p_amount, 0);
    end if;

    insert into public.journal_entry_lines (entry_id, account_id, debit, credit)
    values (v_entry_id, v_acc_party, 0, p_amount);

    return jsonb_build_object(
        'payment_id', v_payment_id,
        'invoice_id', v_inv.id,
        'no',        v_inv.no,
        'total',     v_inv.total,
        'paid',      v_inv.paid + p_amount,
        'remaining', v_new_rem,
        'status',    v_status,
        'entry_no',  v_entry_no
    );
end;
$$;

-- ---------------------------------------------------------------------
-- settle_supplier: pay a supplier's oldest owned purchase invoices, then
-- their oldest commission dues — all in one balanced transaction.
-- ---------------------------------------------------------------------
create or replace function public.settle_supplier(
    p_request_id  uuid,
    p_supplier_id uuid,
    p_amount      bigint,
    p_method      text,
    p_date        date default current_date,
    p_note        text default null
) returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
    v_tenant      uuid := public.get_my_tenant_id();
    v_dup         record;
    v_supplier    record;
    v_amount      bigint := p_amount;
    v_left        bigint;
    v_take        bigint;
    v_status      text;
    v_inv         record;
    v_due         record;
    v_alloc       jsonb := '[]'::jsonb;
    v_alloc_total bigint := 0;
    v_inv_count   bigint := 0;
    v_due_count   bigint := 0;
    v_entry_id    uuid;
    v_entry_no    bigint;
    v_creator     uuid;
    v_result      jsonb;
    v_acc_cash    uuid;
    v_acc_bank    uuid;
    v_acc_ap      uuid;
begin
    if v_tenant is null then
        raise exception 'يجب تسجيل الدخول أولاً';
    end if;

    select * into v_dup
    from public.processed_requests
    where tenant_id = v_tenant and request_id = p_request_id;

    if v_dup.request_id is not null then
        return jsonb_build_object('duplicate', true, 'result', v_dup.result);
    end if;

    if p_amount is null or p_amount <= 0 then
        raise exception 'مبلغ التسوية غير صحيح';
    end if;

    if p_method is null or p_method not in ('cash', 'bank') then
        raise exception 'طريقة دفع غير صحيحة';
    end if;

    select * into v_supplier
    from public.suppliers s
    where s.id = p_supplier_id and s.tenant_id = v_tenant;

    if v_supplier.id is null then
        raise exception 'المورد غير موجود';
    end if;

    select id into v_acc_cash from public.accounts where tenant_id = v_tenant and code = '1010' limit 1;
    select id into v_acc_bank from public.accounts where tenant_id = v_tenant and code = '1015' limit 1;
    select id into v_acc_ap   from public.accounts where tenant_id = v_tenant and code = '2010' limit 1;

    if v_acc_ap is null then
        raise exception 'دليل الحسابات غير مكتمل';
    end if;

    -- Pass 1: owned purchase invoices, oldest first.
    for v_inv in
        select * from public.invoices i
        where i.tenant_id = v_tenant
          and i.type = 'purchase'
          and i.ownership = 'owned'
          and i.party_id = p_supplier_id
          and i.remaining > 0
        order by i.date asc, i.created_at asc
    loop
        exit when v_amount <= 0;

        v_take := least(v_amount, v_inv.remaining);
        v_left := v_inv.remaining - v_take;
        v_status := case
            when v_left = 0                then 'paid'
            when v_inv.paid + v_take < v_inv.total  then 'partial'
            else 'unpaid'
        end;

        update public.invoices
           set paid = paid + v_take, remaining = remaining - v_take, status = v_status
         where id = v_inv.id;

        insert into public.payments (tenant_id, invoice_id, type, party_id, amount, date, method, note)
        values (v_tenant, v_inv.id, 'supplier', p_supplier_id, v_take, p_date, p_method,
                coalesce(p_note, 'تسوية مورد'));

        v_amount := v_amount - v_take;
        v_alloc_total := v_alloc_total + v_take;
        v_inv_count := v_inv_count + 1;
        v_alloc := v_alloc || jsonb_build_object('invoice_id', v_inv.id, 'no', v_inv.no, 'amount', v_take);
    end loop;

    -- Pass 2: commission dues, oldest first.
    for v_due in
        select * from public.commission_dues d
        where d.tenant_id = v_tenant
          and d.supplier_id = p_supplier_id
          and d.remaining > 0
        order by d.date asc, d.created_at asc
    loop
        exit when v_amount <= 0;

        v_take := least(v_amount, v_due.remaining);

        update public.commission_dues
           set paid = paid + v_take, remaining = remaining - v_take
         where id = v_due.id;

        insert into public.payments (tenant_id, invoice_id, type, party_id, amount, date, method, note)
        values (v_tenant, v_due.invoice_id, 'supplier', p_supplier_id, v_take, p_date, p_method,
                coalesce(p_note, 'تسوية عمولة'));

        v_amount := v_amount - v_take;
        v_alloc_total := v_alloc_total + v_take;
        v_due_count := v_due_count + 1;
        v_alloc := v_alloc || jsonb_build_object('due_id', v_due.id, 'invoice_id', v_due.invoice_id, 'amount', v_take);
    end loop;

    if v_amount > 0 then
        raise exception 'المبلغ المطلوب تسويته أكبر من ديون المورد';
    end if;

    if v_alloc_total = 0 then
        raise exception 'لا توجد ديون مستحقة لهذا المورد';
    end if;

    v_entry_no := public.next_journal_no();
    select id into v_creator from public.users u where u.auth_user_id = auth.uid();

    insert into public.journal_entries (tenant_id, entry_no, date, memo, source_type, source_id, created_by)
    values (v_tenant, v_entry_no, p_date, coalesce(p_note, 'تسوية مورد ' || v_supplier.name), 'auto', p_supplier_id, v_creator)
    returning id into v_entry_id;

    if p_method = 'cash' then
        insert into public.journal_entry_lines (entry_id, account_id, debit, credit)
        values (v_entry_id, v_acc_cash, v_alloc_total, 0);
    else
        insert into public.journal_entry_lines (entry_id, account_id, debit, credit)
        values (v_entry_id, v_acc_bank, v_alloc_total, 0);
    end if;

    insert into public.journal_entry_lines (entry_id, account_id, debit, credit)
    values (v_entry_id, v_acc_ap, 0, v_alloc_total);

    v_result := jsonb_build_object(
        'total',          v_alloc_total,
        'invoices_count', v_inv_count,
        'dues_count',     v_due_count,
        'entry_no',       v_entry_no,
        'allocations',    v_alloc
    );

    insert into public.processed_requests (request_id, rpc_name, tenant_id, result)
    values (p_request_id, 'settle_supplier', v_tenant, v_result)
    on conflict (request_id) do nothing;

    return v_result;
end;
$$;

revoke all on function public.record_payment(uuid, uuid, bigint, text, date, text)  from public;
revoke all on function public.settle_supplier(uuid, uuid, bigint, text, date, text) from public;

grant execute on function public.record_payment(uuid, uuid, bigint, text, date, text)  to authenticated;
grant execute on function public.settle_supplier(uuid, uuid, bigint, text, date, text) to authenticated;

commit;