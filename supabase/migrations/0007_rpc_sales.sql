    -- 0007_rpc_sales.sql
    -- The canonical write RPC. Every other accounting RPC mirrors this shape:
    --   SECURITY INVOKER + RLS  -> tenant isolation is enforced by row security
    --   one transaction         -> rollback on any error
    --   idempotent via request_id -> a retried call cannot duplicate an invoice
    --   final balance ASSERT    -> the most important rule (PROJECT_SPEC §5)
    --
    -- Naming note: invoice_items and journal_entry_lines carry no tenant_id, so
    -- their INSERT policies scope through the parent row (invoice / journal entry).

    begin;

    -- ---------------------------------------------------------------------
    -- Idempotency support on the invoice row itself (queryable duplicate).
    -- ---------------------------------------------------------------------
    alter table public.invoices add column if not exists request_id uuid;
    create unique index if not exists idx_invoices_request_id
        on public.invoices (request_id)
        where request_id is not null;

    -- ---------------------------------------------------------------------
    -- INSERT policies for the rows this RPC writes (SELECT policies exist in 0004).
    -- ---------------------------------------------------------------------
    create policy tenant_isolation_insert on public.invoices
        for insert
        with check (tenant_id = public.get_my_tenant_id());

    create policy tenant_isolation_insert on public.invoice_items
        for insert
        with check (
            exists (
                select 1 from public.invoices i
                where i.id = invoice_id
                and i.tenant_id = public.get_my_tenant_id()
            )
        );

    create policy tenant_isolation_insert on public.journal_entries
        for insert
        with check (tenant_id = public.get_my_tenant_id());

    create policy tenant_isolation_insert on public.journal_entry_lines
        for insert
        with check (
            exists (
                select 1 from public.journal_entries je
                where je.id = entry_id
                and je.tenant_id = public.get_my_tenant_id()
            )
        );

    create policy tenant_isolation_insert on public.stock_moves
        for insert
        with check (tenant_id = public.get_my_tenant_id());

    create policy tenant_isolation_insert on public.commission_dues
        for insert
        with check (tenant_id = public.get_my_tenant_id());

    -- ---------------------------------------------------------------------
    -- Privileges. SECURITY INVOKER requires the caller to hold table-level
    -- INSERT (per PROJECT_SPEC §12: RLS is the isolation backstop, the RPC is
    -- where business rules live; these grants are the accepted consequence of
    -- the INVOKER model).
    -- ---------------------------------------------------------------------
    grant insert on public.invoices            to authenticated;
    grant insert on public.invoice_items       to authenticated;
    grant insert on public.journal_entries     to authenticated;
    grant insert on public.journal_entry_lines to authenticated;
    grant insert on public.stock_moves         to authenticated;
    grant insert on public.commission_dues     to authenticated;

    -- ---------------------------------------------------------------------
    -- create_sale_invoice
    --   p_items: jsonb array of {"product_id": uuid, "qty": numeric, "price": bigint}
    --   price is optional; 0/null falls back to products.sale_price.
    --   p_paid: amount collected now; 0 = pure credit sale.
    --   p_payment_method: 'cash' -> 1010 Cash, 'bank' -> 1015 Bank, otherwise Accounts
    --                     Receivable receives the unpaid remainder.
    -- ---------------------------------------------------------------------
    create or replace function public.create_sale_invoice(
        p_request_id     uuid,
        p_customer_id    uuid,
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
        v_pos          bigint;
        v_item         jsonb;
        v_product      record;
        v_supplier     record;
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
        v_rate         numeric;
        v_comm_amount  bigint;
        v_supplier_due bigint;
        v_debit_total  bigint := 0;
        v_acc_ar       uuid;
        v_acc_cash     uuid;
        v_acc_bank     uuid;
        v_acc_sales    uuid;
    begin
        if v_tenant is null then
            raise exception 'يجب تسجيل الدخول أولاً';
        end if;

        -- Idempotency: a retried call returns the existing invoice untouched.
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

        -- Chart of accounts (must exist; seeded by register_tenant).
        select id into v_acc_ar    from public.accounts where tenant_id = v_tenant and code = '1020' limit 1;
        select id into v_acc_cash  from public.accounts where tenant_id = v_tenant and code = '1010' limit 1;
        select id into v_acc_bank  from public.accounts where tenant_id = v_tenant and code = '1015' limit 1;
        select id into v_acc_sales from public.accounts where tenant_id = v_tenant and code = '4010' limit 1;

        if v_acc_ar is null or v_acc_sales is null then
            raise exception 'دليل الحسابات غير مكتمل';
        end if;

        if not exists (select 1 from public.customers c where c.id = p_customer_id and c.tenant_id = v_tenant) then
            raise exception 'العميل غير موجود';
        end if;

        v_no := public.next_invoice_no('sale');

        -- Header first (request_id also acts as the idempotency guard row).
        insert into public.invoices (tenant_id, type, no, party_id, date, subtotal, total, paid, remaining, status, ownership, request_id)
        values (v_tenant, 'sale', v_no, p_customer_id, p_invoice_date, 0, 0, p_paid, p_paid, 'paid', 'owned', p_request_id)
        returning id into v_invoice_id;

        -- Line items: stock check, stock deduction, stock movement, commission dues.
        for v_pos in 0 .. jsonb_array_length(p_items) - 1 loop
            v_item := p_items -> v_pos;

            select * into v_product
            from public.products pr
            where pr.id = (v_item ->> 'product_id')::uuid
            and pr.tenant_id = v_tenant;

            if v_product.id is null then
                raise exception 'المنتج غير موجود';
            end if;

            v_qty := (v_item ->> 'qty')::numeric;
            if v_qty is null or v_qty <= 0 then
                raise exception 'الكمية غير صحيحة';
            end if;

            v_price := (v_item ->> 'price')::bigint;
            if v_price is null or v_price <= 0 then
                v_price := v_product.sale_price;
            end if;

            if v_product.qty - v_qty < 0 then
                raise exception 'الكمية غير متوفرة للمنتج: %', v_product.name;
            end if;

            v_line_total := round(v_qty::numeric * v_price)::bigint;
            v_subtotal := v_subtotal + v_line_total;

            insert into public.invoice_items (invoice_id, product_id, qty, price, total)
            values (v_invoice_id, v_product.id, v_qty, v_price, v_line_total);

            update public.products set qty = qty - v_qty where id = v_product.id;

            insert into public.stock_moves (tenant_id, product_id, type, qty, ref, reason, date)
            values (v_tenant, v_product.id, 'out', v_qty, v_no, 'بيع', p_invoice_date);

            -- Commission dues: supplier linked to the product, deal_type = commission.
            if v_product.supplier_id is not null then
                select * into v_supplier
                from public.suppliers s
                where s.id = v_product.supplier_id
                and s.tenant_id = v_tenant;

                if v_supplier.deal_type = 'commission' then
                    v_rate := coalesce(v_product.commission_rate, v_supplier.commission_rate, 0);
                    if v_rate > 0 then
                        v_comm_amount  := round((v_line_total::numeric * v_rate) / 100)::bigint;
                        v_supplier_due := v_line_total - v_comm_amount;
                        insert into public.commission_dues
                            (tenant_id, supplier_id, invoice_id, product_id, sale_total,
                            commission_rate, commission_amount, supplier_due, paid, remaining, date)
                        values
                            (v_tenant, v_supplier.id, v_invoice_id, v_product.id, v_line_total,
                            v_rate, v_comm_amount, v_supplier_due, 0, v_supplier_due, p_invoice_date);
                    end if;
                end if;
            end if;
        end loop;

        -- Payment validation + finalize header.
        if p_paid > v_subtotal then
            raise exception 'المدفوع أكبر من إجمالي الفاتورة';
        end if;

        v_total := v_subtotal;
        v_remaining := v_total - p_paid;
        v_status := case
            when v_remaining = 0        then 'paid'
            when v_remaining < v_total  then 'partial'
            else 'unpaid'
        end;

        update public.invoices
        set subtotal = v_subtotal, total = v_total, paid = p_paid,
            remaining = v_remaining, status = v_status
        where id = v_invoice_id;

        -- Mandatory balanced journal entry.
        v_entry_no := public.next_journal_no();
        select id into v_creator from public.users u where u.auth_user_id = auth.uid();

        insert into public.journal_entries (tenant_id, entry_no, date, memo, source_type, source_id, created_by)
        values (v_tenant, v_entry_no, p_invoice_date, coalesce(p_memo, 'فاتورة بيع ' || v_no), 'auto', v_invoice_id, v_creator)
        returning id into v_entry_id;

        if p_paid = 0 then
            insert into public.journal_entry_lines (entry_id, account_id, debit, credit)
            values (v_entry_id, v_acc_ar, v_total, 0);
            v_debit_total := v_total;
        else
            if p_payment_method = 'cash' then
                insert into public.journal_entry_lines (entry_id, account_id, debit, credit)
                values (v_entry_id, v_acc_cash, p_paid, 0);
            elsif p_payment_method = 'bank' then
                insert into public.journal_entry_lines (entry_id, account_id, debit, credit)
                values (v_entry_id, v_acc_bank, p_paid, 0);
            end if;
            v_debit_total := p_paid;

            if v_remaining > 0 then
                insert into public.journal_entry_lines (entry_id, account_id, debit, credit)
                values (v_entry_id, v_acc_ar, v_remaining, 0);
                v_debit_total := v_debit_total + v_remaining;
            end if;
        end if;

        insert into public.journal_entry_lines (entry_id, account_id, debit, credit)
        values (v_entry_id, v_acc_sales, 0, v_total);

        -- THE non-negotiable rule: balanced double-entry or full rollback.
        if v_debit_total <> v_total then
            raise exception 'عدم توازن القيد المحاسبي (% <> %)', v_debit_total, v_total;
        end if;

        return jsonb_build_object(
            'invoice_id', v_invoice_id,
            'no',        v_no,
            'total',     v_total,
            'paid',      p_paid,
            'remaining', v_remaining,
            'status',    v_status,
            'entry_no',  v_entry_no
        );
    end;
    $$;

    revoke all on function public.create_sale_invoice(uuid, uuid, jsonb, date, bigint, text, text) from public;
    grant execute on function public.create_sale_invoice(uuid, uuid, jsonb, date, bigint, text, text) to authenticated;

    commit;