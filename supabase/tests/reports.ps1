# ============================================================
# M7 REPORTS & DASHBOARD - end-to-end regression (migration 0019)
# Verifies: get_dashboard_summary, get_chart_of_accounts,
# create_account, create_journal_entry (balanced + idempotent),
# get_journal_entries, get_ledger (opening + running balance),
# get_trial_balance (Sigma Dr = Sigma Cr), get_income_statement,
# get_balance_sheet (assets = liabilities + equity, check = 0).
#
# The dev tenant (owner4) already contains rows from earlier test
# runs, so every aggregate assertion is a DELTA over a baseline
# snapshot taken before this scenario runs. Per-account assertions
# use a freshly created account (no prior history) so they are
# exact. Run AFTER pasting 0019_reports.sql in the SQL Editor.
# ============================================================
param(
    [string]$OwnerEmail = "owner4@test.local",
    [string]$OwnerPass  = "Test@1234567"
)

$url = "https://sxasnunzspkuwbxiddqd.supabase.co"
$key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN4YXNudW56c3BrdXdieGlkZHFkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg3MDYyNDIsImV4cCI6MjEwNDI4MjI0Mn0.6zYdwBewK7t4P7w7w_-BYTXI1rolSeb0Zd6jteyJsUk"
$headers = @{ apikey = $key; "Content-Type" = "application/json" }

Write-Host "Logging in..."
$loginBody = @{ email = $OwnerEmail; password = $OwnerPass } | ConvertTo-Json
$resp = Invoke-RestMethod -Method Post -Uri "$url/auth/v1/token?grant_type=password" -Headers $headers -Body $loginBody
$h4 = @{
    apikey = $key
    Authorization = "Bearer " + $resp.access_token
    "Content-Type" = "application/json"
    "Prefer" = "return=representation"
}
Write-Host "Login successful"

# PowerShell 5.1 sends -Body strings as ISO-8859-1 by default, which replaces
# Arabic with '?' on the wire. Encode as UTF-8 bytes so Arabic survives.
function Invoke-Json {
    param([string]$Method, [string]$Uri, [object]$Body)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes(($Body | ConvertTo-Json -Depth 10))
    try {
        return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $h4 -ContentType "application/json; charset=utf-8" -Body $bytes
    } catch {
        $detail = ""
        if ($_.Exception.Response) {
            try {
                $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
                $detail = $reader.ReadToEnd()
            } catch {}
        }
        throw "API/RPC failed: $($_.Exception.Message) :: $detail"
    }
}

function Invoke-RPC {
    param([string]$name, [hashtable]$p)
    return Invoke-Json -Method "Post" -Uri "$url/rest/v1/rpc/$name" -Body $p
}

function Assert-Equal([string]$label, $expected, $actual) {
    # Try numeric comparison
    $expNum = 0.0
    $actNum = 0.0
    $isNum = [double]::TryParse($expected, [ref]$expNum) -and [double]::TryParse($actual, [ref]$actNum)
    if ($isNum) {
        if ([math]::Abs($expNum - $actNum) -gt 0.0001) {
            throw "FAIL: $label expected [$expected] got [$actual]"
        }
    } else {
        if ([string]$expected -ne [string]$actual) {
            throw "FAIL: $label expected [$expected] got [$actual]"
        }
    }
    Write-Host "  OK: $label = $actual"
}

function Get-RelDate([string]$d, [int]$days) {
    return ([datetime]::ParseExact($d, 'yyyy-MM-dd', $null)).AddDays($days).ToString('yyyy-MM-dd')
}

$runId = [guid]::NewGuid().ToString()

# ---------------------------------------------------------------------------
# BASELINE SNAPSHOT (before our scenario touches anything)
# ---------------------------------------------------------------------------
Write-Host "`n--- Baseline snapshot ---"
$baseDash    = Invoke-RPC -name "get_dashboard_summary" -p @{}
$today       = $baseDash.last_7_days[-1].date
$d1          = Get-RelDate $today -1
$d3          = Get-RelDate $today -3
$d5          = Get-RelDate $today -5
Write-Host "  DB today: $today  (scenario dates: $d5 / $d3 / $d1 / $today)"

$baseTB      = Invoke-RPC -name "get_trial_balance" -p @{ p_as_of_date = $today }
$baseIncome  = Invoke-RPC -name "get_income_statement" -p @{ p_from = $d3; p_to = $today }
$baseSheet   = Invoke-RPC -name "get_balance_sheet" -p @{ p_as_of_date = $today }
$baseJournal = Invoke-RPC -name "get_journal_entries" -p @{ p_from = $d5; p_to = $today }
$baseChart   = Invoke-RPC -name "get_chart_of_accounts" -p @{}

# Precondition sanity: the ledger must already be balanced.
Assert-Equal "baseline Sigma Dr = Sigma Cr" $baseTB.totals.debit $baseTB.totals.credit
Write-Host "  baseline: chart=$($baseChart.Count) journal(count in $d5..$today)=$($baseJournal.Count) tbDr=$($baseTB.totals.debit) incomeNet=$($baseIncome.net) sheetCheck=$($baseSheet.check)"

$cashAcct = ($baseChart | Where-Object { $_.code -eq '1010' })[0].account_id
if (-not $cashAcct) { throw "Cash account 1010 not found in chart" }

# ---------------------------------------------------------------------------
# SCENARIO DATA
#   owned purchase 7x@60=420 (d1)      -> DR Inventory CR AP
#   sale A 2x@100=200 (d3)             -> DR AR CR Revenue
#   payment 80 on sale B (d1)          -> DR Cash CR AR
#   sale B 2x@100=200, paid 80 (today) -> DR AR CR Revenue
#   manual M1 50 (d5) on NEW account   -> DR Expense CR Cash
#   manual M2 22 (d3) on NEW account   -> DR Expense CR Cash
# Totals: Dr 420+200+200+80+50+22 = 972, same Cr. 6 journal entries.
# ---------------------------------------------------------------------------
Write-Host "`n--- Setup: customer, supplier, products ---"
$cust = Invoke-Json -Method "Post" -Uri "$url/rest/v1/customers" -Body @{ name = "عميل M7 $runId" }
$custId = $cust[0].id

$supp = Invoke-Json -Method "Post" -Uri "$url/rest/v1/suppliers" -Body @{ name = "مورد M7 $runId"; deal_type = "direct" }
$suppId = $supp[0].id

function New-Product {
    param([string]$name, [int]$salePrice, [int]$purchasePrice, [int]$qty, [int]$reorder)
    $body = @{ name = $name; unit = "قطعة"; unit_type = "count"; sale_price = $salePrice; purchase_price = $purchasePrice; qty = $qty; reorder_level = $reorder }
    $r = Invoke-Json -Method "Post" -Uri "$url/rest/v1/products" -Body $body
    return $r[0].id
}

$prodId = New-Product "منتج M7 $runId" 100 60 500 0
$alertPid = New-Product "منتج تنبيه M7 $runId" 100 60 3 10   # low-stock alert, qty <= reorder

Write-Host "Creating invoices, payment, ledger account ..."
$pur = Invoke-RPC -name "create_purchase_invoice" -p @{
    p_request_id     = [guid]::NewGuid().ToString()
    p_supplier_id    = $suppId
    p_items          = @( @{ product_id = $prodId; qty = 7; price = 60 } )
    p_invoice_date   = $d1
    p_paid           = 0
    p_payment_method = "cash"
}
if (-not $pur.invoice_id) { throw "owned purchase failed" }
if ($pur.total -ne 420) { throw "purchase total should be 420, got $($pur.total)" }

$saleA = Invoke-RPC -name "create_sale_invoice" -p @{
    p_request_id     = [guid]::NewGuid().ToString()
    p_customer_id    = $custId
    p_items          = @( @{ product_id = $prodId; qty = 2; price = 100 } )
    p_invoice_date   = $d3
    p_paid           = 0
    p_payment_method = "cash"
}
if (-not $saleA.invoice_id) { throw "sale A failed" }
if ($saleA.total -ne 200) { throw "sale A total should be 200, got $($saleA.total)" }

$saleB = Invoke-RPC -name "create_sale_invoice" -p @{
    p_request_id     = [guid]::NewGuid().ToString()
    p_customer_id    = $custId
    p_items          = @( @{ product_id = $prodId; qty = 2; price = 100 } )
    p_invoice_date   = $today
    p_paid           = 0
    p_payment_method = "cash"
}
if (-not $saleB.invoice_id) { throw "sale B failed" }

$pay = Invoke-RPC -name "record_payment" -p @{
    p_request_id = [guid]::NewGuid().ToString()
    p_invoice_id = $saleB.invoice_id
    p_amount     = 80
    p_method     = "cash"
    p_date       = $d1
}
if (-not $pay.payment_id) { throw "payment failed" }

# Fresh expense account (unique code -> no prior history, exact assertions).
$acctRes = $null
for ($i = 0; $i -lt 5; $i++) {
    $code = "5" + (Get-Random -Minimum 100 -Maximum 999)
    $acctRes = Invoke-RPC -name "create_account" -p @{ p_code = $code; p_name = "مصاريف M7 $runId"; p_type = "expense" }
    if (-not $acctRes.duplicate) { break }
}
if ($acctRes.duplicate) { throw "could not allocate a fresh expense account code" }
if ($acctRes.code -ne $code) { throw "create_account returned wrong code $($acctRes.code)" }
$newAcctId = $acctRes.account_id
Write-Host "  ledger account: $code ($newAcctId)"

$memoM1 = "قيد يدوي أول M7 $runId"
$memoM2 = "قيد يدوي ثاني M7 $runId"

$m1 = Invoke-RPC -name "create_journal_entry" -p @{
    p_request_id = [guid]::NewGuid().ToString()
    p_date       = $d5
    p_memo       = $memoM1
    p_lines      = @(
        @{ account_id = $newAcctId; debit = 50; credit = 0 },
        @{ account_id = $cashAcct;  debit = 0;  credit = 50 }
    )
}
if (-not $m1.entry_id) { throw "manual entry M1 failed" }
if ($m1.total -ne 50) { throw "M1 total should be 50, got $($m1.total)" }

$m2ReqId = [guid]::NewGuid().ToString()
$m2 = Invoke-RPC -name "create_journal_entry" -p @{
    p_request_id = $m2ReqId
    p_date       = $d3
    p_memo       = $memoM2
    p_lines      = @(
        @{ account_id = $newAcctId; debit = 22; credit = 0 },
        @{ account_id = $cashAcct;  debit = 0;  credit = 22 }
    )
}
if (-not $m2.entry_id) { throw "manual entry M2 failed" }

# ---------------------------------------------------------------------------
# 1) DASHBOARD
# ---------------------------------------------------------------------------
Write-Host "`n--- 1) get_dashboard_summary ---"
$dash = Invoke-RPC -name "get_dashboard_summary" -p @{}
Assert-Equal "today_sales +200" ($baseDash.today_sales + 200) $dash.today_sales
Assert-Equal "today_purchases unchanged" $baseDash.today_purchases $dash.today_purchases
Assert-Equal "customer_debts +320" ($baseDash.customer_debts + 320) $dash.customer_debts
Assert-Equal "supplier_debts +420" ($baseDash.supplier_debts + 420) $dash.supplier_debts
Assert-Equal "month_expenses unchanged" $baseDash.month_expenses $dash.month_expenses
Assert-Equal "month_salaries unchanged" $baseDash.month_salaries $dash.month_salaries

# Month-cost deltas depend on whether T-5/T-3 fall inside the current DB month.
$revInMonth = 200                                     # sale B is always today
if ($d3.Substring(0, 7) -eq $today.Substring(0, 7)) { $revInMonth += 200 }  # sale A
$expInMonth = 0
if ($d5.Substring(0, 7) -eq $today.Substring(0, 7)) { $expInMonth += 50 }   # M1
if ($d3.Substring(0, 7) -eq $today.Substring(0, 7)) { $expInMonth += 22 }   # M2
$netDelta = $revInMonth - $expInMonth
Assert-Equal "net_profit_month +$netDelta" ($baseDash.net_profit_month + $netDelta) $dash.net_profit_month

if ($dash.last_7_days.Count -ne 7) { throw "last_7_days should have 7 points, got $($dash.last_7_days.Count)" }
Assert-Equal "last_7_days last date == today" $today $dash.last_7_days[-1].date
$last7Sales = 0; $last7Purch = 0
foreach ($p in $dash.last_7_days) { $last7Sales += $p.sales; $last7Purch += $p.purchases }
$baseLast7Sales = 0; $baseLast7Purch = 0
foreach ($p in $baseDash.last_7_days) { $baseLast7Sales += $p.sales; $baseLast7Purch += $p.purchases }
Assert-Equal "last7 sales +400" ($baseLast7Sales + 400) $last7Sales
Assert-Equal "last7 purchases +420" ($baseLast7Purch + 420) $last7Purch

# top_debtors is the TOP 5 by balance, and the dev tenant already has larger
# debtors, so our fresh customer may not rank. Assert structure and use a
# deterministic membership probe only when the top-5 quota is not full.
$topRows = $dash.top_debtors
if ($topRows -isnot [System.Array]) { $topRows = @($topRows) }
if ($topRows.Count -gt 5) { throw "top_debtors must be at most 5, got $($topRows.Count)" }
if ($topRows.Count -eq 0) { throw "top_debtors should list outstanding balances" }
$prevBal = [int]$topRows[0].balance
foreach ($row in $topRows) {
    if (-not $row.customer_id) { throw "top_debtor entry missing customer_id" }
    if (-not $row.name) { throw "top_debtor entry missing name" }
    $bal = [int]$row.balance
    if ($bal -le 0) { throw "top_debtor balance must be > 0, got $($row.balance)" }
    if ($bal -gt $prevBal) { throw "top_debtors not sorted by balance desc" }
    $prevBal = $bal
}
$debtor = @($topRows | Where-Object { $_.customer_id -eq $custId })
if ($topRows.Count -lt 5 -and $debtor.Count -eq 0) {
    throw "top_debtors has < 5 entries yet still misses our customer"
}
if ($debtor.Count -gt 0) { Assert-Equal "top_debtor balance = 320" 320 $debtor[0].balance }

$alert = @($dash.low_stock | Where-Object { $_.product_id -eq $alertPid })
if ($alert.Count -eq 0) { throw "low_stock missing alert product" }
Assert-Equal "low_stock qty shown" 3 $alert[0].qty

# ---------------------------------------------------------------------------
# 2) CHART OF ACCOUNTS
# ---------------------------------------------------------------------------
Write-Host "`n--- 2) get_chart_of_accounts / create_account ---"
$chart = Invoke-RPC -name "get_chart_of_accounts" -p @{}
if ($chart.Count -ne ($baseChart.Count + 1)) { throw "chart count should be base+1, got $($chart.Count)" }
$accRow = ($chart | Where-Object { $_.code -eq $code })[0]
if (-not $accRow) { throw "new account $code missing from chart" }
if ($accRow.type -ne "expense") { throw "new account type should be expense, got $($accRow.type)" }
Assert-Equal "new account balance = 72 (50@d5 + 22@d3)" 72 $accRow.balance

$dup = Invoke-RPC -name "create_account" -p @{ p_code = $code; p_name = "تكرار"; p_type = "expense" }
if (-not $dup.duplicate) { throw "duplicate code $code should return duplicate=true" }

# ---------------------------------------------------------------------------
# 3) LEDGER (fresh account => exact numbers)
# ---------------------------------------------------------------------------
Write-Host "`n--- 3) get_ledger ---"
$led1 = Invoke-RPC -name "get_ledger" -p @{ p_account_id = $newAcctId; p_from = $d3; p_to = $today }
Assert-Equal "opening before $d3 (M1@$d5)" 50 $led1.opening
if ($led1.lines.Count -ne 1) { throw "expected 1 line (M2@$d3), got $($led1.lines.Count)" }
Assert-Equal "line debit 22" 22 $led1.lines[0].debit
Assert-Equal "running balance 72" 72 $led1.lines[0].balance
Assert-Equal "closing 72" 72 $led1.closing

$led2 = Invoke-RPC -name "get_ledger" -p @{ p_account_id = $newAcctId; p_from = $d5; p_to = $today }
Assert-Equal "opening from $d5 = 0" 0 $led2.opening
if ($led2.lines.Count -ne 2) { throw "expected 2 lines (M1+M2), got $($led2.lines.Count)" }
Assert-Equal "line1 balance 50" 50 $led2.lines[0].balance
Assert-Equal "line2 balance 72" 72 $led2.lines[1].balance
Assert-Equal "closing 72" 72 $led2.closing

Write-Host "  unknown account rejected ..."
try {
    Invoke-RPC -name "get_ledger" -p @{ p_account_id = "00000000-0000-0000-0000-000000000000"; p_from = $d3; p_to = $today } | Out-Null
    throw "FAIL: unknown ledger account not rejected"
} catch {
    if ($_.Exception.Message -match "FAIL:") { throw }
    Write-Host "  OK: rejected as expected"
}

# ---------------------------------------------------------------------------
# 4) JOURNAL
# ---------------------------------------------------------------------------
Write-Host "`n--- 4) get_journal_entries ---"
$journal = Invoke-RPC -name "get_journal_entries" -p @{ p_from = $d5; p_to = $today }
if ($journal.Count -ne ($baseJournal.Count + 6)) {
    throw "journal count should be base+6 (purchase, saleA, saleB, payment, M1, M2), got $($journal.Count) vs base $($baseJournal.Count)"
}
$m1row = $journal | Where-Object { $_.memo -eq $memoM1 }
if (-not $m1row) { throw "manual entry M1 missing from journal listing" }
# Use the first line's debit (or credit) because total might be sum of both sides
$m1Amount = $m1row.lines[0].debit
Assert-Equal "M1 amount 50" 50 $m1Amount
Assert-Equal "M1 source manual" "manual" $m1row.source_type
if ($m1row.lines.Count -ne 2) { throw "M1 should have 2 lines, got $($m1row.lines.Count)" }
$expLine = $m1row.lines | Where-Object { $_.account_code -eq $code }
if (-not $expLine -or $expLine.debit -ne 50) { throw "M1 expense line not found with debit 50" }

# ---------------------------------------------------------------------------
# 5) MANUAL ENTRY: idempotency + rejections
# ---------------------------------------------------------------------------
Write-Host "`n--- 5) create_journal_entry idempotency / validation ---"
$m2again = Invoke-RPC -name "create_journal_entry" -p @{
    p_request_id = $m2ReqId
    p_date       = $d3
    p_memo       = $memoM2
    p_lines      = @(
        @{ account_id = $newAcctId; debit = 22; credit = 0 },
        @{ account_id = $cashAcct;  debit = 0;  credit = 22 }
    )
}
if (-not $m2again.duplicate) { throw "same request_id must return duplicate=true" }
Assert-Equal "idempotent entry_id match" $m2.entry_id $m2again.entry.entry_id

Write-Host "  unbalanced entry rejected ..."
try {
    Invoke-RPC -name "create_journal_entry" -p @{
        p_request_id = [guid]::NewGuid().ToString()
        p_date       = $today
        p_memo       = "قيد غير متوازن $runId"
        p_lines      = @(
            @{ account_id = $newAcctId; debit = 100; credit = 0 },
            @{ account_id = $cashAcct;  debit = 0;   credit = 90 }
        )
    } | Out-Null
    throw "FAIL: unbalanced entry accepted"
} catch {
    if ($_.Exception.Message -match "FAIL:") { throw }
    Write-Host "  OK: rejected as expected"
}

Write-Host "  unknown account in entry rejected ..."
try {
    Invoke-RPC -name "create_journal_entry" -p @{
        p_request_id = [guid]::NewGuid().ToString()
        p_date       = $today
        p_memo       = "قيد بحساب مجهول $runId"
        p_lines      = @(
            @{ account_id = "00000000-0000-0000-0000-000000000000"; debit = 5; credit = 0 },
            @{ account_id = $cashAcct; debit = 0; credit = 5 }
        )
    } | Out-Null
    throw "FAIL: unknown account accepted"
} catch {
    if ($_.Exception.Message -match "FAIL:") { throw }
    Write-Host "  OK: rejected as expected"
}

# ---------------------------------------------------------------------------
# 6) TRIAL BALANCE
# ---------------------------------------------------------------------------
Write-Host "`n--- 6) get_trial_balance ---"
$tb = Invoke-RPC -name "get_trial_balance" -p @{ p_as_of_date = $today }
Assert-Equal "Sigma Dr = Sigma Cr (balanced)" $tb.totals.credit $tb.totals.debit
# Scenario adds 6 journal entries: purchase 420, sale A 200, sale B 200,
# payment 80, M1 50, M2 22 -> trial-balance delta = 972 on both sides.
$actualDelta = 420 + 200 + 200 + 80 + 50 + 22
Assert-Equal "trial balance Dr +$actualDelta" ($baseTB.totals.debit + $actualDelta) $tb.totals.debit
Assert-Equal "trial balance Cr +$actualDelta" ($baseTB.totals.credit + $actualDelta) $tb.totals.credit

# ---------------------------------------------------------------------------
# 7) INCOME STATEMENT
# ---------------------------------------------------------------------------
Write-Host "`n--- 7) get_income_statement ---"
$inc = Invoke-RPC -name "get_income_statement" -p @{ p_from = $d3; p_to = $today }
Assert-Equal "revenue +400" ($baseIncome.revenue_total + 400) $inc.revenue_total
Assert-Equal "expenses +22 (M2 only, M1@$d5 outside window)" ($baseIncome.expense_total + 22) $inc.expense_total
Assert-Equal "net +378" ($baseIncome.net + 378) $inc.net

# ---------------------------------------------------------------------------
# 8) BALANCE SHEET
# ---------------------------------------------------------------------------
Write-Host "`n--- 8) get_balance_sheet ---"
$sheet = Invoke-RPC -name "get_balance_sheet" -p @{ p_as_of_date = $today }
Assert-Equal "assets +748 (cash 8 + AR 320 + inventory 420)" ($baseSheet.assets_total + 748) $sheet.assets_total
Assert-Equal "liabilities +420 (AP)" ($baseSheet.liabilities_total + 420) $sheet.liabilities_total
Assert-Equal "equity +328 (net income YTD)" ($baseSheet.equity_total + 328) $sheet.equity_total
Assert-Equal "check = 0 (assets = liab + equity)" 0 $sheet.check

Write-Host "`nALL M7 REPORTS TESTS PASSED (today=$today)"   