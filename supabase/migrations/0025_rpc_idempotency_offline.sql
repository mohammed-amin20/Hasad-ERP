-- 0025_rpc_idempotency_offline.sql
-- Makes the two write RPCs that still had no replay guard safe for the offline
-- queue: adjust_inventory (0014) and create_account (0019).
--
-- WHY NOW. 0014 carried an explicit comment that idempotency was "NOT needed"
-- because "the UI disables double-submit". That assumption dies the moment a
-- leg is queued: the sync flusher replays a request it cannot prove failed, and
-- a request that times out AFTER the server committed is indistinguishable from
-- one that never arrived. Both cases are now reachable, so both RPCs accept a
-- client request_id and return the stored result on a replay.
--
--   * adjust_inventory  -> double-applying the delta silently corrupts stock
--     and posts a second stock_moves row. Genuine data corruption, not a
--     duplicate the user would notice.
--   * create_account    -> the pre-existing per-tenant unique index on
--     accounts.code already prevented a double INSERT, but the replay returned
--     {'duplicate': true}, which the app surfaces as the user-facing error
--     "كود الحساب مستخدم مسبقاً". A retried create therefore looked like a real
--     validation failure, and the local id_map never learned the new account's
--     id. The request_id guard returns the original account_id instead.
--
-- SIGNATURE CHANGE. Adding a parameter with a default does NOT replace the
-- function: `create or replace` with a different parameter list creates an
-- ADDITIONAL overload, and a 4-argument call would then be ambiguous
-- ("function is not unique"). Both old signatures are therefore dropped
-- explicitly first. PostgREST resolves by argument names over the wire, and
-- the new parameter is last with a default, so every existing client that
-- omits it keeps working unchanged.
--
-- IDEMPOTENCY LEDGER. Reuses processed_requests (0009 + 0011) -- the same table
-- settle_supplier uses -- rather than adding a per-RPC table. It carries
-- result jsonb, so a replay returns the byte-identical original envelope
-- instead of recomputing it.
--
-- The read is TENANT-SCOPED on purpose. processed_requests_request_id_key is a
-- FULL global unique constraint (it must stay non-partial: settle_supplier
-- uses `on conflict (request_id)` as its arbiter). A global lookup would hand
-- tenant B the stored result of tenant A's request if two clients ever collided
-- on a request_id, which is a cross-tenant read of another tenant's data. The
-- cost of scoping is that a genuine cross-tenant collision no longer dedupes;
-- the `on conflict do nothing` insert below then silently keeps the first
-- row, and this call is simply treated as a new request. Client-generated UUIDs
-- make that vanishingly unlikely, and failing closed toward "apply the write"
-- is the safer side of that trade.
--
-- Same SECURITY INVOKER / RLS pattern as every other RPC here; the ledger
-- policies from 0011 (select + insert, own tenant) are what this relies on.

begin;

-- ===========================================================================
-- adjust_inventory
-- ===========================================================================

drop function if exists public.adjust_inventory(uuid, numeric, text, date);

create function public.adjust_inventory(
    p_product_id  uuid,
    p_counted_qty numeric,
    p_reason      text default null,
    p_date        date   default current_date,
    p_request_id  uuid   default null
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
    v_previous jsonb;
    v_result   jsonb;
begin
    if v_tenant is null then
        raise exception 'يجب تسجيل الدخول أولاً';
    end if;

    -- Replay: return the first call's stored envelope untouched. This must run
    -- BEFORE any validation, because a legitimate retry re-sends the same
    -- counted qty, and by then the product qty has already been changed to it
    -- -- so the delta now reads 0 and a recomputed answer would be a lie.
    if p_request_id is not null then
        select pr.result into v_previous
        from public.processed_requests pr
        where pr.request_id = p_request_id
          and pr.tenant_id  = v_tenant
          and pr.rpc_name   = 'adjust_inventory';

        if v_previous is not null then
            return v_previous;
        end if;
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
        v_result := jsonb_build_object(
            'product_id', p_product_id,
            'name',       v_product.name,
            'old_qty',    v_old,
            'new_qty',    v_new,
            'delta',      0,
            'changed',    false
        );
    else
        insert into public.stock_moves (tenant_id, product_id, type, qty, ref, reason, date)
        values (v_tenant, p_product_id, 'adjust', abs(v_delta),
                'جرد: ' || v_old::text || ' -> ' || v_new::text,
                p_reason, p_date);

        update public.products
           set qty = v_new
         where id = p_product_id;

        v_result := jsonb_build_object(
            'product_id', p_product_id,
            'name',       v_product.name,
            'old_qty',    v_old,
            'new_qty',    v_new,
            'delta',      v_delta,
            'changed',    true
        );
    end if;

    -- Recorded on the changed:false path too, so a replay of a no-op count
    -- returns the same envelope rather than recomputing against a product that
    -- a later, unrelated count may have moved.
    if p_request_id is not null then
        insert into public.processed_requests (request_id, rpc_name, tenant_id, result)
        values (p_request_id, 'adjust_inventory', v_tenant, v_result)
        on conflict (request_id) do nothing;
    end if;

    return v_result;
end;
$$;

revoke all on function public.adjust_inventory(uuid, numeric, text, date, uuid) from public;
grant execute on function public.adjust_inventory(uuid, numeric, text, date, uuid) to authenticated;

-- ===========================================================================
-- create_account
-- ===========================================================================

drop function if exists public.create_account(text, text, text, text);

create function public.create_account(
    p_code        text,
    p_name        text,
    p_type        text,
    p_parent_code text default null,
    p_request_id  uuid default null
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
    v_previous jsonb;
begin
    if v_tenant is null then
        raise exception 'يجب تسجيل الدخول أولاً';
    end if;

    if p_request_id is not null then
        select pr.result into v_previous
        from public.processed_requests pr
        where pr.request_id = p_request_id
          and pr.tenant_id  = v_tenant
          and pr.rpc_name   = 'create_account';

        if v_previous is not null then
            return v_previous;
        end if;
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

    -- A genuine collision (no request_id, or a different request_id reusing an
    -- existing code) still reports duplicate. Only the request_id path above
    -- can return a successful result for an already-present code.
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

    if p_request_id is not null then
        insert into public.processed_requests (request_id, rpc_name, tenant_id, result)
        values (
            p_request_id,
            'create_account',
            v_tenant,
            jsonb_build_object(
                'account_id', v_account,
                'code',       p_code,
                'name',       p_name,
                'type',       p_type,
                'parent_id',  v_parent
            )
        )
        on conflict (request_id) do nothing;
    end if;

    return jsonb_build_object(
        'account_id', v_account,
        'code',       p_code,
        'name',       p_name,
        'type',       p_type,
        'parent_id',  v_parent
    );
end;
$$;

revoke all on function public.create_account(text, text, text, text, uuid) from public;
grant execute on function public.create_account(text, text, text, text, uuid) to authenticated;

commit;
