# ============================================================
# OFFLINE IDEMPOTENCY - end-to-end regression (migration 0025)
# Verifies: adjust_inventory and create_account accept p_request_id
# and return the ORIGINAL stored envelope on a replay, and that the
# old 4-arg overloads are gone (no ambiguous-signature error).
#
# The bug this pins, in the order the cases hit it:
#   * adjust_inventory re-applies the delta on a retry, so a replay
#     silently corrupts stock (delta is computed from the CURRENT
#     qty, so the second call sees 0 and posts a second stock_moves
#     row that says "no change" while the first one moved the stock).
#   * create_account returns {'duplicate': true} on a retry, which the
#     app shows to the user as "كود الحساب مستخدم مسبقاً" -- a retried
#     create looked exactly like a real validation failure, and the
#     local id_map never learned the account id.
#
# Run AFTER pasting 0025_rpc_idempotency_offline.sql in the SQL Editor.
# Double-click safe: accumulates failures instead of exit 1 mid-run.
# ============================================================
param(
    [string]$OwnerEmail = "owner4@test.local",
    [string]$OwnerPass  = "Test@1234567"
)

$url = "https://sxasnunzspkuwbxiddqd.supabase.co"
$key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN4YXNudW56c3BrdXdieGlkZHFkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg3MDYyNDIsImV4cCI6MjEwNDI4MjI0Mn0.6zYdwBewK7t4P7w7w_-BYTXI1rolSeb0Zd6jteyJsUk"
$headers = @{ apikey = $key; "Content-Type" = "application/json" }

$script:failures = @()
$script:checks = 0

function Test-Ok {
    param([string]$label, [bool]$condition, [string]$detail = "")
    $script:checks++
    if ($condition) {
        Write-Host "  OK: $label"
    } else {
        Write-Host "  FAIL: $label  $detail"
        $script:failures += $label
    }
}

function Test-Equal {
    param([string]$label, $expected, $actual)
    $expNum = 0.0
    $actNum = 0.0
    $isNum = [double]::TryParse($expected, [ref]$expNum) -and [double]::TryParse($actual, [ref]$actNum)
    if ($isNum) {
        Test-Ok $label ([math]::Abs($expNum - $actNum) -lt 0.0001) "expected [$expected] got [$actual]"
    } else {
        Test-Ok $label ([string]$expected -eq [string]$actual) "expected [$expected] got [$actual]"
    }
}

function Test-Summary {
    param([string]$title)
    Write-Host ""
    if ($script:failures.Count -eq 0) {
        Write-Host "ALL PASSED: $title  ($($script:checks) checks)"
    } else {
        Write-Host "$($script:failures.Count) of $($script:checks) checks FAILED: $title"
        foreach ($f in $script:failures) { Write-Host "   - $f" }
    }
}

Write-Host "Logging in..."
$loginBody = @{ email = $OwnerEmail; password = $OwnerPass } | ConvertTo-Json
$resp = Invoke-RestMethod -Method Post -Uri "$url/auth/v1/token?grant_type=password" -Headers $headers -Body $loginBody
$h4 = @{
    apikey = $key
    Authorization = "Bearer " + $resp.access_token
    "Content-Type" = "application/json"
    "Prefer" = "return=representation"
}
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

# --- Case 1: adjust_inventory first call applies the delta ---
Write-Host "`nCase 1: adjust_inventory applies the counted qty (first call)"
$product = Add-Product -name "جرد بدون تكرار $([guid]::NewGuid())" -qty 10
$request1 = [guid]::NewGuid().ToString()
$first = Invoke-RPC -name "adjust_inventory" -p @{
    p_product_id  = $product
    p_counted_qty = 6
    p_reason      = "جرد اختبار عدم التكرار"
    p_request_id  = $request1
}
Test-Equal "delta is -4" -4 $first.delta
Test-Equal "changed is true" "True" ([string]$first.changed)
Test-Equal "product qty reached 6" 6 (Get-ProductQty $product)

# --- Case 2: the replay is a no-op and returns the SAME envelope ---
# This is the regression. Without p_request_id the second call recomputes
# delta from the now-current qty, posts a second stock_moves row, and a naive
# implementation would report delta 0 -- the user sees the count "applied
# twice" and the stock history gains a phantom movement.
Write-Host "`nCase 2: replaying the same request_id changes nothing"
$replay = Invoke-RPC -name "adjust_inventory" -p @{
    p_product_id  = $product
    p_counted_qty = 6
    p_reason      = "جرد اختبار عدم التكرار"
    p_request_id  = $request1
}
Test-Equal "replay returns the original delta" -4 $replay.delta
Test-Equal "replay returns the original old_qty" 10 $replay.old_qty
Test-Equal "replay did not move the stock again" 6 (Get-ProductQty $product)

# --- Case 3: exactly one adjust movement exists for that count ---
# Never wrap a table GET in @(...): PS 5.1 already returns Object[] for a
# multi-row response and the extra wrapper nests it to .Count = 1.
Write-Host "`nCase 3: only one adjust movement was recorded"
$moves = Invoke-RestMethod -Method Get -Uri "$url/rest/v1/stock_moves?select=id,type,qty,ref&product_id=eq.$product&order=created_at.desc" -Headers $hGet
$adjustMoves = @($moves | Where-Object { $_.type -eq 'adjust' })
Test-Equal "adjust movement count" 1 $adjustMoves.Count

# --- Case 4: a DIFFERENT request_id is a genuine new adjustment ---
# The guard must key on request_id, not on "the counted qty looks familiar".
Write-Host "`nCase 4: a new request_id is a real second count"
$request2 = [guid]::NewGuid().ToString()
$second = Invoke-RPC -name "adjust_inventory" -p @{
    p_product_id  = $product
    p_counted_qty = 9
    p_reason      = "جرد لاحق"
    p_request_id  = $request2
}
Test-Equal "second count delta is +3" 3 $second.delta
Test-Equal "product qty reached 9" 9 (Get-ProductQty $product)

# --- Case 5: a no-op count is still recorded, so its replay is stable ---
Write-Host "`nCase 5: a no-op count is ledgered and replays identically"
$request3 = [guid]::NewGuid().ToString()
$noop = Invoke-RPC -name "adjust_inventory" -p @{
    p_product_id  = $product
    p_counted_qty = 9
    p_request_id  = $request3
}
Test-Equal "no-op changed is false" "False" ([string]$noop.changed)
Test-Equal "no-op delta is 0" 0 $noop.delta
$moves2 = Invoke-RestMethod -Method Get -Uri "$url/rest/v1/stock_moves?select=id,type,qty&product_id=eq.$product&order=created_at.desc" -Headers $hGet
Test-Equal "no-op posted no movement" 2 @($moves2 | Where-Object { $_.type -eq 'adjust' }).Count

# --- Case 6: omitting p_request_id still works (backward compatibility) ---
# Every existing online caller sends no request_id. If the migration broke
# that path, this is where it shows. It also proves the old 4-arg overload was
# dropped: with both overloads present PostgREST would answer
# "function public.adjust_inventory(...) is not unique".
Write-Host "`nCase 6: the legacy no-request_id call still resolves"
$legacy = Invoke-RPC -name "adjust_inventory" -p @{
    p_product_id  = $product
    p_counted_qty = 11
    p_reason      = "جرد قديم بدون معرف"
}
Test-Equal "legacy call delta is +2" 2 $legacy.delta
Test-Equal "legacy call moved the stock" 11 (Get-ProductQty $product)

# --- Case 7: create_account first call creates ---
Write-Host "`nCase 7: create_account creates on the first call"
$accountCode = "9$((Get-Random -Minimum 100 -Maximum 999))"
$requestA = [guid]::NewGuid().ToString()
$created = Invoke-RPC -name "create_account" -p @{
    p_code       = $accountCode
    p_name       = "حساب اختبار عدم التكرار"
    p_type       = "expense"
    p_request_id = $requestA
}
Test-Ok "returned an account_id" ($null -ne $created.account_id) "got [$($created.account_id)]"
# Assert the key is ABSENT via a null check, not `[string]$created.duplicate`:
# the success envelope has no `duplicate` key at all, and casting $null to
# string yields "" in PowerShell 5.1, so `Test-Equal ... "False" ([string]...)`
# would fail against a perfectly correct response. Case 8 uses the same form.
Test-Ok "duplicate is not set" ($null -eq $created.duplicate) "duplicate=[$($created.duplicate)]"
Test-Equal "code echoed" $accountCode $created.code
$accountId = $created.account_id

# --- Case 8: the replay returns the SAME account_id, not duplicate:true ---
# The user-visible regression: the pre-0025 replay returned
# {'duplicate': true}, which the app maps to "كود الحساب مستخدم مسبقاً" --
# a retried create reported a validation failure and the local id_map never
# learned the account id, so later offline journals pointed at nothing.
Write-Host "`nCase 8: replaying create_account returns the original account"
$replayed = Invoke-RPC -name "create_account" -p @{
    p_code       = $accountCode
    p_name       = "حساب اختبار عدم التكرار"
    p_type       = "expense"
    p_request_id = $requestA
}
Test-Equal "replay returns the same account_id" $accountId $replayed.account_id
Test-Ok "replay does NOT report duplicate" ($null -eq $replayed.duplicate) "duplicate=$($replayed.duplicate)"

# The chart mirror must not be able to end up with two rows for one code. RLS
# scopes the GET to the caller's own tenant, so this counts only our rows.
$codeRows = Invoke-RestMethod -Method Get -Uri "$url/rest/v1/accounts?select=id,code&code=eq.$accountCode" -Headers $hGet
Test-Equal "exactly one account row exists for the code" 1 @($codeRows).Count

# --- Case 9: a genuine code collision still reports duplicate ---
# The guard must not turn a real duplicate into a false success. A DIFFERENT
# request_id reusing an existing code has no ledger row, so it falls through
# to the uniqueness check.
Write-Host "`nCase 9: a real code collision still reports duplicate"
$collision = Invoke-RPC -name "create_account" -p @{
    p_code       = $accountCode
    p_name       = "محاولة ثانية مختلفة"
    p_type       = "expense"
    p_request_id = ([guid]::NewGuid().ToString())
}
Test-Equal "collision reports duplicate" "True" ([string]$collision.duplicate)

# --- Case 10: legacy create_account (no request_id) still resolves ---
Write-Host "`nCase 10: the legacy no-request_id create_account still resolves"
$legacyCode = "8$((Get-Random -Minimum 100 -Maximum 999))"
$legacyAcct = Invoke-RPC -name "create_account" -p @{
    p_code = $legacyCode
    p_name = "حساب قديم بدون معرف"
    p_type = "expense"
}
Test-Ok "legacy create returned an account_id" ($null -ne $legacyAcct.account_id) "got [$($legacyAcct.account_id)]"

Test-Summary "0025 offline idempotency"

if (-not [Console]::IsInputRedirected) { Read-Host "Press Enter to close" }
if ($script:failures.Count -gt 0) { exit 1 }
exit 0
