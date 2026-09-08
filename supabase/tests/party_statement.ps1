# ============================================================
# PARTY STATEMENT - end-to-end regression (M5 slice B)
# Verifies: migration 0015 applied, get_party_statement returns
# an opening balance, movement lines (invoice + payment, and
# commission as a separate line for suppliers), a closing balance
# that ties to opening + movements, consignment purchases appear
# with zero debit, and an out-of-range party is rejected.
# Run AFTER pasting 0015_get_party_statement.sql in the SQL Editor.
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
    return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $h4 -ContentType "application/json; charset=utf-8" -Body $bytes
}

function Invoke-RPC {
    param([string]$name, [hashtable]$p)
    return Invoke-Json -Method "Post" -Uri "$url/rest/v1/rpc/$name" -Body $p
}

function Get-Statement {
    param([string]$type, [string]$id, [string]$from, [string]$to)
    return Invoke-RPC -name "get_party_statement" -p @{
        p_party_type = $type
        p_party_id   = $id
        p_from       = $from
        p_to         = $to
    }
}

# --- Setup: a customer, a supplier, products ---
Write-Host "Setup: create customer, supplier, products ..."
$custBody = @{ name = "عميل كشف $([guid]::NewGuid())" }
$cust = Invoke-Json -Method "Post" -Uri "$url/rest/v1/customers" -Body $custBody
$custId = $cust[0].id

$suppBody = @{ name = "مورد كشف $([guid]::NewGuid())"; deal_type = "commission"; commission_rate = 10 }
$supp = Invoke-Json -Method "Post" -Uri "$url/rest/v1/suppliers" -Body $suppBody
$suppId = $supp[0].id

function New-Product {
    param([string]$name)
    $body = @{ name = $name; unit = "قطعة"; unit_type = "count"; sale_price = 100; purchase_price = 60; qty = 100; reorder_level = 0 }
    $r = Invoke-Json -Method "Post" -Uri "$url/rest/v1/products" -Body $body
    return $r[0].id
}

$pid2 = New-Product -name "منتج بيع $([guid]::NewGuid())"
$pid3 = New-Product -name "منتج أمانة $([guid]::NewGuid())"
$items = @( @{ product_id = $pid2; qty = 2; price = 100 } )
$sale = Invoke-RPC -name "create_sale_invoice" -p @{
    p_request_id   = [guid]::NewGuid().ToString()
    p_customer_id  = $custId
    p_items        = $items
    p_invoice_date = "2026-09-01"
    p_paid         = 0
    p_payment_method = "cash"
}
if (-not $sale.invoice_id) { throw "Case 1: sale failed" }

Invoke-RPC -name "record_payment" -p @{
    p_request_id = [guid]::NewGuid().ToString()
    p_invoice_id = $sale.invoice_id
    p_amount     = 80
    p_method     = "cash"
    p_date       = "2026-09-05"
} | Out-Null

$st = Get-Statement -type "customer" -id $custId -from "2026-09-01" -to "2026-09-30"
if ($st.opening -ne 0) { throw "Case 1: opening should be 0, got $($st.opening)" }
if ($st.lines.Count -ne 2) { throw "Case 1: expected 2 lines (invoice + payment), got $($st.lines.Count)" }
if ($st.lines[0].debit -ne 200 -or $st.lines[0].kind -ne "invoice") { throw "Case 1: bad invoice line" }
if ($st.lines[1].credit -ne 80 -or $st.lines[1].kind -ne "payment") { throw "Case 1: bad payment line" }
if ($st.closing -ne 120) { throw "Case 1: closing should be 120 (200-80), got $($st.closing)" }
Write-Host "  opening=$($st.opening) lines=$($st.lines.Count) closing=$($st.closing)"

# --- Case 2: commission supplier statement has a separate commission line ---
Write-Host "Case 2: consignment receipt (zero debit) + commission line ..."

# consignment (commission) receipt forces paid=0 and ownership=consignment
$pitems = @( @{ product_id = $pid3; qty = 10; price = 60 } )
$pur = Invoke-RPC -name "create_purchase_invoice" -p @{
    p_request_id   = [guid]::NewGuid().ToString()
    p_supplier_id  = $suppId
    p_items        = $pitems
    p_invoice_date = "2026-09-02"
    p_paid         = 0
    p_payment_method = "cash"
}
if (-not $pur.invoice_id) { throw "Case 2: consignment purchase failed" }

# selling the consignment item generates the commission due
$sitems = @( @{ product_id = $pid3; qty = 2; price = 100 } )
$sale2 = Invoke-RPC -name "create_sale_invoice" -p @{
    p_request_id   = [guid]::NewGuid().ToString()
    p_customer_id  = $custId
    p_items        = $sitems
    p_invoice_date = "2026-09-03"
    p_paid         = 0
    p_payment_method = "cash"
}
if (-not $sale2.invoice_id) { throw "Case 2: consignment-item sale failed" }

$st2 = Get-Statement -type "supplier" -id $suppId -from "2026-09-01" -to "2026-09-30"
$consignmentLine = @($st2.lines | Where-Object { $_.kind -eq 'invoice' })
if ($consignmentLine.Count -ne 1 -or $consignmentLine[0].credit -ne 0 -or $consignmentLine[0].debit -ne 0) {
    throw "Case 2: consignment invoice must show zero debit/credit"
}
$commLine = @($st2.lines | Where-Object { $_.kind -eq 'commission' })
if ($commLine.Count -ne 1) { throw "Case 2: expected 1 commission line, got $($commLine.Count)" }
# due = sale price x (1 - 0.10) = 100 x 2 x 0.90 = 180
if ([int]$commLine[0].credit -ne 180) { throw "Case 2: commission credit should be 180, got $($commLine[0].credit)" }
Write-Host "  consignment zero-debit OK, commission=$($commLine[0].credit)"

# --- Case 3: opening balance picks up rows before the range ---
Write-Host "Case 3: opening balance before range ..."
$st3 = Get-Statement -type "customer" -id $custId -from "2026-09-10" -to "2026-09-30"
if ($st3.opening -ne 320) { throw "Case 3: opening should be 320, got $($st3.opening)" }
if ($st3.lines.Count -ne 0) { throw "Case 3: no lines expected in the later range, got $($st3.lines.Count)" }
if ($st3.closing -ne 320) { throw "Case 3: closing should stay 320, got $($st3.closing)" }
Write-Host "  opening=$($st3.opening) closing=$($st3.closing)"

# --- Case 4: invalid party rejected ---
Write-Host "Case 4: unknown party rejected ..."
try {
    Get-Statement -type "customer" -id "00000000-0000-0000-0000-000000000000" -from "2026-09-01" -to "2026-09-30" | Out-Null
    throw "Case 4 failed: unknown party not rejected"
} catch {
    if ($_.Exception.Message -match "Case 4 failed") { throw }
    Write-Host "  (rejected as expected)"
}

# --- Case 5: bad range rejected ---
Write-Host "Case 5: from > to rejected ..."
try {
    Get-Statement -type "customer" -id $custId -from "2026-09-30" -to "2026-09-01" | Out-Null
    throw "Case 5 failed: bad range not rejected"
} catch {
    if ($_.Exception.Message -match "Case 5 failed") { throw }
    Write-Host "  (rejected as expected)"
}

Write-Host "`nALL PARTY STATEMENT TESTS PASSED"
