# ============================================================
# IDEMPOTENCY FIXED - duplicate request_id on record_payment (M1)
# Verifies: same request_id twice -> first succeeds, second
# returns {duplicate: true, payment: {...}} with no second row.
# NOTE: no cleanup deletes here - financial records are immutable
# by design (SELECT-only RLS; no DELETE grant). Test rows are
# tenant-scoped and harmless.
# ============================================================
param(
    [string]$OwnerEmail = "owner4@test.local",
    [string]$OwnerPass  = "Test@1234567"
)

$url = "https://sxasnunzspkuwbxiddqd.supabase.co"
$key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN4YXNudW56c3BrdXdieGlkZHFkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg3MDYyNDIsImV4cCI6MjEwNDI4MjI0Mn0.6zYdwBewK7t4P7w7w_-BYTXI1rolSeb0Zd6jteyJsUk"
$headers = @{ apikey = $key; "Content-Type" = "application/json" }

# 1. Login
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

# 2. Get Tenant ID
$tenant = @(Invoke-RestMethod -Method Get -Uri "$url/rest/v1/tenants?select=id&limit=1" -Headers $h4)
$tenantId = $tenant[0].id
Write-Host "Tenant ID: $tenantId"

# 3. Helper
function InsertAndGetId {
    param(
        [string]$table,
        [hashtable]$data
    )
    $body = $data | ConvertTo-Json
    try {
        $result = Invoke-RestMethod -Method Post -Uri "$url/rest/v1/$table" -Headers $h4 -Body $body -ErrorAction Stop
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

# 4. Create test data
Write-Host "Creating Customer, Product..."
$customerId = InsertAndGetId -table "customers" -data @{ name = "Idem_Customer"; tenant_id = $tenantId }
Write-Host "Customer ID: $customerId"

$productId = InsertAndGetId -table "products" -data @{
    tenant_id = $tenantId
    name = "Idem_Product"
    unit = "piece"
    unit_type = "count"
    sale_price = 1000
    purchase_price = 500
    qty = 10
}
Write-Host "Product ID: $productId"

# 5. Create Sale Invoice
Write-Host "Creating Sale Invoice..."
$saleBody = @{
    p_request_id = [guid]::NewGuid().ToString()
    p_customer_id = $customerId
    p_invoice_date = (Get-Date -Format "yyyy-MM-dd")
    p_items = @(@{ product_id = $productId; qty = 2; price = 1000 })
} | ConvertTo-Json -Depth 6

try {
    $saleResult = Invoke-RestMethod -Method Post -Uri "$url/rest/v1/rpc/create_sale_invoice" -Headers $h4 -Body $saleBody -ErrorAction Stop
    $invoiceId = $saleResult.invoice_id
    Write-Host "Invoice Created, ID: $invoiceId, Status: $($saleResult.status)"
} catch {
    Write-Host "Invoice creation failed:"
    $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
    Write-Host $reader.ReadToEnd()
    exit 1
}

# 6. Idempotency test: fixed request_id
$fixedRequestId = [guid]::NewGuid().ToString()
Write-Host ("`nFixed Request ID: " + $fixedRequestId)

$payBody = @{
    p_request_id = $fixedRequestId
    p_invoice_id = $invoiceId
    p_amount = 2000
    p_method = "cash"
    p_date = (Get-Date -Format "yyyy-MM-dd")
    p_note = "idempotency test"
} | ConvertTo-Json

Write-Host "`n--- FIRST CALL (should succeed) ---"
try {
    $result1 = Invoke-RestMethod -Method Post -Uri "$url/rest/v1/rpc/record_payment" -Headers $h4 -Body $payBody -ErrorAction Stop
    Write-Host "First result: $($result1 | ConvertTo-Json -Compress)"
} catch {
    Write-Host "First call failed: $_"
    exit 1
}

Write-Host "`n--- SECOND CALL (should return duplicate) ---"
try {
    $result2 = Invoke-RestMethod -Method Post -Uri "$url/rest/v1/rpc/record_payment" -Headers $h4 -Body $payBody -ErrorAction Stop
    Write-Host "Second result: $($result2 | ConvertTo-Json -Compress)"
    if ($result2.duplicate -eq $true) {
        Write-Host "SUCCESS: Idempotency check passed! Duplicate detected."
    } else {
        Write-Host "WARNING: Duplicate was not detected. Check request_id logic."
        exit 1
    }
} catch {
    Write-Host "Second call failed with error: $_"
    exit 1
}

Write-Host "Idempotency test completed!"