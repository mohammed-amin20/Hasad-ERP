# M1 Test Scenarios

How to verify Batch 1 after applying the migrations in the dashboard SQL Editor.

**Apply order (SQL Editor), all 13:**
`0001_extensions.sql` → `0002_schema.sql` → `0003_auth_helpers.sql` → `0004_rls_grants.sql` → `0005_register_tenant.sql` → `0006_invoice_counters.sql` → `0007_rpc_sales.sql` → `0008_rpc_purchases.sql` → `0009_rpc_payments.sql` → `0010_rpc_employees.sql` → `0011_idempotency.sql` → `0012_storage.sql` → `0013_reminder.sql`

> **PowerShell 5.1 gotchas (learned live):**
> - PS unwraps a single-row JSON array into a plain object → `$x[0]` is `null`. Wrap every
>   list-returning call: `$cus = @(Invoke-RestMethod ...)`.
> - `PATCH` on any table **requires a WHERE clause** (`?tenant_id=eq.<id>`) or PostgREST
>   returns `21000 UPDATE requires a WHERE clause`.
> - `register_tenant` is one-shot: re-running on an existing tenant returns
>   `400 "هذا المستخدم مسجل بالفعل في مؤسسة"`. Use a **fresh auth user** per regression run.
> - The versioned scripts in `supabase/tests/` (`payment_final.ps1`,
>   `reminder_final_v2.ps1`, `idempotency_fixed.ps1`) already handle all of this.

---

## Part A — Structural checks (SQL Editor, runs as postgres)

Run each as its own query after the migrations are applied.

```sql
-- 1. Extensions are present
select extname from pg_extension where extname in ('pgcrypto', 'pg_cron', 'pg_net') order by 1;
-- expect: pg_cron, pg_net, pgcrypto

-- 2. All 17 tables exist
select table_name from information_schema.tables
where table_schema = 'public' and table_type = 'BASE TABLE'
  and table_name not like 'processed_requests'
order by table_name;

-- 3. RLS is enabled on every table
select tablename, rowsecurity
from pg_tables
where schemaname = 'public'
order by tablename;
-- expect rowsecurity = true on all 17 + processed_requests

-- 4. Chart-of-accounts seed function exists and counts to 14 when run
select public.seed_chart_of_accounts('00000000-0000-0000-0000-000000000000');

-- 5. Helper functions
select public.get_my_tenant_id(), public.get_my_role(); -- expect null / null when run as postgres
```

> **Caution:** item 4 above writes into a throwaway tenant so the schema-level seed
> path is exercised. It is safe to run as postgres. The real registration path is
> tested in Part B (as an authenticated user).

Clean up the throwaway tenant afterwards if you used item 4:

```sql
delete from public.tenants where id = '00000000-0000-0000-0000-000000000000';
```

---

## Part B — Functional checks (REST, as a real authenticated user)

RLS/RPC behavior cannot be truthfully tested as `postgres` (superuser bypasses RLS).
Use the REST API with a real signed-in user JWT.

### Step 1 — Create a test auth user
Dashboard → **Authentication → Users → Add user**.
Create two users for the two-tenant isolation test (e.g. `owner1@test.local` and `owner2@test.local`).

### Step 2 — Get a JWT for a user
```powershell
$body = '{"email":"owner1@test.local","password":"<password>"}'
Invoke-RestMethod -Method Post `
  -Uri "https://sxasnunzspkuwbxiddqd.supabase.co/auth/v1/token?grant_type=password" `
  -Headers @{ apikey = "<ANON_KEY>" ; "Content-Type" = "application/json" } `
  -Body $body
# copy the returned .access_token
```

### Step 3 — Register the tenant (as that user)
```powershell
$headers = @{
  apikey = "<ANON_KEY>"
  Authorization = "Bearer <access_token>"
  "Content-Type" = "application/json"
}
Invoke-RestMethod -Method Post `
  -Uri "https://sxasnunzspkuwbxiddqd.supabase.co/rest/v1/rpc/register_tenant" `
  -Headers $headers `
  -Body '{"p_name":"شركة الاختبار الأولى","p_owner_name":"محمد"}'
# expect the new tenant uuid
```

### Step 4 — Verify the tenant was seeded
```powershell
Invoke-RestMethod -Method Get `
  -Uri "https://sxasnunzspkuwbxiddqd.supabase.co/rest/v1/tenants" `
  -Headers $headers # returns only this tenant

Invoke-RestMethod -Method Get `
  -Uri "https://sxasnunzspkuwbxiddqd.supabase.co/rest/v1/accounts?select=code,name,type&order=code" `
  -Headers $headers # expect exactly the 14 accounts
```

### Step 5 — The critical isolation test (M1 exit criteria)
Repeat Steps 2–3 for `owner2@test.local` (second tenant). Then:

```powershell
# Still using owner2's token:
Invoke-RestMethod -Method Get `
  -Uri "https://sxasnunzspkuwbxiddqd.supabase.co/rest/v1/customers" `
  -Headers $headers      # 0 rows — and critically:
Invoke-RestMethod -Method Get `
  -Uri "https://sxasnunzspkuwbxiddqd.supabase.co/rest/v1/tenants" `
  -Headers $headers      # only owner2's tenant, NEVER owner1's
```

Also verify a user cannot double-register:

```powershell
Invoke-RestMethod -Method Post `
  -Uri "https://sxasnunzspkuwbxiddqd.supabase.co/rest/v1/rpc/register_tenant" `
  -Headers $headers `
  -Body '{"p_name":"شركة مكررة"}'
# expect an error: "هذا المستخدم مسجل بالفعل في مؤسسة"
```

---

## Pass criteria for Batch 1
- [ ] All 6 migration scripts applied without error.
- [ ] Extensions + 17 tables + RLS verified (Part A).
- [ ] owner1 registers tenant → 14 accounts seeded, own tenant visible.
- [ ] owner2 cannot see owner1's data (isolation), and duplicate registration is rejected.

---

# Batch 2 — Sales invoice RPC

**Apply order (SQL Editor):** `0006_invoice_counters.sql` → `0007_rpc_sales.sql`

### Structural checks (SQL Editor, as postgres)

```sql
-- counters table + RLS
select schemaname, tablename, rowsecurity from pg_tables
where schemaname='public' and tablename in ('invoice_counters','invoices');

-- 3 new functions exist
select proname from pg_proc
where proname in ('next_invoice_no','next_journal_no','create_sale_invoice') order by 1;
```

### Functional tests (PowerShell, owner1)

The block below assumes you still have the Batch 1 session ($url/$key/$h1/$h2) or re-sets them.

```powershell
# ---- 0. re-establish session if needed ---------------------------------
$url = "https://sxasnunzspkuwbxiddqd.supabase.co"
$key = "<ANON_KEY>"
$p1 = "owner1-pass-here"
$headers = @{ apikey = $key; "Content-Type" = "application/json" }
$t1 = (Invoke-RestMethod -Method Post -Uri "$url/auth/v1/token?grant_type=password" -Headers $headers -Body (@{email="owner1@test.local"; password=$p1} | ConvertTo-Json)).access_token
$h1 = @{ apikey = $key; Authorization = "Bearer $t1"; "Content-Type" = "application/json" }

# ---- 1a. customer ------------------------------------------------------
$cust = (Invoke-RestMethod -Method Post -Uri "$url/rest/v1/customers" -Headers $h1 `
  -Body '{"name":"زبون تجريبي"}')
"$($cust | Out-String | ForEach-Object { $_ })"

# ---- 1b. normal product (qty 100, sale 50.00) ----------------------------
$prod = (Invoke-RestMethod -Method Post -Uri "$url/rest/v1/products" -Headers $h1 `
  -Body '{"name":"منتج تجريبي","unit":"حبة","unit_type":"count","sale_price":5000,"purchase_price":3000,"qty":100}')
$prodLet = (Invoke-RestMethod -Method Post -Uri "$url/rest/v1/products" -Headers $h1 `
  -Body '{"name":"منتج طماطم","unit":"كغ","unit_type":"weight","sale_price":3000,"purchase_price":1500,"qty":50}')

# ---- 1c. commission supplier (20%) + linked commission product -----------
$sup = (Invoke-RestMethod -Method Post -Uri "$url/rest/v1/suppliers" -Headers $h1 `
  -Body '{"name":"مورد بالعمولة","deal_type":"commission","commission_rate":20}')
$prodC = (Invoke-RestMethod -Method Post -Uri "$url/rest/v1/products" -Headers $h1 `
  -Body ("{`"name`":`"منتج عمولة`",`"unit`":`"حبة`",`"unit_type`":`"count`",`"sale_price`":8000,`"purchase_price`":0,`"qty`":50,`"supplier_id`":`"" + $sup[0].id + "`"}"))

# ---- 2. invoice #1: pure credit sale, 10 units of the normal product -----
$r1 = (Invoke-RestMethod -Method Post -Uri "$url/rest/v1/rpc/create_sale_invoice" -Headers $h1 `
  -Body (@{ request_id=[guid]::NewGuid().ToString(); customer_id=$cust[0].id; invoice_date="2026-09-06";
          items=@(@{product_id=$prod[0].id; qty=10; price=5000}) } | ConvertTo-Json -Depth 5 -Compress))
$r1 | ConvertTo-Json -Compress
# expect: no = S-000001, total = 50000, paid = 0, remaining = 50000, status = unpaid, entry_no = 1

# ---- 2b. its journal is balanced: AR 50000 debit / Sales 50000 credit -----
"JOURNAL ROWS -> " + ((Invoke-RestMethod -Method Get -Uri "$url/rest/v1/journal_entries?select=entry_no,date,source_id" -Headers $h1) | ConvertTo-Json -Compress)
# verify lines in the SQL editor or via: .../rest/v1/journal_entry_lines

# ---- 2c. stock was deducted: 100 - 10 = 90 --------------------------------
"STOCK AFTER #1 -> " + ((Invoke-RestMethod -Method Get -Uri "$url/rest/v1/products?select=name,qty&id=eq.$($prod[0].id)" -Headers $h1) | ConvertTo-Json -Compress)

# ---- 3. invoice #2: partial payment (25.00 cash on a 20-unit sale) --------
$r2 = (Invoke-RestMethod -Method Post -Uri "$url/rest/v1/rpc/create_sale_invoice" -Headers $h1 `
  -Body (@{ request_id=[guid]::NewGuid().ToString(); customer_id=$cust[0].id; invoice_date="2026-09-06";
          items=@(@{product_id=$prodLet[0].id; qty=5; price=3000});
          paid=2500; payment_method="cash" } | ConvertTo-Json -Depth 5 -Compress))
$r2 | ConvertTo-Json -Compress
# expect: total 15000, paid 2500, remaining 12500, status partial
# journal: cash 2500 + AR 12500 debit / Sales 15000 credit (balanced)

# ---- 4. idempotency: replay invoice #1's request_id -----------------------
$dup = (Invoke-RestMethod -Method Post -Uri "$url/rest/v1/rpc/create_sale_invoice" -Headers $h1 `
  -Body (@{ request_id=$r1.request_id; customer_id=$cust[0].id; invoice_date="2026-09-06";
          items=@(@{product_id=$prod[0].id; qty=10; price=5000}) } | ConvertTo-Json -Depth 5 -Compress))
$dup | ConvertTo-Json -Compress
# expect: {"duplicate": true, "invoice": {...}} — no second invoice, no extra stock loss

"INVOICE COUNT (must stay 2) -> " + (Invoke-RestMethod -Method Get -Uri "$url/rest/v1/invoices?select=id" -Headers $h1).Count

# ---- 5. commission: sell 2 of the commission product (80.00 sale) --------
$r3 = (Invoke-RestMethod -Method Post -Uri "$url/rest/v1/rpc/create_sale_invoice" -Headers $h1 `
  -Body (@{ request_id=[guid]::NewGuid().ToString(); customer_id=$cust[0].id; invoice_date="2026-09-06";
          items=@(@{product_id=$prodC[0].id; qty=2; price=8000}) } | ConvertTo-Json -Depth 5 -Compress))
$r3 | ConvertTo-Json -Compress
"COMMISSION DUES -> " + ((Invoke-RestMethod -Method Get -Uri "$url/rest/v1/commission_dues" -Headers $h1) | ConvertTo-Json -Compress)
# expect one due row: sale_total 16000, rate 20, commission_amount 3200, supplier_due 12800

# ---- 6. insufficient stock must fail --------------------------------------
try {
  Invoke-RestMethod -Method Post -Uri "$url/rest/v1/rpc/create_sale_invoice" -Headers $h1 `
    -Body (@{ request_id=[guid]::NewGuid().ToString(); customer_id=$cust[0].id; invoice_date="2026-09-06";
             items=@(@{product_id=$prod[0].id; qty=99999; price=5000}) } | ConvertTo-Json -Depth 5 -Compress)
} catch { "INSUFFICIENT STOCK REJECTED -> " + $_.Exception.Response.StatusCode.value__ }

# ---- 7. isolation: owner2 (or $h2) sees zero sales invoices ---------------
"OWNER2 INVOICES -> " + (Invoke-RestMethod -Method Get -Uri "$url/rest/v1/invoices?select=id" -Headers $h2).Count
```

### Pass criteria for Batch 2
- [ ] `invoice_counters` + 3 functions exist (structural).
- [ ] Invoice #1: `S-000001`, credit sale, journal balanced, stock 100→90.
- [ ] Invoice #2: partial cash payment splits AR + Cash correctly.
- [ ] Duplicate `request_id` returns `duplicate: true` with no new rows.
- [ ] Commission sale books `commission_due` (total 16000 → 3200 commission / 12800 due).
- [ ] Insufficient stock raises an error; owner2 sees no invoices.

Report the results and I proceed with Batch 3 (`0008_rpc_purchases.sql` — direct/consignment + inline product).

---

# Batch 3 — Purchase invoice RPC

**Apply:** `0008_rpc_purchases.sql` in the SQL Editor.

### Structural check (SQL Editor)
```sql
select proname from pg_proc where proname in ('create_purchase_invoice') order by 1;
```

### Functional tests (PowerShell, owner1)

```powershell
# re-establish session if needed (same start as Batch 2 block)
# ---- 1. direct supplier + existing product exists from Batch 2 -------------
$supD = (Invoke-RestMethod -Method Post -Uri "$url/rest/v1/suppliers" -Headers $h1 `
  -Body '{"name":"مورد مباشر","deal_type":"direct"}')

# direct purchase of 20 units @ 30.00 (drops from 90 stock to 110)
$pd = (Invoke-RestMethod -Method Post -Uri "$url/rest/v1/rpc/create_purchase_invoice" -Headers $h1 `
  -Body (@{ request_id=[guid]::NewGuid().ToString(); supplier_id=$supD[0].id; invoice_date="2026-09-06";
           items=@(@{product_id=$prod[0].id; qty=20; price=3000}) } | ConvertTo-Json -Depth 5 -Compress))
$pd | ConvertTo-Json -Compress
# expect: no = P-000001, ownership = owned, total 60000, remaining 60000, status unpaid, entry_no = N (next)

"STOCK AFTER DIRECT BUY -> " + ((Invoke-RestMethod -Method Get -Uri "$url/rest/v1/products?select=name,qty&id=eq.$($prod[0].id)" -Headers $h1) | ConvertTo-Json -Compress)
# expect qty = 110
# journal: DR Inventory 1030=60000 / CR AP 2010=60000 (balanced)

# ---- 2. inline new product on a direct purchase -----------------------------
$pi = (Invoke-RestMethod -Method Post -Uri "$url/rest/v1/rpc/create_purchase_invoice" -Headers $h1 `
  -Body (@{ request_id=[guid]::NewGuid().ToString(); supplier_id=$supD[0].id; invoice_date="2026-09-06";
           items=@(@{ new_product=@{name="تفاح"; unit="كغ"; unit_type="weight"; sale_price=2200};
                      qty=100; price=1500 }) } | ConvertTo-Json -Depth 5 -Compress))
$pi | ConvertTo-Json -Compress
"NEW PRODUCT ROW -> " + ((Invoke-RestMethod -Method Get -Uri "$url/rest/v1/products?select=name,unit_type,qty,purchase_price,supplier_id&name=eq.تفاح" -Headers $h1) | ConvertTo-Json -Compress)
# expect a new product linked to $supD, qty 100, purchase_price 1500

# ---- 3. commission supplier receipt: consignment, NO debt -------------------
$pc = (Invoke-RestMethod -Method Post -Uri "$url/rest/v1/rpc/create_purchase_invoice" -Headers $h1 `
  -Body (@{ request_id=[guid]::NewGuid().ToString(); supplier_id=$sup[0].id; invoice_date="2026-09-06";
           items=@(@{product_id=$prodC[0].id; qty=10; price=4000}) } | ConvertTo-Json -Depth 5 -Compress))
$pc | ConvertTo-Json -Compress
# expect: ownership = consignment, status unpaid, entry_no = null, total 40000, remaining 40000

"JOURNAL COUNT (only from owned buys) -> " + (Invoke-RestMethod -Method Get -Uri "$url/rest/v1/journal_entries?select=id" -Headers $h1).Count
# consignment receipt must NOT create a journal row

# ---- 4. paying a consignment receipt is forbidden --------------------------
try {
  Invoke-RestMethod -Method Post -Uri "$url/rest/v1/rpc/create_purchase_invoice" -Headers $h1 `
    -Body (@{ request_id=[guid]::NewGuid().ToString(); supplier_id=$sup[0].id; invoice_date="2026-09-06";
             items=@(@{product_id=$prodC[0].id; qty=1; price=4000}); paid=1000; payment_method="cash" } | ConvertTo-Json -Depth 5 -Compress)
} catch { "CONSIGNMENT PAY REJECTED -> " + $_.Exception.Response.StatusCode.value__ }

# ---- 5. duplicate replay is a no-op -----------------------------------------
Invoke-RestMethod -Method Post -Uri "$url/rest/v1/rpc/create_purchase_invoice" -Headers $h1 `
  -Body (@{ request_id=$pd.request_id; supplier_id=$supD[0].id; invoice_date="2026-09-06";
           items=@(@{product_id=$prod[0].id; qty=20; price=3000}) } | ConvertTo-Json -Depth 5 -Compress) | ConvertTo-Json -Compress
# expect {"duplicate": true, ...}

-- ---- 6. isolation ------------------------------------------------------------
"OWNER2 INVOICES -> " + (Invoke-RestMethod -Method Get -Uri "$url/rest/v1/invoices?select=id" -Headers $h2).Count

# ---- 7. both product_id AND new_product on one line is rejected --------------
try {
  Invoke-RestMethod -Method Post -Uri "$url/rest/v1/rpc/create_purchase_invoice" -Headers $h1 `
    -Body (@{ request_id=[guid]::NewGuid().ToString(); supplier_id=$supD[0].id; invoice_date="2026-09-06";
             items=@(@{ product_id=$prod[0].id; new_product=@{name="خطأ"; unit="حبة"; unit_type="count"};
                        qty=1; price=100 }) } | ConvertTo-Json -Depth 5 -Compress)
} catch { "AMBIGUOUS LINE REJECTED -> " + $_.Exception.Response.StatusCode.value__ }
```

### Pass criteria for Batch 3
- [ ] Direct purchase: `P-000001`, journal `1030 DR / 2010 CR` balanced, stock 90→110.
- [ ] Inline new product → row created (weight, qty 100) linked to the supplier.
- [ ] Commission receipt: `ownership=consignment`, `entry_no=null`, no journal row, unpaid.
- [ ] Paying a consignment receipt raises an error.
- [ ] Duplicate replay no-op; ambiguous `product_id`+`new_product` line rejected; owner2 sees nothing.

Report the results and I proceed with Batch 4 (`0009_rpc_payments.sql` — `record_payment` + `settle_supplier`).

---

# Batch 4 — Payments RPC

**Apply:** `0009_rpc_payments.sql` in the SQL Editor.

### Structural checks (SQL Editor)
```sql
-- payments has request_id; processed_requests has a result column
select column_name from information_schema.columns
where table_name = 'payments' and column_name = 'request_id';

select column_name from information_schema.columns
where table_name = 'processed_requests' and column_name = 'result';

-- functions exist
select proname from pg_proc where proname in ('record_payment','settle_supplier') order by 1;
```

### Functional tests (PowerShell, owner1)

Prereqs from earlier batches: sale invoice #1 exists with `remaining=50000` ($r1 no S-000001), a direct supplier $supD with 1 owned purchase invoice ($pd P-000001, remaining 60000), and a commission due from selling $prodC (12800).

```powershell
# ---- 1. collect half of sale #1 (25.00) ------------------------------------
$pay1 = (Invoke-RestMethod -Method Post -Uri "$url/rest/v1/rpc/record_payment" -Headers $h1 `
  -Body (@{ request_id=[guid]::NewGuid().ToString(); invoice_id=$r1.invoice_id; amount=25000; method="cash"; date="2026-09-07" } | ConvertTo-Json -Depth 5 -Compress))
$pay1 | ConvertTo-Json -Compress
# expect: no = S-000001, remaining 25000, status partial, entry_no = next N
# journal: DR Cash 1010 = 25000 / CR AR 1020 = 25000 (balanced)

# ---- 2. overpay is rejected -------------------------------------------------
try {
  Invoke-RestMethod -Method Post -Uri "$url/rest/v1/rpc/record_payment" -Headers $h1 `
    -Body (@{ request_id=[guid]::NewGuid().ToString(); invoice_id=$r1.invoice_id; amount=999999; method="cash" } | ConvertTo-Json -Depth 5 -Compress)
} catch { "OVERPAY REJECTED -> " + $_.Exception.Response.StatusCode.value__ }

# ---- 3. duplicate payment request_id is a no-op ------------------------------
Invoke-RestMethod -Method Post -Uri "$url/rest/v1/rpc/record_payment" -Headers $h1 `
  -Body (@{ request_id=$pay1.request_id; invoice_id=$r1.invoice_id; amount=25000; method="cash" } | ConvertTo-Json -Depth 5 -Compress) | ConvertTo-Json -Compress
# expect {"duplicate": true, "payment": {...}}

# ---- 4. settle the supplier: covers purchase invoice (60000) + due (12800) ---
$settle = (Invoke-RestMethod -Method Post -Uri "$url/rest/v1/rpc/settle_supplier" -Headers $h1 `
  -Body (@{ request_id=[guid]::NewGuid().ToString(); supplier_id=$sup[0].id; amount=12800; method="bank"; date="2026-09-07" } | ConvertTo-Json -Depth 5 -Compress))
$settle | ConvertTo-Json -Compress
# expect: total 12800, invoices_count 0, dues_count 1, allocations has the 12800 due

# full settle including the direct purchase invoice:
$settle2 = (Invoke-RestMethod -Method Post -Uri "$url/rest/v1/rpc/settle_supplier" -Headers $h1 `
  -Body (@{ request_id=[guid]::NewGuid().ToString(); supplier_id=$supD[0].id; amount=60000; method="bank"; date="2026-09-07" } | ConvertTo-Json -Depth 5 -Compress))
$settle2 | ConvertTo-Json -Compress
# expect: total 60000, invoices_count 1, dues_count 0; P-000001 now remaining 0 status paid

"SUPPLIER DUE REMAINING (expect 0) -> " + ((Invoke-RestMethod -Method Get -Uri "$url/rest/v1/commission_dues?select=supplier_due,paid,remaining" -Headers $h1) | ConvertTo-Json -Compress)
"DIRECT INVOICE STATUS (expect paid) -> " + ((Invoke-RestMethod -Method Get -Uri "$url/rest/v1/invoices?select=no,paid,remaining,status&id=eq.$($pd.invoice_id)" -Headers $h1) | ConvertTo-Json -Compress)

# ---- 5. settling with nothing owed raises ------------------------------------
try {
  Invoke-RestMethod -Method Post -Uri "$url/rest/v1/rpc/settle_supplier" -Headers $h1 `
    -Body (@{ request_id=[guid]::NewGuid().ToString(); supplier_id=$sup[0].id; amount=1000; method="cash" } | ConvertTo-Json -Depth 5 -Compress)
} catch { "NOTHING-DUE REJECTED -> " + $_.Exception.Response.StatusCode.value__ }

# ---- 6. over-settling raises -------------------------------------------------
try {
  Invoke-RestMethod -Method Post -Uri "$url/rest/v1/rpc/settle_supplier" -Headers $h1 `
    -Body (@{ request_id=[guid]::NewGuid().ToString(); supplier_id=$supD[0].id; amount=999999; method="cash" } | ConvertTo-Json -Depth 5 -Compress)
} catch { "OVER-SETTLE REJECTED -> " + $_.Exception.Response.StatusCode.value__ }

# ---- 7. isolation (+ journal sanity: everything so far is balanced) ----------
"OWNER2 PAYMENTS -> " + (Invoke-RestMethod -Method Get -Uri "$url/rest/v1/payments?select=id" -Headers $h2).Count
"OWNER2 INVOICES -> " + (Invoke-RestMethod -Method Get -Uri "$url/rest/v1/invoices?select=id" -Headers $h2).Count
```

Optional SQL-editor sanity (as postgres): every journal entry created so far balances:

```sql
select entry_id, sum(debit) as d, sum(credit) as c
from public.journal_entry_lines group by entry_id having sum(debit) <> sum(credit);
-- expect 0 rows
```

### Pass criteria for Batch 4
- [ ] Partial collection on S-000001 → remaining 25000, status partial, balanced journal.
- [ ] Overpay rejected; duplicate `request_id` no-op.
- [ ] `settle_supplier`: commission due cleared (12800) + owned invoice cleared (P-000001 → paid).
- [ ] Nothing-due and over-settle both raise.
- [ ] owner2 sees zero payments/invoices; global journal balanced.

Report the results and I proceed with Batch 5 (`0010_rpc_employees.sql` — `add_employee_movement` + `pay_salary`).

---

# Batch 5 — Employees RPC

**Apply:** `0010_rpc_employees.sql` in the SQL Editor.

### Structural checks (SQL Editor)
```sql
select proname from pg_proc
where proname in ('get_employee_entitlement','add_employee_movement','pay_salary') order by 1;

select column_name from information_schema.columns
where table_name = 'salaries' and column_name = 'request_id';
```

### Functional tests (PowerShell, owner1)

Prereq: the weight product ("طماطم", $prodLet) from Batch 2 — qty 45 after its sale (50-5). Employee must exist.

```powershell
# ---- 0. employee + bump product context -------------------------------------
$emp = (Invoke-RestMethod -Method Post -Uri "$url/rest/v1/employees" -Headers $h1 `
  -Body '{"name":"محمد الموظف","job_title":"مندوب","base_salary":100000}')  # 1000.00

# ---- 1. product deduction: 2 kg of طماطم (cost 1500) = 3000 -------------------
$movP = (Invoke-RestMethod -Method Post -Uri "$url/rest/v1/rpc/add_employee_movement" -Headers $h1 `
  -Body (@{ request_id=[guid]::NewGuid().ToString(); employee_id=$emp[0].id; month="2026-09-01";
           direction="out"; category="product"; description="شهر سبتمبر"; product_id=$prodLet[0].id; qty=2 } | ConvertTo-Json -Depth 5 -Compress))
$movP | ConvertTo-Json -Compress
# expect: amount 3000
"STOCK AFTER PRODUCT DEDUCTION (expect 43) -> " + ((Invoke-RestMethod -Method Get -Uri "$url/rest/v1/products?select=name,qty&id=eq.$($prodLet[0].id)" -Headers $h1) | ConvertTo-Json -Compress)

# ---- 2. advance 2000 + bonus 5000 ---------------------------------------------
$movA = (Invoke-RestMethod -Method Post -Uri "$url/rest/v1/rpc/add_employee_movement" -Headers $h1 `
  -Body (@{ request_id=[guid]::NewGuid().ToString(); employee_id=$emp[0].id; month="2026-09-01";
           direction="out"; category="advance"; amount=2000; description="سلفة" } | ConvertTo-Json -Depth 5 -Compress))
$movB = (Invoke-RestMethod -Method Post -Uri "$url/rest/v1/rpc/add_employee_movement" -Headers $h1 `
  -Body (@{ request_id=[guid]::NewGuid().ToString(); employee_id=$emp[0].id; month="2026-09-01";
           direction="in"; category="bonus"; amount=5000; description="مكافأة" } | ConvertTo-Json -Depth 5 -Compress))

# ---- 3. compute entitlement: 100000 + 5000 - (3000 + 2000) = 100000 -------------
"ENTITLEMENT -> " + ((Invoke-RestMethod -Method Post -Uri "$url/rest/v1/rpc/get_employee_entitlement" -Headers $h1 `
  -Body (@{ employee_id=$emp[0].id; month="2026-09-01" } | ConvertTo-Json -Depth 5 -Compress)) | ConvertTo-Json -Compress)
# expect: base 100000, arrears 0, entitlements 5000, deductions 5000, net_due 100000

# ---- 4. pay 90% of net due (90000) ---------------------------------------------
$sal1 = (Invoke-RestMethod -Method Post -Uri "$url/rest/v1/rpc/pay_salary" -Headers $h1 `
  -Body (@{ request_id=[guid]::NewGuid().ToString(); employee_id=$emp[0].id; month="2026-09-01";
           paid=90000; method="cash"; date="2026-09-30" } | ConvertTo-Json -Depth 5 -Compress))
$sal1 | ConvertTo-Json -Compress
# expect: net_due 100000, paid 90000, arrears_carried 10000
# journal: DR 5030 = 100000 (wage expense, nothing to clear first month) / CR cash 90000 + CR 2030 10000

# ---- 5. October: base 100000 + prior arrears 10000 = 110000; pay all ----------
$sal2 = (Invoke-RestMethod -Method Post -Uri "$url/rest/v1/rpc/pay_salary" -Headers $h1 `
  -Body (@{ request_id=[guid]::NewGuid().ToString(); employee_id=$emp[0].id; month="2026-10-01";
           paid=110000; method="bank"; date="2026-10-31" } | ConvertTo-Json -Depth 5 -Compress))
$sal2 | ConvertTo-Json -Compress
# expect: arrears 10000, net_due 110000, paid 110000, arrears_carried 0
# journal: DR 2030 = 10000, DR 5030 = 100000 / CR bank 110000 (balanced)

# ---- 6. double-pay September must raise ----------------------------------------
try {
  Invoke-RestMethod -Method Post -Uri "$url/rest/v1/rpc/pay_salary" -Headers $h1 `
    -Body (@{ request_id=[guid]::NewGuid().ToString(); employee_id=$emp[0].id; month="2026-09-01";
             paid=1000; method="cash" } | ConvertTo-Json -Depth 5 -Compress)
} catch { "DOUBLE-PAY REJECTED -> " + $_.Exception.Response.StatusCode.value__ }

# ---- 7. overpay beyond net due must raise ---------------------------------------
try {
  Invoke-RestMethod -Method Post -Uri "$url/rest/v1/rpc/pay_salary" -Headers $h1 `
    -Body (@{ request_id=[guid]::NewGuid().ToString(); employee_id=$emp[0].id; month="2026-11-01";
             paid=999999; method="cash" } | ConvertTo-Json -Depth 5 -Compress)
} catch { "OVERPAY REJECTED -> " + $_.Exception.Response.StatusCode.value__ }

# ---- 8. duplicate movement / salary request_id are no-ops ----------------------
Invoke-RestMethod -Method Post -Uri "$url/rest/v1/rpc/add_employee_movement" -Headers $h1 `
  -Body (@{ request_id=$movA.request_id; employee_id=$emp[0].id; month="2026-09-01";
           direction="out"; category="advance"; amount=2000 } | ConvertTo-Json -Depth 5 -Compress) | ConvertTo-Json -Compress

# ---- 9. direction/category mismatch must raise ---------------------------------
try {
  Invoke-RestMethod -Method Post -Uri "$url/rest/v1/rpc/add_employee_movement" -Headers $h1 `
    -Body (@{ request_id=[guid]::NewGuid().ToString(); employee_id=$emp[0].id; month="2026-09-01";
             direction="in"; category="advance"; amount=100 } | ConvertTo-Json -Depth 5 -Compress)
} catch { "BAD DIRECTION REJECTED -> " + $_.Exception.Response.StatusCode.value__ }

"OWNER2 EMPLOYEES -> " + (Invoke-RestMethod -Method Get -Uri "$url/rest/v1/employees?select=id" -Headers $h2).Count
```

Optional post-check (SQL editor): global balance sanity again — expect 0 rows.

```sql
select entry_id, sum(debit) as d, sum(credit) as c
from public.journal_entry_lines group by entry_id having sum(debit) <> sum(credit);
```

### Pass criteria for Batch 5
- [ ] Product deduction: stock −2, movement amount 3000 (`qty × cost`).
- [ ] Entitlement: base 100000 + bonus 5000 − (3000+2000) = **net_due 100000**.
- [ ] September pay 90000 → arrears carried 10000, journal balanced.
- [ ] October pay 110000 (clears arrears: DR 2030 10000 + DR 5030 100000 / CR bank 110000).
- [ ] Double-pay, overpay, and direction/category mismatch all raise; duplicate request_ids no-op; owner2 sees nothing.

Report the results and I proceed with Batch 6 (final): `0012_storage.sql`, `0013_reminder.sql`, `supabase/README.md`, and the full regression run.

---

# Migration fixes applied during verification (already in the files)

Re-running any of these after the fact is safe — each is `create or replace` / idempotent:
- **`0009_rpc_payments.sql`** — `record_payment` wrote `invoices.type` (`sale`/`purchase`)
  into `payments.type`, which only allows `customer`/`supplier` → caught live as
  `23514 payments_type_check`. Fixed with a `case` mapping inside the function.
- **`0012_storage.sql`** — removed `ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;`
  (postgres is not the owner → `42501`). Storage tables ship with RLS on; only the
  bucket-scoped policies remain.
- **`0013_reminder.sql`** — job cleanup uses `select cron.unschedule(jobid)` from
  `cron.job where jobname = ...` instead of `delete from cron.job`
  (extension-owned schema → `42501`).

---

# Batch 6 — Storage + Reminders, then Full Regression

**Apply:** `0012_storage.sql` → `0013_reminder.sql` in the SQL Editor.

### Structural checks (SQL Editor)
```sql
-- storage bucket
select id, "name", public from storage.buckets where id = 'pdfs';

-- reminder tables + RLS
select schemaname, tablename, rowsecurity from pg_tables
where schemaname='public' and tablename in ('tenant_settings','reminder_log');

-- functions exist
select proname from pg_proc
where proname in ('send_due_reminders','send_reminder_now') order by 1;

-- cron job registered
select jobname, schedule, "command" from cron.job where jobname = 'send-due-reminders-daily';
```

### Part B — reminder tests (PowerShell, owner1)

```powershell
# owner1 settings were auto-seeded by the trigger; point it at a live webhook.
# NOTE: PATCH needs a WHERE clause - always carry the tenant_id filter.
$t = @(Invoke-RestMethod -Method Get -Uri "$url/rest/v1/tenants?select=id" -Headers $h1)
Invoke-RestMethod -Method Patch -Uri "$url/rest/v1/tenant_settings?tenant_id=eq.$($t[0].id)" -Headers $h1 `
  -Body (@{ reminder_webhook_url="https://webhook.site/<your-test-id>"; reminder_days_threshold=1; reminder_enabled="true" } | ConvertTo-Json -Depth 5 -Compress)

# owner1's customer has phone? set one if missing:
Invoke-RestMethod -Method Patch -Uri "$url/rest/v1/customers?id=eq.$($cust[0].id)" -Headers $h1 `
  -Body (@{ phone="0599-000000" } | ConvertTo-Json -Depth 5 -Compress)
```
Create an invoice (or reuse an existing unpaid S-000001) dated ≥2 days ago, then:

```powershell
# on-demand "remind now"
Invoke-RestMethod -Method Post -Uri "$url/rest/v1/rpc/send_reminder_now" -Headers $h1 `
  -Body (@{ p_customer_id=$cust[0].id } | ConvertTo-Json -Depth 5 -Compress) | ConvertTo-Json -Compress
# expect a reminder_log row with status sent, phone filled, message containing amount

"REMINDER LOG -> " + ((Invoke-RestMethod -Method Get -Uri "$url/rest/v1/reminder_log?select=status,phone,message,amount" -Headers $h1) | ConvertTo-Json -Compress)
"OWNER2 LOG (expect 0) -> " + (Invoke-RestMethod -Method Get -Uri "$url/rest/v1/reminder_log?select=id" -Headers $h2).Count
```
(If you don't have a test webhook, still call `send_reminder_now` and expect either a
`reminder_log` `failed` row or the "لا يوجد رقم" error — that itself proves RLS by
owner2 seeing zero rows.)

---

# Full Regression — fresh tenant (M1 exit criteria)

Create a **fresh** auth user each run (e.g. `owner3@test.local`, then `owner4@test.local`
next time — `register_tenant` is one-shot). The flows below are also automated in
`supabase/tests/payment_final.ps1`, `reminder_final_v2.ps1`, and `idempotency_fixed.ps1`:

```powershell
# sign in owner3, capture $h3, then:
# 1. register tenant
$t3 = (Invoke-RestMethod -Method Post -Uri "$url/auth/v1/token?grant_type=password" -Headers $headers -Body (@{email="owner3@test.local";password=$p3}|ConvertTo-Json)).access_token
$h3 = @{ apikey=$key; Authorization="Bearer $t3"; "Content-Type"="application/json" }
"REGISTER -> " + (Invoke-RestMethod -Method Post -Uri "$url/rest/v1/rpc/register_tenant" -Headers $h3 -Body '{"p_name":"شركة التحقق الشاملة"}')

# 2. chart of accounts
"ACCOUNTS (expect 14) -> " + (Invoke-RestMethod -Method Get -Uri "$url/rest/v1/accounts?select=code&order=code" -Headers $h3).Count

# 3. masters
$cu = (Invoke-RestMethod -Method Post -Uri "$url/rest/v1/customers" -Headers $h3 -Body '{"name":"عميل تجريبي"}')
$pr = (Invoke-RestMethod -Method Post -Uri "$url/rest/v1/products" -Headers $h3 -Body '{"name":"منتج","unit":"حبة","unit_type":"count","sale_price":5000,"purchase_price":2000,"qty":100}')
$su = (Invoke-RestMethod -Method Post -Uri "$url/rest/v1/suppliers" -Headers $h3 -Body '{"name":"مورد","deal_type":"commission","commission_rate":20}')

# 4. sale 30 units -> S-000001
$s = (Invoke-RestMethod -Method Post -Uri "$url/rest/v1/rpc/create_sale_invoice" -Headers $h3 -Body (@{request_id=[guid]::NewGuid().ToString();customer_id=$cu[0].id;invoice_date="2026-09-06";items=@(@{product_id=$pr[0].id;qty=30;price=5000})}|ConvertTo-Json -Depth 5 -Compress))
"$($s|ConvertTo-Json -Compress)"
"STOCK (expect 70) -> " + (Invoke-RestMethod -Method Get -Uri "$url/rest/v1/products?select=qty&id=eq.$($pr[0].id)" -Headers $h3).qty

# 5. pay 80% -> 12000, remaining 3000
$pay = (Invoke-RestMethod -Method Post -Uri "$url/rest/v1/rpc/record_payment" -Headers $h3 -Body (@{request_id=[guid]::NewGuid().ToString();invoice_id=$s.invoice_id;amount=120000;method="cash"}|ConvertTo-Json -Depth 5 -Compress))
"$($pay|ConvertTo-Json -Compress)"

# 6. purchase: link the commission product to the supplier + consignment receipt (no debt)
Invoke-RestMethod -Method Patch -Uri "$url/rest/v1/products?id=eq.$($pr[0].id)" -Headers $h3 -Body (@{supplier_id=$su[0].id}|ConvertTo-Json -Depth 5) | Out-Null
$pur = (Invoke-RestMethod -Method Post -Uri "$url/rest/v1/rpc/create_purchase_invoice" -Headers $h3 -Body (@{request_id=[guid]::NewGuid().ToString();supplier_id=$su[0].id;invoice_date="2026-09-06";items=@(@{product_id=$pr[0].id;qty=10;price=2000})}|ConvertTo-Json -Depth 5 -Compress))
"$($pur|ConvertTo-Json -Compress)"   # ownership = consignment, entry_no null

# 7. employee: product deduction + wage pay
$em = (Invoke-RestMethod -Method Post -Uri "$url/rest/v1/employees" -Headers $h3 -Body '{"name":"موظف","base_salary":50000}')
Invoke-RestMethod -Method Post -Uri "$url/rest/v1/rpc/add_employee_movement" -Headers $h3 -Body (@{request_id=[guid]::NewGuid().ToString();employee_id=$em[0].id;month="2026-09-01";direction="out";category="product";product_id=$pr[0].id;qty=2}|ConvertTo-Json -Depth 5 -Compress)|Out-Null
$sl = (Invoke-RestMethod -Method Post -Uri "$url/rest/v1/rpc/pay_salary" -Headers $h3 -Body (@{request_id=[guid]::NewGuid().ToString();employee_id=$em[0].id;month="2026-09-01";paid=50000;method="cash"}|ConvertTo-Json -Depth 5 -Compress))
"$($sl|ConvertTo-Json -Compress)"    # net_due = 50000 - 4000(product) = 46000

# 8. library is balanced globally
"INVOICES -> " + (Invoke-RestMethod -Method Get -Uri "$url/rest/v1/invoices?select=no,total,paid,remaining,status,ownership" -Headers $h3).Count
```

### Regression pass criteria
- [ ] New tenant: 14 accounts seeded on register.
- [ ] Sale S-000001 (stock 100→70), partial cash payment splits correctly.
- [ ] Consignment receipt books **no** journal entry (entry_no null) and no debt.
- [ ] Employee product deduction moves stock (−2) and pay_salary computes net_due 46000.
- [ ] owner2 sees zero rows in every tenant table (isolation holds).
- [ ] Global journal balance sanity returns 0 discrepancies.

---

## M1 Definition of Done (final gate)
- [ ] All 13 migrations applied in order without error.
- [ ] Every functional batch (1–6) and the fresh-tenant regression pass.
- [ ] Storage bucket + reminder log + cron job verified.
- [ ] `supabase/README.md` documents connection, RPC contract, and apply order.

On green, M1 is delivered. Commit the `supabase/` tree, then proceed to **M2** (Flutter restructure: `core/ domain/ data/ presentation/`, AuthRepository + SupabaseAuthRepository, login screen, responsive shell, role-gated nav, 16 screen scaffolds, widget_test rewrite, font_awesome_flutter).