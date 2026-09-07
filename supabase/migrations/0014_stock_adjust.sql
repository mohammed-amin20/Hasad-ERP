-- 0014_stock_adjust.sql
-- adjust_inventory — physical inventory count (MILESTONES M4, output 6).
--   * Direct single-product adjustment: records the delta as a stock_moves
--     row of type 'adjust' (qty check is `> 0`, so magnitude is stored and
--     direction is readable from ref: "جرد: old -> new").
--   * Idempotency is NOT needed here: the caller must not blindly retry a
--     count; the UI disables double-submit (`p_request_id` would require a
--     tracking table, which stock_moves already partially provides).
-- Existing grants/policies from 0007 cover stock_moves inserts; products
-- has a full tenant-isolation policy from 0004.
-- Same SECURITY INVOKER / RLS pattern as the invoice RPCs.

begin;

create or replace function public.adjust_inventory(
    p_product_id  uuid,
    p_counted_qty numeric,
    p_reason      text default null,
    p_date        date default current_date
) returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
    v_tenant   uuid := public.get_my_tenant_id();
    v_product  record;
    v_old      numeric;
    v_new      numeric;
    v_delta    numeric;
begin
    if v_tenant is null then
        raise exception 'يجب تسجيل الدخول أولاً';
    end if;

    if p_product_id is null or p_counted_qty is null or p_counted_qty < 0 then
        raise exception 'الكمية المقروءة غير صحيحة';
    end if;

    select * into v_product
    from public.products pr
    where pr.id = p_product_id
      and pr.tenant_id = v_tenant;

    if not found then
        raise exception 'المنتج غير موجود';
    end if;

    v_old := v_product.qty;
    v_new := round(p_counted_qty::numeric, 3);
    v_delta := v_new - v_old;

    if v_delta = 0 then
        return jsonb_build_object(
            'product_id', p_product_id,
            'name',       v_product.name,
            'old_qty',    v_old,
            'new_qty',    v_new,
            'delta',      0,
            'changed',    false
        );
    end if;

    insert into public.stock_moves (tenant_id, product_id, type, qty, ref, reason, date)
    values (v_tenant, p_product_id, 'adjust', abs(v_delta),
            'جرد: ' || v_old::text || ' -> ' || v_new::text,
            p_reason, p_date);

    update public.products
       set qty = v_new
     where id = p_product_id;

    return jsonb_build_object(
        'product_id', p_product_id,
        'name',       v_product.name,
        'old_qty',    v_old,
        'new_qty',    v_new,
        'delta',      v_delta,
        'changed',    true
    );
end;
$$;

revoke all on function public.adjust_inventory(uuid, numeric, text, date) from public;
grant execute on function public.adjust_inventory(uuid, numeric, text, date) to authenticated;

commit;