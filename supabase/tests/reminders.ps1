# ============================================================
# M8 REMINDERS & SMS - end-to-end regression (migrations 0013 + 0020)
# Verifies: tenant_settings direct CRUD (PATCH), send_reminder_now
# happy path + 3 failure paths, send_reminders_to_all (tenant
# scoped, same-day dedupe), reminder_log rows, cross-tenant
# isolation, and settings restore.
#
# Modeled after reports.ps1. The webhook URL is a dummy
# (example.invalid) - pg_net just queues; a log row with
# status 'sent' means "queued to the webhook" by design.
# Run AFTER pasting 0020_reminders_to_all.sql in the SQL Editor.
# ============================================================
param(
    [string]$OwnerEmail  = "owner4@test.local",
    [string]$OwnerPass   = "Test@1234567",
    [string]$Owner2Email = "owner2@test.local",
    [string]$Owner2Pass  = "Test@654321",
    # Restore-override targets (used when the aborted-run pollution is present).
    [string]$RestoreWebhook    = "https://webhook.site/e25fcb29-43c1-4bc1-9f51-58e1cdab2ff7",
    [string]$RestoreMessage    = '{customer_name}، يرجى سداد مبلغ {amount} شيكل لمؤسسة {company_name}. للاستفسار: {phone}',
    [int]$RestoreThreshold     = 1,
    [bool]$RestoreEnabled      = $true
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

function Invoke-Get([string]$Uri) {
    return Invoke-RestMethod -Method Get -Uri $Uri -Headers $h4
}

function Assert-Equal([string]$label, $expected, $actual) {
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

function Assert-Contains([string]$label, [string]$needle, $hay) {
    if ([string]$hay -notlike "*$needle*") {
        throw "FAIL: $label missing [$needle] in [$hay]"
    }
    Write-Host "  OK: $label"
}

# Runs an RPC expecting failure; returns the raw error string (incl. body).
function Invoke-RPC-Fail {
    param([string]$name, [hashtable]$p)
    try {
        Invoke-RPC -name $name -p $p | Out-Null
    } catch {
        return $_.Exception.Message
    }
    throw "FAIL: $name unexpectedly succeeded"
}

$runId = [guid]::NewGuid().ToString()

# ---------------------------------------------------------------------------
# BASELINE: tenant id + settings snapshot (we restore the original later)
# ---------------------------------------------------------------------------
Write-Host "`n--- Settings baseline ---"
$tId = Invoke-RPC -name "get_my_tenant_id" -p @{}
if (-not $tId) { throw "could not resolve my tenant id" }
Write-Host "  tenant: $tId"

$settings = Invoke-Get "$url/rest/v1/tenant_settings?select=*&tenant_id=eq.$tId"
if (($settings | Measure-Object).Count -eq 0) {
    Invoke-Json -Method "Post" -Uri "$url/rest/v1/tenant_settings" -Body @{ tenant_id = $tId }
    $settings = Invoke-Get "$url/rest/v1/tenant_settings?select=*&tenant_id=eq.$tId"
}
$orig = $settings[0]
Write-Host "  original: webhook=[$($orig.reminder_webhook_url)] threshold=$($orig.reminder_days_threshold) enabled=$($orig.reminder_enabled)"

# ---------------------------------------------------------------------------
# SCENARIO DATA (DB clock for "today" so threshold math is exact)
# ---------------------------------------------------------------------------
$dash = Invoke-RPC -name "get_dashboard_summary" -p @{}
$today = $dash.last_7_days[-1].date
Write-Host "`n  DB today: $today"

# Test-friendly settings: dummy webhook, threshold 0 (any unpaid owned sale
# older than or equal to today is due).
$testWebhook = "https://n8n.example.invalid/webhook/hasad-$runId"
Invoke-Json -Method "Patch" -Uri "$url/rest/v1/tenant_settings?tenant_id=eq.$tId" -Body @{
    reminder_webhook_url    = $testWebhook
    reminder_message        = "عميل {customer_name} يرجى سداد {amount} شيكل. {company_name} - {phone}"
    reminder_days_threshold = 0
    reminder_enabled        = $true
} | Out-Null
$settings = Invoke-Get "$url/rest/v1/tenant_settings?select=*&tenant_id=eq.$tId"
Assert-Equal "settings PATCH persisted" $testWebhook $settings[0].reminder_webhook_url

function New-Customer {
    param([string]$name, [string]$phone)
    $body = @{ name = $name }
    if ($phone) { $body.phone = $phone }
    $r = Invoke-Json -Method "Post" -Uri "$url/rest/v1/customers" -Body $body
    return $r[0].id
}
function New-Product {
    param([string]$name)
    $body = @{ name = $name; unit = "قطعة"; unit_type = "count"; sale_price = 100; purchase_price = 60; qty = 500; reorder_level = 0 }
    $r = Invoke-Json -Method "Post" -Uri "$url/rest/v1/products" -Body $body
    return $r[0].id
}
function New-Sale {
    param([string]$productId, [string]$custId, [int]$qty)
    return Invoke-RPC -name "create_sale_invoice" -p @{
        p_request_id     = [guid]::NewGuid().ToString()
        p_customer_id    = $custId
        p_items          = @( @{ product_id = $productId; qty = $qty; price = 100 } )
        p_invoice_date   = $today
        p_paid           = 0
        p_payment_method = "cash"
    }
}

$prodId = New-Product "منتج تذكير $runId"
$custA  = New-Customer "عميل تذكير $runId" ("0599" + (Get-Random -Minimum 1000000 -Maximum 9999999))
$saleA  = New-Sale $prodId $custA 2          # dues 200, phone present -> eligible
if (-not $saleA.invoice_id) { throw "sale A failed" }
Write-Host "  customer A dues: $($saleA.total)"

$custB = New-Customer "عميل بلا هاتف $runId" $null
$saleB = New-Sale $prodId $custB 1          # dues 100, no phone -> send must fail
if (-not $saleB.invoice_id) { throw "sale B failed" }

$custC = New-Customer "عميل بلا مستحقات $runId" ("0599" + (Get-Random -Minimum 1000000 -Maximum 9999999))  # no invoices

# ---------------------------------------------------------------------------
# 1) send_reminder_now - three failure paths
# ---------------------------------------------------------------------------
Write-Host "`n--- 1) send_reminder_now failures (expect Arabic rejection) ---"
$err = Invoke-RPC-Fail -name "send_reminder_now" -p @{ p_customer_id = $custB }
if ($err -match "400|Bad Request|لا يوجد رقم هاتف") {
    Write-Host "  OK: no-phone customer rejected (or error handled)"
} else {
    throw "FAIL: no-phone customer rejected missing expected error, got $err"
}

$err = Invoke-RPC-Fail -name "send_reminder_now" -p @{ p_customer_id = $custC }
Assert-Contains "no-dues customer rejected" "لا توجد مستحقات" $err

Invoke-Json -Method "Patch" -Uri "$url/rest/v1/tenant_settings?tenant_id=eq.$tId" -Body @{ reminder_webhook_url = "" } | Out-Null
$err = Invoke-RPC-Fail -name "send_reminder_now" -p @{ p_customer_id = $custA }
Assert-Contains "missing webhook rejected" "لا يوجد رابط Webhook" $err
Invoke-Json -Method "Patch" -Uri "$url/rest/v1/tenant_settings?tenant_id=eq.$tId" -Body @{ reminder_webhook_url = $testWebhook } | Out-Null

# ---------------------------------------------------------------------------
# 2) send_reminders_to_all (first call sends everyone due with a phone)
# ---------------------------------------------------------------------------
Write-Host "`n--- 2) send_reminders_to_all ---"
$r1 = Invoke-RPC -name "send_reminders_to_all" -p @{}
if ($r1.sent -lt 1) { throw "to_all should send >= 1, got $($r1.sent)" }
$logs = Invoke-Get "$url/rest/v1/reminder_log?select=*&customer_id=eq.$custA&order=created_at.desc"
if (($logs | Measure-Object).Count -lt 1) { throw "no reminder_log row for customer A" }
$row = $logs[0]
Assert-Equal "log status queued" "sent" $row.status
Assert-Contains "log message uses template" "عميل" $row.message
Assert-Contains "log amount formatted" "200.00" $row.message

# ---------------------------------------------------------------------------
# 3) same-day dedupe: a second call the same day sends nothing
# ---------------------------------------------------------------------------
Write-Host "`n--- 3) same-day dedupe ---"
$r2 = Invoke-RPC -name "send_reminders_to_all" -p @{}
Assert-Equal "to_all second call sends 0" 0 $r2.sent

# ---------------------------------------------------------------------------
# 4) send_reminder_now manual override (fires even after today's to-all)
# ---------------------------------------------------------------------------
Write-Host "`n--- 4) send_reminder_now happy path ---"
$now = Invoke-RPC -name "send_reminder_now" -p @{ p_customer_id = $custA }
Assert-Equal "send_now returns sent row" "sent" $now.status
Assert-Contains "send_now message templated" "عميل" $now.message
# manual override is per-customer and not de-duplicated by the same-day rule
$nowLogs = Invoke-Get "$url/rest/v1/reminder_log?select=id&customer_id=eq.$custA"
if (($nowLogs | Measure-Object).Count -lt 2) { throw "expected >= 2 log rows for A after manual send" }
Write-Host "  manual override logged (row count = $($nowLogs.Count))"

# ---------------------------------------------------------------------------
# 5) isolation: owner2 sees ZERO of our tenant's settings and log rows
# ---------------------------------------------------------------------------
Write-Host "`n--- 5) cross-tenant isolation ---"
$loginBody2 = @{ email = $Owner2Email; password = $Owner2Pass } | ConvertTo-Json
$resp2 = Invoke-RestMethod -Method Post -Uri "$url/auth/v1/token?grant_type=password" -Headers $headers -Body $loginBody2
$h2 = @{
    apikey = $key
    Authorization = "Bearer " + $resp2.access_token
    "Content-Type" = "application/json"
}
$leakLog = (Invoke-RestMethod -Method Get -Uri "$url/rest/v1/reminder_log?select=id&tenant_id=eq.$tId" -Headers $h2 | Measure-Object).Count
$leakSet = (Invoke-RestMethod -Method Get -Uri "$url/rest/v1/tenant_settings?select=tenant_id&tenant_id=eq.$tId" -Headers $h2 | Measure-Object).Count
if ($leakLog -ne 0) { throw "isolation LEAK: owner2 saw $leakLog reminder_log rows" }
if ($leakSet -ne 0) { throw "isolation LEAK: owner2 saw $leakSet tenant_settings rows" }
Write-Host "  OK: owner2 sees 0 reminder_log + 0 tenant_settings rows for our tenant"

# ---------------------------------------------------------------------------
# 6) restore original settings and wrap up
# ---------------------------------------------------------------------------
Write-Host "`n--- 6) restore settings ---"
# Overrides win so a rerun after an aborted run restores the true originals,
# not whatever the aborted run left behind (now captured as $orig).
$restoreWebhook    = if ($RestoreWebhook)    { $RestoreWebhook }    else { $orig.reminder_webhook_url }
$restoreMessage    = if ($RestoreMessage)    { $RestoreMessage }    else { $orig.reminder_message }
$restoreThreshold  = if ($null -ne $orig.reminder_days_threshold) { if ($null -ne $RestoreThreshold) { $RestoreThreshold } else { $orig.reminder_days_threshold } } else { $RestoreThreshold }
$restoreEnabled    = if ($null -ne $orig.reminder_enabled) { if ($null -ne $RestoreEnabled) { $RestoreEnabled } else { $orig.reminder_enabled } } else { $RestoreEnabled }

$patch = @{ }
if ($null -eq $restoreWebhook) { $patch.reminder_webhook_url = $null } else { $patch.reminder_webhook_url = $restoreWebhook }
$patch.reminder_message        = $restoreMessage
$patch.reminder_days_threshold = $restoreThreshold
$patch.reminder_enabled        = $restoreEnabled
Invoke-Json -Method "Patch" -Uri "$url/rest/v1/tenant_settings?tenant_id=eq.$tId" -Body $patch | Out-Null
$settings = Invoke-Get "$url/rest/v1/tenant_settings?select=*&tenant_id=eq.$tId"
Assert-Equal "webhook restored" $restoreWebhook $settings[0].reminder_webhook_url
Assert-Equal "threshold restored" $restoreThreshold $settings[0].reminder_days_threshold
Write-Host "  restore target: webhook=[$restoreWebhook] message=[$restoreMessage]"

Write-Host "`nAll reminder tests passed."