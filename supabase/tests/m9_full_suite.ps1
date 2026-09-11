# ============================================================
# M9 FULL SUITE - PowerShell REST regression (42 assertions)
#
# Canonical successor to supabase/tests/pgtap/run_pgtap_tests_pure.sql.
# The pgTAP runnner was abandoned: `SET request.jwt.claims = (SELECT ...)`
# is not supported in the Supabase SQL Editor, and the users table has no
# `email` column. This suite drives the SAME 39 scenarios over real JWT +
# PostgREST, plus 3 gap-fillers (E1-E3) to reach plan(42):
#
#   T1  Tenant isolation (RLS)           6
#   T2  Double-entry create_sale_invoice 3
#   T3  Commission (consignment)         5
#   T4  record_payment                   3
#   E1  open-invoice count for C1        1
#   T5  get_party_statement              3   (incl. E2)
#   T6  adjust_inventory                 3
#   T7  Salaries (movement + pay)        3
#   T8  Idempotency (request_id)         3
#   T9  Reminders                        4   (incl. E3)
#   T10 Financial reports                8
#   ----------------------------------- 42
#
# Every assertion is either an invariant (`balanced = true`, `check = 0`,
# per-entity exact values on freshly created rows) or a delta over a baseline
# snapshot, because the dev tenant (owner4) accumulates rows across runs.
# IDs are threaded step-to-step (no temp tables over HTTP).
#
# Run:  .\m9_full_suite.ps1   (after migrations 0001-0021 in DEV SQL Editor)
# ============================================================
param(
    [string]$OwnerAEmail = "owner4@test.local",
    [string]$OwnerAPass  = "Test@1234567",
    [string]$OwnerBEmail = "owner2@test.local",
    [string]$OwnerBPass  = "Test@654321",
    [string]$WebhookId   = "e25fcb29-43c1-4bc1-9f51-58e1cdab2ff7"
)

$url = "https://sxasnunzspkuwbxiddqd.supabase.co"
$key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN4YXNudW56c3BrdXdieGlkZHFkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg3MDYyNDIsImV4cCI6MjEwNDI4MjI0Mn0.6zYdwBewK7t4P7w7w_-BYTXI1rolSeb0Zd6jteyJsUk"
$headers = @{ apikey = $key; "Content-Type" = "application/json" }

$script:Pass = 0
$script:Fail = 0

function Get-Token([string]$email, [string]$pass) {
    $body = @{ email = $email; password = $pass } | ConvertTo-Json
    $r = Invoke-RestMethod -Method Post -Uri "$url/auth/v1/token?grant_type=password" -Headers $headers -Body $body -ErrorAction Stop
    return $r.access_token
}

Write-Host "Logging in (tenant A = owner4, tenant B = owner2)..."
$tokA = Get-Token $OwnerAEmail $OwnerAPass
$tokB = Get-Token $OwnerBEmail $OwnerBPass

# Tenant A (owner4) - write headers (Prefer return=representation) + read headers
$h4 = @{ apikey = $key; Authorization = "Bearer " + $tokA; "Content-Type" = "application/json"; "Prefer" = "return=representation" }
$h4g = @{ apikey = $key; Authorization = "Bearer " + $tokA; "Content-Type" = "application/json" }
# Tenant B (owner2)
$h2 = @{ apikey = $key; Authorization = "Bearer " + $tokB; "Content-Type" = "application/json"; "Prefer" = "return=representation" }
$h2g = @{ apikey = $key; Authorization = "Bearer " + $tokB; "Content-Type" = "application/json" }
Write-Host "  OK: tokens acquired"

# PowerShell 5.1 sends -Body strings as ISO-8859-1 by default, which replaces
# Arabic with '?' on the wire. Encode as UTF-8 bytes so Arabic survives.
function Invoke-Json {
    param([string]$Method, [string]$Uri, [object]$Body, [hashtable]$H = $h4)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes(($Body | ConvertTo-Json -Depth 10))
    try {
        return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $H -ContentType "application/json; charset=utf-8" -Body $bytes -ErrorAction Stop
    } catch {
        $detail = ""
        if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
            $detail = $_.ErrorDetails.Message
        } elseif ($_.Exception.Response) {
            try {
                $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
                $detail = $reader.ReadToEnd()
            } catch {}
        }
        throw "API/RPC failed: $($_.Exception.Message) :: $detail"
    }
}

function Invoke-RPC {
    param([string]$name, [hashtable]$p, [hashtable]$H = $h4)
    return Invoke-Json -Method "Post" -Uri "$url/rest/v1/rpc/$name" -Body $p -H $H
}

# pgTAP lives_ok equivalent: run a scriptblock, count pass/fail, keep going.
# optional $captureVar stores the scriptblock output in SCRIPT scope.
function Invoke-Ok {
    param([string]$label, [scriptblock]$scriptBlock, [string]$captureVar = "")
    try {
        $res = & $scriptBlock
        if ($captureVar) { Set-Variable -Name $captureVar -Value $res -Scope Script }
        $script:Pass++
        Write-Host "  OK: $label"
    } catch {
        $script:Fail++
        Write-Host "  FAIL: $label :: $($_.Exception.Message)"
    }
}

function Assert-Equal([string]$label, $expected, $actual) {
    $expNum = 0.0
    $actNum = 0.0
    $isNum = [double]::TryParse([string]$expected, [ref]$expNum) -and [double]::TryParse([string]$actual, [ref]$actNum)
    if ($isNum) {
        if ([math]::Abs($expNum - $actNum) -gt 0.0001) {
            $script:Fail++
            Write-Host "  FAIL: $label expected [$expected] got [$actual]"
        } else {
            $script:Pass++
            Write-Host "  OK: $label = $actual"
        }
    } else {
        if ([string]$expected -ne [string]$actual) {
            $script:Fail++
            Write-Host "  FAIL: $label expected [$expected] got [$actual]"
        } else {
            $script:Pass++
            Write-Host "  OK: $label = $actual"
        }
    }
}

function Assert-True([string]$label, $condition) {
    if ($condition) {
        $script:Pass++
        Write-Host "  OK: $label"
    } else {
        $script:Fail++
        Write-Host "  FAIL: $label (condition false)"
    }
}

function Get-RelDate([string]$d, [int]$days) {
    return ([datetime]::ParseExact($d, 'yyyy-MM-dd', $null)).AddDays($days).ToString('yyyy-MM-dd')
}

# PS 5.1 returns $null for an empty JSON array body -> a count-of-$null breaks
# "expect 0 rows" assertions. Normalize multi-row/empty to a real integer count.
function Get-RowCount([string]$uri, [hashtable]$H = $h4g) {
    $r = Invoke-RestMethod -Method Get -Uri $uri -Headers $H
    if ($null -eq $r) { return 0 }
    return @($r).Count
}

function Test-Summary {
    Write-Host ""
    Write-Host "TOTAL: $script:Pass passed, $script:Fail failed"
    if ($script:Fail -gt 0) { $script:failed = $true }
}

# ---------------------------------------------------------------------------
# BASELINE SNAPSHOT
# ---------------------------------------------------------------------------
Write-Host "`n--- Baseline snapshot ---"
$runId = [guid]::NewGuid().ToString("N").Substring(0, 8)
Write-Host "  run id: $runId"

$baseDash = Invoke-RPC -name "get_dashboard_summary" -p @{}
$today = $baseDash.last_7_days[-1].date
$d1  = Get-RelDate $today -1
$d3  = Get-RelDate $today -3
$d5  = Get-RelDate $today -5
$d30 = Get-RelDate $today -30
$thisMonth = $today.Substring(0, 7)
$mFirst = "$thisMonth-01"
$tenantIdA = (Invoke-RestMethod -Method Get -Uri "$url/rest/v1/tenants?select=id&limit=1" -Headers $h4g)[0].id
$tenantIdB = (Invoke-RestMethod -Method Get -Uri "$url/rest/v1/tenants?select=id&limit=1" -Headers $h2g)[0].id
Write-Host "  DB today: $today   tenant A: $tenantIdA   tenant B: $tenantIdB"

$baseJournal = Invoke-RPC -name "get_journal_entries" -p @{ p_from = $d30; p_to = $today }
$baseEntryIds = @($baseJournal | ForEach-Object { $_.entry_id })

# ---------------------------------------------------------------------------
# T1: TENANT ISOLATION (RLS)
# ---------------------------------------------------------------------------
Write-Host "`n--- T1: Tenant isolation (RLS) ---"
Assert-Equal "A sees its own tenant row" 1 (Get-RowCount "$url/rest/v1/tenants?select=id&id=eq.$tenantIdA" $h4g)

# Name-based, run-scoped: both tenants created rows here, so match on the unique
# per-run name token, not on shared prefixes or full-row counts.
$c1 = Invoke-Json -Method "Post" -Uri "$url/rest/v1/customers" -Body @{ name = "عميل M9T1-A-$runId"; phone = "0599000001" }
$c1Id = $c1[0].id
$c2 = Invoke-Json -Method "Post" -Uri "$url/rest/v1/customers" -Body @{ name = "عميل M9T1-B-$runId"; phone = "0599000002" } -H $h2
$c2Id = $c2[0].id
$nA = "M9T1-A-$runId"
$nB = "M9T1-B-$runId"

Assert-Equal "A sees customer C1 by name" 1 (Get-RowCount "$url/rest/v1/customers?select=id&name=like.*${nA}*" $h4g)
Assert-Equal "B sees 0 of A's C1 (isolated)" 0 (Get-RowCount "$url/rest/v1/customers?select=id&name=like.*${nA}*" $h2g)
Assert-Equal "B sees customer C2 by name" 1 (Get-RowCount "$url/rest/v1/customers?select=id&name=like.*${nB}*" $h2g)
Assert-Equal "A sees 0 of B's C2 (isolated)" 0 (Get-RowCount "$url/rest/v1/customers?select=id&name=like.*${nB}*" $h4g)
Assert-Equal "B sees its own tenant row" 1 (Get-RowCount "$url/rest/v1/tenants?select=id&id=eq.$tenantIdB" $h2g)

# ---------------------------------------------------------------------------
# T2: DOUBLE-ENTRY create_sale_invoice
# ---------------------------------------------------------------------------
Write-Host "`n--- T2: Double-entry create_sale_invoice ---"
$p1 = Invoke-Json -Method "Post" -Uri "$url/rest/v1/products" -Body @{
    name = "M9T2 P1 $runId"; unit = "قطعة"; unit_type = "count"
    sale_price = 10000; purchase_price = 6000; qty = 100; reorder_level = 10
}
$p1Id = $p1[0].id

$t2 = $null
Invoke-Ok -label "create_sale_invoice (2x10000) succeeds" -scriptBlock {
    Invoke-RPC -name "create_sale_invoice" -p @{
        p_request_id = [guid]::NewGuid().ToString()
        p_customer_id = $c1Id
        p_items = @( @{ product_id = $p1Id; qty = 2; price = 10000 } )
        p_invoice_date = $today
        p_paid = 0
        p_payment_method = "cash"
        p_memo = "M9T2 sale $runId"
    }
} -captureVar "t2"
$t2Inv = $t2.invoice_id

$entry2 = (Invoke-RPC -name "get_journal_entries" -p @{ p_from = $d30; p_to = $today } | Where-Object { $_.memo -eq "M9T2 sale $runId" })[0]
if ($null -ne $entry2) {
    $dr2 = 0.0; $cr2 = 0.0
    foreach ($l in $entry2.lines) { if ($l.debit) { $dr2 += $l.debit }; if ($l.credit) { $cr2 += $l.credit } }
    Assert-Equal "sale journal entry balanced (sum debit = sum credit)" $dr2 $cr2
} else {
    $script:Fail++
    Write-Host "  FAIL: sale journal entry balanced (entry not found by memo)"
}
Assert-Equal "inventory deducted (100 - 2 = 98)" 98 (Invoke-RestMethod -Method Get -Uri "$url/rest/v1/products?select=qty&id=eq.$p1Id" -Headers $h4g).qty

# ---------------------------------------------------------------------------
# T3: COMMISSION (CONSIGNMENT)
# ---------------------------------------------------------------------------
Write-Host "`n--- T3: Commission (consignment) ---"
$s1 = Invoke-Json -Method "Post" -Uri "$url/rest/v1/suppliers" -Body @{ name = "M9T3 S1 $runId"; phone = "0599000003"; deal_type = "commission"; commission_rate = 20 }
$s1Id = $s1[0].id
$pc = Invoke-Json -Method "Post" -Uri "$url/rest/v1/products" -Body @{
    name = "M9T3 PC $runId"; unit = "قطعة"; unit_type = "count"
    sale_price = 15000; purchase_price = 5000; qty = 50; reorder_level = 5
}
$pcId = $pc[0].id
$custComm = Invoke-Json -Method "Post" -Uri "$url/rest/v1/customers" -Body @{ name = "M9T3 C $runId"; phone = "0599000004" }
$custCommId = $custComm[0].id

Invoke-Ok -label "consignment purchase (10 units) succeeds" -scriptBlock {
    Invoke-RPC -name "create_purchase_invoice" -p @{
        p_request_id = [guid]::NewGuid().ToString()
        p_supplier_id = $s1Id
        p_items = @( @{ product_id = $pcId; qty = 10 } )
        p_invoice_date = $today
        p_paid = 0
        p_payment_method = "cash"
        p_memo = "M9T3 consignment receipt $runId"
    }
}
# invoices has party_id (polymorphic customer/supplier), no supplier_id column.
$consInvs = Invoke-RestMethod -Method Get -Uri "$url/rest/v1/invoices?select=id,remaining&type=eq.purchase&party_id=eq.$s1Id&ownership=eq.consignment" -Headers $h4g
$rem3 = 0.0
foreach ($i in @($consInvs)) { if ($i.remaining) { $rem3 += $i.remaining } }
Assert-Equal "consignment receipt keeps remaining = total (50000; stock-only, not payable)" 50000 $rem3

$sale3 = $null
Invoke-Ok -label "consignment sale (3x15000) succeeds" -scriptBlock {
    Invoke-RPC -name "create_sale_invoice" -p @{
        p_request_id = [guid]::NewGuid().ToString()
        p_customer_id = $custCommId
        p_items = @( @{ product_id = $pcId; qty = 3; price = 15000 } )
        p_invoice_date = $today
        p_paid = 0
        p_payment_method = "cash"
        p_memo = "M9T3 consignment sale $runId"
    }
} -captureVar "sale3"
$sale3Inv = $sale3.invoice_id

# commission_dues columns are supplier_due / remaining (no 'due_amount'/'status').
$dues = Invoke-RestMethod -Method Get -Uri "$url/rest/v1/commission_dues?select=supplier_due,remaining&invoice_id=eq.$sale3Inv" -Headers $h4g
Assert-True "pending commission due (remaining>0) created for consignment sale" ((Get-RowCount "$url/rest/v1/commission_dues?select=id&invoice_id=eq.$sale3Inv&remaining=gt.0" $h4g) -ge 1)
$dueSum = 0.0
foreach ($d in @($dues)) { if ($d.supplier_due) { $dueSum += $d.supplier_due } }
Assert-Equal "commission supplier_due = 15000 * 0.80 * 3 = 36000" 36000 $dueSum

# ---------------------------------------------------------------------------
# T4: record_payment
# ---------------------------------------------------------------------------
Write-Host "`n--- T4: record_payment ---"
$pay4 = $null
Invoke-Ok -label "record_payment 10000 on unpaid 20000 invoice succeeds" -scriptBlock {
    Invoke-RPC -name "record_payment" -p @{
        p_request_id = [guid]::NewGuid().ToString()
        p_invoice_id = $t2Inv
        p_amount = 10000
        p_method = "cash"
        p_date = $today
    }
} -captureVar "pay4"
Assert-Equal "invoice status = partial after partial payment" "partial" (Invoke-RestMethod -Method Get -Uri "$url/rest/v1/invoices?select=status&id=eq.$t2Inv" -Headers $h4g).status

# Newest entry NOT in the baseline (results ordered by entry_no desc) is the payment
# journal created by record_payment above. get_journal_entries exposes entry_id (not id).
$afterPays = Invoke-RPC -name "get_journal_entries" -p @{ p_from = $d30; p_to = $today }
$newPay = @($afterPays | Where-Object { $baseEntryIds -notcontains $_.entry_id })[0]
if ($null -ne $newPay) {
    $drP = 0.0; $crP = 0.0
    foreach ($l in $newPay.lines) { if ($l.debit) { $drP += $l.debit }; if ($l.credit) { $crP += $l.credit } }
    Assert-Equal "payment journal entry balanced" $drP $crP
} else {
    $script:Fail++
    Write-Host "  FAIL: payment journal entry balanced (no new entry after record_payment)"
}

# ---------------------------------------------------------------------------
# E1: open-invoice count for C1
# ---------------------------------------------------------------------------
Assert-Equal "E1: C1 has exactly one open invoice" 1 (Invoke-RestMethod -Method Get -Uri "$url/rest/v1/invoices?select=id&party_id=eq.$c1Id&type=eq.sale&remaining=gt.0" -Headers $h4g).Count

# ---------------------------------------------------------------------------
# T5: get_party_statement (+E2)
# ---------------------------------------------------------------------------
Write-Host "`n--- T5: get_party_statement ---"
$stmt = Invoke-RPC -name "get_party_statement" -p @{
    p_party_type = "customer"; p_party_id = $c1Id; p_from = $d30; p_to = $today
}
Assert-True "statement envelope has opening balance" ($null -ne $stmt.opening)
Assert-True "statement envelope has lines array" ($null -ne $stmt.lines)
Assert-True "E2: statement has closing balance" ($null -ne $stmt.closing)

# ---------------------------------------------------------------------------
# T6: adjust_inventory
# ---------------------------------------------------------------------------
Write-Host "`n--- T6: adjust_inventory ---"
$adj = $null
Invoke-Ok -label "adjust_inventory 98 -> 105 succeeds" -scriptBlock {
    Invoke-RPC -name "adjust_inventory" -p @{
        p_product_id = $p1Id; p_counted_qty = 105; p_reason = "جرد شهري M9T6 $runId"
    }
} -captureVar "adj"
Assert-Equal "product qty now 105" 105 (Invoke-RestMethod -Method Get -Uri "$url/rest/v1/products?select=qty&id=eq.$p1Id" -Headers $h4g).qty
$moves6 = Invoke-RestMethod -Method Get -Uri "$url/rest/v1/stock_moves?select=ref,type&product_id=eq.$p1Id&type=eq.adjust" -Headers $h4g
Assert-True "stock_moves recorded with جرد: ref" (@($moves6 | Where-Object { $_.ref -like "جرد:*" }).Count -ge 1)

# ---------------------------------------------------------------------------
# T7: SALARIES
# ---------------------------------------------------------------------------
Write-Host "`n--- T7: Salaries ---"
$emp1 = Invoke-Json -Method "Post" -Uri "$url/rest/v1/employees" -Body @{
    name = "M9T7 E1 $runId"; job_title = "محاسب"; phone = "0599000005"; base_salary = 500000
}
$emp1Id = $emp1[0].id

# add_employee_movement(p_request_id,uuid,...): p_request_id is FIRST and required;
# p_direction is 'in'|'out' (never 'deduct'); cash deductions use 'out'+'advance',
# and the description param is p_description. pay_salary also requires p_request_id first.
$mov7 = $null
Invoke-Ok -label "add_employee_movement (advance 50000 out) succeeds" -scriptBlock {
    Invoke-RPC -name "add_employee_movement" -p @{
        p_request_id = [guid]::NewGuid().ToString()
        p_employee_id = $emp1Id
        p_month = $mFirst
        p_direction = "out"
        p_category = "advance"
        p_amount = 50000
        p_description = "سلفة M9T7"
        p_date = $today
    }
} -captureVar "mov7"
$pay7 = $null
Invoke-Ok -label "pay_salary (450000 bank) succeeds" -scriptBlock {
    Invoke-RPC -name "pay_salary" -p @{
        p_request_id = [guid]::NewGuid().ToString()
        p_employee_id = $emp1Id
        p_month = $mFirst
        p_paid = 450000
        p_method = "bank"
        p_date = $today
        p_note = "راتب M9T7"
    }
} -captureVar "pay7"
Assert-True "T7: movement 50000, net_due 450000, paid 450000, one salary row" (
    ($null -ne $mov7 -and $mov7.amount -eq 50000) -and
    ($null -ne $pay7) -and
    ($pay7.net_due -eq 450000) -and
    ($pay7.paid -eq 450000) -and
    ((Get-RowCount "$url/rest/v1/salaries?select=id&employee_id=eq.$emp1Id" $h4g) -eq 1)
)

# ---------------------------------------------------------------------------
# T8: IDEMPOTENCY (p_request_id)
# ---------------------------------------------------------------------------
Write-Host "`n--- T8: Idempotency ---"
$p2 = Invoke-Json -Method "Post" -Uri "$url/rest/v1/products" -Body @{
    name = "M9T8 P2 $runId"; unit = "قطعة"; unit_type = "count"
    sale_price = 10000; purchase_price = 6000; qty = 20; reorder_level = 2
}
$p2Id = $p2[0].id
$c8 = Invoke-Json -Method "Post" -Uri "$url/rest/v1/customers" -Body @{ name = "M9T8 C $runId"; phone = "0599000006" }
$c8Id = $c8[0].id
$req8 = [guid]::NewGuid().ToString()

# Idempotency lives on invoices.request_id (0007): a replayed call returns
# {duplicate:true, invoice:{...original}} and never writes a second invoice.
# processed_requests is NOT used by create_sale_invoice, so assert on invoices.
$inv8a = $null
Invoke-Ok -label "first create_sale_invoice with request_id succeeds" -scriptBlock {
    Invoke-RPC -name "create_sale_invoice" -p @{
        p_request_id = $req8
        p_customer_id = $c8Id
        p_items = @( @{ product_id = $p2Id; qty = 1; price = 10000 } )
        p_invoice_date = $today
        p_paid = 0
        p_payment_method = "cash"
        p_memo = "M9T8 idem 1 $runId"
    }
} -captureVar "inv8a"
$inv8b = $null
Invoke-Ok -label "second call with SAME request_id succeeds (no duplicate)" -scriptBlock {
    Invoke-RPC -name "create_sale_invoice" -p @{
        p_request_id = $req8
        p_customer_id = $c8Id
        p_items = @( @{ product_id = $p2Id; qty = 1; price = 10000 } )
        p_invoice_date = $today
        p_paid = 0
        p_payment_method = "cash"
        p_memo = "M9T8 idem 2 $runId"
    }
} -captureVar "inv8b"
$idemOk = $false
if ($null -ne $inv8a -and $null -ne $inv8b -and $inv8b.duplicate) {
    $idemOk = (($inv8b.invoice.id -eq $inv8a.invoice_id) -and
               ((Get-RowCount "$url/rest/v1/invoices?select=id&request_id=eq.$req8" $h4g) -eq 1))
}
Assert-True "T8: replay returns duplicate + same invoice id + single invoice row" $idemOk

# ---------------------------------------------------------------------------
# T9: REMINDERS (+E3)
# ---------------------------------------------------------------------------
Write-Host "`n--- T9: Reminders ---"
$r1 = Invoke-Json -Method "Post" -Uri "$url/rest/v1/customers" -Body @{ name = "M9T9 R1 $runId"; phone = "0599000101" }
$r1Id = $r1[0].id
$rp = Invoke-Json -Method "Post" -Uri "$url/rest/v1/products" -Body @{
    name = "M9T9 RP $runId"; unit = "قطعة"; unit_type = "count"
    sale_price = 10000; purchase_price = 5000; qty = 10; reorder_level = 1
}
$rpId = $rp[0].id

$inv9Resp = Invoke-RPC -name "create_sale_invoice" -p @{
    p_request_id = [guid]::NewGuid().ToString()
    p_customer_id = $r1Id
    p_items = @( @{ product_id = $rpId; qty = 2; price = 10000 } )
    p_invoice_date = $today
    p_paid = 0
    p_payment_method = "cash"
    p_memo = "M9T9 reminder $runId"
}
$inv9 = $inv9Resp.invoice_id

# Fresh R2 with a new unpaid owned sale: gives send_reminders_to_all a customer
# that is NOT already deduped today (R1 gets logged by send_reminder_now below).
$r2 = Invoke-Json -Method "Post" -Uri "$url/rest/v1/customers" -Body @{ name = "M9T9 R2 $runId"; phone = "0599000102" }
$r2Id = $r2[0].id
$inv9R2 = Invoke-RPC -name "create_sale_invoice" -p @{
    p_request_id = [guid]::NewGuid().ToString()
    p_customer_id = $r2Id
    p_items = @( @{ product_id = $rpId; qty = 1; price = 10000 } )
    p_invoice_date = $today
    p_paid = 0
    p_payment_method = "cash"
    p_memo = "M9T9 reminder R2 $runId"
}

# Webhook + threshold (0 => any unpaid owned sale dated <= today is due).
Invoke-Json -Method "Patch" -Uri "$url/rest/v1/tenant_settings?tenant_id=eq.$tenantIdA" -Body @{
    reminder_webhook_url = "https://webhook.site/$WebhookId"
    reminder_message = "M9T9: {customer_name} - {amount}"
    reminder_days_threshold = 0
} | Out-Null

$rem9 = $null
Invoke-Ok -label "send_reminder_now succeeds for customer with outstanding balance" -scriptBlock {
    Invoke-RPC -name "send_reminder_now" -p @{ p_customer_id = $r1Id }
} -captureVar "rem9"

# T9: verify the settings PATCH persisted (so a webhook-missing 400 can't
# masquerade as a pg_net issue) AND the fire logged a 'sent' row for R1 today.
$webhookSet = $false
$ts9 = Invoke-RestMethod -Method Get -Uri "$url/rest/v1/tenant_settings?select=reminder_webhook_url&tenant_id=eq.$tenantIdA" -Headers $h4g
if ($null -ne $ts9 -and $null -ne $ts9.reminder_webhook_url -and ($ts9.reminder_webhook_url -like "*webhook.site*")) { $webhookSet = $true }
Assert-True "T9: webhook persisted + reminder_log sent row for R1 today" (
    $webhookSet -and $null -ne $rem9 -and $rem9.status -eq "sent" -and
    ((Get-RowCount "$url/rest/v1/reminder_log?select=id&customer_id=eq.$r1Id&status=eq.sent&created_at=gte.$today" $h4g) -ge 1)
)
$all = $null
Invoke-Ok -label "send_reminders_to_all succeeds" -scriptBlock {
    Invoke-RPC -name "send_reminders_to_all" -p @{}
} -captureVar "all"
Assert-True "E3: send_reminders_to_all returns sent >= 1" ($null -ne $all -and $null -ne $all.sent -and [int64]$all.sent -ge 1)

# ---------------------------------------------------------------------------
# T10: FINANCIAL REPORTS
# ---------------------------------------------------------------------------
Write-Host "`n--- T10: Financial reports ---"
$bDash = $null
Invoke-Ok -label "get_dashboard_summary succeeds" -scriptBlock { Invoke-RPC -name "get_dashboard_summary" -p @{} } -captureVar "bDash"
Assert-Equal "dashboard last_7_days has 7 points" 7 @($bDash.last_7_days).Count
Invoke-Ok -label "get_chart_of_accounts succeeds" -scriptBlock { Invoke-RPC -name "get_chart_of_accounts" -p @{} }
$bTb = $null
Invoke-Ok -label "get_trial_balance succeeds" -scriptBlock { Invoke-RPC -name "get_trial_balance" -p @{ p_as_of_date = $today } } -captureVar "bTb"
$balancedFlag = $false
if ($null -ne $bTb.balanced) {
    $balancedFlag = [bool]$bTb.balanced
} elseif ($null -ne $bTb.totals -and $null -ne $bTb.totals.debit) {
    $balancedFlag = ([math]::Abs([double]$bTb.totals.debit - [double]$bTb.totals.credit) -le 0.0001)
}
Assert-True "trial balance reports balanced = true" $balancedFlag
Invoke-Ok -label "get_income_statement succeeds" -scriptBlock { Invoke-RPC -name "get_income_statement" -p @{ p_from = $d30; p_to = $today } }
$bSheet = $null
Invoke-Ok -label "get_balance_sheet succeeds" -scriptBlock { Invoke-RPC -name "get_balance_sheet" -p @{ p_as_of_date = $today } } -captureVar "bSheet"
$chk = $null
if ($null -ne $bSheet.check) { $chk = $bSheet.check } elseif ($null -ne $bSheet.sheet_check) { $chk = $bSheet.sheet_check }
Assert-Equal "balance sheet check = 0 (balanced)" 0 $chk

# ---------------------------------------------------------------------------
Test-Summary

# Double-click safe: keep the console open so the TOTAL line stays visible.
# Automated runs (redirected input) skip the pause; the exit code is preserved.
if (-not [Console]::IsInputRedirected) { Read-Host "`nPress Enter to close" }
if ($script:failed) { exit 1 }
exit 0