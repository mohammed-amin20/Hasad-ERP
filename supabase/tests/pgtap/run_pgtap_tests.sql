-- Hasad ERP — pgTAP Regression Test Suite
-- Run in Supabase SQL Editor against DEV or PROD project
-- Requires: pgtap extension (CREATE EXTENSION pgtap;)

-- Enable pgTAP
CREATE EXTENSION IF NOT EXISTS pgtap;

-- Test plan: declare number of tests
SELECT plan(42);

-- ============================================================
-- HELPER: Create test tenant + users
-- ============================================================

DO $$
DECLARE
  v_tenant_a uuid := gen_random_uuid();
  v_tenant_b uuid := gen_random_uuid();
  v_user_a uuid := gen_random_uuid();
  v_user_b uuid := gen_random_uuid();
BEGIN
  -- Insert tenants directly (bypass register_tenant for test isolation)
  INSERT INTO tenants (id, name, plan, created_at)
  VALUES (v_tenant_a, 'Test Tenant A', 'basic', now()),
         (v_tenant_b, 'Test Tenant B', 'basic', now());

  -- Insert users linked to tenants
  INSERT INTO users (id, tenant_id, email, role, created_at)
  VALUES (v_user_a, v_tenant_a, 'usera@test.local', 'admin', now()),
         (v_user_b, v_tenant_b, 'userb@test.local', 'admin', now());

  -- Store for later tests (using temp table)
  CREATE TEMP TABLE test_context (
    tenant_a uuid, tenant_b uuid, user_a uuid, user_b uuid
  ) ON COMMIT DROP;
  INSERT INTO test_context VALUES (v_tenant_a, v_tenant_b, v_user_a, v_user_b);
END $$;

-- Helper to get test tenant IDs
\set tenant_a `SELECT tenant_a FROM test_context`
\set tenant_b `SELECT tenant_b FROM test_context`
\set user_a `SELECT user_a FROM test_context`
\set user_b `SELECT user_b FROM test_context`

-- ============================================================
-- TEST 1: Tenant Isolation (RLS)
-- ============================================================

-- Set role to tenant A
SET ROLE authenticated;
SET request.jwt.claims = format('{"sub": "%s", "tenant_id": "%s"}', :'user_a', :'tenant_a')::jsonb;

-- Tenant A should see only their data
SELECT is(
  (SELECT count(*) FROM tenants),
  1,
  'Tenant A sees only their own tenant row'
);

SELECT is(
  (SELECT count(*) FROM customers),
  0,
  'Tenant A sees zero customers initially'
);

-- Insert customer as tenant A
INSERT INTO customers (tenant_id, name, phone) VALUES (:'tenant_a', 'Customer A1', '0599111111');

SELECT is(
  (SELECT count(*) FROM customers),
  1,
  'Tenant A sees their inserted customer'
);

-- Switch to tenant B
SET request.jwt.claims = format('{"sub": "%s", "tenant_id": "%s"}', :'user_b', :'tenant_b')::jsonb;

SELECT is(
  (SELECT count(*) FROM customers),
  0,
  'Tenant B sees ZERO customers (tenant A data isolated)'
);

-- Insert customer as tenant B
INSERT INTO customers (tenant_id, name, phone) VALUES (:'tenant_b', 'Customer B1', '0599222222');

SELECT is(
  (SELECT count(*) FROM customers),
  1,
  'Tenant B sees only their own customer'
);

-- Switch back to tenant A
SET request.jwt.claims = format('{"sub": "%s", "tenant_id": "%s"}', :'user_a', :'tenant_a')::jsonb;

SELECT is(
  (SELECT count(*) FROM customers),
  1,
  'Tenant A still sees only their customer after tenant B insert'
);

-- ============================================================
-- TEST 2: Double-Entry Balance (create_sale_invoice)
-- ============================================================

-- Setup: customer, product, accounts for tenant A
SET request.jwt.claims = format('{"sub": "%s", "tenant_id": "%s"}', :'user_a', :'tenant_a')::jsonb;

DO $$
DECLARE
  v_customer uuid;
  v_product uuid;
BEGIN
  INSERT INTO customers (tenant_id, name, phone) VALUES (:'tenant_a', 'Test Customer', '0599111111')
  RETURNING id INTO v_customer;
  
  INSERT INTO products (tenant_id, name, unit_type, unit, sale_price, qty_on_hand, reorder_level)
  VALUES (:'tenant_a', 'Test Product', 'count', 'قطعة', 10000, 100, 10)
  RETURNING id INTO v_product;
  
  CREATE TEMP TABLE test_entities (customer_id uuid, product_id uuid) ON COMMIT DROP;
  INSERT INTO test_entities VALUES (v_customer, v_product);
END $$;

\set customer_id `SELECT customer_id FROM test_entities`
\set product_id `SELECT product_id FROM test_entities`

-- Successful sale invoice (balanced)
SELECT lives_ok(
  $$
  SELECT create_sale_invoice(
    p_request_id := gen_random_uuid(),
    p_customer_id := :'customer_id',
    p_items := jsonb_build_array(
      jsonb_build_object('product_id', :'product_id', 'qty', 2, 'price', 10000)
    ),
    p_invoice_date := CURRENT_DATE,
    p_paid := 0,
    p_payment_method := 'cash',
    p_memo := 'Test sale'
  );
  $$,
  'create_sale_invoice succeeds with balanced entry'
);

-- Verify journal entry is balanced
SELECT is(
  (SELECT sum(debit) - sum(credit) FROM journal_entry_lines jel
   JOIN journal_entries je ON je.id = jel.journal_entry_id
   WHERE je.tenant_id = :'tenant_a'),
  0,
  'Journal entry for sale is balanced (debit = credit)'
);

-- Verify inventory deducted
SELECT is(
  (SELECT qty_on_hand FROM products WHERE id = :'product_id'),
  98,
  'Inventory deducted by sold quantity (100 - 2 = 98)'
);

-- ============================================================
-- TEST 3: Commission Logic (Consignment)
-- ============================================================

-- Setup: commission supplier + product linked to it
SET request.jwt.claims = format('{"sub": "%s", "tenant_id": "%s"}', :'user_a', :'tenant_a')::jsonb;

DO $$
DECLARE
  v_supplier uuid;
  v_product uuid;
  v_customer uuid;
BEGIN
  INSERT INTO suppliers (tenant_id, name, phone, deal_type, commission_rate)
  VALUES (:'tenant_a', 'Commission Supplier', '0599333333', 'commission', 0.20)
  RETURNING id INTO v_supplier;
  
  INSERT INTO products (tenant_id, name, unit_type, unit, sale_price, qty_on_hand, reorder_level, supplier_id, commission_rate)
  VALUES (:'tenant_a', 'Consignment Product', 'count', 'قطعة', 15000, 50, 5, v_supplier, 0.20)
  RETURNING id INTO v_product;
  
  INSERT INTO customers (tenant_id, name, phone) VALUES (:'tenant_a', 'Commission Customer', '0599444444')
  RETURNING id INTO v_customer;
  
  CREATE TEMP TABLE commission_test (supplier_id uuid, product_id uuid, customer_id uuid) ON COMMIT DROP;
  INSERT INTO commission_test VALUES (v_supplier, v_product, v_customer);
END $$;

\set comm_supplier `SELECT supplier_id FROM commission_test`
\set comm_product `SELECT product_id FROM commission_test`
\set comm_customer `SELECT customer_id FROM commission_test`

-- Consignment purchase (receipt, no debt)
SELECT lives_ok(
  $$
  SELECT create_purchase_invoice(
    p_request_id := gen_random_uuid(),
    p_supplier_id := :'comm_supplier',
    p_items := jsonb_build_array(
      jsonb_build_object('product_id', :'comm_product', 'qty', 10)
    ),
    p_invoice_date := CURRENT_DATE,
    p_paid := 0,
    p_payment_method := 'cash',
    p_memo := 'Consignment receipt'
  );
  $$,
  'Consignment purchase succeeds'
);

-- Verify zero debt (consignment)
SELECT is(
  (SELECT sum(remaining) FROM invoices WHERE supplier_id = :'comm_supplier' AND ownership = 'consignment'),
  0,
  'Consignment purchase creates zero remaining debt'
);

-- Sale of consignment product → commission due
SELECT lives_ok(
  $$
  SELECT create_sale_invoice(
    p_request_id := gen_random_uuid(),
    p_customer_id := :'comm_customer',
    p_items := jsonb_build_array(
      jsonb_build_object('product_id', :'comm_product', 'qty', 3, 'price', 15000)
    ),
    p_invoice_date := CURRENT_DATE,
    p_paid := 0,
    p_payment_method := 'cash',
    p_memo := 'Consignment sale'
  );
  $$,
  'Consignment sale succeeds'
);

-- Verify commission due created
SELECT ok(
  EXISTS (
    SELECT 1 FROM commission_dues cd
    JOIN invoices i ON i.id = cd.invoice_id
    WHERE i.tenant_id = :'tenant_a' AND cd.status = 'pending'
  ),
  'Commission due created for consignment sale'
);

-- Verify commission amount = sale_price * (1 - commission_rate) * qty
-- 15000 * (1 - 0.20) * 3 = 15000 * 0.80 * 3 = 36000
SELECT is(
  (SELECT sum(due_amount) FROM commission_dues cd
   JOIN invoices i ON i.id = cd.invoice_id
   WHERE i.tenant_id = :'tenant_a'),
  36000,
  'Commission due amount correct (36000 agorot)'
);

-- ============================================================
-- TEST 4: Payments (record_payment)
-- ============================================================

SET request.jwt.claims = format('{"sub": "%s", "tenant_id": "%s"}', :'user_a', :'tenant_a')::jsonb;

-- Get an unpaid invoice from tenant A
\set unpaid_invoice `SELECT id FROM invoices WHERE tenant_id = :'tenant_a' AND type = 'sale' AND status = 'unpaid' LIMIT 1`

SELECT lives_ok(
  $$
  SELECT record_payment(
    p_request_id := gen_random_uuid(),
    p_invoice_id := :'unpaid_invoice',
    p_amount := 10000,
    p_method := 'cash',
    p_date := CURRENT_DATE,
    p_note := 'Partial payment'
  );
  $$,
  'record_payment succeeds'
);

-- Verify invoice status updated to partial
SELECT is(
  (SELECT status FROM invoices WHERE id = :'unpaid_invoice'),
  'partial',
  'Invoice status updated to partial after payment'
);

-- Verify journal entry created and balanced
SELECT is(
  (SELECT sum(debit) - sum(credit) FROM journal_entry_lines jel
   JOIN journal_entries je ON je.id = jel.journal_entry_id
   WHERE je.source_type = 'payment' AND je.tenant_id = :'tenant_a'),
  0,
  'Payment journal entry is balanced'
);

-- ============================================================
-- TEST 5: Party Statement (get_party_statement)
-- ============================================================

SET request.jwt.claims = format('{"sub": "%s", "tenant_id": "%s"}', :'user_a', :'tenant_a')::jsonb;

-- Get customer statement
\set stmt_customer `SELECT id FROM customers WHERE tenant_id = :'tenant_a' LIMIT 1`

SELECT lives_ok(
  $$
  SELECT get_party_statement('customer', :'stmt_customer', CURRENT_DATE - INTERVAL '30 days', CURRENT_DATE);
  $$,
  'get_party_statement returns result for customer'
);

-- Verify statement structure
SELECT ok(
  (SELECT get_party_statement('customer', :'stmt_customer', CURRENT_DATE - INTERVAL '30 days', CURRENT_DATE))::jsonb ? 'opening',
  'Statement has opening balance'
);

SELECT ok(
  (SELECT get_party_statement('customer', :'stmt_customer', CURRENT_DATE - INTERVAL '30 days', CURRENT_DATE))::jsonb ? 'lines',
  'Statement has lines array'
);

-- ============================================================
-- TEST 6: Inventory Adjustment (adjust_inventory)
-- ============================================================

SET request.jwt.claims = format('{"sub": "%s", "tenant_id": "%s"}', :'user_a', :'tenant_a')::jsonb;

\set adj_product `SELECT id FROM products WHERE tenant_id = :'tenant_a' AND name = 'Test Product'`

-- Count = 105 (increase by 7)
SELECT lives_ok(
  $$
  SELECT adjust_inventory(:'adj_product', 105, 'Physical count', CURRENT_DATE);
  $$,
  'adjust_inventory succeeds with increase'
);

SELECT is(
  (SELECT qty_on_hand FROM products WHERE id = :'adj_product'),
  105,
  'Product qty updated to counted value (105)'
);

SELECT ok(
  EXISTS (
    SELECT 1 FROM stock_moves WHERE product_id = :'adj_product' AND ref LIKE 'جرد:%'
  ),
  'Stock move recorded for adjustment'
);

-- ============================================================
-- TEST 7: Salaries (add_employee_movement, pay_salary)
-- ============================================================

SET request.jwt.claims = format('{"sub": "%s", "tenant_id": "%s"}', :'user_a', :'tenant_a')::jsonb;

DO $$
DECLARE
  v_emp uuid;
BEGIN
  INSERT INTO employees (tenant_id, name, role, phone, base_salary)
  VALUES (:'tenant_a', 'Test Employee', 'sales', '0599555555', 500000)
  RETURNING id INTO v_emp;
  
  CREATE TEMP TABLE salary_test (emp_id uuid) ON COMMIT DROP;
  INSERT INTO salary_test VALUES (v_emp);
END $$;

\set emp_id `SELECT emp_id FROM salary_test`

-- Add advance deduction
SELECT lives_ok(
  $$
  SELECT add_employee_movement(
    p_employee_id := :'emp_id',
    p_month := date_trunc('month', CURRENT_DATE)::date,
    p_direction := 'deduct',
    p_category := 'advance',
    p_amount := 50000,
    p_date := CURRENT_DATE,
    p_note := 'Cash advance'
  );
  $$,
  'add_employee_movement (advance) succeeds'
);

-- Pay salary
SELECT lives_ok(
  $$
  SELECT pay_salary(
    p_employee_id := :'emp_id',
    p_month := date_trunc('month', CURRENT_DATE)::date,
    p_paid := 450000,
    p_method := 'bank',
    p_date := CURRENT_DATE,
    p_note := 'Salary payment'
  );
  $$,
  'pay_salary succeeds'
);

-- Verify salary record created
SELECT is(
  (SELECT count(*) FROM salaries WHERE employee_id = :'emp_id'),
  1,
  'Salary record created'
);

-- ============================================================
-- TEST 8: Idempotency (p_request_id)
-- ============================================================

SET request.jwt.claims = format('{"sub": "%s", "tenant_id": "%s"}', :'user_a', :'tenant_a')::jsonb;

\set idempotent_req gen_random_uuid()

-- First call
SELECT lives_ok(
  $$
  SELECT create_sale_invoice(
    p_request_id := :'idempotent_req',
    p_customer_id := :'customer_id',
    p_items := jsonb_build_array(
      jsonb_build_object('product_id', :'product_id', 'qty', 1, 'price', 10000)
    ),
    p_invoice_date := CURRENT_DATE,
    p_paid := 0,
    p_payment_method := 'cash',
    p_memo := 'Idempotency test 1'
  );
  $$,
  'First call with request_id succeeds'
);

-- Second call with same request_id should return same invoice (not duplicate)
SELECT lives_ok(
  $$
  SELECT create_sale_invoice(
    p_request_id := :'idempotent_req',
    p_customer_id := :'customer_id',
    p_items := jsonb_build_array(
      jsonb_build_object('product_id', :'product_id', 'qty', 1, 'price', 10000)
    ),
    p_invoice_date := CURRENT_DATE,
    p_paid := 0,
    p_payment_method := 'cash',
    p_memo := 'Idempotency test 2'
  );
  $$,
  'Second call with same request_id succeeds (no error)'
);

-- Verify only ONE invoice created for this request_id
SELECT is(
  (SELECT count(*) FROM processed_requests WHERE request_id = :'idempotent_req'),
  1,
  'processed_requests has exactly one entry for the request_id'
);

-- ============================================================
-- TEST 9: Reminder Functions
-- ============================================================

SET request.jwt.claims = format('{"sub": "%s", "tenant_id": "%s"}', :'user_a', :'tenant_a')::jsonb;

-- Configure tenant settings for reminders
UPDATE tenant_settings SET
  webhook_url = 'https://n8n.test/webhook/hasad-reminder',
  message = 'Test reminder for {customer_name}',
  days_threshold = 1,
  enabled = true
WHERE tenant_id = :'tenant_a';

-- Create overdue invoice (date 5 days ago)
\set overdue_invoice `SELECT id FROM invoices WHERE tenant_id = :'tenant_a' AND type = 'sale' AND status = 'unpaid' ORDER BY created_at LIMIT 1`

UPDATE invoices SET date = CURRENT_DATE - INTERVAL '5 days' WHERE id = :'overdue_invoice';

-- send_reminder_now
SELECT lives_ok(
  $$
  SELECT send_reminder_now((
    SELECT customer_id FROM invoices WHERE id = :'overdue_invoice'
  ));
  $$,
  'send_reminder_now succeeds for overdue customer'
);

-- Verify reminder_log entry
SELECT ok(
  EXISTS (SELECT 1 FROM reminder_log WHERE tenant_id = :'tenant_a'),
  'reminder_log entry created'
);

-- send_reminders_to_all
SELECT lives_ok(
  $$
  SELECT send_reminders_to_all();
  $$,
  'send_reminders_to_all succeeds'
);

-- ============================================================
-- TEST 10: Financial Reports
-- ============================================================

SET request.jwt.claims = format('{"sub": "%s", "tenant_id": "%s"}', :'user_a', :'tenant_a')::jsonb;

-- Dashboard summary
SELECT lives_ok(
  $$ SELECT get_dashboard_summary(); $$,
  'get_dashboard_summary succeeds'
);

-- Chart of accounts
SELECT lives_ok(
  $$ SELECT get_chart_of_accounts(); $$,
  'get_chart_of_accounts succeeds'
);

-- Trial balance
SELECT lives_ok(
  $$ SELECT get_trial_balance(CURRENT_DATE); $$,
  'get_trial_balance succeeds'
);

-- Verify trial balance is balanced
SELECT is(
  (SELECT (get_trial_balance(CURRENT_DATE))::jsonb ->> 'balanced')::boolean,
  true,
  'Trial balance reports balanced = true'
);

-- Income statement
SELECT lives_ok(
  $$ SELECT get_income_statement(CURRENT_DATE - INTERVAL '30 days', CURRENT_DATE); $$,
  'get_income_statement succeeds'
);

-- Balance sheet
SELECT lives_ok(
  $$ SELECT get_balance_sheet(CURRENT_DATE); $$,
  'get_balance_sheet succeeds'
);

-- Verify balance sheet check = 0
SELECT is(
  (SELECT (get_balance_sheet(CURRENT_DATE))::jsonb ->> 'sheet_check')::numeric,
  0,
  'Balance sheet check = 0 (balanced)'
);

-- ============================================================
-- CLEANUP
-- ============================================================

-- Drop test data (optional - run manually if needed)
-- DROP TABLE test_context, test_entities, commission_test, salary_test;

-- Finish
SELECT * FROM finish();