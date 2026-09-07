# ============================================================
# REMINDER FINAL - reminder webhook test (M1 Batch 6)
# Verifies: tenant_settings PATCH, unpaid invoice -> send_reminder_now
# -> reminder_log row, and cross-tenant isolation (owner2 = 0).
# ============================================================
param(
    [string]$Owner1Email  = "owner1@test.local",
    [string]$Owner1Pass   = "Test@1234566",
    [string]$Owner2Email  = "owner2@test.local",
    [string]$Owner2Pass   = "Test@654321",
    [string]$WebhookId    = "e25fcb29-43c1-4bc1-9f51-58e1cdab2ff7"
)

$url = "https://sxasnunzspkuwbxiddqd.supabase.co"
$key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN4YXNudW56c3BrdXdieGlkZHFkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg3MDYyNDIsImV4cCI6MjEwNDI4MjI0Mn0.6zYdwBewK7t4P7w7w_-BYTXI1rolSeb0Zd6jteyJsUk"
$headers = @{ apikey = $key; "Content-Type" = "application/json" }

# 1. Login
Write-Host "Logging in..."
$loginBody = @{ email = $Owner1Email; password = $Owner1Pass } | ConvertTo-Json
try {
    $resp = Invoke-RestMethod -Method Post -Uri "$url/auth/v1/token?grant_type=password" -Headers $headers -Body $loginBody -ErrorAction Stop
} catch {
    Write-Host "Owner1 login failed, trying owner4..."
    $loginBody = @{ email = "owner4@test.local"; password = "Test@1234567" } | ConvertTo-Json
    $resp = Invoke-RestMethod -Method Post -Uri "$url/auth/v1/token?grant_type=password" -Headers $headers -Body $loginBody -ErrorAction Stop
}
$h1 = @{
    apikey = $key
    Authorization = "Bearer " + $resp.access_token
    "Content-Type" = "application/json"
    "Prefer" = "return=representation"
}
Write-Host "Login successful"

# 2. Get Tenant ID
Write-Host "Getting Tenant ID..."
$tenant = @(Invoke-RestMethod -Method Get -Uri "$url/rest/v1/tenants?select=id&limit=1" -Headers $h1)
$tenantId = $tenant[0].id
Write-Host "Tenant ID: $tenantId"

# 3. Helper (NOTE: PATCH on tenant_settings REQUIRES ?tenant_id=eq. filter)
function InsertAndGetId {
    param(
        [string]$table,
        [hashtable]$data
    )
    $body = $data | ConvertTo-Json
    try {
        $result = Invoke-RestMethod -Method Post -Uri "$url/rest/v1/$table" -Headers $h1 -Body $body -ErrorAction Stop
        if ($result -and $result.Count -gt 0 -and $result[0].id) {
            return $result[0].id
        } else {
            throw "Insertion succeeded but no ID in response"
        }
    } catch {
        Write-Host "Failed in table $table : $_"
        if ($_.Exception.Response) {
            $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            Write-Host "Error details: $($reader.ReadToEnd())"
        }
        exit 1
    }
}

# 4. Set Webhook URL
Write-Host "Setting webhook URL..."
$webhookUrl = "https://webhook.site/$WebhookId"
$patchBody = @{ reminder_webhook_url = $webhookUrl; reminder_days_threshold = 1 } | ConvertTo-Json
try {
    Invoke-RestMethod -Method Patch -Uri "$url/rest/v1/tenant_settings?tenant_id=eq.$tenantId" -Headers $h1 -Body $patchBody | Out-Null
    Write-Host "Webhook URL set to: $webhookUrl"
} catch {
    Write-Host "Failed to set webhook: $_"
    exit 1
}

# 5. Create Customer (with phone)
Write-Host "Creating customer..."
$customerId = InsertAndGetId -table "customers" -data @{
    tenant_id = $tenantId
    name = "Reminder_Test_Customer"
    phone = "0599-000004"
}
Write-Host "Customer ID: $customerId"

# 6. Create Product
Write-Host "Creating product..."
$productId = InsertAndGetId -table "products" -data @{
    tenant_id = $tenantId
    name = "Reminder_Test_Product"
    unit = "piece"
    unit_type = "count"
    sale_price = 1000
    purchase_price = 500
    qty = 10
}
Write-Host "Product ID: $productId"

# 7. Create Unpaid Sale Invoice
Write-Host "Creating unpaid invoice..."
$invoiceData = @{
    p_request_id = [guid]::NewGuid().ToString()
    p_customer_id = $customerId
    p_invoice_date = (Get-Date -Format "yyyy-MM-dd")
    p_items = @(@{ product_id = $productId; qty = 2; price = 1000 })
} | ConvertTo-Json -Depth 6

try {
    $invResult = Invoke-RestMethod -Method Post -Uri "$url/rest/v1/rpc/create_sale_invoice" -Headers $h1 -Body $invoiceData -ErrorAction Stop
    $invoiceId = $invResult.invoice_id
    Write-Host "Invoice created: $invoiceId, Status: $($invResult.status)"
} catch {
    Write-Host "Failed to create invoice:"
    $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
    Write-Host $reader.ReadToEnd()
    exit 1
}

# 8. Call send_reminder_now
Write-Host "Calling send_reminder_now..."
try {
    $result = Invoke-RestMethod -Method Post -Uri "$url/rest/v1/rpc/send_reminder_now" -Headers $h1 -Body (@{ p_customer_id = $customerId } | ConvertTo-Json) -ErrorAction Stop
    Write-Host "Reminder sent: $($result | ConvertTo-Json -Compress)"
} catch {
    Write-Host "Reminder failed:"
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        Write-Host $reader.ReadToEnd()
    } else {
        Write-Host $_.Exception.Message
    }
}

# 9. Check reminder_log
Write-Host "Checking reminder_log..."
$logs = Invoke-RestMethod -Method Get -Uri "$url/rest/v1/reminder_log?select=*&order=created_at.desc&limit=1" -Headers $h1
if ($logs.Count -gt 0) {
    Write-Host "Latest log: $($logs | ConvertTo-Json -Compress)"
} else {
    Write-Host "No logs found (reminder might have failed silently)"
}

# 10. Check owner2 invoices (expect 0)
Write-Host "Checking owner2 invoices + log (expecting 0)..."
$loginBody2 = @{ email = $Owner2Email; password = $Owner2Pass } | ConvertTo-Json
try {
    $resp2 = Invoke-RestMethod -Method Post -Uri "$url/auth/v1/token?grant_type=password" -Headers $headers -Body $loginBody2 -ErrorAction Stop
    $h2 = @{ apikey = $key; Authorization = "Bearer " + $resp2.access_token; "Content-Type" = "application/json" }
    $inv2 = (Invoke-RestMethod -Method Get -Uri "$url/rest/v1/invoices?select=id" -Headers $h2).Count
    $log2 = (Invoke-RestMethod -Method Get -Uri "$url/rest/v1/reminder_log?select=id" -Headers $h2).Count
    Write-Host "Owner2 invoices: $inv2 (Expected: 0)"
    Write-Host "Owner2 reminder_log: $log2 (Expected: 0)"
} catch {
    Write-Host "Owner2 check failed: $_"
}

Write-Host "Test completed. Check your webhook.site dashboard ($WebhookId)"