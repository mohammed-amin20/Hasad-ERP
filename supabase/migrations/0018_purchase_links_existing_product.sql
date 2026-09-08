-- 0018_purchase_links_existing_product.sql
-- Fix (recreates create_purchase_invoice from 0008): a consignment purchase
-- that references an EXISTING product must bind that product to the
-- (commission) supplier. create_sale_invoice keys commission dues off
-- product.supplier_id + supplier.deal_type = 'commission', but 0008 only
-- stamped supplier_id/commission_rate on inline (new_product) items — so
-- consignment stock that was pre-created stayed unlinked and its sales
-- silently produced NO commission dues (party_statement.ps1 Case 2).
--
-- Behavior change: on a consignment receipt, an existing product whose
-- supplier_id differs from the purchasing supplier is relinked to it
-- (commission_rate falls back to the supplier's). Direct (owned) purchases
-- are untouched — a product is never relinked through a non-commission deal.

begin;

create or replace function public.create_purchase_invoice(
    p_request_id     uuid,
    p_supplier_id    uuid,
    p_items          jsonb,
    p_invoice_date   date default current_date,
    p_paid           bigint default 0,
    p_payment_method text default null,
    p_memo           text default null
) returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
    v_tenant       uuid := public.get_my_tenant_id();
    v_existing     jsonb;
    v_supplier     record;
    v_ownership    text;
    v_pos          bigint;
    v_item         jsonb;
    v_product      record;
    v_pid          uuid;
    v_qty          numeric;
    v_price        bigint;
    v_line_total   bigint;
    v_subtotal     bigint := 0;
    v_total        bigint;
    v_remaining    bigint;
    v_status       text;
    v_no           text;
    v_invoice_id   uuid;
    v_entry_id     uuid;
    v_entry_no     bigint;
    v_creator      uuid;
    v_debit_total  bigint := 0;
    v_acc_inventory uuid;
    v_acc_ap       uuid;
    v_acc_cash     uuid;
    v_acc_bank     uuid;
begin
    if v_tenant is null then
        raise exception 'يجب تسجيل الدخول أولاً';
    end if;

    -- Idempotency.
    select to_jsonb(inv) into v_existing
    from public.invoices inv
    where inv.tenant_id = v_tenant
      and inv.request_id = p_request_id;

    if v_existing is not null then
        return jsonb_build_object('duplicate', true, 'invoice', v_existing);
    end if;

    if p_items is null or jsonb_array_length(p_items) = 0 then
        raise exception 'لا توجد أصناف في الفاتورة';
    end if;

    if p_paid < 0 or (p_paid > 0 and (p_payment_method is null or p_payment_method not in ('cash', 'bank'))) then
        raise exception 'طريقة دفع غير صحيحة';
    end if;

    select * into v_supplier
    from public.suppliers s
    where s.id = p_supplier_id
      and s.tenant_id = v_tenant;

    if v_supplier.id is null then
        raise exception 'المورد غير موجود';
    end if;

    v_ownership := case when v_supplier.deal_type = 'commission' then 'consignment' else 'owned' end;

    -- Consignment receipts can never be paid.
    if v_ownership = 'consignment' and p_paid > 0 then
        raise exception 'لا يمكن دفع فاتورة استلام بالعمولة';
    end if;

    -- Chart accounts (only needed for direct purchases).
    select id into v_acc_inventory from public.accounts where tenant_id = v_tenant and code = '1030' limit 1;
    select id into v_acc_ap        from public.accounts where tenant_id = v_tenant and code = '2010' limit 1;
    select id into v_acc_cash      from public.accounts where tenant_id = v_tenant and code = '1010' limit 1;
    select id into v_acc_bank      from public.accounts where tenant_id = v_tenant and code = '1015' limit 1;

    if v_ownership = 'owned' and (v_acc_inventory is null or v_acc_ap is null) then
        raise exception 'دليل الحسابات غير مكتمل';
    end if;

    v_no := public.next_invoice_no('purchase');

    insert into public.invoices (tenant_id, type, no, party_id, date, subtotal, total, paid, remaining, status, ownership, request_id)
    values (v_tenant, 'purchase', v_no, p_supplier_id, p_invoice_date, 0, 0, p_paid, p_paid, 'paid', v_ownership, p_request_id)
    returning id into v_invoice_id;

    -- Line items: reference an existing product or create one inline.
    for v_pos in 0 .. jsonb_array_length(p_items) - 1 loop
        v_item := p_items -> v_pos;
        v_pid   := (v_item ->> 'product_id')::uuid;

        if v_pid is not null and v_item ? 'new_product' then
            raise exception 'حدد المنتج الموجود أو الجديد وليس كليهما معاً';
        end if;

        if v_pid is not null then
            select * into v_product
            from public.products pr
            where pr.id = v_pid
              and pr.tenant_id = v_tenant;

            if not found then
                raise exception 'المنتج غير موجود';
            end if;

            -- Consignment stock is bound to its (commission) supplier: link
            -- the product so later sales generate the supplier's commission
            -- dues (create_sale_invoice keys off product.supplier_id).
            if v_ownership = 'consignment' and v_product.supplier_id is distinct from p_supplier_id then
                update public.products
                   set supplier_id     = p_supplier_id,
                       commission_rate = coalesce(commission_rate, v_supplier.commission_rate)
                 where id = v_product.id;
            end if;
        else
            if not (v_item ? 'new_product') then
                raise exception 'كل بند يجب أن يحتوي على منتج';
            end if;

            if (v_item->'new_product'->>'name') is null or trim((v_item->'new_product'->>'name')) = '' then
                raise exception 'اسم المنتج الجديد مطلوب';
            end if;

            insert into public.products
                (tenant_id, name, unit, unit_type, sale_price, purchase_price, qty, supplier_id, commission_rate)
            values
                (v_tenant,
                 (v_item->'new_product'->>'name'),
                 coalesce((v_item->'new_product'->>'unit'), 'قطعة'),
                 coalesce((v_item->'new_product'->>'unit_type'), 'count'),
                 coalesce(((v_item->'new_product'->>'sale_price')::bigint), 0),
                 0,
                 0,
                 p_supplier_id,
                 coalesce(((v_item->'new_product'->>'commission_rate')::numeric), v_supplier.commission_rate))
            returning * into v_product;
        end if;

        v_qty := (v_item ->> 'qty')::numeric;
        if v_qty is null or v_qty <= 0 then
            raise exception 'الكمية غير صحيحة';
        end if;

        v_price := (v_item ->> 'price')::bigint;
        if v_price is null or v_price <= 0 then
            v_price := v_product.purchase_price;
        end if;

        v_line_total := round(v_qty::numeric * v_price)::bigint;
        v_subtotal := v_subtotal + v_line_total;

        insert into public.invoice_items (invoice_id, product_id, qty, price, total)
        values (v_invoice_id, v_product.id, v_qty, v_price, v_line_total);

        update public.products set qty = qty + v_qty, purchase_price = v_price
        where id = v_product.id;

        insert into public.stock_moves (tenant_id, product_id, type, qty, ref, reason, date)
        values (v_tenant, v_product.id, 'in', v_qty, v_no, 'شراء', p_invoice_date);
    end loop;

    if p_paid > v_subtotal then
        raise exception 'المدفوع أكبر من إجمالي الفاتورة';
    end if;

    v_total := v_subtotal;
    v_remaining := v_total - p_paid;
    v_status := case
        when v_ownership = 'consignment' then 'unpaid'
        when v_remaining = 0             then 'paid'
        when v_remaining < v_total       then 'partial'
        else 'unpaid'
    end;

    update public.invoices
       set subtotal = v_subtotal, total = v_total, paid = p_paid,
           remaining = v_remaining, status = v_status
     where id = v_invoice_id;

    -- Journal entry ONLY for real debt (direct suppliers).
    if v_ownership = 'owned' then
        v_entry_no := public.next_journal_no();
        select id into v_creator from public.users u where u.auth_user_id = auth.uid();

        insert into public.journal_entries (tenant_id, entry_no, date, memo, source_type, source_id, created_by)
        values (v_tenant, v_entry_no, p_invoice_date, coalesce(p_memo, 'فاتورة شراء ' || v_no), 'auto', v_invoice_id, v_creator)
        returning id into v_entry_id;

        insert into public.journal_entry_lines (entry_id, account_id, debit, credit)
        values (v_entry_id, v_acc_inventory, v_total, 0);
        v_debit_total := v_total;

        if p_paid > 0 then
            if p_payment_method = 'cash' then
                insert into public.journal_entry_lines (entry_id, account_id, debit, credit)
                values (v_entry_id, v_acc_cash, 0, p_paid);
            elsif p_payment_method = 'bank' then
                insert into public.journal_entry_lines (entry_id, account_id, debit, credit)
                values (v_entry_id, v_acc_bank, 0, p_paid);
            end if;
        end if;

        if v_remaining > 0 then
            insert into public.journal_entry_lines (entry_id, account_id, debit, credit)
            values (v_entry_id, v_acc_ap, 0, v_remaining);
        end if;

        if v_debit_total <> v_total then
            raise exception 'عدم توازن القيد المحاسبي';
        end if;
    end if;

    return jsonb_build_object(
        'invoice_id', v_invoice_id,
        'no',        v_no,
        'total',     v_total,
        'paid',      p_paid,
        'remaining', v_remaining,
        'status',    v_status,
        'ownership', v_ownership,
        'entry_no',  v_entry_no
    );
end;
$$;

revoke all on function public.create_purchase_invoice(uuid, uuid, jsonb, date, bigint, text, text) from public;
grant execute on function public.create_purchase_invoice(uuid, uuid, jsonb, date, bigint, text, text) to authenticated;

commit;