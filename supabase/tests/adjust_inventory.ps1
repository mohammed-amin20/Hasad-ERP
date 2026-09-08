# ============================================================
# ADJUST INVENTORY - end-to-end regression (M4 slice 3)
# Verifies: migration 0014 applied, adjust_inventory reduces
# the count (down-adjust) and up-adjusts, records a stock_moves
# row of type 'adjust', and rejects a bad counted qty.
# Run AFTER pasting 0014_stock_adjust.sql in the SQL Editor.
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
# GET headers: no Prefer needed on reads, and no @(...) wrapper on GET calls.
# PS 5.1 quirk: wrapping Invoke-RestMethod in @() nests a multi-row Object[]
# into a single wrapper (.Count=1), so the Case 5 Where-Object filter collapsed.
# Invoke-RestMethod already returns Object[] for multi-row responses.
$hGet = @{
    apikey = $key
    Authorization = $h4.Authorization
    "Content-Type" = "application/json"
}
Write-Host "Login successful"

# PowerShell 5.1 sends -Body strings as ISO-8859-1 by default, which replaces
# Arabic with '?' on the wire. Encode as UTF-8 bytes so Arabic survives.
function Invoke-Json {
    param([string]$Method, [string]$Uri, [object]$Body)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes(($Body | ConvertTo-Json -Depth 10))
    return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $h4 -ContentType "application/json; charset=utf-8" -Body $bytes
}

function Add-Product {
    param([string]$name, [double]$qty)
    $body = @{
        name = $name
        unit = "قطعة"
        unit_type = "count"
        sale_price = 500
        purchase_price = 300
        qty = $qty
        reorder_level = 0
    }
    $result = Invoke-Json -Method "Post" -Uri "$url/rest/v1/products" -Body $body
    return $result[0].id
}

function Get-ProductQty {
    param([string]$id)
    $rows = Invoke-RestMethod -Method Get -Uri "$url/rest/v1/products?select=qty&id=eq.$id" -Headers $hGet
    return [double]$rows.qty
}

# --- Case 1: down-adjust (physical count lower than stock) ---
Write-Host "Case 1: down-adjust 10 -> 6 ..."
$pid1 = Add-Product -name "منتج جرد اختبار 1 - $([guid]::NewGuid())" -qty 10
$body1 = @{
    p_product_id = $pid1
    p_counted_qty = 6
    p_reason = "جرد شهري"
}
$r1 = Invoke-Json -Method "Post" -Uri "$url/rest/v1/rpc/adjust_inventory" -Body $body1
if ($r1.delta -ne -4 -or $r1.changed -ne $true) { throw "Case 1 failed: delta=$($r1.delta) changed=$($r1.changed)" }
if ((Get-ProductQty $pid1) -ne 6) { throw "Case 1 failed: qty did not reach 6" }

# --- Case 2: up-adjust ---
Write-Host "Case 2: up-adjust 6 -> 9 ..."
$body2 = @{
    p_product_id = $pid1
    p_counted_qty = 9
    p_reason = "بضاعة إضافية مكتشفة"
}
$r2 = Invoke-Json -Method "Post" -Uri "$url/rest/v1/rpc/adjust_inventory" -Body $body2
if ($r2.delta -ne 3) { throw "Case 2 failed: delta=$($r2.delta)" }
if ((Get-ProductQty $pid1) -ne 9) { throw "Case 2 failed: qty did not reach 9" }

# --- Case 3: no-op when counted equals stock ---
Write-Host "Case 3: same-count no-op ..."
$body3 = @{
    p_product_id = $pid1
    p_counted_qty = 9
}
$r3 = Invoke-Json -Method "Post" -Uri "$url/rest/v1/rpc/adjust_inventory" -Body $body3
if ($r3.changed -ne $false -or $r3.delta -ne 0) { throw "Case 3 failed: changed=$($r3.changed) delta=$($r3.delta)" }

# --- Case 4: negative counted qty rejected ---
Write-Host "Case 4: negative counted qty rejected ..."
try {
    $body4 = @{ p_product_id = $pid1; p_counted_qty = -2 }
    Invoke-Json -Method "Post" -Uri "$url/rest/v1/rpc/adjust_inventory" -Body $body4 | Out-Null
    throw "Case 4 failed: negative qty was accepted"
} catch {
    if ($_.Exception.Message -match "Case 4 failed") { throw }
    Write-Host "  (rejected as expected)"
}

# --- Case 5: stock_moves recorded with type 'adjust' ---
Write-Host "Case 5: stock_moves recorded ..."
$moves = Invoke-RestMethod -Method Get -Uri "$url/rest/v1/stock_moves?select=id,type,qty,ref,reason&product_id=eq.$pid1&order=created_at.desc" -Headers $hGet
$adjustMoves = @($moves | Where-Object { $_.type -eq 'adjust' })
if ($adjustMoves.Count -lt 2) { throw "Case 5 failed: expected >=2 adjust moves, got $($adjustMoves.Count)" }

Write-Host "`nALL ADJUST INVENTORY TESTS PASSED"
Write-Host "Product: $pid1  final qty: $(Get-ProductQty $pid1)"