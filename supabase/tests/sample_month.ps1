# ============================================================
# SAMPLE MONTH - realistic full-month scenario + reconciliation
#
# M9 Output #4: "Realistic sample data + full-month scenarios to
# match balances manually and continuously (a month without
# financial errors = success criterion from business_model.md)".
#
# What it does:
#   1. Registers a FRESH tenant via /auth/v1/signup + register_tenant
#      (this also doubles as the S4 tenant-onboarding smoke test).
#   2. Seeds one past month of realistic Arabic data:
#        - 3 customers, 2 suppliers (one direct, one commission 20%)
#        - 3 products, direct purchases, a consignment receipt
#        - 3 credit sales, 2 customer payments
#        - owner capital injection + rent/utilities (manual journal)
#        - one employee paid his salary
#   3. Reconciles EVERY account balance, stock level, AR/AP, commission
#      dues, invoice statuses and financial statements to hand-computed
#      expected values. Any mismatch = financial error in the month.
#
# The month is a FULL past calendar month (defaults to previous month,
# override with -Year/-Month), so the business books a complete period
# with a closing trial balance + income statement + balance sheet.
#
# No data is destroyed: it runs inside its own brand-new tenant, so the
# shared DEV tenant (owner4) is untouched. Rows are left in place for
# inspection; the whole tenant can be dropped in the SQL Editor if needed.
#
# Run:  .\sample_month.ps1        (DEV default)
#       .\sample_month.ps1 -SupabaseUrl https://prod.supabase.co -AnonKey "..."
# ============================================================
param(
    [string]$SupabaseUrl = "https://sxasnunzspkuwbxiddqd.supabase.co",
    [string]$AnonKey     = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN4YXNudW56c3BrdXdieGlkZHFkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg3MDYyNDIsImV4cCI6MjEwNDI4MjI0Mn0.6zYdwBewK7t4P7w7w_-BYTXI1rolSeb0Zd6jteyJsUk",
    [string]$Email       = "",   # default: demo<runId>@test.local
    [string]$Password    = "Test@1234567",
    [string]$CompanyName = "شركة الديمو",
    [string]$OwnerName   = "مالك الديمو",
    [int]$Year           = 0,    # 0 = previous month's year
    [int]$Month          = 0     # 0 = previous month
)

$url = $SupabaseUrl
$key = $AnonKey
$baseHeaders = @{ apikey = $key; "Content-Type" = "application/json" }

$script:Pass = 0
$script:Fail = 0
$script:failed = $false

# ---------------------------------------------------------------------------
# Helpers (kept identical to m9_full_suite.ps1)
# ---------------------------------------------------------------------------
function Invoke-Json {
    param([string]$Method, [string]$Uri, [object]$Body, [hashtable]$H)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes(($Body | ConvertTo-Json -Depth 12))
    try {
        return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $H -ContentType "application/json; charset=utf-8" -Body $bytes -ErrorAction Stop
    } catch {
        $detail = ""
        if ($_.ErrorDetails -and $_.ErrorDetails.Message) { $detail = $_.ErrorDetails.Message }
        elseif ($_.Exception.Response) {
            try {
                $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
                $detail = $reader.ReadToEnd()
            } catch {}
        }
        throw "API/RPC failed: $($_.Exception.Message) :: $detail"
    }
}

function Get-Token {
    param([string]$email, [string]$pass)
    $body = @{ email = $email; password = $pass } | ConvertTo-Json
    $r = Invoke-RestMethod -Method Post -Uri "$url/auth/v1/token?grant_type=password" -Headers $baseHeaders -Body $body -ErrorAction Stop
    return $r.access_token
}

function Invoke-Ok {
    param([string]$label, [scriptblock]$scriptBlock)
    try {
        & $scriptBlock | Out-Null
        $script:Pass++
        Write-Host "  OK: $label"
    } catch {
        $script:Fail++
        Write-Host "  FAIL: $label :: $($_.Exception.Message)"
    }
}

function Assert-Equal([string]$label, $expected, $actual) {
    $expNum = 0.0; $actNum = 0.0
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
    if ($condition) { $script:Pass++; Write-Host "  OK: $label" }
    else { $script:Fail++; Write-Host "  FAIL: $label (condition false)" }
}

function Get-RowCount([string]$uri, [hashtable]$H) {
    $r = Invoke-RestMethod -Method Get -Uri $uri -Headers $H
    if ($null -eq $r) { return 0 }
    return @($r).Count
}

function Get-RelDate([string]$d, [int]$days) {
    return ([datetime]::ParseExact($d, 'yyyy-MM-dd', $null)).AddDays($days).ToString('yyyy-MM-dd')
}

function Sum-Field($rows, [string]$field) {
    $sum = 0.0
    if ($null -eq $rows) { return 0.0 }
    foreach ($row in @($rows)) { if ($null -ne $row.$field) { $sum += [double]$row.$field } }
    return $sum
}

function Test-Summary {
    Write-Host ""
    Write-Host "TOTAL: $script:Pass passed, $script:Fail failed"
    if ($script:Fail -gt 0) { $script:failed = $true }
}

# ---------------------------------------------------------------------------
# Deterministic month (full past calendar month by default)
# ---------------------------------------------------------------------------
$now = Get-Date
if ($Month -eq 0) { $Month = $now.AddMonths(-1).Month }
if ($Year -eq 0)  { $Year  = $now.AddMonths(-1).Year }
$mFirst = [string]::Format("{0:0000}-{1:00}-01", $Year, $Month)
$mEnd   = ([datetime]::ParseExact($mFirst, 'yyyy-MM-dd', $null)).AddMonths(1).AddDays(-1).ToString('yyyy-MM-dd')
$d2  = Get-RelDate $mFirst 1
$d3  = Get-RelDate $mFirst 2
$d4  = Get-RelDate $mFirst 3
$d5  = Get-RelDate $mFirst 4
$d6  = Get-RelDate $mFirst 5
$d8  = Get-RelDate $mFirst 7
$d11 = Get-RelDate $mFirst 10
$d13 = Get-RelDate $mFirst 12
$d14 = Get-RelDate $mFirst 13
$d16 = Get-RelDate $mFirst 15
$d17 = Get-RelDate $mFirst 16
$d18 = Get-RelDate $mFirst 17

Write-Host "=== Hasad Sample Month: $mFirst .. $mEnd ==="

# ---------------------------------------------------------------------------
# 1. FRESH TENANT (onboarding smoke test + isolation for the scenario)
# ---------------------------------------------------------------------------
$runId = [guid]::NewGuid().ToString("N").Substring(0, 8)
if ([string]::IsNullOrWhiteSpace($Email)) { $Email = "demo$runId@test.local" }
Write-Host "`n--- Onboarding fresh tenant ($Email) ---"

# Sign up a brand-new auth user, then register their business.
$signup = $null
Invoke-Ok -label "signup new auth user" -scriptBlock {
    $r = Invoke-Json -Method "Post" -Uri "$url/auth/v1/signup" -Body @{ email = $Email; password = $Password } -H $baseHeaders
    $script:signupTok = $r.access_token
}
if (-not $script:signupTok) {
    Write-Host "  (no token from signup - email confirm may be on; trying password login)..." -ForegroundColor Yellow
    Invoke-Ok -label "login after signup" -scriptBlock {
        $script:signupTok = Get-Token $Email $Password
    }
}
if (-not $script:signupTok) {
    Write-Host "ERROR: could not obtain a session for $Email. Enable Auth -> Providers -> Email -> 'Confirm email' = OFF and re-run." -ForegroundColor Red
    exit 1
}

$h = @{ apikey = $key; Authorization = "Bearer $($script:signupTok)"; "Content-Type" = "application/json"; "Prefer" = "return=representation" }
$hg = @{ apikey = $key; Authorization = "Bearer $($script:signupTok)"; "Content-Type" = "application/json" }

Invoke-Ok -label "register_tenant('$CompanyName')" -scriptBlock {
    $script:tenantId = Invoke-Json -Method "Post" -Uri "$url/rest/v1/rpc/register_tenant" -Body @{ p_name = $CompanyName; p_owner_name = $OwnerName } -H $h
}
$tenantId = $script:tenantId
Assert-True "tenant registered (non-empty id)" (-not [string]::IsNullOrWhiteSpace($tenantId))

function Invoke-RPC {
    param([string]$name, [hashtable]$p)
    return Invoke-Json -Method "Post" -Uri "$url/rest/v1/rpc/$name" -Body $p -H $h
}

# Chart of accounts seeded by register_tenant. Map code -> {id, balance}.
$acc = @{}
$chartNow = Invoke-RPC -name "get_chart_of_accounts" -p @{}
foreach ($a in @($chartNow)) { $acc[$a.code] = $a }
Assert-True "chart of accounts has 14 seeded accounts" ($chartNow.Count -eq 14)
$id1010 = $acc['1010'].account_id; $id1015 = $acc['1015'].account_id
$id1020 = $acc['1020'].account_id; $id1030 = $acc['1030'].account_id
$id3010 = $acc['3010'].account_id; $id4010 = $acc['4010'].account_id
$id5020 = $acc['5020'].account_id; $id5030 = $acc['5030'].account_id

# ---------------------------------------------------------------------------
# 2. MASTER DATA (realistic Arabic)
# ---------------------------------------------------------------------------
Write-Host "`n--- Master data ---"
$cA = Invoke-Json -Method "Post" -Uri "$url/rest/v1/customers" -Body @{ name = "أحمد محمد"; phone = "0599111001" }
$cB = Invoke-Json -Method "Post" -Uri "$url/rest/v1/customers" -Body @{ name = "محمود عبد"; phone = "0599111002" }
$cC = Invoke-Json -Method "Post" -Uri "$url/rest/v1/customers" -Body @{ name = "سامي عادل"; phone = "0599111003" }
$cAId = $cA[0].id; $cBId = $cB[0].id; $cCId = $cC[0].id

$s1 = Invoke-Json -Method "Post" -Uri "$url/rest/v1/suppliers" -Body @{ name = "مؤسسة الجملة للتموين"; phone = "0599222001"; deal_type = "owned" }
$s2 = Invoke-Json -Method "Post" -Uri "$url/rest/v1/suppliers" -Body @{ name = "مورد البضاعة بالعمولة"; phone = "0599222002"; deal_type = "commission"; commission_rate = 20 }
$s1Id = $s1[0].id; $s2Id = $s2[0].id

# Products created directly; the consignment receipt later relinks P3 to S2 (0018).
$p1 = Invoke-Json -Method "Post" -Uri "$url/rest/v1/products" -Body @{ name = "قهوة 1 كغ"; unit = "كغ"; unit_type = "count"; sale_price = 6000; purchase_price = 4000; qty = 0; reorder_level = 10 }
$p2 = Invoke-Json -Method "Post" -Uri "$url/rest/v1/products" -Body @{ name = "سكر 5 كغ";  unit = "كيس"; unit_type = "count"; sale_price = 5000; purchase_price = 3500; qty = 0; reorder_level = 10 }
$p3 = Invoke-Json -Method "Post" -Uri "$url/rest/v1/products" -Body @{ name = "أرز 10 كغ"; unit = "كيس"; unit_type = "count"; sale_price = 12000; purchase_price = 8000; qty = 0; reorder_level = 5 }
$p1Id = $p1[0].id; $p2Id = $p2[0].id; $p3Id = $p3[0].id

# ---------------------------------------------------------------------------
# 3. OWNER CAPITAL injection (manual journal; exercises create_journal_entry)
# ---------------------------------------------------------------------------
Write-Host "`n--- Capital injection (manual journal) ---"
Invoke-Ok -label "capital: cash 50000 + bank 700000" -scriptBlock {
    Invoke-RPC -name "create_journal_entry" -p @{
        p_request_id = [guid]::NewGuid().ToString()
        p_date = $mFirst; p_memo = "رأس المال - إيداع أولي"
        p_lines = @(
            @{ account_id = $id1010; debit = 50000;  credit = 0 }
            @{ account_id = $id1015; debit = 700000; credit = 0 }
            @{ account_id = $id3010; debit = 0;      credit = 750000 }
        )
    }
}

# ---------------------------------------------------------------------------
# 4. PURCHASES (direct, paid from bank -> no AP) + CONSIGNMENT receipt
# ---------------------------------------------------------------------------
Write-Host "`n--- Purchases + consignment ---"
Invoke-Ok -label "R1: P1 x50 = 200000 bank" -scriptBlock {
    Invoke-RPC -name "create_purchase_invoice" -p @{
        p_request_id = [guid]::NewGuid().ToString(); p_supplier_id = $s1Id
        p_items = @( @{ product_id = $p1Id; qty = 50 } )
        p_invoice_date = $d2; p_paid = 200000; p_payment_method = "bank"; p_memo = "شراء قهوة"
    }
}
Invoke-Ok -label "R2: P2 x40 = 140000 bank" -scriptBlock {
    Invoke-RPC -name "create_purchase_invoice" -p @{
        p_request_id = [guid]::NewGuid().ToString(); p_supplier_id = $s1Id
        p_items = @( @{ product_id = $p2Id; qty = 40 } )
        p_invoice_date = $d3; p_paid = 140000; p_payment_method = "bank"; p_memo = "شراء سكر"
    }
}
Invoke-Ok -label "R3: P3 x20 = 160000 bank" -scriptBlock {
    Invoke-RPC -name "create_purchase_invoice" -p @{
        p_request_id = [guid]::NewGuid().ToString(); p_supplier_id = $s1Id
        p_items = @( @{ product_id = $p3Id; qty = 20 } )
        p_invoice_date = $d4; p_paid = 160000; p_payment_method = "bank"; p_memo = "شراء أرز"
    }
}
Invoke-Ok -label "RC: consignment P3 x30 (stock only, no entry)" -scriptBlock {
    Invoke-RPC -name "create_purchase_invoice" -p @{
        p_request_id = [guid]::NewGuid().ToString(); p_supplier_id = $s2Id
        p_items = @( @{ product_id = $p3Id; qty = 30 } )
        p_invoice_date = $d5; p_paid = 0; p_payment_method = "cash"; p_memo = "بضاعة بالعمولة"
    }
}

# ---------------------------------------------------------------------------
# 5. SALES (all credit -> AR) + PAYMENTS
# ---------------------------------------------------------------------------
Write-Host "`n--- Sales ---"
Invoke-Ok -label "V1 CA: P1 x5 + P3 x2 = 54000" -scriptBlock {
    Invoke-RPC -name "create_sale_invoice" -p @{
        p_request_id = [guid]::NewGuid().ToString(); p_customer_id = $cAId
        p_items = @(
            @{ product_id = $p1Id; qty = 5;  price = 6000  }
            @{ product_id = $p3Id; qty = 2;  price = 12000 }
        )
        p_invoice_date = $d6; p_paid = 0; p_payment_method = "cash"; p_memo = "فاتورة أحمد"
    }
}
Invoke-Ok -label "V2 CB: P1 x6 + P2 x8 + P3 x3 = 112000" -scriptBlock {
    Invoke-RPC -name "create_sale_invoice" -p @{
        p_request_id = [guid]::NewGuid().ToString(); p_customer_id = $cBId
        p_items = @(
            @{ product_id = $p1Id; qty = 6;  price = 6000  }
            @{ product_id = $p2Id; qty = 8;  price = 5000  }
            @{ product_id = $p3Id; qty = 3;  price = 12000 }
        )
        p_invoice_date = $d8; p_paid = 0; p_payment_method = "cash"; p_memo = "فاتورة محمود"
    }
}
Invoke-Ok -label "V3 CC: P2 x4 + P3 x3 = 56000" -scriptBlock {
    Invoke-RPC -name "create_sale_invoice" -p @{
        p_request_id = [guid]::NewGuid().ToString(); p_customer_id = $cCId
        p_items = @(
            @{ product_id = $p2Id; qty = 4;  price = 5000  }
            @{ product_id = $p3Id; qty = 3;  price = 12000 }
        )
        p_invoice_date = $d11; p_paid = 0; p_payment_method = "cash"; p_memo = "فاتورة سامي"
    }
}

Write-Host "`n--- Payments ---"
Invoke-Ok -label "PAY CA 54000 cash (fully settles V1)" -scriptBlock {
    Invoke-RPC -name "record_payment" -p @{
        p_request_id = [guid]::NewGuid().ToString(); p_invoice_id = ((Invoke-Json -Method "Get" -Uri "$url/rest/v1/invoices?select=id&party_id=eq.$cAId&type=eq.sale" -H $hg)[0]).id
        p_amount = 54000; p_method = "cash"; p_date = $d13
    }
}
Invoke-Ok -label "PAY CB 112000 bank (fully settles V2)" -scriptBlock {
    Invoke-RPC -name "record_payment" -p @{
        p_request_id = [guid]::NewGuid().ToString(); p_invoice_id = ((Invoke-Json -Method "Get" -Uri "$url/rest/v1/invoices?select=id&party_id=eq.$cBId&type=eq.sale" -H $hg)[0]).id
        p_amount = 112000; p_method = "bank"; p_date = $d14
    }
}

# ---------------------------------------------------------------------------
# 6. EXPENSES (manual journal) + SALARY
# ---------------------------------------------------------------------------
Write-Host "`n--- Expenses + salary ---"
Invoke-Ok -label "EXP1 rent 60000 cash" -scriptBlock {
    Invoke-RPC -name "create_journal_entry" -p @{
        p_request_id = [guid]::NewGuid().ToString(); p_date = $d16; p_memo = "إيجار المحل"
        p_lines = @(
            @{ account_id = $id5020; debit = 60000; credit = 0 }
            @{ account_id = $id1010; debit = 0;     credit = 60000 }
        )
    }
}
Invoke-Ok -label "EXP2 utilities 40000 bank" -scriptBlock {
    Invoke-RPC -name "create_journal_entry" -p @{
        p_request_id = [guid]::NewGuid().ToString(); p_date = $d17; p_memo = "كهرباء ومياه"
        p_lines = @(
            @{ account_id = $id5020; debit = 40000; credit = 0 }
            @{ account_id = $id1015; debit = 0;     credit = 40000 }
        )
    }
}
$emp1 = Invoke-Json -Method "Post" -Uri "$url/rest/v1/employees" -Body @{ name = "خالد حسن"; job_title = "بائع"; phone = "0599333001"; base_salary = 100000 }
$emp1Id = $emp1[0].id
Invoke-Ok -label "SAL1 pay salary 100000 bank" -scriptBlock {
    Invoke-RPC -name "pay_salary" -p @{
        p_request_id = [guid]::NewGuid().ToString(); p_employee_id = $emp1Id
        p_month = $mFirst; p_paid = 100000; p_method = "bank"; p_date = $d18; p_note = "راتب شهر"
    }
}

# ---------------------------------------------------------------------------
# 7. RECONCILIATION (expected values are hand-computed, all in agorot)
# ---------------------------------------------------------------------------
Write-Host "`n--- Reconciliation ---"

$p1q = (Invoke-RestMethod -Method Get -Uri "$url/rest/v1/products?select=qty&id=eq.$p1Id" -Headers $hg).qty
$p2q = (Invoke-RestMethod -Method Get -Uri "$url/rest/v1/products?select=qty&id=eq.$p2Id" -Headers $hg).qty
$p3q = (Invoke-RestMethod -Method Get -Uri "$url/rest/v1/products?select=qty&id=eq.$p3Id" -Headers $hg).qty
Assert-Equal "stock P1 = 39 (50 bought - 11 sold)" 39 $p1q
Assert-Equal "stock P2 = 28 (40 bought - 12 sold)" 28 $p2q
Assert-Equal "stock P3 = 42 (20+30 in, 8 sold)"    42 $p3q

# Consignment receipt: payable-looking remaining in invoices table, but NOT
# a supplier debt and with NO journal entry (documented design).
$rcInvs = Invoke-RestMethod -Method Get -Uri "$url/rest/v1/invoices?select=remaining,status&ownership=eq.consignment" -Headers $hg
Assert-Equal "consignment invoice remaining = 240000" 240000 (Sum-Field $rcInvs "remaining")
Assert-True  "consignment invoice status = unpaid" (($rcInvs | ForEach-Object { $_.status }) -contains "unpaid")
$consignEntries = Invoke-RPC -name "get_journal_entries" -p @{ p_from = $mFirst; p_to = $mEnd }
Assert-Equal "no journal entry ships the consignment receipt" 0 @($consignEntries | Where-Object { $_.memo -like "*بالعمولة*" }).Count

# Journal entries: 2 capital + 3 purchases + 3 sales + 3 payments + 2 expenses + 1 salary = 14
Assert-Equal "journal entry count = 14" 14 @($consignEntries).Count

# Receivables per customer.
$arA = Sum-Field (Invoke-RestMethod -Method Get -Uri "$url/rest/v1/invoices?select=remaining&party_id=eq.$cAId&type=eq.sale" -Headers $hg) "remaining"
$arB = Sum-Field (Invoke-RestMethod -Method Get -Uri "$url/rest/v1/invoices?select=remaining&party_id=eq.$cBId&type=eq.sale" -Headers $hg) "remaining"
$arC = Sum-Field (Invoke-RestMethod -Method Get -Uri "$url/rest/v1/invoices?select=remaining&party_id=eq.$cCId&type=eq.sale" -Headers $hg) "remaining"
Assert-Equal "CA remaining = 0 (paid in full)"   0 $arA
Assert-Equal "CB remaining = 0 (paid in full)"   0 $arB
Assert-Equal "CC remaining = 56000 (unpaid)" 56000 $arC

# Account balances via get_chart_of_accounts (debit - credit signed).
$charts = Invoke-RPC -name "get_chart_of_accounts" -p @{}
$bal = @{}
foreach ($a in $charts) { $bal[$a.code] = $a.balance }
Assert-Equal "1010 النقدية = 44000"       44000   $bal['1010']
Assert-Equal "1015 البنك = 172000"        172000  $bal['1015']
Assert-Equal "1020 الذمم المدينة = 56000" 56000   $bal['1020']
Assert-Equal "1030 المخزون = 500000"      500000  $bal['1030']
Assert-Equal "3010 رأس المال = -750000 (credit)" -750000 $bal['3010']
Assert-Equal "4010 إيرادات = -222000 (credit)"  -222000 $bal['4010']
Assert-Equal "5020 مصروفات تشغيلية = 100000"    100000  $bal['5020']
Assert-Equal "5030 أجور = 100000"               100000  $bal['5030']

# Commission dues on the 8 consignment P3 units sold (rate 20, price 12000).
$dues = Invoke-RestMethod -Method Get -Uri "$url/rest/v1/commission_dues?select=commission_amount,supplier_due,remaining" -Headers $hg
Assert-Equal "commission due = 8 x 9600 = 76800" 76800 (Sum-Field $dues "supplier_due")
Assert-Equal "commission outstanding = 76800"    76800 (Sum-Field $dues "remaining")
Assert-Equal "commission share = 8 x 2400 = 19200" 19200 (Sum-Field $dues "commission_amount")

# Salary row.
$sal = Invoke-RestMethod -Method Get -Uri "$url/rest/v1/salaries?select=net_due,paid&employee_id=eq.$emp1Id" -Headers $hg
Assert-True "salary row: net_due 100000 / paid 100000, count 1" (
    @($sal).Count -eq 1 -and $sal[0].net_due -eq 100000 -and $sal[0].paid -eq 100000
)

# Generic statement for the still-open customer.
$stmt = Invoke-RPC -name "get_party_statement" -p @{ p_party_type = "customer"; p_party_id = $cCId; p_from = $mFirst; p_to = $mEnd }
Assert-Equal "CC statement closing = 56000" 56000 $stmt.closing

# Financial reports.
$tb = Invoke-RPC -name "get_trial_balance" -p @{ p_as_of_date = $mEnd }
$balOk = $false
if ($null -ne $tb.balanced) { $balOk = [bool]$tb.balanced }
elseif ($null -ne $tb.totals -and $null -ne $tb.totals.debit) { $balOk = ([math]::Abs([double]$tb.totals.debit - [double]$tb.totals.credit) -le 0.0001) }
Assert-True "trial balance balanced = true" $balOk

$is = Invoke-RPC -name "get_income_statement" -p @{ p_from = $mFirst; p_to = $mEnd }
Assert-Equal "income statement revenue = 222000" 222000 $is.revenue_total
Assert-Equal "income statement expenses = 200000" 200000 $is.expense_total
Assert-Equal "income statement net = +22000 (profitable month)" 22000 $is.net

$bs = Invoke-RPC -name "get_balance_sheet" -p @{ p_as_of_date = $mEnd }
$chk = $null
if ($null -ne $bs.check) { $chk = $bs.check } elseif ($null -ne $bs.sheet_check) { $chk = $bs.sheet_check }
Assert-Equal "balance sheet check = 0 (fully balanced)" 0 $chk

# ---------------------------------------------------------------------------
Test-Summary
Write-Host "Tenant id: $tenantId  (email: $Email, password: $Password)" -ForegroundColor Cyan
Write-Host "Inspect the month in the app with the demo login, or drop the tenant in the SQL Editor: DELETE FROM public.tenants WHERE id = '$tenantId';" -ForegroundColor DarkGray

if (-not [Console]::IsInputRedirected) { Read-Host "`nPress Enter to close" }
if ($script:failed) { exit 1 }
exit 0