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