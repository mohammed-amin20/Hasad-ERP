-- 0011_idempotency.sql
-- processed_requests: generic idempotency ledger for bulk-style write RPCs.
--   * record_payment  -> payments.request_id   (per-row queryable duplicate)
--   * settle_supplier -> processed_requests.result (many payments rows per call,
--     idempotency kept here so a replayed settle returns the saved result)
--   * Direct-invoker select/insert with tenant isolation; CREATE TABLE is
--     already prepended idempotently inside 0009 so a fresh sequential
--     apply of 0001-0021 survives 0009's ALTER.
--
-- The `on conflict (request_id) do nothing` in settle_supplier (0009) needs a
-- FULL (non-partial) unique constraint/index on request_id to infer the arbiter,
-- hence `constraint processed_requests_request_id_key unique (request_id)`.

begin;

create table if not exists public.processed_requests (
    id         uuid primary key default gen_random_uuid(),
    tenant_id  uuid not null references public.tenants(id) on delete cascade,
    request_id uuid not null constraint processed_requests_request_id_key unique,
    rpc_name   text,
    result     jsonb,
    created_at timestamptz not null default now()
);

-- Heal a legacy table that predates the unique constraint (DEV).
do $$
begin
    if not exists (
        select 1 from pg_constraint
        where conrelid = 'public.processed_requests'::regclass
          and contype = 'u'
          and conname = 'processed_requests_request_id_key'
    ) then
        alter table public.processed_requests
            add constraint processed_requests_request_id_key unique (request_id);
    end if;
end;
$$;

alter table public.processed_requests enable row level security;

drop policy if exists tenant_isolation_select on public.processed_requests;
create policy tenant_isolation_select on public.processed_requests
    for select
    using (tenant_id = public.get_my_tenant_id());

drop policy if exists tenant_isolation_insert on public.processed_requests;
create policy tenant_isolation_insert on public.processed_requests
    for insert
    with check (tenant_id = public.get_my_tenant_id());

grant select, insert on public.processed_requests to authenticated;
revoke all on public.processed_requests from anon;

commit;