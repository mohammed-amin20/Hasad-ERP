-- HASAD ERP - PRODUCTION SCHEMA (combined 0001-0021)
-- Concatenated from supabase/migrations/*.sql in order. Paste into Supabase SQL Editor once.

-- ======================================================
-- FILE: 0001_extensions.sql
-- ======================================================
-- 0001_extensions.sql
-- Enable required Postgres extensions for Hasad.
-- pgcrypto : gen_random_uuid() for UUID primary keys
-- pg_cron  : scheduled daily runs (due reminders, Batch 6)
-- pg_net   : outbound HTTP from SQL (n8n webhooks, Batch 6)

create extension if not exists pgcrypto;
create extension if not exists pg_cron;
create extension if not exists pg_net;

-- ======================================================
-- FILE: 0002_schema.sql
-- ======================================================
    -- 0002_schema.sql
    -- Core Hasad ERP schema — 17 tables, in the logical build order from PROJECT_SPEC §4.
    -- Rules applied everywhere:
    --   * Money is stored as BIGINT in Agorot (45.50 ₪ = 4550). No floats.
    --   * No VAT / no tax-authority fields anywhere.
    --   * Every tenant-owned table carries a NOT NULL tenant_id FK.
    --   * Enums are text + CHECK constraints for simplicity.

    begin;

    -- 1. tenants
    create table public.tenants (
        id         uuid primary key default gen_random_uuid(),
        name       text not null,
        plan       text not null default 'basic',
        created_at timestamptz not null default now()
    );

    -- 2. users (linked to Supabase Auth)
    create table public.users (
        id           uuid primary key default gen_random_uuid(),
        tenant_id    uuid not null references public.tenants(id) on delete cascade,
        auth_user_id uuid not null unique references auth.users(id) on delete cascade,
        name         text not null,
        role         text not null check (role in ('admin', 'accountant', 'sales')),
        created_at   timestamptz not null default now()
    );

    -- 3. accounts (chart of accounts)
    create table public.accounts (
        id        uuid primary key default gen_random_uuid(),
        tenant_id uuid not null references public.tenants(id) on delete cascade,
        code      text not null,
        name      text not null,
        type      text not null check (type in ('asset', 'liability', 'equity', 'revenue', 'expense')),
        parent_id uuid references public.accounts(id)
    );

    -- 4. journal_entries
    create table public.journal_entries (
        id          uuid primary key default gen_random_uuid(),
        tenant_id   uuid not null references public.tenants(id) on delete cascade,
        entry_no    bigint not null,
        date        date not null default current_date,
        memo        text,
        source_type text not null default 'auto' check (source_type in ('auto', 'manual')),
        source_id   uuid,
        created_by  uuid not null references public.users(id),
        created_at  timestamptz not null default now()
    );

    -- 5. journal_entry_lines (the balanced double-entry heart)
    create table public.journal_entry_lines (
        id         uuid primary key default gen_random_uuid(),
        entry_id   uuid not null references public.journal_entries(id) on delete cascade,
        account_id uuid not null references public.accounts(id),
        debit      bigint not null default 0 check (debit >= 0),
        credit     bigint not null default 0 check (credit >= 0),
        check (debit > 0 or credit > 0),
        check (not (debit > 0 and credit > 0))
    );

    -- 6. customers
    create table public.customers (
        id         uuid primary key default gen_random_uuid(),
        tenant_id  uuid not null references public.tenants(id) on delete cascade,
        name       text not null,
        phone      text,
        notes      text,
        created_at timestamptz not null default now()
    );

    -- 7. suppliers
    create table public.suppliers (
        id              uuid primary key default gen_random_uuid(),
        tenant_id       uuid not null references public.tenants(id) on delete cascade,
        name            text not null,
        phone           text,
        notes           text,
        deal_type       text not null default 'direct' check (deal_type in ('direct', 'commission')),
        commission_rate numeric(5, 2) check (commission_rate is null or commission_rate between 0 and 100),
        created_at      timestamptz not null default now()
    );

    -- 8. products
    create table public.products (
        id             uuid primary key default gen_random_uuid(),
        tenant_id      uuid not null references public.tenants(id) on delete cascade,
        name           text not null,
        barcode        text,
        unit           text not null,
        unit_type      text not null check (unit_type in ('count', 'weight')),
        sale_price     bigint not null default 0 check (sale_price >= 0),
        purchase_price bigint not null default 0 check (purchase_price >= 0),
        qty            numeric(15, 3) not null default 0 check (qty >= 0),
        reorder_level  numeric(15, 3) not null default 0,
        supplier_id    uuid references public.suppliers(id),
        commission_rate numeric(5, 2) check (commission_rate is null or commission_rate between 0 and 100),
        created_at     timestamptz not null default now()
    );

    -- 9. invoices (party_id references a customer OR a supplier — polymorphic, no FK)
    create table public.invoices (
        id         uuid primary key default gen_random_uuid(),
        tenant_id  uuid not null references public.tenants(id) on delete cascade,
        type       text not null check (type in ('sale', 'purchase')),
        no         text not null,
        party_id   uuid not null,
        date       date not null default current_date,
        subtotal   bigint not null default 0 check (subtotal >= 0),
        total      bigint not null default 0 check (total >= 0),
        paid       bigint not null default 0 check (paid >= 0),
        remaining  bigint not null default 0 check (remaining >= 0),
        status     text not null default 'unpaid' check (status in ('paid', 'partial', 'unpaid')),
        ownership  text not null default 'owned' check (ownership in ('owned', 'consignment')),
        created_at timestamptz not null default now()
    );

    -- 10. invoice_items
    create table public.invoice_items (
        id         uuid primary key default gen_random_uuid(),
        invoice_id uuid not null references public.invoices(id) on delete cascade,
        product_id uuid not null references public.products(id),
        qty        numeric(15, 3) not null check (qty > 0),
        price      bigint not null default 0 check (price >= 0),
        total      bigint not null default 0 check (total >= 0)
    );

    -- 11. commission_dues (Commission suppliers only)
    create table public.commission_dues (
        id                uuid primary key default gen_random_uuid(),
        tenant_id         uuid not null references public.tenants(id) on delete cascade,
        supplier_id       uuid not null references public.suppliers(id),
        invoice_id        uuid not null references public.invoices(id),
        product_id        uuid not null references public.products(id),
        sale_total        bigint not null default 0 check (sale_total >= 0),
        commission_rate   numeric(5, 2) not null check (commission_rate between 0 and 100),
        commission_amount bigint not null default 0 check (commission_amount >= 0),
        supplier_due      bigint not null default 0 check (supplier_due >= 0),
        paid              bigint not null default 0 check (paid >= 0),
        remaining         bigint not null default 0 check (remaining >= 0),
        date              date not null default current_date,
        created_at        timestamptz not null default now()
    );

    -- 12. payments
    create table public.payments (
        id         uuid primary key default gen_random_uuid(),
        tenant_id  uuid not null references public.tenants(id) on delete cascade,
        invoice_id uuid references public.invoices(id),
        type       text not null check (type in ('customer', 'supplier')),
        party_id   uuid not null,
        amount     bigint not null check (amount > 0),
        date       date not null default current_date,
        method     text,
        note       text,
        created_at timestamptz not null default now()
    );

    -- 13. expenses
    create table public.expenses (
        id          uuid primary key default gen_random_uuid(),
        tenant_id   uuid not null references public.tenants(id) on delete cascade,
        category    text not null,
        description text,
        amount      bigint not null check (amount > 0),
        date        date not null default current_date,
        created_at  timestamptz not null default now()
    );

    -- 14. employees
    create table public.employees (
        id          uuid primary key default gen_random_uuid(),
        tenant_id   uuid not null references public.tenants(id) on delete cascade,
        name        text not null,
        job_title   text,
        phone       text,
        base_salary bigint not null default 0 check (base_salary >= 0),
        created_at  timestamptz not null default now()
    );

    -- 15. salaries
    create table public.salaries (
        id          uuid primary key default gen_random_uuid(),
        tenant_id   uuid not null references public.tenants(id) on delete cascade,
        employee_id uuid not null references public.employees(id),
        month       date not null,
        base_salary bigint not null default 0 check (base_salary >= 0),
        paid        bigint not null default 0 check (paid >= 0),
        date        date not null default current_date,
        created_at  timestamptz not null default now()
    );

    -- 16. employee_movements (advance / product / other / bonus / allowance)
    create table public.employee_movements (
        id          uuid primary key default gen_random_uuid(),
        tenant_id   uuid not null references public.tenants(id) on delete cascade,
        employee_id uuid not null references public.employees(id),
        month       date not null,
        date        date not null default current_date,
        direction   text not null check (direction in ('in', 'out')),
        category    text not null check (category in ('advance', 'product', 'other', 'bonus', 'allowance')),
        amount      bigint not null default 0 check (amount >= 0),
        description text,
        product_id  uuid references public.products(id),
        qty         numeric(15, 3) check (qty is null or qty > 0),
        created_at  timestamptz not null default now()
    );

    -- 17. stock_moves
    create table public.stock_moves (
        id          uuid primary key default gen_random_uuid(),
        tenant_id   uuid not null references public.tenants(id) on delete cascade,
        product_id  uuid not null references public.products(id),
        type        text not null check (type in ('in', 'out', 'adjust')),
        qty         numeric(15, 3) not null check (qty > 0),
        ref         text,
        reason      text,
        date        date not null default current_date,
        employee_id uuid references public.employees(id),
        created_at  timestamptz not null default now()
    );

    -- Indexes: tenant isolation on every tenant-owned table + practical query paths.
    create index idx_users_tenant_id          on public.users (tenant_id);
    create index idx_users_auth_user_id       on public.users (auth_user_id);
    create index idx_accounts_tenant_id       on public.accounts (tenant_id);
    create index idx_accounts_parent_id       on public.accounts (parent_id);
    create index idx_journal_entries_tenant   on public.journal_entries (tenant_id, date);
    create index idx_journal_entries_source   on public.journal_entries (tenant_id, source_id);
    create index idx_journal_lines_entry      on public.journal_entry_lines (entry_id);
    create index idx_customers_tenant_id      on public.customers (tenant_id);
    create index idx_suppliers_tenant_id      on public.suppliers (tenant_id);
    create index idx_products_tenant_id       on public.products (tenant_id);
    create index idx_products_supplier        on public.products (supplier_id);
    create index idx_invoices_tenant_type     on public.invoices (tenant_id, type, date);
    create index idx_invoices_tenant_party    on public.invoices (tenant_id, party_id);
    create index idx_invoice_items_invoice    on public.invoice_items (invoice_id);
    create index idx_invoice_items_product    on public.invoice_items (product_id);
    create index idx_commission_dues_tenant   on public.commission_dues (tenant_id, supplier_id, paid);
    create index idx_payments_tenant          on public.payments (tenant_id, party_id);
    create index idx_payments_invoice         on public.payments (invoice_id);
    create index idx_expenses_tenant          on public.expenses (tenant_id, date);
    create index idx_employees_tenant_id      on public.employees (tenant_id);
    create index idx_salaries_tenant          on public.salaries (tenant_id, employee_id, month);
    create index idx_employee_movements_tenant on public.employee_movements (tenant_id, employee_id, month);
    create index idx_stock_moves_tenant       on public.stock_moves (tenant_id, product_id);

    commit;

-- ======================================================
-- FILE: 0003_auth_helpers.sql
-- ======================================================
-- 0003_auth_helpers.sql
-- Tenant/auth helpers used by every RLS policy and by the Flutter app.
-- get_my_tenant_id() is SECURITY DEFINER so policies can read the caller's
-- tenant even when the caller has no SELECT on `users`. It is STABLE + strict
-- search_path to prevent hijacking.
-- get_my_user() / get_my_role() are SECURITY INVOKER (subject to RLS).

begin;

create or replace function public.get_my_tenant_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
    select tenant_id
    from public.users
    where auth_user_id = auth.uid()
    limit 1;
$$;

create or replace function public.get_my_user()
returns public.users
language sql
stable
security invoker
set search_path = public
as $$
    select *
    from public.users
    where auth_user_id = auth.uid()
    limit 1;
$$;

create or replace function public.get_my_role()
returns text
language sql
stable
security invoker
set search_path = public
as $$
    select role
    from public.get_my_user();
$$;

-- Functions are PUBLIC-executable by default; restrict to authenticated users.
revoke all on function public.get_my_tenant_id() from public;
revoke all on function public.get_my_user()     from public;
revoke all on function public.get_my_role()     from public;

grant execute on function public.get_my_tenant_id() to authenticated;
grant execute on function public.get_my_user()     to authenticated;
grant execute on function public.get_my_role()     to authenticated;

commit;

-- ======================================================
-- FILE: 0004_rls_grants.sql
-- ======================================================
-- 0004_rls_grants.sql
-- Row Level Security + grants. Primary isolation layer (PROJECT_SPEC §12).
--   * Master tables  (customers, suppliers, products, expenses): full CRUD via RLS.
--   * Financial tables: SELECT only — writes happen exclusively through RPC functions
--     (invoices, invoice_items, journal_entries, journal_entry_lines, payments,
--      commission_dues, salaries, employee_movements, stock_moves).
--   * tables with no tenant_id (invoice_items, journal_entry_lines) are scoped
--     through their parent via EXISTS subquery.
--   * processed_requests is handled in 0011_idempotency.sql.

begin;

-- =====================================================================
-- Master tables — authenticated callers manage their own tenant's rows
-- =====================================================================

alter table public.customers enable row level security;
create policy tenant_isolation on public.customers
    for all
    using (tenant_id = public.get_my_tenant_id())
    with check (tenant_id = public.get_my_tenant_id());

alter table public.suppliers enable row level security;
create policy tenant_isolation on public.suppliers
    for all
    using (tenant_id = public.get_my_tenant_id())
    with check (tenant_id = public.get_my_tenant_id());

alter table public.products enable row level security;
create policy tenant_isolation on public.products
    for all
    using (tenant_id = public.get_my_tenant_id())
    with check (tenant_id = public.get_my_tenant_id());

alter table public.expenses enable row level security;
create policy tenant_isolation on public.expenses
    for all
    using (tenant_id = public.get_my_tenant_id())
    with check (tenant_id = public.get_my_tenant_id());

-- =====================================================================
-- Financial tables — READ ONLY via RLS
-- =====================================================================

alter table public.invoices enable row level security;
create policy tenant_isolation_select on public.invoices
    for select
    using (tenant_id = public.get_my_tenant_id());

alter table public.invoice_items enable row level security;
create policy tenant_isolation_select on public.invoice_items
    for select
    using (
        exists (
            select 1 from public.invoices i
            where i.id = invoice_id
              and i.tenant_id = public.get_my_tenant_id()
        )
    );

alter table public.journal_entries enable row level security;
create policy tenant_isolation_select on public.journal_entries
    for select
    using (tenant_id = public.get_my_tenant_id());

alter table public.journal_entry_lines enable row level security;
create policy tenant_isolation_select on public.journal_entry_lines
    for select
    using (
        exists (
            select 1 from public.journal_entries je
            where je.id = entry_id
              and je.tenant_id = public.get_my_tenant_id()
        )
    );

alter table public.payments enable row level security;
create policy tenant_isolation_select on public.payments
    for select
    using (tenant_id = public.get_my_tenant_id());

alter table public.commission_dues enable row level security;
create policy tenant_isolation_select on public.commission_dues
    for select
    using (tenant_id = public.get_my_tenant_id());

alter table public.salaries enable row level security;
create policy tenant_isolation_select on public.salaries
    for select
    using (tenant_id = public.get_my_tenant_id());

alter table public.employee_movements enable row level security;
create policy tenant_isolation_select on public.employee_movements
    for select
    using (tenant_id = public.get_my_tenant_id());

alter table public.stock_moves enable row level security;
create policy tenant_isolation_select on public.stock_moves
    for select
    using (tenant_id = public.get_my_tenant_id());

-- =====================================================================
-- users / accounts / tenants
-- =====================================================================

alter table public.users enable row level security;
create policy own_or_same_tenant on public.users
    for select
    using (auth_user_id = auth.uid() or tenant_id = public.get_my_tenant_id());

alter table public.accounts enable row level security;
create policy tenant_isolation_select on public.accounts
    for select
    using (tenant_id = public.get_my_tenant_id());

alter table public.tenants enable row level security;
create policy tenant_isolation_select on public.tenants
    for select
    using (id = public.get_my_tenant_id());

-- =====================================================================
-- Grants
-- =====================================================================

-- Full CRUD on master tables for authenticated users.
grant select, insert, update, delete on public.customers to authenticated;
grant select, insert, update, delete on public.suppliers to authenticated;
grant select, insert, update, delete on public.products   to authenticated;
grant select, insert, update, delete on public.expenses   to authenticated;

-- Read-only on financial tables.
grant select on public.invoices           to authenticated;
grant select on public.invoice_items      to authenticated;
grant select on public.journal_entries    to authenticated;
grant select on public.journal_entry_lines to authenticated;
grant select on public.payments           to authenticated;
grant select on public.commission_dues    to authenticated;
grant select on public.salaries           to authenticated;
grant select on public.employee_movements to authenticated;
grant select on public.stock_moves        to authenticated;

-- Read on the auxiliary tables.
grant select on public.users    to authenticated;
grant select on public.accounts to authenticated;
grant select on public.tenants  to authenticated;

-- Explicitly no INSERT/UPDATE/DELETE for authenticated on financial tables.
revoke insert, update, delete on public.invoices           from authenticated;
revoke insert, update, delete on public.invoice_items      from authenticated;
revoke insert, update, delete on public.journal_entries    from authenticated;
revoke insert, update, delete on public.journal_entry_lines from authenticated;
revoke insert, update, delete on public.payments           from authenticated;
revoke insert, update, delete on public.commission_dues    from authenticated;
revoke insert, update, delete on public.salaries           from authenticated;
revoke insert, update, delete on public.employee_movements from authenticated;
revoke insert, update, delete on public.stock_moves        from authenticated;

-- Anonymous role gets nothing.
revoke all on public.customers from anon;
revoke all on public.suppliers from anon;
revoke all on public.products   from anon;
revoke all on public.expenses   from anon;
revoke all on public.invoices           from anon;
revoke all on public.invoice_items      from anon;
revoke all on public.journal_entries    from anon;
revoke all on public.journal_entry_lines from anon;
revoke all on public.payments           from anon;
revoke all on public.commission_dues    from anon;
revoke all on public.salaries           from anon;
revoke all on public.employee_movements from anon;
revoke all on public.stock_moves        from anon;
revoke all on public.users    from anon;
revoke all on public.accounts from anon;
revoke all on public.tenants  from anon;

commit;

-- ======================================================
-- FILE: 0005_register_tenant.sql
-- ======================================================
-- 0005_register_tenant.sql
-- Bootstrap functions:
--   * seed_chart_of_accounts(p_tenant_id)       — the 14 default accounts (PROJECT_SPEC §3)
--   * register_tenant(p_name, p_owner_name)     — create business + link first admin user
-- Both are SECURITY DEFINER (they must act before/for a user who has no tenant yet)
-- but register_tenant re-validates auth.uid() and rejects users that already
-- belong to a tenant. Owner identity comes from the session (confirmed decision).

begin;

create or replace function public.seed_chart_of_accounts(p_tenant_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
    insert into public.accounts (tenant_id, code, name, type) values
        (p_tenant_id, '1010', 'النقدية',           'asset'),
        (p_tenant_id, '1015', 'البنك',              'asset'),
        (p_tenant_id, '1020', 'الذمم المدينة',      'asset'),
        (p_tenant_id, '1030', 'المخزون',            'asset'),
        (p_tenant_id, '1040', 'الأصول الثابتة',     'asset'),
        (p_tenant_id, '2010', 'الذمم الدائنة',      'liability'),
        (p_tenant_id, '2030', 'رواتب مستحقة',       'liability'),
        (p_tenant_id, '3010', 'رأس المال',          'equity'),
        (p_tenant_id, '3020', 'الأرباح المحتجزة',   'equity'),
        (p_tenant_id, '4010', 'إيرادات المبيعات',   'revenue'),
        (p_tenant_id, '4020', 'مردودات المبيعات',   'revenue'),
        (p_tenant_id, '5010', 'تكلفة البضاعة المباعة', 'expense'),
        (p_tenant_id, '5020', 'المصروفات التشغيلية',  'expense'),
        (p_tenant_id, '5030', 'الأجور والرواتب',      'expense');
end;
$$;

create or replace function public.register_tenant(p_name text, p_owner_name text default null)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
    v_uid         uuid := auth.uid();
    v_tenant_id   uuid;
    v_owner_name  text;
begin
    if v_uid is null then
        raise exception 'يجب تسجيل الدخول أولاً قبل إنشاء المؤسسة';
    end if;

    if exists (select 1 from public.users where auth_user_id = v_uid) then
        raise exception 'هذا المستخدم مسجل بالفعل في مؤسسة';
    end if;

    v_owner_name := coalesce(
        nullif(trim(p_owner_name), ''),
        (select raw_user_meta_data ->> 'full_name' from auth.users where id = v_uid)
    );
    v_owner_name := coalesce(nullif(trim(v_owner_name), ''), 'مدير');

    insert into public.tenants (name)
    values (p_name)
    returning id into v_tenant_id;

    insert into public.users (tenant_id, auth_user_id, name, role)
    values (v_tenant_id, v_uid, v_owner_name, 'admin');

    perform public.seed_chart_of_accounts(v_tenant_id);

    return v_tenant_id;
end;
$$;

revoke all on function public.seed_chart_of_accounts(uuid) from public;
revoke all on function public.register_tenant(text, text)  from public;

grant execute on function public.seed_chart_of_accounts(uuid) to authenticated;
grant execute on function public.register_tenant(text, text)  to authenticated;

commit;

-- ======================================================
-- FILE: 0006_invoice_counters.sql
-- ======================================================
-- 0006_invoice_counters.sql
-- Per-tenant official number counters (PROJECT_SPEC §11: "Official sequential
-- invoice numbers are generated by the database only, inside the RPC").
-- Counters are incremented with a row lock (UPDATE ... RETURNING) so two
-- concurrent transactions can never produce the same number.
-- Number formats: sales  S-000001, purchases P-000001, journal entry_no bigint.

begin;

create table public.invoice_counters (
    tenant_id   uuid primary key references public.tenants(id) on delete cascade,
    sale_no     bigint not null default 0 check (sale_no >= 0),
    purchase_no bigint not null default 0 check (purchase_no >= 0),
    journal_no  bigint not null default 0 check (journal_no >= 0)
);

alter table public.invoice_counters enable row level security;

create policy tenant_isolation on public.invoice_counters
    for all
    using (tenant_id = public.get_my_tenant_id())
    with check (tenant_id = public.get_my_tenant_id());

grant select, insert, update on public.invoice_counters to authenticated;
revoke all on public.invoice_counters from anon;

-- Ensures a counter row exists for the tenant, then returns the next official
-- invoice number for the given type ('sale'/'purchase').
create or replace function public.next_invoice_no(p_type text)
returns text
language plpgsql
security invoker
set search_path = public
as $$
declare
    v_tenant uuid := public.get_my_tenant_id();
    v_next   bigint;
begin
    if p_type not in ('sale', 'purchase') then
        raise exception 'نوع غير صحيح للرقم التسلسلي';
    end if;

    if v_tenant is null then
        raise exception 'يجب تسجيل الدخول أولاً';
    end if;

    insert into public.invoice_counters (tenant_id)
    values (v_tenant)
    on conflict (tenant_id) do nothing;

    if p_type = 'sale' then
        update public.invoice_counters
           set sale_no = sale_no + 1
         where tenant_id = v_tenant
        returning sale_no into v_next;
    else
        update public.invoice_counters
           set purchase_no = purchase_no + 1
         where tenant_id = v_tenant
        returning purchase_no into v_next;
    end if;

    return case p_type
        when 'sale'     then 'S-' || lpad(v_next::text, 6, '0')
        when 'purchase' then 'P-' || lpad(v_next::text, 6, '0')
    end;
end;
$$;

-- Per-tenant journal entry number.
create or replace function public.next_journal_no()
returns bigint
language plpgsql
security invoker
set search_path = public
as $$
declare
    v_tenant uuid := public.get_my_tenant_id();
    v_next   bigint;
begin
    if v_tenant is null then
        raise exception 'يجب تسجيل الدخول أولاً';
    end if;

    insert into public.invoice_counters (tenant_id)
    values (v_tenant)
    on conflict (tenant_id) do nothing;

    update public.invoice_counters
       set journal_no = journal_no + 1
     where tenant_id = v_tenant
    returning journal_no into v_next;

    return v_next;
end;
$$;

revoke all on function public.next_invoice_no(text) from public;
revoke all on function public.next_journal_no()     from public;

grant execute on function public.next_invoice_no(text) to authenticated;
grant execute on function public.next_journal_no()     to authenticated;

commit;

-- ======================================================
-- FILE: 0007_rpc_sales.sql
-- ======================================================
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

-- ======================================================
-- FILE: 0008_rpc_purchases.sql
-- ======================================================
-- 0008_rpc_purchases.sql
-- create_purchase_invoice — direct vs consignment + inline new-product lines
-- (PROJECT_SPEC §6).
--   * Direct supplier   -> ownership = owned,       real debt booked: DR Inventory
--                         (1030), CR cash/bank + Accounts Payable (2010).
--   * Commission supplier -> ownership = consignment, stock receipt ONLY — no
--                         journal entry, no debt. Paying one is forbidden.
--   * Each line may reference an existing product_id OR carry a new_product
--     payload (created in the same transaction, linked to the supplier).
-- Same transaction / idempotent / INVOKER pattern as create_sale_invoice.

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

-- ======================================================
-- FILE: 0009_rpc_payments.sql
-- ======================================================
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

-- ======================================================
-- FILE: 0010_rpc_employees.sql
-- ======================================================
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

-- ======================================================
-- FILE: 0011_idempotency.sql
-- ======================================================
done

-- ======================================================
-- FILE: 0012_storage.sql
-- ======================================================
-- 0012_storage.sql
-- Tenant-isolated storage bucket for generated documents (PDF statements,
-- invoices). Path convention: {tenant_id}/{folder}/{filename} — the first
-- path segment MUST be the owning tenant's UUID, which is what the RLS
-- policies assert.
-- The statement-pdf Edge Function (M3) is the writer; the Flutter app reads
-- through the same tenant-scoped policies.

begin;

insert into storage.buckets (id, name, public)
values ('pdfs', 'pdfs', false)
on conflict (id) do nothing;

-- storage.objects RLS is already enabled by Supabase by default; do NOT
-- ALTER storage tables from the editor (42501 — they belong to
-- supabase_storage_admin). Just add our bucket-scoped policies.

-- Tenant can only see their own folder.
create policy tenant_isolated_pdf_select on storage.objects
    for select
    using (
        bucket_id = 'pdfs'
        and (storage.foldername(name))[1] = (select public.get_my_tenant_id()::text)
    );

-- Tenant can only write into their own folder.
create policy tenant_isolated_pdf_insert on storage.objects
    for insert
    with check (
        bucket_id = 'pdfs'
        and (storage.foldername(name))[1] = (select public.get_my_tenant_id()::text)
    );

-- Tenant can delete only from their own folder.
create policy tenant_isolated_pdf_delete on storage.objects
    for delete
    using (
        bucket_id = 'pdfs'
        and (storage.foldername(name))[1] = (select public.get_my_tenant_id()::text)
    );

commit;

-- ======================================================
-- FILE: 0013_reminder.sql
-- ======================================================
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

-- ======================================================
-- FILE: 0014_stock_adjust.sql
-- ======================================================
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

-- ======================================================
-- FILE: 0015_get_party_statement.sql
-- ======================================================
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

-- ======================================================
-- FILE: 0016_employees_rls.sql
-- ======================================================
-- 0016_employees_rls.sql
-- employees existed since 0002 but was never covered by 0004_rls_grants.sql
-- (which handles customers/suppliers/products/expenses only): RLS was disabled and
-- no table grants existed, so `authenticated` could neither CRUD employees nor run
-- the salary RPCs (all `security invoker`) — those select from public.employees at
-- runtime and fail with "permission denied for table employees".
-- Fix: promote employees to the master-table pattern (full tenant-scoped CRUD via RLS).

begin;

alter table public.employees enable row level security;

create policy tenant_isolation on public.employees
    for all
    using (tenant_id = public.get_my_tenant_id())
    with check (tenant_id = public.get_my_tenant_id());

grant select, insert, update, delete on public.employees to authenticated;
revoke all on public.employees from anon;

commit;

-- ======================================================
-- FILE: 0017_master_tables_set_tenant.sql
-- ======================================================
-- 0017_master_tables_set_tenant.sql
-- Fix: direct `.from('table')` inserts into the master tables (customers,
-- suppliers, products, expenses, employees) by PostgREST never carry a
-- tenant_id, and nothing stamped one — so the RLS policy
-- `with check (tenant_id = public.get_my_tenant_id())` evaluated
-- `NULL = <tenant>` → false → PostgREST 403 "new row violates row-level
-- security policy". The app and the regression scripts both omit tenant_id.
-- Fix: a BEFORE INSERT trigger stamps tenant_id from the caller's JWT
-- (via the SECURITY DEFINER helper get_my_tenant_id, 0003) BEFORE the RLS
-- with-check runs. The `if null` guard keeps security-definer RPC paths
-- (register_tenant, invoices, salary RPCs ... all pass explicit tenant_id)
-- untouched.

begin;

create or replace function public.set_master_tenant()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
    if new.tenant_id is null then
        new.tenant_id := public.get_my_tenant_id();
    end if;
    return new;
end;
$$;

drop trigger if exists trg_set_tenant on public.employees;
create trigger trg_set_tenant
    before insert on public.employees
    for each row execute function public.set_master_tenant();

drop trigger if exists trg_set_tenant on public.customers;
create trigger trg_set_tenant
    before insert on public.customers
    for each row execute function public.set_master_tenant();

drop trigger if exists trg_set_tenant on public.suppliers;
create trigger trg_set_tenant
    before insert on public.suppliers
    for each row execute function public.set_master_tenant();

drop trigger if exists trg_set_tenant on public.products;
create trigger trg_set_tenant
    before insert on public.products
    for each row execute function public.set_master_tenant();

drop trigger if exists trg_set_tenant on public.expenses;
create trigger trg_set_tenant
    before insert on public.expenses
    for each row execute function public.set_master_tenant();

commit;

-- ======================================================
-- FILE: 0018_purchase_links_existing_product.sql
-- ======================================================
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

-- ======================================================
-- FILE: 0019_reports.sql
-- ======================================================
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

-- ======================================================
-- FILE: 0020_reminders_to_all.sql
-- ======================================================
-- 0020_reminders_to_all.sql
-- M8: app-callable "remind everyone overdue" for the reminders settings screen.
--
--   * send_reminders_to_all(): SECURITY INVOKER, tenant-scoped mirror of the
--     daily send_due_reminders() (migration 0013) - same overdue scan, template
--     and webhook path via _fire_reminder - but callable by the app's
--     "remind all" button. send_due_reminders() stays cron-only (revoked from
--     authenticated) and is NOT touched.
--   * Manual override semantics: reminder_enabled only gates the daily cron
--     job; a manual "remind all" fires regardless. A missing webhook still
--     fails loudly (matches send_reminder_now).
--   * Same-day dedupe is inherited from _fire_reminder/reminder_log (each
--     customer is reminded at most once per day), so re-running the button
--     on the same day is a no-op for customers already logged today.

create or replace function public.send_reminders_to_all()
returns jsonb
language plpgsql
security invoker
set search_path = public, net
as $$
declare
    v_tenant   uuid := public.get_my_tenant_id();
    v_set      record;
    v_company  text;
    v_cutoff   date;
    v_sent     integer := 0;
    v_log_id   uuid;
    c          record;
begin
    if v_tenant is null then
        raise exception 'يجب تسجيل الدخول أولاً';
    end if;

    -- Settings row is seeded per tenant; ensure it exists like send_reminder_now.
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

    v_cutoff := current_date - v_set.reminder_days_threshold;

    for c in
        select cu.id as customer_id, cu.name as customer_name, cu.phone,
               sum(i.remaining) as amount
        from public.invoices i
        join public.customers cu on cu.id = i.party_id and cu.tenant_id = i.tenant_id
        where i.tenant_id = v_tenant
        and i.type = 'sale'
        and i.ownership = 'owned'
        and i.remaining > 0
        and i.date <= v_cutoff
        and cu.phone is not null and cu.phone <> ''
        group by cu.id, cu.name, cu.phone
        having not exists (
            select 1 from public.reminder_log lg
            where lg.tenant_id = v_tenant
            and lg.customer_id = cu.id
            and lg.created_at::date = current_date
        )
    loop
        v_log_id := public._fire_reminder(
            v_tenant, c.customer_id, c.customer_name, c.phone,
            c.amount, v_set.reminder_webhook_url, v_set.reminder_message, v_company
        );
        v_sent := v_sent + 1;
    end loop;

    return jsonb_build_object('sent', v_sent);
end;
$$;

revoke all on function public.send_reminders_to_all() from public;
grant execute on function public.send_reminders_to_all() to authenticated;

-- ======================================================
-- FILE: 0021_user_tenants.sql
-- ======================================================
-- 0021_user_tenants.sql
-- Multi-business support: many-to-many user ↔ tenant with current tenant pointer

begin;

-- 1. Join table for many-to-many user ↔ tenant
create table public.user_tenants (
    user_id   uuid not null references public.users(id) on delete cascade,
    tenant_id uuid not null references public.tenants(id) on delete cascade,
    role      text not null check (role in ('admin', 'accountant', 'sales')),
    primary key (user_id, tenant_id)
);

-- 2. Migrate existing single-tenant users
insert into public.user_tenants (user_id, tenant_id, role)
select id, tenant_id, role
from public.users
where tenant_id is not null;

-- 3. Current tenant pointer on users (for session/default)
alter table public.users add column current_tenant_id uuid references public.tenants(id);

-- 4. Backfill current_tenant_id from existing tenant_id
update public.users set current_tenant_id = tenant_id where tenant_id is not null;

-- 5. Update get_my_tenant_id() to read current_tenant_id
create or replace function public.get_my_tenant_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
    select current_tenant_id
    from public.users
    where auth_user_id = auth.uid()
    limit 1;
$$;

-- 6. Switch-tenant RPC (SECURITY DEFINER, validates membership)
create or replace function public.switch_tenant(p_tenant_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    v_user_id uuid := (select id from public.users where auth_user_id = auth.uid());
begin
    if not exists (
        select 1 from public.user_tenants
        where user_id = v_user_id and tenant_id = p_tenant_id
    ) then
        raise exception 'User does not have access to tenant %', p_tenant_id;
    end if;
    
    update public.users
    set current_tenant_id = p_tenant_id
    where id = v_user_id;
end;
$$;

grant execute on function public.switch_tenant(uuid) to authenticated;

commit;

-- END OF PRODUCTION SCHEMA