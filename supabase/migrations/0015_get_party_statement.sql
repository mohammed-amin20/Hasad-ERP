-- 0015_get_party_statement.sql
-- get_party_statement(p_party_type, p_party_id, p_from, p_to)
-- Detailed account statement for one customer or supplier between two dates
-- (both inclusive), with an opening-balance row and a running balance.
--
-- Rows are produced by a union of:
--   * invoice totals   -> 'invoice' line  (debit for a sale, credit for a purchase)
--   * payments         -> 'payment' line  (opposite direction of the invoice)
--   * commission_dues  -> 'commission'    (supplier only; their due is a credit)
--
-- Consignment purchase invoices have total=0 in the ledger (stock only, no
-- debt), so they contribute zero debit/credit to the statement. Supplier
-- commission dues appear as their own separate line.
--
-- The running balance is computed with a window (sum over rows) seeded by an
-- explicit OPENING row dated before p_from. For a customer: positive = they
-- owe us. For a supplier: positive = we owe them.
--
-- security invoker + RLS: the function only ever reads the caller's tenant
-- (get_my_tenant_id) and provably the requested party belongs to that tenant.

begin;

create or replace function public.get_party_statement(
    p_party_type text,
    p_party_id   uuid,
    p_from       date,
    p_to         date
) returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
    v_tenant      uuid := public.get_my_tenant_id();
    v_exists      boolean;
    v_opening     bigint := 0;
    v_closing     bigint;
    v_rows        jsonb;
begin
    if v_tenant is null then
        raise exception 'يجب تسجيل الدخول أولاً';
    end if;

    if p_party_type not in ('customer', 'supplier') then
        raise exception 'نوع الطرف غير صالح';
    end if;

    if p_from is null or p_to is null then
        raise exception 'يجب تحديد تاريخ البداية والنهاية';
    end if;

    if p_from > p_to then
        raise exception 'تاريخ البداية بعد تاريخ النهاية';
    end if;

    -- Party must belong to the caller's tenant.
    if p_party_type = 'customer' then
        select exists(select 1 from public.customers c
                      where c.id = p_party_id and c.tenant_id = v_tenant)
          into v_exists;
    else
        select exists(select 1 from public.suppliers s
                      where s.id = p_party_id and s.tenant_id = v_tenant)
          into v_exists;
    end if;

    if not v_exists then
        raise exception 'الطرف غير موجود';
    end if;

    -- Opening balance = net position before p_from, from invoices + payments
    -- (+ commission dues for suppliers).
    -- customer lines: sale invoice = +debit (they owe); customer payment = -debit.
    -- supplier lines: owned purchase invoice = +credit (we owe); supplier payment
    --                 = -credit; commission due = +credit (we owe).
    if p_party_type = 'customer' then
        select coalesce(sum(net), 0) into v_opening
        from (
            select (case when i.type = 'sale' then i.total else 0 end) -
                   (case when p.amount is not null then p.amount else 0 end) as net
            from public.invoices i
            left join public.payments p
                   on p.invoice_id = i.id and p.type = 'customer'
            where i.tenant_id = v_tenant
              and i.party_id = p_party_id
              and i.date < p_from
        ) t;
    else
        select coalesce(sum(net), 0) into v_opening
        from (
            select (case
                       when i.ownership = 'owned' then i.total
                       else 0
                    end) -
                   (case when p.amount is not null then p.amount else 0 end) as net
            from public.invoices i
            left join public.payments p
                   on p.invoice_id = i.id and p.type = 'supplier'
            where i.tenant_id = v_tenant
              and i.party_id = p_party_id
              and i.date < p_from
            union all
            select coalesce(d.remaining, 0) as net
            from public.commission_dues d
            where d.tenant_id = v_tenant
              and d.supplier_id = p_party_id
              and d.date < p_from
        ) t;
    end if;

    -- Movement rows within [p_from, p_to], oldest first.
    with movements as (
        select
            i.date                          as dt,
            'invoice'                       as kind,
            i.no                            as ref,
            null                            as note,
            (case when i.type = 'sale' then i.total else 0 end) as debit,
            (case
               when i.type = 'purchase' and i.ownership = 'owned' then i.total
               else 0
            end)                            as credit,
            i.created_at                    as created
        from public.invoices i
        where i.tenant_id = v_tenant
          and i.party_id = p_party_id
          and i.date between p_from and p_to

        union all

        select
            p.date                          as dt,
            'payment'                       as kind,
            (select i.no from public.invoices i where i.id = p.invoice_id) as ref,
            p.note                          as note,
            (case when p.type = 'supplier' then p.amount else 0 end) as debit,
            (case when p.type = 'customer' then p.amount else 0 end) as credit,
            p.created_at                    as created
        from public.payments p
        where p.tenant_id = v_tenant
          and p.party_id = p_party_id
          and p.date between p_from and p_to

        union all

        select
            d.date                          as dt,
            'commission'                    as kind,
            (select i.no from public.invoices i where i.id = d.invoice_id) as ref,
            ('عمولة ' || coalesce(d.commission_rate, 0) || '%') as note,
            0                               as debit,
            d.supplier_due                  as credit,
            d.created_at                    as created
        from public.commission_dues d
        where d.tenant_id = v_tenant
          and d.supplier_id = p_party_id
          and d.date between p_from and p_to
    )
    select coalesce(jsonb_agg(
        jsonb_build_object(
            'date',        to_char(m.dt, 'YYYY-MM-DD'),
            'kind',        m.kind,
            'ref',         m.ref,
            'note',        m.note,
            'debit',       m.debit,
            'credit',      m.credit
        )
        order by m.dt asc, m.created asc
    ), '[]'::jsonb)
      into v_rows
    from movements m;

    select v_opening + coalesce(sum((r->>'debit')::bigint - (r->>'credit')::bigint), 0)
      into v_closing
    from jsonb_array_elements(v_rows) r;

    return jsonb_build_object(
        'party_type', p_party_type,
        'party_id',   p_party_id,
        'from',       to_char(p_from, 'YYYY-MM-DD'),
        'to',         to_char(p_to, 'YYYY-MM-DD'),
        'opening',    v_opening,
        'closing',    v_closing,
        'lines',      v_rows
    );
end;
$$;

revoke all on function public.get_party_statement(text, uuid, date, date) from public;
grant execute on function public.get_party_statement(text, uuid, date, date) to authenticated;

commit;
